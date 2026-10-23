class_name Bullet
extends Area2D

@export var velocity := 12.0


func fly(delta: float) -> void:
	position += transform.x * velocity * delta
