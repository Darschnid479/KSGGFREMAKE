extends Node
class_name CharacterAnimator
## Styrer ekte sanntids skjelett-animasjoner (bein, knær, hofter, overkropp, skuldre, albuer, hode)
## for Pinky, Kaptein Sabeltann, Langemann, Pelle, Pysa og fiender via character_anim.gdshader.

const CHAR_ANIM_SHADER := preload("res://shaders/character_anim.gdshader")

var materials: Array[ShaderMaterial] = []
var state: String = "idle" # "idle", "walk", "run", "jump", "attack", "talk", "push", "hurt", "die"
var phase: float = 0.0
var attack_t: float = 0.0
var hurt_t: float = 0.0
var _smooth_speed: float = 0.0
var _cur := {
	"hip_bob": 0.0, "hip_twist": 0.0, "torso_lean": 0.0, "torso_twist": 0.0,
	"head_nod": 0.0, "head_yaw": 0.0,
	"l_thigh_pitch": 0.0, "l_knee_bend": 0.0, "r_thigh_pitch": 0.0, "r_knee_bend": 0.0,
	"l_arm_pitch": 0.0, "l_arm_out": 0.0, "l_elbow_bend": 0.0,
	"r_arm_pitch": 0.0, "r_arm_out": 0.0, "r_elbow_bend": 0.0,
}


static func attach_to(visual_root: Node3D, forward_sign: float = -1.0) -> CharacterAnimator:
	var anim := CharacterAnimator.new()
	anim.name = "CharacterAnimator"
	visual_root.add_child(anim)
	anim._bind_meshes(visual_root, forward_sign)
	return anim


