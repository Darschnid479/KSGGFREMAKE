extends CharacterBody3D
class_name SwimmingController
## 1:1 port av originalspillets swimmer.ls + hasairability.ls + swimmer_bubbles.ls:
## 2D side-scrolling undervanns-svømming i XY-planet (X = venstre/høyre, Y = opp/ned, Z = 0)
## med luftmåler, stigende luftbobler, skade fra haier/pirajaer/sjøminer og myk svømmerotasjon!

@export var swim_speed: float = 6.2
@export var boost_speed: float = 8.4
@export var air_drain_rate: float = 4.6
@export var air_refill_rate: float = 55.0

var camera_rig: FollowCamera
var _visual_root: Node3D
var _pinky_model: Node3D
var _swim_dir: Vector2 = Vector2(1.0, 0.0)
var _swim_time: float = 0.0
var _invuln_timer: float = 0.0
var _drown_tick: float = 0.0
var _in_air_zone: bool = false
var _air_bubbles_fx: GPUParticles3D


func _ready() -> void:
	add_to_group("player")
	GameState.set_air(100.0, 100.0)
	_setup_visuals()


func _setup_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "SwimmerVisuals"
	add_child(_visual_root)

	if ResourceLoader.exists("res://assets/models/pinky.glb"):
		var scene := load("res://assets/models/pinky.glb") as PackedScene
		if scene:
			_pinky_model = scene.instantiate()
			_visual_root.add_child(_pinky_model)
			for m in _find_meshes(_pinky_model):
				var nm := m.name.to_lower()
				if nm != "pinky" and ("crosshair" in nm or "shovel" in nm or "slingshot" in nm or "swoosh" in nm or "lamp" in nm):
					m.visible = false
			_align_model_center(_pinky_model)
			VisualEnhancer.enhance_character_node(_visual_root, false, 0.0)

	# Subtil undervanns-lykt på Pinky (tilsvarer scene_light festet til pinky i mapManager_swimming.ls!)
	var swim_light := OmniLight3D.new()
	swim_light.position = Vector3(0.0, 0.3, 1.8)
	swim_light.light_color = Color(0.55, 0.92, 1.0)
	swim_light.light_energy = 2.6
	swim_light.omni_range = 16.0
	swim_light.shadow_enabled = false
	add_child(swim_light)

	# Stigende pustebobler fra Pinky (swimmer_bubbles.ls)
	_air_bubbles_fx = GPUParticles3D.new()
	_air_bubbles_fx.amount = 18
	_air_bubbles_fx.lifetime = 2.2
	_air_bubbles_fx.position = Vector3(0.0, 0.45, 0.15)
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.22
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 18.0
	pmat.initial_velocity_min = 0.8
	pmat.initial_velocity_max = 1.6
	pmat.gravity = Vector3(0.0, 0.9, 0.0)
	pmat.scale_min = 0.35
	pmat.scale_max = 0.85
	_air_bubbles_fx.process_material = pmat

	var bq := QuadMesh.new()
	bq.size = Vector2(0.18, 0.18)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_texture = VisualEnhancer.get_soft_glow_tex()
	bmat.albedo_color = Color(0.75, 0.96, 1.0, 0.82)
	bmat.emission_enabled = true
	bmat.emission = Color(0.55, 0.92, 1.0)
	bmat.emission_energy_multiplier = 1.6
	bq.material = bmat
	_air_bubbles_fx.draw_pass_1 = bq
	add_child(_air_bubbles_fx)


func _align_model_center(inst: Node3D) -> void:
	var min_y := 99999.0
	var max_y := -99999.0
	var found := false
	for child in _find_meshes(inst):
		if not child.visible:
			continue
		var aabb: AABB = child.get_aabb()
		min_y = minf(min_y, aabb.position.y)
		max_y = maxf(max_y, aabb.position.y + aabb.size.y)
		found = true
	if found and max_y > min_y:
		var h := max_y - min_y
		var s := 1.65 / maxf(h, 0.01)
		inst.scale = Vector3.ONE * s
		inst.position.y = -(min_y + h * 0.5) * s


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out


