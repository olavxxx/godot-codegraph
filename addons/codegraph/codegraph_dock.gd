@tool
extends Control

# --- Fargepalett fra viewer_template.html (Cyber-Obsidian) ---
const C_BG = Color("#070b10")
const C_PANEL = Color("#0d141d")
const C_PANEL2 = Color("#101a25")
const C_LINE = Color("#1d2b3a")
const C_INK = Color("#cfe3f5")
const C_DIM = Color("#6d8296")
const C_HOT = Color("#ffd166")
const C_ACC = Color("#4fb3ff")
const C_OK = Color("#8ce56c")
const C_BAD = Color("#ff7a6b")  # noko manglar eller er øydelagt
const C_TRACK = Color("#26384a")   # resten av skalaen i søylene

# Søylene i chartet teiknar vi med eitt og det same blokkteiknet. Godot sin
# standardfont har breidde = fontstorleik på █ (16 px @ 16), men berre 5 px på
# · og mellomrom - difor tåler ikkje rutenettet å blande teikn i ei søyle.
const BENCH_FS = 14
const BAR_MIN = 8
const BAR_MAX = 60

const REPO_URL = "https://github.com/olavxxx/godot-codegraph"
const PY_URL = "https://www.python.org/downloads/"
const PY_MIN = 10          # Python 3.10 - backenden krev dette
const UI_PREFS_PATH = "res://.codegraph/ui.json"
const SMALL_PROJECT_LIMIT = 25

# Kind-farger matchet nøyaktig med graph.py & HTML-visningen
const KIND_COLORS = {
	"class": "#8ce56c",
	"fn": "#c792ea",
	"signal": "#ff6b81",
	"autoload": "#ffd166",
	"group": "#ef767a",
	"var": "#7f8fa6",
	"const": "#a3b18a",
	"scene": "#ffb347",
	"file": "#5f6b7a",
	"shader": "#66d9b1"
}

# Bokmål-oversettelse av oppgavene i benchmarken
const TASK_NAMES_NO = {
	1: "Hvem emitterer mission_completed, og hvem lytter?",
	2: "Filoversikt over BeatMakerUI.gd uten å åpne filen",
	3: "Hvem kaller take_damage?",
	4: "Hvilke scenetilkoblinger går til close()?",
	5: "Hvem mottar pressed i .tscn-filer?",
	6: "Hvor finnes @rpc-funksjoner, og hvem kaller dem?",
	7: "Hva påvirkes av å endre GameState?",
	8: "Hvem bruker 'civilians'-gruppen?"
}

