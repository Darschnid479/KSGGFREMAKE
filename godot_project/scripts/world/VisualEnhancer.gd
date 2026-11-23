extends RefCounted
class_name VisualEnhancer
## Moderne AAA animasjonsspill-oppgradering for materialer, lys, partikler, fakkelfat og 3D-øydetaljer.

const WORLD_PBR_SHADER := preload("res://shaders/world_pbr_enhance.gdshader")
const STYLIZED_SKY_SHADER := preload("res://shaders/stylized_sky.gdshader")
const STORM_SKY_SHADER := preload("res://shaders/storm_sky.gdshader")

static var _cached_barrel_albedo: Texture2D
static var _cached_barrel_normal: Texture2D
static var _cached_shadow_tex: Texture2D
static var _cached_micro_tex: Texture2D


static func get_micro_detail_tex() -> Texture2D:
	if _cached_micro_tex == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.08
		fn.fractal_octaves = 4
		var nt := NoiseTexture2D.new()
		nt.width = 256
		nt.height = 256
		nt.seamless = true
		nt.noise = fn
		_cached_micro_tex = nt
	return _cached_micro_tex


## Oppgrader alle materialer på en 3D-verden til moderne AAA animasjons-PBR med mikrodetalj og varm vindusglød.
static func enhance_world_node(root: Node, biome: String = "abra", water_y: float = -999.0) -> void:
	var micro_tex := get_micro_detail_tex()
	for mi in _collect_meshes(root):
		if not mi.visible or mi.mesh == null:
			continue
		var mname := mi.name.to_lower()
		var surf_cnt := mi.mesh.get_surface_count()
		for si in range(surf_cnt):
			var mat := mi.get_active_material(si)
			if mat == null or not (mat is StandardMaterial3D):
				continue
			var sm := mat as StandardMaterial3D
			var mat_name := sm.resource_name.to_lower() + " " + mname

			# Ikke erstatt alfa-utskjæringer (rigg/tauverk/løvverk) – bare finjuster dem for crisp AA
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var dup := sm.duplicate() as StandardMaterial3D
				dup.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
				dup.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
				dup.roughness = clampf(dup.roughness, 0.35, 0.85)
				if "phoenixdefuse2" in mat_name:
					# Glødende dragevingespiss på Greven av Grals drage (bevarer alle skjell-detaljer!)
					dup.emission_enabled = true
					dup.emission = Color(1.0, 0.36, 0.08)
					dup.emission_energy_multiplier = 0.95
					dup.emission_texture = dup.albedo_texture
				mi.set_surface_override_material(si, dup)
				continue

			# Ikke rør bakgrunnsskyboksen hvis det er abrabackground – bare gjør den myk og atmosfærisk
			if "background" in mname:
				var bg := sm.duplicate() as StandardMaterial3D
				bg.roughness = 0.95
				bg.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(si, bg)
				continue

			# Bygg knivskarp moderne animasjons-PBR shader fra GLB-teksturene
			var sh := ShaderMaterial.new()
			sh.shader = WORLD_PBR_SHADER
			sh.set_shader_parameter("albedo_tint", sm.albedo_color)
			sh.set_shader_parameter("has_detail_tex", true)
			sh.set_shader_parameter("detail_tex", micro_tex)
			if sm.albedo_texture:
				sh.set_shader_parameter("has_albedo_tex", true)
				sh.set_shader_parameter("albedo_tex", sm.albedo_texture)
			else:
				sh.set_shader_parameter("has_albedo_tex", false)
			if sm.normal_enabled and sm.normal_texture:
				sh.set_shader_parameter("has_normal_tex", true)
				sh.set_shader_parameter("normal_tex", sm.normal_texture)
			else:
				sh.set_shader_parameter("has_normal_tex", false)
			if sm.roughness_texture:
				sh.set_shader_parameter("has_orm_tex", true)
				sh.set_shader_parameter("orm_tex", sm.roughness_texture)
			else:
				sh.set_shader_parameter("has_orm_tex", false)

			# Biom- og materialspesifikke AAA PBR-verdier
			var micro_str := 0.34
			var micro_sc := 0.48
			var rough := clampf(sm.roughness, 0.25, 0.92)
			var metal := sm.metallic
			var sat := 1.15
			var rim_str := 0.14
			var rim_col := Color(0.86, 0.94, 1.0)
			var em_col := Color(0.0, 0.0, 0.0)
			var em_energy := 0.0

			if biome in ["cave", "cave_end", "cave_end_bosslevel"]:
				micro_str = 0.26
				micro_sc = 0.45
				rough = 0.74
				sat = 1.10
				rim_str = 0.20
				rim_col = Color(0.28, 0.95, 0.72) if "end" in biome else Color(0.95, 0.72, 0.42)
			elif biome in ["graal_bosslevel", "graal_mountain"]:
				micro_str = 0.38
				micro_sc = 0.44
				rough = 0.78
				sat = 1.12
				rim_str = 0.24
				rim_col = Color(0.55, 0.72, 1.0)
			elif biome in ["fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel"]:
				micro_str = 0.34
				micro_sc = 0.52
				rough = 0.80
				sat = 1.16
				rim_str = 0.18
				rim_col = Color(1.0, 0.86, 0.58)
			elif biome in ["abra", "menu", "outro"]:
				micro_str = 0.32
				micro_sc = 0.55
				sat = 1.18
				rim_str = 0.16
				rim_col = Color(1.0, 0.88, 0.68)

			# Materialspesifikke høydepunkter: varm vindusglød, polert gull/messing, glødende drage!
			if "window" in mat_name or "lantern" in mat_name or "bright" in mat_name:
				em_col = Color(1.0, 0.68, 0.24)
				em_energy = 1.15
				rough = 0.28
			elif "phoenixdefuse" in mat_name or "graalboss" in mname:
				if "greven" in mat_name:
					micro_str = 0.10
					rough = 0.58
					rim_str = 0.46
					rim_col = Color(0.68, 0.84, 1.0)
				else:
					# Bevar alle mørke og ildrøde skjell-detaljer på dragen + varm ild-kantglød!
					micro_str = 0.24
					rough = 0.48
					sat = 1.24
					em_col = Color(0.0, 0.0, 0.0)
					em_energy = 0.0
					rim_str = 0.58
					rim_col = Color(1.0, 0.52, 0.16)
			elif "gold" in mat_name or "rail" in mat_name or "skull" in mat_name or "brass" in mat_name:
				metal = maxf(metal, 0.52)
				rough = minf(rough, 0.34)
			elif "wood" in mat_name or "plank" in mat_name or "hull" in mat_name or "dock" in mat_name or "bridge" in mat_name:
				micro_str = 0.36
				micro_sc = 0.68
				rough = 0.64

			sh.set_shader_parameter("base_roughness", rough)
			sh.set_shader_parameter("base_metallic", metal)
			sh.set_shader_parameter("normal_strength", 0.88 if biome in ["cave", "cave_end", "cave_end_bosslevel"] else 1.25)
			sh.set_shader_parameter("micro_detail_strength", micro_str)
			sh.set_shader_parameter("micro_scale", micro_sc)
			sh.set_shader_parameter("saturation_boost", sat)
			sh.set_shader_parameter("wet_water_y", water_y)
			sh.set_shader_parameter("rim_strength", rim_str)
			sh.set_shader_parameter("rim_color", rim_col)
			sh.set_shader_parameter("emission_color", em_col)
			sh.set_shader_parameter("emission_energy", em_energy)
			mi.set_surface_override_material(si, sh)


