extends StaticBody3D
class_name StoryInteractable
## Interaktivt 1:1 historie-objekt (skyvbar kasse, knusbar steinvegg, stige, hopp, skatt osv.).

var prompt_text: String = "[E] Bruk"
var on_interact_cb: Callable
var on_hit_cb: Callable
var is_blocking: bool = false


func _ready() -> void:
	set_blocking(is_blocking)
	if not is_in_group("interactable"):
		add_to_group("interactable")


func set_blocking(blocking: bool) -> void:
	is_blocking = blocking
	collision_layer = 1 if blocking else 8
	collision_mask = 0


func get_interact_prompt() -> String:
	return prompt_text


func interact(player: Node) -> void:
	if on_interact_cb.is_valid():
		on_interact_cb.call(player)


func take_hit(_damage: float, _from_pos: Vector3) -> void:
	if on_hit_cb.is_valid():
		on_hit_cb.call()
	elif on_interact_cb.is_valid():
		on_interact_cb.call(null)
