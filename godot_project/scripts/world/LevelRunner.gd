extends Node3D
class_name LevelRunner
## Laster hvert nivå i 100% original rekkefølge med moderne AAA animasjonsspill-grafikk (Godot 4 Forward+,
## AgX, SSAO, SSIL, volumetrisk tåke, triplanar PBR-mikrodetalj, turkis skumhav og animerte historie-sekvenser).

const PINKY_SCRIPT := preload("res://scripts/player/PinkyController.gd")
const BOAT_SCRIPT := preload("res://scripts/player/BoatController.gd")
const SWIMMER_SCRIPT := preload("res://scripts/player/SwimmingController.gd")
const CAMERA_SCRIPT := preload("res://scripts/player/FollowCamera.gd")
const NPC_SCRIPT := preload("res://scripts/world/NpcActor.gd")
const ENEMY_SCRIPT := preload("res://scripts/world/EnemyActor.gd")
const PORTAL_SCRIPT := preload("res://scripts/world/PortalTrigger.gd")
const COIN_SCRIPT := preload("res://scripts/world/CollectibleCoin.gd")
const BARREL_SCRIPT := preload("res://scripts/world/BreakableBarrel.gd")
const HAZARD_SCRIPT := preload("res://scripts/world/UnderwaterHazard.gd")
const CUTSCENE_SCRIPT := preload("res://scripts/ui/CutscenePlayer.gd")
const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")
const ISLAND_TERRAIN_SHADER := preload("res://shaders/island_terrain.gdshader")

const WORLD_SCALE := 0.1 # Samme 0.1-skala som OBJ->GLB-konvertereren (Shockwave-enheter -> meter)

var current_level_id: String = "cave"
var _world_root: Node3D
var _env_node: WorldEnvironment
var _sun_node: DirectionalLight3D
var _camera_rig: FollowCamera
var _player_node: CharacterBody3D

# Karakter-katalog: kobler originale scriptingdata-navn til norske navn, modeller og rolle
const CHARACTER_ROLES := {
	"sabeltann": {"name": "Kaptein Sabeltann", "model": "sabeltann", "role": "npc", "coins": 15},
	"langemann": {"name": "Langemann", "model": "langemann", "role": "npc", "coins": 10},
	"sunniva": {"name": "Sunniva", "model": "sunniva", "role": "npc", "coins": 10},
	"pelle": {"name": "Pelle", "model": "pelle", "role": "npc", "coins": 5},
	"pysa": {"name": "Pysa", "model": "pelle", "role": "npc", "coins": 5},
	"skalken": {"name": "Skalken", "model": "skalken", "role": "npc", "coins": 5},
	"miriam": {"name": "Miriam av Gral", "model": "miriam", "role": "npc", "coins": 15},
	"benjamin": {"name": "Benjamin", "model": "benjamin", "role": "npc", "coins": 5},
	"sultan": {"name": "Sultanen", "model": "sultan", "role": "npc", "coins": 20},
	"shopkeeper": {"name": "Kjøpmannen", "model": "shopkeeper", "role": "npc", "coins": 0},
	"sirikit": {"name": "Sirikit", "model": "sirikit", "role": "npc", "coins": 10},
	"malena": {"name": "Malena", "model": "malena", "role": "npc", "coins": 10},
	"daughter": {"name": "Høvdingens datter", "model": "chiefs_daughter", "role": "npc", "coins": 10},
	"skeleton": {"name": "Skjelettvakt", "model": "skeleton", "role": "enemy", "hp": 55.0, "dmg": 10.0},
	"guard": {"name": "Palassvakt", "model": "arab_guard1", "role": "enemy", "hp": 70.0, "dmg": 14.0},
	"henchman": {"name": "Maga Khans kriger", "model": "mk_henchman1", "role": "enemy", "hp": 75.0, "dmg": 15.0},
	"tribesman": {"name": "Jungelkriger", "model": "tribesman", "role": "enemy", "hp": 65.0, "dmg": 13.0},
	"panther": {"name": "Svart panter", "model": "panther", "role": "enemy", "hp": 80.0, "dmg": 18.0},
	"meatplant": {"name": "Kjøttetende plante", "model": "meatplant", "role": "enemy", "hp": 90.0, "dmg": 16.0},
	"opponent": {"name": "Fiendtlig pirat", "model": "opponent1", "role": "enemy", "hp": 65.0, "dmg": 12.0},
	"ghost": {"name": "Grusomme Gabriels spøkelse", "model": "ghost", "role": "boss", "hp": 260.0, "dmg": 20.0},
	"maga_khan": {"name": "Maga Khan", "model": "maga_khan", "role": "boss", "hp": 220.0, "dmg": 18.0},
	"dragon": {"name": "Maga Khans drage", "model": "maga_khan", "role": "boss", "hp": 320.0, "dmg": 24.0},
}


func _ready() -> void:
	GameState.level_change_requested.connect(load_level)
	load_level(GameState.current_level_id)