## Oppgrader karaktermodeller (Pinky, Sabeltann, Pelle, Pysa, Skalken, fiender) med Pixar-stil rimlight & myk hud/tøy-shading!
static func enhance_character_node(root: Node, add_shadow: bool = true, shadow_radius: float = 0.72) -> void:
	for mi in _collect_meshes(root):
		if not mi.visible or mi.mesh == null:
			continue
		for si in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(si)
			if mat == null or not (mat is StandardMaterial3D):
				continue
			var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			dup.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			# Unngå plastikk-utbrenning i mørke grotter: myk fløyelsaktig animasjons-roughness
			dup.roughness = clampf(maxf(dup.roughness, 0.56), 0.52, 0.84)
			dup.metallic = minf(dup.metallic, 0.25)
			# Pixar / Ratchet & Clank kantglød som får karakterene til å poppe ut fra bakgrunnen!
			dup.rim_enabled = true
			dup.rim = 0.44
			dup.rim_tint = 0.68
			# Subtil subsurface-glød for levende animerte figurer
			dup.subsurf_scatter_enabled = true
			dup.subsurf_scatter_strength = 0.22
			mi.set_surface_override_material(si, dup)

	if add_shadow:
		add_contact_shadow(root, shadow_radius)


## Myk bakke-kontaktskygge under føttene slik at karakterer alltid står 100% forankret i verden.
static func add_contact_shadow(parent: Node, radius: float = 0.75) -> void:
	if _cached_shadow_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var dx := (float(x) / 63.0 - 0.5) * 2.0
				var dy := (float(y) / 63.0 - 0.5) * 2.0
				var d := sqrt(dx * dx + dy * dy)
				var a := clampf((1.0 - smoothstep_f(0.15, 0.98, d)) * 0.52, 0.0, 0.55)
				img.set_pixel(x, y, Color(0.02, 0.03, 0.06, a))
		_cached_shadow_tex = ImageTexture.create_from_image(img)

	var sh := MeshInstance3D.new()
	sh.name = "ContactShadow"
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	sh.mesh = pm
	sh.position = Vector3(0.0, 0.03, 0.0)
	sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _cached_shadow_tex
	mat.no_depth_test = false
	sh.material_override = mat
	parent.add_child(sh)


