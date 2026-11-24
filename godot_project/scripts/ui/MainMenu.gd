extends Node3D
## Hovedmeny (1:1 tro mot original 2007 menu.jpg):
## Mørk, stemningsfull forbannet natt i Abra Havn med varme lykter, sjøkart-konturer (menu_islands_overlay.png),
## stiplet skattekartsti med røde X-merker for menyvalgene og gyllen Kaptein Sabeltann-tittel!

const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")

class TreasureMapTrail extends Control:
	var stops: Array[Vector2] = []

	func _draw() -> void:
		if stops.is_empty():
			return
		# Lag en myk buet skattekart-sti fra bunnen av skjermen gjennom alle røde X-merker (1:1 menu.jpg!)
		var pts: Array[Vector2] = []
		var w := size.x
		var h := size.y
		var base_pts: Array[Vector2] = [Vector2(w * 0.28, h * 1.04), Vector2(w * 0.56, h * 0.90)]
		for i in range(stops.size() - 1, -1, -1):
			base_pts.append(stops[i])
		# Catmull-Rom-lignende myk kurve
		for i in range(base_pts.size() - 1):
			var p0: Vector2 = base_pts[max(i - 1, 0)]
			var p1: Vector2 = base_pts[i]
			var p2: Vector2 = base_pts[i + 1]
			var p3: Vector2 = base_pts[min(i + 2, base_pts.size() - 1)]
			var steps := 18
			for s in range(steps):
				var t := float(s) / float(steps)
				var t2 := t * t
				var t3 := t2 * t
				var q := 0.5 * (
					(2.0 * p1)
					+ (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
				)
				pts.append(q)
		pts.append(base_pts[-1])

		# Tegn stiplede kremgule skattekart-streker langs kurven
		var accum := 0.0
		var dash_len := 18.0
		var gap_len := 13.0
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var seg_len := a.distance_to(b)
			var cycle := fmod(accum, dash_len + gap_len)
			if cycle < dash_len:
				draw_line(a + Vector2(2, 2), b + Vector2(2, 2), Color(0.03, 0.02, 0.01, 0.65), 6.0, true)
				draw_line(a, b, Color(0.95, 0.92, 0.72, 0.88), 4.5, true)
			accum += seg_len

		# Tegn tydelige håndmalte røde sjørøver-X-er ved hvert menyvalg
		for sp in stops:
			var r := 18.0
			draw_line(sp + Vector2(-r, -r) + Vector2(2, 2), sp + Vector2(r, r) + Vector2(2, 2), Color(0.08, 0.02, 0.01, 0.75), 9.0, true)
			draw_line(sp + Vector2(r, -r) + Vector2(2, 2), sp + Vector2(-r, r) + Vector2(2, 2), Color(0.08, 0.02, 0.01, 0.75), 9.0, true)
			draw_line(sp + Vector2(-r, -r), sp + Vector2(r, r), Color(0.92, 0.22, 0.06, 0.98), 7.5, true)
			draw_line(sp + Vector2(r, -r), sp + Vector2(-r, r), Color(0.92, 0.22, 0.06, 0.98), 7.5, true)
			draw_line(sp + Vector2(-r * 0.8, -r * 0.8), sp + Vector2(r * 0.8, r * 0.8), Color(1.0, 0.45, 0.16, 0.55), 2.5, true)


var _cam_pivot: Node3D
var _settings_panel: PanelContainer
var _trail: TreasureMapTrail


func _ready() -> void:
	_setup_3d_backdrop()
	_setup_menu_ui()
	AudioManager.play_music("menu")


func _setup_3d_backdrop() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = VisualEnhancer.create_biome_sky("menu", {})
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.26, 0.30, 0.16)
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.04
	env.ssao_enabled = true
	env.ssao_radius = 1.45
	env.ssao_intensity = 1.55
	env.ssil_enabled = true
	env.ssil_radius = 3.6
	env.ssil_intensity = 0.48
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.34
	env.glow_bloom = 0.10
	env.glow_hdr_threshold = 1.22
	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.19, 0.09)
	env.fog_density = 0.0085
	env.fog_sky_affect = 0.20
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.04
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.88, 0.78, 0.44)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.rotation_degrees = Vector3(-26.0, -34.0, 0.0)
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.42, 0.48, 0.24)
	fill.light_energy = 0.36
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-22.0, 140.0, 0.0)
	add_child(fill)

	# Mørkt forbannet sjøgrønt havnevann i Abra Havn (matcher original 2007 menu.jpg!)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(460, 460)
	pm.subdivide_width = 96
	pm.subdivide_depth = 96
	water.mesh = pm
	water.position.y = -0.15
	var wmat := ShaderMaterial.new()
	wmat.shader = OCEAN_SHADER
	wmat.set_shader_parameter("deep_color", Color(0.03, 0.06, 0.04, 1.0))
	wmat.set_shader_parameter("mid_color", Color(0.07, 0.13, 0.08, 1.0))
	wmat.set_shader_parameter("shallow_color", Color(0.14, 0.20, 0.11, 1.0))
	wmat.set_shader_parameter("sun_dir", Vector3(0.35, 0.16, -0.92))
	wmat.set_shader_parameter("sun_tint", Color(0.95, 0.78, 0.38))
	wmat.set_shader_parameter("sparkle_strength", 0.55)
	water.material_override = wmat
	add_child(water)

	# Last 2026 nybygd Abra Havn som levende 3D-bakgrunn med varme havnelykter (fri sikt mot husene uten mast midt i teksten!)
	var hero_center := Vector3(-6.0, 4.2, -2.0)
	if ResourceLoader.exists("res://assets/levels/abra.glb"):
		var sc := load("res://assets/levels/abra.glb") as PackedScene
		if sc:
			var inst := sc.instantiate()
			add_child(inst)
			_clean_menu_backdrop(inst)
			VisualEnhancer.enhance_world_node(inst, "menu", -0.15)

	VisualEnhancer.spawn_ambient_particles(self, hero_center, "abra")

	_cam_pivot = Node3D.new()
	_cam_pivot.position = hero_center
	add_child(_cam_pivot)

	var cam := Camera3D.new()
	cam.position = Vector3(14.0, 5.8, 17.5)
	cam.fov = 52.0
	cam.current = true
	_cam_pivot.add_child(cam)
	cam.look_at(hero_center + Vector3(-2.0, 0.8, -4.0), Vector3.UP)


