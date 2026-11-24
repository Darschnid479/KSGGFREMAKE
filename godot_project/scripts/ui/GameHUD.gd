extends CanvasLayer
class_name GameHUD
## 2026 Stilisert 1:1 original-tro HUD for Kaptein Sabeltann og Grusomme Gabriels forbannelse:
## - Verdenskart: revet pergamentramme (world_map_overlay.png) + Den Sorte Dame-medaljong (hud_ship_medallion.png)
## - På land/vann: Pinky-medaljong (hud_pinky_medallion.png) med buet rød anker-helsemåler + gull- og sølvmynt
## - Bunn-høyre: Kontekstuelt originalt handlingsikon (hud_action_*.png) nær NPC/portal/objekt
## - Boss-helsebar (hud_boss_*.png) og undervanns-luftmåler (hud_underwater_bar.png) kun når aktivt i bruk.

class PirateHealthMedallion extends Control:
	var health_ratio: float = 1.0
	var is_ship_mode: bool = false
	var pinky_tex: Texture2D = null
	var ship_tex: Texture2D = null
	var bar_tex: Texture2D = null

	func _init() -> void:
		custom_minimum_size = Vector2(182, 182)
		if ResourceLoader.exists("res://assets/ui/hud_pinky_medallion.png"):
			pinky_tex = load("res://assets/ui/hud_pinky_medallion.png") as Texture2D
		if ResourceLoader.exists("res://assets/ui/hud_ship_medallion.png"):
			ship_tex = load("res://assets/ui/hud_ship_medallion.png") as Texture2D
		if ResourceLoader.exists("res://assets/ui/hud_healthbar_full.png"):
			bar_tex = load("res://assets/ui/hud_healthbar_full.png") as Texture2D

	func set_ratio(r: float) -> void:
		health_ratio = clampf(r, 0.0, 1.0)
		queue_redraw()

	func set_ship_mode(ship: bool) -> void:
		is_ship_mode = ship
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var frame_tex := ship_tex if (is_ship_mode and ship_tex != null) else pinky_tex
		# Anker-utskjæringen i hud_pinky_medallion.png / hud_ship_medallion.png (målt eksakt mot original-alfakanal)
		var bar_rect := Rect2(
			Vector2(w * 0.038, h * (0.375 if is_ship_mode else 0.365)),
			Vector2(w * 0.855, h * (0.565 if is_ship_mode else 0.565))
		)
		if bar_tex:
			# Mørkt tomt anker-spor bak
			draw_texture_rect(bar_tex, bar_rect, false, Color(0.18, 0.05, 0.04, 0.86))
			# Aktiv rød helsefylling beskåret langs buen fra venstre mot høyre etter helseprosent
			if health_ratio > 0.01:
				var tw := float(bar_tex.get_width())
				var th := float(bar_tex.get_height())
				var src_w := maxf(tw * health_ratio, 2.0)
				var dst_w := bar_rect.size.x * health_ratio
				var tint := Color(1.0, 1.0, 1.0, 1.0) if health_ratio > 0.3 else Color(1.0, 0.55, 0.25, 1.0)
				draw_texture_rect_region(
					bar_tex,
					Rect2(bar_rect.position, Vector2(dst_w, bar_rect.size.y)),
					Rect2(Vector2.ZERO, Vector2(src_w, th)),
					tint
				)
		if frame_tex:
			draw_texture_rect(frame_tex, Rect2(Vector2.ZERO, Vector2(w, h)), false)