## Bygg konfigurert AAA animasjonshimmel (stylized_sky eller storm_sky) tilpasset hvert kapittel.
static func create_biome_sky(level_id: String, cfg: Dictionary) -> Sky:
	var sky := Sky.new()
	if level_id in ["graal_bosslevel", "graal_mountain"]:
		var ssm := ShaderMaterial.new()
		ssm.shader = STORM_SKY_SHADER
		sky.sky_material = ssm
		return sky

	var mat := ShaderMaterial.new()
	mat.shader = STYLIZED_SKY_SHADER

	match level_id:
		"menu", "outro":
			mat.set_shader_parameter("zenith_color", Color(0.08, 0.22, 0.56))
			mat.set_shader_parameter("mid_color", Color(0.28, 0.48, 0.78))
			mat.set_shader_parameter("horizon_color", Color(1.0, 0.64, 0.34))
			mat.set_shader_parameter("ground_color", Color(0.05, 0.14, 0.26))
			mat.set_shader_parameter("sun_color", Color(1.0, 0.84, 0.46))
			mat.set_shader_parameter("cloud_lit", Color(1.0, 0.82, 0.56))
			mat.set_shader_parameter("cloud_shadow", Color(0.32, 0.28, 0.48))
			mat.set_shader_parameter("sun_dir", Vector3(0.45, 0.16, -0.88))
			mat.set_shader_parameter("cloud_coverage", 0.50)
		"abra", "treasurehunt":
			mat.set_shader_parameter("zenith_color", Color(0.06, 0.34, 0.82))
			mat.set_shader_parameter("mid_color", Color(0.20, 0.64, 0.96))
			mat.set_shader_parameter("horizon_color", Color(0.98, 0.86, 0.68))
			mat.set_shader_parameter("ground_color", Color(0.04, 0.20, 0.34))
			mat.set_shader_parameter("sun_color", Color(1.0, 0.94, 0.74))
			mat.set_shader_parameter("cloud_lit", Color(1.0, 0.98, 0.92))
			mat.set_shader_parameter("cloud_shadow", Color(0.44, 0.60, 0.82))
			mat.set_shader_parameter("sun_dir", Vector3(-0.52, 0.32, -0.78))
			mat.set_shader_parameter("cloud_coverage", 0.48)
		"fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel":
			mat.set_shader_parameter("zenith_color", Color(0.08, 0.36, 0.78))
			mat.set_shader_parameter("mid_color", Color(0.32, 0.64, 0.92))
			mat.set_shader_parameter("horizon_color", Color(1.0, 0.78, 0.44))
			mat.set_shader_parameter("ground_color", Color(0.55, 0.38, 0.22))
			mat.set_shader_parameter("sun_color", Color(1.0, 0.90, 0.56))
			mat.set_shader_parameter("cloud_lit", Color(1.0, 0.94, 0.78))
			mat.set_shader_parameter("cloud_shadow", Color(0.62, 0.56, 0.70))
			mat.set_shader_parameter("sun_dir", Vector3(0.62, 0.26, -0.74))
			mat.set_shader_parameter("cloud_coverage", 0.38)
		"magakhan_beach", "magakhan_jungle", "magakhan_palace":
			mat.set_shader_parameter("zenith_color", Color(0.05, 0.38, 0.72))
			mat.set_shader_parameter("mid_color", Color(0.18, 0.68, 0.82))
			mat.set_shader_parameter("horizon_color", Color(0.84, 0.94, 0.78))
			mat.set_shader_parameter("ground_color", Color(0.08, 0.22, 0.14))
			mat.set_shader_parameter("sun_color", Color(1.0, 0.95, 0.72))
			mat.set_shader_parameter("cloud_lit", Color(1.0, 0.99, 0.92))
			mat.set_shader_parameter("cloud_shadow", Color(0.34, 0.58, 0.64))
			mat.set_shader_parameter("sun_dir", Vector3(0.45, 0.38, -0.80))
			mat.set_shader_parameter("cloud_coverage", 0.52)
		"world_map":
			mat.set_shader_parameter("zenith_color", Color(0.07, 0.36, 0.84))
			mat.set_shader_parameter("mid_color", Color(0.22, 0.66, 0.96))
			mat.set_shader_parameter("horizon_color", Color(0.95, 0.88, 0.72))
			mat.set_shader_parameter("ground_color", Color(0.02, 0.16, 0.32))
			mat.set_shader_parameter("sun_color", Color(1.0, 0.94, 0.76))
			mat.set_shader_parameter("cloud_lit", Color(1.0, 0.98, 0.94))
			mat.set_shader_parameter("cloud_shadow", Color(0.42, 0.62, 0.84))
			mat.set_shader_parameter("sun_dir", Vector3(0.45, 0.55, -0.70))
			mat.set_shader_parameter("cloud_coverage", 0.42)
		_:
			mat.set_shader_parameter("zenith_color", cfg.get("sky_top", Color(0.04, 0.10, 0.14)))
			mat.set_shader_parameter("mid_color", cfg.get("sky_horizon", Color(0.10, 0.24, 0.22)))
			mat.set_shader_parameter("horizon_color", cfg.get("fog_color", Color(0.08, 0.18, 0.16)))
			mat.set_shader_parameter("ground_color", Color(0.02, 0.05, 0.06))
			mat.set_shader_parameter("sun_color", cfg.get("sun_color", Color(0.45, 1.0, 0.72)))
			mat.set_shader_parameter("cloud_lit", cfg.get("sun_color", Color(0.45, 1.0, 0.72)))
			mat.set_shader_parameter("cloud_shadow", Color(0.04, 0.10, 0.10))
			mat.set_shader_parameter("cloud_coverage", 0.35)

	sky.sky_material = mat
	return sky