# --- Lokalisering (i18n): Engelsk (standard) & Norsk (Bokmål) ---
const STRINGS = {
	"en": {
		"tab_search": "🔍 Search & Explore",
		"tab_bench": "📊 Benchmark & Charts",
		"mode_find": "Find symbol (find)",
		"mode_outline": "Outline file/class (outline)",
		"mode_callers": "Who calls (callers)",
		"mode_signal": "Signal tracing (signal)",
		"mode_rpc": "Network calls (@rpc)",
		"mode_impact": "Impact analysis (impact)",
		"mode_deps": "Dependencies (deps)",
		"mode_status": "Status & counts (status)",
		"hint_find": "Search for function, signal, class, variable...",
		"hint_outline": "Script, class, or autoload name...",
		"hint_callers": "Target method name being called...",
		"hint_signal": "Signal name...",
		"hint_rpc": "Optional filter for RPC functions...",
		"hint_impact": "Symbol or class to inspect impact of...",
		"hint_deps": "File path to trace dependencies...",
		"hint_status": "Click Search for status",
		"btn_search": "Search",
		"btn_visual_graph": "🌐 Web Graph",
		"btn_reindex": "🔄 Reindex",
		"btn_run_bench": "▶ Run Project Benchmark",
		"btn_open_json": "📄 Open bench.json",
		"tab_graph": "🌐 Visual Graph",
		"graph_header": "Interactive 2.5D Obsidian Web Graph",
		"card_files_title": "📁 Files & Architecture Graph",
		"card_files_desc": "Visualizes script dependencies, class inheritance, scenes, and autoload hubs aggregated to the file level.",
		"btn_open_files": "▶ Open Architecture Graph (Browser)",
		"card_signals_title": "⚡ Signal & Scene Wiring Graph",
		"card_signals_desc": "Maps every custom signal, emitter, listener, and .tscn scene connection across the entire game.",
		"btn_open_signals": "▶ Open Signal Graph (Browser)",
		"card_ego_title": "🎯 Neighborhood / Ego Graph",
		"card_ego_desc": "Focuses on a specific class, autoload, or symbol and maps its direct connections up to chosen depth.",
		"ego_input_ph": "Symbol name (e.g. Player, GameState)...",
		"depth": "Depth:",
		"btn_open_ego": "▶ Open Neighborhood (Browser)",
		"graph_tips": "💡 Browser Shortcuts: / to search, F to fit, L for labels, Drag to pan, Scroll to zoom, Click node for inspector.",
		"welcome_title": "Welcome to CodeGraph",
		"welcome_desc": "Your project has not been indexed yet. Initial indexing takes only a few seconds and enables instant symbol navigation, scene signal wires, and @rpc mapping.",
		"btn_index_now": "⚡ Build Initial Index",
		"agent_teach": "Teach my AI agents about CodeGraph",
		"agent_teach_short": "Teach agents",
		"agent_teach_tip": "Writes or updates a marked CodeGraph block in AGENTS.md so AI agents in this repo use kg instead of repeated grep. Never touches text outside the markers. Undo: kg agents --remove",
		"btn_teach_installed": "✓ Agent instructions installed — click to refresh",
		"agents_on": "Agent instructions written to AGENTS.md — commit that file.",
		"agents_off": "Agent instructions removed from AGENTS.md.",
		"agents_fail": "Could not update the agent instructions:",
		"ready": "CodeGraph ready. Select a mode and search.",
		"indexing": "Indexing in progress...",
		"bench_running": "Running real-world benchmark against grep...",
		"done_ms": "Completed in %d ms (exit %d)",
		"err_python": "Warning: Python 3 was not found in PATH.",
		"python_install": "Install Python 3.10+ (https://www.python.org/downloads/) and tick \"Add python.exe to PATH\", then restart Godot.",
		"graph_generating": "Generating interactive graph in a background thread...",
		"enter_term": "Please enter a search term.",
		"bench_empty_project": "Project needs at least 2 GDScript files to run a benchmark suite.",
		"bench_title": "═══ BENCHMARK RESULTS & CHARTS ═══",
		"bench_saved": "Saved automatically to:",
		"bench_time": "⚡ TIME SAVED",
		"bench_time_sub": "%d%% faster",
		"bench_time_detail": "%.1f ms vs %.1f ms",
		"bench_tokens": "🪙 TOKENS SAVED",
		"bench_tokens_sub": "%d%% fewer",
		"bench_tokens_detail": "%d vs %d tokens",
		"bench_won": "🏆 QUALITY / WON",
		"bench_won_sub": "%d of %d tasks",
		"bench_won_detail": "Precise cross-references",
		"bench_grep": "Grep (competent)",
		"bench_kg": "CodeGraph",
		"bench_extra": "extra cost of grep",
		"bench_track": "rest of the scale",
		"bench_scale": "same scale for every task",
		"bench_values": "numbers: grep → CodeGraph",
		"bench_m_tokens": "tokens",
		"bench_m_time": "time",
		"bench_x_fewer": "×%.1f fewer",
		"bench_x_more": "×%.1f more",
		"bench_x_faster": "×%.0f faster",
		"bench_x_slower": "×%.0f slower",
		"bench_total": "TOTAL",
		"bench_total_note": "sum, own scale",
		"tab_agents": "🤖 Agents & Info",
		"agents_header": "AI agents, license and links",
		"agents_card_title": "🤖 Teach my AI agents about CodeGraph",
		"agents_help": "AI agents working in this repo cannot see the plugin. Switch this on and CodeGraph writes a short instruction block into [b]AGENTS.md[/b] that tells them to query [b]kg[/b] before grepping or re-reading whole files. [i]Only the text between the generated markers is written[/i] — your own notes in the file are never touched, and the file is created if it is missing.",
		"agents_written": "[b]Written when you switch it on:[/b] a marked CodeGraph block in AGENTS.md, plus the pointer files CLAUDE.md, .github/copilot-instructions.md and .cursor/rules/codegraph.mdc. These files are meant to be committed. Undo: untick here, or run [b]kg agents --remove[/b].",
		"scripts_count": "This project: %d GDScript file(s) outside addons.",
		"agents_small_warn": "⚠️ Small project? Run the benchmark [i]before[/i] you switch this on. With only a handful of scripts, plain search is already near instant, while the instructions cost context tokens on every agent run. Measure first — the button below runs the test on this project.",
		"agents_big_hint": "This project is big enough that the gain is usually obvious. Run the benchmark to see the real numbers on your machine.",
		"agents_state_on": "✓ Installed — AGENTS.md updated. Commit that file.",
		"agents_state_off": "Not installed — AGENTS.md left as it is.",
		"btn_bench_from_agents": "▶ Run the benchmark first",
		"about_title": "ℹ️ License, source and feedback",
		"about_text": "[b]CodeGraph %s[/b] — released under the [b]MIT License[/b]: free to use, modify and ship in commercial games.\nNeeds Godot 4.4+ and Python 3.10+ on PATH. Source: [url=" + REPO_URL + "][color=#4fb3ff]github.com/olavxxx/godot-codegraph[/color][/url]\n[i]Found a bug, or missing something? Open an issue on GitHub — wishes are very welcome.[/i]",
		"btn_repo": "🌐 GitHub repository",
		"btn_issues": "🐙 Report an issue / wish",
		"py_title": "⚙️ Machine requirements and updates",
		"py_help": "The indexer runs with Python from your own machine. Godot 4.4+ and Python 3.10+ is all that is needed - nothing is installed inside the game project and no packages are downloaded. GitHub is asked for a newer plugin at most once a day, and nothing is written until you say so.",
		"py_head_ok": "✓ Python %s",
		"py_head_missing": "✗ No Python found",
		"py_head_old": "⚠ Python %s too old",
		"py_head_broken": "⚠ Python did not run",
		"py_ok_line": "[color=#8ce56c]✓[/color] [b]Python answers and is ready to index.[/b]",
		"py_missing": "[color=#ff7a6b]✗[/color] [b]No working Python found on this machine.[/b] Index, search and benchmark stay switched off until it answers.",
		"py_missing_note": "The plugin asks for [b]python[/b], [b]python3[/b] and [b]py[/b] through PATH - the same lookup a launcher does on Windows, macOS and Linux alike, so neither [i]where[/i] nor [i]which[/i] is needed.",
		"py_too_old": "[color=#ffc857]⚠[/color] [b]Python %s is too old[/b] - CodeGraph needs 3.10 or newer.",
		"py_not_working": "[color=#ff7a6b]✗[/color] [b]A Python command was found, but it did not run.[/b] On Windows this is usually the Microsoft Store stub that only opens the Store - install real Python and tick \"Add python.exe to PATH\".",
		"k_py_ver": "Python version",
		"k_py_cmd": "Command tried",
		"k_py_exe": "Executable",
		"k_godot": "Godot",
		"k_plugin": "Plugin",
		"py_none": "not found",
		"btn_python_dl": "🐍 Download Python",
		"btn_py_copy": "📋 Copy install command",
		"py_copied": "Install command copied to the clipboard: [b]%s[/b]",
		"expand_more": "▸ Show details",
		"expand_less": "▾ Hide details",
		"py_install_windows": "[b]Windows:[/b] winget install Python.Python.3.12  –  or python.org/downloads",
		"py_install_macos": "[b]macOS:[/b] brew install python  –  or python.org/downloads",
		"py_install_linux": "[b]Linux:[/b] sudo apt install python3  –  or the package for your distro",
		"py_install_other": "Get Python from python.org/downloads and make sure it is on PATH.",
		"btn_py_check": "🔁 Check Python again",
		"upd_head_ok": "✓ latest",
		"upd_head_new": "⚠ %s out",
			"upd_head_never": "– update not checked",
		"upd_head_err": "⚠ cannot check",
		"upd_head_none": "– no releases yet",
		"upd_no_release": "The repo has no [b]version.json[/b] in main and no tag yet, so there is no published version to compare with. Nothing is wrong - updates light up once the project publishes one.",
		"upd_checking": "… checking GitHub",
		"k_upd_latest": "Newest release",
		"k_upd_checked": "Last checked",
		"upd_never": "never",
		"btn_upd_check": "🔍 Check for update",
		"btn_upd_apply": "⬇ Update to %s",
		"btn_upd_confirm": "⬇ Press again to install",
		"upd_head_applying": "⏳ installing",
		"btn_upd_busy": "⏳ Installing %s",
		"upd_installing": "[b]Installing %s.[/b] Downloading the GitHub archive and writing [b]addons/codegraph/[/b] - the backup and [b]restore.bat[/b] are made [i]outside[/i] the project first. Keep the editor open, and do not press again while it works.",
		"upd_apply_failed": "Could not install %s: %s The plugin itself was not touched - the backup and the undo script are outside the project.",
		"upd_exit_code": "kg update --apply stopped with exit code %d",
		"upd_up_to_date": "Already on the newest version (%s). Nothing was changed.",
		"upd_found": "[b]%s[/b] is out. Nothing is written until you press the update button - and a backup plus a [b]restore.bat[/b] are made [i]outside[/i] the project first.",
		"upd_applied": "[b]Installed %s.[/b] Reload the project in Godot now: Project → Reload Current Project.\n[dim]Backup and undo script:[/dim] %s",
		"upd_failed": "Could not read the version: %s The plugin itself was not touched.",
		"upd_agent_note": "[i]AI agents may run [b]kg update[/b] (read-only), but must ask you before running [b]kg update --apply[/b].[/i]",
		"giti_ok": "✓ [b].gitignore[/b] hides what must not be committed (%s) - the index and cache stay on your machine.",
		"giti_missing": "⚠ [b].gitignore[/b] has no rule for [b]%s[/b], so this folder can end up in git: the index, the cache and the update state are per-machine files and should not be committed. (The agent files AGENTS.md, CLAUDE.md and friends [i]are[/i] meant to be committed.)",
		"giti_no_file": "⚠ The project has no [b].gitignore[/b] at all, so nothing hides [b]%s[/b] from git.",
		"btn_giti_fix": "🛠 Add to .gitignore",
		"giti_fixed": "Added [b]%s[/b] to [b].gitignore[/b]. Nothing else in the file was touched.",
		"giti_failed": "Could not write [b].gitignore[/b]: %s",
		"giti_noneed": "Nothing was missing - [b].gitignore[/b] already covers it.",
		"badge_hint": "%s things to look at here: Python status, a newer plugin version and .gitignore. Click to open.",
	},
	"no": {
		"tab_search": "🔍 Søk & Utforsk",
		"tab_bench": "📊 Ytelsestest & Diagram",
		"mode_find": "Finn symbol (find)",
		"mode_outline": "Oversikt (outline)",
		"mode_callers": "Hvem kaller (callers)",
		"mode_signal": "Signalsporing (signal)",
		"mode_rpc": "Nettverkskall (@rpc)",
		"mode_impact": "Konsekvensanalyse (impact)",
		"mode_deps": "Avhengigheter (deps)",
		"mode_status": "Status & tellere (status)",
		"hint_find": "Søk etter funksjon, signal, klasse eller variabel...",
		"hint_outline": "Navn på script, klasse eller autoload...",
		"hint_callers": "Navn på funksjon som kalles...",
		"hint_signal": "Navn på signal...",
		"hint_rpc": "Valgfritt filter for RPC-funksjoner...",
		"hint_impact": "Symbol eller klasse du vil undersøke...",
		"hint_deps": "Filsti for å se avhengigheter...",
		"hint_status": "Klikk Søk for status",
		"btn_search": "Søk",
		"btn_visual_graph": "🌐 Nett-graf",
		"btn_reindex": "🔄 Reindekser",
		"btn_run_bench": "▶ Kjør ytelsestest på dette prosjektet",
		"btn_open_json": "📄 Åpne bench.json",
		"tab_graph": "🌐 Visuell Graf",
		"graph_header": "Interaktiv 2.5D Obsidian Web-graf",
		"card_files_title": "📁 Filer & Arkitektur-graf",
		"card_files_desc": "Viser skriptavhengigheter, klassearv, scener og autoload-knutepunkter aggregert på filnivå.",
		"btn_open_files": "▶ Åpne Arkitektur-graf (Nettleser)",
		"card_signals_title": "⚡ Signal- & Scenetilkoblings-graf",
		"card_signals_desc": "Full oversikt over alle signaler, sendere, lyttere og .tscn-tilkoblinger i hele spillet.",
		"btn_open_signals": "▶ Åpne Signal-graf (Nettleser)",
		"card_ego_title": "🎯 Nabolags- / Ego-graf",
		"card_ego_desc": "Fokuserer på en bestemt klasse, autoload eller symbol og kartlegger koblinger i valgt dybde.",
		"ego_input_ph": "Symbolnavn (f.eks. Player, GameState)...",
		"depth": "Dybde:",
		"btn_open_ego": "▶ Åpne Nabolags-graf (Nettleser)",
		"graph_tips": "💡 Hurtigtaster i nettleseren: / for søk, F for tilpass, L for etiketter, Dra for å panorere, Rull for å zoome, Klikk på node for inspektør.",
		"welcome_title": "Velkommen til CodeGraph",
		"welcome_desc": "Dette prosjektet er ikke indeksert ennå. Første indeksering tar bare noen sekunder og gir deg lynrask kode- og signalnavigasjon.",
		"btn_index_now": "⚡ Bygg indeks nå",
		"agent_teach": "Lær AI-agentane mine om CodeGraph",
		"agent_teach_short": "Lær agentar",
		"agent_teach_tip": "Skriver eller oppdaterar ein merkt CodeGraph-blokk i AGENTS.md, slik at AI-agentar i prosjektet brukar kg i staden for gjentekne grep. Rører aldri tekst utanfor merka. Angre: kg agents --remove",
		"btn_teach_installed": "✓ Agentinstruksjonar installert — klikk for å oppdatere",
		"agents_on": "Agentinstruksjonar skrivne i AGENTS.md — committ fila.",
		"agents_off": "Agentinstruksjonar fjerna frå AGENTS.md.",
		"agents_fail": "Klarte ikkje å oppdatere agentinstruksjonane:",
		"ready": "CodeGraph klar. Velg modus og skriv inn søkeord.",
		"indexing": "Indekserer prosjektet...",
		"bench_running": "Kjører ytelsestest mot grep...",
		"done_ms": "Ferdig på %d ms (exit %d)",
		"err_python": "Advarsel: Python 3 ble ikke funnet i PATH.",
		"python_install": "Installer Python 3.10+ (https://www.python.org/downloads/) og huk av for «Add python.exe to PATH», start så Godot på nytt.",
		"graph_generating": "Genererer interaktiv graf i ein bakgrunnstråd...",
		"enter_term": "Vennligst oppgi et søkeord.",
		"bench_empty_project": "Prosjektet må ha minst 2 GDScript-filer for å kjøre en ytelsestest.",
		"bench_title": "═══ BENCHMARK-RESULTATER & DIAGRAM ═══",
		"bench_saved": "Lagret automatisk til:",
		"bench_time": "⚡ SPART TID",
		"bench_time_sub": "%d%% raskere",
		"bench_time_detail": "%.1f ms mot %.1f ms",
		"bench_tokens": "🪙 SPARTE TOKENS",
		"bench_tokens_sub": "%d%% færre",
		"bench_tokens_detail": "%d mot %d tokens",
		"bench_won": "🏆 KVALITET / VUNNET",
		"bench_won_sub": "%d av %d oppgaver",
		"bench_won_detail": "Presise referanser",
		"bench_grep": "Grep (dyktig)",
		"bench_kg": "CodeGraph",
		"bench_extra": "det grep kosta i tillegg",
		"bench_track": "resten av skalaen",
		"bench_scale": "samme skala for alle oppgåver",
		"bench_values": "tala: grep → CodeGraph",
		"bench_m_tokens": "tokens",
		"bench_m_time": "tid",
		"bench_x_fewer": "×%.1f færre",
		"bench_x_more": "×%.1f fleire",
		"bench_x_faster": "×%.0f raskare",
		"bench_x_slower": "×%.0f saktare",
		"bench_total": "TOTALT",
		"bench_total_note": "sum, eigen skala",
		"tab_agents": "🤖 Agentar & Info",
		"agents_header": "AI-agentar, lisens og lenkjer",
		"agents_card_title": "🤖 Lær AI-agentane mine om CodeGraph",
		"agents_help": "AI-agentar som jobbar i dette prosjektet ser ikkje pluginen. Slår du dette på, skriv CodeGraph ein kort instruksjonsblokk i [b]AGENTS.md[/b] som seier frå om å slå opp i [b]kg[/b] før det grepast eller lesast heile filer. [i]Berre teksten mellom dei genererte merka blir skriven[/i] — eigne notat i fila blir ikkje rørte, og fila blir oppretta om ho manglar.",
		"agents_written": "[b]Dette blir skrive når du slår på:[/b] ein merkt CodeGraph-blokk i AGENTS.md, pluss peikefilene CLAUDE.md, .github/copilot-instructions.md og .cursor/rules/codegraph.mdc. Desse filene skal committast. Angre: fjern haken her, eller køyr [b]kg agents --remove[/b].",
		"scripts_count": "Dette prosjektet: %d GDScript-filer utanfor addons.",
		"agents_small_warn": "⚠️ Lite prosjekt? Kør ytelsestesten [i]før[/i] du slår dette på. Med berre nokre få script er vanleg søk alt nesten umiddelbart, medan instruksjonane kostar context-tokens kvm. agentkøyring. Mål først — knappen under køyrer testen på dette prosjektet.",
		"agents_big_hint": "Prosjektet er stort nok til at gevinsten vanlegvis er tydeleg. Kør ytelsestesten for å sjå tala på din maskin.",
		"agents_state_on": "✓ Installert — AGENTS.md oppdatert. Committ fila.",
		"agents_state_off": "Ikkje installert — AGENTS.md er urørt.",
		"btn_bench_from_agents": "▶ Kjør ytelsestesten først",
		"about_title": "ℹ️ Lisens, kjeldekode og tilbakemelding",
		"about_text": "[b]CodeGraph %s[/b] — lisensiert under [b]MIT-lisensen[/b]: gratis å bruke, endre og sende ut i kommersielle spel.\nKrev Godot 4.4+ og Python 3.10+ i PATH. Kjeldekode: [url=" + REPO_URL + "][color=#4fb3ff]github.com/olavxxx/godot-codegraph[/color][/url]\n[i]Fann du ein feil, eller saknar du noko? Opne ei sak på GitHub — ønskje er velkomne.[/i]",
		"btn_repo": "🌐 GitHub-repo",
		"btn_issues": "🐙 Meld ei sak / ønskje",
		"py_title": "⚙️ Krav til maskina og oppdateringar",
		"py_help": "Indexeraren køyrer med Python frå maskina di. Godot 4.4+ og Python 3.10+ er alt som trengst - ingenting blir installert i spelprosjektet, og ingen pakker blir henta ned. GitHub blir spurdd om nyare plugin høgst éin gong i døgnet, og ingenting blir skrive før du seier til.",
		"py_head_ok": "✓ Python %s",
		"py_head_missing": "✗ Fann inga Python",
		"py_head_old": "⚠ Python %s for gammal",
		"py_head_broken": "⚠ Python køyrde ikkje",
		"py_ok_line": "[color=#8ce56c]✓[/color] [b]Python svarar, klar til å indexere.[/b]",
		"py_missing": "[color=#ff7a6b]✗[/color] [b]Fann ingen fungerande Python på denne maskina.[/b] Index, søk og ytelsestest held seg slått av til ho svarar.",
		"py_missing_note": "Pluginen spør etter [b]python[/b], [b]python3[/b] og [b]py[/b] via PATH - same oppslaget ein launcher gjer på Windows, macOS og Linux, så verken [i]where[/i] eller [i]which[/i] trengst.",
		"py_too_old": "[color=#ffc857]⚠[/color] [b]Python %s er for gammal[/b] - CodeGraph treng 3.10 eller nyare.",
		"py_not_working": "[color=#ff7a6b]✗[/color] [b]Ei Python-kommando vart funnen, men ho køyrde ikkje.[/b] På Windows er dette ofte Microsoft Store-aliaset som berre opnar butikken - installer skikkeleg Python og huk av for \"Add python.exe to PATH\".",
		"k_py_ver": "Python-versjon",
		"k_py_cmd": "Kommando prøvd",
		"k_py_exe": "Køyrbar fil",
		"k_godot": "Godot",
		"k_plugin": "Plugin",
		"py_none": "fannst ikkje",
		"btn_python_dl": "🐍 Last ned Python",
		"btn_py_copy": "📋 Kopier installeringskommando",
		"py_copied": "Installeringskommando kopiert til utklippstavla: [b]%s[/b]",
		"expand_more": "▸ Sjå meir",
		"expand_less": "▾ Sjå mindre",
		"py_install_windows": "[b]Windows:[/b] winget install Python.Python.3.12  –  eller python.org/downloads",
		"py_install_macos": "[b]macOS:[/b] brew install python  –  eller python.org/downloads",
		"py_install_linux": "[b]Linux:[/b] sudo apt install python3  –  eller pakken for distribusjonen din",
		"py_install_other": "Hent Python frå python.org/downloads og passe på at han ligg på PATH.",
		"btn_py_check": "🔁 Sjekk Python på nytt",
		"upd_head_ok": "✓ nyaste",
		"upd_head_new": "⚠ %s finst",
		"upd_head_never": "– updatesjekk ikkje køyrd",
		"upd_head_err": "⚠ kunne ikkje sjekke",
		"upd_head_none": "– ingen utgjevingar enno",
		"upd_no_release": "Repoen har korkje [b]version.json[/b] i main ennå nokon tag, så det finst inga publisert versjon å samanlikne med. Det er ikkje noko galt - oppdatering lyser når prosjektet gjer ei utgjeving.",
		"upd_checking": "… søkjer på GitHub",
		"k_upd_latest": "Nyaste versjon",
		"k_upd_checked": "Sjekka sist",
		"upd_never": "aldri",
		"btn_upd_check": "🔍 Sjekk for oppdatering",
		"btn_upd_apply": "⬇ Oppdater til %s",
		"btn_upd_confirm": "⬇ Trykk igjen for å installere",
		"upd_head_applying": "⏳ installerer",
		"btn_upd_busy": "⏳ Installerer %s",
		"upd_installing": "[b]Installerer %s.[/b] Lastar ned GitHub-arkivet og skriv [b]addons/codegraph/[/b] - backup og [b]restore.bat[/b] blir laga [i]utanfor[/i] prosjektet først. Hald editoren open, og ikkje trykk ein gong til medan han jobbar.",
		"upd_apply_failed": "Kunne ikkje installere %s: %s Sjølve pluginen blei ikkje rør - backup og angra-skript ligg utanfor prosjektet.",
		"upd_exit_code": "kg update --apply stoppa med exit-kode %d",
		"upd_up_to_date": "Allereie nyaste versjon (%s). Ingenting blei endra.",
		"upd_found": "[b]%s[/b] finst. Ingenting blir skrive før du trykkjer på oppdater-knappen - og backup pluss [b]restore.bat[/b] blir laga [i]utanfor[/i] prosjektet først.",
		"upd_applied": "[b]Installerte %s.[/b] Last prosjektet på nytt i Godot no: Prosjekt → Last inn noverande prosjekt på nytt.\n[dim]Backup og angra-skript:[/dim] %s",
		"upd_failed": "Kunne ikkje lese versjon: %s Sjølve pluginen blei ikkje rør.",
		"upd_agent_note": "[i]AI-agentar må køyrje [b]kg update[/b] (berre lesing), men må spørje deg før [b]kg update --apply[/b].[/i]",
		"giti_ok": "✓ [b].gitignore[/b] skjuler det som ikkje skal committast (%s) - index og cache blir verande på maskina di.",
		"giti_missing": "⚠ [b].gitignore[/b] har ikkje regel for [b]%s[/b], så denne mappa kan hamne i git: index og cache er filer per maskin og bør ikkje committast. (Agentfilene AGENTS.md, CLAUDE.md osb. er [i]mente[/i] å committast.)",
		"giti_no_file": "⚠ Prosjektet har heilt korkje [b].gitignore[/b], så ingenting skjuler [b]%s[/b] for git.",
		"btn_giti_fix": "🛠 Legg til i .gitignore",
		"giti_fixed": "La [b]%s[/b] i [b].gitignore[/b]. Ingenting anna i fila blei rør.",
		"giti_failed": "Kunne ikkje skrive [b].gitignore[/b]: %s",
		"giti_noneed": "Mangla ingenting - [b].gitignore[/b] dekkjer det alt.",
		"badge_hint": "%s ting å sjå på her: Python-status, ny pluginversjon og .gitignore. Trykk for å opne.",
	}
}

var lang: String = "en"

# UI Referanser
@onready var main_tabs: TabContainer = %MainTabs
@onready var welcome_panel: PanelContainer = %WelcomePanel
@onready var welcome_title: Label = %WelcomeTitle
@onready var welcome_desc: Label = %WelcomeDesc
@onready var index_now_button: Button = %IndexNowButton
@onready var welcome_progress: ProgressBar = %WelcomeProgress
@onready var welcome_status: Label = %WelcomeStatus
@onready var agent_teach: CheckButton = %AgentTeach
@onready var teach_agents_button: Button = %TeachAgentsButton

