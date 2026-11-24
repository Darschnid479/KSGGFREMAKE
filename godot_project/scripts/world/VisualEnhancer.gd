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
	for slot in [["albedo", "_albedo"], ["normal", "_normal"], ["rough", "_rough"]]:
		var k: String = slot[0]
		var suf: String = slot[1]
		if ResourceLoader.exists(base + suf + ".jpg"):
			d[k] = load(base + suf + ".jpg") as Texture2D
		elif ResourceLoader.exists(base + suf + ".png"):
			d[k] = load(base + suf + ".png") as Texture2D
	_cached_pbr_packs[pack_name] = d
	return d


static func _pick_pbr_pack_name(mat_name: String, biome: String) -> String:
	# 2.5D undervanns-grunnfjell på "blackwall" / "black"
	if "blackwall" in mat_name or mat_name.strip_edges().begins_with("black "):
		return "cutaway_bedrock"
	if "gold" in mat_name or "rail" in mat_name or "skull" in mat_name or "brass" in mat_name or "metal" in mat_name or "bell" in mat_name or "cannon" in mat_name or "iron" in mat_name or "chain" in mat_name:
		return "forged_metal"
	if "roof" in mat_name or "tile" in mat_name or "shingle" in mat_name:
		return "roof_shingles"
	if "chest" in mat_name or "leather" in mat_name or "rope" in mat_name:
		return "leather_detail"
	if "sail" in mat_name or "cloth" in mat_name or "fabric" in mat_name or "banner" in mat_name or "tent" in mat_name:
		return "fabric_detail"
	if "plank" in mat_name or "wood" in mat_name or "hull" in mat_name or "dock" in mat_name or "bridge" in mat_name or "pole" in mat_name or "door" in mat_name or "box" in mat_name or "crate" in mat_name or "catapult" in mat_name or "rowboat" in mat_name or "scaffold" in mat_name or "balcony" in mat_name or "housewall" in mat_name or "mainbuilding" in mat_name or "darklady" in mat_name or "mast" in mat_name:
		return "wood_planks"
	if biome in ["fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel"] and ("sultan" in mat_name or "wall" in mat_name or "plain" in mat_name or "ground" in mat_name or "entrance" in mat_name or "tower" in mat_name or "house" in mat_name):
		return "sandstone_wall"
	if "sand" in mat_name or "beach" in mat_name or "dune" in mat_name:
		return "coast_sand"
	if biome in ["cave", "cave_end", "cave_end_bosslevel", "graal_mountain"] and not ("brick" in mat_name or "castle" in mat_name or "well" in mat_name):
		return "rock_natural"
	if "rock" in mat_name or "cliff" in mat_name or "cave" in mat_name or "mountain" in mat_name or "moss" in mat_name or "tunnel" in mat_name:
		return "rock_natural"
	if "cobble" in mat_name or "plaza" in mat_name or "courtyard" in mat_name or "street" in mat_name or "road" in mat_name or "ground" in mat_name or "square" in mat_name:
		return "cobblestone"
	if "stone" in mat_name or "brick" in mat_name or "castle" in mat_name or "well" in mat_name or "foundation" in mat_name or "chimney" in mat_name or "pussle" in mat_name or "puussle" in mat_name or "under" in mat_name or "dungeon" in mat_name:
		return "stone_masonry"
	if biome in ["abra", "menu", "outro"]:
		return "wood_planks"
	return "rock_natural"


