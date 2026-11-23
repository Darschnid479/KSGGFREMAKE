extends CanvasLayer
class_name GameHUD
## 1:1 original-tro HUD fra Kaptein Sabeltann og Grusomme Gabriels forbannelse (getWidgetData_hud.ls):
## - Bunn-venstre: Pinkys runde helsemedaljong med buet rød helsemåler + gullmynt-teller
## - Bunn-høyre: Kontekstuell handlingsmedaljong ([E]) når spilleren er nær NPC/portal
## - Dialogboks og boss-helsebar kun når aktivt i bruk (ingen våpenlinje 1-6 eller RPG-bokser).

class PirateHealthMedallion extends Control:
	var health_ratio: float = 1.0
	var portrait_tex: Texture2D = null

	func _init() -> void:
		custom_minimum_size = Vector2(158, 158)
		if ResourceLoader.exists("res://assets/ui/pinky_portrait.png"):
			portrait_tex = load("res://assets/ui/pinky_portrait.png") as Texture2D

	func set_ratio(r: float) -> void:
		health_ratio = clampf(r, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(79, 79)
		# Ytre mørk slitt eik + antikk messingramme
		draw_circle(c, 71.0, Color(0.08, 0.05, 0.03, 0.92))
		draw_arc(c, 71.0, 0.0, TAU, 72, Color(0.68, 0.50, 0.22, 0.96), 3.5, true)
		draw_arc(c, 67.5, 0.0, TAU, 72, Color(0.28, 0.19, 0.08, 0.95), 2.5, true)

		# Mørkt spor for buet helsemåler
		var start_a := PI * 0.72
		var sweep := PI * 1.56
		draw_arc(c, 58.0, start_a, start_a + sweep, 56, Color(0.18, 0.08, 0.06, 0.92), 13.0, true)

		# Aktiv dyp karmosinrød helsebue med gyllen kantglans
		if health_ratio > 0.01:
			var fill_col := Color(0.76, 0.11, 0.10, 1.0) if health_ratio > 0.3 else Color(0.95, 0.28, 0.08, 1.0)
			draw_arc(c, 58.0, start_a, start_a + sweep * health_ratio, 56, fill_col, 10.0, true)
			draw_arc(c, 60.5, start_a, start_a + sweep * health_ratio, 56, Color(1.0, 0.62, 0.42, 0.35), 2.0, true)

		# Live-action portrett av Pinky i midten
		if portrait_tex:
			draw_texture_rect(portrait_tex, Rect2(c - Vector2(46, 46), Vector2(92, 92)), false)
		else:
			draw_circle(c, 46.0, Color(0.14, 0.18, 0.26, 0.98))

		# Indre antikk messingring rundt portrettet
		draw_arc(c, 47.0, 0.0, TAU, 64, Color(0.78, 0.58, 0.24, 0.98), 3.2, true)
		draw_arc(c, 45.0, 0.0, TAU, 64, Color(0.14, 0.09, 0.04, 0.85), 1.5, true)


class GoldCoinBadge extends Control:
	var coin_tex: Texture2D = null

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		if ResourceLoader.exists("res://assets/ui/gold_doubloon.png"):
			coin_tex = load("res://assets/ui/gold_doubloon.png") as Texture2D

	func _draw() -> void:
		if coin_tex:
			draw_texture_rect(coin_tex, Rect2(Vector2(4, 4), Vector2(56, 56)), false)
		else:
			var cc := Vector2(32, 32)
			draw_circle(cc, 24.0, Color(0.78, 0.58, 0.14, 0.96))


var _medallion: PirateHealthMedallion
var _coin_badge: GoldCoinBadge
var _coin_label: Label
var _action_panel: PanelContainer
var _action_label: Label

var _dialogue_panel: PanelContainer
var _dialogue_speaker: Label
var _dialogue_text: Label
var _dialogue_queue: Array = []

var _boss_panel: PanelContainer
var _boss_name_lbl: Label
var _boss_bar: ProgressBar

var _air_panel: PanelContainer
var _air_bar: ProgressBar

var _subtitle_panel: PanelContainer
var _subtitle_speaker: Label
var _subtitle_text: Label

var _pause_panel: PanelContainer
var _voice_btn_no: Button
var _voice_btn_orig: Button
var _is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameState.health_changed.connect(_on_health_changed)
	GameState.air_changed.connect(_on_air_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.dialogue_requested.connect(_on_dialogue_requested)
	GameState.voice_line_started.connect(_on_voice_line_started)
	GameState.voice_line_finished.connect(_on_voice_line_finished)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.level_change_requested.connect(_on_level_changed)

	_on_health_changed(GameState.health, GameState.max_health)
	_on_air_changed(GameState.air, GameState.max_air)
	_on_coins_changed(GameState.coins)
	_on_level_changed(GameState.current_level_id)


func _make_panel_style(bg: Color = Color(0.11, 0.07, 0.04, 0.92), border: Color = Color(0.84, 0.64, 0.26, 0.95)) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	return st


func _build_ui() -> void:
	# 1. Bunn-venstre: Original 1:1 Pinky live-action helsemedaljong + Gullmynter
	var bl := HBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 22
	bl.offset_right = 360
	bl.offset_top = -178
	bl.offset_bottom = -16
	bl.alignment = BoxContainer.ALIGNMENT_BEGIN
	bl.add_theme_constant_override("separation", 10)
	add_child(bl)

	_medallion = PirateHealthMedallion.new()
	bl.add_child(_medallion)

	var coin_wrap := HBoxContainer.new()
	coin_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	coin_wrap.add_theme_constant_override("separation", 8)
	bl.add_child(coin_wrap)

	_coin_badge = GoldCoinBadge.new()
	coin_wrap.add_child(_coin_badge)

	_coin_label = Label.new()
	_coin_label.text = "25"
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 30)
	_coin_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.34))
	_coin_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.96))
	_coin_label.add_theme_constant_override("outline_size", 7)
	coin_wrap.add_child(_coin_label)

	# 2. Bunn-høyre: Kontekstuelt handlingsikon (tilsvarer actionicon i originalen, skjult til man er nær NPC/portal)
	_action_panel = PanelContainer.new()
	_action_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_panel.offset_left = -210
	_action_panel.offset_right = -26
	_action_panel.offset_top = -84
	_action_panel.offset_bottom = -26
	_action_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_action_panel.visible = false
	add_child(_action_panel)

	_action_label = Label.new()
	_action_label.text = "[E] Snakk"
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 18)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	_action_panel.add_child(_action_label)

	# 3. Boss-helsebar (topp-senter, kun synlig i bosskamper som i cave_boss_hud / graal_boss_hud)
	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.offset_left = -260
	_boss_panel.offset_right = 260
	_boss_panel.offset_top = 22
	_boss_panel.offset_bottom = 86
	_boss_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.16, 0.05, 0.05, 0.92), Color(0.95, 0.35, 0.25)))
	_boss_panel.visible = false
	add_child(_boss_panel)

	var bv := VBoxContainer.new()
	_boss_panel.add_child(bv)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lbl.add_theme_font_size_override("font_size", 18)
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.68))
	bv.add_child(_boss_name_lbl)

	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.custom_minimum_size = Vector2(480, 18)
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = Color(0.92, 0.18, 0.14)
	bfill.set_corner_radius_all(6)
	_boss_bar.add_theme_stylebox_override("fill", bfill)
	bv.add_child(_boss_bar)

	# 3B. Undervanns-luftmåler (1:1 swimming_hud: kun synlig i 2D-svømmenivåer!)
	_air_panel = PanelContainer.new()
	_air_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_air_panel.offset_left = 26
	_air_panel.offset_right = 310
	_air_panel.offset_top = 24
	_air_panel.offset_bottom = 84
	_air_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.14, 0.22, 0.90), Color(0.32, 0.86, 0.98, 0.95)))
	_air_panel.visible = false
	add_child(_air_panel)

	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 4)
	_air_panel.add_child(av)
	var air_lbl := Label.new()
	air_lbl.text = "LUFT"
	air_lbl.add_theme_font_size_override("font_size", 14)
	air_lbl.add_theme_color_override("font_color", Color(0.68, 0.96, 1.0))
	av.add_child(air_lbl)

	_air_bar = ProgressBar.new()
	_air_bar.show_percentage = false
	_air_bar.max_value = 100.0
	_air_bar.value = 100.0
	_air_bar.custom_minimum_size = Vector2(246, 16)
	var abg := StyleBoxFlat.new()
	abg.bg_color = Color(0.02, 0.08, 0.14, 0.95)
	abg.set_corner_radius_all(6)
	var afill := StyleBoxFlat.new()
	afill.bg_color = Color(0.18, 0.84, 0.98)
	afill.set_corner_radius_all(6)
	_air_bar.add_theme_stylebox_override("background", abg)
	_air_bar.add_theme_stylebox_override("fill", afill)
	av.add_child(_air_bar)

	# 4. Dialogboks (kun synlig når man snakker med karakterer)
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_panel.offset_left = -360
	_dialogue_panel.offset_right = 360
	_dialogue_panel.offset_top = -170
	_dialogue_panel.offset_bottom = -28
	_dialogue_panel.add_theme_stylebox_override("panel", _make_panel_style())
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
	next_btn.text = "Neste [Enter / E]"
	next_btn.pressed.connect(_advance_dialogue)
	dv.add_child(next_btn)

	# 4B. Kinematisk undertekst-banner for norske karakterstemmer (vises automatisk mens noen snakker!)
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.offset_left = -430
	_subtitle_panel.offset_right = 430
	_subtitle_panel.offset_top = -134
	_subtitle_panel.offset_bottom = -24
	var sub_style := StyleBoxFlat.new()
	sub_style.bg_color = Color(0.06, 0.04, 0.03, 0.88)
	sub_style.border_color = Color(0.86, 0.66, 0.26, 0.90)
	sub_style.set_border_width_all(2)
	sub_style.set_corner_radius_all(10)
	sub_style.content_margin_left = 22
	sub_style.content_margin_right = 22
	sub_style.content_margin_top = 10
	sub_style.content_margin_bottom = 10
	_subtitle_panel.add_theme_stylebox_override("panel", sub_style)
	_subtitle_panel.visible = false
	add_child(_subtitle_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	_subtitle_panel.add_child(sv)

	var top_sub := HBoxContainer.new()
	sv.add_child(top_sub)

	_subtitle_speaker = Label.new()
	_subtitle_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_speaker.add_theme_font_size_override("font_size", 19)
	_subtitle_speaker.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	_subtitle_speaker.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01, 0.95))
	_subtitle_speaker.add_theme_constant_override("outline_size", 4)
	top_sub.add_child(_subtitle_speaker)

	var skip_hint := Label.new()
	skip_hint.text = "[Tab] Neste"
	skip_hint.add_theme_font_size_override("font_size", 13)
	skip_hint.add_theme_color_override("font_color", Color(0.76, 0.72, 0.62, 0.85))
	top_sub.add_child(skip_hint)

	_subtitle_text = Label.new()
	_subtitle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_text.add_theme_font_size_override("font_size", 18)
	_subtitle_text.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	_subtitle_text.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	_subtitle_text.add_theme_constant_override("outline_size", 3)
	sv.add_child(_subtitle_text)

	# 5. Pausemeny (ESC – enkel 1:1 uten jukse-nivåvelger)
	_build_pause_menu()


