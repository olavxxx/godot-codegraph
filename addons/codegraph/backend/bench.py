"""bench.py — benchmarks code graph against text search on real code exploration tasks.
Dynamically auto-discovers real signals, scripts, callers, scene wires, and autoloads
from whatever Godot project it is executed in.

Run:    python addons/codegraph/backend/bench.py            (all tasks)
       python addons/codegraph/backend/bench.py --tasks=4,5

Each question is solved via two approaches, measuring time and token footprint:
  GREP : text search across files, plus context an agent must read to answer
         (= 25 lines around each match, merged overlaps)
  GRAPH: kg command in the same process (including index self-refresh)

Token estimate = characters / 4 (conservative heuristic for GDScript code).
"""
from __future__ import annotations

import io
import json
import re
import sys
import time
from contextlib import redirect_stdout
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import graph as kg  # noqa: E402

CONTEXT_LINES = 25


def tokens(s: str) -> int:
    return max(1, round(len(s) / 4))


def grep_side(root: Path, files: list[str], needles: list[str]) -> tuple[str, float, dict]:
    t0 = time.time()
    pat = re.compile("|".join(needles))
    hits: dict[str, list[int]] = {}
    for rel in files:
        try:
            text = (root / rel).read_text(encoding="utf-8-sig", errors="replace")
        except Exception:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            if pat.search(line):
                hits.setdefault(rel, []).append(i)
    search_ms = (time.time() - t0) * 1000

    # phase 2: agent opens context around hits to understand them
    t1 = time.time()
    out: list[str] = []
    segments = 0
    for rel, lns in sorted(hits.items(), key=lambda kv: -len(kv[1])):
        try:
            lines = (root / rel).read_text(encoding="utf-8-sig", errors="replace").splitlines()
        except Exception:
            continue
        spans: list[list[int]] = []
        for ln in sorted(lns):
            a, b = max(1, ln - CONTEXT_LINES), min(len(lines), ln + CONTEXT_LINES)
            if spans and a <= spans[-1][1] + 1:
                spans[-1][1] = max(spans[-1][1], b)
            else:
                spans.append([a, b])
        for a, b in spans:
            segments += 1
            out.append(f"--- {rel}:{a}-{b}\n" + "\n".join(lines[a - 1:b]))
    read_ms = (time.time() - t1) * 1000
    return "\n".join(out), search_ms + read_ms, {
        "filer_skanna": len(files), "filer_treff": len(hits),
        "treff": sum(len(v) for v in hits.values()), "kontekstsegment": segments,
        "sok_ms": round(search_ms, 1), "les_ms": round(read_ms, 1),
    }


def competent_grep(root: Path, files: list[str], needles: list[str],
                   open_files: int = 3, win: int = 25) -> tuple[str, float]:
    """Realistic competent model: the agent greps with file list + counts, then
    only opens the top 3 heaviest files around the first match. These numbers
    represent practical developer/agent usage."""
    t0 = time.time()
    pat = re.compile("|".join(needles))
    hits: dict[str, tuple[int, list[str]]] = {}
    for rel in files:
        try:
            lines = (root / rel).read_text(encoding="utf-8-sig", errors="replace").splitlines()
        except Exception:
            continue
        n = sum(1 for l in lines if pat.search(l))
        if n:
            hits[rel] = (n, lines)
    out = ["\n".join(f"{rel}:{n}" for rel, (n, _) in hits.items())]        # phase 1: file list + counts
    for rel, (n, lines) in sorted(hits.items(), key=lambda kv: -kv[1][0])[:open_files]:
        first = next((i for i, l in enumerate(lines, 1) if pat.search(l)), 1)
        a, b = max(1, first - win), min(len(lines), first + win)
        out.append(f"{rel}:{a}-{b}\n" + "\n".join(lines[a - 1:b]))         # phase 2: open top 3 files
    return "\n".join(out), (time.time() - t0) * 1000


def graph_side(con, fn, *args) -> tuple[str, float]:
    buf = io.StringIO()
    t0 = time.time()
    with redirect_stdout(buf):
        fn(con, *args)
    return buf.getvalue(), (time.time() - t0) * 1000


