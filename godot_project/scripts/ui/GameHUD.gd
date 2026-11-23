extends CanvasLayer
class_name GameHUD
## Moderne norsk sjørøver-HUD: Helse, gullmynter, våpenlinje (1-6), oppdragsbanner, dialogboks, boss-HP og pausemeny.

var _hp_bar: ProgressBar
var _hp_label: Label
var _coin_label: Label
var _level_label: Label
var _obj_label: Label
var _weapon_buttons: Dictionary = {}

var _dialogue_panel: PanelContainer
var _dialogue_speaker: Label
var _dialogue_text: Label
var _dialogue_queue: Array = []

var _boss_panel: PanelContainer
var _boss_name_lbl: Label
var _boss_bar: ProgressBar

var _pause_panel: PanelContainer
var _is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameState.health_changed.connect(_on_health_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.weapon_changed.connect(_on_weapon_changed)
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.dialogue_requested.connect(_on_dialogue_requested)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.level_change_requested.connect(_on_level_changed)

	_on_health_changed(GameState.health, GameState.max_health)
	_on_coins_changed(GameState.coins)
	_on_weapon_changed(GameState.equipped_weapon)
	_on_level_changed(GameState.current_level_id)


func _make_panel_style(bg: Color = Color(0.07, 0.09, 0.14, 0.86), border: Color = Color(0.84, 0.65, 0.28, 0.9)) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	return st


func _build_ui() -> void:
	# 1. Topp-venstre: Helse og gullmynter
	var top_left := PanelContainer.new()
	top_left.position = Vector2(20, 20)
	top_left.custom_minimum_size = Vector2(310, 88)
	top_left.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(top_left)

	var v1 := VBoxContainer.new()
	v1.add_theme_constant_override("separation", 6)
	top_left.add_child(v1)

	var h_row := HBoxContainer.new()
	v1.add_child(h_row)
	_hp_label = Label.new()
	_hp_label.text = "Helse: 100 / 100"
	_hp_label.add_theme_font_size_override("font_size", 17)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.82))
	h_row.add_child(_hp_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(spacer)

	_coin_label = Label.new()
	_coin_label.text = "Gull: 25"
	_coin_label.add_theme_font_size_override("font_size", 18)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.22))
	h_row.add_child(_coin_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(280, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.82, 0.16, 0.18)
	fill.set_corner_radius_all(6)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	v1.add_child(_hp_bar)

	# 2. Topp-høyre: Nivånavn og gjeldende oppdrag
	var top_right := PanelContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_left = -450
	top_right.offset_right = -20
	top_right.offset_top = 20
	top_right.offset_bottom = 115
	top_right.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(top_right)

	var v2 := VBoxContainer.new()
	top_right.add_child(v2)
	_level_label = Label.new()
	_level_label.text = "Abra Havn"
	_level_label.add_theme_font_size_override("font_size", 20)
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	v2.add_child(_level_label)

	_obj_label = Label.new()
	_obj_label.text = "Utforsk Abra Havn og snakk med Kaptein Sabeltann."
	_obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_label.add_theme_font_size_override("font_size", 14)
	_obj_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	v2.add_child(_obj_label)

	# 3. Boss-helsebar (topp-senter, skjult til boss-kamp starter)
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -260
	_boss_panel.offset_right = 260
	_boss_panel.offset_top = 20
	_boss_panel.offset_bottom = 86
	_boss_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.16, 0.04, 0.06, 0.9), Color(1.0, 0.35, 0.28)))
	_boss_panel.visible = false
	add_child(_boss_panel)

	var bv := VBoxContainer.new()
	_boss_panel.add_child(bv)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lbl.add_theme_font_size_override("font_size", 18)
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.72))
	bv.add_child(_boss_name_lbl)

	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(480, 18)
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = Color(0.95, 0.22, 0.16)
	bfill.set_corner_radius_all(6)
	_boss_bar.add_theme_stylebox_override("fill", bfill)
	bv.add_child(_boss_bar)

	# 4. Bunn-senter: Våpenlinje (1-6) + hurtigtips
	var hotbar_wrap := VBoxContainer.new()
	hotbar_wrap.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_wrap.offset_left = -380
	hotbar_wrap.offset_right = 380
	hotbar_wrap.offset_top = -102
	hotbar_wrap.offset_bottom = -16
	hotbar_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hotbar_wrap)

	var hbar := HBoxContainer.new()
	hbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hbar.add_theme_constant_override("separation", 8)
	hotbar_wrap.add_child(hbar)

	var slots := [
		["1", "woodensword", "Tresverd"],
		["2", "sword", "Sabel"],
		["3", "goldsword", "Gullsverd"],
		["4", "rapier", "Kårde"],
		["5", "slingshot", "Sprettert"],
		["6", "lamp", "Lykte"],
	]
	for s in slots:
		var btn := Button.new()
		btn.text = "[%s] %s" % [s[0], s[2]]
		btn.custom_minimum_size = Vector2(114, 42)
		btn.pressed.connect(func(): GameState.equip_weapon(s[1]))
		hbar.add_child(btn)
		_weapon_buttons[s[1]] = btn

	var hint := Label.new()
	hint.text = "WASD: Beveg  |  Space: Hopp  |  Venstreklikk/F: Angrip  |  E: Snakk/Portal  |  Høyreklikk: Roter kamera  |  ESC: Meny"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82, 0.9))
	hotbar_wrap.add_child(hint)

	# 5. Dialogboks (bunn-senter over våpenlinjen)
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_panel.offset_left = -380
	_dialogue_panel.offset_right = 380
	_dialogue_panel.offset_top = -250
	_dialogue_panel.offset_bottom = -114
	_dialogue_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.08, 0.12, 0.94), Color(0.94, 0.74, 0.30)))
	_dialogue_panel.visible = false
	add_child(_dialogue_panel)

	var dv := VBoxContainer.new()
	_dialogue_panel.add_child(dv)
	_dialogue_speaker = Label.new()
	_dialogue_speaker.add_theme_font_size_override("font_size", 20)
	_dialogue_speaker.add_theme_color_override("font_color", Color(1.0, 0.84, 0.32))
	dv.add_child(_dialogue_speaker)

	_dialogue_text = Label.new()
	_dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_text.add_theme_font_size_override("font_size", 16)
	_dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_dialogue_text)

	var next_btn := Button.new()
	next_btn.text = "Neste [Enter / Mellomrom]"
	next_btn.pressed.connect(_advance_dialogue)
	dv.add_child(next_btn)

	# 6. Pause- og Nivåvelger-meny (ESC)
	_build_pause_menu()


