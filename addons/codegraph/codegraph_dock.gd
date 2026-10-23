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
		"bench_win_badge": "✓ CodeGraph wins (%s×)",
		"bench_lose_badge": "Grep wins"
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
		"bench_win_badge": "✓ CodeGraph vinner (%s×)",
		"bench_lose_badge": "Grep vinner"
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

var is_completing: bool = false
var last_typed: String = ""
@onready var search_progress: ProgressBar = %SearchProgress

# Benchmarkfane
@onready var bench_button: Button = %BenchButton
@onready var open_json_button: Button = %OpenJsonButton
@onready var bench_lang_button: Button = %BenchLangButton
@onready var bench_status: Label = %BenchStatus
@onready var bench_display: RichTextLabel = %BenchDisplay
@onready var bench_progress: ProgressBar = %BenchProgress

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
@onready var tips_label: Label = %TipsLabel

var python_cmd: String = "python"
var python_ok: bool = false
var backend_path: String = ""
var symbol_cache: Array[Dictionary] = []
var index_thread: Thread = null
var poll_timer: Timer = null
var html_thread: Thread = null
var html_timer: Timer = null
var html_view_name: String = ""

func _ready() -> void:
	_load_language_preference()
	_setup_ui()
	_init_python()
	_check_indexed_state()
	_load_existing_bench_chart()

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

func _init_python() -> void:
	backend_path = ProjectSettings.globalize_path("res://addons/codegraph/backend/graph.py")
	var test_out: Array = []
	for candidate in ["python", "python3", "py"]:
		var exit_code = OS.execute(candidate, ["--version"], test_out, true)
		if exit_code == 0:
			python_cmd = candidate
			python_ok = true
			_set_backend_enabled(true)
			return
	python_ok = false
	_set_backend_enabled(false)
	status_label.text = t("err_python") + "  " + t("python_install")

# Slår av alt som krev backenden, så brukaren får ei forklaring i staden for feil.
func _set_backend_enabled(on: bool) -> void:
	for b in [index_now_button, search_button, reindex_button, bench_button, html_button,
			open_files_button, open_signals_button, open_ego_button]:
		if b:
			b.disabled = not on

func _setup_ui() -> void:
	# Tab titler
	main_tabs.set_tab_title(0, t("tab_search"))
	main_tabs.set_tab_title(1, t("tab_bench"))
	main_tabs.set_tab_title(2, t("tab_graph"))
	
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
		if not ego_input.text_submitted.is_connected(func(_t): _on_open_ego_pressed()):
			ego_input.text_submitted.connect(func(_t): _on_open_ego_pressed())
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
	
	# Velkomstskjerm
	welcome_title.text = t("welcome_title")
	welcome_desc.text = t("welcome_desc")
	index_now_button.text = t("btn_index_now")
	if not index_now_button.pressed.is_connected(_on_index_now_pressed):
		index_now_button.pressed.connect(_on_index_now_pressed)
	welcome_progress.visible = false
	welcome_status.visible = false
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
	
	# Autocomplete setup
	if not autocomplete_list.item_selected.is_connected(_on_autocomplete_selected):
		autocomplete_list.item_selected.connect(_on_autocomplete_selected)
	
	_on_mode_selected(mode_option.selected)

func _on_search_submitted(_text: String) -> void:
	_on_search_pressed()

