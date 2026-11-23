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
	var min_x := 99999.0
	var max_x := -99999.0
	var min_z := 99999.0
	var max_z := -99999.0
	for mi in meshes:
		var aabb: AABB = mi.get_aabb()
		min_y = minf(min_y, aabb.position.y)
		max_y = maxf(max_y, aabb.position.y + aabb.size.y)
		min_x = minf(min_x, aabb.position.x)
		max_x = maxf(max_x, aabb.position.x + aabb.size.x)
		min_z = minf(min_z, aabb.position.z)
		max_z = maxf(max_z, aabb.position.z + aabb.size.z)

	var h: float = maxf(max_y - min_y, 0.25)
	var half_w: float = clampf((max_x - min_x) * 0.27, h * 0.10, h * 0.22)
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
				sm.set_shader_parameter("base_roughness", clampf(std.roughness, 0.35, 0.85))
				sm.set_shader_parameter("base_metallic", std.metallic)
				if std.albedo_texture:
					sm.set_shader_parameter("has_albedo_tex", true)
					sm.set_shader_parameter("albedo_tex", std.albedo_texture)
				else:
					sm.set_shader_parameter("has_albedo_tex", false)
			else:
				sm.set_shader_parameter("has_albedo_tex", false)
			if fab_nrm:
				sm.set_shader_parameter("has_fabric_normal", true)
				sm.set_shader_parameter("fabric_normal_tex", fab_nrm)
			sm.set_shader_parameter("mesh_min_y", min_y)
			sm.set_shader_parameter("mesh_height", h)
			sm.set_shader_parameter("torso_half_w", half_w)
			sm.set_shader_parameter("z_center", z_mid)
			sm.set_shader_parameter("forward_sign", forward_sign)
			mi.set_surface_override_material(si, sm)
			materials.append(sm)


