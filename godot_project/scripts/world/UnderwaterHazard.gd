extends Area3D
class_name UnderwaterHazard
## 1:1 original undervanns-objekter fra swimmer.ls / ScriptingDataSwimObstacle.ls / underwater_chest.ls:
## - "bubble_column": Stigende luftbobler som fyller Pinkys luftmåler (areatrigger_air*)
## - "mine": Sjømine i kjetting (magakhan_dungeon_underwater)
## - "shark" / "piraya": Patruljerende hai og piraja i 2D-svømming (world_map_underwater)
## - "pickup": Undervanns-skattkiste, brønnkake (wellcake) eller fangehullsnøkkel (key2)
## - "exit": Vannflate-utgang (areatrigger_leave) som sender Pinky til neste nivå (f.eks. Gral-boss!)

@export var kind: String = "bubble_column"
@export var target_level_id: String = ""
@export var pickup_flag: String = ""
@export var pickup_label: String = ""
@export var patrol_range: float = 5.5
@export var patrol_speed: float = 2.6
@export var column_height: float = 12.0

var _origin: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _visual: Node3D
var _collected: bool = false


func _ready() -> void:
	_origin = position
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_entity()


func _build_entity() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var col := CollisionShape3D.new()
	match kind:
		"bubble_column":
			var box := BoxShape3D.new()
			box.size = Vector3(2.4, column_height, 4.0)
			col.shape = box
			col.position.y = column_height * 0.5
			add_child(col)
			_build_bubble_column()
		"mine":
			var sph := SphereShape3D.new()
			sph.radius = 0.95
			col.shape = sph
			add_child(col)
			_build_sea_mine()
		"shark", "piraya":
			var sph := SphereShape3D.new()
			sph.radius = 1.15 if kind == "shark" else 0.72
			col.shape = sph
			add_child(col)
			_build_fish(kind == "shark")
		"pickup":
			var sph := SphereShape3D.new()
			sph.radius = 1.25
			col.shape = sph
			add_child(col)
			_build_pickup()
		"exit":
			var box := BoxShape3D.new()
			box.size = Vector3(5.6, 2.8, 5.0)
			col.shape = box
			add_child(col)
			_build_exit_surface()


func _build_bubble_column() -> void:
	# Stigende glitrende luftboblesøyle som fyller Pinkys luft!
	var pts := GPUParticles3D.new()
	pts.amount = 65
	pts.lifetime = 3.6
	pts.preprocess = 2.5
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.85, 0.35, 0.35)
	pmat.direction = Vector3(0.0, 1.0, 0.0)
	pmat.spread = 8.0
	pmat.initial_velocity_min = column_height * 0.24
	pmat.initial_velocity_max = column_height * 0.36
	pmat.gravity = Vector3(0.0, 0.45, 0.0)
	pmat.scale_min = 0.45
	pmat.scale_max = 1.25
	pts.process_material = pmat

	var qm := QuadMesh.new()
	qm.size = Vector2(0.36, 0.36)
	var bmat := StandardMaterial3D.new()
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_texture = VisualEnhancer.get_soft_glow_tex()
	bmat.albedo_color = Color(0.68, 0.96, 1.0, 0.88)
	bmat.emission_enabled = true
	bmat.emission = Color(0.38, 0.90, 1.0)
	bmat.emission_energy_multiplier = 2.2
	qm.material = bmat
	pts.draw_pass_1 = qm
	_visual.add_child(pts)

	# Mykt turkis boblelys i bunnen av sprekken
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.4, 1.2)
	light.light_color = Color(0.32, 0.92, 1.0)
	light.light_energy = 3.2
	light.omni_range = 10.0
	light.shadow_enabled = false
	_visual.add_child(light)


func _build_sea_mine() -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.17, 0.20)
	iron.metallic = 0.82
	iron.roughness = 0.38
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.22, 0.10)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.18, 0.06)
	glow.emission_energy_multiplier = 3.0

	var body := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.72
	sp.height = 1.44
	body.mesh = sp
	body.material_override = iron
	_visual.add_child(body)

	# 8 skarpe pigger rundt sjøminen
	for dir in [
		Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0),
		Vector3(0.7, 0.7, 0), Vector3(-0.7, 0.7, 0), Vector3(0.7, -0.7, 0), Vector3(-0.7, -0.7, 0),
	]:
		var d: Vector3 = dir.normalized()
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.12
		cm.height = 0.45
		spike.mesh = cm
		spike.position = d * 0.78
		if absf(d.dot(Vector3.UP)) < 0.999:
			var axis := Vector3.UP.cross(d).normalized()
			spike.basis = Basis(axis, acos(clampf(Vector3.UP.dot(d), -1.0, 1.0)))
		spike.material_override = iron
		_visual.add_child(spike)

	var lamp := MeshInstance3D.new()
	var ls := SphereMesh.new()
	ls.radius = 0.16
	ls.height = 0.32
	lamp.mesh = ls
	lamp.position = Vector3(0.0, 0.0, 0.68)
	lamp.material_override = glow
	_visual.add_child(lamp)

	# Ankerkjetting ned mot bunnen
	var chain := MeshInstance3D.new()
	var ch := CylinderMesh.new()
	ch.top_radius = 0.06
	ch.bottom_radius = 0.06
	ch.height = 5.5
	chain.mesh = ch
	chain.position.y = -3.2
	chain.material_override = iron
	_visual.add_child(chain)