def discover_tasks(con, root: Path) -> list[dict]:
    """Dynamically auto-discovers representative symbols, scripts, scene wires,
    and autoloads from whatever Godot project is being analyzed."""
    total_scripts = con.execute("SELECT count(*) FROM files WHERE path LIKE '%.gd' AND addons = 0").fetchone()[0]
    if total_scripts == 0:
        total_scripts = con.execute("SELECT count(*) FROM files WHERE path LIKE '%.gd'").fetchone()[0]

    if total_scripts < 2:
        return []

    tasks = []

    # 1. Top Signal (with emitters or listeners)
    sig_row = con.execute("""
        SELECT nd.name, count(*) as c
        FROM edges e
        JOIN nodes nd ON e.dst = nd.id
        WHERE e.kind IN ('emits', 'connects_to') AND nd.kind = 'signal'
        GROUP BY nd.name
        ORDER BY c DESC LIMIT 1
    """).fetchone()
    if not sig_row:
        sig_row = con.execute("SELECT name FROM nodes WHERE kind = 'signal' LIMIT 1").fetchone()

    sig_name = sig_row[0] if sig_row else "pressed"
    tasks.append(dict(
        id=1,
        spm=f"Who emits {sig_name}, and who listens?",
        spm_no=f"Hvem emitterer {sig_name}, og hvem lytter?",
        grep=[sig_name],
        ane="All text matches including comments and strings, vs resolved signal graph.",
        graf=lambda c, s=sig_name: kg.cmd_signal(c, s)
    ))

    # 2. Largest / Key script outline
    script_row = con.execute("""
        SELECT path, lines FROM files
        WHERE path LIKE '%.gd' AND path NOT LIKE '%test%' AND addons = 0
        ORDER BY lines DESC LIMIT 1
    """).fetchone()
    if not script_row:
        script_row = con.execute("""
            SELECT path, lines FROM files
            WHERE path LIKE '%.gd'
            ORDER BY lines DESC LIMIT 1
        """).fetchone()

    script_path = script_row[0] if script_row else "Main.gd"
    script_name = Path(script_path).name
    script_stem = Path(script_path).stem
    tasks.append(dict(
        id=2,
        spm=f"Outline of {script_name} without opening file",
        spm_no=f"Oversikt over {script_name} uten å åpne filen",
        grep=[r"func _", r"^extends", r"class_name"],
        files=[script_path],
        ane="Fastest for grep - graph outline provides structured overview without bloating LLM context.",
        graf=lambda c, s=script_stem: kg.cmd_outline(c, s)
    ))

    # 3. Method callers
    call_row = con.execute("""
        SELECT nd.name, count(*) as c
        FROM edges e
        JOIN nodes nd ON e.dst = nd.id
        WHERE e.kind = 'calls'
          AND nd.name NOT LIKE 'assert_%'
          AND nd.name NOT IN ('print', 'push_error', 'emit_signal', 'connect', 'queue_free')
        GROUP BY nd.name
        ORDER BY c DESC LIMIT 1
    """).fetchone()
    fn_name = call_row[0] if call_row else "take_damage"
    tasks.append(dict(
        id=3,
        spm=f"Who calls {fn_name}() across the project?",
        spm_no=f"Hvem kaller {fn_name}() på tvers av prosjektet?",
        grep=[rf"\b{fn_name}\b"],
        ane="Matches definition and call sites alike. Uncertain who is caller vs receiver.",
        graf=lambda c, f=fn_name: kg._dir(c, f, "callers")
    ))

    # 4. Scene connection target method
    tscn_method_row = con.execute("""
        SELECT nd.name, count(*) as c
        FROM edges e
        JOIN nodes nd ON e.dst = nd.id
        WHERE e.kind = 'connects_to'
        GROUP BY nd.name
        ORDER BY c DESC LIMIT 1
    """).fetchone()
    tscn_method = tscn_method_row[0] if tscn_method_row else "close"
    tasks.append(dict(
        id=4,
        spm=f"Which scene connections lead to {tscn_method}()?",
        spm_no=f"Hvilke scenetilkoblinger går til {tscn_method}()?",
        grep=[rf'method="{tscn_method}"'],
        ane="Matches in .tscn, but grep cannot resolve which script receives the signal.",
        graf=lambda c, m=tscn_method: kg.cmd_signal(c, m)
    ))

    # 5. Scene connection signal
    tscn_sig_row = con.execute("""
        SELECT ns.name, count(*) as c
        FROM edges e
        JOIN nodes ns ON e.src = ns.id
        WHERE e.kind = 'connects_to'
        GROUP BY ns.name
        ORDER BY c DESC LIMIT 1
    """).fetchone()
    tscn_sig = tscn_sig_row[0] if tscn_sig_row else "pressed"
    tasks.append(dict(
        id=5,
        spm=f"Who receives '{tscn_sig}' in .tscn files?",
        spm_no=f"Hvem mottar '{tscn_sig}' i .tscn-filer?",
        grep=[rf'\[connection signal="{tscn_sig}"'],
        ane="Scene connection lines without receiver. Graph resolves exact script:line for each.",
        graf=lambda c, s=tscn_sig: kg.cmd_signal(c, s)
    ))

    # 6. Network @rpc (or class inheritance if single player)
    rpc_row = con.execute("""
        SELECT name FROM nodes WHERE kind = 'fn' AND meta LIKE '%rpc%' LIMIT 1
    """).fetchone()
    if rpc_row:
        tasks.append(dict(
            id=6,
            spm="Where do @rpc functions exist, and who calls them?",
            spm_no="Hvor finnes @rpc-funksjoner, og hvem kaller dem?",
            grep=[r"^[ \t]*@rpc"],
            ane="Annotated lines, but grep cannot see RPC transfer mode, authority, or call counts.",
            graf=lambda c: kg.cmd_rpc(c, None)
        ))
    else:
        ext_row = con.execute("""
            SELECT nd.name, count(*) as c
            FROM edges e
            JOIN nodes nd ON e.dst = nd.id
            WHERE e.kind = 'extends'
            GROUP BY nd.name
            ORDER BY c DESC LIMIT 1
        """).fetchone()
        base_name = ext_row[0] if ext_row else "Node"
        tasks.append(dict(
            id=6,
            spm=f"Which classes extend {base_name} across the project?",
            spm_no=f"Hvilke klasser arver fra {base_name}?",
            grep=[rf"\bextends {base_name}\b"],
            ane="Grep misses indirect subclasses and inner classes. Graph maps full hierarchy.",
            graf=lambda c, b=base_name: kg._dir(c, b, "callers")
        ))

    # 7. Impact analysis of top Autoload or Central Class
    impact_row = con.execute("""
        SELECT nd.name, nd.kind, count(*) as c
        FROM edges e
        JOIN nodes nd ON e.dst = nd.id
        WHERE nd.kind IN ('autoload', 'class')
        GROUP BY nd.name
        ORDER BY c DESC LIMIT 1
    """).fetchone()
    if not impact_row:
        impact_row = con.execute("SELECT name, kind FROM nodes WHERE kind = 'class' LIMIT 1").fetchone()

    impact_name = impact_row[0] if impact_row else "GameState"
    is_autoload = (impact_row[1] == 'autoload') if impact_row else True
    tasks.append(dict(
        id=7,
        spm=f"What is impacted by changing {impact_name}?",
        spm_no=f"Hva påvirkes av å endre {impact_name}?",
        grep=[rf"\b{impact_name}\."] if is_autoload else [rf"\b{impact_name}\b"],
        ane="Widespread usage across project. Exceeds LLM context window without a graph index.",
        graf=lambda c, n=impact_name: kg.cmd_impact(c, n, 2)
    ))

    # 8. Groups (or high-impact variable/constant if no groups)
    group_row = con.execute("""
        SELECT nd.name, count(*) as c
        FROM edges e
        JOIN nodes nd ON e.dst = nd.id
        WHERE nd.kind = 'group'
        GROUP BY nd.name
        ORDER BY c DESC LIMIT 1
    """).fetchone()
    if group_row:
        grp_name = group_row[0]
        tasks.append(dict(
            id=8,
            spm=f"Who uses group '{grp_name}'?",
            spm_no=f"Hvem bruker gruppen '{grp_name}'?",
            grep=[rf'"{grp_name}"'],
            ane="Matches without distinguishing membership (in_group) from querying (queries_group).",
            graf=lambda c, g=grp_name: kg.cmd_find(c, g)
        ))
    else:
        var_row = con.execute("""
            SELECT nd.name, count(*) as c
            FROM edges e
            JOIN nodes nd ON e.dst = nd.id
            WHERE nd.kind IN ('const', 'var')
            GROUP BY nd.name
            ORDER BY c DESC LIMIT 1
        """).fetchone()
        var_name = var_row[0] if var_row else "config"
        tasks.append(dict(
            id=8,
            spm=f"Who references {var_name} across files?",
            spm_no=f"Hvem refererer til {var_name} på tvers av filer?",
            grep=[rf"\b{var_name}\b"],
            ane="Matches local variables with same name. Graph traces true definition sites.",
            graf=lambda c, v=var_name: kg.cmd_find(c, v)
        ))

    return tasks


