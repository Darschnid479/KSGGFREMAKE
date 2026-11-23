extends Node
class_name StoryScriptEngine
## 1:1 hendelses-, samtale-, spline-, puslespill- og historiemotor direkte fra originalspillets
## godot_project/data/gameplay/<level_id>.json (Global-regler, areatrigger_*, conversation, splines, osv.)!

const WORLD_SCALE := 0.1

var level_id: String = ""
var world_root: Node3D
var level_geom: Node3D
var player: Node3D
var camera_rig: FollowCamera
var heightmap: HeightmapSampler
var actors: Dictionary = {} # lower_key -> Node3D (pinky, sabeltann, langemann, pelle, pysa, skalken, benjamin, miriam, ...)
var colliders: Dictionary = {} # lower_name -> StaticBody3D
var nodes_by_name: Dictionary = {} # lower_name -> Dictionary (raw json node)

var _rules: Array = [] # Global/behaviour trigger rules
var _splines: Array = [] # Spline walk/run definitions
var _area_triggers: Array = [] # Circle/rect area triggers
var _fired_events: Dictionary = {} # event_name -> true
var _pending_timers: Array = [] # {time_left, callback}
var _moving_meshes: Array = [] # {node, target_pos, speed}
var _shouts: Array = [] # {actor, clip, interval, timer}
var _conv_queue: Array[String] = []
var _conv_name: String = ""
var _conv_locked: bool = false
var _active_speaker_node: Node3D = null
var _input_lock_failsafe: float = 0.0
var _elapsed: float = 0.0
var _re_vec: RegEx
var _re_rad: RegEx
var _re_rect: RegEx


