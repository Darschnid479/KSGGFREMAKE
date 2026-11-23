shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.02, 0.14, 0.28, 0.95);
uniform vec4 shallow_color : source_color = vec4(0.05, 0.42, 0.56, 0.88);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);
uniform float wave_speed : hint_range(0.1, 4.0) = 1.1;
uniform float wave_height : hint_range(0.0, 2.0) = 0.18;
uniform float wave_frequency : hint_range(0.02, 2.0) = 0.24;
uniform float roughness_val : hint_range(0.01, 0.5) = 0.06;

varying vec3 v_world_pos;
varying float v_crest;

float wave_fn(vec2 p, float t) {
	float w1 = sin(p.x * wave_frequency + t * wave_speed) * cos(p.y * wave_frequency * 0.85 + t * wave_speed * 0.72);
	float w2 = sin((p.x * 0.72 - p.y * 0.91) * wave_frequency * 2.1 + t * wave_speed * 1.35) * 0.45;
	float w3 = cos((p.x * 1.45 + p.y * 1.12) * wave_frequency * 3.4 - t * wave_speed * 1.8) * 0.22;
	return (w1 + w2 + w3) * wave_height;
}

// Multi-octave per-pixel ripple height for crisp close-up water detail
float ripple_height(vec2 p, float t) {
	float r = 0.0;
	r += sin(p.x * 1.35 + p.y * 0.85 + t * 1.6) * 0.35;
	r += cos(p.x * 2.10 - p.y * 1.95 - t * 2.1) * 0.25;
	r += sin(p.x * 4.20 + p.y * 3.60 + t * 2.9) * 0.14;
	r += cos(p.x * 7.80 - p.y * 6.40 - t * 3.4) * 0.07;
	return r;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = wave_fn(wp.xz, TIME);
	VERTEX.y += h;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_crest = clamp((h / max(wave_height, 0.001)) * 0.5 + 0.5, 0.0, 1.0);

	float eps = 0.4;
	float hx = wave_fn(wp.xz + vec2(eps, 0.0), TIME);
	float hz = wave_fn(wp.xz + vec2(0.0, eps), TIME);
	NORMAL = normalize(vec3(h - hx, eps, h - hz));
}

void fragment() {
	// Per-pixel fine water ripple normal perturbation in view space
	float eps = 0.12;
	vec2 xz = v_world_pos.xz;
	float rc = ripple_height(xz, TIME);
	float rx = ripple_height(xz + vec2(eps, 0.0), TIME);
	float rz = ripple_height(xz + vec2(0.0, eps), TIME);
	vec3 world_ripple_n = normalize(vec3((rc - rx) * 0.55, 1.0, (rc - rz) * 0.55));
	vec3 view_ripple_n = normalize((VIEW_MATRIX * vec4(world_ripple_n, 0.0)).xyz);
	vec3 n = normalize(mix(NORMAL, view_ripple_n, 0.72));
	NORMAL = n;

	float ndotv = clamp(dot(n, normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 3.5);

	// Rich Caribbean pirate sea color blending with wave crest & ripple highlights
	float color_mix = clamp(v_crest * 0.45 + fresnel * 0.55 + rc * 0.12, 0.0, 1.0);
	vec3 base_col = mix(deep_color.rgb, shallow_color.rgb, color_mix);

	// Crisp white foam streaks along crests and bright ripples
	float foam_signal = v_crest * 0.75 + rc * 0.35;
	float foam = smoothstep(0.76, 0.96, foam_signal);
	vec3 col = mix(base_col, foam_color.rgb, foam * 0.55);

	ALBEDO = col;
	METALLIC = 0.18;
	ROUGHNESS = mix(roughness_val, 0.38, foam);
	SPECULAR = 0.85;
	ALPHA = mix(deep_color.a, 0.98, clamp(fresnel * 0.45 + foam * 0.35, 0.0, 1.0));
}