class PirateBossBar extends Control:
	var ratio: float = 1.0
	var boss_title: String = ""
	var frame_tex: Texture2D = null
	var _frames: Dictionary = {}

	func _init() -> void:
		custom_minimum_size = Vector2(540, 138)
		for k in ["graal", "cave", "fatamorgana", "mk"]:
			var p := "res://assets/ui/hud_boss_%s.png" % k
			if ResourceLoader.exists(p):
				_frames[k] = load(p) as Texture2D
		frame_tex = _frames.get("graal", null)

	func set_boss(title: String, cur: float, mx: float, level_id: String) -> void:
		boss_title = title
		ratio = clampf(cur / maxf(mx, 0.001), 0.0, 1.0)
		if "cave" in level_id:
			frame_tex = _frames.get("cave", frame_tex)
		elif "fatamorgana" in level_id:
			frame_tex = _frames.get("fatamorgana", frame_tex)
		elif "magakhan" in level_id:
			frame_tex = _frames.get("mk", frame_tex)
		else:
			frame_tex = _frames.get("graal", frame_tex)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if frame_tex:
			draw_texture_rect(frame_tex, Rect2(Vector2.ZERO, Vector2(w, h)), false)
			# Fyll selve målersporet inni gullrammen
			var tx := w * 0.228
			var ty := h * 0.655
			var tw := w * 0.728
			var th := h * 0.175
			draw_rect(Rect2(tx, ty, tw, th), Color(0.14, 0.04, 0.04, 0.85), true)
			if ratio > 0.005:
				draw_rect(Rect2(tx, ty, tw * ratio, th), Color(0.88, 0.16, 0.10, 0.98), true)
				draw_rect(Rect2(tx, ty, tw * ratio, th * 0.34), Color(1.0, 0.60, 0.36, 0.45), true)


