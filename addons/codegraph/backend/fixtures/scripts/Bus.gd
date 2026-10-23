extends Node
## Autoload-fixture: signal + funksjon som andre filer kaller.

signal died

func spawn_vehicle(kind: String, at: Vector3 = Vector3.ZERO) -> Node:
	return null


func _on_hp_changed(new_hp: int) -> void:
	print(new_hp)


# fleire mottakarar på same signal — test for summert utskrift med --limit
func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_laag)
	GameState.hp_changed.connect(_on_hp_toeg)
	GameState.hp_changed.connect(_on_hp_tre)


func _on_hp_laag(new_hp: int) -> void:
	pass


func _on_hp_toeg(new_hp: int) -> void:
	pass


func _on_hp_tre(new_hp: int) -> void:
	pass