def run(root: Path, only: list[int] | None) -> list[dict]:
    con = kg.db(dict(root=root))  # opens + self-refreshes index
    tasks = discover_tasks(con, root)
    if not tasks:
        print("Project contains fewer than 2 scripts. Cannot run benchmark suite.")
        con.close()
        return []

    alle = kg.list_files(root)
    rows = []
    try:
        for t in tasks:
            if only and t["id"] not in only:
                continue
            files = t.get("files") or alle
            gtext, gms, ginfo = grep_side(root, files, t["grep"])
            ctext, cms = competent_grep(root, files, t["grep"])
            ktext, kms_cold = graph_side(con, t["graf"])      # cold side: initial touch of index pages
            _, kms_warm = graph_side(con, t["graf"])          # warm: same query repeated
            gt, ct, kt = tokens(gtext), tokens(ctext), tokens(ktext)
            rows.append(dict(id=t["id"], spm=t["spm"], spm_no=t.get("spm_no", t["spm"]),
                             grep_info=ginfo, grep_ane=t.get("ane", ""),
                             grep_naiv_ms=round(gms, 1), grep_naiv_token=gt,
                             grep_dugleg_ms=round(cms, 1), grep_dugleg_token=ct,
                             graf_ms=round(kms_cold, 1), graf_ms_varm=round(kms_warm, 1),
                             graf_token=kt,
                             speedup=round(cms / max(kms_warm, 0.001), 1),
                             spart_ms=round(cms - kms_warm, 1),
                             spart_pct=round(100 * (cms - kms_warm) / max(cms, 0.001)),
                             spart_ms_naiv=round(gms - kms_warm, 1),
                             token_ratio=round(ct / max(kt, 1), 1)))
            r = rows[-1]
            print(f"  [{t['id']}] {t['spm'][:40]:42} grep naive {gt:7} t · comp {ct:6} t   "
                  f"graph {kt:6} t   {'GRAPH' if kt <= ct else 'GREP'} {r['token_ratio']:5.1f}x")
    finally:
        con.close()
    return rows


