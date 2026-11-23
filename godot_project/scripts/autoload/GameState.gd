extends Node
## Global spilltilstand og 100% tro original historieprogresjon (port av gameManager.ls + inventoryManager.ls + serialisation.ls).

signal health_changed(current: float, maximum: float)
signal air_changed(current: float, maximum: float)
signal coins_changed(coins: int)
signal weapon_changed(weapon_id: String)
signal objective_changed(text: String)
signal dialogue_requested(speaker: String, lines: Array)
signal boss_health_changed(boss_name: String, current: float, maximum: float)
signal level_change_requested(level_id: String)

const SAVE_PATH := "user://sabeltann_hd_save.json"

const WEAPONS := {
	"woodensword": {"name": "Tresverd", "damage": 15.0, "range": 2.4, "type": "melee"},
	"sword": {"name": "Sjørøversabel", "damage": 28.0, "range": 2.8, "type": "melee"},
	"goldsword": {"name": "Gullsverd", "damage": 45.0, "range": 3.0, "type": "melee"},
	"rapier": {"name": "Sabeltanns kårde", "damage": 60.0, "range": 3.2, "type": "melee"},
	"slingshot": {"name": "Sprettert", "damage": 20.0, "range": 28.0, "type": "ranged"},
	"lamp": {"name": "Lykte-lampe", "damage": 0.0, "range": 10.0, "type": "light"},
}

## 100% original historie-rekkefølge fra start til slutt (verifisert fra gameplayw3ds/*.w3d)
const CANONICAL_STORY_ORDER := [
	"cave",
	"abra",
	"world_map",
	"graal_mountain",
	"graal_underwater",
	"graal_bosslevel",
	"fatamorgana_city",
	"fatamorgana_underwater",
	"fatamorgana_palace",
	"fatamorgana_bosslevel",
	"magakhan_beach",
	"magakhan_jungle",
	"magakhan_palace",
	"magakhan_dungeon",
	"magakhan_dungeon_underwater",
	"magakhan_endboss_level",
	"cave_end",
	"cave_end_bosslevel",
	"outro",
]

const LEVEL_CUTSCENES := {
	"cave": "intro_cave",
	"abra": "abra_miriam",
	"graal_bosslevel": "graal_boss",
	"fatamorgana_city": "fatamorgana_arrival",
	"magakhan_endboss_level": "magakhan_dragon",
	"cave_end_bosslevel": "gabriel_finale",
	"outro": "outro_victory",
}

var current_level_id: String = "cave"
var max_health: float = 100.0
var health: float = 100.0
var max_air: float = 100.0
var air: float = 100.0
var coins: int = 25
var equipped_weapon: String = "sword"
var unlocked_weapons: Array[String] = ["woodensword", "sword", "slingshot", "lamp", "goldsword", "rapier"]
var visited_levels: Array[String] = ["cave"]
var story_achievements: Array[String] = ["unlockedgraal"]
var seen_cutscenes: Array[String] = []
var quest_flags: Dictionary = {}
var current_objective: String = ""
var lamp_enabled: bool = false
var suppress_cutscenes: bool = false

# Moderne AAA animasjons-grafikkinnstillinger
var graphics_quality: String = "Ultra" # "Medium", "High", "Ultra"
var render_scale: float = 1.0
var ssao_enabled: bool = true
var ssil_enabled: bool = true
var volumetric_fog_enabled: bool = true
var glow_enabled: bool = true
var fog_enabled: bool = true
var mouse_sensitivity: float = 0.0028


func _ready() -> void:
	load_game()


func reset_new_game(start_level: String = "cave") -> void:
	current_level_id = start_level
	health = max_health
	coins = 25
	equipped_weapon = "sword"
	visited_levels = [start_level]
	story_achievements = ["unlockedgraal"]
	seen_cutscenes = []
	quest_flags = {}
	lamp_enabled = false
	var info := LevelCatalog.get_level(start_level)
	current_objective = info.get("objective", "")
	emit_signal("health_changed", health, max_health)
	emit_signal("coins_changed", coins)
	emit_signal("weapon_changed", equipped_weapon)
	emit_signal("objective_changed", current_objective)
	save_game()


func has_achievement(ach: String) -> bool:
	return ach in story_achievements


func grant_achievement(ach: String) -> void:
	if not (ach in story_achievements):
		story_achievements.append(ach)
		save_game()


## Returnerer 100% original neste hovedøy på Verdenskartet ut fra spillerens historiefremgang.
func get_active_story_island() -> String:
	if not has_achievement("finishedgraal"):
		return "graal_mountain"
	if not has_achievement("finishedfatamorgana"):
		return "fatamorgana_city"
	if not has_achievement("finishedshangrila"):
		return "magakhan_beach"
	if not has_achievement("finishedcave"):
		return "cave_end"
	return "abra"


func is_island_unlocked(level_id: String) -> bool:
	if has_achievement("finishedcave"):
		return true
	match level_id:
		"abra", "graal_mountain", "treasurehunt":
			return true
		"fatamorgana_city":
			return has_achievement("unlockedfatamorgana") or has_achievement("finishedgraal")
		"magakhan_beach":
			return has_achievement("unlockedshangrila") or has_achievement("finishedfatamorgana")
		"cave_end":
			return has_achievement("unlockedcave") or has_achievement("finishedshangrila")
		_:
			return true