class PirateAirBar extends Control:
	var ratio: float = 1.0
	var frame_tex: Texture2D = null

	func _init() -> void:
		custom_minimum_size = Vector2(316, 105)
		if ResourceLoader.exists("res://assets/ui/hud_underwater_bar.png"):
			frame_tex = load("res://assets/ui/hud_underwater_bar.png") as Texture2D

	func set_ratio(r: float) -> void:
		ratio = clampf(r, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if frame_tex:
			draw_texture_rect(frame_tex, Rect2(Vector2.ZERO, Vector2(w, h)), false)
			var tx := w * 0.242
			var ty := h * 0.635
			var tw := w * 0.715
			var th := h * 0.175
			if ratio > 0.005:
				var col := Color(0.16, 0.82, 0.98, 0.96) if ratio > 0.28 else Color(1.0, 0.32, 0.18, 0.96)
				draw_rect(Rect2(tx, ty, tw * ratio, th), col, true)
				draw_rect(Rect2(tx, ty, tw * ratio, th * 0.36), Color(0.75, 0.98, 1.0, 0.50), true)


var _world_map_frame: TextureRect
var _medallion: PirateHealthMedallion
var _gold_icon: TextureRect
var _coin_label: Label
var _silver_icon: TextureRect
var _silver_label: Label

var _action_box: HBoxContainer
var _action_icon: TextureRect
var _action_panel: PanelContainer
var _action_label: Label
var _action_texs: Dictionary = {}

var _boss_wrap: Control
var _boss_widget: PirateBossBar
var _boss_name_lbl: Label

var _air_widget: PirateAirBar

var _dialogue_panel: PanelContainer
var _dialogue_speaker: Label
var _dialogue_text: Label
var _dialogue_queue: Array = []

var _shop_panel: PanelContainer
var _shop_title_lbl: Label
var _shop_coins_lbl: Label
var _shop_list: VBoxContainer
var _shop_items: Array = []

var _subtitle_panel: PanelContainer
var _subtitle_speaker: Label
var _subtitle_text: Label

var _pause_panel: PanelContainer
var _voice_btn_no: Button
var _voice_btn_orig: Button
var _is_paused: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preload_action_icons()
	_build_ui()
	GameState.health_changed.connect(_on_health_changed)
	GameState.air_changed.connect(_on_air_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.weapon_changed.connect(_on_weapon_changed)
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.shop_requested.connect(_on_shop_requested)
	GameState.dialogue_requested.connect(_on_dialogue_requested)
	GameState.voice_line_started.connect(_on_voice_line_started)
	GameState.voice_line_finished.connect(_on_voice_line_finished)
	GameState.boss_health_changed.connect(_on_boss_health_changed)
	GameState.level_change_requested.connect(_on_level_changed)

	_on_health_changed(GameState.health, GameState.max_health)
	_on_air_changed(GameState.air, GameState.max_air)
	_on_coins_changed(GameState.coins)
	_on_level_changed(GameState.current_level_id)


func _preload_action_icons() -> void:
	for k in ["talk", "portal", "travel", "underwater", "shop", "sword", "climb", "dig", "gong", "jump", "pickup", "pushpull"]:
		var p := "res://assets/ui/hud_action_%s.png" % k
		if ResourceLoader.exists(p):
			_action_texs[k] = load(p) as Texture2D


func _make_panel_style(bg: Color = Color(0.11, 0.07, 0.04, 0.90), border: Color = Color(0.86, 0.66, 0.24, 0.96)) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	return st


func _build_ui() -> void:
	# 0. Verdenskartets ikoniske revne pergamentramme (kun synlig på world_map!)
	_world_map_frame = TextureRect.new()
	_world_map_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world_map_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_world_map_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_world_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://assets/ui/world_map_overlay.png"):
		_world_map_frame.texture = load("res://assets/ui/world_map_overlay.png") as Texture2D
	_world_map_frame.visible = false
	add_child(_world_map_frame)

	# 1. Bunn-venstre: Original 1:1 Pinky/Skute-medaljong med rød anker-helsemåler + gull- og sølvmynt
	var bl := HBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 18
	bl.offset_right = 440
	bl.offset_top = -196
	bl.offset_bottom = -12
	bl.alignment = BoxContainer.ALIGNMENT_BEGIN
	bl.add_theme_constant_override("separation", 6)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bl)

	_medallion = PirateHealthMedallion.new()
	_medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(_medallion)

	var coin_wrap := HBoxContainer.new()
	coin_wrap.size_flags_vertical = Control.SIZE_SHRINK_END
	coin_wrap.add_theme_constant_override("separation", 8)
	coin_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(coin_wrap)

	_gold_icon = TextureRect.new()
	_gold_icon.custom_minimum_size = Vector2(44, 48)
	_gold_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/gold_doubloon.png"):
		_gold_icon.texture = load("res://assets/ui/gold_doubloon.png") as Texture2D
	coin_wrap.add_child(_gold_icon)

	_coin_label = Label.new()
	_coin_label.text = "25"
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 28)
	_coin_label.add_theme_color_override("font_color", Color(0.99, 0.88, 0.44))
	_coin_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.96))
	_coin_label.add_theme_constant_override("outline_size", 7)
	coin_wrap.add_child(_coin_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 1)
	coin_wrap.add_child(spacer)

	_silver_icon = TextureRect.new()
	_silver_icon.custom_minimum_size = Vector2(40, 46)
	_silver_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_silver_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists("res://assets/ui/silver_coin.png"):
		_silver_icon.texture = load("res://assets/ui/silver_coin.png") as Texture2D
	coin_wrap.add_child(_silver_icon)

	_silver_label = Label.new()
	_silver_label.text = "0"
	_silver_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_silver_label.add_theme_font_size_override("font_size", 26)
	_silver_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94))
	_silver_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.96))
	_silver_label.add_theme_constant_override("outline_size", 7)
	coin_wrap.add_child(_silver_label)

	# 2. Bunn-høyre: Kontekstuelt originalt gull-handlingsikon + klar norsk tekst (kun nær interaksjon!)
	_action_box = HBoxContainer.new()
	_action_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_action_box.offset_left = -430
	_action_box.offset_right = -24
	_action_box.offset_top = -108
	_action_box.offset_bottom = -20
	_action_box.alignment = BoxContainer.ALIGNMENT_END
	_action_box.add_theme_constant_override("separation", 10)
	_action_box.visible = false
	_action_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_action_box)

	_action_panel = PanelContainer.new()
	_action_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_action_box.add_child(_action_panel)

	_action_label = Label.new()
	_action_label.text = "[E] Snakk"
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_size_override("font_size", 17)
	_action_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.50))
	_action_panel.add_child(_action_label)

	_action_icon = TextureRect.new()
	_action_icon.custom_minimum_size = Vector2(78, 78)
	_action_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_action_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_action_icon.texture = _action_texs.get("talk", null)
	_action_box.add_child(_action_icon)

	# 3. Boss-helsebar (topp-senter med originalt 2007 boss-portrett og gullramme, kun i bosskamper!)
	_boss_wrap = Control.new()
	_boss_wrap.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_wrap.offset_left = -270
	_boss_wrap.offset_right = 270
	_boss_wrap.offset_top = 14
	_boss_wrap.offset_bottom = 152
	_boss_wrap.visible = false
	_boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_wrap)

	_boss_widget = PirateBossBar.new()
	_boss_widget.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_wrap.add_child(_boss_widget)

	_boss_name_lbl = Label.new()
	_boss_name_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_name_lbl.offset_left = 128
	_boss_name_lbl.offset_right = -24
	_boss_name_lbl.offset_top = 48
	_boss_name_lbl.offset_bottom = 78
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_name_lbl.add_theme_font_size_override("font_size", 21)
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.58))
	_boss_name_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.02, 0.96))
	_boss_name_lbl.add_theme_constant_override("outline_size", 6)
	_boss_wrap.add_child(_boss_name_lbl)

	# 3B. Undervanns-luftmåler (1:1 original såpeboble-luftmåler, kun i 2D-svømmenivåer!)
	_air_widget = PirateAirBar.new()
	_air_widget.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_air_widget.offset_left = 20
	_air_widget.offset_right = 336
	_air_widget.offset_top = 14
	_air_widget.offset_bottom = 119
	_air_widget.visible = false
	_air_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_air_widget)

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

	# 4B. Kinematisk undertekst-banner for norske karakterstemmer
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle_panel.offset_left = -340
	_subtitle_panel.offset_right = 340
	_subtitle_panel.offset_top = -148
	_subtitle_panel.offset_bottom = -32
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

	# 5. Sjørøverbutikk & Pausemeny (ESC)
	_build_shop_menu()
	_build_pause_menu()


