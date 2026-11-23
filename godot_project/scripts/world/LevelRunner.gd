extends Node3D
class_name LevelRunner
## Laster hvilket som helst nivå fra de konverterte HD .glb-filene + originale gameplay JSON-data.

const PINKY_SCRIPT := preload("res://scripts/player/PinkyController.gd")
const BOAT_SCRIPT := preload("res://scripts/player/BoatController.gd")
const CAMERA_SCRIPT := preload("res://scripts/player/FollowCamera.gd")
const NPC_SCRIPT := preload("res://scripts/world/NpcActor.gd")
const ENEMY_SCRIPT := preload("res://scripts/world/EnemyActor.gd")
const PORTAL_SCRIPT := preload("res://scripts/world/PortalTrigger.gd")
const COIN_SCRIPT := preload("res://scripts/world/CollectibleCoin.gd")
const BARREL_SCRIPT := preload("res://scripts/world/BreakableBarrel.gd")
const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")

const WORLD_SCALE := 0.1 # Samme 0.1-skala som OBJ->GLB-konvertereren (Shockwave-enheter -> meter)

var current_level_id: String = "abra"
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

	# 1. Moderne HD belysning, himmel og post-processing
	_setup_modern_environment(cfg)

	# 2. Last original HD .glb nivå-geometri med automatisk kollisjon
	var level_bounds := _load_level_geometry(str(cfg.get("w3d", level_id)))
	# Vent én fysikk-frame slik at trimesh-kollisjonene er registrert før raycast til bakken
	await get_tree().physics_frame

	# 3. Moderne animert Gerstner-hav hvis nivået har sjø
	if bool(cfg.get("has_water", false)):
		_spawn_modern_ocean(float(cfg.get("water_y", -0.2)), level_bounds)

	# 4. Les originale gameplay-data (spawns, NPC-er, fiender, portaler)
	var gp_data := _read_gameplay_json(level_id)

	# 5. Opprett kamera-rigg
	_camera_rig = _create_camera_rig()
	_world_root.add_child(_camera_rig)

	# 6. Spawn spiller (Pinky eller Den Sorte Dame på verdenskartet)
	var spawn_pos := _find_player_spawn(gp_data, level_bounds)
	var mode := str(cfg.get("mode", "adventure"))
	if mode == "boat":
		_player_node = _spawn_boat(spawn_pos)
		_camera_rig.set_target(_player_node, 20.0, 7.5)
	else:
		_player_node = _spawn_pinky(spawn_pos, mode == "swimming")
		_camera_rig.set_target(_player_node, 9.5, 2.4)
	if _camera_rig.spring_arm and _player_node:
		_camera_rig.spring_arm.add_excluded_object(_player_node.get_rid())

	# 7. Spawn NPC-er, fiender, tønner, mynter og portaler
	_populate_entities(level_id, cfg, gp_data, spawn_pos, level_bounds)


func _setup_modern_environment(cfg: Dictionary) -> void:
	_env_node = WorldEnvironment.new()
	var env := Environment.new()
	var is_indoor := not bool(cfg.get("has_water", false)) and float(cfg.get("fog_density", 0.002)) >= 0.006

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = cfg.get("sky_top", Color(0.16, 0.48, 0.88))
	sky_mat.sky_horizon_color = cfg.get("sky_horizon", Color(0.68, 0.84, 0.96))
	sky_mat.ground_bottom_color = cfg.get("fog_color", Color(0.15, 0.25, 0.35))
	sky_mat.ground_horizon_color = cfg.get("sky_horizon", Color(0.68, 0.84, 0.96))
	sky_mat.sun_angle_max = 28.0
	sky.sky_material = sky_mat

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	if is_indoor:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = cfg.get("ambient_color", Color(0.28, 0.42, 0.38))
		env.ambient_light_energy = 1.35
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_sky_contribution = 0.72
		env.ambient_light_color = cfg.get("ambient_color", Color(0.54, 0.60, 0.66))
		env.ambient_light_energy = float(cfg.get("ambient_energy", 0.62))

	# Moderne PBR filmisk tonemapping, SSAO, Glow og tåke
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.ssao_enabled = GameState.ssao_enabled
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.15
	env.glow_enabled = GameState.glow_enabled
	env.glow_intensity = 0.35
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.45
	env.fog_enabled = GameState.fog_enabled
	env.fog_light_color = cfg.get("fog_color", Color(0.66, 0.78, 0.88))
	env.fog_density = float(cfg.get("fog_density", 0.0018))
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12

	_env_node.environment = env
	_world_root.add_child(_env_node)

	_sun_node = DirectionalLight3D.new()
	_sun_node.light_color = cfg.get("sun_color", Color(1.0, 0.94, 0.82))
	_sun_node.light_energy = float(cfg.get("sun_energy", 1.75))
	_sun_node.shadow_enabled = true
	_sun_node.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun_node.directional_shadow_max_distance = 180.0
	_sun_node.shadow_blur = 1.4
	_sun_node.rotation_degrees = Vector3(-44.0, 28.0, 0.0)
	_world_root.add_child(_sun_node)


