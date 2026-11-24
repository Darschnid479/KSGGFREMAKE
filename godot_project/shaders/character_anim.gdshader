shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Ekte sanntids skjelett-deformasjonsshader for alle karakterer (Pinky, Sabeltann, Langemann, Pelle, Pysa, fiender):
// Hierarkiske hofte-, kne-, skulder-, albue-, overkropp- og hode-rotasjoner med myk vekting + skarp PBR-stoffdetalj!

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D fabric_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_tex = true;
uniform bool has_fabric_normal = false;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float base_roughness : hint_range(0.05, 1.0) = 0.62;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;

// Karakterens målte høyde- og bredde-parametre (satt automatisk per modell av CharacterAnimator.gd)
uniform float mesh_min_y = 0.0;
uniform float mesh_height = 1.66;
uniform float torso_half_w = 0.22;
uniform float leg_max_x = 0.24;
uniform float z_center = 0.0;
uniform float forward_sign = -1.0; // -1.0 hvis karakteren ser mot -Z, +1.0 hvis +Z

// Sanntids skjelett-vinkler (radianer) styrt av CharacterAnimator.gd
uniform float hip_bob = 0.0;
uniform float hip_twist = 0.0;
uniform float torso_lean = 0.0;
uniform float torso_twist = 0.0;
uniform float head_nod = 0.0;
uniform float head_yaw = 0.0;

uniform float l_thigh_pitch = 0.0;
uniform float l_knee_bend = 0.0; // >= 0 bøyer kneet bakover
uniform float r_thigh_pitch = 0.0;
uniform float r_knee_bend = 0.0;

uniform float l_arm_pitch = 0.0;
uniform float l_arm_out = 0.0;
uniform float l_elbow_bend = 0.0; // >= 0 bøyer albuen fremover
uniform float r_arm_pitch = 0.0;
uniform float r_arm_out = 0.0;
uniform float r_elbow_bend = 0.0;