func _build_shop_menu() -> void:
	_shop_panel = PanelContainer.new()
	_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	_shop_panel.offset_left = -280
	_shop_panel.offset_right = 280
	_shop_panel.offset_top = -180
	_shop_panel.offset_bottom = 180
	_shop_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_shop_panel.visible = false
	add_child(_shop_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	_shop_panel.add_child(sv)

	_shop_title_lbl = Label.new()
	_shop_title_lbl.text = "Kjøpmannens Sjørøverbutikk"
	_shop_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_title_lbl.add_theme_font_size_override("font_size", 22)
	_shop_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	sv.add_child(_shop_title_lbl)

	_shop_coins_lbl = Label.new()
	_shop_coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coins_lbl.add_theme_font_size_override("font_size", 16)
	_shop_coins_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	sv.add_child(_shop_coins_lbl)

	_shop_list = VBoxContainer.new()
	_shop_list.add_theme_constant_override("separation", 8)
	sv.add_child(_shop_list)

	var close_btn := Button.new()
	close_btn.text = "Lukk butikk [ESC]"
	close_btn.custom_minimum_size = Vector2(0, 38)
	close_btn.pressed.connect(func(): _shop_panel.visible = false)
	sv.add_child(close_btn)


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
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty() or _dialogue_panel.visible or _shop_panel.visible or _is_paused:
		_action_box.visible = false
		return
	var p := players[0] as Node3D
	if not is_instance_valid(p):
		_action_box.visible = false
		return
	var is_boat := (GameState.current_level_id == "world_map")
	var nearest_txt := ""
	var action_key := "talk"
	var best_d := 42.0 if is_boat else 5.0
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D:
			var d := p.global_position.distance_to((node as Node3D).global_position)
			if d < best_d:
				best_d = d
				if node is PortalTrigger:
					var pt := node as PortalTrigger
					nearest_txt = "[E] " + pt.portal_label
					action_key = "underwater" if ("underwater" in pt.target_level_id or "brønn" in pt.portal_label.to_lower() or "dykk" in pt.portal_label.to_lower()) else ("travel" if is_boat else "portal")
				elif node is NpcActor:
					var na := node as NpcActor
					nearest_txt = "[E] " + na.display_name
					action_key = "shop" if ("kjøpmann" in na.display_name.to_lower() or "shop" in na.npc_id.to_lower()) else "talk"
				elif node.has_method("get_interact_prompt"):
					nearest_txt = str(node.call("get_interact_prompt"))
					var low := nearest_txt.to_lower()
					if "katapult" in low or "slå" in low:
						action_key = "sword"
					elif "klatre" in low or "stige" in low:
						action_key = "climb"
					elif "hopp" in low:
						action_key = "jump"
					elif "skyv" in low or "kasse" in low:
						action_key = "pushpull"
					elif "gong" in low:
						action_key = "gong"
					elif "grav" in low:
						action_key = "dig"
					else:
						action_key = "pickup"
				else:
					nearest_txt = "[E] Bruk"
					action_key = "pickup"
	_action_box.visible = (nearest_txt != "")
	if nearest_txt != "":
		_action_label.text = nearest_txt
		var tex: Texture2D = _action_texs.get(action_key, _action_texs.get("talk", null))
		if tex:
			_action_icon.texture = tex


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _shop_panel.visible:
			_shop_panel.visible = false
		elif _dialogue_panel.visible:
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
	if is_instance_valid(_air_widget) and mx > 0.0:
		_air_widget.set_ratio(cur / mx)


func _on_coins_changed(coins: int) -> void:
	if is_instance_valid(_coin_label):
		_coin_label.text = "%d" % coins
	if is_instance_valid(_silver_label):
		_silver_label.text = "%d" % (coins % 10)
	if is_instance_valid(_shop_panel) and _shop_panel.visible:
		_refresh_shop_list()


func _on_weapon_changed(_weapon_id: String) -> void:
	pass


func _on_objective_changed(_text: String) -> void:
	pass


func _on_shop_requested(title: String, items: Array) -> void:
	if not is_instance_valid(_shop_panel):
		return
	_shop_title_lbl.text = title
	_shop_items = items
	_refresh_shop_list()
	_shop_panel.visible = true


func _refresh_shop_list() -> void:
	if not is_instance_valid(_shop_list):
		return
	for ch in _shop_list.get_children():
		ch.queue_free()
	_shop_coins_lbl.text = "Dine gullmynter: %d" % GameState.coins
	for it in _shop_items:
		var item: Dictionary = it
		var cost := int(item.get("cost", 0))
		var weapon_id := str(item.get("weapon", ""))
		var owned := (weapon_id != "" and GameState.has_weapon(weapon_id))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 42)
		if owned:
			btn.text = "✓ %s — Eies allerede (Velg med %s)" % [str(item.get("name", "")), "[2]" if weapon_id == "slingshot" else "[L]" if weapon_id == "lamp" else "[1]"]
			btn.disabled = true
		else:
			btn.text = "%s  —  %d mynter" % [str(item.get("name", "")), cost]
			btn.disabled = GameState.coins < cost
			btn.pressed.connect(func():
				if GameState.spend_coins(cost):
					AudioManager.play_sfx("coinpopup")
					var ach := str(item.get("achievement", ""))
					if ach != "":
						GameState.add_achievement(ach)
					if weapon_id != "":
						GameState.unlock_weapon(weapon_id, true)
					var heal_amt := float(item.get("heal", 0.0))
					if heal_amt > 0.0:
						GameState.heal(heal_amt)
					_refresh_shop_list()
			)
		_shop_list.add_child(btn)


func _on_level_changed(level_id: String) -> void:
	var cfg := LevelCatalog.get_level(level_id)
	var mode := str(cfg.get("mode", "adventure"))
	# Skjul alltid forrige nivå sin boss-bar ved nivåbytte!
	if is_instance_valid(_boss_wrap):
		_boss_wrap.visible = false
	if is_instance_valid(_subtitle_panel):
		_subtitle_panel.visible = false
	if is_instance_valid(_shop_panel):
		_shop_panel.visible = false
	if is_instance_valid(_air_widget):
		_air_widget.visible = (mode == "swimming")
	if is_instance_valid(_world_map_frame):
		_world_map_frame.visible = (level_id == "world_map")
	if is_instance_valid(_medallion):
		_medallion.set_ship_mode(level_id == "world_map")


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
	if not is_instance_valid(_boss_wrap):
		return
	var is_boss_lvl := ("boss" in GameState.current_level_id)
	if boss_name == "" or mx <= 0.0 or not is_boss_lvl:
		_boss_wrap.visible = false
		return
	_boss_wrap.visible = true
	_boss_name_lbl.text = boss_name
	_boss_widget.set_boss(boss_name, cur, mx, GameState.current_level_id)
