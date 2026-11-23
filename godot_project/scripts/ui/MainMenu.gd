extends Node3D
## Hovedmeny med ekte 3D-bakgrunn (Abra Havn / Kaptein Sabeltann + animert hav) og norsk HD-meny.

const OCEAN_SHADER := preload("res://shaders/ocean_water.gdshader")

var _cam_pivot: Node3D
var _level_select_panel: PanelContainer


func _ready() -> void:
	_setup_3d_backdrop()
	_setup_menu_ui()
	AudioManager.play_music("menu")


func _setup_3d_backdrop() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var smat := ProceduralSkyMaterial.new()
	smat.sky_top_color = Color(0.10, 0.24, 0.54)
	smat.sky_horizon_color = Color(0.88, 0.56, 0.34)
	smat.ground_bottom_color = Color(0.04, 0.12, 0.22)
	smat.ground_horizon_color = Color(0.62, 0.44, 0.32)
	sky.sky_material = smat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 1.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.58, 0.46)
	env.fog_density = 0.0020
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.84, 0.58)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-28.0, 38.0, 0.0)
	add_child(sun)

	# Animasjonshav i forgrunnen (eksakt vannlinje for Abra Havn)
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(440, 440)
	pm.subdivide_width = 128
	pm.subdivide_depth = 128
	water.mesh = pm
	water.position.y = -0.10
	var wmat := ShaderMaterial.new()
	wmat.shader = OCEAN_SHADER
	water.material_override = wmat
	add_child(water)

	# Last hovedmeny eller full HD Abra Havn som 3D-blikkfang
	var hero_loaded := false
	var hero_center := Vector3(0.0, 3.0, 0.0)
	var cam_dist := 24.0
	for cand in ["res://assets/levels/mainmenu.glb", "res://assets/levels/abra.glb", "res://assets/models/sabeltann.glb"]:
		if ResourceLoader.exists(cand):
			var sc := load(cand) as PackedScene
			if sc:
				var inst := sc.instantiate()
				add_child(inst)
				_clean_menu_backdrop(inst)
				hero_loaded = true
				if cand.ends_with("abra.glb"):
					hero_center = Vector3(0.0, 5.0, 0.0)
					cam_dist = 32.0
				break

	if not hero_loaded:
		var island := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 6.0; cyl.bottom_radius = 10.0; cyl.height = 3.0
		island.mesh = cyl
		add_child(island)

	_cam_pivot = Node3D.new()
	_cam_pivot.position = hero_center
	add_child(_cam_pivot)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 8.0, cam_dist)
	cam.current = true
	_cam_pivot.add_child(cam)
	cam.look_at(hero_center, Vector3.UP)


func _clean_menu_backdrop(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var nm := mi.name.to_lower()
		if "water" in nm or "abrasea" in nm or "glow" in nm or "portalchoice" in nm or nm in ["shoplamp", "shopslingshot", "shopsword"]:
			mi.visible = false
	for c in node.get_children():
		_clean_menu_backdrop(c)


func _process(delta: float) -> void:
	if is_instance_valid(_cam_pivot):
		_cam_pivot.rotate_y(delta * 0.14)


func _make_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.07, 0.12, 0.88)
	st.border_color = Color(0.90, 0.70, 0.28, 0.95)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 28
	st.content_margin_right = 28
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	return st


func _setup_menu_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.offset_left = 70
	panel.offset_right = 560
	panel.offset_top = -270
	panel.offset_bottom = 270
	panel.add_theme_stylebox_override("panel", _make_style())
	ui.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	var title := Label.new()
	title.text = "KAPTEIN SABELTANN"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.28))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "og Grusomme Gabriels forbannelse\nHD REMAKE EDITION (Godot 4)"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	vb.add_child(sub)

	var start_btn := Button.new()
	start_btn.text = "Start nytt eventyr (Abra Havn)"
	start_btn.custom_minimum_size = Vector2(0, 48)
	start_btn.pressed.connect(func():
		GameState.reset_new_game("abra")
		get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
	)
	vb.add_child(start_btn)

	var cave_btn := Button.new()
	cave_btn.text = "Start fra original intro (Gabriels grotte)"
	cave_btn.custom_minimum_size = Vector2(0, 44)
	cave_btn.pressed.connect(func():
		GameState.reset_new_game("cave")
		get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
	)
	vb.add_child(cave_btn)

	if GameState.has_save():
		var cont_btn := Button.new()
		cont_btn.text = "Fortsett lagret spill (%s)" % LevelCatalog.get_level(GameState.current_level_id).get("title", "")
		cont_btn.custom_minimum_size = Vector2(0, 44)
		cont_btn.pressed.connect(func():
			get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
		)
		vb.add_child(cont_btn)

	var levels_btn := Button.new()
	levels_btn.text = "Velg nivå (alle 18 verdener)"
	levels_btn.custom_minimum_size = Vector2(0, 44)
	levels_btn.pressed.connect(func(): _level_select_panel.visible = not _level_select_panel.visible)
	vb.add_child(levels_btn)

	# Grafikk-kvalitet
	var gfx_box := HBoxContainer.new()
	var glbl := Label.new()
	glbl.text = "HD-grafikk: "
	gfx_box.add_child(glbl)
	for preset in ["Medium", "High", "Ultra"]:
		var gb := Button.new()
		gb.text = preset
		gb.pressed.connect(func(): GameState.apply_graphics_preset(preset))
		gfx_box.add_child(gb)
	vb.add_child(gfx_box)

	var quit_btn := Button.new()
	quit_btn.text = "Avslutt"
	quit_btn.custom_minimum_size = Vector2(0, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vb.add_child(quit_btn)

	# Nivåvelger-panel til høyre
	_level_select_panel = PanelContainer.new()
	_level_select_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_level_select_panel.offset_left = -620
	_level_select_panel.offset_right = -60
	_level_select_panel.offset_top = -300
	_level_select_panel.offset_bottom = 300
	_level_select_panel.add_theme_stylebox_override("panel", _make_style())
	_level_select_panel.visible = false
	ui.add_child(_level_select_panel)

	var lv := VBoxContainer.new()
	_level_select_panel.add_child(lv)
	var ltitle := Label.new()
	ltitle.text = "VELG NIVÅ"
	ltitle.add_theme_font_size_override("font_size", 22)
	ltitle.add_theme_color_override("font_color", Color(1.0, 0.84, 0.30))
	lv.add_child(ltitle)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)

	for lid in LevelCatalog.ORDERED_LEVEL_IDS:
		var info := LevelCatalog.get_level(lid)
		var b := Button.new()
		b.text = str(info.get("title", lid))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(func():
			GameState.reset_new_game(lid)
			get_tree().change_scene_to_file("res://scenes/GameLevel.tscn")
		)
		grid.add_child(b)