## Glødende smijern-fakkelfat med animerte flammer, gnister og varmt lys (Gral borg / grotter).
static func spawn_fire_brazier(parent: Node, pos: Vector3, scale_val: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_val
	parent.add_child(root)

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.14, 0.13, 0.15)
	iron_mat.metallic = 0.85
	iron_mat.roughness = 0.38

	# Smijern-stativ og skål
	var stand := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.26
	scyl.bottom_radius = 0.34
	scyl.height = 0.58
	stand.mesh = scyl
	stand.position.y = 0.29
	stand.material_override = iron_mat
	root.add_child(stand)

	var bowl := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.52
	bcyl.bottom_radius = 0.28
	bcyl.height = 0.30
	bowl.mesh = bcyl
	bowl.position.y = 0.68
	bowl.material_override = iron_mat
	root.add_child(bowl)

	# Glødende kull + stilisert flammekjerne
	var coals := MeshInstance3D.new()
	var csph := SphereMesh.new()
	csph.radius = 0.42
	csph.height = 0.32
	coals.mesh = csph
	coals.position.y = 0.82
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(1.0, 0.42, 0.08)
	cmat.emission_enabled = true
	cmat.emission = Color(1.0, 0.48, 0.10)
	cmat.emission_energy_multiplier = 3.2
	coals.material_override = cmat
	root.add_child(coals)

	# Lagdelt 3D-flamme (ydre oransje + indre lys gul)
	for f_info in [
		[0.34, 0.88, 1.15, Color(1.0, 0.38, 0.04, 0.88), 3.6],
		[0.20, 0.62, 1.08, Color(1.0, 0.86, 0.32, 0.95), 4.8],
	]:
		var fl := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = float(f_info[0])
		cone.height = float(f_info[1])
		fl.mesh = cone
		fl.position.y = float(f_info[2])
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fmat := StandardMaterial3D.new()
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = f_info[3]
		fmat.emission_enabled = true
		fmat.emission = Color(f_info[3].r, f_info[3].g, f_info[3].b)
		fmat.emission_energy_multiplier = float(f_info[4])
		fl.material_override = fmat
		root.add_child(fl)

	# Stigende glødende gnister (GPUParticles3D)
	var pts := GPUParticles3D.new()
	pts.position = Vector3(0.0, 1.0, 0.0)
	pts.amount = 28
	pts.lifetime = 1.6
	pts.preprocess = 1.2
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.28
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 24.0
	pmat.initial_velocity_min = 1.2
	pmat.initial_velocity_max = 2.6
	pmat.gravity = Vector3(0.25, 0.4, 0.0)
	pmat.scale_min = 0.04
	pmat.scale_max = 0.11
	pmat.color = Color(1.0, 0.68, 0.22)
	pts.process_material = pmat
	var qm := SphereMesh.new()
	qm.radius = 0.14
	qm.height = 0.28
	qm.radial_segments = 6
	qm.rings = 4
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.albedo_color = Color(1.0, 0.78, 0.28)
	qmat.emission_enabled = true
	qmat.emission = Color(1.0, 0.56, 0.12)
	qmat.emission_energy_multiplier = 4.0
	qm.material = qmat
	pts.draw_pass_1 = qm
	root.add_child(pts)

	# Varmt flammelys som gir kinematisk oransje-vs-blå kontrast
	var lgt := OmniLight3D.new()
	lgt.position = Vector3(0.0, 1.45, 0.0)
	lgt.light_color = Color(1.0, 0.58, 0.20)
	lgt.light_energy = 5.2
	lgt.omni_range = 16.0
	lgt.omni_attenuation = 1.4
	root.add_child(lgt)
	return root


