"""bench.py — målar graf mot grep på riktige utforskingsspørsmål.

Køyr:  python tools/codegraph/bench.py            (alle oppgåver)
       python tools/codegraph/bench.py --tasks=4,5

Kvart spørsmål blir løyst to vegar, og vi tel tid og tekstmengd:
  GREP : regulær søking i filane, pluss det ein agent MÅ opne for å svare
         (= 25 linjer rundt kvart treff, overlapp slått saman)
  GRAF : kg-kommando i same prosess (inkl. sjølvforfrisking av indexen)

Tokenestimat = teikn / 4 (konservativt; GDScript ligg ofte nærare 3, så talet
er ei øvre grense for grep-sida og ei nedre for graf-sida).
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
    """Rimlegaste modellen: agenten grep-ar med fil liste + tal, så opnar han
    berre dei tre tyngste filane rundt første treff. Desse tala er dei som tel —
    naivmodellen overdriv grep-prisen dramatisk."""
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
    out = ["\n".join(f"{rel}:{n}" for rel, (n, _) in hits.items())]        # fas 1: fil liste + tal
    for rel, (n, lines) in sorted(hits.items(), key=lambda kv: -kv[1][0])[:open_files]:
        first = next((i for i, l in enumerate(lines, 1) if pat.search(l)), 1)
        a, b = max(1, first - win), min(len(lines), first + win)
        out.append(f"{rel}:{a}-{b}\n" + "\n".join(lines[a - 1:b]))         # fas 2: opne tre filer
    return "\n".join(out), (time.time() - t0) * 1000


def graph_side(con, fn, *args) -> tuple[str, float]:
    buf = io.StringIO()
    t0 = time.time()
    with redirect_stdout(buf):
        fn(con, *args)
    return buf.getvalue(), (time.time() - t0) * 1000


TASKS = [
    dict(id=1, spm="Kven emitterer mission_completed, og kven lyttar?",
         grep=[r"mission_completed"],
         ane="alle 235 teksttreffa, inkl. kommentarar, eigen variablenamn og strengar i testfilen. "
             "Agenten må lesa 34k token for å sortera emitteringar frå støy.",
         graf=lambda con: kg.cmd_signal(con, "mission_completed")),
    dict(id=2, spm="Kva inneheld BeatMakerUI.gd, utan å opne fila?",
         grep=[r"func _on_", r"^extends"], files=["scripts/ui/BeatMakerUI.gd"],
         ane="raskast her - grafen tapar. Poenget med outline er at svaret kjem utan at fila hamnar i context.",
         graf=lambda con: kg.cmd_outline(con, "BeatMakerUI")),
    dict(id=3, spm="Kven kallar take_damage?",
         grep=[r"\btake_damage\b"],
         ane="76k token av 530 treffa, inkl. 53 ulike methodar med same namn. Usikkert kven som er mottakar.",
         graf=lambda con: kg._dir(con, "take_damage", "callers")),
    dict(id=4, spm="Kva scene-koplingar går til close()?",
         grep=[r'method="close"'],
         ane="3 treffa i .tscn, men GREP FINN IKKJE kva script som tek imot - signalet og handlern "
             "ligg i kvar sin filtype. Dette er svaret grep ikkje gir, uansett kor mykje ein les.",
         graf=lambda con: kg.cmd_signal(con, "close")),
    dict(id=5, spm="Kven tek imot pressed i .tscn-filer?",
         grep=[r'\[connection signal="pressed"'],
         ane="105 koplingsliner utan mottakar. Grafen er større her (alle 105 med fil:linje), men svaret er komplett.",
         graf=lambda con: kg.cmd_signal(con, "pressed")),
    dict(id=6, spm="Kvar finst @rpc, og kven kallar dei?",
         grep=[r"^[ \t]*@rpc"],
         ane="147 annotasjonslinjer, men ikkje kva som er RPC, kva modus dei har, eller kor mange stader "
             "dei blir kalla frå (annotasjonen og func-linja er to ulike liner).",
         graf=lambda con: kg.cmd_rpc(con, None)),
    dict(id=7, spm="Kva blir påverka av å endre GameState?",
         grep=[r"\bGameState\."],
         ane="574k token = heile context-vindauget deira, frå 1 470/autoload-kalla. Ubrukbart som svar.",
         graf=lambda con: kg.cmd_impact(con, "GameState", 2)),
    dict(id=8, spm="Kven brukar gruppa 'civilians'?",
         grep=[r'"civilians"'],
         ane="122 treffa utan skilnad på dei som ER sivilistar og dei som SPØR etter dei.",
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
            print(f"  [{t['id']}] {t['spm'][:40]:42} grep naiv {gt:7} t · dugleg {ct:6} t   "
                  f"graf {kt:6} t   {'GRAF' if kt <= ct else 'GREP'} {r['token_ratio']:5.1f}x")
    finally:
        con.close()
    return rows


def report(root: Path, rows: list[dict]) -> None:
    out = root / kg.DB_DIR / "bench.md"
    L = ["# codegraph-benchmark", "",
         f"Repo: `{root}`",
         f"{len(rows)} oppgaver. To grep-modellar:",
         "",
         "* **grep naive** = regulært søk + åpne ±25 linjer rundt *hvert* treff (det en robot gjør)",
         "* **grep dyktig** = filliste med tall (som `rg -l -c`), så åpne ±25 linjer i de tre tyngste filene",
         "",
         "**De dyktige tallene er de som teller.** Token = tegn/4. `graf ms` er kald/varm.", "",
         "| # | Oppgave | grep naive t | grep dyktig t | dyktig ms | graf ms (kald/varm) | graf token | graf vs dyktig | spart tid |",
         "|---|---|---|---|---|---|---|---|---|"]
    for r in rows:
        vinn = "**graf**" if r["graf_token"] <= r["grep_dugleg_token"] else "**grep**"
        L.append(f"| {r['id']} | {r['spm']} | {r['grep_naiv_token']} | {r['grep_dugleg_token']} | "
                 f"{r['grep_dugleg_ms']} | {r['graf_ms']} / {r.get('graf_ms_varm', r['graf_ms'])} | "
                 f"{r['graf_token']} | {vinn} {r['token_ratio']}× | "
                 f"+{r['spart_ms']} ms ({r['spart_pct']}%) |")
    tgn, tgc, tk = (sum(r["grep_naiv_token"] for r in rows), sum(r["grep_dugleg_token"] for r in rows),
                    sum(r["graf_token"] for r in rows))
    mc, mk = sum(r["grep_dugleg_ms"] for r in rows), sum(r["graf_ms_varm"] for r in rows)
    mgn = sum(r["grep_naiv_ms"] for r in rows)
    graf_vinn = sum(1 for r in rows if r["graf_token"] <= r["grep_dugleg_token"])
    sp = sum(r["spart_ms"] for r in rows)
    spn = sum(r["spart_ms_naiv"] for r in rows)
    L += ["",
          f"**Totalt token:** grep naive {tgn} · grep dyktig {tgc} · graf {tk}",
          f"**Mot naive agent:** {tgn / max(tk, 1):.0f}× færre token.  "
          f"**Mot dyktig agent:** {tk / max(tgc, 1):.1f}× {'flere' if tk > tgc else 'færre'} token — "
          f"grafen vinner {graf_vinn} av {len(rows)} oppgaver.",
          f"**Spart tid (mot dyktig agent):** {sp:.0f} ms av {mc:.0f} ms = "
          f"{100 * sp / max(mc, 0.001):.0f}% — snitt {sp / len(rows):.0f} ms per spørring.",
          f"**Spart tid (mot naive agent):** {spn:.0f} ms av {mgn:.0f} ms = "
          f"{100 * spn / max(mgn, 0.001):.0f}%.",
          f"**Tid totalt:** dyktig grep {mc:.0f} ms · naive grep {mgn:.0f} ms · graf {mk:.0f} ms (varm).", "",
          "## Hva grep åleine faktisk svarer", ""]
    for r in rows:
        if r.get("grep_ane"):
            L.append(f"* **{r['id']}.** {r['spm']}  \n  {r['grep_ane']}")
    L += ["", "## Merknader", "",
          "* **Naiv-modellen er ikkje motstandaren.** Ein agent som opnar ±25 linjer rundt alle 1 470",
          "  treff, brukar 50× meir enn ein som grep-ar med fil liste og opnar tre stader. Grafen sin",
          "  reelle token-gevinst er difor mykje mindre enn naiv-talet, og på somme oppgåver tapar grafen.",
          "* Tidstal er rettleiande: grep-sidene er Python-løkkjer (ikkje ripgrep). Det er **token-tala**",
          "  som betyr noko - det er det som hamnar i context-vindauget.",
          "* `graf ms (kald/varm)`: første touch av index-sidene vs same spørsmål rett etter.",
          "* Graf-sida er eitt kommando med ferdig svar, summert først (`--limit`/`--all`). Agenten",
          "  opnar ofte éi fil etterpå likevel, men veit då allereie kva fil og kva linje.",
          "* Grafen svarar på *kor* og *kven*, ikkje *kvifor*. Forståing krev framleis lesing.",
          "* Oppgåve 4/5 er døme på koplingar grep rett og slett ikkje finn (signal i `.tscn`",
          "  møter handler i `.gd`), uansett kor mykje ein les. Der er ikkje gevinsten token,",
          "  men at svaret finst i det heile.", ""]
    out.write_text("\n".join(L), encoding="utf-8")
    (root / kg.DB_DIR / "bench.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nskrev {out}")


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