## Oppgrader alle materialer på en 3D-verden til ekte 2K Poly Haven PBR med skarpt normal-relieff og null blass 2004-strekk.
static func enhance_world_node(root: Node, biome: String = "abra", water_y: float = -999.0) -> void:
	var is_dark_biome := biome in [
		"cave", "cave_end", "cave_end_bosslevel",
		"graal_bosslevel", "graal_mountain",
		"magakhan_dungeon", "magakhan_endboss_level"
	]
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

			# Alfa-utskjæringer (rigg/tauverk/løvverk/dragevinger): skarp alpha-scissor uten oransje glødsøl!
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var dup := sm.duplicate() as StandardMaterial3D
				dup.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
				dup.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
				dup.roughness = clampf(maxf(dup.roughness, 0.52), 0.48, 0.88)
				if "phoenixdefuse2" in mat_name:
					dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					dup.alpha_scissor_threshold = 0.45
					dup.cull_mode = BaseMaterial3D.CULL_DISABLED
					dup.emission_enabled = false
				mi.set_surface_override_material(si, dup)
				continue

			if "background" in mname and not ("backgroundwall" in mname):
				var bg := sm.duplicate() as StandardMaterial3D
				bg.roughness = 0.95
				bg.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mi.set_surface_override_material(si, bg)
				continue

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

			var pbr_blend := 0.44
			var tile_scale := 0.56
			var contrast_gamma := 1.03
			var rough := clampf(maxf(sm.roughness, 0.54), 0.32, 0.92)
			var metal := sm.metallic
			var sat := 1.04
			var rim_str := 0.02
			var rim_col := Color(0.86, 0.94, 1.0)
			var em_col := Color(0.0, 0.0, 0.0)
			var em_energy := 0.0
			var nrm_str := 1.08

			if is_cutaway:
				pbr_blend = 0.94
				tile_scale = 0.30
				contrast_gamma = 1.02
				rough = 0.90
				sat = 0.88
				nrm_str = 1.25
				rim_str = 0.0
				sh.set_shader_parameter("has_albedo_tex", false)
				sh.set_shader_parameter("albedo_tint", Color(0.22, 0.27, 0.32, 1.0))
			elif pack_name == "wood_planks":
				pbr_blend = 0.44
				tile_scale = 0.58
				rough = 0.68
				nrm_str = 0.95
			elif pack_name == "rock_natural":
				pbr_blend = 0.56
				tile_scale = 0.45
				rough = 0.82
				nrm_str = 1.30
			elif pack_name == "stone_masonry":
				pbr_blend = 0.50
				tile_scale = 0.48
				rough = 0.76
				nrm_str = 1.18
			elif pack_name == "cobblestone":
				pbr_blend = 0.52
				tile_scale = 0.52
				rough = 0.72
				nrm_str = 1.22
			elif pack_name == "coast_sand":
				pbr_blend = 0.48
				tile_scale = 0.48
				rough = 0.84
				nrm_str = 0.92
			elif pack_name == "sandstone_wall":
				pbr_blend = 0.38
				tile_scale = 0.55
				rough = 0.82
				sat = 0.96
				nrm_str = 0.82
			elif pack_name == "roof_shingles":
				pbr_blend = 0.48
				tile_scale = 0.62
				rough = 0.66
				nrm_str = 1.12
			elif pack_name == "forged_metal":
				pbr_blend = 0.46
				tile_scale = 0.85
				metal = maxf(metal, 0.76)
				rough = 0.24
				nrm_str = 0.88
			elif pack_name == "leather_detail" or pack_name == "fabric_detail":
				pbr_blend = 0.42
				tile_scale = 0.95
				rough = 0.76
				nrm_str = 0.85

			if not is_cutaway:
				if biome in ["cave", "cave_end", "cave_end_bosslevel"]:
					contrast_gamma = 1.04
					sat = 1.02
					rim_str = 0.02
				elif biome in ["graal_bosslevel", "graal_mountain"]:
					contrast_gamma = 1.04
					sat = 1.02
					rim_str = 0.04
					rim_col = Color(0.55, 0.72, 1.0)
				elif biome in ["fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel"]:
					contrast_gamma = 1.02
					sat = 0.96

			if is_dark_biome and ("window" in mat_name or "lantern" in mat_name):
				em_col = Color(1.0, 0.68, 0.26)
				em_energy = 0.85
				rough = 0.34
				pbr_blend = 0.10
			elif "lantern" in mat_name:
				em_col = Color(1.0, 0.72, 0.30)
				em_energy = 0.45
				rough = 0.34
			elif is_boss:
				if "greven" in mat_name:
					contrast_gamma = 1.02
					rough = 0.68
					rim_str = 0.08
				else:
					contrast_gamma = 1.02
					rough = 0.56
					sat = 1.04
					em_col = Color(0.0, 0.0, 0.0)
					em_energy = 0.0
					rim_str = 0.12
					rim_col = Color(1.0, 0.52, 0.18)

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


## Oppgrader karaktermodeller med naturlig matt stoff/hud og ekte 2K fabric normal!
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
			dup.roughness = clampf(maxf(dup.roughness, 0.56), 0.52, 0.88)
			dup.metallic = minf(dup.metallic, 0.15)
			if fab_nrm and not dup.normal_enabled:
				dup.normal_enabled = true
				dup.normal_texture = fab_nrm
				dup.normal_scale = 0.30
				dup.detail_enabled = false
			dup.rim_enabled = true
			dup.rim = 0.08
			dup.rim_tint = 0.40
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