## Atmosfæriske svevende 3D-partikler per biom (gullstøv, glør, grønne spøkelsessporer).
static func spawn_ambient_particles(parent: Node, center: Vector3, biome: String) -> GPUParticles3D:
	var pts := GPUParticles3D.new()
	pts.name = "AmbientAtmosphereParticles"
	pts.position = center + Vector3(0.0, 3.5, 0.0)
	pts.amount = 90
	pts.lifetime = 5.5
	pts.preprocess = 3.0
	pts.visibility_aabb = AABB(Vector3(-45, -20, -45), Vector3(90, 45, 90))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(22.0, 8.0, 22.0)

	var col := Color(1.0, 0.92, 0.68)
	var em_energy := 2.4
	if biome in ["cave_end", "cave_end_bosslevel"]:
		col = Color(0.28, 1.0, 0.66)
		em_energy = 3.6
		pmat.direction = Vector3(0.0, 1.0, 0.0)
		pmat.initial_velocity_min = 0.3
		pmat.initial_velocity_max = 0.8
		pmat.gravity = Vector3(0.0, 0.18, 0.0)
	elif biome in ["graal_bosslevel", "graal_mountain", "magakhan_dungeon", "magakhan_endboss_level"]:
		col = Color(1.0, 0.56, 0.16)
		em_energy = 4.2
		pmat.direction = Vector3(0.3, 1.0, 0.1)
		pmat.initial_velocity_min = 0.7
		pmat.initial_velocity_max = 1.6
		pmat.gravity = Vector3(0.2, 0.35, 0.0)
	else:
		# Varmt gyllent solstøv / hav-glitter i Abra Havn og Fata Morgana
		col = Color(1.0, 0.92, 0.66)
		em_energy = 2.0
		pmat.direction = Vector3(0.2, 0.3, 0.0)
		pmat.initial_velocity_min = 0.15
		pmat.initial_velocity_max = 0.45
		pmat.gravity = Vector3(0.05, 0.05, 0.0)

	pmat.spread = 45.0
	pmat.scale_min = 0.03
	pmat.scale_max = 0.07
	pts.process_material = pmat

	var sp := SphereMesh.new()
	sp.radius = 0.14
	sp.height = 0.28
	sp.radial_segments = 6
	sp.rings = 4
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = col
	smat.emission_enabled = true
	smat.emission = col
	smat.emission_energy_multiplier = em_energy
	sp.material = smat
	pts.draw_pass_1 = sp
	parent.add_child(pts)
	return pts