func setup(p_level_id: String, gp_data: Dictionary, p_world_root: Node3D, p_level_geom: Node3D, p_player: Node3D, p_cam: FollowCamera, p_hm: HeightmapSampler, p_actors: Dictionary, p_colliders: Dictionary = {}) -> void:
	level_id = p_level_id
	world_root = p_world_root
	level_geom = p_level_geom
	player = p_player
	camera_rig = p_cam
	heightmap = p_hm
	actors = p_actors
	colliders = p_colliders
	_elapsed = 0.0
	if player:
		actors["pinky"] = player

	_re_vec = RegEx.new()
	_re_vec.compile("vector\\(([\\-\\d.]+),([\\-\\d.]+),([\\-\\d.]+)\\)")
	_re_rad = RegEx.new()
	_re_rad.compile("#radius:([\\d.]+)")
	_re_rect = RegEx.new()
	_re_rect.compile("#width:([\\d.]+),#length:([\\d.]+)")

	_parse_gameplay_nodes(gp_data)
	_wire_npc_interactions()
	_spawn_story_interactables()

	# Start originalspillets map-oppstartssekvens (uten å fryse spillerkontrollen på startmap!)
	emit_event("startmap")
	emit_event("resumemap")
	_schedule(0.10, func():
		emit_event("startmap_breathing")
		emit_event("resumemap_breathing")
		emit_event("allobjectscreated")
		_trigger_level_opening_voice()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_ENTER:
			if AudioManager.is_voice_playing():
				AudioManager.skip_current_voice()
			elif player and "input_locked" in player and player.input_locked:
				player.input_locked = false
				_input_lock_failsafe = 0.0


func _parse_gameplay_nodes(gp_data: Dictionary) -> void:
	var nodes: Array = gp_data.get("nodes", [])
	for n in nodes:
		var nm := str(n.get("name", ""))
		var low := nm.to_lower()
		nodes_by_name[low] = n
		var ud := str(n.get("userdata", ""))
		if ud.strip_edges() == "":
			continue

		var ud_low := ud.to_lower()
		if low in ["global", "behaviour", "behaviours", "timeline", "abrashop", "catapults"]:
			_parse_global_rules(ud)
		elif low.begins_with("areatrigger_"):
			_parse_area_trigger(low, n, ud)
		elif "#linearsplines" in ud_low and "target" in ud_low and ("trigger" in ud_low or "alltriggers" in ud_low):
			_parse_spline_walk(low, ud)
		elif (not ("#linearsplines" in ud_low)) and (not ("#type:#circle" in ud_low)) and ("trigger =" in ud_low or "trigger=" in ud_low or "alltriggers =" in ud_low):
			_parse_global_rules(ud)


func _parse_global_rules(ud: String) -> void:
	var cur: Dictionary = {}
	for raw_line in ud.replace("\r", "").split("\n"):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		if line.ends_with(";"):
			line = line.substr(0, line.length() - 1).strip_edges()
		var eq := line.find("=")
		if eq < 0:
			continue
		var k := line.substr(0, eq).strip_edges().to_lower()
		var v := line.substr(eq + 1).strip_edges()
		if k == "trigger" or k == "alltriggers":
			if not cur.is_empty():
				_rules.append(cur)
			var trig_specs: Array = []
			for part in v.split(","):
				trig_specs.append(_parse_trigger_spec(part.strip_edges()))
			cur = {
				"triggers": trig_specs,
				"satisfied": {},
				"requirements": [],
				"actions": [],
				"once": true,
				"fired": false,
			}
		elif not cur.is_empty():
			if k == "action":
				# Del opp kommaseparerte handlinger uten å ødelegge vector(x:y:z)
				for act in v.split(","):
					var a := act.strip_edges()
					if a != "":
						cur["actions"].append(a)
			elif k == "requirements":
				for req in v.split(","):
					var r := req.strip_edges().to_lower()
					if r != "":
						cur["requirements"].append(r)
			elif k == "once":
				cur["once"] = (v.strip_edges() != "0")
	if not cur.is_empty():
		_rules.append(cur)


func _parse_trigger_spec(raw: String) -> Dictionary:
	var delay := 0.0
	var ev := raw.to_lower()
	var plus := ev.find("+")
	if plus >= 0:
		delay = float(ev.substr(plus + 1).strip_edges())
		ev = ev.substr(0, plus).strip_edges()
	return {"event": ev, "delay": delay}


func _parse_area_trigger(low_name: String, node: Dictionary, ud: String) -> void:
	var gp: Array = node.get("godot_pos", [0, 0, 0])
	var cx := float(gp[0]) * WORLD_SCALE
	var cz := float(gp[2]) * WORLD_SCALE
	var radius := 3.5
	var vm := _re_vec.search(ud)
	if vm:
		cx = float(vm.get_string(1)) * WORLD_SCALE
		cz = -float(vm.get_string(2)) * WORLD_SCALE
	var rm := _re_rad.search(ud)
	if rm:
		radius = maxf(float(rm.get_string(1)) * WORLD_SCALE, 1.5)
	else:
		var rcm := _re_rect.search(ud)
		if rcm:
			var w := float(rcm.get_string(1)) * WORLD_SCALE
			var l := float(rcm.get_string(2)) * WORLD_SCALE
			radius = maxf(maxf(w, l) * 0.55, 1.8)
	_area_triggers.append({
		"name": low_name,
		"pos": Vector2(cx, cz),
		"radius": radius,
		"enabled": true,
		"inside": false,
	})


func _parse_spline_walk(low_name: String, ud: String) -> void:
	var pts: Array[Vector3] = []
	for m in _re_vec.search_all(ud):
		var gx := float(m.get_string(1)) * WORLD_SCALE
		var gz := -float(m.get_string(2)) * WORLD_SCALE
		var gy := _sample_floor_y(gx, gz, 0.0)
		pts.append(Vector3(gx, gy, gz))
	if pts.is_empty():
		return
	var target := ""
	var trig_raw := ""
	var speed := 3.8
	for raw_line in ud.replace("\r", "").split("\n"):
		for seg in raw_line.split(";"):
			var s := seg.strip_edges()
			var eq := s.find("=")
			if eq < 0:
				continue
			var k := s.substr(0, eq).strip_edges().to_lower()
			var v := s.substr(eq + 1).strip_edges().to_lower()
			if k == "target":
				target = v
			elif k == "trigger" or k == "alltriggers":
				trig_raw = v.split(",")[0].strip_edges()
			elif k == "speed":
				speed = 6.2 if v == "run" else 3.8
	if target != "" and trig_raw != "":
		var tspec := _parse_trigger_spec(trig_raw)
		_splines.append({
			"name": low_name,
			"target": target,
			"event": tspec["event"],
			"delay": tspec["delay"],
			"speed": speed,
			"points": pts,
			"fired": false,
		})


func _trigger_level_opening_voice() -> void:
	# For brett som ikke har egen startconversation i Global (eller forsinket grotte-intro), spill originalens åpningsreplikk straks!
	if AudioManager.is_voice_playing() or not _conv_queue.is_empty():
		return
	match level_id:
		"cave":
			if not GameState.has_achievement("played_cave_intro"):
				GameState.add_achievement("played_cave_intro")
				start_conversation("cave_start_intro1", true, true)
		"abra":
			if not GameState.has_achievement("talked_miriam_intro"):
				GameState.add_achievement("talked_miriam_intro")
				start_conversation("abra_curse_sunniva", true, true)
		"world_map":
			start_conversation("worldmap_intro", true, true)
		"graal_mountain":
			start_conversation("gral_mountain_intro", true, true)
		"graal_bosslevel":
			start_conversation("gral_boss_intro", true, true)
		"fatamorgana_city":
			start_conversation("fatamorgana_city_gate", true, true)
		"fatamorgana_palace":
			start_conversation("fatamorgana_palace_intro", true, true)
		"magakhan_beach":
			start_conversation("shangrila_beach_intro", true, true)
		"magakhan_jungle":
			start_conversation("shangrila_jungle_intro", true, true)
		"magakhan_palace":
			start_conversation("shangrila_palace_intro", true, true)
		"magakhan_dungeon":
			start_conversation("shangrila_dungeon_findanotherway", true, true)
		"magakhan_endboss_level":
			start_conversation("shangrila_boss_fight1", true, true)
		"cave_end":
			start_conversation("cave_end_intro", true, true)
		"cave_end_bosslevel":
			start_conversation("cave_boss_intro", true, true)
		"outro":
			start_conversation("outro_conversation", true, true)


func _wire_npc_interactions() -> void:
	for key in actors.keys():
		var node = actors[key]
		if node is NpcActor:
			var npc := node as NpcActor
			npc.story_conversation_id = _pick_npc_conversation(str(key))
			npc.interact_requested.connect(_on_npc_interacted)


func _pick_npc_conversation(key: String) -> String:
	var k := key.to_lower()
	match level_id:
		"cave":
			if "sabeltann" in k: return "cave_start_findthechest"
			if "langemann" in k: return "cave_start_intro1"
			if "pelle" in k: return "cave_start_throws"
			if "pysa" in k: return "cave_start_openchest"
			if "skalken" in k: return "cave_start_lookingforfood_skalken"
			if "benjamin" in k: return "cave_start_getbackin_benjamin"
		"abra":
			if "miriam" in k: return "abra_curse"
			if "sunniva" in k: return "abra_curse2_sunniva" if not GameState.has_achievement("met_miriam") else "abra_hey_sunniva"
			if "shopkeeper" in k: return "abra_buylamp_shopkeeper"
			if "sabeltann" in k: return "worldmap_graal"
			if "langemann" in k: return "abra_useportal1_miriam"
			if "pelle" in k: return "gral_mountain_intro"
			if "skalken" in k: return "abra_tip3"
		"graal_mountain":
			if "pelle" in k: return "gral_mountain_goahead"
		"fatamorgana_city":
			if "sabeltann" in k: return "fatamorgana_city_gate"
			if "skalken" in k: return "fatamorgana_city_bakeyourself_skalken"
			if "pelle" in k: return "fatamorgana_city_yum"
			if "pysa" in k: return "fatamorgana_city_nocakeshere_pysa"
			if "shopkeeper" in k: return "fatamorgana_city_cakesforsale_shopkeeper"
		"magakhan_beach":
			if "sabeltann" in k: return "shangrila_beach_intro"
			if "skalken" in k: return "shangrila_beach_lookingforfood"
			if "malena" in k: return "shangrila_beach_welcomesons"
			if "benjamin" in k: return "shangrila_beach_justhanging"
			if "langemann" in k: return "shangrila_beach_gatherthemen_langemann"
		"magakhan_dungeon":
			if "sirikit" in k: return "shangrila_dungeon_comewithmepirate"
			if "sabeltann" in k: return "shangrila_dungeon_findanotherway"
			if "langemann" in k: return "shangrila_dungeon_gofurther1"
		"cave_end":
			if "sabeltann" in k or "langemann" in k: return "cave_end_gofirst"
	return ""


func _on_npc_interacted(npc: NpcActor) -> void:
	var k := npc.npc_id.to_lower()
	if "shopkeeper" in k:
		_open_pirate_shop()
	if level_id == "abra" and "miriam" in k:
		GameState.add_achievement("met_miriam")
		GameState.add_achievement("unlockedgraal")
		if not GameState.has_achievement("miriam_travel_coins"):
			GameState.add_achievement("miriam_travel_coins")
			if GameState.coins < 12:
				GameState.add_coins(12)
		GameState.set_objective("Snakk med Kjøpmannen for å kjøpe lykt/sprettert, og gå til seilingsportalen ved brygga!")
	var cid := npc.story_conversation_id
	if cid == "":
		cid = _pick_npc_conversation(npc.npc_id)
	if cid != "":
		start_conversation(cid, true, true)


func _open_pirate_shop() -> void:
	if level_id == "fatamorgana_city":
		GameState.emit_signal("shop_requested", "Kjøpmannen — Fata Morgana", [
			{"id": "goldsword", "name": "Gullsverd (Gylden klinge, 40 skade)", "cost": 25, "weapon": "goldsword"},
			{"id": "heal", "name": "Krydret Honningkake (+60 Liv)", "cost": 5, "heal": 60.0},
		])
	else:
		GameState.emit_signal("shop_requested", "Kjøpmannens Sjørøverbutikk — Abra Havn", [
			{"id": "lamp", "name": "Gruvelykt (Lyser opp mørke huler)", "cost": 8, "weapon": "lamp", "achievement": "gotlamp"},
			{"id": "slingshot", "name": "Pinkys Sprettert (Avstandsskudd)", "cost": 12, "weapon": "slingshot", "achievement": "gotslingshot"},
			{"id": "sword", "name": "Stålsverd (30 nærkamp-skade)", "cost": 18, "weapon": "sword", "achievement": "gotsword"},
			{"id": "heal", "name": "Styrkedrikk (+50 Liv)", "cost": 4, "heal": 50.0},
		])


func _spawn_story_interactables() -> void:
	# 1. Spawn ALLE originale mynter på nøyaktig riktig sted fra gameplay-JSON (ingen tilfeldige sirkler under Pelles føtter!)
	var coin_script := preload("res://scripts/world/CollectibleCoin.gd")
	var coin_count := 0
	for low in nodes_by_name.keys():
		if low.begins_with("walkoverpickup_coppercoin") or low.begins_with("walkoverpickup_goldcoin"):
			var n: Dictionary = nodes_by_name[low]
			var gp: Array = n.get("godot_pos", [0, 0, 0])
			var gx := float(gp[0]) * WORLD_SCALE
			var gz := float(gp[2]) * WORLD_SCALE
			var gy := float(gp[1]) * WORLD_SCALE
			if not ("ignoreheightmap = 1" in str(n.get("userdata", "")).to_lower()):
				gy = _sample_floor_y(gx, gz, gy)
			var c: CollectibleCoin = coin_script.new()
			c.value = 5 if "goldcoin" in low else 1
			c.position = Vector3(gx, gy + 0.55, gz)
			world_root.add_child(c)
			coin_count += 1

	# 2. Generer ALLE originale hopp (jump_*) og stiger (ladder_*) fra gameplay-JSON på tvers av alle brett!
	_spawn_jumps_and_ladders()

	# 3. Generer originale oppdragsskatter (pickup_*) på alle brett (kake, nøkler, kokosnøtter, klubbe osv.)
	_spawn_all_pickups()

	# 4. I Grusomme Gabriels grotte (cave): plasser ekte originale historie-objekter!
	if level_id == "cave":
		_spawn_cave_story_objects()


func _spawn_jumps_and_ladders() -> void:
	for low in nodes_by_name.keys():
		if not (low.begins_with("jump") or low.begins_with("ladder")):
			continue
		if "tutorial" in low or "cameratrigger" in low:
			continue
		var n: Dictionary = nodes_by_name[low]
		var ud := str(n.get("userdata", ""))
		if not ("splinedata" in ud):
			continue
		var pts: Array[Vector3] = []
		for m in _re_vec.search_all(ud):
			var gx := float(m.get_string(1)) * WORLD_SCALE
			var gz := -float(m.get_string(2)) * WORLD_SCALE
			var vz := float(m.get_string(3)) * WORLD_SCALE
			var gy := _sample_floor_y(gx, gz, vz)
			pts.append(Vector3(gx, gy, gz))
		if pts.size() < 2:
			continue
		var a := pts[0]
		var b := pts[pts.size() - 1]
		if a.distance_to(b) < 0.45:
			continue

		var is_climb: bool = low.begins_with("ladder")
		var ev_base: String = str(low)
		for pair in [[a, b, false], [b, a, true]]:
			var from_p: Vector3 = pair[0]
			var to_p: Vector3 = pair[1]
			var is_rev: bool = pair[2]
			var trig := StoryInteractable.new()
			trig.name = ("Ladder_" if is_climb else "Jump_") + ev_base + ("_Top" if is_rev else "_Start")
			trig.position = from_p
			trig.is_blocking = false
			trig.add_to_group("interactable")
			trig.add_to_group("leap_interactable")
			if is_climb:
				trig.prompt_text = "[Space / E] Klatre ned stigen" if is_rev else "[Space / E] Klatre opp stigen"
			else:
				trig.prompt_text = "[Space / E] Hopp over kløften"

			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.50
			tm.outer_radius = 0.58
			ring.mesh = tm
			ring.position.y = 0.04
			var rmat := StandardMaterial3D.new()
			rmat.albedo_color = Color(0.95, 0.78, 0.25, 0.52) if is_climb else Color(0.32, 0.88, 1.0, 0.45)
			rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			rmat.emission_enabled = true
			rmat.emission = Color(rmat.albedo_color.r, rmat.albedo_color.g, rmat.albedo_color.b)
			rmat.emission_energy_multiplier = 0.55
			ring.material_override = rmat
			trig.add_child(ring)

			trig.on_interact_cb = func(p):
				var actor: Node = p if (p != null and p.has_method("leap_to")) else player
				if is_instance_valid(actor) and actor.has_method("leap_to"):
					var dist := from_p.distance_to(to_p)
					var dur := clampf(dist * (0.14 if is_climb else 0.09), 0.48, 1.25)
					var arc := 0.0 if is_climb else clampf(dist * 0.28, 1.35, 3.0)
					actor.leap_to(to_p + Vector3(0.0, 0.12, 0.0), dur, arc, is_climb, func():
						emit_event(ev_base + "_finished")
					)
			world_root.add_child(trig)


func _spawn_all_pickups() -> void:
	for low in nodes_by_name.keys():
		if not low.begins_with("pickup_"):
			continue
		if low == "pickup_woodensword" or level_id == "abra":
			continue
		var n: Dictionary = nodes_by_name[low]
		var gp: Array = n.get("godot_pos", [0, 0, 0])
		var gx := float(gp[0]) * WORLD_SCALE
		var gz := float(gp[2]) * WORLD_SCALE
		var gy := _sample_floor_y(gx, gz, float(gp[1]) * WORLD_SCALE)

		var area := Area3D.new()
		area.name = "Pickup_" + low
		area.position = Vector3(gx, gy + 0.72, gz)
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.6
		cs.shape = sp
		area.add_child(cs)

		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.68
		orb.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.28)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.16)
		mat.emission_energy_multiplier = 1.8
		orb.material_override = mat
		area.add_child(orb)

		var pk_id: String = str(low)
		area.body_entered.connect(func(body: Node):
			if body.is_in_group("player"):
				GameState.add_achievement("got_" + pk_id)
				GameState.heal(25.0)
				GameState.add_coins(5)
				AudioManager.play_sfx("coinpopup")
				if "sword" in pk_id:
					GameState.unlock_weapon("sword", true)
				elif "goldsword" in pk_id:
					GameState.unlock_weapon("goldsword", true)
				emit_event(pk_id + "_pickedup")
				area.queue_free()
		)
		world_root.add_child(area)


