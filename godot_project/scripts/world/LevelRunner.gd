extends Node3D
class_name LevelRunner
## Laster hvert nivå i 100% original rekkefølge med moderne AAA animasjonsspill-grafikk (Godot 4 Forward+,
## AgX, SSAO, SSIL, volumetrisk tåke, triplanar PBR-mikrodetalj, turkis skumhav og animerte historie-sekvenser).

const PINKY_SCRIPT := preload("res://scripts/player/PinkyController.gd")
const BOAT_SCRIPT := preload("res://scripts/player/BoatController.gd")
const CAMERA_SCRIPT := preload("res://scripts/player/FollowCamera.gd")
const NPC_SCRIPT := preload("res://scripts/world/NpcActor.gd")
const ENEMY_SCRIPT := preload("res://scripts/world/EnemyActor.gd")
const PORTAL_SCRIPT := preload("res://scripts/world/PortalTrigger.gd")
const COIN_SCRIPT := preload("res://scripts/world/CollectibleCoin.gd")
const BARREL_SCRIPT := preload("res://scripts/world/BreakableBarrel.gd")
const CUTSCENE_SCRIPT := preload("res://scripts/ui/CutscenePlayer.gd")
const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")

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
	else:
		# 2. Last original HD .glb nivå-geometri med automatisk kollisjon og AAA PBR-oppgradering
		level_bounds = _load_level_geometry(str(cfg.get("w3d", level_id)), water_y)
		await get_tree().physics_frame
		# 3. Moderne Sea-of-Thieves turkis hav med ekte kystskum og kaustikk
		if bool(cfg.get("has_water", false)):
			_spawn_modern_ocean(water_y, level_bounds, false)

	# 4. Les originale gameplay-data (spawns, NPC-er, fiender, portaler)
	var gp_data := _read_gameplay_json(level_id)

	# 5. Opprett kamera-rigg
	_camera_rig = _create_camera_rig()
	_world_root.add_child(_camera_rig)

	# 6. Spawn spiller (Pinky eller Den Sorte Dame på verdenskartet)
	if mode == "boat":
		_player_node = _spawn_boat(Vector3(0.0, 0.0, 8.0))
		_camera_rig.set_target(_player_node, 74.0, 2.0, true)
	else:
		var spawn_pos := _find_player_spawn(level_id, gp_data, level_bounds)
		_player_node = _spawn_pinky(spawn_pos, mode == "swimming")
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

	env.background_mode = Environment.BG_SKY
	env.sky = VisualEnhancer.create_biome_sky(current_level_id, cfg)

	if is_cave:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = cfg.get("ambient_color", Color(0.10, 0.28, 0.24))
		env.ambient_light_energy = float(cfg.get("ambient_energy", 0.55))
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.78
		env.ambient_light_color = cfg.get("ambient_color", Color(0.36, 0.56, 0.86))
		env.ambient_light_energy = float(cfg.get("ambient_energy", 0.68))

	# Moderne AAA animasjons-pipeline: AgX tonemapping + SSAO + SSIL indirekte lys + Glow + Volumetrisk tåke!
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.10 if not is_cave else 1.05
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
	env.glow_intensity = 0.42
	env.glow_bloom = 0.16
	env.glow_hdr_threshold = 1.18

	env.fog_enabled = GameState.fog_enabled
	env.fog_light_color = cfg.get("fog_color", Color(0.62, 0.78, 0.94))
	env.fog_density = float(cfg.get("fog_density", 0.0011))
	env.fog_sky_affect = 0.08 if is_graal else (0.28 if is_cave else 0.14)

	# Volumetrisk tåke for magisk dybde og lysstråler i grottene og på Gral-borgen!
	if GameState.volumetric_fog_enabled and (is_cave or is_graal):
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.022 if is_cave else 0.008
		env.volumetric_fog_albedo = Color(0.24, 0.85, 0.64) if "end" in current_level_id else Color(0.38, 0.48, 0.72)
		env.volumetric_fog_emission = Color(0.04, 0.18, 0.13) if "end" in current_level_id else Color(0.03, 0.04, 0.08)
		env.volumetric_fog_emission_energy = 0.45 if is_cave else 0.25
		env.volumetric_fog_anisotropy = 0.62
		env.volumetric_fog_length = 55.0

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

	# Gral-borgen: 4 brennende smijerns-fakkelfat langs brystvernet + drageglør!
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
	# 1:1 Gral-bosskampen skjer oppe på borggårdens brystvern (Y = 21.41m, Z = -12.4)
	if level_id == "graal_bosslevel":
		return Vector3(-3.5, 21.8, -12.4)

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
	# Moderne animasjonsspill-øyer med håndlagde palmer, sjørøverlandsby, Gral-borg, arabiske kupler og laguner!
	var active_story_id := GameState.get_active_story_island()
	var islands := [
		{"name": "Abra Havn", "id": "abra", "pos": Vector3(-34.0, 0.0, 22.0), "r": 14.0, "seed": 11, "theme": "harbor"},
		{"name": "Gral", "id": "graal_mountain", "pos": Vector3(-28.0, 0.0, -25.0), "r": 15.0, "seed": 23, "theme": "castle"},
		{"name": "Fata Morgana", "id": "fatamorgana_city", "pos": Vector3(34.0, 0.0, -21.0), "r": 14.5, "seed": 37, "theme": "desert"},
		{"name": "Maga Khans øy", "id": "magakhan_beach", "pos": Vector3(40.0, 0.0, 22.0), "r": 15.5, "seed": 53, "theme": "jungle"},
		{"name": "Skattejakt-øya", "id": "treasurehunt", "pos": Vector3(4.0, 0.0, -40.0), "r": 11.5, "seed": 71, "theme": "palm"},
	]

	var micro_noise := FastNoiseLite.new()
	micro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	micro_noise.frequency = 0.09
	micro_noise.fractal_octaves = 5
	var normal_tex := NoiseTexture2D.new()
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 6.0
	normal_tex.noise = micro_noise

	for isl in islands:
		var root := Node3D.new()
		root.position = isl["pos"]
		_world_root.add_child(root)

		var r: float = isl["r"]
		var theme: String = isl["theme"]
		var isl_id: String = str(isl["id"])
		var is_active := (isl_id == active_story_id)
		var unlocked := GameState.is_island_unlocked(isl_id)

		var terrain := _make_stylized_island_mesh(r, int(isl["seed"]), theme, normal_tex)
		root.add_child(terrain)

		# Dekorer øya med palmer, hus, borg, palass eller jungeltempel!
		VisualEnhancer.decorate_world_map_island(root, r, theme, int(isl["seed"]), is_active)

		# Navneskilt over øya
		var lbl := Label3D.new()
		lbl.text = str(isl["name"]) + (" ★" if is_active else ("" if unlocked else " (Låst)"))
		lbl.position = Vector3(0.0, 12.2, 0.0)
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
		portal.position = (isl["pos"] as Vector3) + Vector3(0.0, 0.25, r * 0.92 + 2.8)
		_world_root.add_child(portal)

	# Plasser 2 originale fiendeskip fra world_map.glb ute på havet med skummende kjølvann!
	if ResourceLoader.exists("res://assets/levels/world_map.glb"):
		var sc := load("res://assets/levels/world_map.glb") as PackedScene
		if sc:
			for sp_info in [
				[Vector3(19.0, 0.0, -4.0), -0.6],
				[Vector3(-17.0, 0.0, -9.0), 1.1],
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


func _make_stylized_island_mesh(radius: float, seed_val: int, theme: String, normal_tex: Texture2D) -> MeshInstance3D:
	var n_shape := FastNoiseLite.new()
	n_shape.seed = seed_val
	n_shape.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_shape.frequency = 0.085
	n_shape.fractal_octaves = 5

	var n_detail := FastNoiseLite.new()
	n_detail.seed = seed_val + 99
	n_detail.noise_type = FastNoiseLite.TYPE_CELLULAR
	n_detail.frequency = 0.22

	# Sirkulært polarrutenett: null firkantede undervannskanter og brede frodige øyer der alle palmer står trygt på land!
	var rings := 28
	var segs := 56
	var max_r := radius * 1.55
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_verts: Array = []
	var ring_cols: Array = []
	var ring_uvs: Array = []

	for ri in range(rings + 1):
		var rt := float(ri) / float(rings)
		var r_cur := rt * max_r
		var rv: Array[Vector3] = []
		var rc: Array[Color] = []
		var ru: Array[Vector2] = []
		for si in range(segs + 1):
			var ang := (float(si) / float(segs)) * TAU
			var fx := cos(ang) * r_cur
			var fz := sin(ang) * r_cur
			var coast_warp := n_shape.get_noise_2d(fx * 0.65, fz * 0.65) * 0.24
			var nd := (r_cur / radius) + coast_warp * clampf(rt * 2.0, 0.0, 1.0)
			var ridge := absf(n_shape.get_noise_2d(fx * 1.3, fz * 1.3)) * 0.65 + (0.5 + 0.5 * n_detail.get_noise_2d(fx, fz)) * 0.35

			var peak := 9.2 if theme == "castle" else (6.0 if theme == "desert" else 7.6)
			var h := -11.5
			if nd < 0.96:
				# Bred, frodig tørr øy over havflaten
				var land_t := clampf(1.0 - nd / 0.96, 0.0, 1.0)
				h = 0.15 + pow(land_t, 0.78) * peak * (0.68 + 0.46 * ridge)
			elif nd < 1.48:
				# Myk sandbanke ned fra kysten (0.15m) til under havbunnen (-11.5m)
				var slope_t := clampf((nd - 0.96) / 0.52, 0.0, 1.0)
				h = lerpf(0.15, -11.5, slope_t * slope_t * (3.0 - 2.0 * slope_t))

			# Sørg for at aller ytterste ring alltid ligger trygt under havbunnen (-10.5m)
			if ri == rings:
				h = -11.8

			var c := Color(0.04, 0.14, 0.22)
			if h >= -2.5 and h < 0.12:
				c = Color(0.56, 0.54, 0.36) if theme != "castle" else Color(0.14, 0.16, 0.22)
			elif h >= 0.12 and h < 1.25:
				c = Color(0.90, 0.76, 0.46) if theme != "castle" else Color(0.22, 0.20, 0.26)
			elif h >= 1.25 and h < 4.5:
				match theme:
					"desert": c = Color(0.86, 0.66, 0.34)
					"castle": c = Color(0.24, 0.22, 0.30)
					"jungle": c = Color(0.12, 0.48, 0.16)
					_: c = Color(0.20, 0.52, 0.20)
			elif h >= 4.5:
				match theme:
					"desert": c = Color(0.74, 0.54, 0.28)
					"castle": c = Color(0.32, 0.30, 0.38)
					_: c = Color(0.30, 0.36, 0.26)
			var tint := 0.88 + 0.24 * (0.5 + 0.5 * n_shape.get_noise_2d(fx * 2.2, fz * 2.2))
			c = Color(c.r * tint, c.g * tint, c.b * tint, 1.0)

			rv.append(Vector3(fx, h, fz))
			rc.append(c)
			ru.append(Vector2(fx / max_r * 3.0, fz / max_r * 3.0))
		ring_verts.append(rv)
		ring_cols.append(rc)
		ring_uvs.append(ru)

	for ri in range(rings):
		for si in range(segs):
			var v00: Vector3 = ring_verts[ri][si]
			var v10: Vector3 = ring_verts[ri + 1][si]
			var v01: Vector3 = ring_verts[ri][si + 1]
			var v11: Vector3 = ring_verts[ri + 1][si + 1]
			var c00: Color = ring_cols[ri][si]
			var c10: Color = ring_cols[ri + 1][si]
			var c01: Color = ring_cols[ri][si + 1]
			var c11: Color = ring_cols[ri + 1][si + 1]
			var u00: Vector2 = ring_uvs[ri][si]
			var u10: Vector2 = ring_uvs[ri + 1][si]
			var u01: Vector2 = ring_uvs[ri][si + 1]
			var u11: Vector2 = ring_uvs[ri + 1][si + 1]
			for tri in [
				[v00, c00, u00], [v10, c10, u10], [v11, c11, u11],
				[v00, c00, u00], [v11, c11, u11], [v01, c01, u01],
			]:
				st.set_color(tri[1])
				st.set_uv(tri[2])
				st.add_vertex(tri[0])

	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.roughness = 0.84
	mat.metallic = 0.02
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.normal_scale = 0.78
	mi.material_override = mat
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
	portal.portal_label = "Reis til " + str(next_info.get("title", next_id))
	var portal_raw := spawn_pos + Vector3(6.5, 2.0, -5.5)
	if level_id == "graal_bosslevel":
		portal_raw = Vector3(-6.2, 26.5, -5.5)
	var phit := _raycast_ground(portal_raw, bounds)
	portal.position = (phit + Vector3(0.0, 0.25, 0.0)) if phit.y > -5000.0 else spawn_pos + Vector3(6.0, 0.25, -5.0)
	_world_root.add_child(portal)

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
