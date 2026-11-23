extends RefCounted
class_name VisualEnhancer
## Moderne AAA animasjonsspill-oppgradering for materialer, lys, partikler, fakkelfat og 3D-øydetaljer.

const WORLD_PBR_SHADER := preload("res://shaders/world_pbr_enhance.gdshader")
const STYLIZED_SKY_SHADER := preload("res://shaders/stylized_sky.gdshader")
const STORM_SKY_SHADER := preload("res://shaders/storm_sky.gdshader")

static var _cached_barrel_albedo: Texture2D
static var _cached_barrel_normal: Texture2D
static var _cached_shadow_tex: Texture2D
static var _cached_pbr_packs: Dictionary = {}


static func get_pbr_pack(pack_name: String) -> Dictionary:
	if _cached_pbr_packs.has(pack_name):
		return _cached_pbr_packs[pack_name]
	var base := "res://assets/textures/pbr/" + pack_name
	var d := {}
	if ResourceLoader.exists(base + "_albedo.png"):
		d["albedo"] = load(base + "_albedo.png") as Texture2D
	if ResourceLoader.exists(base + "_normal.png"):
		d["normal"] = load(base + "_normal.png") as Texture2D
	if ResourceLoader.exists(base + "_rough.png"):
		d["rough"] = load(base + "_rough.png") as Texture2D
	_cached_pbr_packs[pack_name] = d
	return d


static func _pick_pbr_pack_name(mat_name: String, biome: String) -> String:
	# 2.5D undervanns-grunnfjell på "blackwall" / "black" slik at ingen flate mørkeblå tomrom finnes!
	if "blackwall" in mat_name or mat_name.strip_edges().begins_with("black "):
		return "cutaway_bedrock"
	if "gold" in mat_name or "rail" in mat_name or "skull" in mat_name or "brass" in mat_name or "metal" in mat_name or "bell" in mat_name or "cannon" in mat_name:
		return "forged_metal"
	if "roof" in mat_name or "tile" in mat_name or "shingle" in mat_name:
		return "roof_shingles"
	if "plank" in mat_name or "wood" in mat_name or "hull" in mat_name or "dock" in mat_name or "bridge" in mat_name or "pole" in mat_name or "door" in mat_name or "box" in mat_name or "crate" in mat_name or "catapult" in mat_name or "rowboat" in mat_name or "scaffold" in mat_name or "balcony" in mat_name or "housewall" in mat_name or "mainbuilding" in mat_name:
		return "wood_planks"
	if biome in ["fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel"] and ("sultan" in mat_name or "wall" in mat_name or "plain" in mat_name or "ground" in mat_name or "entrance" in mat_name):
		return "sandstone_wall"
	if "stone" in mat_name or "rock" in mat_name or "brick" in mat_name or "cave" in mat_name or "castle" in mat_name or "well" in mat_name or "foundation" in mat_name or "chimney" in mat_name or "pussle" in mat_name or "puussle" in mat_name or "under" in mat_name or "dungeon" in mat_name or "ground" in mat_name:
		return "stone_masonry"
	if biome in ["abra", "menu", "outro"]:
		return "wood_planks"
	return "stone_masonry"