func _build_pause_menu() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -320
	_pause_panel.offset_right = 320
	_pause_panel.offset_top = -280
	_pause_panel.offset_bottom = 280
	_pause_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.07, 0.11, 0.96), Color(0.92, 0.72, 0.28)))
	_pause_panel.visible = false
	add_child(_pause_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_pause_panel.add_child(pv)

	var title := Label.new()
	title.text = "PAUSE – KAPTEIN SABELTANN HD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	pv.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Fortsett spillet"
	resume_btn.custom_minimum_size = Vector2(0, 40)
	resume_btn.pressed.connect(_toggle_pause)
	pv.add_child(resume_btn)

	# Grafikk-kvalitet
	var gfx_row := HBoxContainer.new()
	gfx_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var gfx_lbl := Label.new()
	gfx_lbl.text = "Grafikk: "
	gfx_row.add_child(gfx_lbl)
	for preset in ["Medium", "High", "Ultra"]:
		var gb := Button.new()
		gb.text = preset
		gb.pressed.connect(func(): GameState.apply_graphics_preset(preset))
		gfx_row.add_child(gb)
	pv.add_child(gfx_row)

	var sep := Label.new()
	sep.text = "Hurtigreise til nivå:"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	pv.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	for lid in LevelCatalog.ORDERED_LEVEL_IDS:
		var info := LevelCatalog.get_level(lid)
		var lb := Button.new()
		lb.text = str(info.get("title", lid))
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.pressed.connect(func():
			_toggle_pause()
			GameState.request_level(lid)
		)
		grid.add_child(lb)

	var menu_btn := Button.new()
	menu_btn.text = "Tilbake til hovedmeny"
	menu_btn.custom_minimum_size = Vector2(0, 38)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	pv.add_child(menu_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _dialogue_panel.visible:
			_dialogue_panel.visible = false
			_dialogue_queue.clear()
		else:
			_toggle_pause()
	elif _dialogue_panel.visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")):
		_advance_dialogue()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	_is_paused = not _is_paused
	_pause_panel.visible = _is_paused
	get_tree().paused = _is_paused


func _on_health_changed(cur: float, mx: float) -> void:
	_hp_bar.max_value = mx
	_hp_bar.value = cur
	_hp_label.text = "Helse: %d / %d" % [int(cur), int(mx)]


func _on_coins_changed(coins: int) -> void:
	_coin_label.text = "Gull: %d" % coins


func _on_weapon_changed(weapon_id: String) -> void:
	for k in _weapon_buttons.keys():
		var b: Button = _weapon_buttons[k]
		if k == weapon_id:
			b.modulate = Color(1.0, 0.88, 0.35)
		else:
			b.modulate = Color(0.75, 0.78, 0.85)


func _on_objective_changed(text: String) -> void:
	_obj_label.text = text


func _on_level_changed(level_id: String) -> void:
	var info := LevelCatalog.get_level(level_id)
	_level_label.text = str(info.get("title", level_id))
	_boss_panel.visible = false


func _on_dialogue_requested(speaker: String, lines: Array) -> void:
	_dialogue_speaker.text = speaker
	_dialogue_queue = lines.duplicate()
	_advance_dialogue()


func _advance_dialogue() -> void:
	if _dialogue_queue.is_empty():
		_dialogue_panel.visible = false
		return
	_dialogue_text.text = str(_dialogue_queue.pop_front())
	_dialogue_panel.visible = true


func _on_boss_health_changed(boss_name: String, cur: float, mx: float) -> void:
	if boss_name == "" or mx <= 0.0:
		_boss_panel.visible = false
		return
	_boss_panel.visible = true
	_boss_name_lbl.text = boss_name
	_boss_bar.max_value = mx
	_boss_bar.value = cur