func load_level(level_id: String) -> void:
	current_level_id = level_id
	GameState.current_level_id = level_id

	if is_instance_valid(_world_root):
		_world_root.queue_free()
		await get_tree().process_frame

	_world_root = Node3D.new()
	_world_root.name = "WorldRoot_" + level_id
	add_child(_world_root)

	var cfg := LevelCatalog.get_level(level_id)
	GameState.set_objective(str(cfg.get("objective", "")))
	AudioManager.play_music(str(cfg.get("music", "abra")))

	# 1. Moderne AAA animasjonsspill-miljø (AgX, SSAO, SSIL, volumetrisk tåke, malt himmel)
	_setup_modern_environment(cfg)

	var mode := str(cfg.get("mode", "adventure"))
	var level_bounds := AABB(Vector3(-250, -5, -250), Vector3(500, 40, 500))
	var water_y := float(cfg.get("water_y", -0.2)) if bool(cfg.get("has_water", false)) else -999.0

	if mode == "boat":
		# 1:1 Verdenskart: dybdebunn + turkis skumhav + 3D-dekorerte øyer og skip sett ovenfra
		_spawn_world_map_seabed()
		_build_world_map_islands()
		_spawn_modern_ocean(0.0, level_bounds, true)
	elif mode == "swimming":
		# 1:1 2D side-scrolling undervanns-svømmenivå (graal_underwater, fatamorgana_underwater, magakhan_dungeon_underwater, world_map_underwater!)
		level_bounds = _load_underwater_world(str(cfg.get("w3d", level_id)))
	else:
		# 2. Last original HD .glb nivå-geometri med automatisk kollisjon og AAA PBR-oppgradering
		level_bounds = _load_level_geometry(str(cfg.get("w3d", level_id)), water_y)
		await get_tree().physics_frame
		# 3. Moderne Sea-of-Thieves turkis hav med ekte kystskum og kaustikk
		if bool(cfg.get("has_water", false)):
			_spawn_modern_ocean(water_y, level_bounds, false)

	# 4. Les originale gameplay-data (spawns, NPC-er, fiender, portaler, 2D-svømmehindre)
	var gp_data := _read_gameplay_json(level_id)
	if gp_data.is_empty() and level_id == "world_map_underwater":
		gp_data = _read_gameplay_json("world_map_underwater1")

	# 5. Opprett kamera-rigg
	_camera_rig = _create_camera_rig()
	_world_root.add_child(_camera_rig)

	# 6. Spawn spiller (Pinky i 3D, Pinky i 2D-svømming, eller Den Sorte Dame på verdenskartet)
	if mode == "boat":
		_player_node = _spawn_boat(Vector3(0.0, 0.0, 8.0))
		_camera_rig.set_target(_player_node, 74.0, 2.0, true, false)
	elif mode == "swimming":
		_build_underwater_spline_walls(gp_data)
		var swim_pos := _find_swimmer_spawn(level_id, gp_data)
		_player_node = _spawn_swimmer(swim_pos)
		var cam_dist := 14.5 if "world_map" in level_id else 11.8
		_camera_rig.set_target(_player_node, cam_dist, 0.35, false, true)
		_populate_underwater_entities(level_id, cfg, gp_data)
	else:
		var spawn_pos := _find_player_spawn(level_id, gp_data, level_bounds)
		_player_node = _spawn_pinky(spawn_pos, false)
		if level_id == "graal_bosslevel":
			_camera_rig.set_target(_player_node, 3.8, 1.75, false)
			_camera_rig.yaw = -1.52
			_camera_rig.pitch = -0.07
			if _camera_rig.spring_arm:
				_camera_rig.spring_arm.collision_mask = 0
				_camera_rig.spring_arm.spring_length = 3.8
			_camera_rig.rotation = Vector3(_camera_rig.pitch, _camera_rig.yaw, 0.0)
		else:
			_camera_rig.set_target(_player_node, 9.5, 2.4, false)
		if _camera_rig.spring_arm and _player_node:
			_camera_rig.spring_arm.add_excluded_object(_player_node.get_rid())
		# 7. Spawn NPC-er, fiender, håndlagde tønner, dubloner, fakkelfat og portaler
		_populate_entities(level_id, cfg, gp_data, spawn_pos, level_bounds)
		_add_biome_atmosphere(level_id, spawn_pos)

	# 8. Spill av oppskalert animert historie-filmsekvens (videofrekvens) ved hvert nytt hovedkapittel!
	var pending_cut := GameState.get_pending_cutscene(level_id)
	if pending_cut != "":
		GameState.mark_cutscene_seen(pending_cut)
		var player: CutscenePlayer = CUTSCENE_SCRIPT.new()
		add_child(player)
		player.play_cutscene(pending_cut)
		if level_id == "outro":
			player.cutscene_finished.connect(func(_cid: String):
				GameState.complete_level_story("outro")
				GameState.request_level("abra")
			)


func _setup_modern_environment(cfg: Dictionary) -> void:
	_env_node = WorldEnvironment.new()
	var env := Environment.new()
	var is_cave := current_level_id in ["cave", "cave_end", "cave_end_bosslevel", "magakhan_dungeon"]
	var is_graal := current_level_id in ["graal_bosslevel", "graal_mountain"]
	var is_swim := str(cfg.get("mode", "")) == "swimming"

	env.background_mode = Environment.BG_SKY
	env.sky = VisualEnhancer.create_biome_sky(current_level_id, cfg)

	if is_cave or is_swim:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = cfg.get("ambient_color", Color(0.10, 0.36, 0.48))
		env.ambient_light_energy = float(cfg.get("ambient_energy", 0.80 if is_swim else 0.55))
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.78
		env.ambient_light_color = cfg.get("ambient_color", Color(0.36, 0.56, 0.86))
		env.ambient_light_energy = float(cfg.get("ambient_energy", 0.68))

	# Moderne AAA animasjons-pipeline: AgX tonemapping + SSAO + SSIL indirekte lys + Glow + Volumetrisk tåke!
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.12 if is_swim else (1.10 if not is_cave else 1.05)
	env.ssao_enabled = GameState.ssao_enabled
	env.ssao_radius = 1.65
	env.ssao_intensity = 1.70
	env.ssao_power = 1.45
	env.ssao_detail = 0.65

	# Sanntids indirekte bounce-lys (varme vegger i Fata Morgana, smaragdglød i grotten, havrefleks på skuta!)
	env.ssil_enabled = GameState.ssil_enabled
	env.ssil_radius = 4.5
	env.ssil_intensity = 1.05

	env.glow_enabled = GameState.glow_enabled
	env.glow_normalized = true
	env.glow_intensity = 0.45 if is_swim else 0.42
	env.glow_bloom = 0.18 if is_swim else 0.16
	env.glow_hdr_threshold = 1.15

	env.fog_enabled = GameState.fog_enabled
	env.fog_light_color = cfg.get("fog_color", Color(0.62, 0.78, 0.94))
	env.fog_density = float(cfg.get("fog_density", 0.0011))
	env.fog_sky_affect = 0.08 if is_graal else (0.35 if is_swim else (0.28 if is_cave else 0.14))

	# Volumetrisk tåke for magisk dybde og lysstråler i grottene, under vann og på Gral-borgen!
	if GameState.volumetric_fog_enabled and (is_cave or is_graal or is_swim):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.018 if is_swim else (0.022 if is_cave else 0.008)
		env.volumetric_fog_albedo = Color(0.18, 0.72, 0.88) if is_swim else (Color(0.24, 0.85, 0.64) if "end" in current_level_id else Color(0.38, 0.48, 0.72))
		env.volumetric_fog_emission = Color(0.02, 0.14, 0.22) if is_swim else (Color(0.04, 0.18, 0.13) if "end" in current_level_id else Color(0.03, 0.04, 0.08))
		env.volumetric_fog_emission_energy = 0.35 if is_swim else (0.45 if is_cave else 0.25)
		env.volumetric_fog_anisotropy = 0.62
		env.volumetric_fog_length = 48.0 if is_swim else 55.0

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.18

	_env_node.environment = env
	_world_root.add_child(_env_node)

	# Hovedlys (varm sol / sølvblått måneskinn på Gral) med 4K myke skygger
	_sun_node = DirectionalLight3D.new()
	_sun_node.light_color = cfg.get("sun_color", Color(1.0, 0.90, 0.68))
	_sun_node.light_energy = float(cfg.get("sun_energy", 2.25))
	_sun_node.shadow_enabled = true
	_sun_node.shadow_blur = 1.8
	_sun_node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun_node.directional_shadow_max_distance = 220.0
	var sang: Vector3 = cfg.get("sun_angles", Vector3(-36.0, 36.0, 0.0))
	_sun_node.rotation_degrees = sang
	_world_root.add_child(_sun_node)

	# Kald / varm motsatt Pixar-fyllbelysning (hindrer flate grå skygger og skaper kinokontrast!)
	if not is_cave:
		var fill := DirectionalLight3D.new()
		fill.light_color = Color(1.0, 0.62, 0.28) if is_graal else Color(0.38, 0.64, 1.0)
		fill.light_energy = 0.42 if is_graal else 0.52
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(-24.0, sang.y + 165.0, 0.0)
		_world_root.add_child(fill)


