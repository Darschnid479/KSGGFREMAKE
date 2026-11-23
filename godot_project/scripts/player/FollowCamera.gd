extends Node3D
class_name FollowCamera
## Moderne tredjepersons-kamera med fjærarm, myk oppfølging og valgfri mus-rotasjon.

@export var target_path: NodePath
@export var follow_height: float = 2.6
@export var default_distance: float = 9.5
@export var min_distance: float = 4.5
@export var max_distance: float = 24.0
@export var smooth_speed: float = 8.0

var target: Node3D
var yaw: float = 0.0
var pitch: float = -0.32
var distance: float = 9.5
var _rotating: bool = false

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	distance = default_distance
	if spring_arm:
		spring_arm.spring_length = distance
	if target_path != NodePath():
		target = get_node_or_null(target_path)


func set_target(node: Node3D, dist: float = 9.5, height: float = 2.6) -> void:
	target = node
	default_distance = dist
	distance = dist
	follow_height = height
	if spring_arm:
		spring_arm.spring_length = distance
	if target:
		global_position = target.global_position + Vector3(0.0, follow_height, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clamp(distance - 1.2, min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clamp(distance + 1.2, min_distance, max_distance)
	elif event is InputEventMouseMotion and (_rotating or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		yaw -= event.relative.x * GameState.mouse_sensitivity
		pitch = clamp(pitch - event.relative.y * GameState.mouse_sensitivity, -1.15, 0.25)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired := target.global_position + Vector3(0.0, follow_height, 0.0)
	global_position = global_position.lerp(desired, clamp(delta * smooth_speed, 0.0, 1.0))

	# Q/E eller piltaster kan også dreie kamera forsiktig hvis ønskelig
	if Input.is_key_pressed(KEY_Q):
		yaw += 1.8 * delta
	if Input.is_key_pressed(KEY_R):
		yaw -= 1.8 * delta

	rotation = Vector3(pitch, yaw, 0.0)
	if spring_arm:
		spring_arm.spring_length = lerp(spring_arm.spring_length, distance, clamp(delta * 10.0, 0.0, 1.0))


func get_forward_xz() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func get_right_xz() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	return r.normalized() if r.length_squared() > 0.0001 else Vector3.RIGHT
