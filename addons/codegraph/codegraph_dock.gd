@tool
extends Control

@onready var search_input: LineEdit = %SearchInput
@onready var mode_option: OptionButton = %ModeOption
@onready var search_button: Button = %SearchButton
@onready var html_button: Button = %HtmlButton
@onready var reindex_button: Button = %ReindexButton
@onready var status_label: Label = %StatusLabel
@onready var output_display: RichTextLabel = %OutputDisplay

var python_cmd: String = "python"
var backend_path: String = ""

const MODES = [
	{"name": "Finn symbol (find)", "cmd": "find", "hint": "Søk etter funksjon, signal, klasse eller variabel..."},
	{"name": "Oversikt over fil/autoload (outline)", "cmd": "outline", "hint": "Navn på script, klasse eller autoload..."},
	{"name": "Hvem kaller (callers)", "cmd": "callers", "hint": "Navn på funksjon som blir kalt..."},
	{"name": "Signalsporing (signal)", "cmd": "signal", "hint": "Navn på signal..."},
	{"name": "Nettverkskall (@rpc)", "cmd": "rpc", "hint": "Valgfritt filter for RPC-funksjoner..."},
	{"name": "Konsekvensanalyse (impact)", "cmd": "impact", "hint": "Symbol eller klasse du vil sjekke påvirkning av..."},
	{"name": "Avhengigheter (deps)", "cmd": "deps", "hint": "Filsti for å se avhengigheter..."},
	{"name": "Status & teller (status)", "cmd": "status", "hint": "Trykk Søk for status"}
]

func _ready() -> void:
	_init_python()
	_setup_ui()

func _init_python() -> void:
	backend_path = ProjectSettings.globalize_path("res://addons/codegraph/backend/graph.py")
	# Sjekk python-tilgjengelighet
	var test_out: Array = []
	for candidate in ["python", "python3", "py"]:
		var exit_code = OS.execute(candidate, ["--version"], test_out, true)
		if exit_code == 0:
			python_cmd = candidate
			return
	status_label.text = "Advarsel: Python ble ikke funnet i PATH. Installer Python 3 for å bruke CodeGraph."

func _setup_ui() -> void:
	mode_option.clear()
	for m in MODES:
		mode_option.add_item(m["name"])
	
	mode_option.item_selected.connect(_on_mode_selected)
	search_button.pressed.connect(_on_search_pressed)
	search_input.text_submitted.connect(func(_text): _on_search_pressed())
	html_button.pressed.connect(_on_html_pressed)
	reindex_button.pressed.connect(_on_reindex_pressed)
	output_display.meta_clicked.connect(_on_meta_clicked)
	
	_on_mode_selected(0)

func _on_mode_selected(idx: int) -> void:
	if idx >= 0 and idx < MODES.size():
		search_input.placeholder_text = MODES[idx]["hint"]

func _on_search_pressed() -> void:
	var idx = mode_option.selected
	var cmd = MODES[idx]["cmd"]
	var arg = search_input.text.strip_edges()
	
	if cmd != "status" and cmd != "rpc" and arg.is_empty():
		status_label.text = "Vennligst skriv inn et søkeord."
		return
	
	var args: Array[String] = [cmd]
	if not arg.is_empty():
		args.append(arg)
	
	_run_codegraph(args)

func _on_reindex_pressed() -> void:
	_run_codegraph(["index", "--force"])

func _on_html_pressed() -> void:
	var out: Array = []
	status_label.text = "Genererer HTML-graf..."
	var root_dir = ProjectSettings.globalize_path("res://")
	OS.execute(python_cmd, [backend_path, "--path", root_dir, "html", "--open"], out, true)
	status_label.text = "HTML-graf åpnet i nettleser."

func _run_codegraph(subargs: Array[String]) -> void:
	status_label.text = "Kjører oppslag..."
	output_display.clear()
	
	var root_dir = ProjectSettings.globalize_path("res://")
	var full_args = [backend_path, "--path", root_dir]
	full_args.append_array(subargs)
	
	var output_array: Array = []
	var start_time = Time.get_ticks_msec()
	var exit_code = OS.execute(python_cmd, full_args, output_array, true)
	var elapsed = Time.get_ticks_msec() - start_time
	
	if exit_code != 0 and output_array.is_empty():
		status_label.text = "Feil ved kjøring (kode %d). Sjekk at Python 3 er installert." % exit_code
		return
	
	var raw_output = output_array[0] if not output_array.is_empty() else ""
	var formatted_bbcode = _format_output_as_bbcode(raw_output)
	
	output_display.append_text(formatted_bbcode)
	status_label.text = "Ferdig på %d ms (exit %d)" % [elapsed, exit_code]

func _format_output_as_bbcode(raw: String) -> String:
	# Konverter filbaner til klikkbare lenker
	var bb = raw.replace("[", "[lb]").replace("]", "[rb]")
	
	# Regex for å fange filstier med linjenummer f.eks. scripts/player/PlayerController.gd:123
	var file_regex = RegEx.new()
	file_regex.compile(r"([A-Za-z0-9_\-\./]+\.(?:gd|tscn|tres)):([0-9]+)")
	
	var result = ""
	var last_idx = 0
	for match in file_regex.search_all(bb):
		result += bb.substr(last_idx, match.get_start() - last_idx)
		var file_path = match.get_string(1)
		var line_num = match.get_string(2)
		var full_match = match.get_string(0)
		result += "[url=res://%s#%s][color=#478cbf]%s[/color][/url]" % [file_path, line_num, full_match]
		last_idx = match.get_end()
	
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
