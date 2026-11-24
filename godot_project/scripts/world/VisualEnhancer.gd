extends RefCounted
class_name VisualEnhancer
## 2026 Stilisert 3D-animasjonsfilm-rendering for KSGGFREMAKE:
## Kobler de nybygde CC0 PBR-teksturene (Albedo + Normal + ORM), stilisert biombelysning,
## stemningshimler etter originalspillets 2007-fargeskript, fakkelfat og kjølvann — uten fremmede asset-store-tillegg.

const WORLD_PBR_SHADER := preload("res://shaders/world_pbr_enhance.gdshader")
const STYLIZED_SKY_SHADER := preload("res://shaders/stylized_sky.gdshader")
const STORM_SKY_SHADER := preload("res://shaders/storm_sky.gdshader")
const STYLIZED_PANO_SKY_SHADER := preload("res://shaders/stylized_pano_sky.gdshader")

static var _cached_barrel_albedo: Texture2D
static var _cached_barrel_normal: Texture2D
static var _cached_shadow_tex: Texture2D
static var _cached_glow_tex: Texture2D
static var _cached_pbr_packs: Dictionary = {}
static var _cached_sky_panos: Dictionary = {}


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


static func get_sky_pano(sky_name: String) -> Texture2D:
	if _cached_sky_panos.has(sky_name):
		return _cached_sky_panos[sky_name]
	var p := "res://assets/skies/" + sky_name
	if ResourceLoader.exists(p):
		var t := load(p) as Texture2D
		_cached_sky_panos[sky_name] = t
		return t
	return null