# Søkefane
@onready var search_input: LineEdit = %SearchInput
@onready var mode_option: OptionButton = %ModeOption
@onready var search_button: Button = %SearchButton
@onready var html_button: Button = %HtmlButton
@onready var reindex_button: Button = %ReindexButton
@onready var lang_button: Button = %LangButton
@onready var status_label: Label = %StatusLabel
@onready var output_display: RichTextLabel = %OutputDisplay
@onready var autocomplete_box: PanelContainer = %AutocompleteBox
@onready var autocomplete_list: ItemList = %AutocompleteList

# Delstat per tekstfelt: autocomplete blir brukt av både søkjefeltet og
# nabolagsfeltet, så sist skriven tekst og «settekst sjølv» må skil lag per felt.
var _acc_state: Dictionary = {}   # LineEdit -> sist skrevne tekst (backspace-sjekk)
var _acc_busy: Dictionary = {}    # LineEdit -> programmet endra feltet sjølv no
@onready var search_progress: ProgressBar = %SearchProgress

# Benchmarkfane
@onready var bench_button: Button = %BenchButton
@onready var open_json_button: Button = %OpenJsonButton
@onready var bench_lang_button: Button = %BenchLangButton
@onready var bench_status: Label = %BenchStatus
@onready var bench_display: RichTextLabel = %BenchDisplay
@onready var bench_progress: ProgressBar = %BenchProgress

var _bench_raw: String = ""   # rå bench.json: chartet blir renderast på nytt
var _bench_bar_w: int = 0     # når tilgjengeleg breidde endrar seg
var _bench_rendering: bool = false
var _bench_resize_timer: Timer = null

# Web Graph fane
@onready var graph_tab: VBoxContainer = %GraphTab
@onready var graph_title_label: Label = %GraphTitleLabel
@onready var graph_lang_button: Button = %GraphLangButton
@onready var card_files_title: Label = %CardFilesTitle
@onready var card_files_desc: Label = %CardFilesDesc
@onready var open_files_button: Button = %OpenFilesButton
@onready var card_signals_title: Label = %CardSignalsTitle
@onready var card_signals_desc: Label = %CardSignalsDesc
@onready var open_signals_button: Button = %OpenSignalsButton
@onready var card_ego_title: Label = %CardEgoTitle
@onready var card_ego_desc: Label = %CardEgoDesc
@onready var ego_input: LineEdit = %EgoInput
@onready var ego_depth_label: Label = %EgoDepthLabel
@onready var ego_depth_option: OptionButton = %EgoDepthOption
@onready var open_ego_button: Button = %OpenEgoButton
@onready var ego_acc_box: PanelContainer = %EgoAccBox
@onready var ego_acc_list: ItemList = %EgoAccList
@onready var tips_label: Label = %TipsLabel

# Agentfane (meir plass til hjelpetekst enn toggle-knappen i søkefeltet)
@onready var agents_title_label: Label = %AgentsTitleLabel
@onready var agents_lang_button: Button = %AgentsLangButton
@onready var agents_card_title: Label = %TeachCardTitle
@onready var agents_toggle: CheckButton = %AgentsTeach
@onready var agents_state_label: Label = %TeachStateLabel
@onready var agents_help: RichTextLabel = %TeachHelp
@onready var agents_size_label: Label = %TeachSizeLabel
@onready var agents_warn_label: RichTextLabel = %TeachWarn
@onready var agents_written_label: RichTextLabel = %TeachFilesLabel
@onready var bench_from_agents_button: Button = %BenchFromAgentsButton
@onready var about_title: Label = %AboutTitle
@onready var about_text: RichTextLabel = %AboutText
@onready var repo_button: Button = %RepoButton
@onready var issues_button: Button = %IssuesButton
@onready var py_card_title: Label = %PyCardTitle
@onready var py_help: RichTextLabel = %PyHelp
@onready var py_status: RichTextLabel = %PyStatus
@onready var py_install_hint: RichTextLabel = %PyInstallHint
@onready var py_check_button: Button = %PyCheckButton
# Ut pakket / pakka saman - tilstand + knappar
@onready var teach_expand_button: Button = %TeachExpandBtn
@onready var py_head_row: HBoxContainer = %PyHeadRow
@onready var py_summary: RichTextLabel = %PySummary
@onready var py_expand_button: Button = %PyExpandBtn
@onready var py_actions_row: HBoxContainer = %PyActions
@onready var py_download_button: Button = %PyDownloadButton
@onready var py_copy_button: Button = %PyCopyButton
@onready var py_copy_row: HBoxContainer = %PyCopyRow
# Oppdateringsdel av same kort
@onready var upd_chip: RichTextLabel = %UpdChip
@onready var upd_status: RichTextLabel = %UpdStatus
@onready var upd_agent_note: RichTextLabel = %UpdAgentNote
@onready var upd_actions: HBoxContainer = %UpdActions
@onready var upd_check_button: Button = %UpdCheckButton
@onready var upd_apply_button: Button = %UpdApplyButton
@onready var lbl_upd: Label = %PyKUpd
@onready var val_upd: Label = %PyVUpd
@onready var lbl_checked: Label = %PyKChecked
@onready var val_checked: Label = %PyVChecked
# .gitignore-del
@onready var giti_status: RichTextLabel = %GitiStatus
@onready var giti_fix_row: HBoxContainer = %GitiFixRow
@onready var giti_fix_button: Button = %GitiFixButton
# Tabelloversikta over maskina: dim merkelapp + verdi med same kolonner
@onready var py_table: GridContainer = %PyTable
@onready var lbl_py_ver: Label = %PyKVer
@onready var val_py_ver: Label = %PyVVer
@onready var lbl_py_cmd: Label = %PyKCmd
@onready var val_py_cmd: Label = %PyVCmd
@onready var lbl_py_exe: Label = %PyKExe
@onready var val_py_exe: Label = %PyVExe
@onready var lbl_godot: Label = %PyKGodot
@onready var val_godot: Label = %PyVGodot
@onready var lbl_plugin: Label = %PyKPlugin
@onready var val_plugin: Label = %PyVPlugin

# Kva noder som høyrest til kva kort, så `_set_card_open()` berre treng éin liste.
const CARD_BODY = {
	"py": ["py_help", "py_table", "py_status", "py_install_hint", "py_copy_row", "py_actions_row",
		"giti_status", "giti_fix_row", "upd_status", "upd_agent_note", "upd_actions"],
	"teach": ["agents_help", "agents_written_label"],
}
var _card_open: Dictionary = {}     # noverande tilstand per kort
var _card_pinned: Dictionary = {}   # brukaren har valt dette sjølv
var _ui_prefs: Dictionary = {}
var _py_copy_timer: Timer = null

# Oppdateringskontroll: backenden (kg update) gjer nettverksarbeidet i ein tråd,
# og skriv sjølv svaret til .codegraph/update.json - då treng vi ikkje dele
# data på tvers av trådar, og agenten kan lese nøyaktig same fil.
var update_state: Dictionary = {}
var update_thread: Thread = null
var upd_timer: Timer = null
var upd_apply_armed: bool = false
var upd_arm_timer: Timer = null
var upd_busy_text: String = ""
var upd_applying: bool = false   # éin installasjon om gongen - elles kan knappen spammast
var upd_spin: int = 0            # teljar for spinneren i knappeksten medan jobben går
var upd_fail_note: String = ""   # siste installasjonsfeil, visast til noko nytt blir forsøkt
var update_exit: int = 0         # exit-koden til siste kg-ting i tråden
var update_out: Array = []       # stdout/nedre del av feilmelding, berre lesen etter wait_to_finish
const SPIN_FRAMES = ["|", "/", "-", "\\"]
const UPDATE_STATE_PATH = "res://.codegraph/update.json"   # same fil som kg update skriv
const CHECK_TTL_H = 20.0     # editoren startar ofte - éin nettverkssjekk per dag held
# Kva som bør liggje URØRT i git: indexen og cachen våre.
# (Agentfilene AGENTS.md/CLAUDE.md er motsett: dei ER meint å committast.)
const GITIGNORE_WANTED = [".codegraph/"]
const GITIGNORE_PATH = "res://.gitignore"
const AGENTS_TAB = 3           # fanebladet for Agentar & Info (fast rekkjefølgje)
# Kommenteaten vi skriv inn i brukaren sin .gitignore. Alltid engelsk: fila
# hamnar i repoet deira, der alle (og alle agentar) les henne.
const GITIGNORE_HEADER = "# CodeGraph: local index and cache (keep out of git)"

var python_ver: String = ""      # t.d. "3.12.1" - frå Python sjølv, ikkje frå --version-teksten
var python_exe: String = ""      # sys.executable: det faktiske programmet bak kommandoen
var python_problem: String = ""  # "", "missing", "old", "broken"
var python_found_path: String = ""  # PATH-oppsettet fann noko, men det køyrde ikkje

# .gitignore-sjekk og varslande på fanebladet
var gitignore_missing: Array[String] = []
var _gi_status_time_ms: int = 0
var _gi_cached: Array[String] = []
var _gi_mtime: int = 0
# 0 = vi veit ikkje (fila finst ikkje), 1 = ja, 2 = nei
var _gi_exists_state: int = 0
var _badge: Button = null
var _badge_host: TabBar = null
var _tab_stack: Array[Node] = []   # berre ein gjenbrukt jobbekø for _tab_bar()

var python_cmd: String = "python"
var python_ok: bool = false
var backend_path: String = ""
var symbol_cache: Array[Dictionary] = []
var index_thread: Thread = null
var poll_timer: Timer = null
var html_thread: Thread = null
var html_timer: Timer = null
var html_view_name: String = ""
var auto_timer: Timer = null

func _ready() -> void:
	_load_language_preference()
	_load_ui_prefs()
	_load_update_state()
	_setup_ui()
	_init_python()
	_check_indexed_state()
	_load_existing_bench_chart()
	_connect_fs_watch()
	# Éin gong per dag, stille og i bakgrunnen: ingen knappetrykk, inga skriving.
	if Engine.is_editor_hint() and python_ok and _upd_age_h() >= CHECK_TTL_H:
		_start_update_check([], t("upd_checking"))
	# fanen må ha fått breidde si før merket kan plasserast
	call_deferred("_position_badge")

# Editoren varslar når filer på disk endrar seg (lagring av skript, import,
# agent-endringar). Då held vi indeksen frisk utan at brukaren må tenkje på det.
func _connect_fs_watch() -> void:
	if not Engine.is_editor_hint():
		return
	var rfs = EditorInterface.get_resource_filesystem()
	if rfs and rfs.has_signal("filesystem_changed"):
		rfs.filesystem_changed.connect(_on_filesystem_changed)

func _on_filesystem_changed() -> void:
	# Editoren har nettopp skanna disken på nytt - da kan plugin.cfg ha blitt ei
	# anna fil (ein oppdatering, en git checkout, ei handredigering).  Talet i
	# faktatabellen og i About skal følgje etter, elles står det gammalt heilt til
	# ein omstart.  Dette står føre python-vakten, som ikkje har med saka å gjere.
	_refresh_version_labels()
	if not python_ok:
		return
	if auto_timer == null:
		auto_timer = Timer.new()
		auto_timer.one_shot = true
		auto_timer.wait_time = 1.5
		auto_timer.timeout.connect(_auto_index)
		add_child(auto_timer)
	auto_timer.start()

# Inkrementell (IKKJE --force): bakenden hashar filene og tolkar berre endra
# filar på nytt, og returnerer raskt når inga er endra. Berre når det allereie
# finst ein indeks - ny prosjekt vel brukaren sjølv å bygge via velkomst-kortet.
func _auto_index() -> void:
	if not python_ok or not _index_ok():
		return
	if index_thread and index_thread.is_alive():
		return
	_start_async_index(["index"], false)

# Docken kan ha vore skjult medan ein agent bygde indeksen via CLI - då skal
# velkomst-kortet forsvinne og søket bli tilgjengeleg utan å starte editoren på nytt.
func _visibility_changed() -> void:
	if not is_node_ready() or not visible:
		return
	_check_indexed_state()

func _load_language_preference() -> void:
	# Sjekk lagret preferanse først
	var lang_file = "res://.codegraph/lang.txt"
	if FileAccess.file_exists(lang_file):
		var saved = FileAccess.get_file_as_string(lang_file).strip_edges().to_lower()
		if saved in ["en", "no"]:
			lang = saved
			return
	
	# Standard er alltid engelsk med mindre editoren eksplisitt har norsk Bokmål
	lang = "en"
	if Engine.is_editor_hint():
		var settings = EditorInterface.get_editor_settings()
		if settings:
			var editor_lang = str(settings.get_setting("interface/editor/editor_language")).to_lower()
			if editor_lang == "nb" or editor_lang == "no" or editor_lang.begins_with("nb_") or editor_lang.begins_with("no_"):
				lang = "no"

func _toggle_language() -> void:
	lang = "no" if lang == "en" else "en"
	var lang_file = "res://.codegraph/lang.txt"
	DirAccess.make_dir_recursive_absolute("res://.codegraph")
	var f = FileAccess.open(lang_file, FileAccess.WRITE)
	if f:
		f.store_string(lang)
		f.close()
	
	_setup_ui()
	_load_existing_bench_chart()

func t(key: String) -> String:
	var dict = STRINGS.get(lang, STRINGS["en"])
	return dict.get(key, STRINGS["en"].get(key, key))

# Oppslaget går through PATH, same måten ein launcher finn program på - det
# verkar på Windows, macOS og Linux utan at vi må køyre «where»/«which» per
# styresystem. Éin køyring med -c gir oss versjon OG den faktiske fila
# (sys.executable), så brukaren kan sjå kva som faktisk blir brukt.
func _init_python() -> void:
	backend_path = ProjectSettings.globalize_path("res://addons/codegraph/backend/graph.py")
	python_ok = false
	python_ver = ""
	python_exe = ""
	python_problem = ""
	python_found_path = ""
	var probe: String = "import sys;v=sys.version_info;print(v[0]);print(v[1]);print(sys.executable)"
	for candidate in ["python", "python3", "py"]:
		var out: Array = []
		var exit_code: int = OS.execute(candidate, ["-c", probe], out, true)
		var lines: PackedStringArray = String(out[0]).strip_edges().split("\n", false)
		if exit_code != 0 or lines.size() < 3:
			continue
		var major: int = int(lines[0])
		var minor: int = int(lines[1])
		python_cmd = candidate
		python_exe = String(lines[2]).strip_edges()
		python_ver = "%d.%d" % [major, minor]
		if major < 3 or (major == 3 and minor < 10):
			python_problem = "old"          # backenden krev 3.10+
			break
		python_ok = true
		break
	if not python_ok and python_problem.is_empty():
		python_problem = "missing"
		_python_path_probe()               # PATH har noko som heiter python likevel?
	_set_backend_enabled(python_ok)
	if not python_ok:
		status_label.text = t("err_python") + "  " + t("python_install")
	_refresh_python_card()