func _spawn_cave_story_objects() -> void:
	# A) Tresverdet på klippehyllen (pickup_woodensword)
	if nodes_by_name.has("pickup_woodensword"):
		var n: Dictionary = nodes_by_name["pickup_woodensword"]
		var gp: Array = n.get("godot_pos", [207, -62, 146])
		var pos := Vector3(float(gp[0]) * WORLD_SCALE, float(gp[1]) * WORLD_SCALE, float(gp[2]) * WORLD_SCALE)
		pos.y = _sample_floor_y(pos.x, pos.z, pos.y) + 0.65
		var area := Area3D.new()
		area.name = "PickupWoodenSword"
		area.position = pos
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.8
		cs.shape = sp
		area.add_child(cs)

		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 1.15, 0.04)
		blade.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.68, 0.44, 0.22)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.78, 0.25)
		mat.emission_energy_multiplier = 0.85
		blade.material_override = mat
		blade.rotation_degrees = Vector3(0.0, 0.0, 22.0)
		area.add_child(blade)

		var gl := OmniLight3D.new()
		gl.light_color = Color(1.0, 0.84, 0.36)
		gl.light_energy = 2.6
		gl.omni_range = 6.0
		area.add_child(gl)

		area.body_entered.connect(func(body: Node):
			if body.is_in_group("player"):
				GameState.unlock_weapon("woodensword", true)
				AudioManager.play_sfx("coinpopup")
				start_conversation("cave_start_sword1", true, true)
				_schedule(3.5, func(): AudioManager.play_voice("cave_start_swordintro_storyteller"))
				emit_event("pickup_woodensword_pickedup")
				area.queue_free()
		)
		world_root.add_child(area)

	# B) Skyvbar trekasse (cratepuzzle1) med movablecrate.glb
	if nodes_by_name.has("cratepuzzle1"):
		var n: Dictionary = nodes_by_name["cratepuzzle1"]
		var gp: Array = n.get("godot_pos", [-506, 0, -176])
		var pos := Vector3(float(gp[0]) * WORLD_SCALE, 0.0, float(gp[2]) * WORLD_SCALE)
		pos.y = _sample_floor_y(pos.x, pos.z, -6.5)
		var crate := StoryInteractable.new()
		crate.name = "CratePuzzle1"
		crate.position = pos
		crate.is_blocking = true
		crate.add_to_group("interactable")
		crate.prompt_text = "[E] Dytt kassen på plass"
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(1.5, 1.4, 1.5)
		cs.shape = bx
		cs.position.y = 0.7
		crate.add_child(cs)
		if ResourceLoader.exists("res://assets/models/movablecrate.glb"):
			var sc := load("res://assets/models/movablecrate.glb") as PackedScene
			if sc:
				var inst := sc.instantiate()
				crate.add_child(inst)
				VisualEnhancer.enhance_world_node(inst, "abra", -999.0)
		else:
			var mi := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(1.4, 1.3, 1.4)
			mi.mesh = m
			mi.position.y = 0.65
			crate.add_child(mi)
		var dest_crate := crate.position + Vector3(1.8, 0.0, -2.2)
		if nodes_by_name.has("correctposition1"):
			var cp: Array = nodes_by_name["correctposition1"].get("godot_pos", [])
			if cp.size() >= 3:
				var dx := float(cp[0]) * WORLD_SCALE
				var dz := float(cp[2]) * WORLD_SCALE
				dest_crate = Vector3(dx, _sample_floor_y(dx, dz, crate.position.y), dz)
		crate.on_interact_cb = func(_p):
			if not crate.get_meta("solved", false):
				crate.set_meta("solved", true)
				AudioManager.play_sfx("bashbarrel_01")
				_moving_meshes.append({"node": crate, "target_pos": dest_crate, "speed": 3.0})
				emit_event("cratepuzzle1_in_correctposition")
		world_root.add_child(crate)

	# C) Knusbare steinvegger (crushablewall_1 & crushablewall_2)
	for cname in ["crushablewall_1", "crushablewall_2"]:
		if not nodes_by_name.has(cname):
			continue
		var n: Dictionary = nodes_by_name[cname]
		var gp: Array = n.get("godot_pos", [456, -77, -37])
		var pos := Vector3(float(gp[0]) * WORLD_SCALE, 0.0, float(gp[2]) * WORLD_SCALE)
		pos.y = _sample_floor_y(pos.x, pos.z, float(gp[1]) * WORLD_SCALE)
		var wall := StoryInteractable.new()
		wall.name = cname
		wall.position = pos
		wall.is_blocking = false
		wall.add_to_group("hittable")
		wall.add_to_group("interactable")
		wall.prompt_text = "[Venstreklikk / E] Knus den sprukne steinveggen"
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(4.0, 3.2, 1.4)
		cs.shape = bx
		cs.position.y = 1.6
		wall.add_child(cs)
		var wall_id: String = str(cname)
		var crush_fn := func():
			AudioManager.play_sfx("cave_crushablewall")
			_disable_collider(wall_id + "_collision")
			_disable_collider(wall_id)
			if is_instance_valid(level_geom):
				for mi in _find_meshes(level_geom):
					var mn := mi.name.to_lower()
					if ("crushrock" in mn or "crushable" in mn) and mi.global_position.distance_to(pos) < 8.5:
						mi.visible = false
			emit_event(wall_id + "_crushed")
			wall.queue_free()
		wall.on_hit_cb = crush_fn
		wall.on_interact_cb = func(_p): crush_fn.call()
		world_root.add_child(wall)

	# D) Pelle kaster Pinky over lavaen (actionable_throw)
	if nodes_by_name.has("actionable_throw"):
		var n: Dictionary = nodes_by_name["actionable_throw"]
		var gp: Array = n.get("godot_pos", [-218, 0, -267])
		var pos := Vector3(float(gp[0]) * WORLD_SCALE, 0.0, float(gp[2]) * WORLD_SCALE)
		pos.y = _sample_floor_y(pos.x, pos.z, -7.0)
		var trig := StoryInteractable.new()
		trig.name = "ActionableThrow"
		trig.position = pos
		trig.is_blocking = false
		trig.add_to_group("interactable")
		trig.prompt_text = "[E] La Pelle kaste deg over lavaen"
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 2.0
		cs.shape = sp
		trig.add_child(cs)
		trig.on_interact_cb = func(p):
			AudioManager.play_sfx("jump")
			var actor: Node = p if (p != null and p.has_method("leap_to")) else player
			var dest := Vector3(-5.7, _sample_floor_y(-5.7, -23.5, -8.5) + 0.15, -23.5)
			if is_instance_valid(actor) and actor.has_method("leap_to"):
				actor.leap_to(dest, 0.92, 3.8, false, func():
					emit_event("actionable_throw_actioned")
				)
			else:
				if is_instance_valid(player):
					player.global_position = dest
				emit_event("actionable_throw_actioned")
		world_root.add_child(trig)