## Skummende organisk V-kjølvann med bølgeskum-shader bak skipene på verdenskartet!
static func attach_ship_wake(ship_node: Node3D, wake_scale: float = 1.0) -> void:
	var wake := MeshInstance3D.new()
	wake.name = "ShipWake"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 12
	var length := 15.0 * wake_scale
	var w_start := 1.8 * wake_scale
	var w_end := 7.2 * wake_scale
	for r in range(rows):
		var t0 := float(r) / float(rows)
		var t1 := float(r + 1) / float(rows)
		var z0 := t0 * length
		var z1 := t1 * length
		var hw0 := lerpf(w_start, w_end, pow(t0, 0.85))
		var hw1 := lerpf(w_start, w_end, pow(t1, 0.85))
		var p0 := Vector3(-hw0, 0.14, z0)
		var p1 := Vector3(hw0, 0.14, z0)
		var p2 := Vector3(-hw1, 0.14, z1)
		var p3 := Vector3(hw1, 0.14, z1)
		for v in [
			[p0, Vector2(0.0, t0)], [p1, Vector2(1.0, t0)], [p3, Vector2(1.0, t1)],
			[p0, Vector2(0.0, t0)], [p3, Vector2(1.0, t1)], [p2, Vector2(0.0, t1)],
		]:
			st.set_uv(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	wake.mesh = st.commit()
	wake.position = Vector3(0.0, 0.05, 3.4 * wake_scale)
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/ship_wake.gdshader")
	wake.material_override = smat
	ship_node.add_child(wake)


## Dekorer hver øy på Verdenskartet med håndlagde stiliserte 3D-palmer, tårn, sjørøverhus, kupler og fyrtårn!
static func decorate_world_map_island(root: Node3D, radius: float, theme: String, seed_val: int, is_active_story: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 1337

	# 1. Hovedlandemerke midt på øya (slik at hver øy ser umiddelbart gjenkjennelig ut ovenfra!)
	match theme:
		"harbor":
			# Abra Havn: Sjørøverlandsby med varme lysende vinduer + hvitt fyrtårn
			for h_off in [Vector3(-2.6, 2.2, 2.2), Vector3(1.8, 2.5, 1.5), Vector3(-0.6, 3.4, -1.8), Vector3(3.0, 1.9, -1.2)]:
				_add_mini_house(root, h_off, rng.randf_range(0.0, TAU), Color(0.46, 0.28, 0.16), Color(0.58, 0.18, 0.12))
			_add_lighthouse(root, Vector3(0.2, 4.2, 0.2), Color(1.0, 0.84, 0.36))
			for _i in range(11):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.28, radius * 0.62)
				_add_mini_palm(root, Vector3(cos(ang) * d, 1.4, sin(ang) * d), rng.randf_range(0.85, 1.3))
		"castle":
			# Gral: Mørk gotisk borg med 4 tårn og magisk oransje drageflamme på toppen!
			_add_mini_castle(root, Vector3(0.0, 5.4, 0.0))
			for _i in range(12):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.34, radius * 0.64)
				_add_mini_pine(root, Vector3(cos(ang) * d, 1.8, sin(ang) * d), rng.randf_range(0.9, 1.35))
		"desert":
			# Fata Morgana: Gyllent arabisk sultanpalass med hvite/gylne kupler, minareter og daddelpalmer!
			_add_mini_arabian_palace(root, Vector3(0.0, 3.4, 0.0))
			for _i in range(9):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.34, radius * 0.62)
				_add_mini_palm(root, Vector3(cos(ang) * d, 1.3, sin(ang) * d), rng.randf_range(0.8, 1.2))
		"jungle":
			# Maga Khans øy: Tett smaragdgrønn tropisk regnskog + tempelpyramide!
			_add_mini_jungle_temple(root, Vector3(0.0, 4.4, 0.0))
			for _i in range(20):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.24, radius * 0.66)
				_add_mini_palm(root, Vector3(cos(ang) * d, 1.6, sin(ang) * d), rng.randf_range(0.95, 1.45))
		_:
			# Skattejakt-øya: Tropiske palmer + skinnende gullskattkiste-glød!
			for _i in range(8):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.24, radius * 0.58)
				_add_mini_palm(root, Vector3(cos(ang) * d, 1.3, sin(ang) * d), rng.randf_range(0.9, 1.3))
			var chest := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(1.8, 1.2, 1.2)
			chest.mesh = b
			chest.position = Vector3(0.0, 3.8, 0.0)
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.95, 0.74, 0.18)
			cmat.metallic = 0.85
			cmat.roughness = 0.25
			cmat.emission_enabled = true
			cmat.emission = Color(1.0, 0.76, 0.18)
			cmat.emission_energy_multiplier = 1.6
			chest.material_override = cmat
			root.add_child(chest)

	# Hvis øya er gjeldende historiemål: varm gyllen fyrtårn-lysstråle rett over øya!
	if is_active_story:
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 1.6
		cyl.height = 18.0
		beam.mesh = cyl
		beam.position = Vector3(0.0, 12.0, 0.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bmat := StandardMaterial3D.new()
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color(1.0, 0.86, 0.38, 0.22)
		beam.material_override = bmat
		root.add_child(beam)


static func _add_mini_palm(parent: Node3D, pos: Vector3, s: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation_degrees = Vector3(randf_range(-10.0, 10.0), randf_range(0.0, 360.0), randf_range(-10.0, 10.0))
	parent.add_child(n)

	var trunk := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.14
	tc.bottom_radius = 0.28
	tc.height = 3.0
	trunk.mesh = tc
	trunk.position.y = 1.5
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.44, 0.28, 0.14)
	tmat.roughness = 0.88
	trunk.material_override = tmat
	n.add_child(trunk)

	# Frodig avrundet Pixar-løvkrone med buede palmeblader (ingen firkantede kryss!)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.14, 0.48, 0.16)
	lmat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	lmat.roughness = 0.70
	lmat.rim_enabled = true
	lmat.rim = 0.38

	var lmat_bright := StandardMaterial3D.new()
	lmat_bright.albedo_color = Color(0.24, 0.62, 0.20)
	lmat_bright.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	lmat_bright.roughness = 0.66
	lmat_bright.rim_enabled = true
	lmat_bright.rim = 0.42

	# Myk tropisk krone i sentrum + 7 buede, spisse palmeblader
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.82
	cs.height = 0.95
	core.mesh = cs
	core.position.y = 3.05
	core.material_override = lmat_bright
	n.add_child(core)

	for i in range(7):
		var ang := (float(i) / 7.0) * TAU + randf_range(-0.15, 0.15)
		var frond := MeshInstance3D.new()
		var fm := SphereMesh.new()
		fm.radius = 0.42
		fm.height = 2.0
		fm.radial_segments = 8
		fm.rings = 5
		frond.mesh = fm
		frond.scale = Vector3(0.85, 1.0, 0.24)
		frond.position = Vector3(sin(ang) * 0.95, 2.88, cos(ang) * 0.95)
		frond.rotation = Vector3(1.18, ang, 0.0)
		frond.material_override = lmat if (i % 2 == 0) else lmat_bright
		n.add_child(frond)


static func _add_mini_pine(parent: Node3D, pos: Vector3, s: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	parent.add_child(n)

	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.10, 0.22, 0.16)
	lmat.roughness = 0.82
	for tier in [[0.0, 1.4, 2.6, 1.3], [0.0, 2.7, 2.2, 0.95]]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = float(tier[3])
		cm.height = float(tier[2])
		c.mesh = cm
		c.position.y = float(tier[1])
		c.material_override = lmat
		n.add_child(c)


static func _add_mini_house(parent: Node3D, pos: Vector3, rot_y: float, wall_col: Color, roof_col: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 1.8, 1.8)
	body.mesh = bm
	body.position.y = 0.9
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = wall_col
	wmat.roughness = 0.82
	body.material_override = wmat
	n.add_child(body)

	var roof := MeshInstance3D.new()
	var rm := PrismMesh.new()
	rm.size = Vector3(2.5, 1.2, 2.1)
	roof.mesh = rm
	roof.position.y = 2.35
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = roof_col
	rmat.roughness = 0.72
	roof.material_override = rmat
	n.add_child(roof)

	# Varmt glødende vindu
	var win := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(2.28, 0.55, 0.65)
	win.mesh = wm
	win.position.y = 1.0
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1.0, 0.82, 0.34)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.74, 0.24)
	gmat.emission_energy_multiplier = 2.4
	win.material_override = gmat
	n.add_child(win)


