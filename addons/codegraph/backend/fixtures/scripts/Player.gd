class_name Player
extends BaseVehicle
## Fixture som treffer flest mulig parser-regler.

signal hp_changed(new_hp: int)

const MAX_HP := 100

enum Weapon { PISTOL, BAT }


class SaveSlot:
	var slot_name := ""
	var hp := 0


@export var speed := 10.0
@onready var hurtbox: Area2D = $Hurtbox

var _bullet_script = preload("res://scripts/Bullet.gd")


func _ready() -> void:
	hp_changed.connect(_on_hp_changed)
	get_node("Hurtbox/CollisionShape2D").set_visible(true)
	$Hurtbox/CollisionShape2D.modulate = Color.RED
	spawn_vehicle("car")


func spawn_vehicle(
		kind: String,
		extra: Dictionary = {}) -> void:
	var b = _bullet_script.new()
	add_child(b)


func take_damage(n: int) -> void:
	hp_changed.emit(n)


func on_enemy_died() -> void:
	GameState.set_state("won")
