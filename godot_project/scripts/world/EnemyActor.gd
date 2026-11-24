extends CharacterBody3D
class_name EnemyActor
## Fiende- og boss-AI (skjeletter, vakter, panter, kjøttetende plante, Grusomme Gabriels spøkelse, drage).

@export var enemy_name: String = "Skjelett"
@export var model_resource: String = "skeleton"
@export var max_hp: float = 60.0
@export var attack_damage: float = 12.0
@export var move_speed: float = 2.9
@export var aggro_range: float = 15.0
@export var attack_range: float = 2.3
@export var is_boss: bool = false
@export var coin_drop: int = 5
@export var passive_until_hit: bool = false

var hp: float = 60.0
var heightmap_sampler: Callable
var initial_yaw: float = 0.0
var _spawn_pos: Vector3
var _attack_cd: float = 0.0
var _hit_flash: float = 0.0
var _visual: Node3D
var _animator: CharacterAnimator
var _hp_label: Label3D

const COIN_SCRIPT := preload("res://scripts/world/CollectibleCoin.gd")


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	add_to_group("hittable")
	add_to_group("enemy")
	hp = max_hp
	_spawn_pos = global_position

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.75 if is_boss else 0.45
	cap.height = 2.8 if is_boss else 1.8
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)

	_visual = Node3D.new()
	_visual.rotation.y = initial_yaw
	add_child(_visual)

	var glb_path := "res://assets/models/%s.glb" % model_resource
	var is_spectral := false
	if not ResourceLoader.exists(glb_path) and model_resource == "ghost":
		glb_path = "res://assets/models/skeleton.glb"
		is_spectral = true
	if ResourceLoader.exists(glb_path):
		var sc := load(glb_path) as PackedScene
		if sc:
			var inst := sc.instantiate()
			_visual.add_child(inst)
			_align_model(inst)
			if is_spectral:
				var gmat := StandardMaterial3D.new()
				gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				gmat.albedo_color = Color(0.28, 1.0, 0.68, 0.78)
				gmat.emission_enabled = true
				gmat.emission = Color(0.16, 1.0, 0.58)
				gmat.emission_energy_multiplier = 2.8
				gmat.rim_enabled = true
				gmat.rim = 0.85
				for mi in _find_meshes(inst):
					mi.material_override = gmat
				var glight := OmniLight3D.new()
				glight.position.y = 1.8
				glight.light_color = Color(0.22, 1.0, 0.62)
				glight.light_energy = 5.0
				glight.omni_range = 16.0
				_visual.add_child(glight)
			else:
				VisualEnhancer.enhance_character_node(_visual, true, 1.1 if is_boss else 0.72)
				if not (model_resource in ["panther", "meatplant", "dog"]):
					_animator = CharacterAnimator.attach_to(inst, -1.0)
	else:
		_build_fallback()

	_hp_label = Label3D.new()
	_hp_label.position.y = 3.6 if is_boss else 2.35
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.font_size = 34 if is_boss else 24
	_hp_label.outline_size = 8
	_hp_label.modulate = Color(1.0, 0.42, 0.34)
	_hp_label.visible = false
	add_child(_hp_label)
	_update_label()


func _align_model(inst: Node3D) -> void:
	var min_y := 99999.0
	var max_y := -99999.0
	var found := false
	for m in _find_meshes(inst):
		var nm := m.name.to_lower()
		if "shadow" in nm or "crosshair" in nm or "swoosh" in nm:
			m.visible = false
			continue
		var aabb: AABB = m.get_aabb()
		min_y = min(min_y, aabb.position.y)
		max_y = max(max_y, aabb.position.y + aabb.size.y)
		found = true
	if found and max_y > min_y:
		var target_h: float = 3.1 if is_boss else 1.9
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
	cap.radius = 0.7 if is_boss else 0.42
	cap.height = 2.6 if is_boss else 1.7
	mi.mesh = cap
	mi.position.y = cap.height * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.85, 0.55) if is_boss else Color(0.72, 0.16, 0.18)
	if is_boss:
		mat.emission_enabled = true
		mat.emission = Color(0.15, 0.75, 0.45)
	mi.material_override = mat
	_visual.add_child(mi)


func _update_label() -> void:
	if is_instance_valid(_hp_label):
		_hp_label.text = "%s (%d/%d)" % [enemy_name, int(ceil(hp)), int(max_hp)]


func _physics_process(delta: float) -> void:
	_attack_cd = max(0.0, _attack_cd - delta)
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		_visual.scale = Vector3.ONE * (1.0 + _hit_flash * 0.25)
	else:
		_visual.scale = Vector3.ONE

	if not is_on_floor():
		velocity.y -= 20.0 * delta

	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var p := players[0] as Node3D
		var diff := p.global_position - global_position
		diff.y = 0.0
		var dist := diff.length()
		if is_instance_valid(_hp_label):
			_hp_label.visible = (not is_boss and hp < max_hp and dist < 10.0)
		if not passive_until_hit and dist < aggro_range:
			if is_boss:
				GameState.emit_signal("boss_health_changed", enemy_name, hp, max_hp)
			if dist > attack_range:
				var dir := diff.normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), delta * 8.0)
			else:
				velocity.x = 0.0
				velocity.z = 0.0
				if diff.length_squared() > 0.01:
					var dir := diff.normalized()
					_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-dir.x, -dir.z), delta * 10.0)
				if _attack_cd <= 0.0:
					_attack_cd = 1.25
					if is_instance_valid(_animator):
						_animator.trigger_attack()
					GameState.take_damage(attack_damage)
		else:
			velocity.x = lerp(velocity.x, 0.0, delta * 6.0)
			velocity.z = lerp(velocity.z, 0.0, delta * 6.0)

	move_and_slide()
	if heightmap_sampler.is_valid():
		var hm_y: float = heightmap_sampler.call(global_position)
		if hm_y > -5000.0 and global_position.y <= hm_y + 0.12 and velocity.y <= 0.1:
			global_position.y = hm_y
			velocity.y = 0.0

	if is_instance_valid(_animator):
		var hspd := Vector2(velocity.x, velocity.z).length()
		_animator.update_anim(delta, hspd, true, false, false, hp <= 0.0)


func take_hit(damage: float, from_pos: Vector3) -> void:
	passive_until_hit = false
	hp = max(0.0, hp - damage)
	_hit_flash = 0.2
	if is_instance_valid(_animator):
		_animator.trigger_hurt()
	_update_label()
	AudioManager.play_sfx("hit")

	var push := (global_position - from_pos)
	push.y = 0.0
	if push.length_squared() > 0.01:
		velocity += push.normalized() * 6.5

	if is_boss:
		GameState.emit_signal("boss_health_changed", enemy_name, hp, max_hp)

	if hp <= 0.0:
		for i in range(coin_drop):
			var c: CollectibleCoin = COIN_SCRIPT.new()
			c.position = global_position + Vector3(randf_range(-1.4, 1.4), 0.8, randf_range(-1.4, 1.4))
			get_parent().add_child(c)
		if is_boss:
			GameState.complete_level_story(GameState.current_level_id)
			GameState.add_coins(25)
			GameState.emit_signal("boss_health_changed", "", 0.0, 0.0)
			GameState.set_objective("Boss beseiret! Gå til portalen for å fortsette historien!")
		queue_free()
