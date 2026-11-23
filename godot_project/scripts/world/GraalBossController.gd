extends Node3D
class_name GraalBossController
## Ekte interaktiv bosskontroll for Greven av Gral på sin flygende drage (graal_bosslevel).
## Svever i 8-tall over borggården, spyr ildkuler mot Pinky og tar skade fra de 4 katapultene!

signal boss_defeated

var max_hp: float = 260.0
var hp: float = 260.0
var center_pos: Vector3 = Vector3(0.3, 27.6, -1.9)
var player: Node3D
var _t: float = 0.0
var _fire_timer: float = 3.8
var _defeated: bool = false
var _hit_flash: float = 0.0
var _fireballs: Array = [] # {node: Node3D, vel: Vector3, life: float}
var _dragon_visual: Node3D
var _wing_glow: OmniLight3D


func setup_visual(dragon_root: Node3D, p_player: Node3D) -> void:
	_dragon_visual = dragon_root
	add_child(dragon_root)
	player = p_player
	global_position = center_pos
	GameState.emit_signal("boss_health_changed", "Greven av Gral", hp, max_hp)

	_wing_glow = OmniLight3D.new()
	_wing_glow.position = Vector3(0.0, 1.2, 0.8)
	_wing_glow.light_color = Color(1.0, 0.44, 0.12)
	_wing_glow.light_energy = 7.2
	_wing_glow.omni_range = 28.0
	add_child(_wing_glow)


func _physics_process(delta: float) -> void:
	if _defeated:
		global_position.y -= 9.0 * delta
		rotation.z += 2.6 * delta
		rotation.x += 1.4 * delta
		if global_position.y < -10.0:
			queue_free()
		return

	_t += delta * 0.62
	var target_pos := Vector3(
		center_pos.x + sin(_t) * 9.5,
		center_pos.y + sin(_t * 2.0) * 1.65,
		center_pos.z + sin(_t * 2.0) * 6.8
	)
	var move_v := target_pos - global_position
	global_position = global_position.lerp(target_pos, delta * 3.2)
	if move_v.length() > 0.02:
		var yaw := atan2(-move_v.x, -move_v.z)
		rotation.y = lerp_angle(rotation.y, yaw, delta * 4.5)
		rotation.z = clampf(-move_v.x * 0.25, -0.35, 0.35)

	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		if is_instance_valid(_wing_glow):
			_wing_glow.light_color = Color(1.0, 0.92, 0.35)
			_wing_glow.light_energy = 14.0
	elif is_instance_valid(_wing_glow):
		_wing_glow.light_color = Color(1.0, 0.42, 0.12)
		_wing_glow.light_energy = 6.8 + sin(_t * 6.0) * 1.4

	# Spy ildkuler ned mot Pinky på brystvernet!
	_fire_timer -= delta
	if _fire_timer <= 0.0 and is_instance_valid(player):
		_fire_timer = 4.4
		_spawn_fireball()

	# Oppdater svevende ildkuler
	var i := _fireballs.size() - 1
	while i >= 0:
		var fb: Dictionary = _fireballs[i]
		fb["life"] = float(fb["life"]) - delta
		var fnode: Node3D = fb["node"]
		if not is_instance_valid(fnode) or float(fb["life"]) <= 0.0:
			if is_instance_valid(fnode):
				fnode.queue_free()
			_fireballs.remove_at(i)
			i -= 1
			continue
		fnode.global_position += (fb["vel"] as Vector3) * delta
		if is_instance_valid(player):
			var d := fnode.global_position.distance_to(player.global_position + Vector3(0.0, 1.0, 0.0))
			if d < 1.8:
				if player.has_method("take_damage"):
					player.take_damage(14.0, global_position)
				fnode.queue_free()
				_fireballs.remove_at(i)
		i -= 1


func _spawn_fireball() -> void:
	if not is_instance_valid(player):
		return
	var target := player.global_position + Vector3(0.0, 1.0, 0.0)
	var dir := (target - global_position).normalized()

	var ball := Node3D.new()
	ball.global_position = global_position + dir * 2.2
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.55
	sph.height = 1.1
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.08)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.38, 0.04)
	mat.emission_energy_multiplier = 4.5
	mi.material_override = mat
	ball.add_child(mi)

	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.44, 0.1)
	fl.light_energy = 5.5
	fl.omni_range = 9.0
	ball.add_child(fl)

	get_parent().add_child(ball)
	AudioManager.play_sfx("explosion", 0.5)
	_fireballs.append({"node": ball, "vel": dir * 13.5, "life": 4.2})


func hit_by_catapult(damage: float) -> void:
	if _defeated:
		return
	hp = maxf(0.0, hp - damage)
	_hit_flash = 0.45
	AudioManager.play_sfx("explosion", 1.0)
	GameState.emit_signal("boss_health_changed", "Greven av Gral", hp, max_hp)
	if hp <= 0.0:
		_defeated = true
		GameState.add_coins(60)
		GameState.complete_level_story("graal_bosslevel")
		AudioManager.play_voice("gral_boss_afterfight")
		GameState.emit_signal("voice_line_started", "Pinky", "Hurra! Greven av Gral er beseiret! Skynd deg gjennom portalen!", "gral_boss_victory")
		emit_signal("boss_defeated")
