extends Node3D
class_name CollectibleCoin
## Roterende sjørøvergullmynt med magnetisk oppsamling.

@export var value: int = 1
var _phase: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_base_y = position.y

	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.19
	cyl.bottom_radius = 0.19
	cyl.height = 0.045
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.74, 0.16)
	mat.metallic = 0.95
	mat.roughness = 0.20
	mat.emission_enabled = false
	mi.material_override = mat
	add_child(mi)


func _process(delta: float) -> void:
	_phase += delta * 2.8
	rotate_y(delta * 2.6)
	position.y = _base_y + sin(_phase) * 0.16

	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p := players[0] as Node3D
	if not is_instance_valid(p):
		return
	var dist := global_position.distance_to(p.global_position + Vector3(0.0, 0.8, 0.0))
	if dist < 3.2:
		global_position = global_position.lerp(p.global_position + Vector3(0.0, 0.8, 0.0), delta * 10.0)
	if dist < 1.1:
		GameState.add_coins(value)
		queue_free()