const LEVEL_GLB_FALLBACKS := {
	"graal_mountain": "graal_bosslevel",
	"fatamorgana_palace": "fatamorgana_city",
	"swimming": "magakhan_beach",
	"outro": "abra",
}


func _load_level_geometry(w3d_name: String, water_y: float) -> AABB:
	var bounds := AABB(Vector3(-80, -5, -80), Vector3(160, 40, 160))
	var glb_path := "res://assets/levels/%s.glb" % w3d_name
	if not ResourceLoader.exists(glb_path) and LEVEL_GLB_FALLBACKS.has(w3d_name):
		glb_path = "res://assets/levels/%s.glb" % str(LEVEL_GLB_FALLBACKS[w3d_name])
	if ResourceLoader.exists(glb_path):
		var scene := load(glb_path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			inst.name = "LevelGeometry"
			_world_root.add_child(inst)

			var first := true
			var min_v := Vector3.ZERO
			var max_v := Vector3.ZERO
			var lantern_count := 0

			for mi in _find_all_meshes(inst):
				var nm := mi.name.to_lower()
				# Skjul gamle flate 2005 Shockwave-vannflater og 2005 skybokser/bakgrunnskupler!
				if "water" in nm or "abrasea" in nm or nm.ends_with("sea") or nm.ends_with("sea2") or "background" in nm or "skybox" in nm:
					mi.visible = false
					continue
				# Erstatt gamle ugjennomsiktige Shockwave glow-plater med ekte varme Godot 4 OmniLight3D-lykter
				if "glow" in nm:
					mi.visible = false
					if lantern_count < 12 and nm.begins_with("glow"):
						var laabb: AABB = mi.global_transform * mi.get_aabb()
						var lgt := OmniLight3D.new()
						lgt.position = laabb.get_center()
						lgt.light_color = Color(1.0, 0.74, 0.32)
						lgt.light_energy = 3.2
						lgt.omni_range = 14.0
						_world_root.add_child(lgt)
						lantern_count += 1
					continue
				# Skjul usynlige UI/shop/fog-hjelpemesher
				if "portalchoice" in nm or "fog" in nm or nm in ["shoplamp", "shopslingshot", "shopsword"]:
					mi.visible = false
					continue

				# 1:1 Gral-boss: Løft originale Greven av Gral på dragen (GraalBoss) og katapulten opp på borgen!
				if w3d_name == "graal_bosslevel" and nm == "graalboss":
					mi.position = Vector3(6.8, 23.8, -11.6)
					mi.rotation_degrees = Vector3(-6.0, 102.0, 0.0)
					mi.scale = Vector3.ONE * 1.28
					var dragon_glow := OmniLight3D.new()
					dragon_glow.position = Vector3(0.0, 1.4, 1.2)
					dragon_glow.light_color = Color(1.0, 0.44, 0.12)
					dragon_glow.light_energy = 6.2
					dragon_glow.omni_range = 22.0
					mi.add_child(dragon_glow)
					continue
				if w3d_name == "graal_bosslevel" and nm == "catapult":
					mi.position = Vector3(-7.6, 22.8, -11.6)
					mi.rotation_degrees = Vector3(0.0, 90.0, 0.0)
					mi.create_trimesh_collision()
					continue
				if w3d_name == "graal_bosslevel" and nm == "catapultrock":
					mi.visible = false
					continue

				mi.create_trimesh_collision()
				var aabb: AABB = mi.global_transform * mi.get_aabb()
				if first:
					min_v = aabb.position
					max_v = aabb.position + aabb.size
					first = false
				else:
					min_v = min_v.min(aabb.position)
					max_v = max_v.max(aabb.position + aabb.size)

			# Oppgrader ALLE synlige nivåmaterialer til knivskarp AAA animasjons-PBR med 3D mikrodetalj!
			VisualEnhancer.enhance_world_node(inst, current_level_id, water_y)

			if not first:
				bounds = AABB(min_v, max_v - min_v)
			return bounds

	_build_fallback_island()
	return bounds


func _add_biome_atmosphere(level_id: String, spawn_pos: Vector3) -> void:
	# Svevende atmosfæriske partikler i alle verdener
	VisualEnhancer.spawn_ambient_particles(_world_root, spawn_pos, level_id)

	# Gral-borgen: 4 brennende smijerns-fakkelfat + skummel taggete fjellkjede og 3D lynnedslag!
	if level_id == "graal_bosslevel" or level_id == "graal_mountain":
		VisualEnhancer.spawn_graal_scary_backdrop(_world_root)
		if level_id == "graal_bosslevel":
			for bpos in [
				Vector3(-9.2, 21.42, -12.4),
				Vector3(-0.8, 21.42, -13.6),
				Vector3(3.8, 21.42, -13.6),
				Vector3(9.4, 21.42, -11.4),
			]:
				VisualEnhancer.spawn_fire_brazier(_world_root, bpos, 0.92)

	# Grusomme Gabriels grotte-finale: varme inngangsfakler + smaragdgrønn spøkelsesglød i kammeret foran!
	elif level_id in ["cave_end_bosslevel", "cave_end", "cave"]:
		var is_ghost := (level_id != "cave")
		# Dempet varmt lyktelys bak Pinky (gir gyllen kantglød uten utbrenning!)
		var warm_torch := OmniLight3D.new()
		warm_torch.position = spawn_pos + Vector3(-2.6, 2.8, 2.2)
		warm_torch.light_color = Color(1.0, 0.64, 0.24)
		warm_torch.light_energy = 2.8
		warm_torch.omni_range = 16.0
		_world_root.add_child(warm_torch)

		# Eterisk smaragdgrønt lys dypt inne i Grusomme Gabriels skattkammer
		var chamber_glow := OmniLight3D.new()
		chamber_glow.position = spawn_pos + Vector3(0.0, 5.5, -18.0)
		chamber_glow.light_color = Color(0.18, 1.0, 0.64) if is_ghost else Color(1.0, 0.78, 0.34)
		chamber_glow.light_energy = 7.5 if is_ghost else 4.5
		chamber_glow.omni_range = 38.0
		_world_root.add_child(chamber_glow)


func _find_all_meshes(node: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		list.append(node)
	for c in node.get_children():
		list.append_array(_find_all_meshes(c))
	return list


func _build_fallback_island() -> void:
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 2, 60)
	col.shape = box
	col.position.y = -1.0
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(60, 2, 60)
	mi.mesh = m
	mi.position.y = -1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.48, 0.34)
	mat.roughness = 0.88
	mi.material_override = mat
	sb.add_child(mi)
	_world_root.add_child(sb)


