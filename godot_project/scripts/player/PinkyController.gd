extends CharacterBody3D
class_name PinkyController
## Spillerkontroll for Pinky (port av characterManager_pinky.ls + BehaviourManualControl.ls).

@export var walk_speed: float = 7.5
@export var sprint_speed: float = 12.0
@export var jump_velocity: float = 8.2
@export var gravity: float = 22.0
@export var is_swimming: bool = false

var camera_rig: FollowCamera
var heightmap_sampler: Callable
var input_locked: bool = false
var is_talking: bool = false
var is_pushing: bool = false
var _animator: CharacterAnimator
var _spline_pts: Array[Vector3] = []
var _spline_idx: int = 0
var _spline_speed: float = 4.2
var _spline_cb: Callable
var _attack_cooldown: float = 0.0
var _swing_timer: float = 0.0
var _step_timer: float = 0.0
var _bob_phase: float = 0.0
var _visual_root: Node3D
var _sword_pivot: Node3D
var _sword_mesh: MeshInstance3D
var _lamp_light: OmniLight3D
var _interact_targets: Array[Node] = []
var _last_safe_pos: Vector3 = Vector3.ZERO
var _safe_tick: float = 0.0
var _leap_active: bool = false
var _leap_from: Vector3 = Vector3.ZERO
var _leap_to: Vector3 = Vector3.ZERO
var _leap_t: float = 0.0
var _leap_dur: float = 0.65
var _leap_arc: float = 1.6
var _leap_is_climb: bool = false
var _leap_cb: Callable

const ROCK_SCENE := preload("res://scripts/world/SlingshotRock.gd")


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_max_angle = deg_to_rad(62.0)
	floor_snap_length = 0.35
	_last_safe_pos = global_position
	_setup_visuals()
	GameState.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(GameState.equipped_weapon)


func _setup_visuals() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	# Last original HD-konvertert Pinky-modell hvis tilgjengelig, ellers stilfull pirat-placeholder
	var pinky_path := "res://assets/models/pinky.glb"
	if ResourceLoader.exists(pinky_path):
		var scene := load(pinky_path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			_visual_root.add_child(inst)
			# Skjul ekstra verktøy-/effekt-mesher som ligger pakket inn i pinky.glb (crosshair, shovel, swoosh osv.)
			for m in _find_meshes(inst):
				var nm := m.name.to_lower()
				if nm != "pinky" and ("crosshair" in nm or "shovel" in nm or "slingshot" in nm or "swoosh" in nm or "lamp" in nm):
					m.visible = false
			# Auto-juster høyde slik at føttene står nøyaktig på y=0 (null sveving!)
			_align_model_to_floor(inst)
			VisualEnhancer.enhance_character_node(_visual_root, true, 0.65)
			_animator = CharacterAnimator.attach_to(inst, -1.0)
	else:
		_build_fallback_pinky()

	# Sjørøversabel holdt tydelig og FREMOVER i Pinkys høyre hånd (klar til å slå katapulten og fiender!)
	_sword_pivot = Node3D.new()
	_sword_pivot.position = Vector3(0.32, 0.90, -0.20)
	_sword_pivot.rotation_degrees = Vector3(22.0, -24.0, -14.0)
	_visual_root.add_child(_sword_pivot)

	_sword_mesh = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.032, 0.092, 0.88)
	_sword_mesh.mesh = blade
	_sword_mesh.position = Vector3(0.0, 0.02, -0.48)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.95, 1.0)
	mat.metallic = 0.94
	mat.roughness = 0.14
	mat.rim_enabled = true
	mat.rim = 0.55
	_sword_mesh.material_override = mat
	_sword_pivot.add_child(_sword_mesh)

	# Spiss sabeltupp fremover
	var tip := MeshInstance3D.new()
	var tip_m := PrismMesh.new()
	tip_m.size = Vector3(0.032, 0.22, 0.092)
	tip.mesh = tip_m
	tip.position = Vector3(0.0, 0.0, -0.52)
	tip.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	tip.material_override = mat
	_sword_mesh.add_child(tip)

	# Utsmykket gull-parerstang, håndbøyle og sverdfeste i Pinkys hånd
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.98, 0.78, 0.22)
	gmat.metallic = 0.94
	gmat.roughness = 0.20

	var guard := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(0.18, 0.16, 0.045)
	guard.mesh = gbox
	guard.position = Vector3(0.0, -0.01, 0.44)
	guard.material_override = gmat
	_sword_mesh.add_child(guard)

	var grip := MeshInstance3D.new()
	var gcyl := CylinderMesh.new()
	gcyl.top_radius = 0.028
	gcyl.bottom_radius = 0.030
	gcyl.height = 0.18
	grip.mesh = gcyl
	grip.position = Vector3(0.0, -0.01, 0.54)
	grip.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.24, 0.12, 0.06)
	grip_mat.roughness = 0.78
	grip.material_override = grip_mat
	_sword_mesh.add_child(grip)

	var pommel := MeshInstance3D.new()
	var psph := SphereMesh.new()
	psph.radius = 0.044
	psph.height = 0.088
	pommel.mesh = psph
	pommel.position = Vector3(0.0, -0.01, 0.64)
	pommel.material_override = gmat
	_sword_mesh.add_child(pommel)

	# Lykt-lys (Lykte-lampe)
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = Vector3(-0.32, 1.15, 0.35)
	_lamp_light.light_color = Color(1.0, 0.80, 0.42)
	_lamp_light.light_energy = 2.8
	_lamp_light.omni_range = 16.0
	_lamp_light.shadow_enabled = true
	_lamp_light.visible = GameState.lamp_enabled
	_visual_root.add_child(_lamp_light)