static func _add_lighthouse(parent: Node3D, pos: Vector3, glow_col: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)

	var twr := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.65
	tc.bottom_radius = 1.05
	tc.height = 4.6
	twr.mesh = tc
	twr.position.y = 2.3
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.92, 0.88, 0.80)
	wmat.roughness = 0.75
	twr.material_override = wmat
	n.add_child(twr)

	var lamp := MeshInstance3D.new()
	var ls := SphereMesh.new()
	ls.radius = 0.72
	ls.height = 1.44
	lamp.mesh = ls
	lamp.position.y = 5.0
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = glow_col
	lmat.emission_enabled = true
	lmat.emission = glow_col
	lmat.emission_energy_multiplier = 3.2
	lamp.material_override = lmat
	n.add_child(lamp)


static func _add_mini_castle(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.24, 0.22, 0.28)
	smat.roughness = 0.84

	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.14, 0.10, 0.22)
	rmat.roughness = 0.68

	var keep := MeshInstance3D.new()
	var kb := BoxMesh.new()
	kb.size = Vector3(4.6, 4.0, 4.6)
	keep.mesh = kb
	keep.position.y = 2.0
	keep.material_override = smat
	n.add_child(keep)

	for off in [Vector3(-2.3, 0.0, -2.3), Vector3(2.3, 0.0, -2.3), Vector3(-2.3, 0.0, 2.3), Vector3(2.3, 0.0, 2.3)]:
		var t := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.75
		tc.bottom_radius = 0.88
		tc.height = 5.6
		t.mesh = tc
		t.position = off + Vector3(0.0, 2.8, 0.0)
		t.material_override = smat
		n.add_child(t)

		var spire := MeshInstance3D.new()
		var sc := CylinderMesh.new()
		sc.top_radius = 0.04
		sc.bottom_radius = 0.92
		sc.height = 2.2
		spire.mesh = sc
		spire.position = off + Vector3(0.0, 6.6, 0.0)
		spire.material_override = rmat
		n.add_child(spire)

	# Glødende drage-flammefyr i borgtårnet
	var flame := MeshInstance3D.new()
	var fs := SphereMesh.new()
	fs.radius = 0.95
	fs.height = 1.9
	flame.mesh = fs
	flame.position.y = 5.4
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.42, 0.14)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.36, 0.10)
	fmat.emission_energy_multiplier = 3.2
	flame.material_override = fmat
	n.add_child(flame)


