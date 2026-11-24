shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// 2026 Ultra-HD 4K Karakter-shader med eksakte topologiske knokkelvekter i COLOR (null hoftespiker eller arm-klipping!):
// COLOR.r = venstre arm-vekt, COLOR.g = høyre arm-vekt, COLOR.b = bein-vekt, COLOR.a = hode-vekt.
// Kombinerer 4K CC0 PBR-teksturer (stoffvev, lær, fløyel, gull, hårstrå, hud-SSS, blanke øyne).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D fabric_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_tex = true;
uniform bool has_normal_tex = false;
uniform bool has_orm_tex = false;
uniform bool has_fabric_normal = false;
uniform bool use_vertex_bone_weights = true;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float base_roughness : hint_range(0.05, 1.0) = 0.62;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;

// Karakterens målte høyde- og bredde-parametre (satt automatisk per modell av CharacterAnimator.gd)
uniform float mesh_min_y = 0.0;
uniform float mesh_height = 1.66;
uniform float torso_half_w = 0.22;
uniform float leg_max_x = 0.24;
uniform float z_center = 0.0;
uniform float forward_sign = -1.0;

// Sanntids skjelett-vinkler (radianer) styrt av CharacterAnimator.gd
uniform float hip_bob = 0.0;
uniform float hip_twist = 0.0;
uniform float torso_lean = 0.0;
uniform float torso_twist = 0.0;
uniform float head_nod = 0.0;
uniform float head_yaw = 0.0;

uniform float l_thigh_pitch = 0.0;
uniform float l_knee_bend = 0.0;
uniform float r_thigh_pitch = 0.0;
uniform float r_knee_bend = 0.0;