func set_in_air_zone(inside: bool) -> void:
	_in_air_zone = inside


func hit_by_hazard(damage: float, push_from: Vector3) -> void:
	if _invuln_timer > 0.0:
		return
	_invuln_timer = 1.4
	GameState.take_damage(damage)
	var push := (global_position - push_from)
	push.z = 0.0
	if push.length_squared() < 0.01:
		push = Vector3(0.0, 1.0, 0.0)
	velocity = push.normalized() * 7.5


func _physics_process(delta: float) -> void:
	_swim_time += delta
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)
		if _visual_root:
			_visual_root.visible = (int(_invuln_timer * 14.0) % 2 == 0)
	elif _visual_root and not _visual_root.visible:
		_visual_root.visible = true

	# 1. Luftmåler (tømmes under vann, fylles raskt i luftboblesøylene!)
	if _in_air_zone:
		if GameState.air < GameState.max_air:
			GameState.set_air(GameState.air + air_refill_rate * delta, GameState.max_air)
	else:
		GameState.set_air(GameState.air - air_drain_rate * delta, GameState.max_air)
		if GameState.air <= 0.0:
			_drown_tick += delta
			if _drown_tick >= 1.2:
				_drown_tick = 0.0
				GameState.take_damage(10.0)

	# 2. 1:1 original 2D XY-svømmestyring (W/Opp = opp, S/Ned = ned, A/Venstre = venstre, D/Høyre = høyre)
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_backward", "move_forward")
	var inp := Vector2(ix, iy)
	if inp.length() > 1.0:
		inp = inp.normalized()

	var spd := boost_speed if Input.is_action_pressed("sprint") else swim_speed
	var target_vel := Vector3(inp.x * spd, inp.y * spd, 0.0)
	# Myk undervanns-oppdrift når man flyter stille
	if inp.length() < 0.05:
		target_vel.y = sin(_swim_time * 2.4) * 0.45

	velocity = velocity.lerp(target_vel, clampf(delta * 6.5, 0.0, 1.0))
	velocity.z = 0.0
	move_and_slide()
	# Lås Pinky stramt i 2D-svømmeplanet (Z = 0)
	position.z = 0.0

	# 3. Levende animert svømmeorientering i 2D-planet (swimmer.ls!)
	if _visual_root:
		if inp.length() > 0.08:
			_swim_dir = _swim_dir.lerp(inp, clampf(delta * 9.0, 0.0, 1.0)).normalized()
			var face_right := _swim_dir.x >= -0.05
			var target_y_rot := -PI * 0.5 if face_right else PI * 0.5
			var pitch_angle := atan2(_swim_dir.y, maxf(absf(_swim_dir.x), 0.12))
			# Ligg horisontalt fremover i svømmeretningen med rytmisk svømmetak-vugging!
			var stroke := sin(_swim_time * 9.5) * 0.14
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_y_rot, clampf(delta * 10.0, 0.0, 1.0))
			_visual_root.rotation.x = lerpf(_visual_root.rotation.x, -PI * 0.42 + pitch_angle * 0.85 + stroke, clampf(delta * 8.0, 0.0, 1.0))
			_visual_root.rotation.z = lerpf(_visual_root.rotation.z, cos(_swim_time * 9.5) * 0.12, clampf(delta * 8.0, 0.0, 1.0))
		else:
			# Flyt rolig oppreist med myk vannbevegelse (pinky_float)
			var face_right := _swim_dir.x >= -0.05
			var target_y_rot := -PI * 0.35 if face_right else PI * 0.35
			_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_y_rot, clampf(delta * 6.0, 0.0, 1.0))
			_visual_root.rotation.x = lerpf(_visual_root.rotation.x, -0.18 + sin(_swim_time * 2.8) * 0.08, clampf(delta * 5.0, 0.0, 1.0))
			_visual_root.rotation.z = lerpf(_visual_root.rotation.z, cos(_swim_time * 2.2) * 0.06, clampf(delta * 5.0, 0.0, 1.0))