func _bind_meshes(root: Node, forward_sign: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_body_meshes(root, meshes)
	if meshes.is_empty():
		return

	var min_y := 99999.0
	var max_y := -99999.0
	var min_z := 99999.0
	var max_z := -99999.0
	var chest_xs: Array[float] = []
	for mi in meshes:
		var aabb: AABB = mi.get_aabb()
		min_y = minf(min_y, aabb.position.y)
		max_y = maxf(max_y, aabb.position.y + aabb.size.y)
		min_z = minf(min_z, aabb.position.z)
		max_z = maxf(max_z, aabb.position.z + aabb.size.z)

	var h: float = maxf(max_y - min_y, 0.25)
	for mi in meshes:
		var mdt := MeshDataTool.new()
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			if mdt.create_from_surface(mi.mesh, 0) == OK:
				for vi in range(mdt.get_vertex_count()):
					var v := mdt.get_vertex(vi)
					var yn := (v.y - min_y) / h
					if yn >= 0.48 and yn <= 0.72:
						chest_xs.append(absf(v.x))
	chest_xs.sort()
	var chest_med: float = chest_xs[int(chest_xs.size() * 0.45)] if not chest_xs.is_empty() else (h * 0.14)
	var half_w: float = clampf(chest_med * 0.85, h * 0.08, h * 0.16)
	var leg_mx: float = clampf(half_w * 1.15, h * 0.10, h * 0.19)
	var z_mid: float = (min_z + max_z) * 0.5
	var fab := VisualEnhancer.get_pbr_pack("fabric_detail")
	var fab_nrm: Texture2D = fab.get("normal", null)

	for mi in meshes:
		if mi.mesh == null:
			continue
		for si in range(mi.mesh.get_surface_count()):
			var orig := mi.get_active_material(si)
			var sm := ShaderMaterial.new()
			sm.shader = CHAR_ANIM_SHADER
			if orig is StandardMaterial3D:
				var std := orig as StandardMaterial3D
				sm.set_shader_parameter("albedo_tint", std.albedo_color)
				sm.set_shader_parameter("base_roughness", clampf(std.roughness, 0.45, 0.90))
				sm.set_shader_parameter("base_metallic", minf(std.metallic, 0.15))
				if std.albedo_texture:
					sm.set_shader_parameter("has_albedo_tex", true)
					sm.set_shader_parameter("albedo_tex", std.albedo_texture)
				else:
					sm.set_shader_parameter("has_albedo_tex", false)
				if std.normal_enabled and std.normal_texture:
					sm.set_shader_parameter("has_normal_tex", true)
					sm.set_shader_parameter("normal_tex", std.normal_texture)
				else:
					sm.set_shader_parameter("has_normal_tex", false)
				if std.roughness_texture:
					sm.set_shader_parameter("has_orm_tex", true)
					sm.set_shader_parameter("orm_tex", std.roughness_texture)
				else:
					sm.set_shader_parameter("has_orm_tex", false)
			else:
				sm.set_shader_parameter("has_albedo_tex", false)
				sm.set_shader_parameter("has_normal_tex", false)
				sm.set_shader_parameter("has_orm_tex", false)
			if fab_nrm and not bool(sm.get_shader_parameter("has_normal_tex")):
				sm.set_shader_parameter("has_fabric_normal", true)
				sm.set_shader_parameter("fabric_normal_tex", fab_nrm)
			else:
				sm.set_shader_parameter("has_fabric_normal", false)
			sm.set_shader_parameter("mesh_min_y", min_y)
			sm.set_shader_parameter("mesh_height", h)
			sm.set_shader_parameter("torso_half_w", half_w)
			sm.set_shader_parameter("leg_max_x", leg_mx)
			sm.set_shader_parameter("z_center", z_mid)
			sm.set_shader_parameter("forward_sign", forward_sign)
			# Start umiddelbart med naturlig avslappede armer langs siden (null T/A-pose!)
			sm.set_shader_parameter("l_arm_out", -0.88)
			sm.set_shader_parameter("r_arm_out", -0.88)
			sm.set_shader_parameter("l_elbow_bend", 0.28)
			sm.set_shader_parameter("r_elbow_bend", 0.30)
			mi.set_surface_override_material(si, sm)
			materials.append(sm)
	_cur["l_arm_out"] = -0.88
	_cur["r_arm_out"] = -0.88
	_cur["l_elbow_bend"] = 0.28
	_cur["r_elbow_bend"] = 0.30


func _collect_body_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.visible and mi.mesh != null:
			var nm := mi.name.to_lower()
			if not ("shadow" in nm or "crosshair" in nm or "swoosh" in nm or nm == "rapier"):
				out.append(mi)
	for c in node.get_children():
		_collect_body_meshes(c, out)


func trigger_attack() -> void:
	attack_t = 0.38


func trigger_hurt() -> void:
	hurt_t = 0.30


func update_anim(delta: float, move_speed: float, on_floor: bool, is_talking: bool = false, is_pushing: bool = false, is_dead: bool = false) -> void:
	if materials.is_empty():
		return

	_smooth_speed = lerpf(_smooth_speed, move_speed, clampf(delta * 12.0, 0.0, 1.0))
	if attack_t > 0.0:
		attack_t = maxf(0.0, attack_t - delta)
	if hurt_t > 0.0:
		hurt_t = maxf(0.0, hurt_t - delta)

	var tgt := {
		"hip_bob": 0.0, "hip_twist": 0.0, "torso_lean": 0.0, "torso_twist": 0.0,
		"head_nod": 0.0, "head_yaw": 0.0,
		"l_thigh_pitch": 0.0, "l_knee_bend": 0.0, "r_thigh_pitch": 0.0, "r_knee_bend": 0.0,
		"l_arm_pitch": 0.0, "l_arm_out": -0.88, "l_elbow_bend": 0.28,
		"r_arm_pitch": 0.0, "r_arm_out": -0.88, "r_elbow_bend": 0.30,
	}

	if is_dead:
		state = "die"
		tgt["torso_lean"] = -1.35
		tgt["hip_bob"] = -0.32
		tgt["l_arm_out"] = -0.25
		tgt["r_arm_out"] = -0.25
	elif not on_floor:
		state = "jump"
		phase += delta * 4.0
		tgt["torso_lean"] = 0.20
		tgt["l_thigh_pitch"] = 0.68
		tgt["l_knee_bend"] = 1.05
		tgt["r_thigh_pitch"] = 0.28
		tgt["r_knee_bend"] = 0.78
		tgt["l_arm_pitch"] = 0.58
		tgt["r_arm_pitch"] = 0.46
		tgt["l_arm_out"] = -0.40
		tgt["r_arm_out"] = -0.40
		tgt["l_elbow_bend"] = 0.58
		tgt["r_elbow_bend"] = 0.58
	elif is_pushing:
		state = "push"
		phase += delta * 6.5
		var s := sin(phase)
		tgt["torso_lean"] = 0.38
		tgt["hip_bob"] = absf(s) * 0.024
		tgt["l_thigh_pitch"] = s * 0.50
		tgt["r_thigh_pitch"] = -s * 0.50
		tgt["l_knee_bend"] = maxf(0.0, -cos(phase)) * 0.68 + 0.15
		tgt["r_knee_bend"] = maxf(0.0, cos(phase)) * 0.68 + 0.15
		tgt["l_arm_pitch"] = 1.10
		tgt["r_arm_pitch"] = 1.10
		tgt["l_arm_out"] = -0.52
		tgt["r_arm_out"] = -0.52
		tgt["l_elbow_bend"] = 0.22
		tgt["r_elbow_bend"] = 0.22
	elif _smooth_speed > 0.30:
		var is_run := _smooth_speed > 4.2
		state = "run" if is_run else "walk"
		var freq := clampf(_smooth_speed * (1.55 if is_run else 1.85), 4.2, 10.2)
		phase += delta * freq
		var s := sin(phase)
		var c := cos(phase)
		var stride := clampf(_smooth_speed / 4.8, 0.48, 1.12)
		var leg_amp := (0.82 if is_run else 0.56) * stride
		var knee_amp := (1.10 if is_run else 0.74) * stride
		var arm_amp := (0.78 if is_run else 0.50) * stride

		tgt["hip_bob"] = absf(s) * (0.036 if is_run else 0.022) * stride
		tgt["hip_twist"] = s * 0.12 * stride
		tgt["torso_twist"] = -s * 0.15 * stride
		tgt["torso_lean"] = (0.18 if is_run else 0.06) * stride
		tgt["head_nod"] = -absf(s) * 0.05

		tgt["l_thigh_pitch"] = s * leg_amp
		tgt["r_thigh_pitch"] = -s * leg_amp
		tgt["l_knee_bend"] = maxf(0.0, -c) * knee_amp + 0.08
		tgt["r_knee_bend"] = maxf(0.0, c) * knee_amp + 0.08

		tgt["l_arm_pitch"] = -s * arm_amp
		tgt["r_arm_pitch"] = s * arm_amp
		tgt["l_arm_out"] = -0.78 if is_run else -0.84
		tgt["r_arm_out"] = -0.78 if is_run else -0.84
		tgt["l_elbow_bend"] = (0.80 if is_run else 0.36) + maxf(0.0, -s) * 0.28
		tgt["r_elbow_bend"] = (0.80 if is_run else 0.36) + maxf(0.0, s) * 0.28
	elif is_talking:
		state = "talk"
		phase += delta * 4.2
		tgt["hip_bob"] = sin(phase * 0.65) * 0.010
		tgt["torso_twist"] = sin(phase * 0.7) * 0.12
		tgt["torso_lean"] = 0.04 + sin(phase * 1.1) * 0.03
		tgt["head_nod"] = sin(phase * 1.9) * 0.16
		tgt["head_yaw"] = sin(phase * 0.85) * 0.18
		tgt["l_arm_pitch"] = 0.36 + sin(phase * 1.3) * 0.24
		tgt["r_arm_pitch"] = 0.46 + cos(phase * 1.5) * 0.28
		tgt["l_arm_out"] = -0.72 + sin(phase * 1.1) * 0.08
		tgt["r_arm_out"] = -0.72 + cos(phase * 1.2) * 0.08
		tgt["l_elbow_bend"] = 0.68 + sin(phase * 1.7) * 0.20
		tgt["r_elbow_bend"] = 0.74 + cos(phase * 1.4) * 0.20
	else:
		state = "idle"
		phase += delta * 2.0
		tgt["hip_bob"] = sin(phase) * 0.008
		tgt["torso_lean"] = sin(phase * 0.8) * 0.02
		tgt["head_yaw"] = sin(phase * 0.45) * 0.08
		tgt["l_arm_out"] = -0.88 + sin(phase) * 0.015
		tgt["r_arm_out"] = -0.88 + sin(phase) * 0.015
		tgt["l_elbow_bend"] = 0.28
		tgt["r_elbow_bend"] = 0.30

	if attack_t > 0.0:
		var u := 1.0 - (attack_t / 0.38)
		var slash := sin(u * PI)
		var swing := lerpf(1.45, -0.82, smoothstep(0.18, 0.82, u))
		tgt["torso_twist"] = lerpf(-0.45, 0.58, smoothstep(0.12, 0.78, u))
		tgt["torso_lean"] = 0.24 * slash
		tgt["r_arm_pitch"] = swing
		tgt["r_arm_out"] = -0.15 + 0.35 * slash
		tgt["r_elbow_bend"] = 0.35 * (1.0 - slash * 0.6)
		tgt["l_arm_pitch"] = -0.35 * slash
		tgt["l_arm_out"] = -0.25
		tgt["l_elbow_bend"] = 0.45

	if hurt_t > 0.0:
		var hs := sin((hurt_t / 0.30) * PI)
		tgt["torso_lean"] -= 0.32 * hs
		tgt["head_nod"] -= 0.22 * hs

	var blend := clampf(delta * 16.0, 0.0, 1.0)
	for k in _cur.keys():
		_cur[k] = lerpf(float(_cur[k]), float(tgt[k]), blend)
		for sm in materials:
			sm.set_shader_parameter(k, _cur[k])