func _build_pause_menu() -> void:
	_pause_panel = PanelContainer.new()
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -245
	_pause_panel.offset_right = 245
	_pause_panel.offset_top = -185
	_pause_panel.offset_bottom = 185
	_pause_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_pause_panel.visible = false
	add_child(_pause_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	_pause_panel.add_child(pv)

	var title := Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	pv.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "Fortsett spillet"
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.pressed.connect(_toggle_pause)
	pv.add_child(resume_btn)

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

	var voice_row := HBoxContainer.new()
	voice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var v_lbl := Label.new()
	v_lbl.text = "Stemmer: "
	voice_row.add_child(v_lbl)
	_voice_btn_no = Button.new()
	_voice_btn_orig = Button.new()
	_voice_btn_no.pressed.connect(func():
		GameState.voice_language = "no"
		GameState.save_game()
		_refresh_pause_voice_buttons()
	)
	_voice_btn_orig.pressed.connect(func():
		GameState.voice_language = "orig"
		GameState.save_game()
		_refresh_pause_voice_buttons()
	)
	voice_row.add_child(_voice_btn_no)
	voice_row.add_child(_voice_btn_orig)
	pv.add_child(voice_row)
	_refresh_pause_voice_buttons()

	var menu_btn := Button.new()
	menu_btn.text = "Tilbake til hovedmeny"
	menu_btn.custom_minimum_size = Vector2(0, 42)
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	pv.add_child(menu_btn)


func _refresh_pause_voice_buttons() -> void:
	if is_instance_valid(_voice_btn_no):
		_voice_btn_no.text = ("★ Norsk" if GameState.voice_language == "no" else "Norsk")
	if is_instance_valid(_voice_btn_orig):
		_voice_btn_orig.text = ("★ Original CD" if GameState.voice_language == "orig" else "Original CD")


func _process(_delta: float) -> void:
	# Vis kontekstuelt handlingsikon nederst til høyre når Pinky er nær NPC/portal/historie-objekt
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or _dialogue_panel.visible or _is_paused:
		_action_panel.visible = false
		return
	var p := players[0] as Node3D
	if not is_instance_valid(p):
		_action_panel.visible = false
		return
	var nearest_txt := ""
	var best_d := 5.0
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D:
			var d := p.global_position.distance_to((node as Node3D).global_position)
			if d < best_d:
				best_d = d
				if node is PortalTrigger:
					nearest_txt = "[E] " + (node as PortalTrigger).portal_label
				elif node is NpcActor:
					nearest_txt = "[E] " + (node as NpcActor).display_name
				elif node.has_method("get_interact_prompt"):
					nearest_txt = str(node.call("get_interact_prompt"))
				else:
					nearest_txt = "[E] Bruk"
	_action_panel.visible = (nearest_txt != "")
	if nearest_txt != "":
		_action_label.text = nearest_txt


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
	if _is_paused:
		_refresh_pause_voice_buttons()
	get_tree().paused = _is_paused


func _on_health_changed(cur: float, mx: float) -> void:
	if is_instance_valid(_medallion) and mx > 0.0:
		_medallion.set_ratio(cur / mx)


func _on_air_changed(cur: float, mx: float) -> void:
	if is_instance_valid(_air_bar) and mx > 0.0:
		_air_bar.max_value = mx
		_air_bar.value = cur


func _on_coins_changed(coins: int) -> void:
	if is_instance_valid(_coin_label):
		_coin_label.text = "%d" % coins


func _on_level_changed(level_id: String) -> void:
	if is_instance_valid(_boss_panel):
		_boss_panel.visible = false
	if is_instance_valid(_subtitle_panel):
		_subtitle_panel.visible = false
	if is_instance_valid(_air_panel):
		var cfg := LevelCatalog.get_level(level_id)
		_air_panel.visible = (str(cfg.get("mode", "")) == "swimming")


func _on_voice_line_started(speaker_name: String, text: String, _clip_key: String) -> void:
	if not is_instance_valid(_subtitle_panel):
		return
	if text.strip_edges() == "":
		_subtitle_panel.visible = false
		return
	_subtitle_speaker.text = speaker_name if speaker_name != "" else "Forteller"
	_subtitle_text.text = text
	_subtitle_panel.visible = true


func _on_voice_line_finished(_clip_key: String) -> void:
	if is_instance_valid(_subtitle_panel) and not AudioManager.is_voice_playing():
		_subtitle_panel.visible = false


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