func _disable_collider(cname: String) -> void:
	var k := cname.to_lower().strip_edges()
	if not colliders.has(k):
		return
	var sb = colliders[k]
	if is_instance_valid(sb) and sb is StaticBody3D:
		(sb as StaticBody3D).collision_layer = 0
		for c in sb.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", true)


func _enable_collider(cname: String) -> void:
	var k := cname.to_lower().strip_edges()
	if not colliders.has(k):
		return
	var sb = colliders[k]
	if is_instance_valid(sb) and sb is StaticBody3D:
		(sb as StaticBody3D).collision_layer = 1
		for c in sb.get_children():
			if c is CollisionShape3D:
				(c as CollisionShape3D).set_deferred("disabled", false)


func emit_event(event_name: String) -> void:
	var ev := event_name.to_lower().strip_edges()
	if ev == "":
		return
	_fired_events[ev] = true

	# 1. Sjekk alle Global-regler
	for rule in _rules:
		if rule["fired"] and rule["once"]:
			continue
		var matched_here := false
		for i in range(rule["triggers"].size()):
			var ts: Dictionary = rule["triggers"][i]
			if ts["event"] == ev and not rule["satisfied"].has(i):
				matched_here = true
				var delay := float(ts["delay"])
				if delay > 0.01:
					var r_ref: Dictionary = rule
					var idx := i
					_schedule(delay, func():
						r_ref["satisfied"][idx] = true
						_try_fire_rule(r_ref)
					)
				else:
					rule["satisfied"][i] = true
		if matched_here:
			_try_fire_rule(rule)

	# 2. Sjekk alle karakter-splines (sabeltann_1, langemann_1, pelle_1, pinky_end osv.!)
	for sp in _splines:
		if sp["fired"]:
			continue
		if sp["event"] == ev:
			sp["fired"] = true
			var delay := float(sp["delay"])
			var sp_ref: Dictionary = sp
			if delay > 0.01:
				_schedule(delay, func(): _run_spline(sp_ref))
			else:
				_run_spline(sp_ref)


