extends Node3D
class_name CollectibleCoin
## Høyoppløst roterende 3D sjørøver-gullmynt (dublon) med preget myntflate og metallisk gullglans.

@export var value: int = 1
var _phase: float = 0.0
var _base_y: float = 0.0

static var _cached_coin_tex: Texture2D


func _ready() -> void:
	_phase = randf() * TAU
	_base_y = position.y

	if _cached_coin_tex == null and ResourceLoader.exists("res://assets/ui/gold_doubloon.png"):
		_cached_coin_tex = load("res://assets/ui/gold_doubloon.png") as Texture2D

	# Metallisk preget gullmynt-kropp
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.21
	cyl.bottom_radius = 0.21
	cyl.height = 0.055
	cyl.radial_segments = 24
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.26)
	mat.metallic = 0.92
	mat.roughness = 0.18
	mat.rim_enabled = true
	mat.rim = 0.45
	mat.rim_tint = 0.8
	mi.material_override = mat
	add_child(mi)

	# Preget dublon-emblem på begge sider av mynten
	if _cached_coin_tex != null:
		var face_mat := StandardMaterial3D.new()
		face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		face_mat.albedo_texture = _cached_coin_tex
		face_mat.metallic = 0.85
		face_mat.roughness = 0.22
		for side in [-1.0, 1.0]:
			var face := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.38, 0.38)
			face.mesh = q
			face.position = Vector3(0.0, 0.0, side * 0.032)
			if side < 0.0:
				face.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			face.material_override = face_mat
			add_child(face)


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
