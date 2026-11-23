shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Ekte sanntids 3D svømmeanimasjon direkte på Pinkys mesh + rik, skarp og mettet karakter-shading
// (ingen blass/fadet vask i undervannsmiljøet!).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D fabric_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_tex = false;
uniform bool has_fabric_normal = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.56;
uniform float swim_phase = 0.0;
uniform float swim_intensity : hint_range(0.0, 1.5) = 1.0;

vec2 rot2(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

void vertex() {
	vec3 v = VERTEX;
	vec3 n = NORMAL;

	float ax = abs(v.x);
	float sx = v.x >= 0.0 ? 1.0 : -1.0;

	// 1. ARMER: Kun armer/hender (|x| > 0.215, y i [0.42..1.02]) – urørt skjorte og belte!
	float arm_x = smoothstep(0.215, 0.268, ax);
	float arm_y = smoothstep(0.42, 0.56, v.y) * (1.0 - smoothstep(0.95, 1.03, v.y));
	float arm_w = arm_x * arm_y;

	if (arm_w > 0.001) {
		vec3 sh = vec3(sx * 0.21, 0.94, 0.02);
		vec3 d = v - sh;
		float ph = swim_phase + (sx > 0.0 ? 0.0 : 3.14159);
		float reach = 0.5 + 0.5 * sin(ph);
		float pitch_ang = mix(0.45, mix(0.80, 3.05, reach), clamp(swim_intensity, 0.20, 1.0)) * arm_w;
		float out_ang = cos(ph) * 0.22 * swim_intensity * arm_w;

		vec2 yz = rot2(vec2(d.y, d.z), pitch_ang);
		d.y = yz.x;
		d.z = yz.y;
		vec2 xy = rot2(vec2(d.x, d.y), sx * out_ang);
		d.x = xy.x;
		d.y = xy.y;

		vec2 nyz = rot2(vec2(n.y, n.z), pitch_ang);
		n.y = nyz.x;
		n.z = nyz.y;
		v = sh + d;
	}

	// 2. BEIN: Dynamisk saks-/beinspark i motfase med naturlig knebøy!
	float leg_w = (1.0 - smoothstep(0.30, 0.44, v.y)) * (1.0 - arm_w);
	if (leg_w > 0.001) {
		float leg_side = smoothstep(-0.025, 0.025, v.x) * 2.0 - 1.0;
		vec3 hip = vec3(leg_side * 0.08, 0.44, 0.0);
		vec3 d = v - hip;
		float kick_ph = swim_phase * 2.0;
		float kick_ang = leg_side * sin(kick_ph) * 0.55 * swim_intensity * leg_w;
		float knee_w = 1.0 - smoothstep(-0.05, 0.20, v.y);
		float knee_bend = (0.24 + 0.18 * cos(kick_ph * leg_side)) * swim_intensity * knee_w;

		vec2 yz = rot2(vec2(d.y, d.z), kick_ang - knee_bend);
		d.y = yz.x;
		d.z = yz.y;
		vec2 nyz = rot2(vec2(n.y, n.z), kick_ang - knee_bend);
		n.y = nyz.x;
		n.z = nyz.y;
		v = hip + d;
	}

	// 3. HODE: Løft haken fremover slik at Pinky ser rett frem i svømmeretningen!
	float head_w = smoothstep(0.98, 1.12, v.y);
	if (head_w > 0.001) {
		vec3 neck = vec3(0.0, 1.02, 0.0);
		vec3 d = v - neck;
		float look_up = 0.54 * clamp(swim_intensity, 0.25, 1.0) * head_w;
		vec2 yz = rot2(vec2(d.y, d.z), look_up);
		d.y = yz.x;
		d.z = yz.y;
		vec2 nyz = rot2(vec2(n.y, n.z), look_up);
		n.y = nyz.x;
		n.z = nyz.y;
		v = neck + d;
	}

	v.z += sin(swim_phase * 2.0 - v.y * 3.0) * 0.03 * swim_intensity;

	VERTEX = v;
	NORMAL = normalize(n);
}

void fragment() {
	vec3 alb = albedo_color.rgb;
	if (has_albedo_tex) {
		alb *= texture(albedo_tex, UV).rgb;
	}
	// Dyp, skarp og rik fargekontrast (fjerner blass 2005-vask slik at rød-hvite striper og bandana popper!)
	alb = pow(max(alb, vec3(0.0001)), vec3(1.26)) * 1.10;
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, 1.28);

	if (has_fabric_normal) {
		NORMAL_MAP = texture(fabric_normal_tex, UV * 7.0).rgb;
		NORMAL_MAP_DEPTH = 0.42;
	}

	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.4);
	ALBEDO = clamp(alb, vec3(0.0), vec3(1.05));
	ROUGHNESS = roughness_val;
	METALLIC = 0.04;
	SPECULAR = 0.55;
	EMISSION = vec3(0.24, 0.78, 0.96) * fres * 0.16;
}