## Oppgrader alle materialer på en 3D-verden til knivskarp moderne AAA PBR med nye sømløse 512x512 teksturer og normalmaps!
static func enhance_world_node(root: Node, biome: String = "abra", water_y: float = -999.0) -> void:
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

			# Ikke erstatt alfa-utskjæringer (rigg/tauverk/løvverk/sjøgress) – bare gi dyp rik kontrast!
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var dup := sm.duplicate() as StandardMaterial3D
				dup.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
				dup.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
				dup.roughness = clampf(dup.roughness, 0.35, 0.82)
				dup.albedo_color = Color(dup.albedo_color.r * 0.86, dup.albedo_color.g * 0.88, dup.albedo_color.b * 0.86, dup.albedo_color.a)
				if "phoenixdefuse2" in mat_name:
					dup.emission_enabled = true
					dup.emission = Color(1.0, 0.36, 0.08)
					dup.emission_energy_multiplier = 0.95
					dup.emission_texture = dup.albedo_texture
				mi.set_surface_override_material(si, dup)
				continue

			if "background" in mname and not ("backgroundwall" in mname):
				var bg := sm.duplicate() as StandardMaterial3D
				bg.roughness = 0.95
				bg.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(si, bg)
				continue

			# Bygg knivskarp moderne AAA PBR-shader med ekte 512x512 teksturpakke for denne overflatetypen!
			var sh := ShaderMaterial.new()
			sh.shader = WORLD_PBR_SHADER
			sh.set_shader_parameter("albedo_tint", sm.albedo_color)
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

			var pack_name := _pick_pbr_pack_name(mat_name, biome)
			var pack := get_pbr_pack(pack_name)
			var is_cutaway := (pack_name == "cutaway_bedrock")
			var is_boss := ("phoenixdefuse" in mat_name or "graalboss" in mname)
			if not is_boss and pack.has("albedo") and pack.has("normal") and pack.has("rough"):
				sh.set_shader_parameter("has_pbr_pack", true)
				sh.set_shader_parameter("pbr_albedo_tex", pack["albedo"])
				sh.set_shader_parameter("pbr_normal_tex", pack["normal"])
				sh.set_shader_parameter("pbr_rough_tex", pack["rough"])
			else:
				sh.set_shader_parameter("has_pbr_pack", false)

			var pbr_blend := 0.50
			var tile_scale := 0.36
			var contrast_gamma := 1.24
			var rough := clampf(sm.roughness, 0.25, 0.90)
			var metal := sm.metallic
			var sat := 1.24
			var rim_str := 0.06
			var rim_col := Color(0.86, 0.94, 1.0)
			var em_col := Color(0.0, 0.0, 0.0)
			var em_energy := 0.0
			var nrm_str := 1.50

			if is_cutaway:
				# Mørkt, matt 2.5D grunnfjell-skifer som rammer inn den opplyste steintunnelen uten gjenskinn!
				pbr_blend = 0.98
				tile_scale = 0.24
				contrast_gamma = 1.05
				rough = 0.92
				sat = 0.72
				nrm_str = 1.35
				rim_str = 0.0
				sh.set_shader_parameter("has_albedo_tex", false)
				sh.set_shader_parameter("albedo_tint", Color(0.18, 0.24, 0.30, 1.0))
			elif pack_name == "wood_planks":
				pbr_blend = 0.64
				tile_scale = 0.46
				rough = 0.58
				nrm_str = 1.75
			elif pack_name == "stone_masonry":
				pbr_blend = 0.66
				tile_scale = 0.36
				rough = 0.70
				nrm_str = 1.85
			elif pack_name == "sandstone_wall":
				pbr_blend = 0.60
				tile_scale = 0.40
				rough = 0.72
				nrm_str = 1.65
			elif pack_name == "roof_shingles":
				pbr_blend = 0.68
				tile_scale = 0.44
				rough = 0.60
				nrm_str = 1.75
			elif pack_name == "forged_metal":
				pbr_blend = 0.64
				tile_scale = 0.78
				metal = maxf(metal, 0.76)
				rough = 0.22
				nrm_str = 1.45

			if not is_cutaway:
				if biome in ["cave", "cave_end", "cave_end_bosslevel"]:
					contrast_gamma = 1.24
					sat = 1.24
					rim_str = 0.08
					rim_col = Color(0.28, 0.95, 0.72) if "end" in biome else Color(0.55, 0.88, 1.0)
				elif biome in ["graal_bosslevel", "graal_mountain"]:
					contrast_gamma = 1.24
					sat = 1.22
					rim_str = 0.10
					rim_col = Color(0.55, 0.72, 1.0)
				elif biome in ["fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel"]:
					contrast_gamma = 1.28
					sat = 1.28
				elif biome in ["abra", "menu", "outro"]:
					contrast_gamma = 1.30
					sat = 1.28

			if "window" in mat_name or "lantern" in mat_name or "bright" in mat_name:
				em_col = Color(1.0, 0.64, 0.20)
				em_energy = 1.10
				rough = 0.26
				pbr_blend = 0.12
			elif is_boss:
				if "greven" in mat_name:
					contrast_gamma = 1.18
					rough = 0.56
					rim_str = 0.32
					rim_col = Color(0.68, 0.84, 1.0)
				else:
					contrast_gamma = 1.22
					rough = 0.44
					sat = 1.32
					em_col = Color(0.0, 0.0, 0.0)
					em_energy = 0.0
					rim_str = 0.48
					rim_col = Color(1.0, 0.48, 0.12)

			sh.set_shader_parameter("base_roughness", rough)
			sh.set_shader_parameter("base_metallic", metal)
			sh.set_shader_parameter("normal_strength", nrm_str)
			sh.set_shader_parameter("pbr_blend", pbr_blend)
			sh.set_shader_parameter("pbr_tile_scale", tile_scale)
			sh.set_shader_parameter("contrast_gamma", contrast_gamma)
			sh.set_shader_parameter("saturation_boost", sat)
			sh.set_shader_parameter("wet_water_y", water_y)
			sh.set_shader_parameter("rim_strength", rim_str)
			sh.set_shader_parameter("rim_color", rim_col)
			sh.set_shader_parameter("emission_color", em_col)
			sh.set_shader_parameter("emission_energy", em_energy)
			mi.set_surface_override_material(si, sh)