func _load_level_geometry(w3d_name: String) -> AABB:
	var fallback_map := {
		"outro": "abra",
		"graal_mountain": "graal_bosslevel",
		"fatamorgana_palace": "fatamorgana_city",
		"swimming": "world_map",
	}
	var glb_path := "res://assets/levels/%s.glb" % w3d_name
	if not ResourceLoader.exists(glb_path) and fallback_map.has(w3d_name):
		glb_path = "res://assets/levels/%s.glb" % fallback_map[w3d_name]
	var bounds := AABB(Vector3(-40, -2, -40), Vector3(80, 20, 80))

	if ResourceLoader.exists(glb_path):
		var sc := load(glb_path) as PackedScene
		if sc:
			var inst := sc.instantiate()
			inst.name = "LevelGeometry"
			_world_root.add_child(inst)

			var first := true
			var min_v := Vector3(1e9, 1e9, 1e9)
			var max_v := Vector3(-1e9, -1e9, -1e9)
			var lantern_count := 0

			for mi in _find_all_meshes(inst):
				var nm := mi.name.to_lower()
				# Skjul gamle flate Shockwave-vannflater slik at vår moderne Gerstner-havshader vises
				if "water" in nm or "abrasea" in nm or nm.ends_with("sea") or nm.ends_with("sea2"):
					mi.visible = false
					continue
				# Erstatt gamle ugjennomsiktige Shockwave glow-plater med ekte varme Godot 4 OmniLight3D-lykter
				if "glow" in nm:
					mi.visible = false
					if lantern_count < 10 and nm.begins_with("glow"):
						var laabb: AABB = mi.global_transform * mi.get_aabb()
						var lgt := OmniLight3D.new()
						lgt.position = laabb.get_center()
						lgt.light_color = Color(1.0, 0.78, 0.42)
						lgt.light_energy = 2.6
						lgt.omni_range = 12.0
						_world_root.add_child(lgt)
						lantern_count += 1
					continue
				# Skjul usynlige UI/shop/fog-hjelpemesher
				if "portalchoice" in nm or "fog" in nm or nm in ["shoplamp", "shopslingshot", "shopsword"]:
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

			if not first:
				bounds = AABB(min_v, max_v - min_v)
			return bounds

	# Fallback-øy dersom .glb ikke finnes for et nivå
	_build_fallback_island()
	return bounds


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


func _spawn_modern_ocean(water_y: float, bounds: AABB) -> void:
	var water := MeshInstance3D.new()
	water.name = "ModernOcean"
	var pm := PlaneMesh.new()
	var span: float = max(max(bounds.size.x, bounds.size.z) * 2.4, 460.0)
	pm.size = Vector2(span, span)
	pm.subdivide_width = 128
	pm.subdivide_depth = 128
	water.mesh = pm
	water.position = Vector3(bounds.get_center().x, water_y, bounds.get_center().z)

	var sm := ShaderMaterial.new()
	sm.shader = OCEAN_SHADER
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
	cam.fov = 65.0
	cam.near = 0.15
	cam.far = 600.0
	cam.current = true
	arm.add_child(cam)
	return rig


