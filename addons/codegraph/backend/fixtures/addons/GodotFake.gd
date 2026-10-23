extends RefCounted
class_name GodotFake


#addon-stub: denne fila skal IKKE kome med i indeksen utan --addons
func fake_wrapper(x: int) -> void:
	call_group("enemies", "take_damage", x)