## Oppgrader karaktermodeller (Pinky, Sabeltann, Pelle, Pysa, Skalken, fiender) med skarp vevd tøy-normalmap & rik kontrast (ingen blass vask!).
static func enhance_character_node(root: Node, add_shadow: bool = true, shadow_radius: float = 0.72) -> void:
	var fab := get_pbr_pack("fabric_detail")
	var fab_nrm: Texture2D = fab.get("normal", null)
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
			dup.roughness = clampf(maxf(dup.roughness, 0.50), 0.45, 0.78)
			dup.metallic = minf(dup.metallic, 0.25)
			if fab_nrm and not dup.normal_enabled:
				dup.normal_enabled = true
				dup.normal_texture = fab_nrm
				dup.normal_scale = 0.45
				dup.detail_enabled = false
			dup.rim_enabled = true
			dup.rim = 0.18
			dup.rim_tint = 0.55
			dup.subsurf_scatter_enabled = false
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

	# Stigende myke glødende gnister (alfablandede runde glør – null flate gule åttekantede sirkler!)
	var pts := GPUParticles3D.new()
	pts.position = Vector3(0.0, 1.0, 0.0)
	pts.amount = 24
	pts.lifetime = 1.5
	pts.preprocess = 1.0
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.25
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 22.0
	pmat.initial_velocity_min = 1.2
	pmat.initial_velocity_max = 2.5
	pmat.gravity = Vector3(0.22, 0.4, 0.0)
	pmat.scale_min = 0.45
	pmat.scale_max = 1.0
	pmat.color = Color(1.0, 0.68, 0.22)
	pts.process_material = pmat
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	var qmat := StandardMaterial3D.new()
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.albedo_texture = get_soft_glow_tex()
	qmat.albedo_color = Color(1.0, 0.72, 0.26, 0.95)
	qmat.emission_enabled = true
	qmat.emission = Color(1.0, 0.56, 0.14)
	qmat.emission_energy_multiplier = 2.2
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


static var _cached_glow_tex: Texture2D

## Myk radial glød-tekstur (eliminerer alle harde gule prikker/sirkler i luften!).
static func get_soft_glow_tex() -> Texture2D:
	if _cached_glow_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var dx := (float(x) / 63.0 - 0.5) * 2.0
				var dy := (float(y) / 63.0 - 0.5) * 2.0
				var d := sqrt(dx * dx + dy * dy)
				var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.8)
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_cached_glow_tex = ImageTexture.create_from_image(img)
	return _cached_glow_tex


## Atmosfæriske svevende lysstøv-partikler med myk radial glød (aldri harde gule sirkler!).
static func spawn_ambient_particles(parent: Node, center: Vector3, biome: String) -> GPUParticles3D:
	var pts := GPUParticles3D.new()
	pts.name = "AmbientAtmosphereParticles"
	pts.position = center + Vector3(0.0, 4.5, 0.0)
	pts.amount = 42 if biome == "graal_bosslevel" else 64
	pts.lifetime = 5.0
	pts.preprocess = 2.5
	pts.visibility_aabb = AABB(Vector3(-45, -20, -45), Vector3(90, 45, 90))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_radius = 18.0
	pmat.emission_ring_inner_radius = 7.0
	pmat.emission_ring_height = 8.0

	var col := Color(1.0, 0.90, 0.62, 0.72)
	var em_energy := 1.4
	if biome in ["cave_end", "cave_end_bosslevel"]:
		col = Color(0.24, 1.0, 0.66, 0.78)
		em_energy = 2.0
		pmat.direction = Vector3(0.0, 1.0, 0.0)
		pmat.initial_velocity_min = 0.25
		pmat.initial_velocity_max = 0.65
		pmat.gravity = Vector3(0.0, 0.14, 0.0)
	elif biome in ["graal_bosslevel", "graal_mountain", "magakhan_dungeon", "magakhan_endboss_level"]:
		col = Color(1.0, 0.56, 0.18, 0.85)
		em_energy = 2.2
		pmat.direction = Vector3(0.2, 1.0, 0.1)
		pmat.initial_velocity_min = 0.6
		pmat.initial_velocity_max = 1.4
		pmat.gravity = Vector3(0.18, 0.25, 0.0)
	else:
		pmat.direction = Vector3(0.2, 0.3, 0.0)
		pmat.initial_velocity_min = 0.15
		pmat.initial_velocity_max = 0.40
		pmat.gravity = Vector3(0.04, 0.04, 0.0)

	pmat.spread = 38.0
	pmat.scale_min = 0.45
	pmat.scale_max = 0.95
	pts.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.18)
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_texture = get_soft_glow_tex()
	smat.albedo_color = col
	smat.emission_enabled = true
	smat.emission = Color(col.r, col.g, col.b)
	smat.emission_energy_multiplier = em_energy
	qm.material = smat
	pts.draw_pass_1 = qm
	parent.add_child(pts)
	return pts