func walk_spline(points: Array[Vector3], speed: float = 4.2, on_done: Callable = Callable()) -> void:
	_spline_pts = points
	_spline_idx = 0
	_spline_speed = speed
	_spline_cb = on_done


func face_toward(world_target: Vector3) -> void:
	if not is_instance_valid(_visual_root):
		return
	var d := world_target - global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		_visual_root.rotation.y = atan2(-d.x, -d.z)


func _align_model_to_floor(inst: Node3D) -> void:
	var min_y := 99999.0
	var max_y := -99999.0
	var found := false
	for child in _find_meshes(inst):
		if not child.visible:
			continue
		var aabb: AABB = child.get_aabb()
		min_y = min(min_y, aabb.position.y)
		max_y = max(max_y, aabb.position.y + aabb.size.y)
		found = true
	if found and max_y > min_y:
		var h := max_y - min_y
		var target_h := 1.65
		var s: float = target_h / maxf(h, 0.01)
		inst.scale = Vector3.ONE * s
		inst.position.y = -min_y * s


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out


func _build_fallback_pinky() -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.4
	body.mesh = cap
	body.position.y = 0.85
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.18, 0.16)
	m.roughness = 0.6
	body.material_override = m
	_visual_root.add_child(body)


func _on_weapon_changed(weapon_id: String) -> void:
	if not is_instance_valid(_sword_mesh):
		return
	var info: Dictionary = GameState.WEAPONS.get(weapon_id, {})
	var wtype := str(info.get("type", "melee"))
	_sword_mesh.visible = (wtype == "melee") and (weapon_id != "none")
	var mat := _sword_mesh.material_override as StandardMaterial3D
	if mat:
		match weapon_id:
			"woodensword":
				mat.albedo_color = Color(0.58, 0.38, 0.20)
				mat.metallic = 0.05
				mat.roughness = 0.78
			"goldsword":
				mat.albedo_color = Color(1.0, 0.82, 0.22)
				mat.metallic = 0.92
				mat.roughness = 0.18
			"rapier":
				mat.albedo_color = Color(0.92, 0.95, 1.0)
				mat.metallic = 0.96
				mat.roughness = 0.12
			_:
				mat.albedo_color = Color(0.80, 0.84, 0.90)
				mat.metallic = 0.82
				mat.roughness = 0.25
	if is_instance_valid(_lamp_light):
		_lamp_light.visible = GameState.lamp_enabled