## Bygg konfigurert AAA HDRI-himmel (ekte Poly Haven 1K HDRIs med full IBL-refleksjon!) for hvert kapittel.
static func create_biome_sky(level_id: String, cfg: Dictionary) -> Sky:
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var is_swim := ("underwater" in level_id or level_id == "swimming")
	if not is_swim:
		var hdri_path := "res://assets/hdri/kloofendal_48d_partly_cloudy_puresky_1k.hdr"
		var hdri_energy := 0.86
		match level_id:
			"abra", "menu", "outro":
				hdri_path = "res://assets/hdri/small_harbor_01_1k.hdr"
				hdri_energy = 0.88
			"world_map", "treasurehunt":
				hdri_path = "res://assets/hdri/kloofendal_48d_partly_cloudy_puresky_1k.hdr"
				hdri_energy = 0.85
			"magakhan_beach", "magakhan_jungle", "magakhan_palace":
				hdri_path = "res://assets/hdri/spiaggia_di_mondello_1k.hdr"
				hdri_energy = 0.84
			"fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel":
				hdri_path = "res://assets/hdri/goegap_1k.hdr"
				hdri_energy = 0.78
			"graal_mountain", "graal_bosslevel":
				hdri_path = "res://assets/hdri/rogland_moonlit_night_1k.hdr"
				hdri_energy = 0.72
			"cave", "cave_end", "cave_end_bosslevel", "magakhan_dungeon", "magakhan_endboss_level":
				hdri_path = "res://assets/hdri/drachenfels_cellar_1k.hdr"
				hdri_energy = 0.34
		if ResourceLoader.exists(hdri_path):
			var pano_tex := load(hdri_path) as Texture2D
			if pano_tex:
				var pm := PanoramaSkyMaterial.new()
				pm.panorama = pano_tex
				pm.energy_multiplier = hdri_energy
				pm.filter = true
				sky.sky_material = pm
				return sky

	if level_id in ["graal_bosslevel", "graal_mountain"]:
		var ssm := ShaderMaterial.new()
		ssm.shader = STORM_SKY_SHADER
		sky.sky_material = ssm
		return sky

	var mat := ShaderMaterial.new()
	mat.shader = STYLIZED_SKY_SHADER
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

	# 0. Mørk tåkedal under borgen slik at ingen tom avgrunn synes
	var valley := MeshInstance3D.new()
	var vm := PlaneMesh.new()
	vm.size = Vector2(520.0, 520.0)
	valley.mesh = vm
	valley.position = Vector3(0.0, -6.0, 0.0)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.022, 0.028, 0.056)
	vmat.roughness = 0.94
	valley.material_override = vmat
	root.add_child(valley)

	# 1. Ekte 360-graders Poly Haven photogrammetry-fjell og klipper rundt Gral-borgen!
	var mtn_path := "res://assets/store/polyhaven/mountainside/mountainside_1k.gltf"
	var cliff_path := "res://assets/store/polyhaven/namaqualand_cliff_01/namaqualand_cliff_01_1k.gltf"
	var count_ring := 12
	for i in range(count_ring):
		var ang := (float(i) / float(count_ring)) * TAU
		var dist := 98.0 + (float(i % 2) * 16.0)
		var mx := cos(ang) * dist
		var mz := sin(ang) * dist
		var sc_v := Vector3(7.2, 6.4 + float(i % 3) * 1.1, 7.2)
		spawn_store_prop(root, mtn_path, Vector3(mx, -8.0, mz), ang + PI * 0.5, sc_v)

		var cang := ang + (TAU / float(count_ring)) * 0.45
		var cx := cos(cang) * 72.0
		var cz := sin(cang) * 72.0
		spawn_store_prop(root, cliff_path, Vector3(cx, -2.0, cz), cang + 0.4, Vector3(5.6, 6.2, 5.6))

	# 2. Gotiske Asset Store vakttårn og borger plassert på fjellryggene bak borggården
	for sp in [
		["res://assets/store/kaykit_medieval/buildings/blue/building_tower_A_blue.gltf", Vector3(68.0, 14.0, -56.0), 9.0, 0.5],
		["res://assets/store/kaykit_medieval/buildings/blue/building_castle_blue.gltf", Vector3(88.0, 12.0, -14.0), 8.5, -0.8],
		["res://assets/store/kaykit_medieval/buildings/blue/building_tower_B_blue.gltf", Vector3(32.0, 14.0, -82.0), 9.2, 1.2],
		["res://assets/store/kaykit_medieval/buildings/red/building_tower_catapult_red.gltf", Vector3(-42.0, 12.0, -76.0), 8.5, 0.2],
	]:
		var tnode := spawn_store_prop(root, str(sp[0]), sp[1], float(sp[3]), Vector3.ONE * float(sp[2]))
		if tnode:
			for tmi in _collect_meshes(tnode):
				if tmi.mesh:
					for tsi in range(tmi.mesh.get_surface_count()):
						var tm := tmi.get_active_material(tsi)
						if tm is StandardMaterial3D:
							var dtm := (tm as StandardMaterial3D).duplicate() as StandardMaterial3D
							var luma := dtm.albedo_color.get_luminance()
							dtm.albedo_color = dtm.albedo_color.lerp(Color(luma * 0.65, luma * 0.68, luma * 0.78), 0.72).darkened(0.45)
							dtm.roughness = clampf(maxf(dtm.roughness, 0.78), 0.75, 0.95)
							tmi.set_surface_override_material(tsi, dtm)
			var tl := OmniLight3D.new()
			tl.position = Vector3(0.0, 1.8, 0.0)
			tl.light_color = Color(1.0, 0.48, 0.16)
			tl.light_energy = 8.0
			tl.omni_range = 32.0
			tnode.add_child(tl)

	# 3. Sylskarpe 3D forgrenede lynnedslag batchet i ÉN GPU-mesh med HDR-bloom!
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


