extends Node3D
class_name SlingshotRock
## Prosjektil for Pinkys sprettert og Den Sorte Dames kanonkuler.

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 20.0
var _life: float = 2.6
var _radius: float = 0.16


func launch(start_pos: Vector3, dir: Vector3, damage: float = 20.0, speed: float = 26.0, radius: float = 0.16) -> void:
	global_position = start_pos
	_damage = damage
	_radius = radius
	_velocity = dir.normalized() * speed + Vector3(0.0, 2.2, 0.0)

	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = _radius
	sph.height = _radius * 2.0
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.17, 0.16) if radius > 0.25 else Color(0.42, 0.36, 0.30)
	mat.metallic = 0.65 if radius > 0.25 else 0.1
	mat.roughness = 0.4
	mi.material_override = mat
	add_child(mi)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_velocity.y -= 9.8 * delta
	global_position += _velocity * delta

	for node in get_tree().get_nodes_in_group("hittable"):
		if not (node is Node3D):
			continue
		var hit_rad: float = node.get_hit_radius() if node.has_method("get_hit_radius") else 1.3
		if global_position.distance_to(node.global_position + Vector3(0.0, 1.0, 0.0)) <= hit_rad + _radius:
			if node.has_method("take_hit"):
				node.take_hit(_damage, global_position)
			queue_free()
			return