## Skummel gotisk bakgrunns-fjellkjede + 3D forgrenede lynnedslag rundt Gral-borgen!
static func spawn_graal_scary_backdrop(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "GraalScaryBackdrop"
	parent.add_child(root)

	# 0. Mørk tåkedal under borgen slik at ingen tom grå avgrunn noen gang synes!
	var valley := MeshInstance3D.new()
	var vm := PlaneMesh.new()
	vm.size = Vector2(440.0, 440.0)
	valley.mesh = vm
	valley.position = Vector3(0.0, -4.0, 0.0)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.018, 0.022, 0.052)
	vmat.roughness = 0.96
	valley.material_override = vmat
	root.add_child(valley)

	# 1. Ruvende taggete 360-graders gotiske fjelltopper som rammer inn horisonten under uværsskyene!
	var n_mtn := FastNoiseLite.new()
	n_mtn.seed = 666
	n_mtn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_mtn.frequency = 0.032
	n_mtn.fractal_octaves = 5

	var sample_mtn_h := func(fx: float, fz: float, rt: float) -> float:
		var envelope := sin(rt * PI)
		var ridge1 := pow(1.0 - absf(n_mtn.get_noise_2d(fx * 0.55, fz * 0.55)), 2.1)
		var ridge2 := pow(1.0 - absf(n_mtn.get_noise_2d(fx * 1.25 + 23.0, fz * 1.25 - 14.0)), 2.3)
		var crag := ridge1 * 32.0 + ridge2 * 16.0
		return -12.0 + envelope * (18.0 + crag)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 26
	var segs := 112
	var r_inner := 52.0
	var r_outer := 175.0

	var r_verts: Array = []
	var r_cols: Array = []
	var r_uvs: Array = []
	for ri in range(rings + 1):
		var rt := float(ri) / float(rings)
		var r_cur := lerpf(r_inner, r_outer, rt)
		var rv: Array[Vector3] = []
		var rc: Array[Color] = []
		var ru: Array[Vector2] = []
		for si in range(segs + 1):
			var ang := (float(si) / float(segs)) * TAU
			var fx := cos(ang) * r_cur
			var fz := sin(ang) * r_cur
			var h: float = float(sample_mtn_h.call(fx, fz, rt))

			# Dyp mørk gotisk obsidian/skifer-gradient med kjølig sølvblått månelys på eggene
			var col := Color(0.012, 0.015, 0.036)
			if h > 30.0:
				col = Color(0.058, 0.072, 0.145)
			elif h > 18.0:
				col = Color(0.030, 0.036, 0.080)
			elif h > 6.0:
				col = Color(0.018, 0.022, 0.052)
			rv.append(Vector3(fx, h, fz))
			rc.append(col)
			ru.append(Vector2(fx * 0.045, fz * 0.045))
		r_verts.append(rv)
		r_cols.append(rc)
		r_uvs.append(ru)

	# Riktig vikling slik at alle fjell-normaler peker OPP og UT mot spilleren!
	for ri in range(rings):
		for si in range(segs):
			var v00: Vector3 = r_verts[ri][si]
			var v10: Vector3 = r_verts[ri + 1][si]
			var v01: Vector3 = r_verts[ri][si + 1]
			var v11: Vector3 = r_verts[ri + 1][si + 1]
			var c00: Color = r_cols[ri][si]
			var c10: Color = r_cols[ri + 1][si]
			var c01: Color = r_cols[ri][si + 1]
			var c11: Color = r_cols[ri + 1][si + 1]
			var u00: Vector2 = r_uvs[ri][si]
			var u10: Vector2 = r_uvs[ri + 1][si]
			var u01: Vector2 = r_uvs[ri][si + 1]
			var u11: Vector2 = r_uvs[ri + 1][si + 1]
			for tri in [
				[v00, c00, u00], [v10, c10, u10], [v11, c11, u11],
				[v00, c00, u00], [v11, c11, u11], [v01, c01, u01],
			]:
				st.set_color(tri[1])
				st.set_uv(tri[2])
				st.add_vertex(tri[0])

	st.generate_normals()
	st.generate_tangents()
	var mtn := MeshInstance3D.new()
	mtn.mesh = st.commit()
	var mmat := StandardMaterial3D.new()
	mmat.vertex_color_use_as_albedo = true
	mmat.roughness = 0.88
	var rock_img := n_mtn.get_seamless_image(256, 256)
	rock_img.bump_map_to_normal_map(7.0)
	mmat.normal_enabled = true
	mmat.normal_texture = ImageTexture.create_from_image(rock_img)
	mmat.normal_scale = 1.4
	mmat.rim_enabled = true
	mmat.rim = 0.45
	mmat.rim_tint = 0.55
	mtn.material_override = mmat
	root.add_child(mtn)

	# 2. Gotiske ruin-vakttårn forankret DYPT nede i fjellryggene med smale glødende vindussprekker!
	var spire_mat := StandardMaterial3D.new()
	spire_mat.albedo_color = Color(0.022, 0.025, 0.052)
	spire_mat.roughness = 0.90
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(1.0, 0.44, 0.14)
	win_mat.emission_enabled = true
	win_mat.emission = Color(1.0, 0.34, 0.08)
	win_mat.emission_energy_multiplier = 2.8

	for sp in [
		[Vector2(82.0, -52.0), 1.15],
		[Vector2(98.0, -18.0), 1.35],
		[Vector2(86.0, 14.0), 1.10],
		[Vector2(28.0, -86.0), 1.25],
	]:
		var pxz: Vector2 = sp[0]
		var r_pt := pxz.length()
		var rt_pt := clampf((r_pt - r_inner) / (r_outer - r_inner), 0.05, 0.95)
		var base_y: float = float(sample_mtn_h.call(pxz.x, pxz.y, rt_pt))
		var snode := Node3D.new()
		snode.position = Vector3(pxz.x, base_y, pxz.y)
		snode.scale = Vector3.ONE * float(sp[1])
		root.add_child(snode)
		# Dypt forankret steintårn som går 16m ned i fjellet (svever ALDRI!)
		var twr := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 1.6
		tc.bottom_radius = 3.0
		tc.height = 30.0
		tc.radial_segments = 8
		twr.mesh = tc
		twr.position.y = -3.0
		twr.material_override = spire_mat
		snode.add_child(twr)
		# Krans / brystvern rundt tårntoppen
		var crown := MeshInstance3D.new()
		var cc := CylinderMesh.new()
		cc.top_radius = 2.15
		cc.bottom_radius = 1.95
		cc.height = 2.0
		cc.radial_segments = 8
		crown.mesh = cc
		crown.position.y = 12.2
		crown.material_override = spire_mat
		snode.add_child(crown)
		# Spisst gotisk spir
		var roof := MeshInstance3D.new()
		var rc2 := CylinderMesh.new()
		rc2.top_radius = 0.06
		rc2.bottom_radius = 2.05
		rc2.height = 9.0
		rc2.radial_segments = 8
		roof.mesh = rc2
		roof.position.y = 17.5
		roof.material_override = spire_mat
		snode.add_child(roof)
		# Smalt vertikalt gotisk spissvindu mot borgen (IKKE en ring rundt tårnet!)
		var w := MeshInstance3D.new()
		var wb := BoxMesh.new()
		wb.size = Vector3(3.4, 2.3, 0.55)
		w.mesh = wb
		w.position.y = 7.6
		w.material_override = win_mat
		snode.add_child(w)

	# 3. Alle 4 sylskarpe 3D forgrenede lynnedslag batchet i ÉN eneste GPU-mesh med HDR-bloom!
	var bolt_st := SurfaceTool.new()
	bolt_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_3d_lightning_bolt(bolt_st, Vector3(76.0, 96.0, -52.0), Vector3(70.0, 24.0, -48.0), 101, 0.24)
	_append_3d_lightning_bolt(bolt_st, Vector3(92.0, 102.0, -10.0), Vector3(84.0, 26.0, -16.0), 202, 0.22)
	_append_3d_lightning_bolt(bolt_st, Vector3(24.0, 94.0, -84.0), Vector3(18.0, 24.0, -78.0), 303, 0.22)
	_append_3d_lightning_bolt(bolt_st, Vector3(-28.0, 92.0, -80.0), Vector3(-22.0, 22.0, -72.0), 404, 0.20)
	bolt_st.generate_normals()

	var bolts_mi := MeshInstance3D.new()
	bolts_mi.name = "LightningBolts"
	bolts_mi.mesh = bolt_st.commit()
	bolts_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.92, 0.96, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.65, 0.82, 1.0)
	core_mat.emission_energy_multiplier = 7.5
	bolts_mi.material_override = core_mat
	root.add_child(bolts_mi)

	# Enkelt felles lynglød-lys som lyser opp de gotiske fjelltoppene bak Greven av Gral!
	var flash := OmniLight3D.new()
	flash.position = Vector3(68.0, 48.0, -34.0)
	flash.light_color = Color(0.55, 0.74, 1.0)
	flash.light_energy = 11.0
	flash.omni_range = 85.0
	flash.shadow_enabled = false
	root.add_child(flash)


