extends Node

signal state_changed(state: String)

var game_version := "4.8"


func set_state(s: String) -> void:
	state_changed.emit(s)