func _clean_menu_backdrop(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nm := mi.name.to_lower()
		if "water" in nm or "abrasea" in nm or "abrabackground" in nm or "portalchoice" in nm or nm in ["shoplamp", "shopslingshot", "shopsword"]:
			mi.visible = false
		elif "glow" in nm:
			mi.visible = false
			if nm.begins_with("glow"):
				var laabb: AABB = mi.global_transform * mi.get_aabb()
				var lgt := OmniLight3D.new()
				lgt.position = laabb.get_center()
				lgt.light_color = Color(1.0, 0.72, 0.28)
				lgt.light_energy = 4.2
				lgt.omni_range = 16.0
				add_child(lgt)
	for c in node.get_children():
		_clean_menu_backdrop(c)


func _process(delta: float) -> void:
	if is_instance_valid(_cam_pivot):
		_cam_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.00018) * 0.16


func _make_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.06, 0.03, 0.90)
	st.border_color = Color(0.86, 0.66, 0.24, 0.96)
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 26
	st.content_margin_right = 26
	st.content_margin_top = 22
	st.content_margin_bottom = 22
	return st


func _make_btn_style(hover: bool = false) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.28, 0.18, 0.08, 0.92) if hover else Color(0.16, 0.10, 0.05, 0.88)
	st.border_color = Color(0.98, 0.80, 0.34, 1.0) if hover else Color(0.72, 0.54, 0.22, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	return st


func _style_map_button(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)
	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", Color(0.98, 0.95, 0.72))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.28))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.20))
	btn.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.01, 0.96))
	btn.add_theme_constant_override("outline_size", 8)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_settings_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(true))
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.42))


