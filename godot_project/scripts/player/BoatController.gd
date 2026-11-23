extends CharacterBody3D
class_name BoatController
## Styring av Den Sorte Dame på verdenskartet (port av sabeltannboat.ls + boat.ls).

@export var max_speed: float = 22.0
@export var turn_speed: float = 1.65
@export var cannon_cooldown: float = 1.1

var camera_rig: FollowCamera
var _cur_speed: float = 0.0
var _cannon_timer: float = 0.0
var _bob_t: float = 0.0
var _ship_visual: Node3D

const ROCK_SCENE := preload("res://scripts/world/SlingshotRock.gd")


func _ready() -> void:
	add_to_group("player")
	_ship_visual = Node3D.new()
	add_child(_ship_visual)

	# Bygg en stilfull HD-skute (eller bruk w3d-modell)
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.8, 1.4, 7.2)
	hull.mesh = box
	hull.position.y = 0.5
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.14, 0.09, 0.07)
	hmat.roughness = 0.72
	hull.material_override = hmat
	_ship_visual.add_child(hull)

	# Mast & svart sjørøverseil
	var mast := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.22
	cyl.height = 7.5
	mast.mesh = cyl
	mast.position = Vector3(0.0, 4.2, 0.0)
	mast.material_override = hmat
	_ship_visual.add_child(mast)

	var sail := MeshInstance3D.new()
	var sbox := BoxMesh.new()
	sbox.size = Vector3(4.2, 4.0, 0.12)
	sail.mesh = sbox
	sail.position = Vector3(0.0, 4.6, -0.35)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.09, 0.09, 0.11)
	smat.roughness = 0.85
	sail.material_override = smat
	_ship_visual.add_child(sail)

	# Akterlanterne
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(0.0, 2.2, 3.4)
	lantern.light_color = Color(1.0, 0.72, 0.30)
	lantern.light_energy = 4.0
	lantern.omni_range = 14.0
	_ship_visual.add_child(lantern)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") or event.is_action_pressed("jump"):
		_fire_broadsides()
	elif event.is_action_pressed("interact"):
		_check_dock_portal()


func _physics_process(delta: float) -> void:
	_cannon_timer = max(0.0, _cannon_timer - delta)
	var throttle := Input.get_axis("move_backward", "move_forward")
	var steer := Input.get_axis("move_right", "move_left")

	_cur_speed = lerp(_cur_speed, throttle * max_speed, delta * 2.5)
	rotation.y += steer * turn_speed * delta * (0.4 + 0.6 * clamp(abs(_cur_speed) / max_speed, 0.0, 1.0))

	var fwd := -global_transform.basis.z
	velocity = Vector3(fwd.x * _cur_speed, 0.0, fwd.z * _cur_speed)
	move_and_slide()
	global_position.y = 0.0

	# Realistisk bølge-dupping og krenging i svinger
	_bob_t += delta * 2.2
	_ship_visual.position.y = sin(_bob_t) * 0.22
	_ship_visual.rotation.x = sin(_bob_t * 0.85) * 0.045
	_ship_visual.rotation.z = lerp(_ship_visual.rotation.z, -steer * 0.16, delta * 4.0)


func _fire_broadsides() -> void:
	if _cannon_timer > 0.0:
		return
	_cannon_timer = cannon_cooldown
	AudioManager.play_sfx("cannon")
	for side: float in [-1.0, 1.0]:
		var dir: Vector3 = global_transform.basis.x * side
		var ball: SlingshotRock = ROCK_SCENE.new()
		get_parent().add_child(ball)
		ball.launch(global_position + Vector3(0.0, 1.4, 0.0) + dir * 2.0, dir, 40.0, 32.0, 0.38)


func _check_dock_portal() -> void:
	for node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D and global_position.distance_to(node.global_position) < 18.0:
			if node.has_method("interact"):
				node.interact(self)
				return