func _spawn_world_map_seabed() -> void:
	# Ekte havbunn på Y=-10.5 slik at DEPTH_TEXTURE skaper glødende turkise laguner rundt hver øy og safirblått dyp!
	var bed := MeshInstance3D.new()
	bed.name = "WorldMapSeabed"
	var pm := PlaneMesh.new()
	pm.size = Vector2(900.0, 900.0)
	bed.mesh = pm
	bed.position = Vector3(0.0, -10.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.08, 0.16)
	mat.roughness = 1.0
	bed.material_override = mat
	_world_root.add_child(bed)


func _spawn_modern_ocean(water_y: float, bounds: AABB, is_world_map: bool = false) -> void:
	var water := MeshInstance3D.new()
	water.name = "ModernOcean"
	var pm := PlaneMesh.new()
	var span: float = maxf(maxf(bounds.size.x, bounds.size.z) * 2.4, 520.0)
	pm.size = Vector2(span, span)
	pm.subdivide_width = 128
	pm.subdivide_depth = 128
	water.mesh = pm
	water.position = Vector3(bounds.get_center().x, water_y, bounds.get_center().z)

	var sm := ShaderMaterial.new()
	sm.shader = OCEAN_SHADER
	if is_world_map:
		sm.set_shader_parameter("deep_color", Color(0.015, 0.17, 0.36, 1.0))
		sm.set_shader_parameter("mid_color", Color(0.02, 0.40, 0.56, 1.0))
		sm.set_shader_parameter("shallow_color", Color(0.08, 0.72, 0.72, 1.0))
		sm.set_shader_parameter("depth_fade", 3.2)
		sm.set_shader_parameter("foam_width", 0.55)
		sm.set_shader_parameter("wave_height", 0.22)
		sm.set_shader_parameter("cloud_shadow_strength", 0.20)
		sm.set_shader_parameter("sparkle_strength", 1.35)
	elif current_level_id == "fatamorgana_city":
		sm.set_shader_parameter("deep_color", Color(0.02, 0.28, 0.44, 1.0))
		sm.set_shader_parameter("mid_color", Color(0.04, 0.52, 0.62, 1.0))
		sm.set_shader_parameter("shallow_color", Color(0.16, 0.80, 0.78, 1.0))
		sm.set_shader_parameter("sun_dir", Vector3(0.62, 0.28, -0.74))
		sm.set_shader_parameter("sun_tint", Color(1.0, 0.90, 0.58))
		sm.set_shader_parameter("depth_fade", 3.6)
		sm.set_shader_parameter("foam_width", 0.85)
		sm.set_shader_parameter("wave_height", 0.12)
		sm.set_shader_parameter("sparkle_strength", 1.2)
	else:
		sm.set_shader_parameter("deep_color", Color(0.015, 0.16, 0.34, 1.0))
		sm.set_shader_parameter("mid_color", Color(0.02, 0.38, 0.52, 1.0))
		sm.set_shader_parameter("shallow_color", Color(0.10, 0.70, 0.72, 1.0))
		sm.set_shader_parameter("sun_dir", Vector3(-0.52, 0.32, -0.78))
		sm.set_shader_parameter("sun_tint", Color(1.0, 0.94, 0.72))
		sm.set_shader_parameter("depth_fade", 4.2)
		sm.set_shader_parameter("foam_width", 0.95)
		sm.set_shader_parameter("wave_height", 0.16)
		sm.set_shader_parameter("sparkle_strength", 1.1)

	water.material_override = sm
	_world_root.add_child(water)


func _read_gameplay_json(level_id: String) -> Dictionary:
	var path := "res://data/gameplay/%s.json" % level_id
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _create_camera_rig() -> FollowCamera:
	var rig: FollowCamera = CAMERA_SCRIPT.new()
	rig.name = "CameraRig"

	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 9.5
	arm.collision_mask = 1
	arm.margin = 0.65
	var arm_shape := SphereShape3D.new()
	arm_shape.radius = 0.45
	arm.shape = arm_shape
	rig.add_child(arm)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 600.0
	cam.current = true
	arm.add_child(cam)
	return rig


func _find_player_spawn(level_id: String, gp_data: Dictionary, bounds: AABB) -> Vector3:
	# 1:1 Gral-bosskampen skjer oppe på borggårdens brystvern foran katapulten (Y = 21.41m, Z = -12.4)
	if level_id == "graal_bosslevel":
		return Vector3(-0.8, 21.8, -12.4)

	var nodes: Array = gp_data.get("nodes", [])
	for n in nodes:
		var nm := str(n.get("name", "")).to_lower()
		if nm == "character_pinky" or nm == "character_treasureseeker":
			var gp: Array = n.get("godot_pos", [0, 0, 0])
			var p := Vector3(float(gp[0]) * WORLD_SCALE, float(gp[1]) * WORLD_SCALE + 3.0, float(gp[2]) * WORLD_SCALE)
			var hit := _raycast_ground(p, bounds)
			if hit.y > -5000.0:
				return hit + Vector3(0.0, 0.5, 0.0)
	var center := bounds.get_center()
	return _snap_to_surface(Vector3(center.x, bounds.position.y + bounds.size.y + 4.0, center.z), bounds)