static func _append_3d_lightning_bolt(st: SurfaceTool, start_p: Vector3, end_p: Vector3, seed_val: int, width: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var pts: Array[Vector3] = []
	var steps := 18
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var p := start_p.lerp(end_p, t)
		if i > 0 and i < steps:
			var jitter := sin(t * PI) * 4.4
			p.x += rng.randf_range(-jitter, jitter)
			p.z += rng.randf_range(-jitter, jitter)
		pts.append(p)

	_append_bolt_ribbon(st, pts, width)

	for b_idx in [4, 8, 12]:
		var b_start: Vector3 = pts[b_idx]
		var b_dir := Vector3(rng.randf_range(-1.0, 1.0), -1.25, rng.randf_range(-1.0, 1.0)).normalized()
		var b_pts: Array[Vector3] = [b_start]
		var cur := b_start
		for j in range(1, 6):
			cur += b_dir * rng.randf_range(3.0, 5.2) + Vector3(rng.randf_range(-1.8, 1.8), -0.6, rng.randf_range(-1.8, 1.8))
			b_pts.append(cur)
		_append_bolt_ribbon(st, b_pts, width * 0.50)


static func _append_bolt_ribbon(st: SurfaceTool, pts: Array[Vector3], width: float) -> void:
	var n_seg := pts.size() - 1
	for i in range(n_seg):
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var t0 := lerpf(1.0, 0.35, float(i) / float(max(n_seg, 1)))
		var t1 := lerpf(1.0, 0.35, float(i + 1) / float(max(n_seg, 1)))
		var side1 := dir.cross(Vector3.RIGHT)
		if side1.length_squared() < 0.01:
			side1 = dir.cross(Vector3.FORWARD)
		side1 = side1.normalized()
		var side2 := dir.cross(side1).normalized()
		for svec: Vector3 in [side1, side2]:
			var w0: Vector3 = svec * (width * t0)
			var w1: Vector3 = svec * (width * t1)
			# Begge sider (front + bak) slik at lynet synes fra alle vinkler med standard CULL_BACK!
			st.add_vertex(a - w0)
			st.add_vertex(a + w0)
			st.add_vertex(b + w1)
			st.add_vertex(a - w0)
			st.add_vertex(b + w1)
			st.add_vertex(b - w1)
			st.add_vertex(a - w0)
			st.add_vertex(b + w1)
			st.add_vertex(a + w0)
			st.add_vertex(a - w0)
			st.add_vertex(b - w1)
			st.add_vertex(b + w1)


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


## Dekorer hver øy på Verdenskartet med eksakt høyde-plassering (null nedsunkne hus!), klippesteiner, skjær, busker og landemerker!
static func decorate_world_map_island(root: Node3D, radius: float, theme: String, seed_val: int, is_active_story: bool, height_fn: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 1337

	# Kyst-kampesteiner + taggete skjær ute i lagunen på ALLE øyer for ekte skulpturert animasjons-terreng!
	var rock_col := Color(0.24, 0.22, 0.20)
	if theme == "castle":
		rock_col = Color(0.11, 0.10, 0.16)
	elif theme == "desert":
		rock_col = Color(0.56, 0.36, 0.18)
	elif theme == "jungle":
		rock_col = Color(0.18, 0.21, 0.16)
	for _r in range(18):
		var ang := rng.randf() * TAU
		var d := rng.randf_range(radius * 0.45, radius * 1.12)
		var rx := cos(ang) * d
		var rz := sin(ang) * d
		var ry: float = float(height_fn.call(rx, rz))
		if ry > -1.4:
			_add_coastal_rock(root, Vector3(rx, maxf(ry, -0.35), rz), rng.randf_range(0.75, 1.95), rock_col, theme == "castle")

	# Frodig buskas og gress-tuer på grønne øyer
	if theme in ["harbor", "jungle", "palm"]:
		for _b in range(14):
			var ang := rng.randf() * TAU
			var d := rng.randf_range(radius * 0.28, radius * 0.72)
			var bx := cos(ang) * d
			var bz := sin(ang) * d
			var by: float = float(height_fn.call(bx, bz))
			if by > 1.2:
				_add_mini_bush(root, Vector3(bx, by - 0.08, bz), rng.randf_range(0.65, 1.25), theme == "jungle")

	# Hovedlandemerker og bespokte detaljer plassert PÅ eksakt terrenghøyde!
	match theme:
		"harbor":
			# Abra Havn: Tre-brygge ut i vika + sjørøverlandsby på terrassene + fyrtårn!
			_add_mini_dock(root, Vector3(0.0, 0.35, radius * 0.76), 0.0)
			for h_xz in [Vector2(-4.2, 3.0), Vector2(3.6, 2.8), Vector2(-3.2, -2.6), Vector2(3.8, -2.2), Vector2(0.0, 4.4)]:
				var hy: float = float(height_fn.call(h_xz.x, h_xz.y))
				if hy > 0.6:
					_add_mini_house(root, Vector3(h_xz.x, hy - 0.15, h_xz.y), rng.randf_range(0.0, TAU), Color(0.42, 0.26, 0.15), Color(0.58, 0.15, 0.10))
			var ly: float = float(height_fn.call(0.0, -0.5))
			_add_lighthouse(root, Vector3(0.0, ly - 0.25, -0.5), Color(1.0, 0.86, 0.38))
			for _i in range(13):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.34, radius * 0.72)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.8:
					_add_mini_palm(root, Vector3(px, py - 0.1, pz), rng.randf_range(0.75, 1.15))
		"castle":
			# Gral: Mørk gotisk borg helt på den taggete fjelltoppen + svarte furutrær og skarpe klipper!
			var cy: float = float(height_fn.call(0.0, 0.0))
			_add_mini_castle(root, Vector3(0.0, cy - 0.7, 0.0))
			for _i in range(18):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.36, radius * 0.76)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.8:
					_add_mini_pine(root, Vector3(px, py - 0.15, pz), rng.randf_range(0.80, 1.35))
		"desert":
			# Fata Morgana: Sultanpalass med gullkupler + fargerike basar-telt + oase-palmer + brygge!
			var py0: float = float(height_fn.call(0.0, -0.8))
			_add_mini_arabian_palace(root, Vector3(0.0, py0 - 0.45, -0.8))
			_add_mini_dock(root, Vector3(0.0, 0.35, radius * 0.74), 0.0)
			for b_info in [[Vector2(-4.4, 3.2), Color(0.78, 0.14, 0.16)], [Vector2(4.2, 2.8), Color(0.12, 0.50, 0.62)], [Vector2(-1.4, 4.8), Color(0.84, 0.56, 0.12)], [Vector2(2.6, 5.2), Color(0.62, 0.18, 0.52)]]:
				var bxz: Vector2 = b_info[0]
				var by: float = float(height_fn.call(bxz.x, bxz.y))
				if by > 0.5:
					_add_mini_bazaar_tent(root, Vector3(bxz.x, by - 0.1, bxz.y), b_info[1])
			for _i in range(11):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.36, radius * 0.72)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.6:
					_add_mini_palm(root, Vector3(px, py - 0.1, pz), rng.randf_range(0.72, 1.15))
		"jungle":
			# Maga Khans øy: Tempelpyramide på toppen + tett dypgrønn regnskog + vulkanske klippesteiner!
			var ty: float = float(height_fn.call(0.0, 0.0))
			_add_mini_jungle_temple(root, Vector3(0.0, ty - 0.45, 0.0))
			for _i in range(24):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.28, radius * 0.75)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.7:
					_add_mini_palm(root, Vector3(px, py - 0.1, pz), rng.randf_range(0.78, 1.30))
		_:
			# Skattejakt-øya: Skattkiste på høyden + palmer + klipper!
			var ky: float = float(height_fn.call(0.0, 0.0))
			var chest := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(1.8, 1.2, 1.2)
			chest.mesh = b
			chest.position = Vector3(0.0, ky + 0.5, 0.0)
			var cmat := StandardMaterial3D.new()
			cmat.albedo_color = Color(0.95, 0.74, 0.18)
			cmat.metallic = 0.85
			cmat.roughness = 0.25
			cmat.emission_enabled = true
			cmat.emission = Color(1.0, 0.76, 0.18)
			cmat.emission_energy_multiplier = 1.6
			chest.material_override = cmat
			root.add_child(chest)
			for _i in range(10):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.30, radius * 0.68)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.6:
					_add_mini_palm(root, Vector3(px, py - 0.1, pz), rng.randf_range(0.78, 1.15))

	# Diskret varm gyllen markør over gjeldende historiemål
	if is_active_story:
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.25
		cyl.bottom_radius = 1.15
		cyl.height = 16.0
		beam.mesh = cyl
		beam.position = Vector3(0.0, 15.0, 0.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bmat := StandardMaterial3D.new()
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = Color(1.0, 0.86, 0.38, 0.16)
		beam.material_override = bmat
		root.add_child(beam)


static func _add_coastal_rock(parent: Node3D, pos: Vector3, s: float, col: Color, jagged: bool = false) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation_degrees = Vector3(randf_range(-14.0, 14.0), randf_range(0.0, 360.0), randf_range(-14.0, 14.0))
	parent.add_child(n)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.86

	# Fasettert klynge av 2 skarpe klippesteiner (ser ut som ekte skulpturert berg, ikke runde kuler!)
	for k in range(2):
		var r := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = (0.12 if jagged else 0.38) * s
		cm.bottom_radius = (0.95 if k == 0 else 0.68) * s
		cm.height = ((2.2 if jagged else 1.25) if k == 0 else 0.95) * s
		cm.radial_segments = 5
		r.mesh = cm
		r.position = Vector3(0.0 if k == 0 else 0.55 * s, cm.height * 0.32, 0.0 if k == 0 else 0.35 * s)
		r.rotation_degrees = Vector3(randf_range(-16.0, 16.0), float(k) * 73.0, randf_range(-16.0, 16.0))
		r.material_override = mat
		n.add_child(r)


static func _add_mini_bush(parent: Node3D, pos: Vector3, s: float, dark_jungle: bool = false) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	parent.add_child(n)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.06, 0.24, 0.08) if dark_jungle else Color(0.10, 0.32, 0.10)
	bmat.roughness = 0.84
	for off in [Vector3(0.0, 0.35, 0.0), Vector3(0.45, 0.25, 0.2), Vector3(-0.38, 0.28, -0.25)]:
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.52
		sp.height = 0.78
		sp.radial_segments = 7
		sp.rings = 4
		m.mesh = sp
		m.position = off
		m.material_override = bmat
		n.add_child(m)