func _check_indexed_state() -> void:
	var db_path = ProjectSettings.globalize_path("res://.codegraph/graph.db")
	if FileAccess.file_exists(db_path):
		welcome_panel.visible = false
		main_tabs.visible = true
		_load_symbol_cache()
	else:
		welcome_panel.visible = true
		main_tabs.visible = false

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
	if FileAccess.file_exists(json_path):
		var text = FileAccess.get_file_as_string(json_path)
		var chart_bb = _format_bench_json_as_charts(text)
		if not chart_bb.is_empty():
			bench_display.clear()
			bench_display.append_text(chart_bb)

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
	
	var time_saved_pct = round(100.0 * (total_grep_ms - total_kg_ms) / max(total_grep_ms, 0.001))
	var token_saved_pct = round(100.0 * (total_grep_tok - total_kg_tok) / max(total_grep_tok, 0.001))
	
	# KPI Oppsummering
	out += "[table=3]"
	out += "[cell][color=#ffd166][b]%s[/b][/color]\n[color=#8ce56c][font_size=16][b]%s[/b][/font_size][/color]\n[color=#6d8296]%s[/color][/cell]" % [t("bench_time"), t("bench_time_sub") % time_saved_pct, t("bench_time_detail") % [total_kg_ms, total_grep_ms]]
	out += "[cell][color=#ffd166][b]%s[/b][/color]\n[color=#8ce56c][font_size=16][b]%s[/b][/font_size][/color]\n[color=#6d8296]%s[/color][/cell]" % [t("bench_tokens"), t("bench_tokens_sub") % token_saved_pct, t("bench_tokens_detail") % [total_kg_tok, total_grep_tok]]
	out += "[cell][color=#ffd166][b]%s[/b][/color]\n[color=#4fb3ff][font_size=16][b]%s[/b][/font_size][/color]\n[color=#6d8296]%s[/color][/cell]" % [t("bench_won"), t("bench_won_sub") % [won, rows.size()], t("bench_won_detail")]
	out += "[/table]\n\n"
	out += "[color=#1d2b3a]──────────────────────────────────────────────────────────────────────────────[/color]\n\n"
	
	# Visuelle søyler per oppgave
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
		var ratio = r.get("token_ratio", 1.0)
		
		var max_tok = max(g_tok, k_tok, 1)
		var bar_len = 26
		var g_bars = max(1, int(float(g_tok) / max_tok * bar_len))
		var k_bars = max(1, int(float(k_tok) / max_tok * bar_len))
		
		var g_bar_str = "█".repeat(g_bars)
		var k_bar_str = "█".repeat(k_bars)
		
		var win_badge = ("[color=#8ce56c][b]" + t("bench_win_badge") + "[/b][/color]") % str(ratio) if k_tok <= g_tok else ("[color=#ef767a][b]" + t("bench_lose_badge") + "[/b][/color]")
		
		out += "[b][color=#cfe3f5]#%d %s[/color][/b]  %s\n" % [id, spm, win_badge]
		out += "  [color=#6d8296]%s:[/color] [color=#ef767a]%s[/color] [color=#cfe3f5]%d t[/color] [color=#6d8296](%.1f ms)[/color]\n" % [t("bench_grep"), g_bar_str, g_tok, g_ms]
		out += "  [color=#4fb3ff]%s:    [/color] [color=#4fb3ff]%s[/color] [color=#cfe3f5]%d t[/color] [color=#6d8296](%.1f ms)[/color]\n\n" % [t("bench_kg"), k_bar_str, k_tok, k_ms]
	
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

func _on_search_input_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			if search_input.has_selection() or (autocomplete_box.visible and autocomplete_list.item_count > 0):
				accept_event()
				search_input.deselect()
				search_input.caret_column = search_input.text.length()
				autocomplete_box.visible = false
				last_typed = search_input.text
		elif event.keycode == KEY_RIGHT:
			if search_input.has_selection():
				search_input.deselect()
				search_input.caret_column = search_input.text.length()
				autocomplete_box.visible = false
		elif event.keycode == KEY_DOWN and autocomplete_box.visible:
			accept_event()
			autocomplete_list.grab_focus()
			if autocomplete_list.item_count > 0:
				autocomplete_list.select(0)
		elif event.keycode == KEY_ESCAPE:
			autocomplete_box.visible = false
			search_input.deselect()

func _on_search_text_changed(new_text: String) -> void:
	if is_completing:
		return
	
	var raw = new_text.strip_edges()
	if raw.length() < 2 or symbol_cache.is_empty():
		autocomplete_box.visible = false
		last_typed = raw
		return
	
	var q = raw.to_lower()
	var is_backspace = raw.length() < last_typed.length()
	last_typed = raw
	
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
		autocomplete_box.visible = false
		return
	
	autocomplete_list.clear()
	for sym in all_matches:
		var k = sym.get("k", "fn")
		var name_str = sym.get("n", "")
		var display_text = "[%s]  %s" % [k, name_str]
		autocomplete_list.add_item(display_text)
	
	autocomplete_box.visible = true
	
	# Inline auto-completion rett i tekstfeltet med markert forslag
	if not is_backspace and prefix_matches.size() > 0:
		var top_name = prefix_matches[0].get("n", "")
		if top_name.to_lower().begins_with(q) and top_name.length() > raw.length():
			is_completing = true
			search_input.text = top_name
			search_input.select(raw.length(), top_name.length())
			search_input.caret_column = raw.length()
			is_completing = false

func _on_autocomplete_selected(index: int) -> void:
	var item_text = autocomplete_list.get_item_text(index)
	if "]  " in item_text:
		var parts = item_text.split("]  ")
		search_input.text = parts[1]
	elif "] " in item_text:
		var parts = item_text.split("] ")
		search_input.text = parts[1]
	else:
		search_input.text = item_text
	search_input.deselect()
	search_input.caret_column = search_input.text.length()
	autocomplete_box.visible = false
	last_typed = search_input.text
	_on_search_pressed()
