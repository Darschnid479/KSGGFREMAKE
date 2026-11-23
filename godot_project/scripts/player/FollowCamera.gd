extends Node3D
class_name FollowCamera
## Moderne tredjepersons-kamera med fjærarm, myk oppfølging og valgfri mus-rotasjon.

@export var target_path: NodePath
@export var follow_height: float = 2.6
@export var default_distance: float = 9.5
@export var min_distance: float = 4.5
@export var max_distance: float = 120.0
@export var smooth_speed: float = 8.0

var target: Node3D
var yaw: float = 0.0
var pitch: float = -0.32
var distance: float = 9.5
var top_down_mode: bool = false
var side_2d_mode: bool = false
var side_2d_clamp_enabled: bool = false
var side_2d_min_x: float = -999.0
var side_2d_max_x: float = 999.0
var side_2d_min_y: float = -999.0
var side_2d_max_y: float = 999.0
var _rotating: bool = false

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	distance = default_distance
	if spring_arm:
		spring_arm.spring_length = distance
	if target_path != NodePath():
		target = get_node_or_null(target_path)


func set_side_2d_bounds(bounds: AABB, cam_dist: float) -> void:
	var half_h := cam_dist * tan(deg_to_rad(26.0))
	var half_w := half_h * (16.0 / 9.0)
	var bx0 := bounds.position.x + half_w - 0.4
	var bx1 := bounds.position.x + bounds.size.x - half_w + 0.4
	var by0 := bounds.position.y + half_h - 0.4
	var by1 := bounds.position.y + bounds.size.y - half_h + 0.4
	if bx0 <= bx1:
		side_2d_min_x = bx0
		side_2d_max_x = bx1
	else:
		var cx := bounds.get_center().x
		side_2d_min_x = cx
		side_2d_max_x = cx
	if by0 <= by1:
		side_2d_min_y = by0
		side_2d_max_y = by1
	else:
		var cy := bounds.get_center().y
		side_2d_min_y = cy
		side_2d_max_y = cy
	side_2d_clamp_enabled = true
	global_position.x = clampf(global_position.x, side_2d_min_x, side_2d_max_x)
	global_position.y = clampf(global_position.y, side_2d_min_y, side_2d_max_y)


func set_target(node: Node3D, dist: float = 9.5, height: float = 2.6, is_top_down: bool = false, is_side_2d: bool = false) -> void:
	target = node
	default_distance = dist
	distance = dist
	follow_height = height
	top_down_mode = is_top_down
	side_2d_mode = is_side_2d
	side_2d_clamp_enabled = false
	if top_down_mode:
		# 1:1 originalt fugleperspektiv for verdenskartet (ovenfra ned på Den Sorte Dame og øyene)
		pitch = -1.00
		yaw = 0.0
		if spring_arm:
			spring_arm.collision_mask = 0
			spring_arm.spring_length = distance
		if camera:
			camera.fov = 42.0
	elif side_2d_mode:
		# 1:1 originalt 2D side-scrolling undervannskamera (mapManager_swimming.ls: rett langs -Z!)
		pitch = 0.0
		yaw = 0.0
		if spring_arm:
			spring_arm.collision_mask = 0
			spring_arm.spring_length = distance
		if camera:
			camera.fov = 52.0
	else:
		if spring_arm:
			spring_arm.collision_mask = 1
			spring_arm.spring_length = distance
		if camera:
			camera.fov = 65.0
	if target:
		global_position = target.global_position + Vector3(0.0, follow_height, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var lock_orbit := top_down_mode or side_2d_mode
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE) and not lock_orbit:
			_rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clampf(distance - (4.0 if top_down_mode else 1.2), min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clampf(distance + (4.0 if top_down_mode else 1.2), min_distance, max_distance)
	elif event is InputEventKey and event.pressed and not event.echo and not lock_orbit:
		if event.keycode == KEY_C:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and not lock_orbit and (_rotating or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		yaw -= event.relative.x * GameState.mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * GameState.mouse_sensitivity, -0.95, 0.14)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired := target.global_position + Vector3(0.0, follow_height, 0.0)
	if side_2d_mode:
		desired.z = 0.0
		if side_2d_clamp_enabled:
			desired.x = clampf(desired.x, side_2d_min_x, side_2d_max_x)
			desired.y = clampf(desired.y, side_2d_min_y, side_2d_max_y)
	global_position = global_position.lerp(desired, clampf(delta * smooth_speed, 0.0, 1.0))

	if not top_down_mode and not side_2d_mode:
		if Input.is_key_pressed(KEY_Q):
			yaw += 2.0 * delta
		if Input.is_key_pressed(KEY_R):
			yaw -= 2.0 * delta
		# Myk moderne tredjepersons-oppfølging når spilleren svinger med A/D (uten at kamera kjemper mot musen)
		if not _rotating and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var turn_in := Input.get_axis("move_left", "move_right")
			if absf(turn_in) > 0.1 and not Input.is_action_pressed("move_backward"):
				yaw -= turn_in * 0.92 * delta

	rotation = Vector3(pitch, yaw, 0.0)
	if spring_arm:
		spring_arm.spring_length = lerp(spring_arm.spring_length, distance, clampf(delta * 10.0, 0.0, 1.0))


func get_forward_xz() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0001 else Vector3.FORWARD


func get_right_xz() -> Vector3:
	var r := global_transform.basis.x
	r.y = 0.0
	return r.normalized() if r.length_squared() > 0.0001 else Vector3.RIGHT