func _setup_menu_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	# 1. Subtil original sjøkart-kontur (menu_islands_overlay.png) langs kantene som i menu.jpg!
	if ResourceLoader.exists("res://assets/ui/menu_islands_overlay.png"):
		var map_ov := TextureRect.new()
		map_ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		map_ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_ov.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		map_ov.texture = load("res://assets/ui/menu_islands_overlay.png") as Texture2D
		map_ov.modulate = Color(0.94, 0.90, 0.70, 0.24)
		map_ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(map_ov)

	# 2. Stiplet skattekart-sti med røde X-er
	_trail = TreasureMapTrail.new()
	_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_trail)

	# 3. Topp-venstre: Gyllent pirat-tittelmerke (1:1 plassering fra original 2007 menu.jpg)
	var title_box := VBoxContainer.new()
	title_box.position = Vector2(46, 30)
	title_box.add_theme_constant_override("separation", 2)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_box)

	var title := Label.new()
	title.text = "KAPTEIN SABELTANN"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.26))
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.01, 0.98))
	title.add_theme_constant_override("outline_size", 11)
	title_box.add_child(title)

	var sub := Label.new()
	sub.text = "og Grusomme Gabriels forbannelse"
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.98, 0.92, 0.68))
	sub.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.01, 0.96))
	sub.add_theme_constant_override("outline_size", 7)
	title_box.add_child(sub)

	var load_panel := PanelContainer.new()
	load_panel.set_anchors_preset(Control.PRESET_CENTER)
	load_panel.offset_left = -210
	load_panel.offset_right = 210
	load_panel.offset_top = -48
	load_panel.offset_bottom = 48
	load_panel.add_theme_stylebox_override("panel", _make_style())
	load_panel.visible = false
	ui.add_child(load_panel)
	var load_lbl := Label.new()
	load_lbl.text = "Laster inn eventyret..."
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_lbl.add_theme_font_size_override("font_size", 22)
	load_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36))
	load_panel.add_child(load_lbl)

	# 4. Menyvalg langs den stiplede skattekart-stien (med rødt X-merke ved hvert punkt!)
	var entries: Array = []
	if GameState.has_save():
		entries.append({
			"label": "Fortsett spill",
			"x_pos": Vector2(760, 260),
			"text_pos": Vector2(675, 200),
			"cb": func():
				AudioManager.play_sfx("menu_select")
				load_panel.visible = true
				await get_tree().process_frame
				get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
		})
	entries.append({
		"label": "Nytt spill",
		"x_pos": Vector2(620, 385) if GameState.has_save() else Vector2(760, 295),
		"text_pos": Vector2(415, 360) if GameState.has_save() else Vector2(690, 232),
		"cb": func():
			AudioManager.play_sfx("menu_select")
			load_panel.visible = true
			await get_tree().process_frame
			GameState.reset_new_game("cave")
			get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
	})
	entries.append({
		"label": "Innstillinger",
		"x_pos": Vector2(780, 485) if GameState.has_save() else Vector2(585, 435),
		"text_pos": Vector2(818, 462) if GameState.has_save() else Vector2(360, 412),
		"cb": func():
			AudioManager.play_sfx("menu_select")
			_settings_panel.visible = not _settings_panel.visible
	})
	entries.append({
		"label": "Avslutt",
		"x_pos": Vector2(670, 585) if GameState.has_save() else Vector2(805, 555),
		"text_pos": Vector2(710, 560) if GameState.has_save() else Vector2(842, 532),
		"cb": func(): get_tree().quit()
	})

	var stop_pts: Array[Vector2] = []
	for e in entries:
		stop_pts.append(e["x_pos"])
		var btn := Button.new()
		btn.text = str(e["label"])
		btn.position = e["text_pos"]
		_style_map_button(btn)
		btn.pressed.connect(e["cb"])
		ui.add_child(btn)
	_trail.stops = stop_pts
	_trail.queue_redraw()

	# 5. Innstillingspanel (skjult til spilleren trykker Innstillinger)
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_settings_panel.offset_left = 48
	_settings_panel.offset_right = 468
	_settings_panel.offset_top = -100
	_settings_panel.offset_bottom = 220
	_settings_panel.add_theme_stylebox_override("panel", _make_style())
	_settings_panel.visible = false
	ui.add_child(_settings_panel)

	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(sv)

	var stitle := Label.new()
	stitle.text = "INNSTILLINGER"
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 22)
	stitle.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	sv.add_child(stitle)

	var glbl := Label.new()
	glbl.text = "Grafikkvalitet:"
	glbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(glbl)

	var grow := HBoxContainer.new()
	grow.alignment = BoxContainer.ALIGNMENT_CENTER
	grow.add_theme_constant_override("separation", 8)
	for preset in ["Medium", "High", "Ultra"]:
		var gb := Button.new()
		gb.text = preset
		_style_settings_button(gb)
		gb.custom_minimum_size = Vector2(96, 40)
		gb.pressed.connect(func():
			AudioManager.play_sfx("menu_select")
			GameState.apply_graphics_preset(preset)
		)
		grow.add_child(gb)
	sv.add_child(grow)

	var vlbl := Label.new()
	vlbl.text = "Karakterstemmer (undertekster alltid på norsk):"
	vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vlbl.add_theme_font_size_override("font_size", 15)
	sv.add_child(vlbl)

	var vrow := HBoxContainer.new()
	vrow.alignment = BoxContainer.ALIGNMENT_CENTER
	vrow.add_theme_constant_override("separation", 10)
	var btn_no := Button.new()
	var btn_orig := Button.new()
	var refresh_voice_btns := func():
		btn_no.text = ("★ Norsk" if GameState.voice_language == "no" else "Norsk")
		btn_orig.text = ("★ Original CD" if GameState.voice_language == "orig" else "Original CD")
	_style_settings_button(btn_no)
	_style_settings_button(btn_orig)
	btn_no.custom_minimum_size = Vector2(145, 42)
	btn_orig.custom_minimum_size = Vector2(155, 42)
	btn_no.pressed.connect(func():
		AudioManager.play_sfx("menu_select")
		GameState.voice_language = "no"
		GameState.save_game()
		refresh_voice_btns.call()
	)
	btn_orig.pressed.connect(func():
		AudioManager.play_sfx("menu_select")
		GameState.voice_language = "orig"
		GameState.save_game()
		refresh_voice_btns.call()
	)
	refresh_voice_btns.call()
	vrow.add_child(btn_no)
	vrow.add_child(btn_orig)
	sv.add_child(vrow)