## Oppgrader alle synlige nivåmaterialer til 2026 Ultra-HD 4K stilisert 3D-animasjonsfilm-PBR med bakte 4K/2K CC0-kart + 4K RNM triplanar detalj.
static func enhance_world_node(root: Node, biome: String = "abra", water_y: float = -999.0) -> void:
	var is_cursed_harbor := biome in ["abra", "menu"]
	var is_cave := biome in ["cave", "cave_end", "cave_end_bosslevel", "magakhan_dungeon", "magakhan_endboss_level"]
	var is_graal := biome in ["graal_bosslevel", "graal_mountain"]
	var is_desert := biome in ["fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel"]
	var is_world_map := biome == "world_map"

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
			var rname := sm.resource_name.to_lower()
			var mat_name := rname + " " + mname

			# Verdenskartets kystskum (wateredge01..13) og norske hav-kalligrafi-titler (textabra, textgraal osv.)
			if is_world_map and (mname.begins_with("wateredge") or mname.begins_with("text") or "xindicator" in mname):
				var wm := sm.duplicate() as StandardMaterial3D
				wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wm.cull_mode = BaseMaterial3D.CULL_DISABLED
				wm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				if mname.begins_with("wateredge"):
					wm.albedo_color = Color(0.88, 0.98, 1.0, 0.82)
				elif mname.begins_with("text"):
					var no_tex_path := "res://assets/ui/map_%s.png" % mname
					if ResourceLoader.exists(no_tex_path):
						wm.albedo_texture = load(no_tex_path) as Texture2D
					wm.albedo_color = Color(0.96, 0.99, 1.0, 0.94)
				mi.set_surface_override_material(si, wm)
				continue

			# Alfa-utskjæringer (rigg/tauverk/løvverk/seil/dragevinger): skarp og ren uten glødsøl!
			if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var dup := sm.duplicate() as StandardMaterial3D
				dup.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
				dup.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
				dup.roughness = clampf(maxf(dup.roughness, 0.50), 0.45, 0.88)
				if "phoenixdefuse2" in mat_name:
					dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					dup.alpha_scissor_threshold = 0.45
					dup.cull_mode = BaseMaterial3D.CULL_DISABLED
					dup.emission_enabled = false
				mi.set_surface_override_material(si, dup)
				continue

			# Fjerne bakgrunnsflater (unntatt ekte vegger): ren matt silhuett
			if "background" in mname and not ("backgroundwall" in mname):
				var bg := sm.duplicate() as StandardMaterial3D
				bg.roughness = 0.96
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

			var is_cutaway := ("blackwall" in mat_name or rname == "black" or rname.begins_with("black_"))
			var is_boss := ("phoenixdefuse" in mat_name or "graalboss" in mname)
			var is_iconic_painted := (
				"sign" in rname or "flag" in rname or "skull" in rname or "carpet" in rname
				or "window" in rname or "door" in rname or "hatch" in rname or "map" in rname
				or "shop" in rname or "boat" in rname or "wagon" in rname or "flame" in rname
				or "lava" in rname or "cake" in rname or "gong" in rname or is_boss
			)
			var pbr_blend := 0.0
			var tile_scale := 0.24
			var micro_det := 0.0
			var contrast_gamma := 1.02
			var rough := clampf(sm.roughness, 0.18, 0.94)
			var metal := clampf(sm.metallic, 0.0, 1.0)
			var sat := 1.05
			var rim_str := 0.04
			var rim_col := Color(0.88, 0.94, 1.0)
			var em_col := Color(0.0, 0.0, 0.0)
			var em_energy := 0.0
			var nrm_str := 1.12

			if is_cutaway:
				var cut_pack := get_pbr_pack("cutaway_bedrock_4k")
				if cut_pack.has("albedo") and cut_pack.has("normal") and cut_pack.has("rough"):
					sh.set_shader_parameter("has_pbr_pack", true)
					sh.set_shader_parameter("pbr_albedo_tex", cut_pack["albedo"])
					sh.set_shader_parameter("pbr_normal_tex", cut_pack["normal"])
					sh.set_shader_parameter("pbr_rough_tex", cut_pack["rough"])
					pbr_blend = 0.92
					tile_scale = 0.16
					rough = 0.86
					sat = 0.94
					rim_str = 0.0
					nrm_str = 1.15
					sh.set_shader_parameter("has_albedo_tex", false)
					sh.set_shader_parameter("albedo_tint", Color(0.18, 0.24, 0.30, 1.0))
			else:
				# Knivskarpt 4K verdensrom-triplanar RNM-relieff på alle stein-, fjell-, grotte-, mur-, gulv-, tre- og sandflater!
				var det_pack_name := ""
				if not is_iconic_painted:
					if biome in ["cave", "cave_end", "cave_end_bosslevel"] and ("rock" in mat_name or "cave" in mat_name or "wall" in mat_name or "ground" in mat_name or "floor" in mat_name or "portal" in mat_name or "dripstone" in mat_name or "stone" in mat_name or "cliff" in mat_name):
						det_pack_name = "rock_boulder_4k" if ("dripstone" in mat_name or "pillar" in mat_name or "rock" in rname) else "rock_cave_4k"
						micro_det = 0.64
						tile_scale = 0.36
						nrm_str = 1.38
					elif "cliff" in mat_name or "mountain" in mat_name or ("graal" in biome and ("rock" in mat_name or "wall" in mat_name or "tunnel" in mat_name)):
						det_pack_name = "rock_cliff_4k"
						micro_det = 0.56
						tile_scale = 0.30
						nrm_str = 1.32
					elif "castle" in mat_name or "brick" in mat_name or "battlement" in mat_name or "tower" in mat_name or "chimney" in mat_name or "foundation" in mat_name:
						det_pack_name = "stone_castle_4k"
						micro_det = 0.48
						tile_scale = 0.32
						nrm_str = 1.26
					elif "moss" in mat_name or "well" in mat_name or "dungeon" in biome and ("stone" in mat_name or "wall" in mat_name or "floor" in mat_name):
						det_pack_name = "stone_mossy_4k"
						micro_det = 0.52
						tile_scale = 0.32
						nrm_str = 1.28
					elif is_desert and ("floor" in mat_name or "marble" in mat_name or "palace" in biome and "ground" in mat_name):
						det_pack_name = "marble_4k"
						micro_det = 0.34
						tile_scale = 0.24
						nrm_str = 1.05
					elif is_desert and ("stone" in mat_name or "wall" in mat_name or "column" in mat_name or "pillar" in mat_name or "block" in mat_name or "sultan" in mat_name or "city" in mat_name):
						det_pack_name = "sandstone_4k"
						micro_det = 0.44
						tile_scale = 0.30
						nrm_str = 1.22
					elif "stone" in mat_name or "cobble" in mat_name or "tile" in mat_name or "graalground" in mat_name or "pavement" in mat_name or "bridge02" in mat_name or "alter" in mat_name or "altar" in mat_name:
						det_pack_name = "slate_floor_4k" if ("floor" in mat_name or "ground" in mat_name or "tile" in mat_name) else "stone_wall_4k"
						micro_det = 0.48
						tile_scale = 0.32
						nrm_str = 1.26
					elif is_world_map and ("island" in mname or "complete" in rname):
						det_pack_name = "rock_cliff_4k"
						micro_det = 0.36
						tile_scale = 0.07
						nrm_str = 1.18
					elif "sand" in mat_name or "beach" in mat_name or "dune" in mat_name:
						det_pack_name = "coast_sand_4k"
						micro_det = 0.48
						tile_scale = 0.32
						nrm_str = 1.15
					elif "grass" in mat_name or "jungleground" in mat_name or "meadow" in mat_name:
						det_pack_name = "grass_lush_4k"
						micro_det = 0.46
						tile_scale = 0.30
						nrm_str = 1.18
					elif "plank" in mat_name or "wood" in mat_name or "dock" in mat_name or "pier" in mat_name or "bridge01" in mat_name or "deck" in mat_name or "darklady" in rname:
						det_pack_name = "wood_dark_4k" if ("dark" in mat_name or "dungeon" in biome) else "wood_planks_4k"
						micro_det = 0.34
						tile_scale = 0.38
						nrm_str = 1.18

				if det_pack_name != "":
					var dpk := get_pbr_pack(det_pack_name)
					if dpk.has("albedo") and dpk.has("normal") and dpk.has("rough"):
						sh.set_shader_parameter("has_pbr_pack", true)
						sh.set_shader_parameter("pbr_albedo_tex", dpk["albedo"])
						sh.set_shader_parameter("pbr_normal_tex", dpk["normal"])
						sh.set_shader_parameter("pbr_rough_tex", dpk["rough"])
					else:
						sh.set_shader_parameter("has_pbr_pack", false)
						micro_det = 0.0
				else:
					sh.set_shader_parameter("has_pbr_pack", false)

				if is_cursed_harbor:
					contrast_gamma = 1.03
					sat = 1.04
					rim_str = 0.05
					rim_col = Color(0.82, 0.86, 0.56)
				elif is_cave:
					contrast_gamma = 1.03
					sat = 1.04
					rim_str = 0.04
					rim_col = Color(0.56, 0.72, 0.92)
				elif is_graal:
					contrast_gamma = 1.04
					sat = 1.05
					rim_str = 0.07
					rim_col = Color(0.45, 0.76, 0.92)
				elif is_desert:
					contrast_gamma = 1.01
					sat = 1.03
					rim_str = 0.04
					rim_col = Color(1.0, 0.88, 0.64)
				elif is_world_map:
					contrast_gamma = 1.02
					sat = 1.08
					rim_str = 0.05
					rim_col = Color(0.82, 0.94, 1.0)

			# Varmt vinduslys KUN på faktiske opplyste vindusglass (aldri på hele stein-/tre-sokler!)
			var is_lit_window := (
				("window" in rname or "vindu" in rname or "lampglass" in rname)
				and not ("wall" in rname or "stone" in rname or "wood" in rname or "frame" in rname or "door" in rname)
			)
			if is_lit_window and (is_cursed_harbor or is_graal or is_cave):
				em_col = Color(1.0, 0.76, 0.32)
				em_energy = 0.62 if is_cursed_harbor else 0.45
				rough = 0.28
			elif is_boss:
				if "greven" in mat_name:
					contrast_gamma = 1.02
					rough = 0.64
					rim_str = 0.10
				else:
					contrast_gamma = 1.02
					rough = 0.54
					sat = 1.06
					rim_str = 0.14
					rim_col = Color(1.0, 0.52, 0.18)

			sh.set_shader_parameter("base_roughness", rough)
			sh.set_shader_parameter("base_metallic", metal)
			sh.set_shader_parameter("normal_strength", nrm_str)
			sh.set_shader_parameter("pbr_blend", pbr_blend)
			sh.set_shader_parameter("pbr_tile_scale", tile_scale)
			sh.set_shader_parameter("micro_detail", micro_det)
			sh.set_shader_parameter("contrast_gamma", contrast_gamma)
			sh.set_shader_parameter("saturation_boost", sat)
			sh.set_shader_parameter("wet_water_y", water_y)
			sh.set_shader_parameter("rim_strength", rim_str)
			sh.set_shader_parameter("rim_color", rim_col)
			sh.set_shader_parameter("emission_color", em_col)
			sh.set_shader_parameter("emission_energy", em_energy)
			mi.set_surface_override_material(si, sh)


