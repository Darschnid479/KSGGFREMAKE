extends CharacterBody3D
class_name SwimmingController
## 1:1 port av originalspillets swimmer.ls + hasairability.ls + swimmer_bubbles.ls:
## 2D side-scrolling undervanns-svømming i XY-planet (X = venstre/høyre, Y = opp/ned, Z = 0)
## med ekte sanntids 3D crawl-armtak, saks-beinspark (swimmer_anim.gdshader),
## luftmåler, boblespor bak føttene og myk undervannsrotasjon!

const SWIM_ANIM_SHADER := preload("res://shaders/swimmer_anim.gdshader")

@export var swim_speed: float = 3.8
@export var boost_speed: float = 5.4
@export var air_drain_rate: float = 4.6
@export var air_refill_rate: float = 55.0

var camera_rig: FollowCamera
var preview_swim_dir: Vector2 = Vector2.ZERO
var _visual_root: Node3D
var _pinky_model: Node3D
var _swim_materials: Array[ShaderMaterial] = []
var _swim_dir: Vector2 = Vector2(1.0, 0.0)
var _facing_right: bool = true
var _swim_phase: float = 0.85
var _swim_intensity: float = 0.35
var _swim_time: float = 0.0
var _invuln_timer: float = 0.0
var _drown_tick: float = 0.0
var _in_air_zone: bool = false
var _air_bubbles_fx: GPUParticles3D
var _kick_bubbles_fx: GPUParticles3D


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
					continue
				# Installer ekte sanntids 3D svømmeanimasjons-shader (armtak + beinspark + hodeblikk!)
				_apply_swim_shader(m)
			_align_model_center(_pinky_model)

	# Subtil undervanns-lykt på Pinky (scene_light festet til pinky i mapManager_swimming.ls!)
	var swim_light := OmniLight3D.new()
	swim_light.position = Vector3(0.0, 0.45, 2.4)
	swim_light.light_color = Color(0.92, 0.98, 1.0)
	swim_light.light_energy = 2.6
	swim_light.omni_range = 14.0
	swim_light.shadow_enabled = false
	add_child(swim_light)

	# 1. Stigende pustebobler fra Pinkys hode (swimmer_bubbles.ls)
	_air_bubbles_fx = _make_bubble_emitter(16, 2.0, Vector3(0.0, 0.55, 0.15), 0.18, Vector3(0.0, 1.0, 0.0), 0.7, 1.5)
	_visual_root.add_child(_air_bubbles_fx)

	# 2. Livlig svømme-kjølvann av bobler bak Pinkys sparkende føtter!
	_kick_bubbles_fx = _make_bubble_emitter(38, 1.4, Vector3(0.0, -0.78, 0.0), 0.24, Vector3(0.0, -1.0, 0.0), 1.4, 2.8)
	_kick_bubbles_fx.preprocess = 1.0
	_visual_root.add_child(_kick_bubbles_fx)


func _make_bubble_emitter(amt: int, life: float, pos: Vector3, rad: float, dir: Vector3, vmin: float, vmax: float) -> GPUParticles3D:
	var fx := GPUParticles3D.new()
	fx.amount = amt
	fx.lifetime = life
	fx.position = pos
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = rad
	pmat.direction = dir
	pmat.spread = 24.0
	pmat.initial_velocity_min = vmin
	pmat.initial_velocity_max = vmax
	pmat.gravity = Vector3(0.0, 1.1, 0.0)
	pmat.scale_min = 0.35
	pmat.scale_max = 0.95
	fx.process_material = pmat

	var bq := QuadMesh.new()
	bq.size = Vector2(0.20, 0.20)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_texture = VisualEnhancer.get_soft_glow_tex()
	bmat.albedo_color = Color(0.76, 0.97, 1.0, 0.86)
	bmat.emission_enabled = true
	bmat.emission = Color(0.55, 0.92, 1.0)
	bmat.emission_energy_multiplier = 1.8
	bq.material = bmat
	fx.draw_pass_1 = bq
	return fx