# Berre diagnose: PATH peiker på noko som heiter python, men ingen av kommandoene
# køyrde. På Windows er dette nesten alltid Microsoft Store-aliaset.
func _python_path_probe() -> void:
	var finder: String = "where" if OS.get_name() == "Windows" else "which"
	for cand in ["python", "python3"]:
		var out: Array = []
		if OS.execute(finder, [cand], out, true) != 0:
			continue
		var hits: PackedStringArray = String(out[0]).strip_edges().split("\n", false)
		if hits.is_empty():
			continue
		var first: String = String(hits[0]).strip_edges()
		if first.is_empty():
			continue
		python_problem = "broken"
		python_found_path = first
		python_exe = first
		return

# Kortet har to lag: overskrift + statuskodelall (alltid synleg) og
# forklaring/tabell/knappar (kan pakkest saman). Grønt = roleg = samanpakka,
# noko i vegen = utpakka med farge. Brukaren sitt eige val frå før vinn.
func _refresh_python_card() -> void:
	if py_status == null:
		return
	var head: String = ""
	var col: Color = C_DIM
	if python_ok:
		head = t("py_head_ok") % python_ver
		col = C_OK
		py_status.text = t("py_ok_line")
		py_install_hint.text = ""
	elif python_problem == "old":
		head = t("py_head_old") % python_ver
		col = C_HOT
		py_status.text = t("py_too_old") % python_ver
		py_install_hint.text = _py_install_hint()
	elif python_problem == "broken":
		head = t("py_head_broken")
		col = C_BAD
		py_status.text = t("py_not_working") + "\n[color=#6d8296]" + python_found_path + "[/color]"
		py_install_hint.text = _py_install_hint()
	else:
		head = t("py_head_missing")
		col = C_BAD
		py_status.text = t("py_missing") + "\n" + t("py_missing_note")
		py_install_hint.text = _py_install_hint()
	# Overskrifta følgjer tilstanden: grønt er roleg, raudt ropar.
	if py_card_title:
		py_card_title.add_theme_color_override("font_color", col)
	if py_summary:
		py_summary.text = head
		py_summary.add_theme_color_override("default_color", col)
	# Kopieringsknappen gir meinings berre når noko må fikse.
	if py_copy_button:
		py_copy_button.visible = not python_ok
	if py_copy_row:
		py_copy_row.visible = not python_ok
	_fill_py_table()
	if not _card_pinned.get("py", false):
		_set_card_open("py", not python_ok, false)

# Tabelloversikt i staden for éin lang tekstlinje per opplysning: same kolonner
# for alle rader, så auga får noko å halde i.
func _fill_py_table() -> void:
	if py_table == null:
		return
	var none_txt: String = t("py_none")
	lbl_py_ver.text = t("k_py_ver")
	val_py_ver.text = python_ver if not python_ver.is_empty() else none_txt
	lbl_py_cmd.text = t("k_py_cmd")
	val_py_cmd.text = python_cmd if (python_ok or python_problem == "old") else none_txt
	lbl_py_exe.text = t("k_py_exe")
	val_py_exe.text = python_exe if not python_exe.is_empty() else none_txt
	lbl_godot.text = t("k_godot")
	val_godot.text = _godot_version()
	lbl_plugin.text = t("k_plugin")
	val_plugin.text = _plugin_version()
	for lbl: Label in [val_py_ver, val_py_cmd, val_py_exe, val_godot, val_plugin]:
		lbl.add_theme_color_override("font_color", C_INK)
	for lbl: Label in [lbl_py_ver, lbl_py_cmd, lbl_py_exe, lbl_godot, lbl_plugin]:
		lbl.add_theme_color_override("font_color", C_DIM)
	# Langt filnamn skal ikkje utvida breidda på heile fanen.
	val_py_exe.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	val_py_exe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

# 4.7 erstatta get_version_string() med get_version_info(). Kalla går dynamisk,
# elles hadar GDScript-oversetaren namn som ikkje finst i 4.4 og 4.5 - og
# pluginen skal halde seg lova på alle 4.x.
func _godot_version() -> String:
	if Engine.has_method("get_version_info"):
		var vi: Dictionary = Engine.call("get_version_info")
		var s: String = String(vi.get("string", ""))
		if not s.is_empty():
			return s
		return "%d.%d.%d" % [int(vi.get("major", 0)), int(vi.get("minor", 0)), int(vi.get("patch", 0))]
	if Engine.has_method("get_version_string"):
		return String(Engine.call("get_version_string"))
	return "4.x"

# Installingsraadet er ulikt frå styresystem til styresystem - brukaren skal
# sleppe å leite etter kva som gjeld her.
func _py_install_hint() -> String:
	match OS.get_name():
		"Windows":
			return t("py_install_windows")
		"macOS":
			return t("py_install_macos")
		"Linux", "FreeBSD", "OpenBSD", "NetBSD":
			return t("py_install_linux")
		_:
			return t("py_install_other")

# ---------------------------------------------------------------------------
# Utpakkbare kort: mindre innhold nedover, og det som trekkjer merksemd
# allereie openbert. Instillingane blir verande i .codegraph/ui.json (gitignoret).
# ---------------------------------------------------------------------------
func _load_ui_prefs() -> void:
	_ui_prefs = {}
	if not FileAccess.file_exists(UI_PREFS_PATH):
		return
	var fa: FileAccess = FileAccess.open(UI_PREFS_PATH, FileAccess.READ)
	if fa == null:
		return
	var data: Variant = JSON.parse_string(fa.get_as_text())
	fa.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	_ui_prefs = data
	for k in _ui_prefs:
		var key: String = String(k)
		if not key.ends_with("_open"):
			continue
		var which: String = key.trim_suffix("_open")
		if not CARD_BODY.has(which):
			continue
		_card_open[which] = bool(_ui_prefs[k])
		_card_pinned[which] = true

func _save_ui_prefs() -> void:
	var root_dir: String = ProjectSettings.globalize_path("res://.codegraph")
	if not DirAccess.dir_exists_absolute(root_dir):
		DirAccess.make_dir_recursive_absolute(root_dir)
	var fa: FileAccess = FileAccess.open(UI_PREFS_PATH, FileAccess.WRITE)
	if fa == null:
		return
	fa.store_string(JSON.stringify(_ui_prefs, "  "))
	fa.close()

func _body_nodes(which: String) -> Array:
	var out: Array = []
	for nm in CARD_BODY[which]:
		var n: Node = get(String(nm))
		if n:
			out.append(n)
	return out

# Smart standard: noko i vegen → utpakka, alt grønt → samanpakka.
func _default_open(which: String) -> bool:
	if which == "py":
		return not python_ok
	return not _agents_installed()

func _apply_card_states() -> void:
	for which in CARD_BODY:
		if not _card_open.has(String(which)):
			_card_open[String(which)] = _default_open(String(which))
		_set_card_open(String(which), bool(_card_open[String(which)]), false)

func _set_card_open(which: String, open: bool, save: bool = true) -> void:
	_card_open[which] = open
	for n in _body_nodes(which):
		(n as Node).visible = open
	var btn: Button = teach_expand_button if which == "teach" else py_expand_button
	if btn:
		btn.text = t("expand_less") if open else t("expand_more")
	if save:
		_ui_prefs[which + "_open"] = open
		_card_pinned[which] = true
		_save_ui_prefs()
	call_deferred("_position_badge")

func _on_teach_expand_pressed() -> void:
	_set_card_open("teach", not bool(_card_open.get("teach", false)))

func _on_py_expand_pressed() -> void:
	_set_card_open("py", not bool(_card_open.get("py", false)))

func _on_python_dl_pressed() -> void:
	OS.shell_open(PY_URL)

# Sjølve kommandoen, ikkje berre forklaringa - brukaren skal sleppe å skrive
# han av skjermen.
func _py_install_command() -> String:
	match OS.get_name():
		"Windows":
			return "winget install Python.Python.3.12"
		"macOS":
			return "brew install python"
		"Linux", "FreeBSD", "OpenBSD", "NetBSD":
			return "sudo apt install python3"
		_:
			return ""

func _on_py_copy_pressed() -> void:
	var cmd: String = _py_install_command()
	if cmd.is_empty():
		OS.shell_open(PY_URL)
		return
	DisplayServer.clipboard_set(cmd)
	py_install_hint.text = t("py_copied") % cmd
	if _py_copy_timer == null:
		_py_copy_timer = Timer.new()
		_py_copy_timer.one_shot = true
		_py_copy_timer.wait_time = 4.0
		add_child(_py_copy_timer)
		_py_copy_timer.timeout.connect(_refresh_python_card)
	_py_copy_timer.start()

# ---------------------------------------------------------------------------
# .gitignore: index og cache er per-maskinfiler som ALDRI skal i git.
# Agentfilene (AGENTS.md, CLAUDE.md, ...) er motsett: dei er meint å committast.
# ---------------------------------------------------------------------------
func _gi_norm(rule: String) -> String:
	var r: String = rule.strip_edges()
	if r.is_empty() or r.begins_with("#") or r.begins_with("!"):
		return ""
	for pfx in ["./", "**/", "/"]:
		if r.begins_with(pfx):
			r = r.substr(pfx.length())
			break
	while r.ends_with("/") or r.ends_with("*"):
		r = r.substr(0, r.length() - 1)
	return r.replace("\\", "/").to_lower()

# Tidsstempel på fil, om bygget har det. Godot 4.7 har ingen av desse metodane
# i det heile (verken FileAccess::get_modified_time eller DirAccess::get_mod_time),
# så her får vi 0 - og _check_gitignore() brukar då tidsvindauget åleine.
# Framtidige bygget kan få metoden tilbake, og då slår tidsstemplet inn med ein
# gong. 0 er trygt: utan tidsstempel gjeld «same exists-tilstand innanfor
# tidsvindauget», og ei nyoppretta .gitignore gir annan exists-tilstand.
func _file_mtime(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	for method in ["get_modified_time", "get_mod_time"]:
		if f.has_method(method):
			var stamp: Variant = f.call(method, ProjectSettings.globalize_path(path))
			if typeof(stamp) == TYPE_INT and int(stamp) > 0:
				f.close()
				return int(stamp)   # unix-tal, beint samanliknbar
	f.close()
	return 0

func _check_gitignore(force: bool = false) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var exists: bool = FileAccess.file_exists(GITIGNORE_PATH)
	# Tidsstemplet blir lesen ETTER at fila er lesen, elles kan ei rask
	# redigering havne i mellomrommet mellom tida vi måler og innhaldet vi les.
	var mtime: int = 0
	var out: Array[String] = []
	var fa: FileAccess = null
	if exists:
		fa = FileAccess.open(GITIGNORE_PATH, FileAccess.READ)
	var txt: String = ""
	if fa != null:
		txt = fa.get_as_text()
		fa.close()
		mtime = _file_mtime(GITIGNORE_PATH)   # 0 når tidsstempel ikkje finst
	var state: int = 1 if exists else 2
	# mtime endrar seg kvar gong fila blir skriven (Godot 4.7 har elles ikkje
	# FileAccess::get_modified_time, og då er mtime 0 fast - unntaket er ei heilt
	# ny fil, og det tar tidsvindauget under seg av).
	var known_change: bool = state != _gi_exists_state or mtime != _gi_mtime
	if not force:
		if mtime > 0 and state == _gi_exists_state and mtime == _gi_mtime:
			gitignore_missing = _gi_cached   # uendra fil: svaret held framleis
			return
		if not known_change and _gi_status_time_ms > 0 and now_ms - _gi_status_time_ms < 3000:
			gitignore_missing = _gi_cached   # utan tidsstempel: høgst éin les per 3 s
			return
	if not exists:
		for w in GITIGNORE_WANTED:
			out.append(w)
	else:
		var rules: PackedStringArray = txt.split("\n")
		for w in GITIGNORE_WANTED:
			var want: String = _gi_norm(w)
			var found: bool = false
			for r in rules:
				if _gi_norm(r) == want:
					found = true
					break
			if not found:
				out.append(w)
	_gi_cached = out
	_gi_status_time_ms = now_ms
	_gi_mtime = mtime
	_gi_exists_state = state
	gitignore_missing = out

func _refresh_gitignore_row() -> void:
	if giti_status == null:
		return
	_check_gitignore()
	var col: Color = C_OK
	if gitignore_missing.is_empty():
		giti_status.text = t("giti_ok") % ", ".join(GITIGNORE_WANTED)
		if giti_fix_row: giti_fix_row.visible = false
	else:
		col = C_HOT
		var joined: String = ", ".join(gitignore_missing)
		giti_status.text = (t("giti_no_file") if not FileAccess.file_exists(GITIGNORE_PATH)
			else t("giti_missing")) % joined
		if giti_fix_row: giti_fix_row.visible = true
		if giti_fix_button: giti_fix_button.text = t("btn_giti_fix")
	giti_status.add_theme_color_override("default_color", col)
	_refresh_tab_badge()

# Éin trykk-knapp, berre leggje til: meir enn å skrive på slutten av fila gjer
# vi ikkje, og vi spør berre når noko faktisk manglar.
func _on_giti_fix_pressed() -> void:
	# Les fila på nytt FIRST: brukaren kan ha adda regelen for hand mellom
	# raden dukka opp og klikket, og då skal vi ikkje skrive eitt einaste teikn.
	_check_gitignore(true)
	if gitignore_missing.is_empty():
		giti_status.text = t("giti_noneed")
		giti_status.add_theme_color_override("default_color", C_OK)
		if giti_fix_row: giti_fix_row.visible = false
		_refresh_tab_badge()
		return
	var exists: bool = FileAccess.file_exists(GITIGNORE_PATH)
	var txt: String = ""
	var eol: String = "\n"
	if exists:
		var fr: FileAccess = FileAccess.open(GITIGNORE_PATH, FileAccess.READ)
		if fr != null:
			txt = fr.get_as_text()
			fr.close()
		if txt.contains("\r\n"):
			eol = "\r\n"
	if not txt.is_empty() and not txt.ends_with("\n"):
		txt += eol
	txt += eol + GITIGNORE_HEADER + eol
	for w in gitignore_missing:
		txt += w + eol
	var fw: FileAccess = FileAccess.open(GITIGNORE_PATH, FileAccess.WRITE)
	if fw == null:
		_check_gitignore(true)
		giti_status.text = t("giti_failed") % error_string(FileAccess.get_open_error())
		giti_status.add_theme_color_override("default_color", C_BAD)
		return
	fw.store_string(txt)
	fw.close()
	var added: Array[String] = gitignore_missing.duplicate()
	_check_gitignore(true)
	if gitignore_missing.is_empty():
		giti_status.text = t("giti_fixed") % ", ".join(added)
		giti_status.add_theme_color_override("default_color", C_OK)
		if giti_fix_row: giti_fix_row.visible = false
	else:
		# Should not happen (the button only shows when something is missing), but
		# say so instead of pretending the file was just written.
		giti_status.text = t("giti_noneed")
		if giti_fix_row: giti_fix_row.visible = false
		giti_status.add_theme_color_override("default_color", C_OK)
	_refresh_tab_badge()

# ---------------------------------------------------------------------------
# Varslande på fanebladet: tal i raud, avrunda kapsel etter tabenamen.
# ---------------------------------------------------------------------------
func _attention_count() -> int:
	var n: int = 0
	if python_problem != "":
		n += 1
	if bool(update_state.get("update_available", false)):
		n += 1
	if not gitignore_missing.is_empty():
		n += 1
	return n

func _badge_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color("#d43f3a")
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 1)
	return sb

