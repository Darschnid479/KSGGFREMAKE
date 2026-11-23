extends StaticBody3D
class_name BreakableBarrel
## Håndlaget sjørøvertønne med buede trestaver, smijernsbånd og gullmynter.

var hp: float = 20.0
const COIN_SCRIPT := preload("res://scripts/world/CollectibleCoin.gd")


func _ready() -> void:
	add_to_group("hittable")
	var col := CollisionShape3D.new()
	var shp := CylinderShape3D.new()
	shp.radius = 0.50
	shp.height = 1.15
	col.shape = shp
	col.position.y = 0.575
	add_child(col)

	var texs := VisualEnhancer.get_barrel_textures()
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_texture = texs[0]
	wood_mat.normal_enabled = true
	wood_mat.normal_texture = texs[1]
	wood_mat.normal_scale = 1.35
	wood_mat.roughness = 0.72
	wood_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	wood_mat.rim_enabled = true
	wood_mat.rim = 0.28

	# Buet eiketønne-kropp (dreid profil med SurfaceTool)
	var body := MeshInstance3D.new()
	body.mesh = _build_bulging_barrel_mesh(0.41, 0.49, 1.12, 16)
	body.material_override = wood_mat
	add_child(body)

	# To smijernsbånd rundt tønnen
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.16, 0.16, 0.18)
	iron_mat.metallic = 0.88
	iron_mat.roughness = 0.34
	for hy in [0.22, 0.90]:
		var hoop := MeshInstance3D.new()
		var hc := CylinderMesh.new()
		hc.top_radius = 0.468
		hc.bottom_radius = 0.468
		hc.height = 0.085
		hc.radial_segments = 16
		hoop.mesh = hc
		hoop.position.y = hy
		hoop.material_override = iron_mat
		add_child(hoop)

	# Innfelt trelokk på toppen
	var lid := MeshInstance3D.new()
	var lc := CylinderMesh.new()
	lc.top_radius = 0.38
	lc.bottom_radius = 0.38
	lc.height = 0.04
	lid.mesh = lc
	lid.position.y = 1.07
	lid.material_override = wood_mat
	add_child(lid)

	VisualEnhancer.add_contact_shadow(self, 0.65)


func _build_bulging_barrel_mesh(r_end: float, r_mid: float, height: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	for ri in range(rings):
		var v0 := float(ri) / float(rings)
		var v1 := float(ri + 1) / float(rings)
		var y0 := v0 * height
		var y1 := v1 * height
		var r0 := lerpf(r_end, r_mid, sin(v0 * PI))
		var r1 := lerpf(r_end, r_mid, sin(v1 * PI))
		for si in range(segs):
			var u0 := float(si) / float(segs)
			var u1 := float(si + 1) / float(segs)
			var a0 := u0 * TAU
			var a1 := u1 * TAU
			var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			for tri_v in [
				[p00, Vector2(u0, v0)], [p10, Vector2(u1, v0)], [p11, Vector2(u1, v1)],
				[p00, Vector2(u0, v0)], [p11, Vector2(u1, v1)], [p01, Vector2(u0, v1)],
			]:
				st.set_uv(tri_v[1])
				st.add_vertex(tri_v[0])
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


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
