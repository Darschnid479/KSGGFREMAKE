extends Node
## Global spilltilstand (port av gameManager.ls + inventoryManager.ls + serialisation.ls).

signal health_changed(current: float, maximum: float)
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

var current_level_id: String = "abra"
var max_health: float = 100.0
var health: float = 100.0
var coins: int = 25
var equipped_weapon: String = "sword"
var unlocked_weapons: Array[String] = ["woodensword", "sword", "slingshot", "lamp", "goldsword", "rapier"]
var visited_levels: Array[String] = ["abra"]
var quest_flags: Dictionary = {}
var current_objective: String = ""
var lamp_enabled: bool = false

# Moderne HD grafikkinnstillinger (kan justeres i menyen)
var graphics_quality: String = "Ultra" # "Medium", "High", "Ultra"
var render_scale: float = 1.0
var ssao_enabled: bool = true
var glow_enabled: bool = true
var fog_enabled: bool = true
var mouse_sensitivity: float = 0.0028


func _ready() -> void:
	load_game()


func reset_new_game(start_level: String = "abra") -> void:
	current_level_id = start_level
	health = max_health
	coins = 25
	equipped_weapon = "sword"
	visited_levels = [start_level]
	quest_flags = {}
	lamp_enabled = false
	var info := LevelCatalog.get_level(start_level)
	current_objective = info.get("objective", "")
	emit_signal("health_changed", health, max_health)
	emit_signal("coins_changed", coins)
	emit_signal("weapon_changed", equipped_weapon)
	emit_signal("objective_changed", current_objective)
	save_game()


func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)
	emit_signal("coins_changed", coins)
	AudioManager.play_sfx("coin")


func take_damage(amount: float) -> void:
	health = clamp(health - amount, 0.0, max_health)
	emit_signal("health_changed", health, max_health)
	AudioManager.play_sfx("hit")
	if health <= 0.0:
		# Respawn med full helse på samme nivå
		await get_tree().create_timer(1.5).timeout
		health = max_health
		emit_signal("health_changed", health, max_health)
		emit_signal("level_change_requested", current_level_id)


func heal(amount: float) -> void:
	health = clamp(health + amount, 0.0, max_health)
	emit_signal("health_changed", health, max_health)
	AudioManager.play_sfx("pickup")


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
			glow_enabled = true
			fog_enabled = true
			if vp:
				vp.msaa_3d = Viewport.MSAA_2X
		"High":
			render_scale = 1.0
			ssao_enabled = true
			glow_enabled = true
			fog_enabled = true
			if vp:
				vp.msaa_3d = Viewport.MSAA_4X
		"Ultra":
			render_scale = 1.0
			ssao_enabled = true
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
	current_level_id = str(parsed.get("current_level_id", "abra"))
	health = float(parsed.get("health", 100.0))
	coins = int(parsed.get("coins", 25))
	equipped_weapon = str(parsed.get("equipped_weapon", "sword"))
	graphics_quality = str(parsed.get("graphics_quality", "Ultra"))
	var vl = parsed.get("visited_levels", ["abra"])
	if typeof(vl) == TYPE_ARRAY:
		visited_levels.clear()
		for item in vl:
			visited_levels.append(str(item))
	var qf = parsed.get("quest_flags", {})
	if typeof(qf) == TYPE_DICTIONARY:
		quest_flags = qf