func _refresh_tab_badge() -> void:
	var n: int = _attention_count()
	# merka skal berre synast når Agentar-fanen IKKJE allereie er open
	var shown: int = n
	var hidden_because_open: bool = (main_tabs != null and main_tabs.current_tab == AGENTS_TAB)
	if hidden_because_open:
		shown = 0
	if _badge == null:
		var host: TabBar = _tab_bar()
		if host == null:
			push_warning("CodeGraph: fann ikkje TabBar-en i TabContainer-en, varslingsmerket blir utslått")
			return
		_badge_host = host
		_badge = Button.new()
		_badge.focus_mode = Control.FOCUS_NONE
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb: StyleBoxFlat = _badge_style()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			_badge.add_theme_stylebox_override(st, sb)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
			_badge.add_theme_color_override(cn, Color(1, 1, 1, 1))
		_badge.add_theme_font_size_override("font_size", 12)
		_badge.custom_minimum_size = Vector2(20, 19)
		_badge_host.add_child(_badge)
	# merket blir verande i tree-søket (tabar og panel blir gjenbrukte), og
	# musefiltret går attom til IGNORE når merket ikkje treng klikk
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE if shown <= 0 else Control.MOUSE_FILTER_STOP
	_badge.visible = shown > 0
	if shown > 0:
		_badge.text = str(shown)
		# merket tek klikket: byt til Agentar-fanen (samstundes kan brukaren
		# framleis draie fanelinja - merket ligg berre inst i høyre kant)
		if not _badge.pressed.is_connected(_focus_agents_tab):
			_badge.pressed.connect(_focus_agents_tab)
		_badge.mouse_filter = Control.MOUSE_FILTER_STOP
		_badge.tooltip_text = t("badge_hint") % n
	_position_badge()

func _on_tab_changed(_which_tab: int) -> void:
	_refresh_tab_badge()

func _focus_agents_tab() -> void:
	if main_tabs != null:
		main_tabs.current_tab = AGENTS_TAB
	_refresh_tab_badge()

func _find_child_tab_bar(n: Node, depth: int) -> TabBar:
	if n == null or depth > 6:
		return null
	if n is TabBar:
		return n as TabBar
	for c in n.get_children():
		var found: TabBar = _find_child_tab_bar(c, depth + 1)
		if found != null:
			return found
	return null

func _tab_bar() -> TabBar:
	# TabContainer lagar TabBar-en sin eigen "tabbar"-knot i TreeStore, ikkje
	# som vanleg barn. 4.7 og utover har TabContainer difor get_tab_bar(),
	# medan eldre versjonar berre har barna. Vi lagar merket med det same
	# (synleg = først når noko verkeleg krev merksemd), elles forsvinn
	# oppdatering av posisjon når noko endrar seg.
	# Merket blir ikkje fjerna att: skjult knapp kostar ingenting, og
	# oppdateringsposisjonen blir verande korrekt.
	if main_tabs == null:
		return null
	if main_tabs.has_method("get_tab_bar"):
		var tb: Variant = main_tabs.call("get_tab_bar")
		if tb is TabBar:
			return tb as TabBar
	return _find_child_tab_bar(main_tabs, 0)

# Merket står rett etter Agentar-fanen (den er den siste i rada), altså like
# etter tabnamnet og ikkje oppå teksten. Fallback: dersom fanelinja er så smal
# at det ikkje er plass utanfor, trekkjer merket inn i høgre kant av taben.
func _position_badge() -> void:
	if _badge == null or not _badge.visible or _badge_host == null:
		return
	var rect: Rect2 = _badge_host.get_tab_rect(AGENTS_TAB)
	if rect.size.x <= 0.0:
		return
	_badge.reset_size()
	var sz: Vector2 = _badge.get_combined_minimum_size()
	var right_x: float = rect.position.x + rect.size.x
	var x: float = right_x + 6.0
	var limit: float = _badge_host.size.x - 4.0
	if _badge_host.get_tab_count() > AGENTS_TAB + 1:
		var nxt: Rect2 = _badge_host.get_tab_rect(AGENTS_TAB + 1)
		limit = nxt.position.x - 4.0
	if x + sz.x > limit:
		x = right_x - sz.x - 4.0
	_badge.position = Vector2(x, rect.position.y + (rect.size.y - sz.y) * 0.5)

# ---------------------------------------------------------------------------
# Oppdateringskontroll i same kort som Python-statusen.
# `kg update` les versjonen sin frå repoen (version.json / siste tag), write
# svaret til .codegraph/update.json og rører ALDRI pluginen utan at nokon har
# trykt på knapp (eller gitt agenten løyve).
# ---------------------------------------------------------------------------
func _load_update_state() -> void:
	update_state = {}
	if not FileAccess.file_exists(UPDATE_STATE_PATH):
		return
	var fa: FileAccess = FileAccess.open(UPDATE_STATE_PATH, FileAccess.READ)
	if fa == null:
		return
	var data: Variant = JSON.parse_string(fa.get_as_text())
	fa.close()
	if typeof(data) == TYPE_DICTIONARY:
		update_state = data

func _upd_age_h() -> float:
	if not update_state.has("checked_at"):
		return 1e9
	return (Time.get_unix_time_from_system() - float(update_state["checked_at"])) / 3600.0

func _refresh_update_card() -> void:
	if upd_chip == null:
		return
	var head: String = ""
	var col: Color = C_DIM
	var latest: String = String(update_state.get("latest", ""))
	var busy: bool = update_thread != null and update_thread.is_alive()
	if upd_applying:
		head = t("upd_head_applying")
		col = C_HOT
	elif busy:
		head = t("upd_checking")
	elif update_state.is_empty():
		head = t("upd_head_never")
	elif String(update_state.get("error", "")) != "":
		head = t("upd_head_none") if String(update_state.get("reason", "")) == "no_release" else t("upd_head_err")
		if String(update_state.get("reason", "")) == "no_release":
			col = C_DIM
	elif bool(update_state.get("update_available", false)):
		head = t("upd_head_new") % latest
		col = C_HOT
	else:
		head = t("upd_head_ok")
		col = C_OK
	upd_chip.text = head
	upd_chip.add_theme_color_override("default_color", col)
	lbl_upd.text = t("k_upd_latest")
	val_upd.text = latest if not latest.is_empty() else t("upd_never")
	lbl_checked.text = t("k_upd_checked")
	var stamp: String = String(update_state.get("checked_at_iso", ""))
	val_checked.text = stamp if not stamp.is_empty() else t("upd_never")
	if upd_check_button:
		upd_check_button.disabled = busy
		upd_check_button.text = (_spin_frame() + " " + t("upd_checking")) if busy else t("btn_upd_check")
	if upd_apply_button:
		if upd_applying:
			# Knappen blir verande synleg medan jobben går, men slått av: ingen
			# skal kunne trykkje seg gjennom same zippen gong på gong.
			upd_apply_button.visible = true
			upd_apply_button.disabled = true
			upd_apply_button.text = _spin_frame() + " " + (t("btn_upd_busy") % latest)
		else:
			var can: bool = (not busy) and bool(update_state.get("update_available", false))
			upd_apply_button.disabled = false
			upd_apply_button.visible = can
			upd_apply_button.text = t("btn_upd_confirm") if upd_apply_armed else (t("btn_upd_apply") % latest)
	# Kortet hoppar ut sjølv om brukaren ikkje har valt noko, når det finst noko å sjå
	if busy:
		upd_status.text = upd_busy_text
		upd_status.visible = true
	elif not update_state.is_empty():
		var err: String = String(update_state.get("error", ""))
		if not err.is_empty() and String(update_state.get("reason", "")) == "no_release":
			upd_status.text = t("upd_no_release")
			upd_status.visible = true
		elif not err.is_empty():
			upd_status.text = t("upd_failed") % err
			upd_status.visible = true
		elif bool(update_state.get("update_available", false)):
			upd_status.text = t("upd_found") % latest
			upd_status.visible = true
		elif _just_installed() != "":
			# «Installerte X» blir ståande heilt til neste reelle sjekk, så brukaren
			# ser kva som skjedde sjølv om han lastar prosjektet først etterpå.
			upd_status.text = t("upd_applied") % [_just_installed(), String(update_state.get("backup", ""))]
			upd_status.visible = true
		elif upd_fail_note != "":
			upd_status.text = t("upd_apply_failed") % [latest, upd_fail_note]
			upd_status.visible = true
		else:
			upd_status.text = ""
			upd_status.visible = false
	else:
		upd_status.visible = false
	if upd_agent_note:
		upd_agent_note.text = t("upd_agent_note")
	if giti_fix_button:
		giti_fix_button.text = t("btn_giti_fix")
	_refresh_gitignore_row()
	if not _card_pinned.get("py", false) and bool(update_state.get("update_available", false)):
		_set_card_open("py", true, false)
	_refresh_tab_badge()

func _run_update_worker(extra: Array[String]) -> void:
	var root_dir: String = ProjectSettings.globalize_path("res://")
	var args: Array = [backend_path, "--path", root_dir, "update", "--json"]
	args.append_array(extra)
	var out: Array = []
	var code: int = OS.execute(python_cmd, args, out, true)
	# Desse to berre blir lesen etter wait_to_finish(), aldri samstundes med tråden.
	update_out = out
	update_exit = code

func _spin_frame() -> String:
	return SPIN_FRAMES[upd_spin % SPIN_FRAMES.size()]

# Spinneren går på same poll-timeren som ser om tråden er ferdig, så han stoppar
# av seg sjølv når jobben er slutt - ingen timer som går i det stille.
func _spin_busy_labels() -> void:
	var latest: String = String(update_state.get("latest", ""))
	if upd_apply_button != null and upd_applying:
		upd_apply_button.text = _spin_frame() + " " + (t("btn_upd_busy") % latest)
	if upd_check_button != null and update_thread != null and update_thread.is_alive():
		upd_check_button.text = _spin_frame() + " " + t("upd_checking")
		upd_check_button.disabled = true

# Er installasjonen i statefila nyare enn sjekken som høyrer til?  Då er
# «Installerte X» framleis sant å vise, og knappen er borte av seg sjølv.
func _just_installed() -> String:
	if not update_state.has("applied_to"):
		return ""
	if float(update_state.get("applied_at", 0.0)) < float(update_state.get("checked_at", 0.0)):
		return ""
	return String(update_state.get("applied_to", ""))

func _start_update_check(extra: Array[String], note: String) -> void:
	if not python_ok:
		upd_applying = false
		upd_busy_text = t("err_python")
		_refresh_update_card()
		return
	if update_thread != null and update_thread.is_alive():
		return
	upd_busy_text = note
	upd_spin = 0
	update_out = []
	update_exit = 0
	if upd_apply_armed:
		upd_apply_armed = false
	_refresh_update_card()
	update_thread = Thread.new()
	update_thread.start(_run_update_worker.bind(extra))
	if upd_timer == null:
		upd_timer = Timer.new()
		upd_timer.wait_time = 0.30
		upd_timer.timeout.connect(_on_update_poll)
		add_child(upd_timer)
	upd_timer.start()

func _on_update_poll() -> void:
	if update_thread == null:
		if upd_timer:
			upd_timer.stop()
		return
	if update_thread.is_alive():
		upd_spin += 1
		_spin_busy_labels()
		return
	update_thread.wait_to_finish()
	update_thread = null
	if upd_timer:
		upd_timer.stop()
	var was_apply: bool = upd_applying
	upd_applying = false
	_load_update_state()
	if was_apply:
		# Statefila seier no kva versjon som faktisk ligg på disken (backenden
		# les plugin.cfg på nytt etter installasjonen).  Er det ikkje installert
		# noko, skal brukaren få vite kvifor - ikkje ei falsk grøn luke.
		var err: String = String(update_state.get("apply_error", ""))
		if _just_installed() != "":
			upd_fail_note = ""
		elif not err.is_empty():
			upd_fail_note = err
		elif update_exit != 0:
			upd_fail_note = t("upd_exit_code") % update_exit
		else:
			upd_fail_note = ""
		# Faktaraden «Plugin» og About-teksten skal ikkje halde på den gamle versjonen.
		_refresh_version_labels()
	_refresh_update_card()

func _on_upd_check_pressed() -> void:
	if upd_applying or (update_thread != null and update_thread.is_alive()):
		return
	upd_fail_note = ""
	_start_update_check(["--force"], t("upd_checking"))

# To trykk = stadfesting, utan dialogboks som ligg fast i editoren.
func _on_upd_apply_pressed() -> void:
	if upd_applying:
		return      # jobbar allereie: knappen er slått av, men doble klikk kan likevel kome fram
	if not upd_apply_armed:
		upd_apply_armed = true
		upd_fail_note = ""
		_refresh_update_card()
		if upd_arm_timer == null:
			upd_arm_timer = Timer.new()
			upd_arm_timer.one_shot = true
			upd_arm_timer.wait_time = 6.0
			upd_arm_timer.timeout.connect(_disarm_update)
			add_child(upd_arm_timer)
		upd_arm_timer.start()
		return
	upd_apply_armed = false
	upd_applying = true
	if upd_arm_timer:
		upd_arm_timer.stop()
	_start_update_check(["--apply", "--force"], t("upd_installing") % String(update_state.get("latest", "")))

func _disarm_update() -> void:
	if upd_applying:
		return      # armings-timaren skal ikkje endre knappane medan installasjonen går
	upd_apply_armed = false
	_refresh_update_card()

# Installerer du Python medan editoren går, trengst ingen omstart: knappen
# gjenopprettar heile tilstanden - knappar, status, indeks og agentfane.
func _on_py_check_pressed() -> void:
	if py_status:
		py_status.text = "…"
	_init_python()
	_check_indexed_state()
	_sync_agent_checks()
	_refresh_project_size_hint()

