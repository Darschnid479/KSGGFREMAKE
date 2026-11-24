extends StaticBody3D
class_name EnemyShip
## Patruljerende sjørøverskip på verdenskartet som kan senkes med Den Sorte Dames bredsider!

var center_pos: Vector3 = Vector3.ZERO
var patrol_radius: float = 24.0
var patrol_speed: float = 0.25
var max_hp: float = 80.0
var hp: float = 80.0
var _angle: float = 0.0
var _sinking: bool = false
var _flash: float = 0.0
var _ship_visual: Node3D
var _base_scale: Vector3 = Vector3.ONE


func setup_ship(visual: Node3D, center: Vector3, start_angle: float) -> void:
	_ship_visual = visual
	_base_scale = visual.scale
	add_child(visual)
	center_pos = center
	_angle = start_angle
	global_position = center + Vector3(cos(_angle) * patrol_radius, 2.0, sin(_angle) * patrol_radius)
	add_to_group("hittable")

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 7.5
	col.shape = sph
	col.position.y = 3.5
	add_child(col)


func get_hit_radius() -> float:
	return 11.0


func _physics_process(delta: float) -> void:
	if _sinking:
		global_position.y -= 2.4 * delta
		rotation.z += 0.55 * delta
		if global_position.y < -12.0:
			queue_free()
		return

	_angle += patrol_speed * delta
	var nx := center_pos.x + cos(_angle) * patrol_radius
	var nz := center_pos.z + sin(_angle) * patrol_radius
	var next_p := Vector3(nx, 2.0 + sin(_angle * 3.0) * 0.22, nz)
	var dir := next_p - global_position
	global_position = next_p
	if dir.length_squared() > 0.0001:
		rotation.y = atan2(-dir.x, -dir.z)

	if _flash > 0.0:
		_flash -= delta
		if is_instance_valid(_ship_visual):
			_ship_visual.scale = _base_scale * (1.0 + sin(_flash * 35.0) * 0.08)


func take_hit(damage: float, _from_pos: Vector3) -> void:
	if _sinking:
		return
	hp = maxf(0.0, hp - damage)
	_flash = 0.3
	AudioManager.play_sfx("hit", 0.9)
	if hp <= 0.0:
		_sinking = true
		GameState.add_coins(25)
		AudioManager.play_sfx("explosion", 1.0)