uniform float l_arm_pitch = 0.0;
uniform float l_arm_out = 0.0;
uniform float l_elbow_bend = 0.0;
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

	float hip_y = mesh_min_y + 0.47 * h;
	float knee_y = mesh_min_y + 0.24 * h;
	float waist_y = mesh_min_y + 0.50 * h;
	float sh_y = mesh_min_y + 0.75 * h;
	float elbow_y = mesh_min_y + 0.56 * h;
	float neck_y = mesh_min_y + 0.80 * h;
	float fwd = -forward_sign;

	// Eksakte topologiske knokkelvekter fra COLOR_0 (bakt i 3D-grafen så hofter/shorts/kjoler ALDRI dras med armene!)
	float w_l_arm = 0.0;
	float w_r_arm = 0.0;
	float leg_mask = 0.0;
	float head_mask = 0.0;

	if (use_vertex_bone_weights) {
		w_l_arm = clamp(COLOR.r, 0.0, 1.0);
		w_r_arm = clamp(COLOR.g, 0.0, 1.0);
		leg_mask = clamp(COLOR.b, 0.0, 1.0);
		head_mask = clamp(COLOR.a, 0.0, 1.0);
	} else {
		float leg_x_mask = 1.0 - smoothstep(leg_max_x * 0.88, leg_max_x * 1.12, abs(p.x));
		leg_mask = (1.0 - smoothstep(0.40, 0.48, yn)) * leg_x_mask;
		float arm_band = smoothstep(0.42, 0.54, yn) * (1.0 - smoothstep(0.79, 0.87, yn));
		float arm_x = smoothstep(torso_half_w * 1.05, torso_half_w * 1.45, abs(p.x));
		float am = arm_band * arm_x;
		w_l_arm = am * (1.0 - smoothstep(-0.04, 0.01, p.x));
		w_r_arm = am * smoothstep(-0.01, 0.04, p.x);
		head_mask = smoothstep(0.79, 0.87, yn);
	}

	// 1. BEIN & KNÆR
	if (leg_mask > 0.001) {
		float l_side = 1.0 - smoothstep(-0.04, 0.02, p.x);
		float r_side = smoothstep(-0.02, 0.04, p.x);
		float shin_mask = leg_mask * (1.0 - smoothstep(0.20, 0.28, yn));
		float w_l = leg_mask * l_side;
		float w_r = leg_mask * r_side;
		float ws_l = shin_mask * l_side;
		float ws_r = shin_mask * r_side;

		float knee_a = -(l_knee_bend * ws_l + r_knee_bend * ws_r) * fwd;
		if (abs(knee_a) > 0.0005) {
			vec3 kp = vec3(p.x, knee_y, z_center);
			p = kp + rot_x(p - kp, knee_a);
			n = rot_x(n, knee_a);
		}
		float thigh_a = (l_thigh_pitch * w_l + r_thigh_pitch * w_r) * fwd;
		if (abs(thigh_a) > 0.0005) {
			vec3 hp = vec3(p.x, hip_y, z_center);
			p = hp + rot_x(p - hp, thigh_a);
			n = rot_x(n, thigh_a);
		}
	}

	// 2. ARMER, ALBUER & HENDER (kun topologiske arm-verteks — 0% hofte/belte/kjole-forvrengning!)
	float arm_any = w_l_arm + w_r_arm;
	if (arm_any > 0.001) {
		float forearm_fac = 1.0 - smoothstep(0.50, 0.62, yn);
		float fl = w_l_arm * forearm_fac;
		float fr = w_r_arm * forearm_fac;

		float elb_a = (l_elbow_bend * fl + r_elbow_bend * fr) * fwd;
		if (abs(elb_a) > 0.0005) {
			vec3 ep = vec3(sign(p.x) * torso_half_w * 1.15, elbow_y, z_center);
			p = ep + rot_x(p - ep, elb_a);
			n = rot_x(n, elb_a);
		}

		float sh_pitch = (l_arm_pitch * w_l_arm + r_arm_pitch * w_r_arm) * fwd;
		float sh_out = (-l_arm_out * w_l_arm + r_arm_out * w_r_arm);
		if (abs(sh_pitch) > 0.0005 || abs(sh_out) > 0.0005) {
			vec3 sp = vec3(sign(p.x) * torso_half_w * 0.92, sh_y, z_center);
			vec3 rel = p - sp;
			rel = rot_z(rel, sh_out);
			rel = rot_x(rel, sh_pitch);
			p = sp + rel;
			n = rot_x(rot_z(n, sh_out), sh_pitch);
		}
	}

	// 3. OVERKROPP & HODE
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

	if (head_mask > 0.001) {
		vec3 np = vec3(0.0, neck_y, z_center);
		vec3 rel = p - np;
		float nod_a = -head_nod * head_mask * fwd;
		rel = rot_y(rot_x(rel, nod_a), head_yaw * head_mask);
		p = np + rel;
		n = rot_y(rot_x(n, nod_a), head_yaw * head_mask);
	}

	// 4. HOFTE-GYNGING & STEG-LØFT
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
		alb *= texture(albedo_tex, UV).rgb;
	}
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, 1.07);

	float rough = base_roughness;
	float metal = base_metallic;
	float ao = 1.0;

	if (has_orm_tex) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ao = mix(1.0, clamp(orm.r, 0.50, 1.0), 0.72);
		rough = clamp(orm.g, 0.06, 0.95);
		metal = clamp(max(base_metallic, orm.b), 0.0, 1.0);
	}

	if (has_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = 0.96;
	} else if (has_fabric_normal) {
		NORMAL_MAP = texture(fabric_normal_tex, UV * 10.0).rgb;
		NORMAL_MAP_DEPTH = 0.32;
	}

	float is_warm_skin = smoothstep(0.05, 0.18, alb.r - alb.b) * smoothstep(0.32, 0.55, alb.r) * (1.0 - metal) * smoothstep(0.25, 0.42, rough);
	float is_cloth = smoothstep(0.60, 0.78, rough) * (1.0 - metal);
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	// Myk moderne Pixar-stoff/fløyel-fresnel kantglød (fremhever silhuett og vevstruktur)
	float rim = pow(1.0 - ndotv, 3.0) * mix(0.14, 0.24, is_cloth);

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.0));
	METALLIC = metal;
	ROUGHNESS = rough;
	AO = ao;
	SPECULAR = mix(mix(0.42, 0.56, 1.0 - rough), 0.85, metal);
	BACKLIGHT = mix(alb * 0.10, vec3(0.48, 0.24, 0.15) * alb, is_warm_skin) * (1.0 - metal);
	RIM = rim;
	RIM_TINT = mix(0.45, 0.72, is_cloth);
	EMISSION = mix(alb, vec3(0.96, 0.93, 0.86), 0.35) * rim * 0.55;
}