# Slår av alt som krev backenden, så brukaren får ei forklaring i staden for feil.
func _set_backend_enabled(on: bool) -> void:
	for b in [index_now_button, search_button, reindex_button, bench_button, html_button,
			open_files_button, open_signals_button, open_ego_button, teach_agents_button,
			bench_from_agents_button]:
		if b:
			b.disabled = not on
	if agent_teach:
		agent_teach.visible = on
	if agents_toggle:
		agents_toggle.disabled = not on

func _setup_ui() -> void:
	# Tab titlar
	main_tabs.set_tab_title(0, t("tab_search"))
	main_tabs.set_tab_title(1, t("tab_bench"))
	main_tabs.set_tab_title(2, t("tab_graph"))
	main_tabs.set_tab_title(3, t("tab_agents"))
	
	# Web Graph fane
	if graph_title_label: graph_title_label.text = t("graph_header")
	if card_files_title: card_files_title.text = t("card_files_title")
	if card_files_desc: card_files_desc.text = t("card_files_desc")
	if open_files_button:
		open_files_button.text = t("btn_open_files")
		if not open_files_button.pressed.is_connected(_on_open_files_pressed):
			open_files_button.pressed.connect(_on_open_files_pressed)
	if card_signals_title: card_signals_title.text = t("card_signals_title")
	if card_signals_desc: card_signals_desc.text = t("card_signals_desc")
	if open_signals_button:
		open_signals_button.text = t("btn_open_signals")
		if not open_signals_button.pressed.is_connected(_on_open_signals_pressed):
			open_signals_button.pressed.connect(_on_open_signals_pressed)
	if card_ego_title: card_ego_title.text = t("card_ego_title")
	if card_ego_desc: card_ego_desc.text = t("card_ego_desc")
	if ego_input:
		ego_input.placeholder_text = t("ego_input_ph")
		# Eige metode i staden for lambda: lambda i is_connected() matchar aldri,
		# så kvar språkbytte la til ei ny tilkopling (Enter opna nettlesaren to gongar).
		if not ego_input.text_submitted.is_connected(_on_ego_submitted):
			ego_input.text_submitted.connect(_on_ego_submitted)
		if not ego_input.text_changed.is_connected(_on_ego_text_changed):
			ego_input.text_changed.connect(_on_ego_text_changed)
		if not ego_input.gui_input.is_connected(_on_ego_input_gui_input):
			ego_input.gui_input.connect(_on_ego_input_gui_input)
	if ego_acc_list and not ego_acc_list.item_selected.is_connected(_on_ego_acc_selected):
		ego_acc_list.item_selected.connect(_on_ego_acc_selected)
	if ego_depth_label: ego_depth_label.text = t("depth")
	if ego_depth_option and ego_depth_option.item_count == 0:
		ego_depth_option.add_item("1 step")
		ego_depth_option.add_item("2 steps")
		ego_depth_option.add_item("3 steps")
		ego_depth_option.selected = 1
	if open_ego_button:
		open_ego_button.text = t("btn_open_ego")
		if not open_ego_button.pressed.is_connected(_on_open_ego_pressed):
			open_ego_button.pressed.connect(_on_open_ego_pressed)
	if tips_label: tips_label.text = t("graph_tips")
	if graph_lang_button:
		graph_lang_button.text = "🌐 " + lang.to_upper()
		if not graph_lang_button.pressed.is_connected(_toggle_language):
			graph_lang_button.pressed.connect(_toggle_language)
	
	# Språkknapp
	lang_button.text = "🌐 " + lang.to_upper()
	if not lang_button.pressed.is_connected(_toggle_language):
		lang_button.pressed.connect(_toggle_language)
	if bench_lang_button:
		bench_lang_button.text = "🌐 " + lang.to_upper()
		if not bench_lang_button.pressed.is_connected(_toggle_language):
			bench_lang_button.pressed.connect(_toggle_language)
	
	# Agentfane: same toggle som i søkefeltet, men her er det plass til heile
	# forklaringa (kva som blir skrive, når det ikkje lønner seg, lisens og lenkjer).
	if agents_title_label: agents_title_label.text = t("agents_header")
	# Statuslinja i toggle rada skal skjere seg av med prikkar framfor å tvinga
	# heile fanen breiare enn vindauget.
	if agents_state_label:
		agents_state_label.clip_text = true
		agents_state_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if agents_lang_button:
		agents_lang_button.text = "🌐 " + lang.to_upper()
		if not agents_lang_button.pressed.is_connected(_toggle_language):
			agents_lang_button.pressed.connect(_toggle_language)
	if agents_card_title: agents_card_title.text = t("agents_card_title")
	if agents_toggle:
		agents_toggle.text = t("agent_teach")
		agents_toggle.tooltip_text = t("agent_teach_tip")
		if not agents_toggle.toggled.is_connected(_on_agents_toggle):
			agents_toggle.toggled.connect(_on_agents_toggle)
	if agents_help: agents_help.text = t("agents_help")
	if agents_written_label: agents_written_label.text = t("agents_written")
	if about_title: about_title.text = t("about_title")
	if about_text:
		about_text.text = t("about_text") % _plugin_version()
		if not about_text.meta_clicked.is_connected(_on_meta_clicked):
			about_text.meta_clicked.connect(_on_meta_clicked)
	if repo_button:
		repo_button.text = t("btn_repo")
		if not repo_button.pressed.is_connected(_on_repo_pressed):
			repo_button.pressed.connect(_on_repo_pressed)
	if issues_button:
		issues_button.text = t("btn_issues")
		if not issues_button.pressed.is_connected(_on_issues_pressed):
			issues_button.pressed.connect(_on_issues_pressed)
	if py_card_title: py_card_title.text = t("py_title")
	if py_help: py_help.text = t("py_help")
	if py_check_button:
		py_check_button.text = t("btn_py_check")
		if not py_check_button.pressed.is_connected(_on_py_check_pressed):
			py_check_button.pressed.connect(_on_py_check_pressed)
	if py_download_button:
		py_download_button.text = t("btn_python_dl")
		if not py_download_button.pressed.is_connected(_on_python_dl_pressed):
			py_download_button.pressed.connect(_on_python_dl_pressed)
	if py_copy_button:
		py_copy_button.text = t("btn_py_copy")
		if not py_copy_button.pressed.is_connected(_on_py_copy_pressed):
			py_copy_button.pressed.connect(_on_py_copy_pressed)
	if teach_expand_button and not teach_expand_button.pressed.is_connected(_on_teach_expand_pressed):
		teach_expand_button.pressed.connect(_on_teach_expand_pressed)
	if py_expand_button and not py_expand_button.pressed.is_connected(_on_py_expand_pressed):
		py_expand_button.pressed.connect(_on_py_expand_pressed)
	if main_tabs != null and not main_tabs.tab_changed.is_connected(_on_tab_changed):
		main_tabs.tab_changed.connect(_on_tab_changed)   # merket skal vekk når fanen er open
	var tb: TabBar = _tab_bar()
	if tb != null:
		tb.add_theme_constant_override("h_separation", 34)   # merket treng plass i taben
	if upd_check_button:
		upd_check_button.text = t("btn_upd_check")
		if not upd_check_button.pressed.is_connected(_on_upd_check_pressed):
			upd_check_button.pressed.connect(_on_upd_check_pressed)
	if upd_apply_button:
		if not upd_apply_button.pressed.is_connected(_on_upd_apply_pressed):
			upd_apply_button.pressed.connect(_on_upd_apply_pressed)
	if upd_agent_note: upd_agent_note.text = t("upd_agent_note")
	if giti_fix_button and not giti_fix_button.pressed.is_connected(_on_giti_fix_pressed):
		giti_fix_button.pressed.connect(_on_giti_fix_pressed)
	_check_gitignore(true)   # bytte av språk = brukaren bad om fersk status
	_refresh_gitignore_row()
	_refresh_update_card()
	# Python-statusen står i denne fanen også når backenden er slått heilt av,
	# så ho må teiknavast uavhengig av resten.
	_refresh_python_card()
	# Eige val frå før (ui.json) vinn over dei smarte standardane.
	_apply_card_states()
	if bench_from_agents_button:
		bench_from_agents_button.text = t("btn_bench_from_agents")
		if not bench_from_agents_button.pressed.is_connected(_on_bench_from_agents_pressed):
			bench_from_agents_button.pressed.connect(_on_bench_from_agents_pressed)
	_sync_agent_checks()
	_refresh_project_size_hint()
	# lag merket allereie no - då er posisjonen på plass før første teikning
	_refresh_tab_badge()
	
	# Velkomstskjerm
	welcome_title.text = t("welcome_title")
	welcome_desc.text = t("welcome_desc")
	index_now_button.text = t("btn_index_now")
	if not index_now_button.pressed.is_connected(_on_index_now_pressed):
		index_now_button.pressed.connect(_on_index_now_pressed)
	welcome_progress.visible = false
	welcome_status.visible = false
	# Agentopplæring: tilstanden blir lest frå disken, ikkje hugsa i minnet.
	agent_teach.text = t("agent_teach_short")
	agent_teach.tooltip_text = t("agent_teach_tip")
	agent_teach.set_block_signals(true)
	agent_teach.button_pressed = _agents_installed()
	agent_teach.set_block_signals(false)
	if not agent_teach.toggled.is_connected(_on_agent_teach):
		agent_teach.toggled.connect(_on_agent_teach)
	# Velkomst-kortet har same handling som knappen i verktøylinja: fanene
	# (og dermed verktøylinja) er skjulte før prosjektet er indeksert.
	_teach_button_text()
	if not teach_agents_button.pressed.is_connected(_on_teach_pressed):
		teach_agents_button.pressed.connect(_on_teach_pressed)
	search_progress.visible = false
	bench_progress.visible = false
	
	# Knapper
	search_button.text = t("btn_search")
	html_button.text = t("btn_visual_graph")
	reindex_button.text = t("btn_reindex")
	bench_button.text = t("btn_run_bench")
	open_json_button.text = t("btn_open_json")
	status_label.text = t("ready")
	bench_status.text = ""
	
	# Modusliste
	var cur_mode = mode_option.selected if mode_option.item_count > 0 else 0
	mode_option.clear()
	var modes = ["find", "outline", "callers", "signal", "rpc", "impact", "deps", "status"]
	for m in modes:
		mode_option.add_item(t("mode_" + m))
	
	if cur_mode >= 0 and cur_mode < mode_option.item_count:
		mode_option.selected = cur_mode
	
	if not mode_option.item_selected.is_connected(_on_mode_selected):
		mode_option.item_selected.connect(_on_mode_selected)
	if not search_button.pressed.is_connected(_on_search_pressed):
		search_button.pressed.connect(_on_search_pressed)
	if not search_input.text_submitted.is_connected(_on_search_submitted):
		search_input.text_submitted.connect(_on_search_submitted)
	if not search_input.text_changed.is_connected(_on_search_text_changed):
		search_input.text_changed.connect(_on_search_text_changed)
	if not search_input.gui_input.is_connected(_on_search_input_gui_input):
		search_input.gui_input.connect(_on_search_input_gui_input)
	if not html_button.pressed.is_connected(_on_html_pressed):
		html_button.pressed.connect(_on_html_pressed)
	if not reindex_button.pressed.is_connected(_on_reindex_pressed):
		reindex_button.pressed.connect(_on_reindex_pressed)
	if not bench_button.pressed.is_connected(_on_bench_pressed):
		bench_button.pressed.connect(_on_bench_pressed)
	if not open_json_button.pressed.is_connected(_on_open_json_pressed):
		open_json_button.pressed.connect(_on_open_json_pressed)
	if not output_display.meta_clicked.is_connected(_on_meta_clicked):
		output_display.meta_clicked.connect(_on_meta_clicked)
	if not bench_display.meta_clicked.is_connected(_on_meta_clicked):
		bench_display.meta_clicked.connect(_on_meta_clicked)
	# Breidde på brødteksten styrer kor breie søylene blir (sjå _bench_bar_width),
	# så storleiken må setjast i koden - og chartet teiknast på nytt når panelet endrar seg.
	bench_display.add_theme_font_size_override("normal_font_size", BENCH_FS)
	if not bench_display.resized.is_connected(_on_bench_display_resized):
		bench_display.resized.connect(_on_bench_display_resized)
	
	# Autocomplete setup
	if not autocomplete_list.item_selected.is_connected(_on_autocomplete_selected):
		autocomplete_list.item_selected.connect(_on_autocomplete_selected)
	
	_on_mode_selected(mode_option.selected)

func _on_search_submitted(_text: String) -> void:
	_on_search_pressed()

func _check_indexed_state() -> void:
	if _index_ok():
		welcome_panel.visible = false
		main_tabs.visible = true
		_load_symbol_cache()
	else:
		welcome_panel.visible = true
		main_tabs.visible = false

# Ein 0-byte graph.db er attetter ein avbroten køyring, ikkje ein indeks.
func _index_ok() -> bool:
	var db = "res://.codegraph/graph.db"
	if not FileAccess.file_exists(db):
		return false
	return FileAccess.get_size(db) > 1024

func _on_mode_selected(idx: int) -> void:
	var modes = ["find", "outline", "callers", "signal", "rpc", "impact", "deps", "status"]
	if idx >= 0 and idx < modes.size():
		search_input.placeholder_text = t("hint_" + modes[idx])

# --- Asynkron indeksering med levende ProgressBar ---
func _on_index_now_pressed() -> void:
	_start_async_index(["index", "--force"], true)

func _on_reindex_pressed() -> void:
	_start_async_index(["index", "--force"], false)

func _start_async_index(args: Array[String], is_welcome: bool) -> void:
	if not python_ok:
		status_label.text = t("err_python") + "  " + t("python_install")
		return
	if index_thread and index_thread.is_alive():
		return
	
	if is_welcome:
		welcome_progress.value = 0
		welcome_progress.visible = true
		welcome_status.visible = true
		welcome_status.text = t("indexing")
		index_now_button.visible = false
	else:
		search_progress.value = 0
		search_progress.visible = true
		reindex_button.disabled = true
		status_label.text = t("indexing")
	
	index_thread = Thread.new()
	index_thread.start(_run_index_worker.bind(args))
	
	if not poll_timer:
		poll_timer = Timer.new()
		poll_timer.wait_time = 0.08
		poll_timer.timeout.connect(_on_poll_progress.bind(is_welcome))
		add_child(poll_timer)
	poll_timer.start()

func _run_index_worker(subargs: Array[String]) -> void:
	var root_dir = ProjectSettings.globalize_path("res://")
	var full_args = [backend_path, "--path", root_dir]
	full_args.append_array(subargs)
	var out: Array = []
	OS.execute(python_cmd, full_args, out, true)

