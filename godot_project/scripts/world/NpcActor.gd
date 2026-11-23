extends StaticBody3D
class_name NpcActor
## Ekte animert 1:1 NPC (Kaptein Sabeltann, Langemann, Sunniva, Pelle, Pysa, Skalken, Miriam osv.)
## med skjelett-animasjon (bein/armer/snakke-gester), ekte spline-vandring og original historie-dialog!

@export var npc_id: String = "sabeltann"
@export var display_name: String = "Kaptein Sabeltann"
@export var model_resource: String = "sabeltann"
@export var dialogue_lines: Array[String] = []
@export var reward_coins: int = 0

var heightmap_sampler: Callable
var story_conversation_id: String = ""
var is_talking: bool = false
var _visual: Node3D
var _animator: CharacterAnimator
var _talked: bool = false
var _spline_pts: Array[Vector3] = []
var _spline_idx: int = 0
var _spline_speed: float = 3.8
var _spline_cb: Callable
var _cur_speed: float = 0.0

signal interact_requested(npc: NpcActor)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")
	# NPC-er blokkerer ikke Pinky i trange huleganger (E-interaksjon skjer via gruppe-avstand!)
	collision_layer = 4
	collision_mask = 0
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)

	var glb_path := "res://assets/models/%s.glb" % model_resource
	if ResourceLoader.exists(glb_path):
		var sc := load(glb_path) as PackedScene
		if sc:
			var inst := sc.instantiate()
			_visual.add_child(inst)
			_align_model(inst)
			VisualEnhancer.enhance_character_node(_visual, true, 0.72)
			if not (model_resource in ["dog", "panther", "meatplant", "movablecrate"]):
				_animator = CharacterAnimator.attach_to(inst, -1.0)
			if "pysa" in npc_id.to_lower() and _animator:
				# Gi Pysa egen blågrønn piratnyanse og litt lavere vekst så han skiller seg klart fra Pelle!
				_visual.scale = Vector3(0.95, 0.92, 0.95)
				for sm in _animator.materials:
					sm.set_shader_parameter("albedo_tint", Color(0.84, 0.92, 0.96, 1.0))
	else:
		_build_fallback()


func walk_spline(points: Array[Vector3], speed: float = 3.8, on_done: Callable = Callable()) -> void:
	_spline_pts = points
	_spline_idx = 0
	_spline_speed = speed
	_spline_cb = on_done


func zap_to(pos: Vector3) -> void:
	_spline_pts.clear()
	_spline_idx = 0
	var y := pos.y
	if heightmap_sampler.is_valid():
		var hy: float = heightmap_sampler.call(pos)
		if hy > -5000.0:
			y = hy
	global_position = Vector3(pos.x, y, pos.z)


func face_toward(world_target: Vector3) -> void:
	if not is_instance_valid(_visual):
		return
	var d := world_target - global_position
	d.y = 0.0
	if d.length_squared() > 0.01:
		_visual.rotation.y = atan2(-d.x, -d.z)


func set_talking(active: bool, look_target: Vector3 = Vector3.ZERO) -> void:
	is_talking = active
	if active and look_target != Vector3.ZERO:
		face_toward(look_target)


func _align_model(inst: Node3D) -> void:
	var min_y := 99999.0
	var max_y := -99999.0
	var found := false
	for m in _find_meshes(inst):
		var nm := m.name.to_lower()
		if "shadow" in nm or "crosshair" in nm or "swoosh" in nm or nm == "rapier":
			m.visible = false
			continue
		var aabb: AABB = m.get_aabb()
		min_y = min(min_y, aabb.position.y)
		max_y = max(max_y, aabb.position.y + aabb.size.y)
		found = true
	if found and max_y > min_y:
		var target_h := 2.05 if model_resource == "sabeltann" else (1.92 if model_resource == "langemann" else 1.82)
		var s: float = target_h / maxf(max_y - min_y, 0.01)
		inst.scale = Vector3.ONE * s
		inst.position.y = -min_y * s


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out


func _build_fallback() -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.65
	mi.mesh = cap
	mi.position.y = 0.85
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.30, 0.65)
	mi.material_override = mat
	_visual.add_child(mi)


func _physics_process(delta: float) -> void:
	_cur_speed = 0.0
	if _spline_idx < _spline_pts.size():
		var tgt := _spline_pts[_spline_idx]
		var diff := Vector3(tgt.x - global_position.x, 0.0, tgt.z - global_position.z)
		var dist := diff.length()
		if dist < 0.42:
			_spline_idx += 1
			if _spline_idx >= _spline_pts.size():
				_spline_pts.clear()
				if _spline_cb.is_valid():
					var cb := _spline_cb
					_spline_cb = Callable()
					cb.call()
		else:
			var step := minf(_spline_speed * delta, dist)
			var dir := diff / dist
			global_position.x += dir.x * step
			global_position.z += dir.z * step
			if heightmap_sampler.is_valid():
				var hy: float = heightmap_sampler.call(global_position)
				if hy > -5000.0:
					global_position.y = lerpf(global_position.y, hy, clampf(delta * 14.0, 0.0, 1.0))
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
			_cur_speed = _spline_speed

	if is_instance_valid(_animator):
		_animator.update_anim(delta, _cur_speed, true, is_talking, false, false)


func get_interact_prompt() -> String:
	return "[E] Snakk med " + display_name


func interact(player: Node) -> void:
	if player is Node3D:
		face_toward((player as Node3D).global_position)
	emit_signal("interact_requested", self)
	if story_conversation_id != "":
		return
	if not _talked and reward_coins > 0:
		_talked = true
		GameState.add_coins(reward_coins)
	var lines: Array = dialogue_lines if not dialogue_lines.is_empty() else ["Hiv o' hoi, Pinky!"]
	GameState.emit_signal("dialogue_requested", display_name, lines)