func _apply_swim_shader(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	var fab := VisualEnhancer.get_pbr_pack("fabric_detail")
	var fab_nrm: Texture2D = fab.get("normal", null)
	for si in range(mi.mesh.get_surface_count()):
		var orig := mi.get_active_material(si)
		var sm := ShaderMaterial.new()
		sm.shader = SWIM_ANIM_SHADER
		if orig is StandardMaterial3D:
			var std := orig as StandardMaterial3D
			sm.set_shader_parameter("albedo_color", std.albedo_color)
			if std.albedo_texture:
				sm.set_shader_parameter("has_albedo_tex", true)
				sm.set_shader_parameter("albedo_tex", std.albedo_texture)
		if fab_nrm:
			sm.set_shader_parameter("has_fabric_normal", true)
			sm.set_shader_parameter("fabric_normal_tex", fab_nrm)
		sm.set_shader_parameter("swim_phase", _swim_phase)
		sm.set_shader_parameter("swim_intensity", _swim_intensity)
		mi.set_surface_override_material(si, sm)
		_swim_materials.append(sm)


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
		var s := 1.72 / maxf(h, 0.01)
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


func _update_swim_pose(dir_2d: Vector2, active_swim: bool, delta: float) -> void:
	# Oppdater armtak- og beinspark-fasen i svømmeshaderen!
	var rate := 8.2 if active_swim else 3.2
	_swim_phase += delta * rate
	var target_int := 1.0 if active_swim else 0.36
	_swim_intensity = lerpf(_swim_intensity, target_int, clampf(delta * 7.0, 0.0, 1.0))

	for sm in _swim_materials:
		sm.set_shader_parameter("swim_phase", _swim_phase)
		sm.set_shader_parameter("swim_intensity", _swim_intensity)

	if _kick_bubbles_fx:
		_kick_bubbles_fx.emitting = active_swim

	if not _visual_root:
		return

	if absf(dir_2d.x) > 0.08:
		_facing_right = dir_2d.x > 0.0

	# Beregn eksakt høyrehånds 3D-svømmebasis:
	# - Aktiv svømming: hodet (+Y) peker rett i svømmeretningen (horisontalt fremover!), magen (-Z) ned, profil mot kamera (+Z)!
	# - Flytende pause: kroppen ligger lett skrått fremover mens Pinky trår vannet!
	var target_head: Vector3
	if active_swim:
		target_head = Vector3(dir_2d.x, dir_2d.y, 0.0).normalized()
	else:
		var tilt_x := 0.36 if _facing_right else -0.36
		target_head = Vector3(tilt_x, 0.93, 0.0).normalized()

	var side_sign := 1.0 if _facing_right else -1.0
	var local_x := Vector3(0.0, 0.0, side_sign)
	var local_z := local_x.cross(target_head).normalized()
	if local_z.length_squared() < 0.01:
		local_z = Vector3(0.0, 1.0, 0.0)
	var target_basis := Basis(local_x, target_head, local_z).orthonormalized()

	# Legg på subtil rullebevegelse langs kroppen i takt med crawl-armtakene!
	var roll := sin(_swim_phase) * (0.18 if active_swim else 0.06)
	target_basis = target_basis * Basis(Vector3.UP, roll)

	var cur_q := _visual_root.transform.basis.get_rotation_quaternion()
	var dst_q := target_basis.get_rotation_quaternion()
	_visual_root.transform.basis = Basis(cur_q.slerp(dst_q, clampf(delta * 9.0, 0.0, 1.0)))


func force_swim_pose(dir_2d: Vector2, phase: float = 0.95) -> void:
	preview_swim_dir = dir_2d.normalized()
	_facing_right = preview_swim_dir.x >= 0.0
	_swim_phase = phase
	_swim_intensity = 1.0
	for sm in _swim_materials:
		sm.set_shader_parameter("swim_phase", _swim_phase)
		sm.set_shader_parameter("swim_intensity", _swim_intensity)
	if _kick_bubbles_fx:
		_kick_bubbles_fx.emitting = true
	if _visual_root:
		var head := Vector3(preview_swim_dir.x, preview_swim_dir.y, 0.0).normalized()
		var side_sign := 1.0 if _facing_right else -1.0
		var lx := Vector3(0.0, 0.0, side_sign)
		var lz := lx.cross(head).normalized()
		_visual_root.transform.basis = Basis(lx, head, lz).orthonormalized()


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
	if inp.length() < 0.05 and preview_swim_dir.length() > 0.05:
		_update_swim_pose(preview_swim_dir, true, delta)
		return
	if inp.length() > 1.0:
		inp = inp.normalized()

	var spd := boost_speed if Input.is_action_pressed("sprint") else swim_speed
	var target_vel := Vector3(inp.x * spd, inp.y * spd, 0.0)
	if inp.length() < 0.05:
		target_vel.y = sin(_swim_time * 2.4) * 0.45

	velocity = velocity.lerp(target_vel, clampf(delta * 6.5, 0.0, 1.0))
	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0

	var is_moving := inp.length() > 0.08
	if is_moving:
		_swim_dir = _swim_dir.lerp(inp, clampf(delta * 10.0, 0.0, 1.0)).normalized()
	_update_swim_pose(_swim_dir, is_moving, delta)