static func _add_mini_dock(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.36, 0.21, 0.10)
	wmat.roughness = 0.84
	var plank := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 0.25, 5.4)
	plank.mesh = bm
	plank.position = Vector3(0.0, 0.25, 1.8)
	plank.material_override = wmat
	n.add_child(plank)
	for px in [-0.95, 0.95]:
		for pz in [0.2, 2.0, 3.8]:
			var post := MeshInstance3D.new()
			var pc := CylinderMesh.new()
			pc.top_radius = 0.16
			pc.bottom_radius = 0.18
			pc.height = 1.8
			post.mesh = pc
			post.position = Vector3(px, -0.25, pz)
			post.material_override = wmat
			n.add_child(post)


static func _add_mini_bazaar_tent(parent: Node3D, pos: Vector3, col: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = randf_range(0.0, TAU)
	parent.add_child(n)
	var t := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 1.45
	cm.height = 1.5
	cm.radial_segments = 4
	t.mesh = cm
	t.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.72
	t.material_override = mat
	n.add_child(t)


static func _add_mini_palm(parent: Node3D, pos: Vector3, s: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation_degrees = Vector3(randf_range(-12.0, 12.0), randf_range(0.0, 360.0), randf_range(-12.0, 12.0))
	parent.add_child(n)

	var trunk := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.13
	tc.bottom_radius = 0.26
	tc.height = 2.9
	trunk.mesh = tc
	trunk.position.y = 1.45
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.36, 0.22, 0.10)
	tmat.roughness = 0.88
	trunk.material_override = tmat
	n.add_child(trunk)

	# Rike dypgrønne smaragd- og olivenpalmeblader (ikke knall-lime leketøysgrønn!)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.07, 0.30, 0.09)
	lmat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	lmat.roughness = 0.74
	lmat.rim_enabled = true
	lmat.rim = 0.28

	var lmat_bright := StandardMaterial3D.new()
	lmat_bright.albedo_color = Color(0.14, 0.42, 0.12)
	lmat_bright.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	lmat_bright.roughness = 0.70
	lmat_bright.rim_enabled = true
	lmat_bright.rim = 0.32

	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.56
	cs.height = 0.65
	core.mesh = cs
	core.position.y = 2.95
	core.material_override = lmat
	n.add_child(core)

	for i in range(7):
		var ang := (float(i) / 7.0) * TAU + randf_range(-0.15, 0.15)
		var frond := MeshInstance3D.new()
		var fm := PrismMesh.new()
		fm.size = Vector3(0.58, 2.05, 0.14)
		frond.mesh = fm
		frond.position = Vector3(sin(ang) * 0.95, 2.82, cos(ang) * 0.95)
		frond.rotation = Vector3(1.24, ang, 0.0)
		frond.material_override = lmat if (i % 2 == 0) else lmat_bright
		n.add_child(frond)


static func _add_mini_pine(parent: Node3D, pos: Vector3, s: float) -> void:
	var n := Node3D.new()
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation_degrees = Vector3(randf_range(-6.0, 6.0), randf_range(0.0, 360.0), randf_range(-6.0, 6.0))
	parent.add_child(n)

	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.06, 0.15, 0.11)
	lmat.roughness = 0.86
	for tier in [[0.0, 1.1, 2.2, 1.25], [0.0, 2.1, 2.0, 0.96], [0.0, 3.0, 1.7, 0.68]]:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = float(tier[3])
		cm.height = float(tier[2])
		cm.radial_segments = 6
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