func _on_poll_progress(is_welcome: bool) -> void:
	var prog_file = "res://.codegraph/progress.json"
	if FileAccess.file_exists(prog_file):
		var text = FileAccess.get_file_as_string(prog_file)
		var json = JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			var d = json.data
			var pct = d.get("pct", 0)
			var cur = d.get("current", 0)
			var tot = d.get("total", 0)
			var msg = d.get("msg", "")
			
			if is_welcome:
				welcome_progress.value = pct
				if d.get("phase") == "parsing":
					welcome_status.text = "%d / %d (%d%%) — %s" % [cur, tot, pct, msg]
				else:
					welcome_status.text = "%d%% — %s" % [pct, msg]
			else:
				search_progress.value = pct
				if d.get("phase") == "parsing":
					status_label.text = "%d / %d (%d%%) — %s" % [cur, tot, pct, msg]
				else:
					status_label.text = "%d%% — %s" % [pct, msg]
	
	if index_thread and not index_thread.is_alive():
		index_thread.wait_to_finish()
		index_thread = null
		if poll_timer:
			poll_timer.stop()
		
		welcome_progress.visible = false
		welcome_status.visible = false
		search_progress.visible = false
		index_now_button.visible = true
		reindex_button.disabled = false
		status_label.text = t("ready")
		_check_indexed_state()

func _on_search_pressed() -> void:
	autocomplete_box.visible = false
	if not python_ok:
		status_label.text = t("err_python") + "  " + t("python_install")
		return
	var modes = ["find", "outline", "callers", "signal", "rpc", "impact", "deps", "status"]
	var idx = mode_option.selected
	var cmd = modes[idx]
	var arg = search_input.text.strip_edges()
	
	if cmd != "status" and cmd != "rpc" and arg.is_empty():
		status_label.text = t("enter_term")
		return
	
	var args: Array[String] = [cmd]
	if not arg.is_empty():
		args.append(arg)
	
	_run_codegraph(args)

func _on_html_pressed() -> void:
	main_tabs.current_tab = 2

func _on_open_files_pressed() -> void:
	_open_html_view("files")

func _on_open_signals_pressed() -> void:
	_open_html_view("signals")

func _on_open_ego_pressed() -> void:
	var sym = ego_input.text.strip_edges()
	if ego_acc_box:
		ego_acc_box.visible = false          # forslagslista skal ikkje bli liggjande
	if sym.is_empty():
		sym = search_input.text.strip_edges()
	if sym.is_empty():
		status_label.text = t("enter_term")
		return
	var depth = ego_depth_option.selected + 1
	_open_html_view("ego", sym, depth)

func _open_html_view(view_name: String, ego: String = "", depth: int = 2) -> void:
	if not python_ok:
		status_label.text = t("err_python") + "  " + t("python_install")
		return
	if html_thread and html_thread.is_alive():
		return
	html_view_name = view_name
	status_label.text = t("graph_generating")
	html_thread = Thread.new()
	html_thread.start(_run_html_worker.bind(view_name, ego, depth))
	if not html_timer:
		html_timer = Timer.new()
		html_timer.wait_time = 0.15
		html_timer.timeout.connect(_on_html_poll)
		add_child(html_timer)
	html_timer.start()

# Grafgenerering er denaste tunge jobben som ikkje allereie var tråda -
# elles frys editoren i fleire sekund på store prosjekt.
func _run_html_worker(view_name: String, ego: String, depth: int) -> void:
	var root_dir = ProjectSettings.globalize_path("res://")
	var args = [backend_path, "--path", root_dir, "html", "--view", view_name, "--open"]
	if not ego.is_empty():
		args.append_array(["--ego", ego, "--depth", str(depth)])
	var out: Array = []
	OS.execute(python_cmd, args, out, true)

func _on_html_poll() -> void:
	if html_thread == null:
		return
	if html_thread.is_alive():
		return
	html_thread.wait_to_finish()
	html_thread = null
	if html_timer:
		html_timer.stop()
	status_label.text = "Web Graph: " + html_view_name

func _exit_tree() -> void:
	if poll_timer:
		poll_timer.stop()
	if html_timer:
		html_timer.stop()
	# Trådar må høvlast før noden døyr, elles kan editoren krasja ved avlsuting.
	if index_thread != null:
		index_thread.wait_to_finish()
		index_thread = null
	if html_thread != null:
		html_thread.wait_to_finish()
		html_thread = null
	if update_thread != null:
		update_thread.wait_to_finish()
		update_thread = null
	if upd_timer:
		upd_timer.stop()

# --- Benchmark & Visuelle Diagrammer (Støtter Engelsk og Bokmål) ---
func _on_bench_pressed() -> void:
	if not python_ok:
		bench_status.text = t("err_python")
		return
	bench_status.text = t("bench_running")
	bench_display.clear()
	bench_progress.visible = true
	bench_button.disabled = true
	
	var root_dir = ProjectSettings.globalize_path("res://")
	var bench_py = ProjectSettings.globalize_path("res://addons/codegraph/backend/bench.py")
	
	var output_array: Array = []
	var start_time = Time.get_ticks_msec()
	var exit_code = OS.execute(python_cmd, [bench_py, "--path", root_dir], output_array, true)
	var elapsed = Time.get_ticks_msec() - start_time
	
	bench_progress.visible = false
	bench_button.disabled = false
	bench_status.text = t("done_ms") % [elapsed, exit_code]
	
	_load_existing_bench_chart()

func _load_existing_bench_chart() -> void:
	var json_path = "res://.codegraph/bench.json"
	_bench_raw = FileAccess.get_file_as_string(json_path) if FileAccess.file_exists(json_path) else ""
	# first av éin frame: då er panelstorleiken kjend, og søylebreidda blir
	# rekna ut frå den riktige breidde i staden for noden sin fallback (0).
	_render_bench.call_deferred()

func _render_bench() -> void:
	if _bench_rendering:
		return
	_bench_rendering = true
	bench_display.clear()
	if _bench_raw.is_empty():
		_bench_bar_w = 0
		_bench_rendering = false
		return
	var chart_bb = _format_bench_json_as_charts(_bench_raw)
	if not chart_bb.is_empty():
		bench_display.append_text(chart_bb)
	_bench_rendering = false

# kor mykje av breidda som er att til sjølve søyla. Fast kolonnetabell + breidde
# etter panelstorleik gjer at chartet fyller breidda i staden for å flyte i ho.
# rekneskapen er målt i fontstorleikar: merkelapp ~3.3×, tala ~8.4×, ×-kolonne
# ~5.4× og tre kolonnemellomrom ~2.6× = ~19.7×, pluss margin og glød = 24×.
func _bench_bar_width() -> int:
	var w: float = bench_display.size.x
	if w < 360.0:
		w = 980.0                            # fanen er skjult/enno ikkje teikna
	var chrome: float = 24.0 * BENCH_FS
	return clampi(int((w - chrome) / float(BENCH_FS)), BAR_MIN, BAR_MAX)

# Dra i panelet → ny breidde → nytt rutenett. Forstyrra-timer slik at chartet
# berre blir teikna ein gong etter at brukaren slepp kanten (og ikkje inne i
# signalkøyringa som storleiksendringa sjølv utløyser).
func _on_bench_display_resized() -> void:
	if _bench_raw.is_empty() or _bench_rendering or _bench_bar_width() == _bench_bar_w:
		return
	if _bench_resize_timer == null:
		_bench_resize_timer = Timer.new()
		_bench_resize_timer.one_shot = true
		_bench_resize_timer.wait_time = 0.2
		_bench_resize_timer.timeout.connect(_render_bench)
		add_child(_bench_resize_timer)
	_bench_resize_timer.start()

func _bench_bar(g_val, k_val, scale_max, bar_w: int) -> String:
	## Samanslått bar: blå = CodeGraph sin verdi, raud rest = det konkurrenten kosta i
	## tillegg, demt = resten av skalaen. Heile søyla er ALLTID bar_w stk av same
	## blokkteikn: standardfonten har breidde = fontstorleik på █, men berre 5 px på
	## · og mellomrom - difor flyt chartet om ein blandar teikna i ei søyle.
	var sc: float = max(float(scale_max), 1.0)
	var gc: int = clampi(int(round(float(g_val) / sc * bar_w)), 0, bar_w)
	var kc: int = clampi(int(round(float(k_val) / sc * bar_w)), 0, bar_w)
	if kc == 0 and float(k_val) > 0.0:
		kc = 1
	if gc == 0 and float(g_val) > 0.0:
		gc = 1
	var s = "[color=#4fb3ff]" + "█".repeat(kc) + "[/color]"
	if gc > kc:
		s += "[color=#ef767a]" + "█".repeat(gc - kc) + "[/color]"
	var rest: int = bar_w - max(gc, kc)
	if rest > 0:
		s += "[color=#26384a]" + "█".repeat(rest) + "[/color]"
	return s

# Ei rad i rutenettet: merkelapp | søyle | grep → CodeGraph | ×-faktor.
# Tabellceller gjer kolonnene aligned utan å telja teikn.
func _bench_cells(label: String, bar: String, gtxt: String, ktxt: String,
		unit: String, verdict: String, vcol: String) -> String:
	return ("[cell][color=#6d8296]%s[/color][/cell]"
		+ "[cell]%s[/cell]"
		+ "[cell][color=#7d93a8]%s →[/color] [color=#cfe3f5][b]%s[/b] %s[/color][/cell]"
		+ "[cell][color=%s][b]%s[/b][/color][/cell]") % [label, bar, gtxt, ktxt, unit, vcol, verdict]


func _format_bench_json_as_charts(json_text: String) -> String:
	var json = JSON.new()
	if json.parse(json_text) != OK or not (json.data is Array):
		return ""
	
	var rows = json.data
	if rows.is_empty():
		return "[color=#ffd166][b]%s[/b][/color]" % t("bench_empty_project")
	
	var is_no = (lang == "no")
	
	var out = "[color=#ffd166][font_size=16][b]%s[/b][/font_size][/color]\n" % t("bench_title")
	out += "[color=#6d8296]%s [url=res://.codegraph/bench.json][color=#4fb3ff].codegraph/bench.json[/color][/url] · [url=res://.codegraph/bench.md][color=#4fb3ff]bench.md[/color][/url][/color]\n\n" % t("bench_saved")
	
	var total_grep_tok = 0
	var total_kg_tok = 0
	var total_grep_ms = 0.0
	var total_kg_ms = 0.0
	var won = 0
	
	for r in rows:
		total_grep_tok += int(r.get("grep_dugleg_token", 0))
		total_kg_tok += int(r.get("graf_token", 0))
		total_grep_ms += float(r.get("grep_dugleg_ms", 0.0))
		total_kg_ms += float(r.get("graf_ms_varm", 0.0))
		if int(r.get("graf_token", 0)) <= int(r.get("grep_dugleg_token", 0)):
			won += 1
	
	# KPI: det som slår er ×-faktoren, ikkje prosentane
	var time_factor = total_grep_ms / max(total_kg_ms, 0.001)
	out += "[table=3]"
	out += "[cell][color=#ffd166][b]%s[/b][/color]\n[color=#8ce56c][font_size=26][b]×%.1f[/b][/font_size][/color]\n[color=#6d8296]%s[/color][/cell]" % [t("bench_time"), time_factor, t("bench_time_detail") % [total_kg_ms, total_grep_ms]]
	out += "[cell][color=#ffd166][b]%s[/b][/color]\n[color=#8ce56c][font_size=26][b]−%d %%[/b][/font_size][/color]\n[color=#6d8296]%s[/color][/cell]" % [t("bench_tokens"), int(round(100.0 * (total_grep_tok - total_kg_tok) / max(total_grep_tok, 1))), t("bench_tokens_detail") % [total_kg_tok, total_grep_tok]]
	out += "[cell][color=#ffd166][b]%s[/b][/color]\n[color=#4fb3ff][font_size=26][b]%d / %d[/b][/font_size][/color]\n[color=#6d8296]%s[/color][/cell]" % [t("bench_won"), won, rows.size(), t("bench_won_detail")]
	out += "[/table]\n\n"
	
	# Éi felles skala per metrikk: då kan auga samanlikne oppgåvene.
	# Blå bit = det CodeGraph brukte, raud rest = det grep kosta i tillegg.
	var bar_w = _bench_bar_width()
	_bench_bar_w = bar_w
	var max_tok = 1
	var max_ms = 1.0
	for r in rows:
		max_tok = max(max_tok, max(int(r.get("grep_dugleg_token", 0)), int(r.get("graf_token", 0))))
		max_ms = max(max_ms, max(float(r.get("grep_dugleg_ms", 0.0)), float(r.get("graf_ms_varm", 0.0))))
	out += ("[color=#4fb3ff]█[/color][color=#6d8296] %s   [color=#ef767a]█[/color] %s   "
			+ "[color=#26384a]█[/color] %s[/color]\n[color=#6d8296][i]%s · %s[/i][/color]\n\n") % [
			t("bench_kg"), t("bench_extra"), t("bench_track"), t("bench_scale"), t("bench_values")]

	for r in rows:
		var id = int(r.get("id", 0))
		var spm = r.get("spm", "")
		if is_no:
			if r.has("spm_no") and not str(r.get("spm_no")).is_empty():
				spm = str(r.get("spm_no"))
			elif TASK_NAMES_NO.has(id):
				spm = TASK_NAMES_NO[id]
		var g_tok = int(r.get("grep_dugleg_token", 0))
		var k_tok = int(r.get("graf_token", 0))
		var g_ms = float(r.get("grep_dugleg_ms", 0.0))
		var k_ms = float(r.get("graf_ms_varm", 0.0))
		var speed = g_ms / max(k_ms, 0.01)
		var win: bool = k_tok <= g_tok
		var fast: bool = speed >= 1.0
		var tcol: String = "#8ce56c" if win else "#ef767a"
		var mcol: String = "#8ce56c" if fast else "#ef767a"
		var v_tok: String = (t("bench_x_fewer") % [float(g_tok) / max(k_tok, 1)]) if win \
			else (t("bench_x_more") % [float(k_tok) / max(g_tok, 1)])
		var v_ms: String = (t("bench_x_faster") % [speed]) if fast \
			else (t("bench_x_slower") % [1.0 / max(speed, 0.001)])
		out += "[color=%s][b]%s[/b][/color]  [color=#cfe3f5][b]#%d[/b]  %s[/color]\n" % [tcol, "✓" if win else "✗", id, spm]
		out += "[table=4]"
		out += _bench_cells(t("bench_m_tokens"), _bench_bar(g_tok, k_tok, max_tok, bar_w),
			str(g_tok), str(k_tok), "t", v_tok, tcol)
		out += _bench_cells(t("bench_m_time"), _bench_bar(g_ms, k_ms, max_ms, bar_w),
			"%.1f" % g_ms, "%.1f" % k_ms, "ms", v_ms, mcol)
		out += "[/table]\n\n"
	
	# TOTALT: same rutenett, men summen av alle oppgåvene - difor eigen skala.
	var win_tot: bool = total_kg_tok <= total_grep_tok
	out += "[color=#ffd166][b]%s[/b]  [color=#6d8296][i]%s[/i][/color]\n" % [t("bench_total"), t("bench_total_note")]
	out += "[table=4]"
	out += _bench_cells(t("bench_m_tokens"), _bench_bar(total_grep_tok, total_kg_tok, total_grep_tok, bar_w),
		str(total_grep_tok), str(total_kg_tok), "t",
		(t("bench_x_fewer") % [float(total_grep_tok) / max(total_kg_tok, 1)]) if win_tot \
			else (t("bench_x_more") % [float(total_kg_tok) / max(total_grep_tok, 1)]),
		"#8ce56c" if win_tot else "#ef767a")
	out += _bench_cells(t("bench_m_time"), _bench_bar(total_grep_ms, total_kg_ms, total_grep_ms, bar_w),
		"%.1f" % total_grep_ms, "%.1f" % total_kg_ms, "ms",
		t("bench_x_faster") % [total_grep_ms / max(total_kg_ms, 0.001)], "#8ce56c")
	out += "[/table]\n"
	return out