static var _cached_store_scenes: Dictionary = {}

static func get_store_scene(res_path: String) -> PackedScene:
	if _cached_store_scenes.has(res_path):
		return _cached_store_scenes[res_path]
	if not ResourceLoader.exists(res_path):
		return null
	var sc := load(res_path) as PackedScene
	if sc:
		_cached_store_scenes[res_path] = sc
	return sc


static func _strip_colliders(node: Node) -> void:
	for c in node.get_children():
		if c is StaticBody3D or c is CollisionObject3D or c is CollisionShape3D:
			c.queue_free()
		else:
			_strip_colliders(c)


static func spawn_store_prop(parent: Node, res_path: String, pos: Vector3, rot_y: float = 0.0, scale_vec: Vector3 = Vector3.ONE, ground_y: bool = false) -> Node3D:
	var sc := get_store_scene(res_path)
	if sc == null:
		return null
	var inst := sc.instantiate() as Node3D
	if inst == null:
		return null
	_strip_colliders(inst)
	inst.position = pos
	inst.rotation.y = rot_y
	inst.scale = scale_vec
	if ground_y:
		var min_y := 9999.0
		for mi in _collect_meshes(inst):
			var ab: AABB = mi.transform * mi.get_aabb()
			min_y = minf(min_y, ab.position.y)
		if min_y < 9000.0:
			inst.position.y -= min_y * scale_vec.y
	parent.add_child(inst)
	return inst


