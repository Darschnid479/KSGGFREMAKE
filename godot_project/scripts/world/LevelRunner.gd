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
const HM_SCRIPT := preload("res://scripts/world/HeightmapSampler.gd")
const STORY_SCRIPT := preload("res://scripts/world/StoryScriptEngine.gd")
const GRAAL_BOSS_SCRIPT := preload("res://scripts/world/GraalBossController.gd")
const ENEMY_SHIP_SCRIPT := preload("res://scripts/world/EnemyShip.gd")
const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")
const ISLAND_TERRAIN_SHADER := preload("res://shaders/island_terrain.gdshader")

const WORLD_SCALE := 0.1 # Samme 0.1-skala som OBJ->GLB-konvertereren (Shockwave-enheter -> meter)

var current_level_id: String = "cave"
var _world_root: Node3D
var _env_node: WorldEnvironment
var _sun_node: DirectionalLight3D
var _camera_rig: FollowCamera
var _player_node: CharacterBody3D
var _heightmap: HeightmapSampler
var _level_geom: Node3D
var _story_engine: StoryScriptEngine
var _actors_by_name: Dictionary = {}
var _colliders_by_name: Dictionary = {}
var _graal_boss_mesh: Mesh
var _graal_boss_mat: Material
var _catapult_mesh: Mesh
var _catapult_mat: Material
var _catapult_rock_mesh: Mesh
var _graal_boss_ctrl: GraalBossController

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
	AudioManager.stop_voice(false)

	if is_instance_valid(_world_root):
		_world_root.queue_free()
		await get_tree().process_frame

	_world_root = Node3D.new()
	_world_root.name = "WorldRoot_" + level_id
	add_child(_world_root)
	_level_geom = null
	_story_engine = null
	_actors_by_name.clear()
	_colliders_by_name.clear()
	_graal_boss_mesh = null
	_graal_boss_mat = null
	_catapult_mesh = null
	_catapult_mat = null
	_catapult_rock_mesh = null
	_graal_boss_ctrl = null

	# 0. Last 1:1 originalt binært høydekart (.hm) for millimeter-nøyaktig bakkekontakt (null sveving!)
	_heightmap = HM_SCRIPT.new()
	_heightmap.load_level(level_id)

	var cfg := LevelCatalog.get_level(level_id)
	GameState.set_objective(str(cfg.get("objective", "")))
	AudioManager.play_music(str(cfg.get("music", "abra")))

	# 1. Moderne AAA animasjonsspill-miljø (ACES, SSAO, SSIL, volumetrisk tåke, malt himmel)
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

	# 4. Les originale gameplay-data (spawns, NPC-er, fiender, portaler, 2D-svømmehindre, Global-historie)
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
		var cam_dist := 12.5 if "world_map" in level_id else 9.2
		_camera_rig.set_target(_player_node, cam_dist, 0.35, false, true)
		_camera_rig.set_side_2d_bounds(level_bounds, cam_dist)
		_populate_underwater_entities(level_id, cfg, gp_data)
	else:
		var spawn_pos := _find_player_spawn(level_id, gp_data, level_bounds)
		_build_3d_spline_walls(gp_data, spawn_pos)
		_player_node = _spawn_pinky(spawn_pos, false)
		var is_tight_indoor := level_id in [
			"cave", "cave_end", "cave_end_bosslevel",
			"magakhan_dungeon", "magakhan_palace", "fatamorgana_palace", "graal_bosslevel"
		]
		if level_id == "graal_bosslevel":
			_camera_rig.set_target(_player_node, 3.8, 2.65, false)
			_camera_rig.yaw = -0.68
			_camera_rig.pitch = -0.14
			_camera_rig.rotation = Vector3(_camera_rig.pitch, _camera_rig.yaw, 0.0)
		elif level_id == "cave":
			# Kinematisk 1:1 åpningsvinkel bak Pinky som rammer inn Kaptein Sabeltann, Langemann, Pelle, Pysa og grotte-tunnelen!
			_camera_rig.set_target(_player_node, 7.6, 2.05, false)
			_camera_rig.yaw = -0.34
			_camera_rig.pitch = -0.14
			_camera_rig.rotation = Vector3(_camera_rig.pitch, _camera_rig.yaw, 0.0)
		elif level_id == "abra":
			_camera_rig.set_target(_player_node, 6.4, 2.35, false)
			_camera_rig.yaw = -1.25
			_camera_rig.pitch = -0.15
			_camera_rig.rotation = Vector3(_camera_rig.pitch, _camera_rig.yaw, 0.0)
		else:
			_camera_rig.set_target(_player_node, 9.5, 2.4, false)
		if _camera_rig.spring_arm:
			if is_tight_indoor:
				_camera_rig.spring_arm.collision_mask = 0
			if _player_node:
				_camera_rig.spring_arm.add_excluded_object(_player_node.get_rid())
		# 7. Spawn NPC-er, fiender, originale 1:1 mynter, historie-objekter, portaler og 1:1 stemme-/historiemotor!
		_populate_entities(level_id, cfg, gp_data, spawn_pos, level_bounds)
		_add_biome_atmosphere(level_id, spawn_pos)

	# 8. Spill av oppskalert animert historie-filmsekvens ved overgangskapitler (cave og abra starter LIVE i 3D med stemmer!)
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

	if is_swim:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.08, 0.28, 0.40)
		env.ambient_light_energy = 0.42
	elif is_cave:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.24, 0.22, 0.28) if current_level_id == "cave" else cfg.get("ambient_color", Color(0.18, 0.24, 0.32))
		env.ambient_light_energy = 0.46 if current_level_id == "cave" else 0.38
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.72
		env.ambient_light_color = cfg.get("ambient_color", Color(0.36, 0.56, 0.86))
		env.ambient_light_energy = clampf(float(cfg.get("ambient_energy", 0.65)) * 0.58, 0.32, 0.44)

	# Moderne AAA animasjons-pipeline: ACES kinokontrast + dyp SSAO + kontrollert SSIL – null melkeaktig «fade»!
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02 if is_swim else (1.04 if current_level_id == "cave" else (1.00 if not is_cave else 0.98))
	env.ssao_enabled = GameState.ssao_enabled
	env.ssao_radius = 1.70
	env.ssao_intensity = 2.05
	env.ssao_power = 1.55
	env.ssao_detail = 0.72

	# Sanntids indirekte bounce-lys (dempet slik at dype skygger og skarpe PBR-teksturer bevares!)
	env.ssil_enabled = GameState.ssil_enabled
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.62

	env.glow_enabled = GameState.glow_enabled
	env.glow_normalized = true
	env.glow_intensity = 0.34 if is_swim else 0.36
	env.glow_bloom = 0.10 if is_swim else 0.12
	env.glow_hdr_threshold = 1.25

	env.fog_enabled = GameState.fog_enabled
	env.fog_light_color = cfg.get("fog_color", Color(0.62, 0.78, 0.94))
	if is_swim:
		# Dybde-tåke starter BAK Pinky (11.2m) slik at Pinky og forgrunnssteinene har NULL gråblå slør over seg!
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_depth_begin = 11.2
		env.fog_depth_end = 36.0
		env.fog_density = 0.48
		env.fog_sky_affect = 0.20
	else:
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_density = float(cfg.get("fog_density", 0.0011)) * (0.45 if current_level_id == "cave" else 0.68)
		env.fog_sky_affect = 0.08 if is_graal else (0.24 if is_cave else 0.10)

	# Diskret volumetrisk tåke for lysstråler uten å bleke teksturene i forgrunnen!
	if GameState.volumetric_fog_enabled and (is_cave or is_graal or is_swim):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0035 if is_swim else (0.0085 if current_level_id == "cave" else (0.015 if is_cave else 0.006))
		env.volumetric_fog_albedo = Color(0.14, 0.66, 0.84) if is_swim else (Color(0.24, 0.85, 0.64) if "end" in current_level_id else Color(0.42, 0.38, 0.56))
		env.volumetric_fog_emission = Color(0.01, 0.08, 0.14) if is_swim else (Color(0.03, 0.15, 0.11) if "end" in current_level_id else Color(0.02, 0.02, 0.04))
		env.volumetric_fog_emission_energy = 0.06 if is_swim else (0.22 if current_level_id == "cave" else (0.35 if is_cave else 0.20))
		env.volumetric_fog_anisotropy = 0.68
		env.volumetric_fog_length = 42.0 if is_swim else 55.0

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.18

	_env_node.environment = env
	_world_root.add_child(_env_node)

	# Hovedlys (skarp varm sol / sølvblått måneskinn / krystallklart undervannslys) med 4K skygger
	_sun_node = DirectionalLight3D.new()
	if is_swim:
		_sun_node.light_color = Color(0.80, 0.96, 1.0)
		_sun_node.light_energy = 2.05
	else:
		_sun_node.light_color = cfg.get("sun_color", Color(1.0, 0.90, 0.68))
		_sun_node.light_energy = float(cfg.get("sun_energy", 2.25)) * 1.08
	_sun_node.shadow_enabled = true
	_sun_node.shadow_blur = 1.6
	_sun_node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun_node.directional_shadow_max_distance = 220.0
	var sang: Vector3 = Vector3(-30.0, 18.0, 0.0) if is_swim else cfg.get("sun_angles", Vector3(-36.0, 36.0, 0.0))
	_sun_node.rotation_degrees = sang
	_world_root.add_child(_sun_node)

	# Dempet motsatt Pixar-fyllbelysning (bevarer dype skygger og 3D-dybde!)
	if not is_cave:
		var fill := DirectionalLight3D.new()
		fill.light_color = Color(1.0, 0.60, 0.26) if is_graal else (Color(0.24, 0.72, 0.90) if is_swim else Color(0.36, 0.62, 1.0))
		fill.light_energy = 0.24 if is_graal else (0.18 if is_swim else 0.26)
		fill.shadow_enabled = false
		fill.rotation_degrees = Vector3(-24.0, sang.y + 165.0, 0.0)
		_world_root.add_child(fill)


