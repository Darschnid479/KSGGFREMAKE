extends Area3D
class_name PortalTrigger
## Glødende nivå-portal (port av portal.ls / portalchoice.ls) som fører til neste øy eller område.

@export var target_level_id: String = "world_map"
@export var portal_label: String = "Seil videre"
var _ring: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.6
	col.shape = sph
	add_child(col)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.3
	torus.outer_radius = 1.6
	_ring.mesh = torus
	_ring.position.y = 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.78, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.72, 0.15)
	mat.emission_energy_multiplier = 2.4
	_ring.material_override = mat
	add_child(_ring)

	var light := OmniLight3D.new()
	light.position.y = 1.6
	light.light_color = Color(1.0, 0.80, 0.30)
	light.light_energy = 2.8
	light.omni_range = 10.0
	add_child(light)

	var lbl := Label3D.new()
	lbl.text = "[E] " + portal_label
	lbl.position.y = 2.8
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 42
	lbl.outline_size = 10
	lbl.modulate = Color(1.0, 0.92, 0.65)
	add_child(lbl)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(_ring):
		_ring.rotate_y(delta * 1.4)
		_ring.position.y = 0.25 + sin(_t * 2.5) * 0.12


func interact(_actor: Node) -> void:
	AudioManager.play_sfx("portal")
	GameState.request_level(target_level_id)
