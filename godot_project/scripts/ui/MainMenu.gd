extends Node3D
## Hovedmeny (1:1 tro mot originalen) med 3D-bakgrunn av Abra Havn i solnedgang og ren historieflyt.

const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")

var _cam_pivot: Node3D
var _settings_panel: PanelContainer


func _ready() -> void:
	_setup_3d_backdrop()
	_setup_menu_ui()
	AudioManager.play_music("menu")


func _setup_3d_backdrop() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = VisualEnhancer.create_biome_sky("menu", {})
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.72
	env.ambient_light_energy = 0.40
	# Moderne ACES kinematisk tonemapping med dyp kontrast og null blass tåke-vask!
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.ssao_enabled = true
	env.ssao_radius = 1.65
	env.ssao_intensity = 2.05
	env.ssil_enabled = true
	env.ssil_radius = 4.2
	env.ssil_intensity = 0.65
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = 0.36
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.64, 0.42)
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.10
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.18
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.80, 0.48)
	sun.light_energy = 2.60
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.rotation_degrees = Vector3(-16.0, 32.0, 0.0)
	add_child(sun)

	# Kald motsatt himmel-kantbelysning for myk Pixar-dybde på skutesiden
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.36, 0.60, 0.98)
	fill.light_energy = 0.24
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-28.0, -145.0, 0.0)
	add_child(fill)

	# Sea of Thieves-inspirert turkis-gull solnedgangshav med ekte skum rundt bryggestolpene
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(460, 460)
	pm.subdivide_width = 128
	pm.subdivide_depth = 128
	water.mesh = pm
	water.position.y = -0.10
	var wmat := ShaderMaterial.new()
	wmat.shader = OCEAN_SHADER
	wmat.set_shader_parameter("deep_color", Color(0.015, 0.14, 0.28, 1.0))
	wmat.set_shader_parameter("mid_color", Color(0.03, 0.34, 0.46, 1.0))
	wmat.set_shader_parameter("shallow_color", Color(0.10, 0.62, 0.64, 1.0))
	wmat.set_shader_parameter("sun_dir", Vector3(0.45, 0.18, -0.88))
	wmat.set_shader_parameter("sun_tint", Color(1.0, 0.82, 0.46))
	wmat.set_shader_parameter("sparkle_strength", 1.4)
	water.material_override = wmat
	add_child(water)

	# Last full HD Abra Havn som 3D-bakgrunn med oppgraderte AAA PBR-materialer og varme lykter
	var hero_loaded := false
	var hero_center := Vector3(0.0, 5.0, 0.0)
	var cam_dist := 32.0
	for cand in ["res://assets/levels/abra.glb", "res://assets/models/sabeltann.glb"]:
		if ResourceLoader.exists(cand):
			var sc := load(cand) as PackedScene
			if sc:
				var inst := sc.instantiate()
				add_child(inst)
				_clean_menu_backdrop(inst)
				VisualEnhancer.enhance_world_node(inst, "menu", -0.10)
				hero_loaded = true
				break

	if not hero_loaded:
		var island := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 6.0; cyl.bottom_radius = 10.0; cyl.height = 3.0
		island.mesh = cyl
		add_child(island)

	# Svevende gyllent solstøv i forgrunnen
	VisualEnhancer.spawn_ambient_particles(self, hero_center, "abra")

	_cam_pivot = Node3D.new()
	_cam_pivot.position = hero_center
	add_child(_cam_pivot)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 8.0, cam_dist)
	cam.fov = 58.0
	cam.current = true
	_cam_pivot.add_child(cam)
	cam.look_at(hero_center, Vector3.UP)


func _clean_menu_backdrop(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nm := mi.name.to_lower()
		# Skjul gamle flate vannflater, bakgrunns-skyggeboks (slik at vår nye solnedgangshimmel skinner!) og glød-plater
		if "water" in nm or "abrasea" in nm or "abrabackground" in nm or "portalchoice" in nm or nm in ["shoplamp", "shopslingshot", "shopsword"]:
			mi.visible = false
		elif "glow" in nm:
			mi.visible = false
			if nm.begins_with("glow"):
				var laabb: AABB = mi.global_transform * mi.get_aabb()
				var lgt := OmniLight3D.new()
				lgt.position = laabb.get_center()
				lgt.light_color = Color(1.0, 0.72, 0.30)
				lgt.light_energy = 3.6
				lgt.omni_range = 14.0
				add_child(lgt)
	for c in node.get_children():
		_clean_menu_backdrop(c)


func _process(delta: float) -> void:
	if is_instance_valid(_cam_pivot):
		_cam_pivot.rotate_y(delta * 0.12)


func _make_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.11, 0.07, 0.04, 0.86)
	st.border_color = Color(0.84, 0.64, 0.26, 0.95)
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 30
	st.content_margin_right = 30
	st.content_margin_top = 26
	st.content_margin_bottom = 26
	return st


func _make_btn_style(hover: bool = false) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.32, 0.20, 0.10, 0.94) if hover else Color(0.20, 0.12, 0.06, 0.90)
	st.border_color = Color(0.96, 0.78, 0.34, 1.0) if hover else Color(0.72, 0.54, 0.22, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(8)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	return st


func _style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _make_btn_style(false))
	btn.add_theme_stylebox_override("hover", _make_btn_style(true))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(true))
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.42))
	btn.custom_minimum_size = Vector2(0, 50)


func _setup_menu_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 72
	panel.offset_right = 510
	panel.offset_top = -195
	panel.offset_bottom = 195
	panel.add_theme_stylebox_override("panel", _make_style())
	ui.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "KAPTEIN SABELTANN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "og Grusomme Gabriels forbannelse"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Color(0.95, 0.88, 0.74))
	vb.add_child(sub)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	vb.add_child(sep)

	if GameState.has_save():
		var cont_btn := Button.new()
		cont_btn.text = "Fortsett spill"
		_style_button(cont_btn)
		cont_btn.pressed.connect(func():
			AudioManager.play_sfx("menu_select")
			get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
		)
		vb.add_child(cont_btn)

	var start_btn := Button.new()
	start_btn.text = "Nytt spill"
	_style_button(start_btn)
	start_btn.pressed.connect(func():
		AudioManager.play_sfx("menu_select")
		# 1:1 historieflyt: starter alltid i Grusomme Gabriels grotte
		GameState.reset_new_game("cave")
		get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
	)
	vb.add_child(start_btn)

	var opt_btn := Button.new()
	opt_btn.text = "Innstillinger"
	_style_button(opt_btn)
	opt_btn.pressed.connect(func():
		AudioManager.play_sfx("menu_select")
		_settings_panel.visible = not _settings_panel.visible
	)
	vb.add_child(opt_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Avslutt"
	_style_button(quit_btn)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit_btn)

	# Skjult innstillingspanel (åpnes kun ved klikk på Innstillinger)
	_settings_panel = PanelContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.offset_left = 40
	_settings_panel.offset_right = 420
	_settings_panel.offset_top = -120
	_settings_panel.offset_bottom = 120
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
		_style_button(gb)
		gb.custom_minimum_size = Vector2(96, 40)
		gb.pressed.connect(func():
			AudioManager.play_sfx("menu_select")
			GameState.apply_graphics_preset(preset)
		)
		grow.add_child(gb)
	sv.add_child(grow)