## Oppgrader karaktermodeller — bevarer bakte CC0 Normal- og ORM-kart for tydelig skille mellom hud, stoff, lær og metall!
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
			dup.vertex_color_use_as_albedo = false
			dup.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			dup.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			dup.roughness = clampf(dup.roughness, 0.36, 0.90)
			if fab_nrm and not dup.normal_enabled:
				dup.normal_enabled = true
				dup.normal_texture = fab_nrm
				dup.normal_scale = 0.28
			dup.rim_enabled = true
			dup.rim = 0.14
			dup.rim_tint = 0.35
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
				var a := clampf((1.0 - smoothstep_f(0.15, 0.98, d)) * 0.54, 0.0, 0.56)
				img.set_pixel(x, y, Color(0.02, 0.03, 0.05, a))
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


## Bygg 2026 Ultra-HD 4K stilisert animasjonshimmel tilpasset hvert områdes dokumenterte 2007-fargeskript
## (med malte 4K PureSky-skyer, måne/sol-glød og fjerne fjell-, klippe-, øy- og ørkensilhuetter!).
static func create_biome_sky(level_id: String, cfg: Dictionary) -> Sky:
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_512

	# Kartlegg alle utendørs biomer til sine 4K (4096x2048) stiliserte 360-graders himmelpanoramer
	var pano_file := ""
	var pano_exposure := 1.08
	var pano_rot := 0.0
	var pano_drift := 0.0018
	var storm_flash := 0.0
	var mist_str := 0.08
	var mist_col := Color(0.20, 0.30, 0.36)

	match level_id:
		"graal_bosslevel", "graal_mountain":
			pano_file = "sky_graal_storm_4k.png"
			pano_exposure = 1.24
			pano_rot = 0.85
			pano_drift = 0.0028
			storm_flash = 0.85
			mist_str = 0.14
			mist_col = Color(0.11, 0.22, 0.28)
		"abra":
			pano_file = "sky_abra_twilight_4k.png"
			pano_exposure = 1.12
			pano_rot = 0.35
			pano_drift = 0.0016
			mist_str = 0.12
			mist_col = Color(0.42, 0.42, 0.22)
		"menu":
			pano_file = "sky_abra_night_4k.png"
			pano_exposure = 1.10
			pano_rot = 0.20
			pano_drift = 0.0012
			mist_str = 0.10
			mist_col = Color(0.18, 0.20, 0.10)
		"fatamorgana_city", "fatamorgana_palace", "fatamorgana_bosslevel":
			pano_file = "sky_fatamorgana_4k.png"
			pano_exposure = 1.10 if level_id != "fatamorgana_bosslevel" else 0.96
			pano_rot = 1.10
			pano_drift = 0.0014
			mist_str = 0.10
			mist_col = Color(0.94, 0.78, 0.54)
		"world_map", "treasurehunt", "magakhan_beach":
			pano_file = "sky_tropical_4k.png"
			pano_exposure = 1.10
			pano_rot = 0.60
			pano_drift = 0.0018
			mist_str = 0.08
			mist_col = Color(0.74, 0.90, 0.95)
		"magakhan_jungle":
			pano_file = "sky_jungle_4k.png"
			pano_exposure = 1.12
			pano_rot = 0.45
			pano_drift = 0.0015
			mist_str = 0.12
			mist_col = Color(0.48, 0.70, 0.52)
		"magakhan_palace", "outro":
			pano_file = "sky_outro_sunset_4k.png"
			pano_exposure = 1.16
			pano_rot = 0.25 if level_id == "outro" else 1.40
			pano_drift = 0.0016
			mist_str = 0.10
			mist_col = Color(0.96, 0.68, 0.40)

	if pano_file != "":
		var pano_tex := get_sky_pano(pano_file)
		if pano_tex != null:
			var psm := ShaderMaterial.new()
			psm.shader = STYLIZED_PANO_SKY_SHADER
			psm.set_shader_parameter("sky_pano", pano_tex)
			psm.set_shader_parameter("exposure", pano_exposure)
			psm.set_shader_parameter("rotation_offset", pano_rot)
			psm.set_shader_parameter("cloud_drift_speed", pano_drift)
			psm.set_shader_parameter("storm_flash_strength", storm_flash)
			psm.set_shader_parameter("storm_flash_color", Color(0.55, 0.80, 1.0))
			psm.set_shader_parameter("horizon_mist_strength", mist_str)
			psm.set_shader_parameter("horizon_mist_color", mist_col)
			sky.sky_material = psm
			return sky

	if level_id in ["graal_bosslevel", "graal_mountain"]:
		var ssm := ShaderMaterial.new()
		ssm.shader = STORM_SKY_SHADER
		ssm.set_shader_parameter("zenith_color", Color(0.015, 0.045, 0.075))
		ssm.set_shader_parameter("horizon_color", Color(0.075, 0.165, 0.215))
		ssm.set_shader_parameter("cloud_dark", Color(0.025, 0.060, 0.085))
		ssm.set_shader_parameter("cloud_lit", Color(0.36, 0.58, 0.72))
		sky.sky_material = ssm
		return sky

	var mat := ShaderMaterial.new()
	mat.shader = STYLIZED_SKY_SHADER
	match level_id:
		"cave", "magakhan_dungeon", "magakhan_endboss_level":
			mat.set_shader_parameter("zenith_color", cfg.get("sky_top", Color(0.03, 0.04, 0.08)))
			mat.set_shader_parameter("mid_color", cfg.get("sky_horizon", Color(0.08, 0.08, 0.14)))
			mat.set_shader_parameter("horizon_color", cfg.get("fog_color", Color(0.06, 0.07, 0.12)))
			mat.set_shader_parameter("ground_color", Color(0.02, 0.02, 0.04))
			mat.set_shader_parameter("sun_color", cfg.get("sun_color", Color(1.0, 0.72, 0.42)))
			mat.set_shader_parameter("cloud_lit", Color(0.14, 0.14, 0.20))
			mat.set_shader_parameter("cloud_shadow", Color(0.03, 0.04, 0.07))
			mat.set_shader_parameter("cloud_coverage", 0.20)
			mat.set_shader_parameter("sun_size", 0.005)
		_:
			mat.set_shader_parameter("zenith_color", cfg.get("sky_top", Color(0.01, 0.14, 0.24)))
			mat.set_shader_parameter("mid_color", cfg.get("sky_horizon", Color(0.04, 0.28, 0.36)))
			mat.set_shader_parameter("horizon_color", cfg.get("fog_color", Color(0.03, 0.22, 0.30)))
			mat.set_shader_parameter("ground_color", Color(0.01, 0.06, 0.10))
			mat.set_shader_parameter("sun_color", cfg.get("sun_color", Color(0.45, 0.96, 0.84)))
			mat.set_shader_parameter("cloud_lit", cfg.get("sun_color", Color(0.40, 0.85, 0.76)))
			mat.set_shader_parameter("cloud_shadow", Color(0.03, 0.12, 0.16))
			mat.set_shader_parameter("cloud_coverage", 0.28)
			mat.set_shader_parameter("sun_size", 0.008)

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

	var pts := GPUParticles3D.new()
	pts.position = Vector3(0.0, 1.0, 0.0)
	pts.amount = 20
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

	var lgt := OmniLight3D.new()
	lgt.position = Vector3(0.0, 1.45, 0.0)
	lgt.light_color = Color(1.0, 0.58, 0.20)
	lgt.light_energy = 5.0
	lgt.omni_range = 16.0
	lgt.omni_attenuation = 1.4
	root.add_child(lgt)
	return root


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


