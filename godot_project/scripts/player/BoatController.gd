extends CharacterBody3D
class_name BoatController
## Styring av Den Sorte Dame på verdenskartet (1:1 port av sabeltannboat.ls + mapManager_world_map.ls).
## Bruker den ekte HD 3D-modellen av Den Sorte Dame (darklady + railing + frontdecoration) fra world_map.glb.

@export var max_speed: float = 38.0
@export var turn_speed: float = 1.60
@export var cannon_cooldown: float = 1.1

var camera_rig: FollowCamera
var target_island_pos: Vector3 = Vector3.ZERO
var has_target_island: bool = false
var _cur_speed: float = 0.0
var _cannon_timer: float = 0.0
var _bob_t: float = 0.0
var _ship_visual: Node3D
var _arrow_node: MeshInstance3D

const ROCK_SCENE := preload("res://scripts/world/SlingshotRock.gd")


func set_target_island(pos: Vector3, enabled: bool = true) -> void:
	target_island_pos = pos
	has_target_island = enabled
	if is_instance_valid(_arrow_node):
		_arrow_node.visible = enabled


func _ready() -> void:
	add_to_group("player")
	if GameState.has_achievement("ship_sail"):
		max_speed *= 1.32
	if GameState.has_achievement("ship_cannon"):
		cannon_cooldown *= 0.62
	_ship_visual = Node3D.new()
	add_child(_ship_visual)

	var loaded_real := false
	if ResourceLoader.exists("res://assets/levels/world_map.glb"):
		var sc := load("res://assets/levels/world_map.glb") as PackedScene
		if sc:
			var inst := sc.instantiate()
			_ship_visual.add_child(inst)
			var arrow_src: MeshInstance3D = null
			# Vis Den Sorte Dame (darklady + railing + frontdecoration) og hent original 3D retningspil (directionindicator)
			for mi in _find_meshes(inst):
				var nm := mi.name.to_lower()
				if nm == "directionindicator":
					arrow_src = mi
					mi.visible = false
				else:
					mi.visible = (nm in ["darklady", "railing", "frontdecoration"])
			inst.scale = Vector3.ONE * 0.48
			VisualEnhancer.enhance_world_node(inst, "abra", 0.0)
			if arrow_src and arrow_src.mesh:
				_arrow_node = MeshInstance3D.new()
				_arrow_node.name = "DirectionIndicator"
				_arrow_node.mesh = arrow_src.mesh
				var arrow_mat := StandardMaterial3D.new()
				arrow_mat.albedo_color = Color(0.96, 0.72, 0.16)
				arrow_mat.metallic = 0.30
				arrow_mat.roughness = 0.32
				arrow_mat.emission_enabled = true
				arrow_mat.emission = Color(0.88, 0.54, 0.08)
				arrow_mat.emission_energy_multiplier = 0.45
				_arrow_node.material_override = arrow_mat
				_arrow_node.scale = Vector3.ONE * 0.56
				_arrow_node.position = Vector3(0.0, 2.8, -7.8)
				_arrow_node.visible = has_target_island
				add_child(_arrow_node)
			loaded_real = true

	if not loaded_real:
		_build_fallback_ship()

	# Skummende kjølvann bak Den Sorte Dame
	VisualEnhancer.attach_ship_wake(_ship_visual, 1.05)

	# Varm akterlanterne på skuta
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0.0, 3.6, 5.2)
	lantern.light_color = Color(1.0, 0.76, 0.34)
	lantern.light_energy = 4.2
	lantern.omni_range = 20.0
	_ship_visual.add_child(lantern)


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out


func _build_fallback_ship() -> void:
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 1.6, 8.2)
	hull.mesh = box
	hull.position.y = 0.6
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.14, 0.09, 0.07)
	hmat.roughness = 0.72
	hull.material_override = hmat
	_ship_visual.add_child(hull)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		_fire_broadsides()
	elif event.is_action_pressed("interact"):
		_check_dock_portal()


func _physics_process(delta: float) -> void:
	_cannon_timer = maxf(0.0, _cannon_timer - delta)
	var throttle := Input.get_axis("move_backward", "move_forward")
	var steer := Input.get_axis("move_right", "move_left")

	_cur_speed = lerp(_cur_speed, throttle * max_speed, delta * 2.6)
	rotation.y += steer * turn_speed * delta * (0.45 + 0.55 * clampf(absf(_cur_speed) / max_speed, 0.0, 1.0))

	var fwd := -global_transform.basis.z
	velocity = Vector3(fwd.x * _cur_speed, 0.0, fwd.z * _cur_speed)
	move_and_slide()
	global_position.y = 0.0

	# Realistisk bølge-dupping og krenging
	_bob_t += delta * 2.0
	_ship_visual.position.y = sin(_bob_t) * 0.24
	_ship_visual.rotation.x = sin(_bob_t * 0.85) * 0.035
	_ship_visual.rotation.z = lerp(_ship_visual.rotation.z, -steer * 0.14, delta * 4.0)

	if is_instance_valid(_arrow_node) and _arrow_node.visible:
		var flat_delta := Vector3(target_island_pos.x - global_position.x, 0.0, target_island_pos.z - global_position.z)
		if flat_delta.length_squared() > 1.0:
			var world_yaw := atan2(-flat_delta.x, -flat_delta.z)
			var rel_yaw := world_yaw - rotation.y
			_arrow_node.rotation.y = rel_yaw
			var rel_dir := Vector3(-sin(rel_yaw), 0.0, -cos(rel_yaw))
			_arrow_node.position = rel_dir * 7.8 + Vector3(0.0, 2.8 + sin(_bob_t * 1.6) * 0.30, 0.0)


func _fire_broadsides() -> void:
	if _cannon_timer > 0.0:
		return
	_cannon_timer = cannon_cooldown
	AudioManager.play_sfx("cannon")
	for side: float in [-1.0, 1.0]:
		var dir: Vector3 = global_transform.basis.x * side
		var ball: SlingshotRock = ROCK_SCENE.new()
		get_parent().add_child(ball)
		ball.launch(global_position + Vector3(0.0, 1.8, 0.0) + dir * 2.5, dir, 40.0, 38.0, 0.42)


func _check_dock_portal() -> void:
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D and global_position.distance_to((node as Node3D).global_position) < 24.0:
			if node.has_method("interact"):
				node.interact(self)
				return