func _build_world_map_islands() -> void:
	# Moderne animasjonsspill-øyer med synkrone steinnormaler, skulpturerte klippeterrasser og håndlagde landemerker!
	var active_story_id := GameState.get_active_story_island()
	var islands := [
		{"name": "Abra Havn", "id": "abra", "pos": Vector3(-29.0, 0.0, 18.0), "r": 13.8, "seed": 11, "theme": "harbor"},
		{"name": "Gral", "id": "graal_mountain", "pos": Vector3(-25.0, 0.0, -17.5), "r": 14.5, "seed": 23, "theme": "castle"},
		{"name": "Fata Morgana", "id": "fatamorgana_city", "pos": Vector3(29.0, 0.0, -16.0), "r": 14.0, "seed": 37, "theme": "desert"},
		{"name": "Maga Khans øy", "id": "magakhan_beach", "pos": Vector3(32.0, 0.0, 18.5), "r": 14.8, "seed": 53, "theme": "jungle"},
		{"name": "Skattejakt-øya", "id": "treasurehunt", "pos": Vector3(2.0, 0.0, -29.0), "r": 10.5, "seed": 71, "theme": "palm"},
	]

	# Synkron prosedyrell støy- og normaltekstur (100% klar allerede på bilde 1!)
	var micro_noise := FastNoiseLite.new()
	micro_noise.seed = 404
	micro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	micro_noise.frequency = 0.08
	micro_noise.fractal_octaves = 5
	var noise_img := micro_noise.get_seamless_image(256, 256)
	var height_noise_tex := ImageTexture.create_from_image(noise_img)
	var nrm_img := noise_img.duplicate() as Image
	nrm_img.bump_map_to_normal_map(8.5)
	var normal_tex := ImageTexture.create_from_image(nrm_img)

	for isl in islands:
		var root := Node3D.new()
		root.position = isl["pos"]
		_world_root.add_child(root)

		var r: float = isl["r"]
		var theme: String = isl["theme"]
		var seed_v: int = int(isl["seed"])
		var isl_id: String = str(isl["id"])
		var is_active := (isl_id == active_story_id)
		var unlocked := GameState.is_island_unlocked(isl_id)

		var n_shape := FastNoiseLite.new()
		n_shape.seed = seed_v
		n_shape.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n_shape.frequency = 0.095
		n_shape.fractal_octaves = 5

		var n_detail := FastNoiseLite.new()
		n_detail.seed = seed_v + 99
		n_detail.noise_type = FastNoiseLite.TYPE_CELLULAR
		n_detail.frequency = 0.22

		var height_fn := func(fx: float, fz: float) -> float:
			return _sample_island_height(fx, fz, r, theme, n_shape, n_detail)

		var terrain := _make_stylized_island_mesh(r, theme, height_fn, height_noise_tex, normal_tex)
		root.add_child(terrain)

		# Dekorer øya med eksakt terrenghøyde (null nedsunkne hus!), brygger, klippesteiner, busker, palmer og landemerker!
		VisualEnhancer.decorate_world_map_island(root, r, theme, seed_v, is_active, height_fn)

		# Navneskilt over øya
		var lbl := Label3D.new()
		lbl.text = str(isl["name"]) + (" ★" if is_active else ("" if unlocked else " (Låst)"))
		lbl.position = Vector3(0.0, 14.5, 0.0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 64
		lbl.outline_size = 16
		lbl.modulate = Color(1.0, 0.90, 0.44) if is_active else (Color(0.96, 0.94, 0.86) if unlocked else Color(0.65, 0.68, 0.74))
		root.add_child(lbl)

		# Ankringsbøye ved øya
		var portal: PortalTrigger = PORTAL_SCRIPT.new()
		portal.is_world_map_buoy = true
		portal.target_level_id = isl_id if unlocked else active_story_id
		portal.portal_label = "Gå i land: " + str(isl["name"])
		portal.position = (isl["pos"] as Vector3) + Vector3(0.0, 0.25, r * 0.95 + 2.8)
		_world_root.add_child(portal)

	# 1:1 original dykkebøye ute på havet (world_map_underwater1..10 skipsvrak-dykk i 2D!)
	var dive_buoy: PortalTrigger = PORTAL_SCRIPT.new()
	dive_buoy.is_world_map_buoy = true
	dive_buoy.target_level_id = "world_map_underwater"
	dive_buoy.portal_label = "Dykk til skipsvraket (2D)"
	dive_buoy.position = Vector3(-9.5, 0.25, 11.5)
	_world_root.add_child(dive_buoy)

	# Plasser 2 originale fiendeskip fra world_map.glb ute på havet med skummende kjølvann!
	if ResourceLoader.exists("res://assets/levels/world_map.glb"):
		var sc := load("res://assets/levels/world_map.glb") as PackedScene
		if sc:
			for sp_info in [
				[Vector3(17.5, 0.0, -2.5), -0.6],
				[Vector3(-15.5, 0.0, -5.5), 1.1],
			]:
				var ship := sc.instantiate()
				ship.position = sp_info[0]
				ship.rotation.y = sp_info[1]
				ship.scale = Vector3.ONE * 0.42
				for mi in _find_all_meshes(ship):
					var nm := mi.name.to_lower()
					mi.visible = (nm in ["enemyship", "enemyrailing"])
				VisualEnhancer.enhance_world_node(ship, "abra", 0.0)
				VisualEnhancer.attach_ship_wake(ship, 1.8)
				_world_root.add_child(ship)


func _sample_island_height(fx: float, fz: float, radius: float, theme: String, n_shape: FastNoiseLite, n_detail: FastNoiseLite) -> float:
	var r_cur := Vector2(fx, fz).length()
	var rt := clampf(r_cur / (radius * 1.55), 0.0, 1.0)
	# Organisk kystlinje med tydelige viker, nes og klippeodder!
	var ang := atan2(fz, fx)
	var cove := sin(ang * 3.0 + float(n_shape.seed)) * 0.10 + cos(ang * 5.0 - float(n_shape.seed) * 0.5) * 0.06
	var coast_warp := n_shape.get_noise_2d(fx * 0.72, fz * 0.72) * 0.34 + cove
	var nd := (r_cur / radius) + coast_warp * clampf(rt * 2.1, 0.0, 1.0)

	# Flere dramatiske fjellrygger og klippetopper på hver øy (skarpe 3D-skygger!)
	var ridge := pow(1.0 - absf(n_shape.get_noise_2d(fx * 1.45, fz * 1.45)), 1.85) * 0.85
	var crag := (0.5 + 0.5 * n_detail.get_noise_2d(fx * 1.15, fz * 1.15)) * 0.55
	# Sekundære fjellknatter langs kanten slik at øya ikke bare er en jevn kuppel!
	var sub_peak_a := exp(-Vector2(fx - radius * 0.38, fz + radius * 0.25).length_squared() / (radius * radius * 0.09)) * 4.4
	var sub_peak_b := exp(-Vector2(fx + radius * 0.36, fz - radius * 0.22).length_squared() / (radius * radius * 0.08)) * 3.8

	var peak := 14.5 if theme == "castle" else (9.6 if theme == "desert" else 11.8)
	if nd < 0.96:
		var land_t := clampf(1.0 - nd / 0.96, 0.0, 1.0)
		var base_cone := pow(land_t, 0.62) * peak * (0.48 + 0.56 * ridge + 0.34 * crag)
		var extra_crags := (sub_peak_a + sub_peak_b) * smoothstep(0.08, 0.45, land_t)
		var raw_h := 0.25 + base_cone + extra_crags
		# Tydelige bratte klippeterrasser med flate platåer (gir skarp 3D-skygge og tydelig klippeshader!)
		var step_h := 2.6 if theme == "castle" else 2.2
		var frac := fmod(raw_h, step_h) / step_h
		var terrace := floorf(raw_h / step_h) * step_h + smoothstep(0.18, 0.58, frac) * step_h
		var terr_w := 0.72 if theme == "castle" else (0.45 if theme == "desert" else 0.58)
		return lerpf(raw_h, terrace, terr_w)
	elif nd < 1.48:
		var slope_t := clampf((nd - 0.96) / 0.52, 0.0, 1.0)
		return lerpf(0.25, -11.5, slope_t * slope_t * (3.0 - 2.0 * slope_t))
	return -11.8


func _make_stylized_island_mesh(radius: float, theme: String, height_fn: Callable, noise_tex: Texture2D, normal_tex: Texture2D) -> MeshInstance3D:
	var rings := 42
	var segs := 72
	var max_r := radius * 1.55
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_verts: Array = []
	var ring_uvs: Array = []

	for ri in range(rings + 1):
		var rt := float(ri) / float(rings)
		var r_cur := rt * max_r
		var rv: Array[Vector3] = []
		var ru: Array[Vector2] = []
		for si in range(segs + 1):
			var ang := (float(si) / float(segs)) * TAU
			var fx := cos(ang) * r_cur
			var fz := sin(ang) * r_cur
			var h: float = -11.8 if ri == rings else float(height_fn.call(fx, fz))
			rv.append(Vector3(fx, h, fz))
			ru.append(Vector2(fx / max_r * 4.0, fz / max_r * 4.0))
		ring_verts.append(rv)
		ring_uvs.append(ru)

	for ri in range(rings):
		for si in range(segs):
			var v00: Vector3 = ring_verts[ri][si]
			var v10: Vector3 = ring_verts[ri + 1][si]
			var v01: Vector3 = ring_verts[ri][si + 1]
			var v11: Vector3 = ring_verts[ri + 1][si + 1]
			var u00: Vector2 = ring_uvs[ri][si]
			var u10: Vector2 = ring_uvs[ri + 1][si]
			var u01: Vector2 = ring_uvs[ri][si + 1]
			var u11: Vector2 = ring_uvs[ri + 1][si + 1]
			for tri in [
				[v00, u00], [v10, u10], [v11, u11],
				[v00, u00], [v11, u11], [v01, u01],
			]:
				st.set_uv(tri[1])
				st.add_vertex(tri[0])

	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()

	var theme_id := 0
	match theme:
		"castle": theme_id = 1
		"desert": theme_id = 2
		"jungle": theme_id = 3
		"palm": theme_id = 4
		_: theme_id = 0

	var smat := ShaderMaterial.new()
	smat.shader = ISLAND_TERRAIN_SHADER
	smat.set_shader_parameter("theme_id", theme_id)
	smat.set_shader_parameter("noise_tex", noise_tex)
	smat.set_shader_parameter("detail_normal_tex", normal_tex)
	mi.material_override = smat
	return mi


func _snap_to_surface(pos: Vector3, bounds: AABB) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space:
		var from := Vector3(pos.x, bounds.position.y + bounds.size.y + 20.0, pos.z)
		var to := Vector3(pos.x, bounds.position.y - 30.0, pos.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		if hit and hit.has("position"):
			return hit["position"] + Vector3(0.0, 0.5, 0.0)
	return Vector3(pos.x, maxf(pos.y, 1.5), pos.z)


func _spawn_pinky(pos: Vector3, is_swim: bool) -> CharacterBody3D:
	var pinky: PinkyController = PINKY_SCRIPT.new()
	pinky.name = "Pinky"
	pinky.is_swimming = is_swim
	pinky.position = pos
	# I Gral-bosskampen vender Pinky fremover mot Greven av Gral og katapulten med sverdet klart i hånden!
	if current_level_id == "graal_bosslevel":
		pinky.rotation_degrees.y = -72.0
	pinky.camera_rig = _camera_rig

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.6
	col.shape = cap
	col.position.y = 0.85
	pinky.add_child(col)

	_world_root.add_child(pinky)
	return pinky


func _spawn_boat(pos: Vector3) -> CharacterBody3D:
	var boat: BoatController = BOAT_SCRIPT.new()
	boat.name = "DenSorteDame"
	boat.position = Vector3(pos.x, 0.0, pos.z)
	boat.camera_rig = _camera_rig

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.5, 2.5, 11.0)
	col.shape = box
	col.position.y = 1.2
	boat.add_child(col)

	_world_root.add_child(boat)
	return boat


func _populate_entities(level_id: String, cfg: Dictionary, gp_data: Dictionary, spawn_pos: Vector3, bounds: AABB) -> void:
	# 1:1 Greven av Gral på dragen (selve GraalBoss-dragemodellen fra graal_bosslevel.glb svever over borgen)
	if level_id == "graal_bosslevel":
		GameState.emit_signal("boss_health_changed", "Greven av Gral", 260.0, 260.0)

	var nodes: Array = gp_data.get("nodes", [])
	var spawned_chars := 0

	for n in nodes:
		var nm := str(n.get("name", "")).to_lower()
		if not nm.begins_with("character_"):
			continue
		var key := nm.substr(10)
		if key == "pinky" or key == "treasureseeker":
			continue

		var gp: Array = n.get("godot_pos", [0, 0, 0])
		var pos := _snap_to_surface(
			Vector3(float(gp[0]) * WORLD_SCALE, float(gp[1]) * WORLD_SCALE + 2.0, float(gp[2]) * WORLD_SCALE),
			bounds
		)

		var matched_role := _match_character_role(key)
		if matched_role.is_empty():
			continue

		spawned_chars += 1
		if spawned_chars > 24:
			continue

		if matched_role["role"] == "npc":
			var npc: NpcActor = NPC_SCRIPT.new()
			npc.npc_id = key
			npc.display_name = matched_role["name"]
			npc.model_resource = matched_role["model"]
			npc.reward_coins = int(matched_role.get("coins", 5))
			npc.position = pos
			_world_root.add_child(npc)
		else:
			var enemy: EnemyActor = ENEMY_SCRIPT.new()
			enemy.enemy_name = matched_role["name"]
			enemy.model_resource = matched_role["model"]
			enemy.max_hp = float(matched_role.get("hp", 60.0))
			enemy.attack_damage = float(matched_role.get("dmg", 12.0))
			enemy.is_boss = (matched_role["role"] == "boss")
			enemy.coin_drop = 25 if enemy.is_boss else 5
			enemy.position = pos
			_world_root.add_child(enemy)

	# Portal til neste nivå i 100% original historierekkefølge
	var next_id := str(cfg.get("next_level", "world_map"))
	var next_info := LevelCatalog.get_level(next_id)
	var portal: PortalTrigger = PORTAL_SCRIPT.new()
	portal.target_level_id = next_id
	if level_id == "graal_mountain":
		portal.portal_label = "Hopp i brønnen → Undervannstunnel (2D)"
	else:
		portal.portal_label = "Reis til " + str(next_info.get("title", next_id))
	var portal_raw := spawn_pos + Vector3(6.5, 2.0, -5.5)
	if level_id == "graal_bosslevel":
		portal_raw = Vector3(-6.2, 26.5, -5.5)
	var phit := _raycast_ground(portal_raw, bounds)
	portal.position = (phit + Vector3(0.0, 0.25, 0.0)) if phit.y > -5000.0 else spawn_pos + Vector3(6.0, 0.25, -5.0)
	_world_root.add_child(portal)

	# 1:1 originale undervanns-brønner (2D side-scrolling dykk!) i Fata Morgana og Maga Khans fangehull
	if level_id == "fatamorgana_city":
		var well_p: PortalTrigger = PORTAL_SCRIPT.new()
		well_p.target_level_id = "fatamorgana_underwater"
		well_p.portal_label = "Dykk i brønnen etter kaken (2D)"
		var wh := _raycast_ground(spawn_pos + Vector3(-5.5, 2.5, -4.5), bounds)
		well_p.position = (wh + Vector3(0.0, 0.25, 0.0)) if wh.y > -5000.0 else spawn_pos + Vector3(-5.5, 0.25, -4.5)
		_world_root.add_child(well_p)
	elif level_id == "magakhan_dungeon":
		var key_p: PortalTrigger = PORTAL_SCRIPT.new()
		key_p.target_level_id = "magakhan_dungeon_underwater"
		key_p.portal_label = "Dykk etter fangehullsnøkkelen (2D)"
		var kh := _raycast_ground(spawn_pos + Vector3(-5.5, 2.5, -4.5), bounds)
		key_p.position = (kh + Vector3(0.0, 0.25, 0.0)) if kh.y > -5000.0 else spawn_pos + Vector3(-5.5, 0.25, -4.5)
		_world_root.add_child(key_p)

	# Plasser pregede dubloner og håndlagde eiketønner KUN på flatt, tørt dekke (normal.y > 0.88)!
	var min_dry_y: float = float(cfg.get("water_y", -99.0)) + 0.45 if bool(cfg.get("has_water", false)) else -999.0
	for i in range(10):
		var ang := (float(i) / 10.0) * TAU + 0.2
		var rad := 6.0 + float(i % 3) * 3.5
		var cand := spawn_pos + Vector3(cos(ang) * rad, 3.0, sin(ang) * rad)
		var info := _raycast_ground_info(cand, bounds)
		if info.has("position"):
			var hit_pos: Vector3 = info["position"]
			var hit_nrm: Vector3 = info["normal"]
			if hit_pos.y > min_dry_y and hit_nrm.y > 0.86 and absf(hit_pos.y - spawn_pos.y) < 2.6:
				var coin: CollectibleCoin = COIN_SCRIPT.new()
				coin.position = hit_pos + Vector3(0.0, 0.60, 0.0)
				_world_root.add_child(coin)

	if level_id != "graal_bosslevel":
		for i in range(4):
			var ang := (float(i) / 4.0) * TAU + 0.5
			var cand := spawn_pos + Vector3(cos(ang) * 7.5, 3.0, sin(ang) * 7.5)
			var info := _raycast_ground_info(cand, bounds)
			if info.has("position"):
				var hit_pos: Vector3 = info["position"]
				var hit_nrm: Vector3 = info["normal"]
				if hit_pos.y > min_dry_y and hit_nrm.y > 0.90 and absf(hit_pos.y - spawn_pos.y) < 2.2:
					var barrel: BreakableBarrel = BARREL_SCRIPT.new()
					barrel.position = hit_pos
					_world_root.add_child(barrel)


# ==============================================================================
# 1:1 2D SIDE-SCROLLING UNDERVANNS-SVØMMING (graal_underwater, fatamorgana_underwater,
# magakhan_dungeon_underwater, world_map_underwater)
# ==============================================================================

func _load_underwater_world(w3d_name: String) -> AABB:
	var bounds := AABB(Vector3(-26, -20, -14), Vector3(52, 42, 18))
	var glb_path := "res://assets/levels/%s.glb" % w3d_name
	if ResourceLoader.exists(glb_path):
		var scene := load(glb_path) as PackedScene
		if scene:
			var inst := scene.instantiate()
			inst.name = "UnderwaterGeometry_" + w3d_name
			_world_root.add_child(inst)
			var all_meshes := _find_all_meshes(inst)
			var first := true
			for mi in all_meshes:
				if mi.mesh == null:
					continue
				var aabb := mi.global_transform * mi.get_aabb()
				if first:
					bounds = aabb
					first = false
				else:
					bounds = bounds.merge(aabb)
			VisualEnhancer.enhance_world_node(inst, "cave", -999.0)

	# Dyp havblå bakgrunnsvegg bak undervannstunnelen slik at himmelen aldri skinner gjennom baksiden
	var bg := MeshInstance3D.new()
	bg.name = "UnderwaterBackdrop"
	var pm := PlaneMesh.new()
	pm.size = Vector2(120.0, 90.0)
	bg.mesh = pm
	bg.position = Vector3(bounds.get_center().x, bounds.get_center().y, -6.5)
	bg.rotation_degrees.x = 90.0
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.albedo_color = Color(0.015, 0.14, 0.24)
	bg.material_override = bg_mat
	_world_root.add_child(bg)

	# Ekte volumetriske undervanns-lyskjegler (SpotLight3D) som skinner ned brønnsjaktene uten harde kanter!
	for rx in [-12.5, -0.4, 11.0]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(rx, 13.0, 1.5)
		sl.rotation_degrees = Vector3(-86.0, 0.0, 0.0)
		sl.light_color = Color(0.42, 0.92, 1.0)
		sl.light_energy = 7.5
		sl.light_volumetric_fog_energy = 2.6
		sl.spot_range = 24.0
		sl.spot_angle = 28.0
		sl.spot_attenuation = 0.75
		sl.shadow_enabled = false
		_world_root.add_child(sl)

	# Myke flytende undervanns-støvpartikler og lysende plankton
	VisualEnhancer.spawn_ambient_particles(_world_root, Vector3(0.0, 0.0, 0.0), "cave_end")
	return bounds


func _find_swimmer_spawn(level_id: String, gp_data: Dictionary) -> Vector3:
	for n in gp_data.get("nodes", []):
		if str(n.get("name", "")).to_lower() == "swimmer_pinky":
			var sp: Array = n.get("sw_pos", [0, 0, 0])
			return Vector3(float(sp[0]) * WORLD_SCALE, float(sp[1]) * WORLD_SCALE - 3.0, 0.0)
	if level_id == "graal_underwater":
		return Vector3(-12.8, 5.5, 0.0)
	return Vector3(0.0, 2.0, 0.0)


func _spawn_swimmer(pos: Vector3) -> CharacterBody3D:
	var sw: SwimmingController = SWIMMER_SCRIPT.new()
	sw.name = "PinkySwimmer"
	sw.position = Vector3(pos.x, pos.y, 0.0)
	sw.camera_rig = _camera_rig

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.65
	col.shape = sph
	sw.add_child(col)

	_world_root.add_child(sw)
	return sw


func _build_underwater_spline_walls(gp_data: Dictionary) -> void:
	# Konverter originalspillets 2D XY-splines (Line01..03 + Circle01..06) direkte til ekte kollisjonsvegger!
	var body := StaticBody3D.new()
	body.name = "UnderwaterSplineCollision"
	_world_root.add_child(body)

	var re_vec := RegEx.new()
	re_vec.compile("vector\\(([\\-\\d.]+),([\\-\\d.]+),([\\-\\d.]+)\\)")
	var re_rad := RegEx.new()
	re_rad.compile("#radius:([\\d.]+)")

	for n in gp_data.get("nodes", []):
		var ud := str(n.get("userdata", ""))
		if "#linearSplines" in ud:
			var pts: Array[Vector2] = []
			for m in re_vec.search_all(ud):
				pts.append(Vector2(float(m.get_string(1)) * WORLD_SCALE, float(m.get_string(2)) * WORLD_SCALE))
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var seg := b - a
				var seg_len := seg.length()
				if seg_len < 0.1:
					continue
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(seg_len + 0.35, 0.55, 4.0)
				cs.shape = bx
				var mid := (a + b) * 0.5
				cs.position = Vector3(mid.x, mid.y, 0.0)
				cs.rotation.z = atan2(seg.y, seg.x)
				body.add_child(cs)
		elif "#type:#circle" in ud and not ("3dsound" in str(n.get("name", "")).to_lower()):
			var rm := re_rad.search(ud)
			var vm := re_vec.search(ud)
			if rm and vm:
				var rad := float(rm.get_string(1)) * WORLD_SCALE * 0.85
				var cx := float(vm.get_string(1)) * WORLD_SCALE
				var cy := float(vm.get_string(2)) * WORLD_SCALE
				var cs := CollisionShape3D.new()
				var sph := SphereShape3D.new()
				sph.radius = maxf(rad, 0.4)
				cs.shape = sph
				cs.position = Vector3(cx, cy, 0.0)
				body.add_child(cs)


func _populate_underwater_entities(level_id: String, cfg: Dictionary, gp_data: Dictionary) -> void:
	var next_id := str(cfg.get("next_level", "world_map"))
	var ret_id := str(cfg.get("return_level", next_id))
	var has_bubbles := false
	var has_exit := false

	for n in gp_data.get("nodes", []):
		var nm := str(n.get("name", "")).to_lower()
		var sp: Array = n.get("sw_pos", [0, 0, 0])
		var pos := Vector3(float(sp[0]) * WORLD_SCALE, float(sp[1]) * WORLD_SCALE, 0.0)

		if nm == "bubbles" or nm == "bubbles3" or nm == "bubbles4" or (nm.begins_with("areatrigger_air") and not has_bubbles):
			if nm.begins_with("areatrigger_air"):
				pos.y -= 7.5
			var bub: UnderwaterHazard = HAZARD_SCRIPT.new()
			bub.kind = "bubble_column"
			bub.column_height = 12.5
			bub.position = pos
			_world_root.add_child(bub)
			has_bubbles = true
		elif nm.begins_with("mine_"):
			var mine: UnderwaterHazard = HAZARD_SCRIPT.new()
			mine.kind = "mine"
			mine.position = pos
			_world_root.add_child(mine)
		elif nm.begins_with("shark_"):
			var sh: UnderwaterHazard = HAZARD_SCRIPT.new()
			sh.kind = "shark"
			sh.patrol_range = 6.5
			sh.patrol_speed = 3.2
			sh.position = pos
			_world_root.add_child(sh)
		elif nm.begins_with("piraya_"):
			var pr: UnderwaterHazard = HAZARD_SCRIPT.new()
			pr.kind = "piraya"
			pr.patrol_range = 4.2
			pr.patrol_speed = 3.8
			pr.position = pos
			_world_root.add_child(pr)
		elif nm.begins_with("object_coppercoin") or nm.begins_with("object_goldcoin"):
			var coin: CollectibleCoin = COIN_SCRIPT.new()
			coin.position = pos
			_world_root.add_child(coin)
		elif nm == "walkoverpickup_cake":
			var pk: UnderwaterHazard = HAZARD_SCRIPT.new()
			pk.kind = "pickup"
			pk.pickup_flag = "wellcake"
			pk.pickup_label = "brønnkaken i Fata Morgana"
			pk.position = pos
			_world_root.add_child(pk)
		elif nm == "walkoverpickup_key2":
			var pk: UnderwaterHazard = HAZARD_SCRIPT.new()
			pk.kind = "pickup"
			pk.pickup_flag = "key2"
			pk.pickup_label = "fangehullsnøkkelen"
			pk.position = pos
			_world_root.add_child(pk)
		elif nm == "areatrigger_leave":
			var ex: UnderwaterHazard = HAZARD_SCRIPT.new()
			ex.kind = "exit"
			ex.target_level_id = next_id
			ex.position = pos
			_world_root.add_child(ex)
			has_exit = true
		elif nm == "areatrigger_leave2":
			var ex2: UnderwaterHazard = HAZARD_SCRIPT.new()
			ex2.kind = "exit"
			ex2.target_level_id = ret_id
			ex2.position = pos
			_world_root.add_child(ex2)

	# Sørg for luftbobler, skattkiste og utgang også i world_map_underwater!
	if not has_bubbles:
		var bub: UnderwaterHazard = HAZARD_SCRIPT.new()
		bub.kind = "bubble_column"
		bub.column_height = 14.0
		bub.position = Vector3(-0.1, -6.2, 0.0)
		_world_root.add_child(bub)
	if "world_map" in level_id:
		var chest: UnderwaterHazard = HAZARD_SCRIPT.new()
		chest.kind = "pickup"
		chest.pickup_flag = "underwater_treasure"
		chest.pickup_label = "den sunkne sjørøverskatten"
		chest.position = Vector3(2.5, -9.5, 0.0)
		_world_root.add_child(chest)
	if not has_exit:
		var ex: UnderwaterHazard = HAZARD_SCRIPT.new()
		ex.kind = "exit"
		ex.target_level_id = next_id
		ex.position = Vector3(0.0, 12.5, 0.0)
		_world_root.add_child(ex)


func _raycast_ground(pos: Vector3, bounds: AABB) -> Vector3:
	var info := _raycast_ground_info(pos, bounds)
	if info.has("position"):
		return info["position"]
	return Vector3(pos.x, -9999.0, pos.z)


func _raycast_ground_info(pos: Vector3, bounds: AABB) -> Dictionary:
	var space := get_world_3d().direct_space_state
	if space:
		var from := Vector3(pos.x, bounds.position.y + bounds.size.y + 10.0, pos.z)
		var to := Vector3(pos.x, bounds.position.y - 10.0, pos.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		if hit and hit.has("position"):
			return hit
	return {}


func _match_character_role(key: String) -> Dictionary:
	for k in CHARACTER_ROLES.keys():
		if key == k or key.begins_with(k):
			return CHARACTER_ROLES[k]
	return {}