func leap_to(dest_pos: Vector3, duration: float = 0.62, arc_height: float = 1.8, is_climb: bool = false, on_done: Callable = Callable()) -> void:
	if _leap_active:
		return
	_leap_active = true
	_leap_from = global_position
	_leap_to = dest_pos
	_leap_t = 0.0
	_leap_dur = maxf(duration, 0.25)
	_leap_arc = arc_height
	_leap_is_climb = is_climb
	_leap_cb = on_done
	velocity = Vector3.ZERO
	var d := dest_pos - _leap_from
	d.y = 0.0
	if d.length_squared() > 0.01 and is_instance_valid(_visual_root):
		_visual_root.rotation.y = atan2(-d.x, -d.z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			GameState.lamp_enabled = not GameState.lamp_enabled
			if is_instance_valid(_lamp_light):
				_lamp_light.visible = GameState.lamp_enabled
			AudioManager.play_sfx("switch")
		elif event.keycode == KEY_1:
			for w in ["rapier", "goldsword", "sword", "woodensword"]:
				if GameState.has_weapon(w):
					GameState.equip_weapon(w)
					break
		elif event.keycode == KEY_2:
			if GameState.has_weapon("slingshot"):
				GameState.equip_weapon("slingshot")

	if input_locked or _leap_active:
		return
	if event.is_action_pressed("attack"):
		_perform_attack()
	elif event.is_action_pressed("interact"):
		_perform_interact()


func _physics_process(delta: float) -> void:
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	if _swing_timer > 0.0:
		_swing_timer = max(0.0, _swing_timer - delta)
		var p := 1.0 - (_swing_timer / 0.28)
		_sword_pivot.rotation = Vector3(-0.35 + sin(p * PI) * 0.4, -1.25 + p * 2.5, 0.25)
	elif is_instance_valid(_sword_pivot):
		_sword_pivot.rotation = _sword_pivot.rotation.lerp(Vector3(0.32, -0.35, -0.22), delta * 10.0)

	# 0. Assistert hopp over kløft / stige-klatring / Pelle-kast
	if _leap_active:
		_leap_t += delta / _leap_dur
		if _leap_t >= 1.0:
			global_position = _leap_to
			_last_safe_pos = _leap_to
			_leap_active = false
			velocity = Vector3.ZERO
			var lcb := _leap_cb
			_leap_cb = Callable()
			if lcb.is_valid():
				lcb.call()
		else:
			var pos := _leap_from.lerp(_leap_to, _leap_t)
			if not _leap_is_climb:
				pos.y += sin(_leap_t * PI) * _leap_arc
			global_position = pos
		if is_instance_valid(_animator):
			_animator.update_anim(delta, 5.5 if _leap_is_climb else 0.0, _leap_is_climb, false, false, false)
		return

	var move_dir := Vector3.ZERO
	var spd := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	# Historie-styrt spline-gange (f.eks. pinky_end, pinky_chestwalk)
	if _spline_idx < _spline_pts.size():
		var tgt := _spline_pts[_spline_idx]
		var diff := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
		if diff.length() < 0.45:
			_spline_idx += 1
			if _spline_idx >= _spline_pts.size() and _spline_cb.is_valid():
				var cb := _spline_cb
				_spline_cb = Callable()
				cb.call()
		else:
			move_dir = diff.normalized()
			spd = _spline_speed
	elif not input_locked:
		# Bevegelsesretning relativt til kamera
		var ix := Input.get_axis("move_left", "move_right")
		var iz := Input.get_axis("move_forward", "move_backward")
		if is_instance_valid(camera_rig):
			move_dir = (camera_rig.get_right_xz() * ix) + (-camera_rig.get_forward_xz() * iz)
		else:
			move_dir = Vector3(ix, 0.0, iz)
		if move_dir.length_squared() > 0.001:
			move_dir = move_dir.normalized()

	var hm_floor_y := -9999.0
	if heightmap_sampler.is_valid() and not is_swimming:
		hm_floor_y = heightmap_sampler.call(global_position)
	var grounded := is_on_floor() or (hm_floor_y > -5000.0 and global_position.y <= hm_floor_y + 0.16 and velocity.y <= 0.1)
	if is_swimming:
		spd *= 0.72
		var vy := 0.0
		if not input_locked:
			if Input.is_action_pressed("jump"):
				vy = 5.0
			elif Input.is_key_pressed(KEY_CTRL):
				vy = -5.0
		velocity = velocity.lerp(Vector3(move_dir.x * spd, vy, move_dir.z * spd), delta * 6.0)
	else:
		velocity.x = lerp(velocity.x, move_dir.x * spd, delta * 12.0)
		velocity.z = lerp(velocity.z, move_dir.z * spd, delta * 12.0)
		if grounded:
			if not input_locked and Input.is_action_just_pressed("jump"):
				if _try_nearby_leap():
					return
				velocity.y = jump_velocity
				grounded = false
				AudioManager.play_sfx("jump")
		else:
			velocity.y -= gravity * delta

	move_and_slide()

	# Nøyaktig original heightmap-gulv (mykt steg opp/ned uten å sette seg fast i trimesh!)
	if heightmap_sampler.is_valid() and not is_swimming:
		var hm_y: float = heightmap_sampler.call(global_position)
		if hm_y > -5000.0:
			if global_position.y <= hm_y + 0.18 and velocity.y <= 0.15:
				global_position.y = hm_y
				velocity.y = 0.0
				grounded = true
			_safe_tick += delta
			if grounded and _safe_tick >= 0.25:
				_safe_tick = 0.0
				# Ikke lagre trygg posisjon midt nede i lava!
				var in_cave_lava := ("cave" in GameState.current_level_id) and hm_y < -10.55 and global_position.x > -20.0 and global_position.x < 10.0 and global_position.z > -28.0 and global_position.z < 5.0
				if not in_cave_lava:
					_last_safe_pos = global_position

	# Sikkerhetsnett mot å falle i avgrunner, vann eller glødende lava!
	if not is_swimming and _last_safe_pos != Vector3.ZERO:
		var fell_void := (hm_floor_y <= -5000.0 and global_position.y < _last_safe_pos.y - 3.6) or (global_position.y < _last_safe_pos.y - 7.5)
		var fell_lava := ("cave" in GameState.current_level_id) and hm_floor_y > -5000.0 and hm_floor_y < -10.55 and global_position.y <= -10.50 and global_position.x > -20.0 and global_position.x < 10.0 and global_position.z > -28.0 and global_position.z < 5.0
		if fell_void or fell_lava:
			GameState.take_damage(12.0)
			AudioManager.play_sfx("hit")
			global_position = _last_safe_pos + Vector3(0.0, 0.35, 0.0)
			velocity = Vector3.ZERO

	# Roter Pinky mykt mot bevegelsesretning (-Z fremover!) + ekte skjelett-animasjoner!
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.35 and move_dir.length_squared() > 0.001 and is_instance_valid(_visual_root):
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, delta * 12.0)
		_step_timer -= delta
		if _step_timer <= 0.0 and grounded:
			_step_timer = 0.34 if horiz_speed < 8.0 else 0.24
			AudioManager.play_sfx("step", 0.18)

	if is_instance_valid(_animator):
		_animator.update_anim(delta, horiz_speed, grounded or is_swimming, is_talking, is_pushing, GameState.health <= 0.0)