static func spawn_ambient_particles(parent: Node, center: Vector3, biome: String) -> GPUParticles3D:
	var pts := GPUParticles3D.new()
	pts.name = "AmbientAtmosphereParticles"
	pts.position = center + Vector3(0.0, 4.5, 0.0)
	pts.amount = 36 if biome == "graal_bosslevel" else 48
	pts.lifetime = 5.0
	pts.preprocess = 2.5
	pts.visibility_aabb = AABB(Vector3(-45, -20, -45), Vector3(90, 45, 90))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pmat.emission_ring_radius = 18.0
	pmat.emission_ring_inner_radius = 7.0
	pmat.emission_ring_height = 8.0

	var col := Color(1.0, 0.90, 0.62, 0.55)
	var em_energy := 1.2
	if biome in ["cave_end", "cave_end_bosslevel"]:
		col = Color(0.24, 1.0, 0.66, 0.72)
		em_energy = 1.8
		pmat.direction = Vector3(0.0, 1.0, 0.0)
		pmat.initial_velocity_min = 0.25
		pmat.initial_velocity_max = 0.65
		pmat.gravity = Vector3(0.0, 0.14, 0.0)
	elif biome in ["graal_bosslevel", "graal_mountain", "magakhan_dungeon", "magakhan_endboss_level"]:
		col = Color(1.0, 0.56, 0.18, 0.78)
		em_energy = 2.0
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
	pmat.scale_min = 0.40
	pmat.scale_max = 0.85
	pts.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
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