const LEVEL_GLB_FALLBACKS := {
	"swimming": "magakhan_beach",
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
			_level_geom = inst

			var first := true
			var min_v := Vector3.ZERO
			var max_v := Vector3.ZERO
			var lantern_count := 0
			var torch_positions: Array[Vector3] = []
			var lava_meshes: Array[MeshInstance3D] = []

			for mi in _find_all_meshes(inst):
				var nm := mi.name.to_lower()
				# Skjul gamle flate 2005 Shockwave-vannflater og 2005 skybokser/bakgrunnskupler!
				# Unntak: i grotten beholder vi det indre grottevannet (cavewater) og senker topwateroutside under sandstranden!
				if nm == "cavewater":
					var cw_mat := StandardMaterial3D.new()
					cw_mat.albedo_color = Color(0.03, 0.14, 0.20, 0.86)
					cw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					cw_mat.roughness = 0.24
					cw_mat.metallic = 0.12
					mi.material_override = cw_mat
					continue
				if nm == "topwateroutside":
					mi.position.y -= 0.62
					var ow_mat := StandardMaterial3D.new()
					ow_mat.albedo_color = Color(0.02, 0.14, 0.24, 0.90)
					ow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					ow_mat.roughness = 0.22
					ow_mat.metallic = 0.15
					mi.material_override = ow_mat
					continue
				if "water" in nm or "abrasea" in nm or nm.ends_with("sea") or nm.ends_with("sea2") or "background" in nm or "skybox" in nm:
					mi.visible = false
					continue
				# Skjul gamle billboard-røyk/tåke-kort og shop-UI-hjelpemesher (BEHOLD portal1..portal7 = ekte grottegeometri!)
				if "portalchoice" in nm or "foginfo" in nm or "lightsmoke" in nm or nm == "fog" or nm in ["shoplamp", "shopslingshot", "shopsword"]:
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
				# Originale grottefakler (mktorch1..39): behold fakkelholderen og gi ekte varmt fakkelskjær!
				if "mktorch" in nm or "mk_torch" in nm:
					var taabb: AABB = mi.global_transform * mi.get_aabb()
					var tpos := taabb.get_center() + Vector3(0.0, 0.45, 0.0)
					if torch_positions.size() < 16:
						var too_close := false
						for prev in torch_positions:
							if prev.distance_to(tpos) < 10.5:
								too_close = true
								break
						if not too_close:
							torch_positions.append(tpos)
							var tl := OmniLight3D.new()
							tl.position = tpos
							tl.light_color = Color(1.0, 0.62, 0.22)
							tl.light_energy = 4.6
							tl.omni_range = 19.0
							_world_root.add_child(tl)
					continue
				# Originale glødende lavabasseng (cavelava1, cavebigroomlava, cavelava2, endlava)
				if "lava" in nm:
					lava_meshes.append(mi)
					continue

				# 1:1 Gral-boss: Trekk ut originale GraalBoss-dragen, katapult og steinprosjektil for interaktiv bosskamp!
				if w3d_name == "graal_bosslevel" and nm == "graalboss":
					_graal_boss_mesh = mi.mesh
					mi.visible = false
					continue
				if w3d_name == "graal_bosslevel" and nm == "catapult":
					_catapult_mesh = mi.mesh
					mi.visible = false
					continue
				if w3d_name == "graal_bosslevel" and nm == "catapultrock":
					_catapult_rock_mesh = mi.mesh
					mi.visible = false
					continue

				# Når vi har et eksakt 1:1 høydekart (.hm) + 3D spline-vegger, skal IKKE ujevne hule-/steinmesher blokkere Pinky!
				var use_hm := (_heightmap != null and _heightmap.valid)
				var is_walkable_deck := ("deck" in nm or "plank" in nm or "bridge" in nm or "pier" in nm or "dock" in nm or "gangway" in nm or "stair" in nm or "castlefloor" in nm) and not ("cave" in nm or "portal" in nm or "rock" in nm or "cliff" in nm or "mountain" in nm or "terrain" in nm or "wall" in nm)
				if (not use_hm) or is_walkable_deck:
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
			if w3d_name == "graal_bosslevel":
				for mi2 in _find_all_meshes(inst):
					var nm2 := mi2.name.to_lower()
					if nm2 == "graalboss":
						_graal_boss_mat = mi2.material_override if mi2.material_override else mi2.get_active_material(0)
					elif nm2 == "catapult":
						_catapult_mat = mi2.material_override if mi2.material_override else mi2.get_active_material(0)

			# Gi lavabassengene ekte glødende vulkansk oransje-rød emisjon etter PBR-oppgradering!
			if not lava_meshes.is_empty():
				var lava_mat := StandardMaterial3D.new()
				lava_mat.albedo_color = Color(0.95, 0.28, 0.04)
				lava_mat.roughness = 0.35
				lava_mat.emission_enabled = true
				lava_mat.emission = Color(1.0, 0.34, 0.05)
				lava_mat.emission_energy_multiplier = 2.6
				for lmi in lava_meshes:
					lmi.material_override = lava_mat
					var laabb: AABB = lmi.global_transform * lmi.get_aabb()
					var ll := OmniLight3D.new()
					ll.position = laabb.get_center() + Vector3(0.0, 3.0, 0.0)
					ll.light_color = Color(1.0, 0.36, 0.08)
					ll.light_energy = 5.0
					ll.omni_range = 24.0
					_world_root.add_child(ll)

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
		# Naturlig varm-nøytral grottelykt over inngangen (fremhever Sabeltanns hvite sminke, hatt og farger!)
		var warm_torch := OmniLight3D.new()
		warm_torch.position = spawn_pos + Vector3(0.8, 4.4, -2.6)
		warm_torch.light_color = Color(1.0, 0.90, 0.78)
		warm_torch.light_energy = 3.2
		warm_torch.omni_range = 22.0
		_world_root.add_child(warm_torch)

		# Eterisk smaragdgrønt lys dypt inne i Grusomme Gabriels skattkammer
		var chamber_glow := OmniLight3D.new()
		chamber_glow.position = spawn_pos + Vector3(0.0, 5.5, -18.0)
		chamber_glow.light_color = Color(0.18, 1.0, 0.64) if is_ghost else Color(1.0, 0.74, 0.36)
		chamber_glow.light_energy = 7.5 if is_ghost else 4.0
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


func _make_hm_callable() -> Callable:
	return func(p: Vector3) -> float:
		if _heightmap and _heightmap.valid:
			return _heightmap.sample_y(p.x, p.z)
		return -9999.0


func _find_player_spawn(level_id: String, gp_data: Dictionary, bounds: AABB) -> Vector3:
	# 1:1 Gral-bosskampen skjer oppe på borggårdens flate sørlige brystvern ved Catapult_1 (Y = 21.48m)
	if level_id == "graal_bosslevel":
		var gy := _heightmap.sample_y(-6.8, 7.85) if (_heightmap and _heightmap.valid) else 21.48
		return Vector3(-6.8, (gy if gy > -5000.0 else 21.48) + 0.05, 7.85)

	var nodes: Array = gp_data.get("nodes", [])
	for n in nodes:
		var nm := str(n.get("name", "")).to_lower()
		if nm == "character_pinky" or nm == "character_treasureseeker":
			var gp: Array = n.get("godot_pos", [0, 0, 0])
			var px := float(gp[0]) * WORLD_SCALE
			var pz := float(gp[2]) * WORLD_SCALE
			if _heightmap and _heightmap.valid:
				var hy := _heightmap.sample_y(px, pz)
				if hy > -5000.0:
					return Vector3(px, hy + 0.05, pz)
			var p := Vector3(px, float(gp[1]) * WORLD_SCALE + 2.0, pz)
			var hit := _raycast_ground(p, bounds)
			if hit.y > -5000.0:
				return hit + Vector3(0.0, 0.05, 0.0)
	var center := bounds.get_center()
	return _snap_to_surface(Vector3(center.x, bounds.position.y + bounds.size.y + 4.0, center.z), bounds) + Vector3(0.0, 0.05, 0.0)


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

	# Plasser 2 originale patruljerende og senkbare fiendeskip fra world_map.glb ute på havet!
	if ResourceLoader.exists("res://assets/levels/world_map.glb"):
		var sc := load("res://assets/levels/world_map.glb") as PackedScene
		if sc:
			for sp_info in [
				[Vector3(17.5, 0.0, -2.5), -0.6],
				[Vector3(-15.5, 0.0, -5.5), 1.1],
			]:
				var ship_vis := sc.instantiate()
				ship_vis.scale = Vector3.ONE * 0.42
				for mi in _find_all_meshes(ship_vis):
					var nm := mi.name.to_lower()
					mi.visible = (nm in ["enemyship", "enemyrailing"])
				VisualEnhancer.enhance_world_node(ship_vis, "abra", 0.0)
				VisualEnhancer.attach_ship_wake(ship_vis, 1.8)
				var eship: EnemyShip = ENEMY_SHIP_SCRIPT.new()
				eship.name = "EnemyShip"
				_world_root.add_child(eship)
				eship.setup_ship(ship_vis, sp_info[0], sp_info[1])


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
	if _heightmap and _heightmap.valid:
		var hy := _heightmap.sample_y(pos.x, pos.z)
		if hy > -5000.0:
			return Vector3(pos.x, hy, pos.z)
	var space := get_world_3d().direct_space_state
	if space:
		var from := Vector3(pos.x, bounds.position.y + bounds.size.y + 20.0, pos.z)
		var to := Vector3(pos.x, bounds.position.y - 30.0, pos.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		if hit and hit.has("position"):
			return hit["position"]
	return Vector3(pos.x, pos.y, pos.z)


func _spawn_pinky(pos: Vector3, is_swim: bool) -> CharacterBody3D:
	var pinky: PinkyController = PINKY_SCRIPT.new()
	pinky.name = "Pinky"
	pinky.is_swimming = is_swim
	pinky.position = pos
	pinky.heightmap_sampler = _make_hm_callable()
	# I Gral-bosskampen vender Pinky fremover mot borggården, katapultene og dragen; i grotten mot Kaptein Sabeltann!
	if current_level_id == "graal_bosslevel":
		pinky.rotation_degrees.y = -38.0
	elif current_level_id == "cave":
		pinky.rotation_degrees.y = -20.0
	pinky.camera_rig = _camera_rig

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.25
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


func _find_node_pos(nodes: Array, target_lower: String) -> Dictionary:
	for n in nodes:
		if str(n.get("name", "")).to_lower() == target_lower:
			var gp: Array = n.get("godot_pos", [0, 0, 0])
			return {"found": true, "pos": Vector3(float(gp[0]) * WORLD_SCALE, float(gp[1]) * WORLD_SCALE, float(gp[2]) * WORLD_SCALE)}
	return {"found": false}


func _populate_entities(level_id: String, cfg: Dictionary, gp_data: Dictionary, spawn_pos: Vector3, bounds: AABB) -> void:
	# 1:1 Greven av Gral på dragen (selve GraalBoss-dragemodellen fra graal_bosslevel.glb svever over borgen)
	if level_id == "graal_bosslevel":
		GameState.emit_signal("boss_health_changed", "Greven av Gral", 260.0, 260.0)

	var hm_cb := _make_hm_callable()
	var nodes: Array = gp_data.get("nodes", [])
	var spawned_chars := 0
	var occupied_positions: Array[Vector3] = [spawn_pos]
	var has_original_coins := false

	for n in nodes:
		var nm := str(n.get("name", "")).to_lower()
		if nm.begins_with("walkoverpickup_coppercoin") or nm.begins_with("walkoverpickup_goldcoin"):
			has_original_coins = true
			continue
		if not nm.begins_with("character_"):
			continue
		var key := nm.substr(10)
		if key == "pinky" or key == "treasureseeker":
			continue

		var gp: Array = n.get("godot_pos", [0, 0, 0])
		var pos := _snap_to_surface(
			Vector3(float(gp[0]) * WORLD_SCALE, float(gp[1]) * WORLD_SCALE, float(gp[2]) * WORLD_SCALE),
			bounds
		)

		var matched_role := _match_character_role(key)
		if matched_role.is_empty():
			continue

		spawned_chars += 1
		if spawned_chars > 24:
			continue

		occupied_positions.append(pos)
		if matched_role["role"] == "npc":
			var npc: NpcActor = NPC_SCRIPT.new()
			npc.npc_id = key
			npc.display_name = matched_role["name"]
			npc.model_resource = matched_role["model"]
			npc.reward_coins = int(matched_role.get("coins", 5))
			npc.heightmap_sampler = hm_cb
			npc.position = pos
			_world_root.add_child(npc)
			if pos.distance_to(spawn_pos) < 18.0:
				npc.face_toward(spawn_pos)
			_actors_by_name[key] = npc
			var base_k := str(matched_role["model"])
			if not _actors_by_name.has(base_k):
				_actors_by_name[base_k] = npc
			if key.begins_with("pysa"):
				_actors_by_name["pysa"] = npc
		else:
			var enemy: EnemyActor = ENEMY_SCRIPT.new()
			enemy.enemy_name = matched_role["name"]
			enemy.model_resource = matched_role["model"]
			enemy.max_hp = float(matched_role.get("hp", 60.0))
			enemy.attack_damage = float(matched_role.get("dmg", 12.0))
			enemy.is_boss = (matched_role["role"] == "boss")
			enemy.coin_drop = 25 if enemy.is_boss else 5
			enemy.heightmap_sampler = hm_cb
			enemy.position = pos
			_world_root.add_child(enemy)
			_actors_by_name[key] = enemy

	# 1:1 originale portaler på eksakte original-koordinater (ingen falsk portal foran skipets rekkverk eller rett ved grottestart!)
	var next_id := str(cfg.get("next_level", "world_map"))
	var next_info := LevelCatalog.get_level(next_id)
	var portal: PortalTrigger = PORTAL_SCRIPT.new()
	portal.target_level_id = next_id
	var portal_pos := Vector3.ZERO
	var use_custom_portal := false

	if level_id == "cave":
		# I grotten fortsetter historien ved Grusomme Gabriels kiste innerst i skattkammeret (areatrigger_chest)
		var ch := _find_node_pos(nodes, "areatrigger_chest")
		portal.portal_label = "Åpne Grusomme Gabriels kiste → Abra Havn"
		portal_pos = _snap_to_surface(ch["pos"] if ch["found"] else Vector3(45.76, -6.5, -98.01), bounds)
		use_custom_portal = true
	elif level_id == "abra":
		# Eksakt original seilingsportal på torget ved Miriam (actionable_portal) – IKKE bak skipsrekkverket!
		var ap := _find_node_pos(nodes, "actionable_portal")
		portal.portal_label = "Sett seil til De Syv Hav"
		portal_pos = _snap_to_surface(ap["pos"] if ap["found"] else Vector3(-18.81, 0.0, -4.21), bounds)
		use_custom_portal = true
	elif level_id == "graal_mountain":
		var aw := _find_node_pos(nodes, "actionable_well")
		portal.portal_label = "Hopp i brønnen → Undervannstunnel (2D)"
		portal_pos = _snap_to_surface(aw["pos"] if aw["found"] else Vector3(54.06, 0.0, -134.26), bounds)
		use_custom_portal = true
		# Original retur-portal ved stranden tilbake til Den Sorte Dame
		var ret := _find_node_pos(nodes, "actionable_gotoworldmap")
		if ret["found"]:
			var rp: PortalTrigger = PORTAL_SCRIPT.new()
			rp.target_level_id = "world_map"
			rp.portal_label = "Tilbake til Den Sorte Dame"
			rp.position = _snap_to_surface(ret["pos"], bounds) + Vector3(0.0, 0.15, 0.0)
			_world_root.add_child(rp)
	elif level_id == "graal_bosslevel":
		portal.portal_label = "Seil videre → Fata Morgana!"
		var gy := _heightmap.sample_y(-0.8, -5.0) if (_heightmap and _heightmap.valid) else 21.48
		portal_pos = Vector3(-0.8, (gy if gy > -5000.0 else 21.48), -5.0)
		use_custom_portal = false # Aktiveres først når Greven av Gral er beseiret!
	else:
		portal.portal_label = "Reis til " + str(next_info.get("title", next_id))
		var portal_raw := spawn_pos + Vector3(6.5, 0.0, -5.5)
		portal_pos = _snap_to_surface(portal_raw, bounds)

	portal.position = portal_pos + Vector3(0.0, 0.15, 0.0)
	if level_id == "graal_bosslevel":
		_spawn_graal_boss_arena(gp_data, bounds, spawn_pos, portal)
	else:
		_world_root.add_child(portal)
		occupied_positions.append(portal.position)

	# 1:1 originale undervanns-brønner (2D side-scrolling dykk!) i Fata Morgana og Maga Khans fangehull
	if level_id == "fatamorgana_city":
		var well_p: PortalTrigger = PORTAL_SCRIPT.new()
		well_p.target_level_id = "fatamorgana_underwater"
		well_p.portal_label = "Dykk i brønnen etter kaken (2D)"
		var wn := _find_node_pos(nodes, "actionable_well")
		var wbase: Vector3 = wn["pos"] if wn["found"] else spawn_pos + Vector3(-5.5, 0.0, -4.5)
		well_p.position = _snap_to_surface(wbase, bounds) + Vector3(0.0, 0.15, 0.0)
		_world_root.add_child(well_p)
	elif level_id == "magakhan_dungeon":
		var key_p: PortalTrigger = PORTAL_SCRIPT.new()
		key_p.target_level_id = "magakhan_dungeon_underwater"
		key_p.portal_label = "Dykk etter fangehullsnøkkelen (2D)"
		var kn := _find_node_pos(nodes, "actionable_well")
		var kbase: Vector3 = kn["pos"] if kn["found"] else spawn_pos + Vector3(-5.5, 0.0, -4.5)
		key_p.position = _snap_to_surface(kbase, bounds) + Vector3(0.0, 0.15, 0.0)
		_world_root.add_child(key_p)

	# Spawn kun reserve-mynter/tønner på brett som IKKE allerede har originale walkoverpickup-mynter (unngår sirkel-rot på cave og abra!)
	var min_dry_y: float = float(cfg.get("water_y", -99.0)) + 0.45 if bool(cfg.get("has_water", false)) else -999.0
	if not has_original_coins and level_id != "cave":
		for i in range(10):
			var ang := (float(i) / 10.0) * TAU + 0.2
			var rad := 6.0 + float(i % 3) * 3.5
			var cand := spawn_pos + Vector3(cos(ang) * rad, 3.0, sin(ang) * rad)
			var info := _raycast_ground_info(cand, bounds)
			if info.has("position"):
				var hit_pos: Vector3 = info["position"]
				var hit_nrm: Vector3 = info["normal"]
				if hit_pos.y > min_dry_y and hit_nrm.y > 0.86 and absf(hit_pos.y - spawn_pos.y) < 2.6:
					var too_close := false
					for occ in occupied_positions:
						if hit_pos.distance_to(occ) < 2.8:
							too_close = true
							break
					if too_close:
						continue
					var coin: CollectibleCoin = COIN_SCRIPT.new()
					coin.position = hit_pos + Vector3(0.0, 0.60, 0.0)
					_world_root.add_child(coin)

	if level_id != "graal_bosslevel" and level_id != "cave" and level_id != "abra":
		for i in range(4):
			var ang := (float(i) / 4.0) * TAU + 0.5
			var cand := spawn_pos + Vector3(cos(ang) * 7.5, 3.0, sin(ang) * 7.5)
			var info := _raycast_ground_info(cand, bounds)
			if info.has("position"):
				var hit_pos: Vector3 = info["position"]
				var hit_nrm: Vector3 = info["normal"]
				if hit_pos.y > min_dry_y and hit_nrm.y > 0.90 and absf(hit_pos.y - spawn_pos.y) < 2.2:
					var too_close := false
					for occ in occupied_positions:
						if hit_pos.distance_to(occ) < 3.0:
							too_close = true
							break
					if too_close:
						continue
					var barrel: BreakableBarrel = BARREL_SCRIPT.new()
					barrel.position = hit_pos
					_world_root.add_child(barrel)

	# 8. Start 1:1 original historie-, samtale-, spline- og stemmemotor fra gameplay/<level_id>.json!
	_story_engine = STORY_SCRIPT.new()
	_story_engine.name = "StoryScriptEngine"
	_world_root.add_child(_story_engine)
	_story_engine.setup(level_id, gp_data, _world_root, _level_geom, _player_node, _camera_rig, _heightmap, _actors_by_name, _colliders_by_name)


func _build_3d_spline_walls(gp_data: Dictionary, spawn_pos: Vector3) -> void:
	# Konverter originalspillets 2D XZ-splines (Line*, Shape*, Circle*, *_collision) til glatte loddrette vegger!
	var shared_body := StaticBody3D.new()
	shared_body.name = "SplineCollision3D"
	shared_body.collision_layer = 1
	shared_body.collision_mask = 0
	_world_root.add_child(shared_body)

	var re_vec := RegEx.new()
	re_vec.compile("vector\\(([\\-\\d.]+),([\\-\\d.]+),([\\-\\d.]+)\\)")
	var re_rad := RegEx.new()
	re_rad.compile("#radius:([\\d.]+)")

	for n in gp_data.get("nodes", []):
		var low := str(n.get("name", "")).to_lower()
		var ud := str(n.get("userdata", ""))
		if not ("splinedata" in ud):
			continue
		if "validposition" in low or "3dsound" in low or "particle" in low or "platform_collision" in low:
			continue
		if low.begins_with("jump") or low.begins_with("ladder") or low.begins_with("areatrigger"):
			continue
		var is_wall_node := low.begins_with("line") or low.begins_with("shape") or low.begins_with("circle") or ("collision" in low)
		if not is_wall_node:
			continue

		var is_named_toggle := ("collision" in low)
		var target_body: StaticBody3D = shared_body
		if is_named_toggle:
			target_body = StaticBody3D.new()
			target_body.name = "Col_" + str(n.get("name", ""))
			target_body.collision_layer = 1
			target_body.collision_mask = 0
			_world_root.add_child(target_body)
			_colliders_by_name[low] = target_body
			if low.ends_with("_collision"):
				_colliders_by_name[low.substr(0, low.length() - 10)] = target_body

		if "#linearSplines" in ud:
			var pts: Array[Vector2] = []
			for m in re_vec.search_all(ud):
				pts.append(Vector2(float(m.get_string(1)) * WORLD_SCALE, -float(m.get_string(2)) * WORLD_SCALE))
			if "#closed:1" in ud and pts.size() >= 3:
				pts.append(pts[0])
			for i in range(pts.size() - 1):
				var a := pts[i]
				var b := pts[i + 1]
				var seg := b - a
				var seg_len := seg.length()
				if seg_len < 0.08:
					continue
				var mid := (a + b) * 0.5
				var hy := _heightmap.sample_y(mid.x, mid.y) if (_heightmap and _heightmap.valid) else spawn_pos.y
				if hy < -5000.0:
					hy = spawn_pos.y
				var cs := CollisionShape3D.new()
				var bx := BoxShape3D.new()
				bx.size = Vector3(seg_len + 0.06, 16.0, 0.08)
				cs.shape = bx
				cs.position = Vector3(mid.x, hy + 5.5, mid.y)
				cs.rotation.y = -atan2(seg.y, seg.x)
				target_body.add_child(cs)
		elif "#type:#circle" in ud:
			var rm := re_rad.search(ud)
			var vm := re_vec.search(ud)
			if rm and vm:
				var rad := maxf(float(rm.get_string(1)) * WORLD_SCALE * 0.78, 0.22)
				var cx := float(vm.get_string(1)) * WORLD_SCALE
				var cz := -float(vm.get_string(2)) * WORLD_SCALE
				var hy := _heightmap.sample_y(cx, cz) if (_heightmap and _heightmap.valid) else spawn_pos.y
				if hy < -5000.0:
					hy = spawn_pos.y
				var cs := CollisionShape3D.new()
				var cyl := CylinderShape3D.new()
				cyl.radius = rad
				cyl.height = 16.0
				cs.shape = cyl
				cs.position = Vector3(cx, hy + 5.5, cz)
				target_body.add_child(cs)


func _spawn_graal_boss_arena(gp_data: Dictionary, bounds: AABB, _spawn_pos: Vector3, exit_portal: PortalTrigger) -> void:
	# 1. Flygende interaktiv Greven av Gral på drage over borggården
	var boss: GraalBossController = GRAAL_BOSS_SCRIPT.new()
	boss.name = "GraalBossController"
	var dragon_vis := Node3D.new()
	if _graal_boss_mesh:
		var dmi := MeshInstance3D.new()
		dmi.mesh = _graal_boss_mesh
		if _graal_boss_mat:
			dmi.material_override = _graal_boss_mat
		dmi.scale = Vector3.ONE * 1.32
		dragon_vis.add_child(dmi)
	else:
		var dmi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.8
		sm.height = 3.2
		dmi.mesh = sm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.55, 0.14, 0.10)
		dm.emission_enabled = true
		dm.emission = Color(0.85, 0.25, 0.05)
		dmi.material_override = dm
		dragon_vis.add_child(dmi)
	_world_root.add_child(boss)
	boss.setup_visual(dragon_vis, _player_node)
	_graal_boss_ctrl = boss

	boss.boss_defeated.connect(func():
		if is_instance_valid(exit_portal) and not exit_portal.is_inside_tree():
			_world_root.add_child(exit_portal)
	)

	# 2. Alle 4 interaktive hjørne-katapulter på brystvernet (bruk med sverdhugg eller [E]!)
	var cat_positions: Array[Vector3] = []
	for cname in ["catapult_1", "catapult_2", "catapult_3", "catapult_4"]:
		var res := _find_node_pos(gp_data.get("nodes", []), cname)
		if res["found"]:
			cat_positions.append(_snap_to_surface(res["pos"], bounds))
	if cat_positions.is_empty():
		for fp in [
			Vector3(-9.45, 21.41, 5.92),
			Vector3(7.60, 21.41, 6.04),
			Vector3(7.74, 21.41, -10.30),
			Vector3(-9.32, 21.41, -10.59),
		]:
			cat_positions.append(_snap_to_surface(fp, bounds))

	var center_arena := Vector3(0.3, 21.5, -1.9)
	for i in range(cat_positions.size()):
		var cpos: Vector3 = cat_positions[i]
		var cat := StoryInteractable.new()
		cat.name = "Catapult_%d" % (i + 1)
		cat.position = cpos
		cat.is_blocking = false
		cat.add_to_group("interactable")
		cat.add_to_group("hittable")
		cat.prompt_text = "[E] / [Slå] Avfyr katapult!"

		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 2.0
		cs.shape = sph
		cat.add_child(cs)

		var cvis := Node3D.new()
		if _catapult_mesh:
			var cmi := MeshInstance3D.new()
			cmi.mesh = _catapult_mesh
			if _catapult_mat:
				cmi.material_override = _catapult_mat
			cvis.add_child(cmi)
		else:
			var cmi := MeshInstance3D.new()
			var bx := BoxMesh.new()
			bx.size = Vector3(1.6, 1.2, 2.2)
			cmi.mesh = bx
			cmi.position.y = 0.6
			cvis.add_child(cmi)
		var look_dir := Vector3(center_arena.x - cpos.x, 0.0, center_arena.z - cpos.z)
		if look_dir.length() > 0.1:
			cvis.rotation.y = atan2(-look_dir.x, -look_dir.z)
		cat.add_child(cvis)

		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.35
		tm.outer_radius = 1.65
		ring.mesh = tm
		ring.position.y = 0.08
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(1.0, 0.78, 0.22)
		rmat.emission_enabled = true
		rmat.emission = Color(1.0, 0.68, 0.12)
		rmat.emission_energy_multiplier = 2.0
		ring.material_override = rmat
		cat.add_child(ring)

		var state := {"ready_ms": 0}
		var fire_cb := func(_p = null):
			var now := Time.get_ticks_msec()
			if now < int(state["ready_ms"]):
				return
			if not is_instance_valid(_graal_boss_ctrl):
				return
			state["ready_ms"] = now + 2600
			AudioManager.play_sfx("explosion", 0.75)

			var tw_cat := cat.create_tween()
			tw_cat.tween_property(cvis, "scale", Vector3(1.12, 0.85, 1.12), 0.12)
			tw_cat.tween_property(cvis, "scale", Vector3.ONE, 0.28)

			var boulder := MeshInstance3D.new()
			if _catapult_rock_mesh:
				boulder.mesh = _catapult_rock_mesh
			else:
				var bsph := SphereMesh.new()
				bsph.radius = 0.45
				bsph.height = 0.9
				boulder.mesh = bsph
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.85, 0.48, 0.15)
			bmat.emission_enabled = true
			bmat.emission = Color(1.0, 0.44, 0.08)
			bmat.emission_energy_multiplier = 2.8
			boulder.material_override = bmat
			_world_root.add_child(boulder)
			boulder.global_position = cpos + Vector3(0.0, 2.2, 0.0)

			var start_p := boulder.global_position
			var tw_b := _world_root.create_tween()
			tw_b.tween_method(func(t: float):
				if not is_instance_valid(boulder) or not is_instance_valid(_graal_boss_ctrl):
					return
				var mid_p := start_p.lerp(_graal_boss_ctrl.global_position, t)
				mid_p.y += sin(t * PI) * 4.5
				boulder.global_position = mid_p
			, 0.0, 1.0, 0.58)
			tw_b.tween_callback(func():
				if is_instance_valid(boulder):
					boulder.queue_free()
				if is_instance_valid(_graal_boss_ctrl):
					_graal_boss_ctrl.hit_by_catapult(65.0)
			)

		cat.on_interact_cb = fire_cb
		cat.on_hit_cb = func(): fire_cb.call(null)
		_world_root.add_child(cat)


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
	bg_mat.albedo_color = Color(0.012, 0.11, 0.20)
	bg.material_override = bg_mat
	_world_root.add_child(bg)

	# Ekte volumetriske undervanns-lyskjegler (SpotLight3D) som skinner ned brønnsjaktene uten harde kanter!
	for rx in [-12.5, -0.4, 11.0]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(rx, 13.0, 1.2)
		sl.rotation_degrees = Vector3(-86.0, 0.0, 0.0)
		sl.light_color = Color(0.42, 0.94, 1.0)
		sl.light_energy = 7.2
		sl.light_volumetric_fog_energy = 3.2
		sl.spot_range = 24.0
		sl.spot_angle = 26.0
		sl.spot_attenuation = 0.72
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
