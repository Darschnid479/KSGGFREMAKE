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
var _attack_cooldown: float = 0.0
var _swing_timer: float = 0.0
var _step_timer: float = 0.0
var _bob_phase: float = 0.0
var _visual_root: Node3D
var _sword_pivot: Node3D
var _sword_mesh: MeshInstance3D
var _lamp_light: OmniLight3D
var _interact_targets: Array[Node] = []

const ROCK_SCENE := preload("res://scripts/world/SlingshotRock.gd")


func _ready() -> void:
	add_to_group("player")
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
			# Auto-juster høyde slik at føttene står på y=0 (kun basert på synlig kropp)
			_align_model_to_floor(inst)
			VisualEnhancer.enhance_character_node(_visual_root, true, 0.65)
	else:
		_build_fallback_pinky()

	# Sverd / våpen-pivot ved høyre senket hånd
	_sword_pivot = Node3D.new()
	_sword_pivot.position = Vector3(0.30, 0.78, 0.14)
	_sword_pivot.rotation_degrees = Vector3(12.0, 8.0, -6.0)
	_visual_root.add_child(_sword_pivot)

	_sword_mesh = MeshInstance3D.new()
	var blade := BoxMesh.new()
	blade.size = Vector3(0.035, 0.075, 0.92)
	_sword_mesh.mesh = blade
	_sword_mesh.position = Vector3(0.0, 0.0, 0.46)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.90, 0.93, 0.98)
	mat.metallic = 0.92
	mat.roughness = 0.16
	mat.rim_enabled = true
	mat.rim = 0.4
	_sword_mesh.material_override = mat
	_sword_pivot.add_child(_sword_mesh)

	# Gull-parerstang og håndtak på sabelen
	var guard := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(0.22, 0.06, 0.05)
	guard.mesh = gbox
	guard.position = Vector3(0.0, 0.0, 0.02)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.96, 0.78, 0.24)
	gmat.metallic = 0.92
	gmat.roughness = 0.22
	guard.material_override = gmat
	_sword_mesh.add_child(guard)

	# Lykt-lys (Lykte-lampe)
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = Vector3(-0.32, 1.15, 0.35)
	_lamp_light.light_color = Color(1.0, 0.80, 0.42)
	_lamp_light.light_energy = 2.8
	_lamp_light.omni_range = 16.0
	_lamp_light.shadow_enabled = true
	_lamp_light.visible = GameState.lamp_enabled
	_visual_root.add_child(_lamp_light)


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

	var hat := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.52
	cyl.height = 0.25
	hat.mesh = cyl
	hat.position.y = 1.68
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.12, 0.10, 0.14)
	hat.material_override = hm
	_visual_root.add_child(hat)


func _on_weapon_changed(weapon_id: String) -> void:
	if not is_instance_valid(_sword_mesh):
		return
	var info: Dictionary = GameState.WEAPONS.get(weapon_id, {})
	var wtype := str(info.get("type", "melee"))
	_sword_mesh.visible = (wtype == "melee")
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			GameState.lamp_enabled = not GameState.lamp_enabled
			if is_instance_valid(_lamp_light):
				_lamp_light.visible = GameState.lamp_enabled
			AudioManager.play_sfx("switch")

	if event.is_action_pressed("attack"):
		_perform_attack()
	elif event.is_action_pressed("interact"):
		_perform_interact()


func _physics_process(delta: float) -> void:
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	if _swing_timer > 0.0:
		_swing_timer = max(0.0, _swing_timer - delta)
		var p := 1.0 - (_swing_timer / 0.26)
		_sword_pivot.rotation = Vector3(-0.3, -1.2 + p * 2.4, 0.25)
	elif is_instance_valid(_sword_pivot):
		_sword_pivot.rotation = _sword_pivot.rotation.lerp(Vector3(0.15, 0.15, 0.0), delta * 10.0)

	# Bevegelsesretning relativt til kamera
	var ix := Input.get_axis("move_left", "move_right")
	var iz := Input.get_axis("move_forward", "move_backward")
	var move_dir := Vector3.ZERO
	if is_instance_valid(camera_rig):
		move_dir = (camera_rig.get_right_xz() * ix) + (-camera_rig.get_forward_xz() * iz)
	else:
		move_dir = Vector3(ix, 0.0, iz)
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()

	var spd := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	if is_swimming:
		spd *= 0.72
		var vy := 0.0
		if Input.is_action_pressed("jump"):
			vy = 5.0
		elif Input.is_key_pressed(KEY_CTRL):
			vy = -5.0
		velocity = velocity.lerp(Vector3(move_dir.x * spd, vy, move_dir.z * spd), delta * 6.0)
	else:
		velocity.x = lerp(velocity.x, move_dir.x * spd, delta * 12.0)
		velocity.z = lerp(velocity.z, move_dir.z * spd, delta * 12.0)
		if is_on_floor():
			if Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
				AudioManager.play_sfx("jump")
		else:
			velocity.y -= gravity * delta

	move_and_slide()

	# Heightmap sikkerhetsgulv (fra originale heightmap-data hvis 3D-mesh har små sprekker)
	if heightmap_sampler.is_valid() and not is_swimming:
		var hm_y: float = heightmap_sampler.call(global_position)
		if hm_y > -500.0 and global_position.y < hm_y - 0.15 and velocity.y <= 0.0:
			global_position.y = hm_y
			velocity.y = 0.0

	# Roter Pinky mykt mot bevegelsesretning + gang-animasjon
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.4 and is_instance_valid(_visual_root):
		var target_yaw := atan2(move_dir.x, move_dir.z)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, delta * 12.0)
		_bob_phase += delta * horiz_speed * 1.45
		_visual_root.position.y = abs(sin(_bob_phase)) * 0.10
		_visual_root.rotation.z = sin(_bob_phase) * 0.045
		_step_timer -= delta
		if _step_timer <= 0.0 and is_on_floor():
			_step_timer = 0.34 if horiz_speed < 9.0 else 0.24
			AudioManager.play_sfx("step", 0.18)
	elif is_instance_valid(_visual_root):
		_visual_root.position.y = lerp(_visual_root.position.y, 0.0, delta * 8.0)
		_visual_root.rotation.z = lerp(_visual_root.rotation.z, 0.0, delta * 8.0)


func _perform_attack() -> void:
	if _attack_cooldown > 0.0:
		return
	var info: Dictionary = GameState.WEAPONS.get(GameState.equipped_weapon, GameState.WEAPONS["sword"])
	var wtype := str(info.get("type", "melee"))
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

	# Nærkamp (sverd/sabel/kårde)
	_attack_cooldown = 0.34
	_swing_timer = 0.26
	AudioManager.play_sfx("sword")

	var forward := _visual_root.global_transform.basis.z
	for node in get_tree().get_nodes_in_group("hittable"):
		if not (node is Node3D):
			continue
		var diff: Vector3 = node.global_position - global_position
		diff.y = 0.0
		if diff.length() <= rng + 0.8:
			if diff.length() < 1.2 or forward.dot(diff.normalized()) > -0.1:
				if node.has_method("take_hit"):
					node.take_hit(dmg, global_position)


func _perform_interact() -> void:
	var best: Node = null
	var best_d := 4.5
	for node in get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	if best and best.has_method("interact"):
		best.interact(self)
