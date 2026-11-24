extends Area3D
class_name PortalTrigger
## Elegant stilisert nautisk kompass-portal (port av portal.ls / portalchoice.ls) med mykt lys og nærhetstekst.

@export var target_level_id: String = "world_map"
@export var portal_label: String = "Seil videre"
@export var is_world_map_buoy: bool = false

var _ring: MeshInstance3D
var _lbl: Label3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.2 if is_world_map_buoy else 2.6
	col.shape = sph
	add_child(col)

	# Diskret ankringsbøye-markør kun på verdenskartet (ingen prangende neon-ringer på land/skipsdekk!)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.65 if is_world_map_buoy else 0.52
	torus.outer_radius = 1.82 if is_world_map_buoy else 0.56
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.28, 1.0)
	_ring.position.y = 0.05
	_ring.visible = is_world_map_buoy
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.76, 0.56, 0.16)
	mat.metallic = 0.80
	mat.roughness = 0.30
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.68, 0.18)
	mat.emission_energy_multiplier = 0.45 if is_world_map_buoy else 0.15
	_ring.material_override = mat
	add_child(_ring)

	if is_world_map_buoy:
		var light := OmniLight3D.new()
		light.position.y = 1.0
		light.light_color = Color(1.0, 0.78, 0.32)
		light.light_energy = 1.2
		light.omni_range = 8.0
		add_child(light)

	# Flytende tekst vises KUN når Pinky er rett i nærheten (holder spillbildet rent og kinoaktig!)
	_lbl = Label3D.new()
	_lbl.text = "[E] " + portal_label
	_lbl.position.y = 2.4
	_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lbl.font_size = 30
	_lbl.outline_size = 8
	_lbl.modulate = Color(1.0, 0.94, 0.74, 0.0)
	_lbl.visible = false
	add_child(_lbl)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_ring):
		_ring.rotate_y(delta * 1.1)
		_ring.position.y = 0.14 + sin(_t * 2.2) * 0.06

	if is_instance_valid(_lbl) and not is_world_map_buoy:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty() and is_instance_valid(players[0]):
			var d := global_position.distance_to((players[0] as Node3D).global_position)
			var show_a := clampf(1.0 - (d - 4.5) / 3.5, 0.0, 1.0)
			_lbl.visible = show_a > 0.02
			_lbl.modulate.a = show_a


func interact(_actor: Node) -> void:
	AudioManager.play_sfx("portal")
	GameState.complete_level_story(GameState.current_level_id)
	GameState.request_level(target_level_id)