func _find_player_spawn(gp_data: Dictionary, bounds: AABB) -> Vector3:
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


func _snap_to_surface(pos: Vector3, bounds: AABB) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space:
		var from := Vector3(pos.x, bounds.position.y + bounds.size.y + 20.0, pos.z)
		var to := Vector3(pos.x, bounds.position.y - 30.0, pos.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		if hit and hit.has("position"):
			return hit["position"] + Vector3(0.0, 0.5, 0.0)
	return Vector3(pos.x, max(pos.y, 1.5), pos.z)


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
	box.size = Vector3(3.0, 2.0, 7.2)
	col.shape = box
	col.position.y = 1.0
	boat.add_child(col)

	_world_root.add_child(boat)
	return boat


func _populate_entities(level_id: String, cfg: Dictionary, gp_data: Dictionary, spawn_pos: Vector3, bounds: AABB) -> void:
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

	# Portal til neste nivå + retur til Abra Havn / Verdenskartet
	var next_id := str(cfg.get("next_level", "world_map"))
	var next_info := LevelCatalog.get_level(next_id)
	var portal: PortalTrigger = PORTAL_SCRIPT.new()
	portal.target_level_id = next_id
	portal.portal_label = "Reis til " + str(next_info.get("title", next_id))
	portal.position = _snap_to_surface(spawn_pos + Vector3(8.5, 2.0, -7.5), bounds)
	_world_root.add_child(portal)

	if level_id != "abra":
		var home_portal: PortalTrigger = PORTAL_SCRIPT.new()
		home_portal.target_level_id = "abra"
		home_portal.portal_label = "Tilbake til Abra Havn"
		home_portal.position = _snap_to_surface(spawn_pos + Vector3(-8.5, 2.0, -7.5), bounds)
		_world_root.add_child(home_portal)

	# Plasser gullmynter og knusbare tønner kun på fast grunn over vannlinjen
	var min_dry_y: float = float(cfg.get("water_y", -99.0)) + 0.35 if bool(cfg.get("has_water", false)) else -999.0
	for i in range(12):
		var ang := (float(i) / 12.0) * TAU + 0.2
		var rad := 7.0 + float(i % 4) * 4.5
		var cand := spawn_pos + Vector3(cos(ang) * rad, 3.0, sin(ang) * rad)
		var hit_pos := _raycast_ground(cand, bounds)
		if hit_pos.y > min_dry_y and absf(hit_pos.y - spawn_pos.y) < 4.0:
			var coin: CollectibleCoin = COIN_SCRIPT.new()
			coin.position = hit_pos + Vector3(0.0, 0.55, 0.0)
			_world_root.add_child(coin)

	for i in range(5):
		var ang := (float(i) / 5.0) * TAU + 0.5
		var cand := spawn_pos + Vector3(cos(ang) * 9.5, 3.0, sin(ang) * 9.5)
		var hit_pos := _raycast_ground(cand, bounds)
		if hit_pos.y > min_dry_y and absf(hit_pos.y - spawn_pos.y) < 4.0:
			var barrel: BreakableBarrel = BARREL_SCRIPT.new()
			barrel.position = hit_pos
			_world_root.add_child(barrel)


func _raycast_ground(pos: Vector3, bounds: AABB) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space:
		var from := Vector3(pos.x, bounds.position.y + bounds.size.y + 10.0, pos.z)
		var to := Vector3(pos.x, bounds.position.y - 10.0, pos.z)
		var q := PhysicsRayQueryParameters3D.create(from, to)
		var hit := space.intersect_ray(q)
		if hit and hit.has("position"):
			return hit["position"]
	return Vector3(pos.x, -9999.0, pos.z)


func _match_character_role(key: String) -> Dictionary:
	for k in CHARACTER_ROLES.keys():
		if key == k or key.begins_with(k):
			return CHARACTER_ROLES[k]
	return {}
