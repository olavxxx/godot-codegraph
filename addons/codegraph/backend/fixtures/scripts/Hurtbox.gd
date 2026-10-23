extends Area2D

signal died


func _ready() -> void:
	add_to_group("enemies")
	Bus.spawn_vehicle("bike", Vector3.ZERO)
	call_group("enemies", "take_damage", 5)
	var steam = Engine.get_singleton("Steam")
	print(Time.get_ticks_msec())