func _on_open_json_pressed() -> void:
	var json_path = ProjectSettings.globalize_path("res://.codegraph/bench.json")
	if FileAccess.file_exists("res://.codegraph/bench.json"):
		OS.shell_open(json_path)
	else:
		bench_status.text = "No bench.json found yet. Run benchmark first!"

func _run_codegraph(subargs: Array[String]) -> void:
	status_label.text = t("indexing")
	output_display.clear()
	
	var root_dir = ProjectSettings.globalize_path("res://")
	var full_args = [backend_path, "--path", root_dir]
	full_args.append_array(subargs)
	
	var output_array: Array = []
	var start_time = Time.get_ticks_msec()
	var exit_code = OS.execute(python_cmd, full_args, output_array, true)
	var elapsed = Time.get_ticks_msec() - start_time
	
	if exit_code != 0 and output_array.is_empty():
		status_label.text = "Feil ved kjøring (kode %d)" % exit_code
		return
	
	var raw_output = output_array[0] if not output_array.is_empty() else ""
	var formatted_bbcode = _format_output_as_bbcode(raw_output)
	
	output_display.append_text(formatted_bbcode)
	status_label.text = t("done_ms") % [elapsed, exit_code]

# --- Styling & BBCode Formattering i Look & Feel ---
func _format_output_as_bbcode(raw: String) -> String:
	var bb = raw.replace("[", "[lb]").replace("]", "[rb]")
	
	for kind in KIND_COLORS.keys():
		var col = KIND_COLORS[kind]
		bb = bb.replace(kind + " ", "[color=" + col + "][b]" + kind + "[/b][/color] ")
		bb = bb.replace(kind + "\t", "[color=" + col + "][b]" + kind + "[/b][/color]\t")
	
	bb = bb.replace("[lb]rpc[rb]", "[color=#ffd166][b][rpc][/b][/color]")
	bb = bb.replace("[lb]export[rb]", "[color=#4fb3ff][b][export][/b][/color]")
	
	var file_regex = RegEx.new()
	file_regex.compile(r"([A-Za-z0-9_\-\./]+\.(?:gd|tscn|tres)):([0-9]+)")
	
	var result = ""
	var last_idx = 0
	for m in file_regex.search_all(bb):
		result += bb.substr(last_idx, m.get_start() - last_idx)
		var file_path = m.get_string(1)
		var line_num = m.get_string(2)
		var full_match = m.get_string(0)
		result += "[url=res://%s#%s][color=#4fb3ff]%s[/color][/url]" % [file_path, line_num, full_match]
		last_idx = m.get_end()
	
	result += bb.substr(last_idx)
	return result

func _on_meta_clicked(meta: Variant) -> void:
	var link = str(meta)
	if "#" in link:
		var parts = link.split("#")
		var file_path = parts[0]
		var line_num = parts[1].to_int()
		
		if file_path.ends_with(".tscn"):
			if EditorInterface.has_method("open_scene_from_path"):
				EditorInterface.open_scene_from_path(file_path)
		else:
			var script = load(file_path)
			if script and EditorInterface.has_method("edit_script"):
				EditorInterface.edit_script(script, line_num)
	else:
		OS.shell_open(link)

# --- Autocomplete funksjonalitet ---
func _load_symbol_cache() -> void:
	symbol_cache.clear()
	var json_path = "res://.codegraph/symbols.json"
	if FileAccess.file_exists(json_path):
		var content_str = FileAccess.get_file_as_string(json_path)
		var json = JSON.new()
		if json.parse(content_str) == OK and json.data is Array:
			for item in json.data:
				symbol_cache.append(item)
			return
	
	# Fallback: backenden eig symbolformatet, så be han om det - aldri SQL her.
	if not FileAccess.file_exists("res://.codegraph/graph.db"):
		return
	var out: Array = []
	var args = [backend_path, "--path", ProjectSettings.globalize_path("res://"), "symbols", "--limit", "4000"]
	var ec = OS.execute(python_cmd, args, out, true)
	if ec == 0 and not out.is_empty():
		var json2 = JSON.new()
		if json2.parse(out[0]) == OK and json2.data is Array:
			for item in json2.data:
				symbol_cache.append(item)

# --- Autocomplete: felles for båe tekstfelta (søk og nabolag) ---
# Same symbolcache, same rekkjefølgje på forslaga og same inline-markering.
# Berre kva felt som får tekstet, og kva som skjer ved klikk, er ulikt.
func _on_search_input_gui_input(event: InputEvent) -> void:
	_acc_key(search_input, autocomplete_list, autocomplete_box, event)

func _on_ego_input_gui_input(event: InputEvent) -> void:
	_acc_key(ego_input, ego_acc_list, ego_acc_box, event)

# TAB/HØGRE tek forslaget, PIL NED hoppar ned i lista, ESC skjuler ho.
func _acc_key(field: LineEdit, list: ItemList, box: PanelContainer, event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_TAB:
		if field.has_selection() or (box.visible and list.item_count > 0):
			accept_event()
			_acc_take_inline(field, box)
	elif event.keycode == KEY_RIGHT:
		if field.has_selection():
			_acc_take_inline(field, box)
	elif event.keycode == KEY_DOWN and box.visible:
		accept_event()
		list.grab_focus()
		if list.item_count > 0:
			list.select(0)
	elif event.keycode == KEY_ESCAPE:
		box.visible = false
		field.deselect()

func _acc_take_inline(field: LineEdit, box: PanelContainer) -> void:
	field.deselect()
	field.caret_column = field.text.length()
	box.visible = false
	_acc_state[field] = field.text

func _on_search_text_changed(new_text: String) -> void:
	_acc_update(search_input, autocomplete_list, autocomplete_box)
	if new_text.strip_edges().is_empty():
		_reset_search_results()

# X-knappen (eller backspace heilt ut) skal ta med svaret som står att. Utan dette
# blir det ståande eit svar frå før, og brukaren trudar det er svaret på det tomme feltet.
func _reset_search_results() -> void:
	if not is_instance_valid(output_display):
		return
	# Svaret blir lagt til med append_text(), og då er .text framleis tom - det er
	# get_parsed_text() som held på det som faktisk står på skjermen.
	if output_display.get_parsed_text().is_empty():
		return
	output_display.clear()
	status_label.text = t("enter_term")

func _on_ego_text_changed(_new_text: String) -> void:
	_acc_update(ego_input, ego_acc_list, ego_acc_box)

func _acc_update(field: LineEdit, list: ItemList, box: PanelContainer) -> void:
	if _acc_busy.get(field, false):
		return
	
	var raw = field.text.strip_edges()
	var prev = String(_acc_state.get(field, ""))
	var is_backspace = raw.length() < prev.length()
	_acc_state[field] = raw
	if raw.length() < 2 or symbol_cache.is_empty():
		box.visible = false
		return
	
	var q = raw.to_lower()
	var prefix_matches: Array[Dictionary] = []
	var other_matches: Array[Dictionary] = []
	for sym in symbol_cache:
		var name_str = sym.get("n", "")
		var lower_name = name_str.to_lower()
		if lower_name.begins_with(q):
			prefix_matches.append(sym)
			if prefix_matches.size() >= 10:
				break
		elif q in lower_name and other_matches.size() < 6:
			other_matches.append(sym)
	
	var all_matches: Array[Dictionary] = []
	all_matches.append_array(prefix_matches)
	if all_matches.size() < 8:
		all_matches.append_array(other_matches)
	
	if all_matches.is_empty():
		box.visible = false
		return
	
	list.clear()
	for sym in all_matches:
		var k = sym.get("k", "fn")
		var nm = sym.get("n", "")
		list.add_item("[%s]  %s" % [k, nm])
	
	box.visible = true
	
	# Inline auto-completion rett i tekstfeltet med markert forslag
	if not is_backspace and prefix_matches.size() > 0:
		var top_name = prefix_matches[0].get("n", "")
		if top_name.to_lower().begins_with(q) and top_name.length() > raw.length():
			_acc_busy[field] = true
			field.text = top_name
			field.select(raw.length(), top_name.length())
			field.caret_column = raw.length()
			_acc_busy[field] = false

func _on_autocomplete_selected(index: int) -> void:
	_acc_pick(search_input, autocomplete_list, autocomplete_box, index)
	_on_search_pressed()

# Nabolagsfeltet: eit klikk fyller berre feltet. Han opnar ikkje nettlesaren
# av seg sjølv - brukaren trykkar sjølv på Open Neighborhood.
func _on_ego_acc_selected(index: int) -> void:
	_acc_pick(ego_input, ego_acc_list, ego_acc_box, index)
	ego_input.grab_focus()

func _acc_pick(field: LineEdit, list: ItemList, box: PanelContainer, index: int) -> void:
	var item_text = list.get_item_text(index)
	if "]  " in item_text:
		field.text = item_text.split("]  ")[1]
	elif "] " in item_text:
		field.text = item_text.split("] ")[1]
	else:
		field.text = item_text
	field.deselect()
	field.caret_column = field.text.length()
	box.visible = false
	_acc_state[field] = field.text

func _on_ego_submitted(_text: String) -> void:
	_on_open_ego_pressed()

# --- Agentopplæring: la agenten i prosjektet vite at CodeGraph finst ---
# Bakenden eig alt innhaldet (med tala frå dette prosjektet) og skriv berre
# inne i merka blokker. Editoren skriv difor aldri brukaren sin eigen tekst.
func _agents_installed() -> bool:
	if not FileAccess.file_exists("res://AGENTS.md"):
		return false
	return "BEGIN CODEGRAPH" in FileAccess.get_file_as_string("res://AGENTS.md")

func _teach_button_text() -> void:
	if teach_agents_button:
		teach_agents_button.text = t("btn_teach_installed") if _agents_installed() else t("agent_teach")

# Begge toggleane (søkefeltet + agentfana) speglar tilstanden på disken, så
# brukaren får same svar uansett kvar han slår av/på.
func _sync_agent_checks() -> void:
	var installed: bool = _agents_installed()
	for c in [agent_teach, agents_toggle]:
		if c:
			c.set_block_signals(true)
			c.button_pressed = installed
			c.set_block_signals(false)
	if agents_state_label:
		agents_state_label.text = t("agents_state_on") if installed else t("agents_state_off")
		agents_state_label.add_theme_color_override("font_color",
			C_OK if installed else C_DIM)
	_teach_button_text()

func _teach_agents(on: bool) -> bool:
	var args = [backend_path, "--path", ProjectSettings.globalize_path("res://"), "agents",
			"--install" if on else "--remove", "--tools", "claude,copilot,cursor"]
	var out: Array = []
	var ec = OS.execute(python_cmd, args, out, true)
	if ec == 0:
		status_label.text = t("agents_on") if on else t("agents_off")
	else:
		status_label.text = t("agents_fail") + " " + str(ec) + (" " + " ".join(out) if out else "")
	_sync_agent_checks()
	return ec == 0

func _on_agent_teach(on: bool) -> void:
	if python_ok:
		_teach_agents(on)

func _on_agents_toggle(on: bool) -> void:
	if python_ok:
		_teach_agents(on)

func _on_teach_pressed() -> void:
	if python_ok:
		_teach_agents(true)

# tel GDScript-filer i same omfang som indeksen brukar (addons/ og skjulte
# mapper ute) - det er talet som avgjer om ytelsestesten er verdt å køyrde først.
func _count_gd(dir_path: String, depth: int) -> int:
	if depth > 12:
		return 0
	var d = DirAccess.open(dir_path)
	if d == null:
		return 0
	var n = 0
	d.list_dir_begin()
	var fname = d.get_next()
	while fname != "":
		if not fname.begins_with("."):
			if d.current_is_dir():
				if fname != "addons":
					n += _count_gd(dir_path.path_join(fname), depth + 1)
			elif fname.ends_with(".gd"):
				n += 1
		if n > 4000:
			break
		fname = d.get_next()
	d.list_dir_end()
	return n

func _refresh_project_size_hint() -> void:
	if agents_size_label == null or agents_warn_label == null:
		return
	var n = _count_gd("res://", 0)
	agents_size_label.text = t("scripts_count") % n
	if n < SMALL_PROJECT_LIMIT:
		agents_warn_label.add_theme_color_override("default_color", C_HOT)
		agents_warn_label.text = t("agents_small_warn")
	else:
		agents_warn_label.add_theme_color_override("default_color", C_DIM)
		agents_warn_label.text = t("agents_big_hint")

func _plugin_version() -> String:
	var cfg = ConfigFile.new()
	if cfg.load("res://addons/codegraph/plugin.cfg") != OK:
		return ""
	return str(cfg.get_value("plugin", "version", ""))

# Versjonstalet i faktatabellen og i About-teksten blir sett når editoren startar.
# Etter ein installasjon er fila på disken ei anna, så her må vi lese henne på
# nytt - elles står det «1.1.4» medan pluginen på disken allereie er 1.1.5, heilt
# til brukaren lastar prosjektet på nytt.
func _refresh_version_labels() -> void:
	var ver: String = _plugin_version()
	if val_plugin:
		val_plugin.text = ver
		val_plugin.add_theme_color_override("font_color", C_INK)
	if about_text:
		about_text.text = t("about_text") % ver

func _on_repo_pressed() -> void:
	OS.shell_open(REPO_URL)

func _on_issues_pressed() -> void:
	OS.shell_open(REPO_URL + "/issues/new")

# Same staden som chartet: brukaren ser tala med ein gong han er der.
func _on_bench_from_agents_pressed() -> void:
	main_tabs.current_tab = 1
	if python_ok:
		_on_bench_pressed()

# Docken kan endre storlek medan fanelinja ligg att: då flyttar vi merket med.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_position_badge()
