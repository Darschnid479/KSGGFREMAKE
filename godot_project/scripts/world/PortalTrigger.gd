extends Area3D
class_name PortalTrigger
## Elegant stilisert nautisk kompass-portal (port av portal.ls / portalchoice.ls) med mykt lys og nærhetstekst.

@export var target_level_id: String = "world_map"
@export var portal_label: String = "Seil videre"
@export var is_world_map_buoy: bool = false

var _ring: Node3D
var _lbl: Label3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 5.2 if is_world_map_buoy else 2.6
	col.shape = sph
	add_child(col)

	if is_world_map_buoy:
		var buoy_root := Node3D.new()
		var buoy_path := "res://assets/store/polyhaven/ocean_buoy/ocean_buoy_1k.gltf"
		if ResourceLoader.exists(buoy_path):
			var sc := load(buoy_path) as PackedScene
			if sc:
				var binst := sc.instantiate()
				binst.scale = Vector3.ONE * 1.45
				buoy_root.add_child(binst)
		else:
			var cyl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.4
			cm.bottom_radius = 0.65
			cm.height = 2.0
			cyl.mesh = cm
			buoy_root.add_child(cyl)
		var light := OmniLight3D.new()
		light.position.y = 2.4
		light.light_color = Color(1.0, 0.78, 0.34)
		light.light_energy = 2.2
		light.omni_range = 12.0
		buoy_root.add_child(light)
		_ring = buoy_root
		add_child(_ring)
	else:
		# Hold portaler på land/skipsdekk helt uten prangende torus-ringer
		_ring = Node3D.new()
		_ring.visible = false
		add_child(_ring)

	# Flytende tekst vises KUN når spilleren er rett i nærheten
	_lbl = Label3D.new()
	_lbl.text = "[E] " + portal_label
	_lbl.position.y = 3.8 if is_world_map_buoy else 2.4
	_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lbl.font_size = 36 if is_world_map_buoy else 30
	_lbl.outline_size = 8
	_lbl.modulate = Color(1.0, 0.94, 0.74, 0.0)
	_lbl.visible = false
	add_child(_lbl)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_ring) and is_world_map_buoy:
		_ring.rotation.y = sin(_t * 0.65) * 0.25
		_ring.rotation.z = cos(_t * 1.35) * 0.08
		_ring.position.y = 0.15 + sin(_t * 1.9) * 0.14

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