## Dekorer hver øy på Verdenskartet med ekte CC0 Asset Store-bygninger, festninger, brygger, palmer, klipper og skattkister!
static func decorate_world_map_island(root: Node3D, radius: float, theme: String, seed_val: int, is_active_story: bool, height_fn: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 1337

	# Ekte photogrammetry kystklipper og mosegrodde steiner langs kystlinjen (erstatter sylinder-kjegler!)
	var cliff_asset := "res://assets/store/polyhaven/namaqualand_cliff_01/namaqualand_cliff_01_1k.gltf" if theme in ["castle", "desert"] else "res://assets/store/polyhaven/rock_moss_set_01/rock_moss_set_01_1k.gltf"
	for _r in range(10):
		var ang := rng.randf() * TAU
		var d := rng.randf_range(radius * 0.58, radius * 0.98)
		var rx := cos(ang) * d
		var rz := sin(ang) * d
		var ry: float = float(height_fn.call(rx, rz))
		if ry > -1.0:
			var sc_f := rng.randf_range(0.65, 1.35) if theme in ["castle", "desert"] else rng.randf_range(0.85, 1.65)
			spawn_store_prop(root, cliff_asset, Vector3(rx, ry - 0.35, rz), rng.randf() * TAU, Vector3.ONE * sc_f)

	var rock_small := "res://assets/store/polyhaven/rock_07/rock_07_1k.gltf"
	for _rs in range(12):
		var ang2 := rng.randf() * TAU
		var d2 := rng.randf_range(radius * 0.52, radius * 1.05)
		var rx2 := cos(ang2) * d2
		var rz2 := sin(ang2) * d2
		var ry2: float = float(height_fn.call(rx2, rz2))
		if ry2 > -0.6:
			spawn_store_prop(root, rock_small, Vector3(rx2, ry2 - 0.08, rz2), rng.randf() * TAU, Vector3.ONE * rng.randf_range(3.5, 6.5))

	# Ekte frodige bregner & tropiske planter på grønne øyer
	var fern_path := "res://assets/store/polyhaven/fern_02/fern_02_1k.gltf"
	var palm_path := "res://assets/store/polyhaven/pachira_aquatica_01/pachira_aquatica_01_1k.gltf"
	var calathea_path := "res://assets/store/polyhaven/calathea_orbifolia_01/calathea_orbifolia_01_1k.gltf"
	var shrub_path := "res://assets/store/polyhaven/shrub_sorrel_01/shrub_sorrel_01_1k.gltf"
	if theme in ["harbor", "jungle", "palm"]:
		for _b in range(14):
			var ang := rng.randf() * TAU
			var d := rng.randf_range(radius * 0.30, radius * 0.80)
			var bx := cos(ang) * d
			var bz := sin(ang) * d
			var by: float = float(height_fn.call(bx, bz))
			if by > 0.7:
				var fp := fern_path if (_b % 2 == 0) else calathea_path
				spawn_store_prop(root, fp, Vector3(bx, by - 0.05, bz), rng.randf() * TAU, Vector3.ONE * rng.randf_range(2.2, 3.8))

	# Ekte Asset Store landemerker og bebyggelse for hver øy (null BoxMesh/PrismMesh-klosser!)
	var pier_path := "res://assets/store/polyhaven/modular_wooden_pier/modular_wooden_pier_1k.gltf"
	var barrel_path := "res://assets/store/polyhaven/wooden_barrels_01/wooden_barrels_01_1k.gltf"
	var crate_path := "res://assets/store/polyhaven/wooden_crate_01/wooden_crate_01_1k.gltf"
	match theme:
		"harbor":
			spawn_store_prop(root, pier_path, Vector3(0.0, -0.35, radius * 0.88), 0.0, Vector3.ONE * 1.45)
			spawn_store_prop(root, barrel_path, Vector3(-1.4, 0.8, radius * 0.82), 0.4, Vector3.ONE * 1.35)
			spawn_store_prop(root, crate_path, Vector3(1.5, 0.8, radius * 0.84), -0.3, Vector3.ONE * 1.45)
			for b_spec in [
				["res://assets/store/kaykit_medieval/buildings/blue/building_tavern_blue.gltf", Vector2(-3.2, 2.2), 3.6],
				["res://assets/store/kaykit_medieval/buildings/blue/building_market_blue.gltf", Vector2(3.6, 2.5), 3.4],
				["res://assets/store/kaykit_medieval/buildings/blue/building_home_A_blue.gltf", Vector2(-5.4, -2.0), 3.5],
				["res://assets/store/kaykit_medieval/buildings/blue/building_home_B_blue.gltf", Vector2(4.5, -2.5), 3.5],
				["res://assets/store/kaykit_medieval/buildings/blue/building_windmill_blue.gltf", Vector2(0.0, -0.8), 3.8],
			]:
				var xz: Vector2 = b_spec[1]
				var hy: float = float(height_fn.call(xz.x, xz.y))
				if hy > 0.5:
					spawn_store_prop(root, str(b_spec[0]), Vector3(xz.x, hy - 0.15, xz.y), rng.randf() * TAU, Vector3.ONE * float(b_spec[2]))
			for _i in range(16):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.36, radius * 0.78)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.7:
					var tp := palm_path if (_i % 3 != 2) else shrub_path
					var sc_t := rng.randf_range(1.9, 3.0) if tp == palm_path else rng.randf_range(2.6, 4.0)
					spawn_store_prop(root, tp, Vector3(px, py - 0.1, pz), rng.randf() * TAU, Vector3.ONE * sc_t)
		"castle":
			var cy: float = float(height_fn.call(0.0, 0.0))
			spawn_store_prop(root, "res://assets/store/polyhaven/modular_fort_01/modular_fort_01_1k.gltf", Vector3(0.0, cy - 0.65, 0.0), 0.4, Vector3.ONE * 0.78)
			spawn_store_prop(root, "res://assets/store/kaykit_medieval/buildings/red/building_castle_red.gltf", Vector3(-3.5, cy - 0.25, 2.5), 0.8, Vector3.ONE * 3.8)
			spawn_store_prop(root, "res://assets/store/kaykit_medieval/buildings/red/building_tower_catapult_red.gltf", Vector3(4.5, cy - 0.35, -2.0), -0.6, Vector3.ONE * 3.6)
			for _i in range(14):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.40, radius * 0.80)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.8:
					spawn_store_prop(root, shrub_path, Vector3(px, py - 0.15, pz), rng.randf() * TAU, Vector3.ONE * rng.randf_range(2.6, 4.0))
		"desert":
			spawn_store_prop(root, pier_path, Vector3(0.0, -0.35, radius * 0.86), 0.0, Vector3.ONE * 1.45)
			for b_spec in [
				["res://assets/store/kaykit_medieval/buildings/yellow/building_castle_yellow.gltf", Vector2(0.0, -1.2), 4.2],
				["res://assets/store/kaykit_medieval/buildings/yellow/building_market_yellow.gltf", Vector2(-4.5, 3.0), 3.6],
				["res://assets/store/kaykit_medieval/buildings/yellow/building_tower_B_yellow.gltf", Vector2(4.6, 2.4), 3.6],
				["res://assets/store/kaykit_medieval/buildings/yellow/building_home_A_yellow.gltf", Vector2(-3.8, -3.4), 3.4],
			]:
				var xz: Vector2 = b_spec[1]
				var py0: float = float(height_fn.call(xz.x, xz.y))
				if py0 > 0.5:
					spawn_store_prop(root, str(b_spec[0]), Vector3(xz.x, py0 - 0.2, xz.y), rng.randf() * TAU, Vector3.ONE * float(b_spec[2]))
			for _i in range(12):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.38, radius * 0.76)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.6:
					spawn_store_prop(root, palm_path, Vector3(px, py - 0.1, pz), rng.randf() * TAU, Vector3.ONE * rng.randf_range(1.8, 2.8))
		"jungle":
			var ty: float = float(height_fn.call(0.0, 0.0))
			spawn_store_prop(root, "res://assets/store/kaykit_medieval/buildings/red/building_castle_red.gltf", Vector3(0.0, ty - 0.45, 0.0), 0.2, Vector3.ONE * 4.2)
			for _i in range(22):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.28, radius * 0.78)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.7:
					var tp := palm_path if (_i % 2 == 0) else shrub_path
					spawn_store_prop(root, tp, Vector3(px, py - 0.1, pz), rng.randf() * TAU, Vector3.ONE * rng.randf_range(2.2, 3.5))
		_:
			var ky: float = float(height_fn.call(0.0, 0.0))
			var chest_n := spawn_store_prop(root, "res://assets/store/polyhaven/treasure_chest/treasure_chest_1k.gltf", Vector3(0.0, ky + 0.1, 0.0), 0.4, Vector3.ONE * 2.8)
			if chest_n:
				var gl := OmniLight3D.new()
				gl.position = Vector3(0.0, 1.4, 0.0)
				gl.light_color = Color(1.0, 0.82, 0.28)
				gl.light_energy = 3.2
				gl.omni_range = 14.0
				chest_n.add_child(gl)
			for _i in range(12):
				var ang := rng.randf() * TAU
				var d := rng.randf_range(radius * 0.30, radius * 0.72)
				var px := cos(ang) * d
				var pz := sin(ang) * d
				var py: float = float(height_fn.call(px, pz))
				if py > 0.6:
					spawn_store_prop(root, palm_path, Vector3(px, py - 0.1, pz), rng.randf() * TAU, Vector3.ONE * rng.randf_range(1.8, 2.7))

	# Diskret gyllent fyrlys over neste aktive historie-øy (ingen prangende gjennomsiktig kjegle!)
	if is_active_story:
		var beacon_l := OmniLight3D.new()
		beacon_l.position = Vector3(0.0, 16.0, 0.0)
		beacon_l.light_color = Color(1.0, 0.84, 0.36)
		beacon_l.light_energy = 4.5
		beacon_l.omni_range = 36.0
		root.add_child(beacon_l)