func _try_fire_rule(rule: Dictionary) -> void:
	if rule["fired"] and rule["once"]:
		return
	if rule["satisfied"].size() < rule["triggers"].size():
		return
	# Sjekk krav (pinky_hasachieved_* / pinky_nothasachieved_*)
	for req in rule["requirements"]:
		var r := str(req)
		if r.begins_with("pinky_hasachieved_"):
			if not GameState.has_achievement(r.substr(18)):
				return
		elif r.begins_with("pinky_nothasachieved_"):
			if GameState.has_achievement(r.substr(21)):
				return
	rule["fired"] = true
	if not rule["once"]:
		rule["satisfied"] = {}
	for act in rule["actions"]:
		_execute_action(str(act))


func _execute_action(raw: String) -> void:
	var parts := raw.split("|")
	if parts.is_empty():
		return
	var cmd := parts[0].strip_edges().to_lower()

	match cmd:
		"disableinput":
			if _elapsed < 1.2:
				return
			if player and "input_locked" in player:
				player.input_locked = true
				_input_lock_failsafe = 5.0
		"enableinput":
			if player and "input_locked" in player:
				player.input_locked = false
				_input_lock_failsafe = 0.0
		"startconversation":
			if parts.size() >= 2:
				var cname := parts[1].strip_edges().to_lower()
				var nocam := "nocamera" in raw.to_lower()
				var dontlock := "dontlock" in raw.to_lower() or _elapsed < 1.5
				start_conversation(cname, nocam, dontlock)
		"playsfx", "playsound":
			if parts.size() >= 2:
				var clip := parts[1].strip_edges().to_lower()
				var send_fin := "sendfinishedevent=1" in raw.to_lower()
				if not AudioManager.get_dialogue_info(clip).is_empty():
					AudioManager.play_voice(clip, func():
						if send_fin:
							emit_event(clip + "_finished")
					)
				else:
					AudioManager.play_sfx(clip)
					if send_fin:
						_schedule(0.8, func(): emit_event(clip + "_finished"))
		"startloopingsound":
			if parts.size() >= 2:
				AudioManager.play_music(parts[1].strip_edges().to_lower())
		"playambience":
			if parts.size() >= 2:
				AudioManager.play_ambience(parts[1].strip_edges().to_lower())
		"sendgameevent":
			if parts.size() >= 2:
				emit_event(parts[1].strip_edges().to_lower())
		"proceedtomap", "loadmap":
			if parts.size() >= 2:
				var nxt := parts[1].strip_edges().to_lower()
				if level_id == "cave" and nxt == "world_map":
					nxt = "abra" # Etter grotten drar mannskapet rett til Miriam av Gral i Abra Havn!
				GameState.complete_level_story(level_id)
				GameState.request_level(nxt)
		"adduseitem", "selectuseitem", "give", "addtoinventory":
			if parts.size() >= 2:
				var item := parts[1].strip_edges().to_lower()
				if item in ["woodensword", "sword", "goldsword", "rapier", "slingshot", "lamp"]:
					GameState.unlock_weapon(item, cmd in ["selectuseitem", "give"])
				else:
					GameState.add_achievement("got_" + item)
		_:
			if parts.size() >= 2:
				var sub := parts[1].strip_edges().to_lower()
				_execute_target_action(cmd, sub, parts)


