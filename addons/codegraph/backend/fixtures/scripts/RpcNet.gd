extends Node

# RPC-annotasjon står på SI EGIE linje i GDScript, så flags må lesast baklengs.
@rpc("any_peer", "call_remote", "reliable")
func net_ping(from_id: int) -> void:
	add_to_group("bandits")
	remove_from_group("bandits")
	if is_in_group("bandits"):
		pass
	var mobb := get_nodes_in_group("bandits")
	var forste := get_first_node_in_group("bandits")
	call_group("bandits", "take_damage")


@rpc("authority", "call_local", "reliable")
func net_pong() -> void:
	net_ping(1)


func _ready() -> void:
	# motor-signal i KODE (same behandling som .tscn-koplingar)
	%UiButton.pressed.connect(_on_ui_pressed)


func _on_ui_pressed() -> void:
	net_ping(2)


func this_is_not_rpc() -> void:
	pass