func _collect_body_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.visible and mi.mesh != null:
			var nm := mi.name.to_lower()
			if not ("shadow" in nm or "crosshair" in nm or "swoosh" in nm):
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
		"l_arm_pitch": 0.0, "l_arm_out": 0.06, "l_elbow_bend": 0.12,
		"r_arm_pitch": 0.0, "r_arm_out": 0.06, "r_elbow_bend": 0.12,
	}

	if is_dead:
		state = "die"
		tgt["torso_lean"] = -1.35
		tgt["hip_bob"] = -0.32
		tgt["l_arm_out"] = 0.55
		tgt["r_arm_out"] = 0.55
	elif not on_floor:
		state = "jump"
		phase += delta * 4.0
		tgt["torso_lean"] = 0.18
		tgt["l_thigh_pitch"] = 0.62
		tgt["l_knee_bend"] = 0.98
		tgt["r_thigh_pitch"] = 0.25
		tgt["r_knee_bend"] = 0.72
		tgt["l_arm_pitch"] = 0.52
		tgt["r_arm_pitch"] = 0.42
		tgt["l_arm_out"] = 0.38
		tgt["r_arm_out"] = 0.38
		tgt["l_elbow_bend"] = 0.55
		tgt["r_elbow_bend"] = 0.55
	elif is_pushing:
		state = "push"
		phase += delta * 7.5
		var s := sin(phase)
		tgt["torso_lean"] = 0.40
		tgt["hip_bob"] = absf(s) * 0.028
		tgt["l_thigh_pitch"] = s * 0.55
		tgt["r_thigh_pitch"] = -s * 0.55
		tgt["l_knee_bend"] = maxf(0.0, -cos(phase)) * 0.72 + 0.15
		tgt["r_knee_bend"] = maxf(0.0, cos(phase)) * 0.72 + 0.15
		tgt["l_arm_pitch"] = 1.15
		tgt["r_arm_pitch"] = 1.15
		tgt["l_elbow_bend"] = 0.20
		tgt["r_elbow_bend"] = 0.20
	elif _smooth_speed > 0.35:
		var is_run := _smooth_speed > 6.8
		state = "run" if is_run else "walk"
		var freq := clampf(_smooth_speed * (1.28 if is_run else 1.55), 5.0, 14.5)
		phase += delta * freq
		var s := sin(phase)
		var c := cos(phase)
		var stride := clampf(_smooth_speed / 8.5, 0.42, 1.12)
		var leg_amp := (0.86 if is_run else 0.58) * stride
		var knee_amp := (1.18 if is_run else 0.76) * stride
		var arm_amp := (0.78 if is_run else 0.48) * stride

		# Ekte gang- og løpesyklus: høye kneløft i svingfasen, hoftesving, motsatt armsving!
		tgt["hip_bob"] = absf(s) * (0.045 if is_run else 0.026) * stride
		tgt["hip_twist"] = s * 0.14 * stride
		tgt["torso_twist"] = -s * 0.16 * stride
		tgt["torso_lean"] = (0.22 if is_run else 0.08) * stride
		tgt["head_nod"] = -absf(s) * 0.06

		tgt["l_thigh_pitch"] = s * leg_amp
		tgt["r_thigh_pitch"] = -s * leg_amp
		# Kne bøyer seg mest når beinet løftes bakfra og fremover!
		tgt["l_knee_bend"] = maxf(0.0, -c) * knee_amp + 0.08
		tgt["r_knee_bend"] = maxf(0.0, c) * knee_amp + 0.08

		tgt["l_arm_pitch"] = -s * arm_amp
		tgt["r_arm_pitch"] = s * arm_amp
		tgt["l_arm_out"] = -0.10 if is_run else -0.15
		tgt["r_arm_out"] = -0.10 if is_run else -0.15
		tgt["l_elbow_bend"] = (0.82 if is_run else 0.34) + maxf(0.0, -s) * 0.32
		tgt["r_elbow_bend"] = (0.82 if is_run else 0.34) + maxf(0.0, s) * 0.32
	elif is_talking:
		state = "talk"
		phase += delta * 4.4
		tgt["hip_bob"] = sin(phase * 0.65) * 0.012
		tgt["torso_twist"] = sin(phase * 0.7) * 0.12
		tgt["torso_lean"] = 0.06 + sin(phase * 1.1) * 0.04
		tgt["head_nod"] = sin(phase * 1.9) * 0.16
		tgt["head_yaw"] = sin(phase * 0.85) * 0.18
		tgt["l_arm_pitch"] = 0.38 + sin(phase * 1.3) * 0.25
		tgt["r_arm_pitch"] = 0.48 + cos(phase * 1.5) * 0.28
		tgt["l_arm_out"] = -0.06 + sin(phase * 1.1) * 0.10
		tgt["r_arm_out"] = -0.06 + cos(phase * 1.2) * 0.10
		tgt["l_elbow_bend"] = 0.68 + sin(phase * 1.7) * 0.22
		tgt["r_elbow_bend"] = 0.74 + cos(phase * 1.4) * 0.22
	else:
		state = "idle"
		phase += delta * 2.1
		tgt["hip_bob"] = sin(phase) * 0.010
		tgt["torso_lean"] = sin(phase * 0.8) * 0.025
		tgt["head_yaw"] = sin(phase * 0.45) * 0.08
		tgt["l_arm_out"] = -0.22 + sin(phase) * 0.02
		tgt["r_arm_out"] = -0.22 + sin(phase) * 0.02
		tgt["l_elbow_bend"] = 0.16
		tgt["r_elbow_bend"] = 0.18

	# Overstyr overkropp og høyre arm ved ekte sverdhugg!
	if attack_t > 0.0:
		var u := 1.0 - (attack_t / 0.38) # 0 -> 1
		var slash := sin(u * PI)
		var swing := lerpf(1.35, -0.75, smoothstep(0.18, 0.82, u))
		tgt["torso_twist"] = lerpf(-0.42, 0.56, smoothstep(0.12, 0.78, u))
		tgt["torso_lean"] = 0.24 * slash
		tgt["r_arm_pitch"] = swing
		tgt["r_arm_out"] = 0.45 * slash
		tgt["r_elbow_bend"] = 0.35 * (1.0 - slash * 0.6)
		tgt["l_arm_pitch"] = -0.35 * slash
		tgt["l_arm_out"] = 0.30 * slash

	if hurt_t > 0.0:
		var hs := sin((hurt_t / 0.30) * PI)
		tgt["torso_lean"] -= 0.32 * hs
		tgt["head_nod"] -= 0.22 * hs

	var blend := clampf(delta * 16.0, 0.0, 1.0)
	for k in _cur.keys():
		_cur[k] = lerpf(float(_cur[k]), float(tgt[k]), blend)
		for sm in materials:
			sm.set_shader_parameter(k, _cur[k])