func _execute_target_action(target: String, sub: String, parts: PackedStringArray) -> void:
	match sub:
		"enable":
			for t in _area_triggers:
				if t["name"] == target:
					t["enabled"] = true
			_enable_collider(target)
		"disable":
			for t in _area_triggers:
				if t["name"] == target:
					t["enabled"] = false
			_disable_collider(target)
		"disablecollision":
			_disable_collider(target)
		"enablecollision":
			_enable_collider(target)
		"open", "crush", "removefromworld", "scaleout":
			_disable_collider(target)
			_disable_collider(target + "_collision")
			if is_instance_valid(level_geom):
				var mi := _find_mesh_by_name(level_geom, target)
				if mi:
					mi.visible = false
			if sub == "crush":
				AudioManager.play_sfx("cave_crushablewall")
				emit_event(target + "_crushed")
			elif sub == "open":
				AudioManager.play_sfx("door")
				emit_event(target + "_opened")
		"close":
			_enable_collider(target)
			_enable_collider(target + "_collision")
			if is_instance_valid(level_geom):
				var mi := _find_mesh_by_name(level_geom, target)
				if mi:
					mi.visible = true
		"adduseitem", "selectuseitem", "give", "addtoinventory":
			if parts.size() >= 3:
				var item := parts[2].strip_edges().to_lower()
				if item in ["woodensword", "sword", "goldsword", "rapier", "slingshot", "lamp"]:
					GameState.unlock_weapon(item, sub in ["selectuseitem", "give"])
				else:
					GameState.add_achievement("got_" + item)
		"addachievement":
			if parts.size() >= 3:
				GameState.add_achievement(parts[2].strip_edges().to_lower())
		"resethealth":
			GameState.heal(100.0)
		"jump", "throw", "climbwithcamera":
			if parts.size() >= 3:
				var jname := parts[2].strip_edges().to_lower()
				if actors.has(target) and nodes_by_name.has(jname):
					var ud := str(nodes_by_name[jname].get("userdata", ""))
					var pts: Array[Vector3] = []
					for m in _re_vec.search_all(ud):
						var gx := float(m.get_string(1)) * WORLD_SCALE
						var gz := -float(m.get_string(2)) * WORLD_SCALE
						pts.append(Vector3(gx, _sample_floor_y(gx, gz, 0.0), gz))
					var act_node = actors[target]
					if pts.size() >= 2 and act_node.has_method("leap_to"):
						var dest := pts[pts.size() - 1]
						act_node.leap_to(dest, 0.85, 0.0 if sub == "climbwithcamera" else 2.6, sub == "climbwithcamera", func(): emit_event(jname + "_finished"))
					elif not pts.is_empty() and act_node.has_method("walk_spline"):
						act_node.walk_spline(pts, 5.6, func(): emit_event(jname + "_finished"))
					else:
						emit_event(jname + "_finished")
		"zapto":
			if parts.size() >= 3:
				var dest_name := parts[2].strip_edges().to_lower()
				if actors.has(target) and nodes_by_name.has(dest_name):
					var gp: Array = nodes_by_name[dest_name].get("godot_pos", [0, 0, 0])
					var gx := float(gp[0]) * WORLD_SCALE
					var gz := float(gp[2]) * WORLD_SCALE
					var gy := _sample_floor_y(gx, gz, float(gp[1]) * WORLD_SCALE)
					var act_node = actors[target]
					if act_node.has_method("zap_to"):
						act_node.zap_to(Vector3(gx, gy, gz))
					elif act_node is Node3D:
						(act_node as Node3D).global_position = Vector3(gx, gy, gz)
		"startshout":
			if parts.size() >= 3 and actors.has(target):
				var clip := parts[2].strip_edges().to_lower()
				var iv := float(parts[3]) if parts.size() >= 4 else 16.0
				_shouts.append({"actor": actors[target], "clip": clip, "interval": maxf(iv, 10.0), "timer": 3.0})
		"stopshout":
			_shouts = _shouts.filter(func(s): return s["actor"] != actors.get(target))
		"changeposition":
			if is_instance_valid(level_geom):
				var mi := _find_mesh_by_name(level_geom, target)
				if mi:
					var delta_y := -1.0
					if parts.size() >= 3 and "vector(" in parts[2]:
						var m := RegEx.new()
						m.compile("vector\\(([\\-\\d.]+):([\\-\\d.]+):([\\-\\d.]+)\\)")
						var res := m.search(parts[2])
						if res:
							delta_y = float(res.get_string(3)) * WORLD_SCALE
					_moving_meshes.append({"node": mi, "target_pos": mi.position + Vector3(0.0, delta_y, 0.0), "speed": 1.2})
		"keyframeplayer-play":
			if is_instance_valid(level_geom):
				var mi := _find_mesh_by_name(level_geom, target)
				if mi:
					if "coffin" in target:
						_moving_meshes.append({"node": mi, "target_pos": mi.position + Vector3(0.0, 1.4, -1.6), "speed": 2.4})
					elif "curse" in target:
						_moving_meshes.append({"node": mi, "target_pos": mi.position + Vector3(0.0, 5.5, 0.0), "speed": 2.6})
						var gl := OmniLight3D.new()
						gl.light_color = Color(0.18, 1.0, 0.55)
						gl.light_energy = 7.5
						gl.omni_range = 24.0
						mi.add_child(gl)