func _try_nearby_leap() -> bool:
	var best: Node = null
	var best_d := 3.4
	for node in get_tree().get_nodes_in_group("leap_interactable"):
		if node is Node3D:
			var d := global_position.distance_to((node as Node3D).global_position)
			if d < best_d:
				best_d = d
				best = node
	if best and best.has_method("interact"):
		best.interact(self)
		return true
	return false


func _perform_attack() -> void:
	if _attack_cooldown > 0.0:
		return
	var info: Dictionary = GameState.WEAPONS.get(GameState.equipped_weapon, GameState.WEAPONS["sword"])
	var wtype := str(info.get("type", "melee"))
	if wtype == "none":
		# Auto-velg beste opplåste sverd hvis spilleren har funnet det eller trykker angrip
		for w in ["rapier", "goldsword", "sword", "woodensword"]:
			if GameState.has_weapon(w):
				GameState.equip_weapon(w)
				info = GameState.WEAPONS.get(w, {})
				wtype = str(info.get("type", "melee"))
				break
	if wtype == "none":
		return
	var dmg := float(info.get("damage", 25.0))
	var rng := float(info.get("range", 2.8))

	if wtype == "light":
		GameState.lamp_enabled = not GameState.lamp_enabled
		if is_instance_valid(_lamp_light):
			_lamp_light.visible = GameState.lamp_enabled
		AudioManager.play_sfx("switch")
		return

	if wtype == "ranged":
		_attack_cooldown = 0.42
		AudioManager.play_sfx("slingshot")
		var rock: SlingshotRock = ROCK_SCENE.new()
		get_parent().add_child(rock)
		var dir := -_visual_root.global_transform.basis.z
		if is_instance_valid(camera_rig):
			dir = camera_rig.get_forward_xz()
		rock.launch(global_position + Vector3(0.0, 1.35, 0.0) + dir * 0.7, dir, dmg)
		return

	# Nærkamp (sverd/sabel/kårde) med ekte sverdhugg-animasjon!
	_attack_cooldown = 0.34
	_swing_timer = 0.28
	if is_instance_valid(_animator):
		_animator.trigger_attack()
	AudioManager.play_sfx("sword")

	var forward := -_visual_root.global_transform.basis.z
	for node in get_tree().get_nodes_in_group("hittable"):
		if not (node is Node3D):
			continue
		var diff: Vector3 = node.global_position - global_position
		diff.y = 0.0
		if diff.length() <= rng + 1.2:
			if diff.length() < 1.6 or forward.dot(diff.normalized()) > -0.25:
				if node.has_method("take_hit"):
					node.take_hit(dmg, global_position)


func _perform_interact() -> void:
	var best: Node = null
	var best_d := 4.8
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	if best and best.has_method("interact"):
		best.interact(self)