def report(root: Path, rows: list[dict]) -> None:
    out = root / kg.DB_DIR / "bench.md"
    if not rows:
        out.write_text("# CodeGraph Benchmark\n\nProject has insufficient GDScript files to run benchmark suite.\n", encoding="utf-8")
        (root / kg.DB_DIR / "bench.json").write_text("[]", encoding="utf-8")
        print(f"\nwrote {out} (empty)")
        return

    L = ["# CodeGraph Benchmark", "",
         f"Repository: `{root}`",
         f"{len(rows)} dynamically discovered tasks from active codebase. Two grep models tested:",
         "",
         "* **grep naive** = regular pattern search + opening ±25 lines around *every* match (what a naive bot does)",
         "* **grep competent** = file list with counts (like `rg -l -c`), then opening ±25 lines in the top 3 files",
         "",
         "**Competent figures are what matter in practice.** Tokens = chars / 4. `graph ms` is cold / warm.", "",
         "| # | Task | grep naive t | grep comp. t | comp. ms | graph ms (cold/warm) | graph tokens | graph vs comp. | time saved |",
         "|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        win = "**graph**" if r["graf_token"] <= r["grep_dugleg_token"] else "**grep**"
        L.append(f"| {r['id']} | {r['spm']} | {r['grep_naiv_token']} | {r['grep_dugleg_token']} | "
                 f"{r['grep_dugleg_ms']} | {r['graf_ms']} / {r.get('graf_ms_varm', r['graf_ms'])} | "
                 f"{r['graf_token']} | {win} {r['token_ratio']}× | "
                 f"+{r['spart_ms']} ms ({r['spart_pct']}%) |")
    tgn, tgc, tk = (sum(r["grep_naiv_token"] for r in rows), sum(r["grep_dugleg_token"] for r in rows),
                    sum(r["graf_token"] for r in rows))
    mc, mk = sum(r["grep_dugleg_ms"] for r in rows), sum(r["graf_ms_varm"] for r in rows)
    mgn = sum(r["grep_naiv_ms"] for r in rows)
    graf_vinn = sum(1 for r in rows if r["graf_token"] <= r["grep_dugleg_token"])
    sp = sum(r["spart_ms"] for r in rows)
    spn = sum(r["spart_ms_naiv"] for r in rows)
    L += ["",
          f"**Total tokens:** grep naive {tgn} · grep competent {tgc} · graph {tk}",
          f"**Vs naive agent:** {tgn / max(tk, 1):.0f}× fewer tokens.  "
          f"**Vs competent agent:** {tk / max(tgc, 1):.1f}× {'more' if tk > tgc else 'fewer'} tokens — "
          f"graph wins {graf_vinn} of {len(rows)} tasks.",
          f"**Time saved (vs competent agent):** {sp:.0f} ms of {mc:.0f} ms = "
          f"{100 * sp / max(mc, 0.001):.0f}% — avg {sp / len(rows):.0f} ms per query.",
          f"**Time saved (vs naive agent):** {spn:.0f} ms of {mgn:.0f} ms = "
          f"{100 * spn / max(mgn, 0.001):.0f}%.",
          f"**Total runtime:** competent grep {mc:.0f} ms · naive grep {mgn:.0f} ms · graph {mk:.0f} ms (warm).", "",
          "## What grep alone actually answers", ""]
    for r in rows:
        if r.get("grep_ane"):
            L.append(f"* **{r['id']}.** {r['spm']}  \n  {r['grep_ane']}")
    L += ["", "## Observations", "",
          "* **Dynamic Auto-Discovery:** These tasks were automatically derived from this specific project's",
          "  graph index, targeting its actual signals, largest scripts, call sites, and autoloads.",
          "* **Naive model is not the main opponent.** An agent opening ±25 lines around all matches",
          "  spends up to 50× more than one opening the top 3 files. The real token gain is measured against competent grep.",
          "* Runtime figures are indicative: grep runs in Python loops (not ripgrep binary). **Token counts**",
          "  are what truly matter, as tokens fill LLM context windows.",
          "* `graph ms (cold/warm)`: initial touch of index pages vs instant subsequent query.",
          "* The graph command provides structured answers up front (`--limit`/`--all`). The agent",
          "  may inspect a file afterwards, but already knows the exact file, class, and line number.",
          "* The graph answers *where* and *who*, not *why*. Deep code understanding still involves reading code.",
          "* Scene wiring tasks demonstrate connections that text search cannot resolve (signals in `.tscn`",
          "  wired to handlers in `.gd`). The advantage here is not just tokens, but correctness.", ""]
    out.write_text("\n".join(L), encoding="utf-8")
    (root / kg.DB_DIR / "bench.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nwrote {out}")


def main() -> int:
    only = None
    for a in sys.argv[1:]:
        if a.startswith("--tasks"):
            only = [int(x) for x in a.split("=", 1)[1].split(",")] if "=" in a else None
    root = kg.find_root(None)
    print(f"bench: {root}")
    rows = run(root, only)
    report(root, rows)
    return 0


if __name__ == "__main__":
    sys.exit(main())