## Låser opp nøyaktig riktig originalt kapittel / milepæl når spilleren fullfører et nivå eller en boss.
func complete_level_story(level_id: String) -> void:
	match level_id:
		"cave":
			grant_achievement("escapedcave")
			grant_achievement("unlockedgraal")
		"graal_bosslevel":
			grant_achievement("finishedgraal")
			grant_achievement("unlockedfatamorgana")
		"fatamorgana_bosslevel":
			grant_achievement("finishedfatamorgana")
			grant_achievement("unlockedshangrila")
		"magakhan_endboss_level":
			grant_achievement("finishedshangrila")
			grant_achievement("unlockedcave")
		"cave_end_bosslevel":
			grant_achievement("finishedcave")
		"outro":
			grant_achievement("completedstory")


func get_pending_cutscene(level_id: String) -> String:
	if suppress_cutscenes:
		return ""
	if not LEVEL_CUTSCENES.has(level_id):
		return ""
	var cid: String = str(LEVEL_CUTSCENES[level_id])
	if cid in seen_cutscenes:
		return ""
	return cid


func mark_cutscene_seen(cutscene_id: String) -> void:
	if not (cutscene_id in seen_cutscenes):
		seen_cutscenes.append(cutscene_id)
		save_game()


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	emit_signal("coins_changed", coins)
	AudioManager.play_sfx("coin")


func take_damage(amount: float) -> void:
	health = clampf(health - amount, 0.0, max_health)
	emit_signal("health_changed", health, max_health)
	AudioManager.play_sfx("hit")
	if health <= 0.0:
		await get_tree().create_timer(1.5).timeout
		health = max_health
		emit_signal("health_changed", health, max_health)
		emit_signal("level_change_requested", current_level_id)


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)
	emit_signal("health_changed", health, max_health)
	AudioManager.play_sfx("pickup")


func set_air(cur: float, mx: float = 100.0) -> void:
	max_air = maxf(mx, 1.0)
	air = clampf(cur, 0.0, max_air)
	emit_signal("air_changed", air, max_air)


func equip_weapon(weapon_id: String) -> void:
	if weapon_id in unlocked_weapons:
		equipped_weapon = weapon_id
		if weapon_id == "lamp":
			lamp_enabled = not lamp_enabled
		emit_signal("weapon_changed", equipped_weapon)
		AudioManager.play_sfx("switch")


func set_objective(text: String) -> void:
	current_objective = text
	emit_signal("objective_changed", text)


func request_level(level_id: String) -> void:
	current_level_id = level_id
	if not (level_id in visited_levels):
		visited_levels.append(level_id)
	var info := LevelCatalog.get_level(level_id)
	set_objective(info.get("objective", ""))
	save_game()
	emit_signal("level_change_requested", level_id)


func apply_graphics_preset(preset: String) -> void:
	graphics_quality = preset
	var vp := get_viewport()
	match preset:
		"Medium":
			render_scale = 0.85
			ssao_enabled = false
			ssil_enabled = false
			volumetric_fog_enabled = false
			glow_enabled = true
			fog_enabled = true
			if vp:
				vp.msaa_3d = Viewport.MSAA_2X
		"High":
			render_scale = 1.0
			ssao_enabled = true
			ssil_enabled = true
			volumetric_fog_enabled = false
			glow_enabled = true
			fog_enabled = true
			if vp:
				vp.msaa_3d = Viewport.MSAA_4X
		"Ultra":
			render_scale = 1.0
			ssao_enabled = true
			ssil_enabled = true
			volumetric_fog_enabled = true
			glow_enabled = true
			fog_enabled = true
			if vp:
				vp.msaa_3d = Viewport.MSAA_4X
	if vp:
		vp.scaling_3d_scale = render_scale
	save_game()


func save_game() -> void:
	var payload := {
		"current_level_id": current_level_id,
		"health": health,
		"coins": coins,
		"equipped_weapon": equipped_weapon,
		"visited_levels": visited_levels,
		"story_achievements": story_achievements,
		"seen_cutscenes": seen_cutscenes,
		"quest_flags": quest_flags,
		"graphics_quality": graphics_quality,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t"))
		f.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	current_level_id = str(parsed.get("current_level_id", "cave"))
	health = float(parsed.get("health", 100.0))
	coins = int(parsed.get("coins", 25))
	equipped_weapon = str(parsed.get("equipped_weapon", "sword"))
	graphics_quality = str(parsed.get("graphics_quality", "Ultra"))
	var vl = parsed.get("visited_levels", ["cave"])
	if typeof(vl) == TYPE_ARRAY:
		visited_levels.clear()
		for item in vl:
			visited_levels.append(str(item))
	var sa = parsed.get("story_achievements", ["unlockedgraal"])
	if typeof(sa) == TYPE_ARRAY:
		story_achievements.clear()
		for item in sa:
			story_achievements.append(str(item))
	var sc = parsed.get("seen_cutscenes", [])
	if typeof(sc) == TYPE_ARRAY:
		seen_cutscenes.clear()
		for item in sc:
			seen_cutscenes.append(str(item))
	var qf = parsed.get("quest_flags", {})
	if typeof(qf) == TYPE_DICTIONARY:
		quest_flags = qf