## Stilisert stormhorisont + 3D lynnedslag for Gral-borgen (100% original-tro, null fremmede KayKit-borger/foto-klipper!).
static func spawn_graal_scary_backdrop(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "GraalStormBackdrop"
	parent.add_child(root)

	# Mørk tåkedal langt under borgen slik at ingen tom avgrunn synes
	var valley := MeshInstance3D.new()
	var vm := PlaneMesh.new()
	vm.size = Vector2(560.0, 560.0)
	valley.mesh = vm
	valley.position = Vector3(0.0, -14.0, 0.0)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.020, 0.048, 0.068)
	vmat.roughness = 0.96
	valley.material_override = vmat
	root.add_child(valley)

	# 3D forgrenede lynnedslag mot nattehimmelen (matcher originalens stormstemning!)
	var bolt_st := SurfaceTool.new()
	bolt_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_3d_lightning_bolt(bolt_st, Vector3(76.0, 96.0, -52.0), Vector3(70.0, 18.0, -48.0), 101, 0.22)
	_append_3d_lightning_bolt(bolt_st, Vector3(24.0, 94.0, -84.0), Vector3(18.0, 18.0, -78.0), 303, 0.20)
	bolt_st.generate_normals()

	var bolts_mi := MeshInstance3D.new()
	bolts_mi.name = "LightningBolts"
	bolts_mi.mesh = bolt_st.commit()
	bolts_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(0.88, 0.96, 1.0)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.54, 0.84, 1.0)
	core_mat.emission_energy_multiplier = 6.5
	bolts_mi.material_override = core_mat
	root.add_child(bolts_mi)


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
	wake.position = Vector3(0.0, 2.05, 3.4 * wake_scale)
	wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var smat := ShaderMaterial.new()
	smat.shader = load("res://shaders/ship_wake.gdshader")
	wake.material_override = smat
	ship_node.add_child(wake)


## Ingen uoriginale Asset Store-rekvisitter — hvert brett bevarer 100% originalspillets plasseringer og arkitektur.
static func decorate_world_map_island(_root: Node3D, _radius: float, _theme: String, _seed_val: int, _is_active_story: bool, _height_fn: Callable) -> void:
	pass


static func dress_level_with_asset_store(_world_root: Node3D, _level_id: String, _spawn_pos: Vector3, _water_y: float, _actors_by_name: Dictionary, _hm_cb: Callable) -> void:
	pass


## Stilisert CC0 treverk-tekstur for ødeleggbare tønner.
static func get_barrel_textures() -> Array:
	if _cached_barrel_albedo != null and _cached_barrel_normal != null:
		return [_cached_barrel_albedo, _cached_barrel_normal]
	var pk := get_pbr_pack("wood_planks")
	if pk.has("albedo") and pk.has("normal"):
		_cached_barrel_albedo = pk["albedo"]
		_cached_barrel_normal = pk["normal"]
		return [_cached_barrel_albedo, _cached_barrel_normal]
	var w := 64
	var h := 64
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
