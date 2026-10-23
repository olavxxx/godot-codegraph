@tool
extends EditorPlugin

var dock_scene: PackedScene
var dock_instance: Control

func _enter_tree() -> void:
	dock_scene = preload("res://addons/codegraph/codegraph_dock.tscn")
	if dock_scene:
		dock_instance = dock_scene.instantiate()
		var icon = preload("res://addons/codegraph/icons/icon.svg")
		add_control_to_bottom_panel(dock_instance, "CodeGraph", icon)

func _exit_tree() -> void:
	if dock_instance:
		remove_control_from_bottom_panel(dock_instance)
		dock_instance.queue_free()
		dock_instance = null
