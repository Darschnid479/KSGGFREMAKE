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
var nodes_by_name: Dictionary = {} # lower_name -> Dictionary (raw json node)

var _rules: Array = [] # Global trigger rules
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
var _re_vec: RegEx
var _re_rad: RegEx
var _re_rect: RegEx


func setup(p_level_id: String, gp_data: Dictionary, p_world_root: Node3D, p_level_geom: Node3D, p_player: Node3D, p_cam: FollowCamera, p_hm: HeightmapSampler, p_actors: Dictionary) -> void:
	level_id = p_level_id
	world_root = p_world_root
	level_geom = p_level_geom
	player = p_player
	camera_rig = p_cam
	heightmap = p_hm
	actors = p_actors
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

	# Start originalspillets map-oppstartssekvens (startmap -> startmap_breathing)!
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


func _parse_gameplay_nodes(gp_data: Dictionary) -> void:
	var nodes: Array = gp_data.get("nodes", [])
	for n in nodes:
		var nm := str(n.get("name", ""))
		var low := nm.to_lower()
		nodes_by_name[low] = n
		var ud := str(n.get("userdata", ""))
		if ud.strip_edges() == "":
			continue

		if low == "global":
			_parse_global_rules(ud)
		elif low.begins_with("areatrigger_"):
			_parse_area_trigger(low, n, ud)
		elif "#linearSplines" in ud and "target" in ud.to_lower() and "trigger" in ud.to_lower():
			_parse_spline_walk(low, ud)


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
			elif k == "trigger":
				trig_raw = v
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
	# For brett som ikke har egen startconversation i Global, spill av originalens introduksjonsreplikk!
	if AudioManager.is_voice_playing() or not _conv_queue.is_empty():
		return
	match level_id:
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
			if "shopkeeper" in k: return "abra_buysword_shopkeeper"
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
	var cid := npc.story_conversation_id
	if cid == "":
		cid = _pick_npc_conversation(npc.npc_id)
	if cid == "":
		return
	if level_id == "abra" and "miriam" in npc.npc_id:
		GameState.add_achievement("met_miriam")
		GameState.set_objective("Gå til seilingsportalen ved brygga i Abra Havn for å sette seil mot Gral!")
	start_conversation(cid, true, true)


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

	# 2. I Grusomme Gabriels grotte (cave): plasser ekte originale historie-objekter!
	if level_id == "cave":
		_spawn_cave_story_objects()


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
		sp.radius = 1.6
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
				GameState.equip_weapon("woodensword")
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
		crate.on_interact_cb = func(_p):
			if not crate.get_meta("solved", false):
				crate.set_meta("solved", true)
				AudioManager.play_sfx("bashbarrel_01")
				_moving_meshes.append({"node": crate, "target_pos": crate.position + Vector3(1.8, 0.0, -2.2), "speed": 3.0})
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
			if is_instance_valid(level_geom):
				for mi in _find_meshes(level_geom):
					if "crushrock" in mi.name.to_lower() and mi.global_position.distance_to(pos) < 8.0:
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
		trig.add_to_group("interactable")
		trig.prompt_text = "[E] La Pelle kaste deg over lavaen"
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.8
		cs.shape = sp
		trig.add_child(cs)
		trig.on_interact_cb = func(_p):
			emit_event("actionable_throw_actioned")
			AudioManager.play_sfx("jump")
			if is_instance_valid(player):
				var dest := Vector3(-5.7, _sample_floor_y(-5.7, -23.5, -8.5) + 0.3, -23.5)
				player.global_position = dest
		world_root.add_child(trig)


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
			if player and "input_locked" in player:
				player.input_locked = true
				_input_lock_failsafe = 14.0
		"enableinput":
			if player and "input_locked" in player:
				player.input_locked = false
				_input_lock_failsafe = 0.0
		"startconversation":
			if parts.size() >= 2:
				var cname := parts[1].strip_edges().to_lower()
				var nocam := "nocamera" in raw.to_lower()
				var dontlock := "dontlock" in raw.to_lower()
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
		"disable":
			for t in _area_triggers:
				if t["name"] == target:
					t["enabled"] = false
		"addachievement":
			if parts.size() >= 3:
				GameState.add_achievement(parts[2].strip_edges().to_lower())
		"resethealth":
			GameState.heal(100.0)
		"jump":
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
					if not pts.is_empty() and act_node.has_method("walk_spline"):
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
