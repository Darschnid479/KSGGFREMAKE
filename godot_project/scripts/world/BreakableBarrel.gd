extends StaticBody3D
class_name BreakableBarrel
## Ødeleggbar sjørøvertønne som slipper gullmynter når Pinky slår den med sverd eller sprettert.

var hp: float = 20.0
const COIN_SCRIPT := preload("res://scripts/world/CollectibleCoin.gd")


func _ready() -> void:
	add_to_group("hittable")
	var col := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = 0.55
	shp.height = 1.2
	col.shape = shp
	col.position.y = 0.6
	add_child(col)

	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.48
	cyl.bottom_radius = 0.50
	cyl.height = 1.18
	mi.mesh = cyl
	mi.position.y = 0.59
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.25, 0.13)
	mat.roughness = 0.82
	mi.material_override = mat
	add_child(mi)


func take_hit(damage: float, _from_pos: Vector3) -> void:
	hp -= damage
	AudioManager.play_sfx("hit")
	if hp <= 0.0:
		for i in range(3):
			var c: CollectibleCoin = COIN_SCRIPT.new()
			c.position = global_position + Vector3(randf_range(-0.9, 0.9), 0.7, randf_range(-0.9, 0.9))
			get_parent().add_child(c)
		if randf() < 0.35:
			GameState.heal(15.0)
		queue_free()