static func _add_mini_arabian_palace(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)

	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.92, 0.78, 0.52)
	sand_mat.roughness = 0.76

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.98, 0.78, 0.24)
	gold_mat.metallic = 0.72
	gold_mat.roughness = 0.26

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.2, 2.8, 4.4)
	base.mesh = bm
	base.position.y = 1.4
	base.material_override = sand_mat
	n.add_child(base)

	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 2.0
	dm.height = 3.8
	dome.mesh = dm
	dome.position.y = 3.4
	dome.material_override = gold_mat
	n.add_child(dome)

	for moff in [Vector3(-2.8, 0.0, -2.2), Vector3(2.8, 0.0, -2.2), Vector3(-2.8, 0.0, 2.2), Vector3(2.8, 0.0, 2.2)]:
		var min_t := MeshInstance3D.new()
		var mc := CylinderMesh.new()
		mc.top_radius = 0.42
		mc.bottom_radius = 0.58
		mc.height = 5.4
		min_t.mesh = mc
		min_t.position = moff + Vector3(0.0, 2.7, 0.0)
		min_t.material_override = sand_mat
		n.add_child(min_t)

		var cap := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.62
		cs.height = 1.4
		cap.mesh = cs
		cap.position = moff + Vector3(0.0, 5.7, 0.0)
		cap.material_override = gold_mat
		n.add_child(cap)


static func _add_mini_jungle_temple(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.32, 0.36, 0.28)
	smat.roughness = 0.86

	for tier in [[5.2, 1.4, 0.7], [3.6, 1.4, 2.1], [2.1, 1.4, 3.5]]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(float(tier[0]), float(tier[1]), float(tier[0]))
		b.mesh = bm
		b.position.y = float(tier[2])
		b.material_override = smat
		n.add_child(b)

	var gem := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.65
	gs.height = 1.3
	gem.mesh = gs
	gem.position.y = 4.9
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.24, 0.96, 0.56)
	gmat.emission_enabled = true
	gmat.emission = Color(0.20, 0.95, 0.52)
	gmat.emission_energy_multiplier = 2.8
	gem.material_override = gmat
	n.add_child(gem)


## Prosedyrell treverk-tekstur for håndlagde sjørøvertønner (ingen ensfargede sylindre!).
static func get_barrel_textures() -> Array:
	if _cached_barrel_albedo != null and _cached_barrel_normal != null:
		return [_cached_barrel_albedo, _cached_barrel_normal]

	var w := 256
	var h := 256
	var alb_img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var nrm_img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var staves := 12.0
	for y in range(h):
		var v := float(y) / float(h)
		for x in range(w):
			var u := float(x) / float(w)
			var stave_f := fmod(u * staves, 1.0)
			var stave_idx := floorf(u * staves)
			var seam := smoothstep_f(0.0, 0.06, stave_f) * (1.0 - smoothstep_f(0.94, 1.0, stave_f))
			var grain := sin((v * 26.0 + stave_idx * 1.7 + sin(u * 60.0) * 0.25)) * 0.5 + 0.5
			var plank_tint := 0.85 + 0.22 * sin(stave_idx * 3.7)
			var shade := (0.45 + 0.55 * seam) * (0.86 + 0.14 * grain) * plank_tint
			var col := Color(0.46 * shade, 0.26 * shade, 0.12 * shade)
			alb_img.set_pixel(x, y, col)

			var nx := 0.5
			if stave_f < 0.08:
				nx = 0.22
			elif stave_f > 0.92:
				nx = 0.78
			else:
				nx = 0.5 + (grain - 0.5) * 0.18
			nrm_img.set_pixel(x, y, Color(nx, 0.5, 0.94))

	_cached_barrel_albedo = ImageTexture.create_from_image(alb_img)
	_cached_barrel_normal = ImageTexture.create_from_image(nrm_img)
	return [_cached_barrel_albedo, _cached_barrel_normal]


static func smoothstep_f(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / maxf(e1 - e0, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _collect_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_collect_meshes(c))
	return out