## Innreder alle 3D-nivåer med ekte høyoppløselige Asset Store-detaljer (tønner, kasser, skattkister, lykter, klipper, bregner, fakler)
## utplassert trygt langs vegger/kanter uten å blokkere spillerens sti eller triggere!
static func dress_level_with_asset_store(world_root: Node3D, level_id: String, spawn_pos: Vector3, water_y: float, actors_by_name: Dictionary, hm_cb: Callable) -> void:
	if level_id in ["world_map", "menu", "outro"] or "underwater" in level_id or "swimming" in level_id:
		return

	var avoid_pts: Array[Vector3] = [spawn_pos]
	for k in actors_by_name.keys():
		var act = actors_by_name[k]
		if act is Node3D and is_instance_valid(act):
			avoid_pts.append((act as Node3D).position)

	var can_place := func(p: Vector3, min_d: float) -> bool:
		for ap in avoid_pts:
			if Vector2(p.x - ap.x, p.z - ap.z).length() < min_d:
				return false
		return true

	var place_on_ground := func(res_path: String, x: float, z: float, rot_y: float, sc: float, add_fire: bool = false, clear_r: float = 3.2, max_y_delta: float = 999.0) -> void:
		var y := spawn_pos.y
		if hm_cb.is_valid():
			var hy: float = float(hm_cb.call(Vector3(x, 0.0, z)))
			if hy > -5000.0:
				y = hy
		if max_y_delta < 900.0 and absf(y - spawn_pos.y) > max_y_delta:
			return
		var p := Vector3(x, y, z)
		if not can_place.call(p, clear_r):
			return
		var n := spawn_store_prop(world_root, res_path, p, rot_y, Vector3.ONE * sc, true)
		if n and ("rock_" in res_path or "boulder_" in res_path):
			n.position.y -= 0.14 * sc
		if n and add_fire:
			var l := OmniLight3D.new()
			l.position = Vector3(0.0, 0.7 / maxf(sc, 0.2), 0.0)
			l.light_color = Color(1.0, 0.68, 0.26)
			l.light_energy = 2.4
			l.omni_range = 11.0
			n.add_child(l)

	var p_rock07 := "res://assets/store/polyhaven/rock_07/rock_07_1k.gltf"
	var p_boulder := "res://assets/store/polyhaven/boulder_01/boulder_01_1k.gltf"
	var p_fern := "res://assets/store/polyhaven/fern_02/fern_02_1k.gltf"
	var p_palm := "res://assets/store/polyhaven/pachira_aquatica_01/pachira_aquatica_01_1k.gltf"
	var p_barrels := "res://assets/store/polyhaven/wooden_barrels_01/wooden_barrels_01_1k.gltf"
	var p_wine := "res://assets/store/polyhaven/wine_barrel_01/wine_barrel_01_1k.gltf"
	var p_crate1 := "res://assets/store/polyhaven/wooden_crate_01/wooden_crate_01_1k.gltf"
	var p_crate2 := "res://assets/store/polyhaven/wooden_crate_02/wooden_crate_02_1k.gltf"
	var p_lantern := "res://assets/store/polyhaven/wooden_lantern_01/wooden_lantern_01_1k.gltf"
	var p_chest := "res://assets/store/polyhaven/treasure_chest/treasure_chest_1k.gltf"
	var p_cannon := "res://assets/store/polyhaven/cannon_01/cannon_01_1k.gltf"
	var p_bucket := "res://assets/store/polyhaven/wooden_bucket_01/wooden_bucket_01_1k.gltf"
	var p_candles := "res://assets/store/kaykit_dungeon/candle_triple.gltf.glb"
	var p_diya := "res://assets/store/polyhaven/brass_diya_lantern/brass_diya_lantern_1k.gltf"

	match level_id:
		"cave", "cave_end", "cave_end_bosslevel":
			# Jordnære Poly Haven steiner, bregner, smuglertønner, skattkiste og trelykter trygt langs hulegulvets kanter
			place_on_ground.call(p_rock07, -44.6, 53.6, 0.5, 1.85, false, 2.6, 0.55)
			place_on_ground.call(p_rock07, -35.8, 52.8, -1.2, 1.75, false, 2.6, 0.55)
			place_on_ground.call(p_boulder, -36.0, 49.8, 0.9, 0.85, false, 2.6, 0.55)
			place_on_ground.call(p_fern, -44.9, 55.4, 0.4, 1.45, false, 2.4, 0.55)
			place_on_ground.call(p_fern, -35.9, 56.2, -0.7, 1.35, false, 2.4, 0.55)
			place_on_ground.call(p_barrels, -45.4, 59.8, 0.3, 1.12, false, 2.6, 0.65)
			place_on_ground.call(p_crate1, -44.1, 60.4, 0.9, 1.25, false, 2.6, 0.65)
			place_on_ground.call(p_lantern, -43.9, 59.5, 0.0, 1.25, true, 2.4, 0.65)
			place_on_ground.call(p_lantern, -42.5, 51.8, 0.3, 1.35, true, 2.4, 0.55)
			place_on_ground.call(p_diya, -37.2, 52.0, 0.0, 1.85, true, 2.4, 0.55)
			place_on_ground.call(p_chest, -34.8, 60.8, -2.4, 1.05, false, 2.6, 0.65)
		"abra":
			# Stort oppankret handelsskip i bukten + dekkskanon, tønner og bregner i Abra Havn
			var bay_ship := spawn_store_prop(world_root, "res://assets/store/polyhaven/dutch_ship_medium/dutch_ship_medium_1k.gltf", Vector3(36.0, maxf(water_y, -0.2) - 0.6, -24.0), -0.85, Vector3.ONE * 0.56)
			if bay_ship:
				attach_ship_wake(bay_ship, 1.2)
			place_on_ground.call(p_barrels, -9.8, 22.8, 0.5, 1.10, false, 2.4)
			place_on_ground.call(p_crate2, -5.2, 23.2, -0.4, 1.15, false, 2.4)
			place_on_ground.call(p_bucket, -6.5, 22.6, 0.0, 1.20, false, 2.2)
			place_on_ground.call(p_lantern, -10.2, 18.8, 0.0, 1.25, true, 2.4)
			place_on_ground.call(p_cannon, -11.5, 17.5, -1.6, 0.95, false, 2.6)
			place_on_ground.call(p_palm, -24.5, -8.5, 0.7, 1.85, false, 3.0)
			place_on_ground.call(p_fern, -16.0, -2.5, 0.2, 1.45, false, 2.6)
		"fatamorgana_city":
			# Ørkenskjær, palmer, messinglanterner og markedskasser langs brygge & basarmurer
			place_on_ground.call(p_boulder, -26.8, 23.2, 1.4, 1.45, false, 2.8)
			place_on_ground.call(p_boulder, -36.5, 22.4, -0.9, 1.30, false, 2.8)
			place_on_ground.call(p_wine, -35.2, 25.8, 0.2, 1.10, false, 2.4)
			place_on_ground.call(p_crate1, -28.8, 26.8, 0.6, 1.20, false, 2.4)
			place_on_ground.call(p_diya, -34.2, 23.6, 0.0, 1.65, true, 2.2)
			place_on_ground.call(p_palm, -41.5, 14.5, 0.4, 1.75, false, 3.0)
			place_on_ground.call(p_palm, -24.0, 12.0, 1.8, 1.80, false, 3.0)
			place_on_ground.call(p_fern, -43.0, 19.5, 0.0, 1.35, false, 2.4)
		"graal_bosslevel":
			# Borggård-lykter og steinsprut langs ytterkanten av brystvernet (midtstien er helt fri!)
			for gp in [Vector2(-4.4, 6.25), Vector2(1.2, 6.25), Vector2(4.2, 6.25)]:
				place_on_ground.call(p_lantern, float(gp.x), float(gp.y), 0.1, 1.15, true, 1.8, 0.6)
			for dp in [Vector2(-8.1, 6.8), Vector2(6.6, 5.4), Vector2(-6.2, -9.8)]:
				place_on_ground.call(p_diya, float(dp.x), float(dp.y), 0.4, 1.55, true, 1.8, 0.8)
			place_on_ground.call(p_rock07, 5.4, 6.25, 0.7, 0.90, false, 1.8, 0.6)
			place_on_ground.call(p_candles, -8.3, 8.2, 0.3, 1.10, false, 1.6, 0.6)
		_:
			# Generisk dekor langs nivåperiferien for øvrige scener
			var rng := RandomNumberGenerator.new()
			rng.seed = level_id.hash()
			for i in range(6):
				var ang := (float(i) / 6.0) * TAU + rng.randf_range(-0.2, 0.2)
				var dist := rng.randf_range(7.5, 16.0)
				var px := spawn_pos.x + cos(ang) * dist
				var pz := spawn_pos.z + sin(ang) * dist
				var prop := p_lantern if ("dungeon" in level_id or "palace" in level_id) else (p_fern if ("jungle" in level_id or "beach" in level_id) else p_barrels)
				place_on_ground.call(prop, px, pz, rng.randf() * TAU, 1.2, false, 3.2)


## Prosedyrell treverk-tekstur fallback for ødeleggbare tønner.
static func get_barrel_textures() -> Array:
	if _cached_barrel_albedo != null and _cached_barrel_normal != null:
		return [_cached_barrel_albedo, _cached_barrel_normal]
	var pk := get_pbr_pack("wood_planks")
	if pk.has("albedo") and pk.has("normal"):
		_cached_barrel_albedo = pk["albedo"]
		_cached_barrel_normal = pk["normal"]
		return [_cached_barrel_albedo, _cached_barrel_normal]
	var w := 128
	var h := 128
	var alb_img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var nrm_img := Image.create(w, h, false, Image.FORMAT_RGB8)
	alb_img.fill(Color(0.36, 0.22, 0.12))
	nrm_img.fill(Color(0.5, 0.5, 1.0))
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