func _build_fish(is_shark: bool) -> void:
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.28, 0.36, 0.46) if is_shark else Color(0.68, 0.16, 0.14)
	fmat.roughness = 0.36
	fmat.rim_enabled = true
	fmat.rim = 0.55

	var body := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.55 if is_shark else 0.34
	sp.height = 1.1 if is_shark else 0.68
	body.mesh = sp
	body.scale = Vector3(2.2, 0.85, 0.72) if is_shark else Vector3(1.5, 1.0, 0.6)
	body.material_override = fmat
	_visual.add_child(body)

	var fin := MeshInstance3D.new()
	var fm := PrismMesh.new()
	fm.size = Vector3(0.75, 0.72, 0.14) if is_shark else Vector3(0.4, 0.4, 0.1)
	fin.mesh = fm
	fin.position = Vector3(-0.1, 0.52 if is_shark else 0.30, 0.0)
	fin.material_override = fmat
	_visual.add_child(fin)

	var tail := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.65, 0.92, 0.12) if is_shark else Vector3(0.4, 0.55, 0.1)
	tail.mesh = tm
	tail.position = Vector3(-1.25 if is_shark else -0.62, 0.0, 0.0)
	tail.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	tail.material_override = fmat
	_visual.add_child(tail)


func _build_pickup() -> void:
	var gmat := StandardMaterial3D.new()
	if pickup_flag == "wellcake":
		gmat.albedo_color = Color(0.96, 0.78, 0.42)
		gmat.emission_enabled = true
		gmat.emission = Color(1.0, 0.72, 0.25)
		gmat.emission_energy_multiplier = 1.8
	elif pickup_flag == "key2":
		gmat.albedo_color = Color(1.0, 0.86, 0.24)
		gmat.metallic = 0.92
		gmat.roughness = 0.20
		gmat.emission_enabled = true
		gmat.emission = Color(1.0, 0.82, 0.22)
		gmat.emission_energy_multiplier = 2.4
	else:
		gmat.albedo_color = Color(0.95, 0.74, 0.18)
		gmat.metallic = 0.85
		gmat.roughness = 0.25
		gmat.emission_enabled = true
		gmat.emission = Color(1.0, 0.76, 0.18)
		gmat.emission_energy_multiplier = 2.0

	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.8, 0.75) if pickup_flag != "key2" else Vector3(0.95, 0.32, 0.22)
	m.mesh = bm
	m.material_override = gmat
	_visual.add_child(m)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.84, 0.35)
	light.light_energy = 2.6
	light.omni_range = 7.0
	light.shadow_enabled = false
	_visual.add_child(light)


func _build_exit_surface() -> void:
	# Lysende solstråle-vannoverflate i toppen av brønnsjakten!
	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.2, 3.2)
	surf.mesh = pm
	surf.position.y = 0.6
	var smat := StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color(0.45, 0.94, 1.0, 0.42)
	smat.emission_enabled = true
	smat.emission = Color(0.55, 0.96, 1.0)
	smat.emission_energy_multiplier = 2.4
	surf.material_override = smat
	_visual.add_child(surf)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.4, 1.5)
	light.light_color = Color(0.65, 0.96, 1.0)
	light.light_energy = 4.0
	light.omni_range = 12.0
	light.shadow_enabled = false
	_visual.add_child(light)


func _process(delta: float) -> void:
	_time += delta
	match kind:
		"mine":
			position.y = _origin.y + sin(_time * 1.9) * 0.32
		"shark", "piraya":
			var prev_x := position.x
			position.x = _origin.x + sin(_time * (patrol_speed / maxf(patrol_range, 1.0))) * patrol_range
			position.y = _origin.y + cos(_time * 2.2) * 0.35
			if _visual:
				var moving_right := position.x >= prev_x
				_visual.scale.x = 1.0 if moving_right else -1.0
		"pickup":
			if _visual and not _collected:
				_visual.rotation.y += delta * 1.8
				_visual.position.y = sin(_time * 2.6) * 0.22


func _on_body_entered(body: Node) -> void:
	if not (body is SwimmingController):
		return
	var sw := body as SwimmingController
	match kind:
		"bubble_column":
			sw.set_in_air_zone(true)
		"mine":
			sw.hit_by_hazard(25.0, global_position)
		"shark":
			sw.hit_by_hazard(30.0, global_position)
		"piraya":
			sw.hit_by_hazard(18.0, global_position)
		"pickup":
			if _collected:
				return
			_collected = true
			if pickup_flag != "":
				GameState.quest_flags[pickup_flag] = true
			GameState.add_coins(25)
			if pickup_label != "":
				GameState.emit_signal("dialogue_requested", "Pinky", ["Fant " + pickup_label + "! Svøm opp til overflaten igjen!"])
			visible = false
		"exit":
			if _time >= 1.5 and target_level_id != "":
				GameState.request_level(target_level_id)


func _on_body_exited(body: Node) -> void:
	if body is SwimmingController and kind == "bubble_column":
		(body as SwimmingController).set_in_air_zone(false)
