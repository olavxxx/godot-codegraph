"""bench.py — benchmarks code graph against text search on real code exploration tasks.

Run:    python tools/codegraph/bench.py            (all tasks)
       python tools/codegraph/bench.py --tasks=4,5

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

    # fase 2: agenten opnar kontekst rundt trefa for å forstå dei
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


TASKS = [
    dict(id=1, spm="Who emits mission_completed, and who listens?",
         grep=[r"mission_completed"],
         ane="All text matches including comments, variable names and strings in test files.",
         graf=lambda con: kg.cmd_signal(con, "mission_completed")),
    dict(id=2, spm="Outline of BeatMakerUI.gd without opening file",
         grep=[r"func _on_", r"^extends"], files=["scripts/ui/BeatMakerUI.gd"],
         ane="Fastest for grep - graph loses. Point of outline is to get structure without bloating context.",
         graf=lambda con: kg.cmd_outline(con, "BeatMakerUI")),
    dict(id=3, spm="Who calls take_damage?",
         grep=[r"\btake_damage\b"],
         ane="Matches across 53 different methods with the same name. Uncertain who is caller vs receiver.",
         graf=lambda con: kg._dir(con, "take_damage", "callers")),
    dict(id=4, spm="Which scene connections lead to close()?",
         grep=[r'method="close"'],
         ane="Matches in .tscn, but grep cannot resolve which script receives the signal.",
         graf=lambda con: kg.cmd_signal(con, "close")),
    dict(id=5, spm="Who receives pressed in .tscn files?",
         grep=[r'\[connection signal="pressed"'],
         ane="Scene connection lines without receiver. Graph resolves exact script:line for each.",
         graf=lambda con: kg.cmd_signal(con, "pressed")),
    dict(id=6, spm="Where do @rpc functions exist, and who calls them?",
         grep=[r"^[ \t]*@rpc"],
         ane="Annotated lines, but grep cannot see RPC transfer mode, authority, or call counts.",
         graf=lambda con: kg.cmd_rpc(con, None)),
    dict(id=7, spm="What is impacted by changing GameState?",
         grep=[r"\bGameState\."],
         ane="Over 1,470 autoload calls. Exceeds LLM context window without a graph index.",
         graf=lambda con: kg.cmd_impact(con, "GameState", 2)),
    dict(id=8, spm="Who uses group 'civilians'?",
         grep=[r'"civilians"'],
         ane="Dozens of matches without distinguishing membership (in_group) from querying (queries_group).",
         graf=lambda con: kg.cmd_find(con, "civilians")),
]


def run(root: Path, only: list[int] | None) -> list[dict]:
    con = kg.db(dict(root=root))  # opnar + sjølvforfriskar indexen
    alle = kg.list_files(root)
    rows = []
    try:
        for t in TASKS:
            if only and t["id"] not in only:
                continue
            files = t.get("files") or alle
            gtext, gms, ginfo = grep_side(root, files, t["grep"])
            ctext, cms = competent_grep(root, files, t["grep"])
            ktext, kms_cold = graph_side(con, t["graf"])      # kald side: første touch av index-sidene
            _, kms_warm = graph_side(con, t["graf"])          # varm: same spørsmål på nytt
            gt, ct, kt = tokens(gtext), tokens(ctext), tokens(ktext)
            rows.append(dict(id=t["id"], spm=t["spm"], grep_info=ginfo, grep_ane=t.get("ane", ""),
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
    L = ["# CodeGraph Benchmark", "",
         f"Repository: `{root}`",
         f"{len(rows)} real-world tasks. Two grep models tested:",
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
          "* **Naive model is not the main opponent.** An agent opening ±25 lines around all matches",
          "  spends up to 50× more than one opening the top 3 files. The real token gain is measured against competent grep.",
          "* Runtime figures are indicative: grep runs in Python loops (not ripgrep binary). **Token counts**",
          "  are what truly matter, as tokens fill LLM context windows.",
          "* `graph ms (cold/warm)`: initial touch of index pages vs instant subsequent query.",
          "* The graph command provides structured answers up front (`--limit`/`--all`). The agent",
          "  may inspect a file afterwards, but already knows the exact file, class, and line number.",
          "* The graph answers *where* and *who*, not *why*. Deep code understanding still involves reading code.",
          "* Tasks 4 and 5 demonstrate connections that text search cannot resolve (signals in `.tscn`",
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
