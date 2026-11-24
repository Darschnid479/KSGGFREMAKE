extends Area3D
class_name PortalTrigger
## Original-tro portal / ankringspunkt (port av portal.ls / portalchoice.ls).
## På land vises handlingsikonet ryddig nederst til høyre i GameHUD (aldri flytende tekst over skjermen).

@export var target_level_id: String = "world_map"
@export var portal_label: String = "Seil videre"
@export var is_world_map_buoy: bool = false

var _ring: Node3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 22.0 if is_world_map_buoy else 2.6
	col.shape = sph
	add_child(col)

	# Ren 1:1 original-tro usynlig trigger-sone (ingen uoriginale bøyer i sjøen — handlingsikonet vises i GameHUD!)
	_ring = Node3D.new()
	_ring.visible = false
	add_child(_ring)


func _process(_delta: float) -> void:
	pass


func interact(_actor: Node) -> void:
	AudioManager.play_sfx("portal")
	GameState.complete_level_story(GameState.current_level_id)
	GameState.request_level(target_level_id)
