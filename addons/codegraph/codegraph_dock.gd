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

# --- Lokalisering (i18n) ---
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
		"welcome_title": "Welcome to CodeGraph",
		"welcome_desc": "Your project has not been indexed yet. Initial indexing takes only a few seconds and enables instant symbol navigation, scene signal wires, and @rpc mapping.",
		"btn_index_now": "⚡ Build Initial Index",
		"ready": "CodeGraph ready. Select a mode and search.",
		"indexing": "Indexing in progress...",
		"bench_running": "Running real-world benchmark against grep...",
		"done_ms": "Completed in %d ms (exit %d)",
		"err_python": "Warning: Python 3 was not found in PATH. Please install Python 3.",
		"enter_term": "Please enter a search term."
	},
	"no": {
		"tab_search": "🔍 Søk & Utforsk",
		"tab_bench": "📊 Ytelsestest & Diagram",
		"mode_find": "Finn symbol (find)",
		"mode_outline": "Oversikt over fil/autoload (outline)",
		"mode_callers": "Hvem kaller (callers)",
		"mode_signal": "Signalsporing (signal)",
		"mode_rpc": "Nettverkskall (@rpc)",
		"mode_impact": "Konsekvensanalyse (impact)",
		"mode_deps": "Avhengigheter (deps)",
		"mode_status": "Status & tellere (status)",
		"hint_find": "Søk etter funksjon, signal, klasse eller variabel...",
		"hint_outline": "Navn på script, klasse eller autoload...",
		"hint_callers": "Navn på funksjon som blir kalt...",
		"hint_signal": "Navn på signal...",
		"hint_rpc": "Valgfritt filter for RPC-funksjoner...",
		"hint_impact": "Symbol eller klasse du vil sjekke påvirkning av...",
		"hint_deps": "Filsti for å se avhengigheter...",
		"hint_status": "Trykk Søk for status",
		"btn_search": "Søk",
		"btn_visual_graph": "🌐 Web-graf",
		"btn_reindex": "🔄 Reindeks",
		"btn_run_bench": "▶ Kjør ytelsestest på dette prosjektet",
		"btn_open_json": "📄 Åpne bench.json",
		"welcome_title": "Velkommen til CodeGraph",
		"welcome_desc": "Dette prosjektet er ikke indeksert ennå. Første indeksering tar bare noen sekunder og gir deg lynrask kode- og signalnavigasjon.",
		"btn_index_now": "⚡ Bygg indeks nå",
		"ready": "CodeGraph klar. Velg modus og skriv søkeord.",
		"indexing": "Indekserer prosjektet...",
		"bench_running": "Kjører ytelsestest mot grep...",
		"done_ms": "Ferdig på %d ms (exit %d)",
		"err_python": "Advarsel: Python 3 ble ikke funnet i PATH. Installer Python 3.",
		"enter_term": "Vennligst skriv inn et søkeord."
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
@onready var status_label: Label = %StatusLabel
@onready var output_display: RichTextLabel = %OutputDisplay
@onready var autocomplete_popup: PopupPanel = %AutocompletePopup
@onready var autocomplete_list: ItemList = %AutocompleteList
@onready var search_progress: ProgressBar = %SearchProgress

# Benchmarkfane
@onready var bench_button: Button = %BenchButton
@onready var open_json_button: Button = %OpenJsonButton
@onready var bench_status: Label = %BenchStatus
@onready var bench_display: RichTextLabel = %BenchDisplay
@onready var bench_progress: ProgressBar = %BenchProgress

var python_cmd: String = "python"
var backend_path: String = ""
var symbol_cache: Array[Dictionary] = []
var index_thread: Thread = null
var poll_timer: Timer = null

func _ready() -> void:
	_detect_language()
	_init_python()
	_setup_ui()
	_check_indexed_state()
	_load_existing_bench_chart()

func _detect_language() -> void:
	lang = "en"
	if Engine.is_editor_hint():
		var settings = EditorInterface.get_editor_settings()
		if settings:
			var editor_lang = str(settings.get_setting("interface/editor/editor_language"))
			if editor_lang.begins_with("no") or editor_lang.begins_with("nb") or editor_lang.begins_with("nn"):
				lang = "no"

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
			return
	status_label.text = t("err_python")

func _setup_ui() -> void:
	# Tab titler
	main_tabs.set_tab_title(0, t("tab_search"))
	main_tabs.set_tab_title(1, t("tab_bench"))
	
	# Velkomstskjerm
	welcome_title.text = t("welcome_title")
	welcome_desc.text = t("welcome_desc")
	index_now_button.text = t("btn_index_now")
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
	mode_option.clear()
	var modes = ["find", "outline", "callers", "signal", "rpc", "impact", "deps", "status"]
	for m in modes:
		mode_option.add_item(t("mode_" + m))
	
	mode_option.item_selected.connect(_on_mode_selected)
	search_button.pressed.connect(_on_search_pressed)
	search_input.text_submitted.connect(func(_text): _on_search_pressed())
	search_input.text_changed.connect(_on_search_text_changed)
	html_button.pressed.connect(_on_html_pressed)
	reindex_button.pressed.connect(_on_reindex_pressed)
	bench_button.pressed.connect(_on_bench_pressed)
	open_json_button.pressed.connect(_on_open_json_pressed)
	output_display.meta_clicked.connect(_on_meta_clicked)
	bench_display.meta_clicked.connect(_on_meta_clicked)
	
	# Autocomplete setup
	autocomplete_list.item_selected.connect(_on_autocomplete_selected)
	
	_on_mode_selected(0)

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
	autocomplete_popup.hide()
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
	var out: Array = []
	status_label.text = t("indexing")
	var root_dir = ProjectSettings.globalize_path("res://")
	OS.execute(python_cmd, [backend_path, "--path", root_dir, "html", "--open"], out, true)
	status_label.text = "HTML-graf åpnet i nettleser."

# --- Benchmark & Visuelle Diagrammer ---
func _on_bench_pressed() -> void:
	bench_status.text = t("bench_running")
	bench_display.clear()
	bench_progress.visible = true
	bench_button.disabled = true
	
	var root_dir = ProjectSettings.globalize_path("res://")
	var bench_py = ProjectSettings.globalize_path("res://tools/codegraph/bench.py")
	if not FileAccess.file_exists(bench_py):
		bench_py = ProjectSettings.globalize_path("res://addons/codegraph/backend/bench.py")
	
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
		return ""
	
	var out = "[color=#ffd166][font_size=16][b]═══ BENCHMARK RESULTATER & DIAGRAM ═══[/b][/font_size][/color]\n"
	out += "[color=#6d8296]Lagret automatisk til: [url=res://.codegraph/bench.json][color=#4fb3ff].codegraph/bench.json[/color][/url] · [url=res://.codegraph/bench.md][color=#4fb3ff]bench.md[/color][/url][/color]\n\n"
	
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
	out += "[cell][color=#ffd166][b]⚡ SPART TID[/b][/color]\n[color=#8ce56c][font_size=16][b]%d%% raskere[/b][/font_size][/color]\n[color=#6d8296]%.1f ms mot %.1f ms[/color][/cell]" % [time_saved_pct, total_kg_ms, total_grep_ms]
	out += "[cell][color=#ffd166][b]🪙 SPART TOKENS[/b][/color]\n[color=#8ce56c][font_size=16][b]%d%% færre[/b][/font_size][/color]\n[color=#6d8296]%d mot %d tokens[/color][/cell]" % [token_saved_pct, total_kg_tok, total_grep_tok]
	out += "[cell][color=#ffd166][b]🏆 KVALITET / VUNNET[/b][/color]\n[color=#4fb3ff][font_size=16][b]%d av %d oppgaver[/b][/font_size][/color]\n[color=#6d8296]Presise referanser[/color][/cell]" % [won, rows.size()]
	out += "[/table]\n\n"
	out += "[color=#1d2b3a]──────────────────────────────────────────────────────────────────────────────[/color]\n\n"
	
	# Visuelle søyler per oppgave
	for r in rows:
		var spm = r.get("spm", "")
		var id = r.get("id", 0)
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
		
		var win_badge = "[color=#8ce56c][b]✓ CodeGraph vinner (" + str(ratio) + "×)[/b][/color]" if k_tok <= g_tok else "[color=#ef767a][b]Grep vinner[/b][/color]"
		
		out += "[b][color=#cfe3f5]#%d %s[/color][/b]  %s\n" % [id, spm, win_badge]
		out += "  [color=#6d8296]Grep (dyktig):[/color] [color=#ef767a]%s[/color] [color=#cfe3f5]%d t[/color] [color=#6d8296](%.1f ms)[/color]\n" % [g_bar_str, g_tok, g_ms]
		out += "  [color=#4fb3ff]CodeGraph:    [/color] [color=#4fb3ff]%s[/color] [color=#cfe3f5]%d t[/color] [color=#6d8296](%.1f ms)[/color]\n\n" % [k_bar_str, k_tok, k_ms]
	
	return out

func _on_open_json_pressed() -> void:
	var json_path = ProjectSettings.globalize_path("res://.codegraph/bench.json")
	if FileAccess.file_exists("res://.codegraph/bench.json"):
		OS.shell_open(json_path)
	else:
		bench_status.text = "Ingen bench.json funnet ennå. Kjør testen først!"

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
	var root_dir = ProjectSettings.globalize_path("res://")
	var out: Array = []
	var py_script = "import sqlite3, json, sys; con = sqlite3.connect('.codegraph/graph.db'); rows = con.execute('SELECT DISTINCT name, kind FROM nodes WHERE kind IN (\"class\",\"fn\",\"signal\",\"autoload\") LIMIT 3500').fetchall(); print(json.dumps([{'n':r[0],'k':r[1]} for r in rows]))"
	var ec = OS.execute(python_cmd, ["-c", py_script], out, true)
	if ec == 0 and not out.is_empty():
		var json = JSON.new()
		if json.parse(out[0]) == OK and json.data is Array:
			for item in json.data:
				symbol_cache.append(item)

func _on_search_text_changed(new_text: String) -> void:
	var q = new_text.strip_edges().to_lower()
	if q.length() < 2 or symbol_cache.is_empty():
		autocomplete_popup.hide()
		return
	
	autocomplete_list.clear()
	var hits = 0
	for sym in symbol_cache:
		var name_str = sym.get("n", "")
		if q in name_str.to_lower():
			var k = sym.get("k", "fn")
			var display_text = "[%s] %s" % [k, name_str]
			autocomplete_list.add_item(display_text)
			hits += 1
			if hits >= 10:
				break
	
	if hits > 0:
		var pos = search_input.global_position + Vector2(0, search_input.size.y + 4)
		autocomplete_popup.position = Vector2i(int(pos.x), int(pos.y))
		autocomplete_popup.size = Vector2i(int(search_input.size.x), min(hits * 28 + 10, 240))
		autocomplete_popup.show()
	else:
		autocomplete_popup.hide()

func _on_autocomplete_selected(index: int) -> void:
	var item_text = autocomplete_list.get_item_text(index)
	if "] " in item_text:
		var parts = item_text.split("] ")
		search_input.text = parts[1]
	else:
		search_input.text = item_text
	autocomplete_popup.hide()
	_on_search_pressed()