func start_conversation(conv_name: String, no_camera: bool = false, dont_lock: bool = false) -> void:
	var clips := AudioManager.get_conversation_clips(conv_name)
	if clips.is_empty():
		emit_event(conv_name + "_finished")
		return
	_set_active_speaker(null)
	_conv_name = conv_name.to_lower()
	_conv_queue = clips
	_conv_locked = not dont_lock
	if _conv_locked and player and "input_locked" in player:
		player.input_locked = true
		_input_lock_failsafe = 18.0
	_play_next_conv_line()


func _play_next_conv_line() -> void:
	_set_active_speaker(null)
	if _conv_queue.is_empty():
		var finished_name := _conv_name
		_conv_name = ""
		if _conv_locked and player and "input_locked" in player:
			player.input_locked = false
			_input_lock_failsafe = 0.0
		_conv_locked = false
		if finished_name != "":
			emit_event(finished_name + "_finished")
		return

	var clip := _conv_queue[0]
	_conv_queue.remove_at(0)
	var info := AudioManager.play_voice(clip, func():
		emit_event(clip + "_finished")
		_play_next_conv_line()
	)
	var sp := str(info.get("speaker", "")).to_lower()
	if actors.has(sp):
		_set_active_speaker(actors[sp])
	if _conv_locked:
		_input_lock_failsafe = 14.0


