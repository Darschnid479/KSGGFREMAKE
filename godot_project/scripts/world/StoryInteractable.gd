extends StaticBody3D
class_name StoryInteractable
## Interaktivt 1:1 historie-objekt (skyvbar kasse, knusbar steinvegg, Pelle-kast osv.).

var prompt_text: String = "[E] Bruk"
var on_interact_cb: Callable
var on_hit_cb: Callable


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