vec3 rot_x(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

vec3 rot_y(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

vec3 rot_z(vec3 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

void vertex() {
	float h = max(mesh_height, 0.2);
	float yn = clamp((VERTEX.y - mesh_min_y) / h, 0.0, 1.0);
	vec3 p = VERTEX;
	vec3 n = NORMAL;

	float hip_y = mesh_min_y + 0.48 * h;
	float knee_y = mesh_min_y + 0.24 * h;
	float waist_y = mesh_min_y + 0.50 * h;
	float sh_y = mesh_min_y + 0.74 * h;
	float elbow_y = mesh_min_y + 0.54 * h;
	float neck_y = mesh_min_y + 0.80 * h;
	float fwd = -forward_sign; // +1 når karakteren ser mot -Z

	// 1. BEIN & KNÆR (yn < 0.49 OG |x| innenfor beinsonen slik at hendene i A-posen ALDRI blir dratt med beina!)
	float leg_x_mask = 1.0 - smoothstep(leg_max_x * 0.88, leg_max_x * 1.12, abs(p.x));
	float leg_mask = (1.0 - smoothstep(0.42, 0.50, yn)) * leg_x_mask;
	float shin_mask = (1.0 - smoothstep(0.20, 0.28, yn)) * leg_x_mask;
	float l_side = 1.0 - smoothstep(-0.04, 0.02, p.x);
	float r_side = smoothstep(-0.02, 0.04, p.x);

	if (leg_mask > 0.001) {
		float w_l = leg_mask * l_side;
		float w_r = leg_mask * r_side;
		float ws_l = shin_mask * l_side;
		float ws_r = shin_mask * r_side;

		// Først bøy leggen bakover rundt kneleddet
		float knee_a = -(l_knee_bend * ws_l + r_knee_bend * ws_r) * fwd;
		if (abs(knee_a) > 0.0005) {
			vec3 kp = vec3(p.x, knee_y, z_center);
			p = kp + rot_x(p - kp, knee_a);
			n = rot_x(n, knee_a);
		}

		// Deretter sving hele beinet (lår + bøyd legg) rundt hofteleddet
		float thigh_a = (l_thigh_pitch * w_l + r_thigh_pitch * w_r) * fwd;
		if (abs(thigh_a) > 0.0005) {
			vec3 hp = vec3(p.x, hip_y, z_center);
			p = hp + rot_x(p - hp, thigh_a);
			n = rot_x(n, thigh_a);
		}
	}

	// 2. ARMER, ALBUER & HENDER (fanger hele overarm + underarm fra skulder og ut, slik at ingen blir stående i T/A-pose!)
	float arm_band = smoothstep(0.24, 0.34, yn) * (1.0 - smoothstep(0.79, 0.88, yn));
	float arm_inner = mix(leg_max_x * 0.84, torso_half_w * 0.84, smoothstep(0.40, 0.64, yn));
	float arm_x = smoothstep(arm_inner * 0.82, arm_inner * 1.12, abs(p.x));
	float arm_mask = arm_band * arm_x;
	float forearm_mask = arm_mask * (1.0 - smoothstep(0.50, 0.62, yn));

	if (arm_mask > 0.001) {
		float left_x = 1.0 - smoothstep(-0.04, 0.01, p.x);
		float right_x = smoothstep(-0.01, 0.04, p.x);
		float al = arm_mask * left_x;
		float ar = arm_mask * right_x;
		float fl = forearm_mask * left_x;
		float fr = forearm_mask * right_x;

		// Bøy underarmen + hånden fremover rundt albuen
		float elb_a = (l_elbow_bend * fl + r_elbow_bend * fr) * fwd;
		if (abs(elb_a) > 0.0005) {
			vec3 ep = vec3(sign(p.x) * torso_half_w * 1.12, elbow_y, z_center);
			p = ep + rot_x(p - ep, elb_a);
			n = rot_x(n, elb_a);
		}

		// Sving hele armen rundt skulderen (frem/tilbake + senk armene naturlig inn mot hoftene!)
		float sh_pitch = (l_arm_pitch * al + r_arm_pitch * ar) * fwd;
		float sh_out = (-l_arm_out * al + r_arm_out * ar);
		if (abs(sh_pitch) > 0.0005 || abs(sh_out) > 0.0005) {
			vec3 sp = vec3(sign(p.x) * torso_half_w * 0.72, sh_y, z_center);
			vec3 rel = p - sp;
			rel = rot_z(rel, sh_out);
			rel = rot_x(rel, sh_pitch);
			p = sp + rel;
			n = rot_x(rot_z(n, sh_out), sh_pitch);
		}
	}

	// 3. OVERKROPP & HODE (lener fremover mot -Z i løp, vrir seg i sverdhugg, nikker i samtaler!)
	float upper_mask = smoothstep(0.46, 0.60, yn);
	if (upper_mask > 0.001) {
		vec3 wp = vec3(0.0, waist_y, z_center);
		vec3 rel = p - wp;
		float lean_a = -torso_lean * upper_mask * fwd;
		float twist_a = torso_twist * upper_mask;
		rel = rot_y(rot_x(rel, lean_a), twist_a);
		p = wp + rel;
		n = rot_y(rot_x(n, lean_a), twist_a);
	}

	float head_mask = smoothstep(0.79, 0.87, yn);
	if (head_mask > 0.001) {
		vec3 np = vec3(0.0, neck_y, z_center);
		vec3 rel = p - np;
		float nod_a = -head_nod * head_mask * fwd;
		rel = rot_y(rot_x(rel, nod_a), head_yaw * head_mask);
		p = np + rel;
		n = rot_y(rot_x(n, nod_a), head_yaw * head_mask);
	}

	// 4. HOFTE-GYNGING & VERTIKALT STEG-LØFT (beholder føttene på bakken uten å synke!)
	vec3 hp_root = vec3(0.0, hip_y, z_center);
	p = hp_root + rot_y(p - hp_root, hip_twist);
	n = rot_y(n, hip_twist);
	p.y += hip_bob * h;

	VERTEX = p;
	NORMAL = normalize(n);
}

void fragment() {
	vec3 alb = albedo_tint.rgb;
	if (has_albedo_tex) {
		vec3 c_tex = texture(albedo_tex, UV).rgb;
		vec2 tx_sz = 1.0 / max(vec2(textureSize(albedo_tex, 0)), vec2(64.0));
		vec3 b_tex = (
			texture(albedo_tex, UV + vec2(tx_sz.x, 0.0)).rgb +
			texture(albedo_tex, UV - vec2(tx_sz.x, 0.0)).rgb +
			texture(albedo_tex, UV + vec2(0.0, tx_sz.y)).rgb +
			texture(albedo_tex, UV - vec2(0.0, tx_sz.y)).rgb
		) * 0.25;
		alb *= clamp(c_tex + (c_tex - b_tex) * 0.60, vec3(0.0), vec3(1.12));
	}
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, 1.03);

	if (has_fabric_normal) {
		NORMAL_MAP = texture(fabric_normal_tex, UV * 9.0).rgb;
		NORMAL_MAP_DEPTH = 0.20;
	}

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.0));
	METALLIC = base_metallic;
	ROUGHNESS = clamp(max(base_roughness, 0.58), 0.55, 0.90);
	SPECULAR = 0.16;
}