func _set_active_speaker(node: Node3D) -> void:
	if is_instance_valid(_active_speaker_node):
		if _active_speaker_node is NpcActor:
			(_active_speaker_node as NpcActor).set_talking(false)
		elif "is_talking" in _active_speaker_node:
			_active_speaker_node.is_talking = false
	_active_speaker_node = node
	if is_instance_valid(node):
		var look_at := player.global_position if is_instance_valid(player) and node != player else Vector3.ZERO
		if node is NpcActor:
			(node as NpcActor).set_talking(true, look_at)
		elif "is_talking" in node:
			node.is_talking = true


func _run_spline(sp: Dictionary) -> void:
	var tname := str(sp["target"])
	var act = actors.get(tname, null)
	if not is_instance_valid(act):
		emit_event(str(sp["name"]) + "_finished")
		return
	var pts: Array[Vector3] = sp["points"]
	var sname := str(sp["name"])
	if act.has_method("walk_spline"):
		act.walk_spline(pts, float(sp["speed"]), func(): emit_event(sname + "_finished"))
	else:
		emit_event(sname + "_finished")


func _physics_process(delta: float) -> void:
	_elapsed += delta
	# 1. Tidsforsinkede triggere
	var keep_timers: Array = []
	for t in _pending_timers:
		t["time_left"] -= delta
		if t["time_left"] <= 0.0:
			var cb: Callable = t["cb"]
			if cb.is_valid():
				cb.call()
		else:
			keep_timers.append(t)
	_pending_timers = keep_timers

	# 2. Sikkerhetsventil mot fastlåst input
	if _input_lock_failsafe > 0.0:
		_input_lock_failsafe -= delta
		if _input_lock_failsafe <= 0.0 and player and "input_locked" in player:
			player.input_locked = false

	# 3. Sjekk originale areatrigger_* mot Pinkys XZ-posisjon
	if is_instance_valid(player):
		var p2 := Vector2(player.global_position.x, player.global_position.z)
		for tr in _area_triggers:
			if not tr["enabled"]:
				continue
			var now_in := p2.distance_to(tr["pos"]) <= float(tr["radius"])
			if now_in and not tr["inside"]:
				tr["inside"] = true
				emit_event(str(tr["name"]) + "_enter")
			elif not now_in and tr["inside"]:
				tr["inside"] = false
				emit_event(str(tr["name"]) + "_leave")

		# 4. Nærhets-rop fra mannskap (Skalken, Benjamin, Pelle)
		for sh in _shouts:
			sh["timer"] -= delta
			if sh["timer"] <= 0.0 and is_instance_valid(sh["actor"]):
				if (sh["actor"] as Node3D).global_position.distance_to(player.global_position) < 9.5 and not AudioManager.is_voice_playing():
					AudioManager.play_voice(str(sh["clip"]))
					sh["timer"] = float(sh["interval"])
				else:
					sh["timer"] = 2.0

	# 5. Bevegelige nivå-mesher (lava som synker, kistelokk som flyr opp, forbannelsesrøyk, kasse)
	var keep_mv: Array = []
	for mv in _moving_meshes:
		var node: Node3D = mv["node"]
		if not is_instance_valid(node):
			continue
		var tgt: Vector3 = mv["target_pos"]
		node.position = node.position.move_toward(tgt, float(mv["speed"]) * delta)
		if node.position.distance_to(tgt) > 0.02:
			keep_mv.append(mv)
	_moving_meshes = keep_mv


func _schedule(delay: float, cb: Callable) -> void:
	_pending_timers.append({"time_left": delay, "cb": cb})


func _sample_floor_y(gx: float, gz: float, fallback: float) -> float:
	if heightmap and heightmap.valid:
		var hy := heightmap.sample_y(gx, gz)
		if hy > -5000.0:
			return hy
	return fallback


func _find_mesh_by_name(root: Node, target_lower: String) -> MeshInstance3D:
	var clean_t := target_lower.replace("_", "")
	for mi in _find_meshes(root):
		var mn := mi.name.to_lower().replace("_", "")
		if mn == clean_t or clean_t in mn:
			return mi
	return null


func _find_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_meshes(c))
	return out
