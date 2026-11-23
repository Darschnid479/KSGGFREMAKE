shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// Fotorealistisk live-action havshader med organisk rotert fBM-støy (ingen gjentakende rutenett),
// dype atlanterhavs-/karibiske sjøfarger, realistisk Fresnel-speiling og naturtro bølgeskum.

uniform vec4 deep_color : source_color = vec4(0.015, 0.065, 0.125, 0.97);
uniform vec4 shallow_color : source_color = vec4(0.035, 0.20, 0.26, 0.92);
uniform vec4 foam_color : source_color = vec4(0.86, 0.91, 0.95, 1.0);
uniform float wave_speed : hint_range(0.1, 4.0) = 0.85;
uniform float wave_height : hint_range(0.0, 2.0) = 0.18;
uniform float roughness_val : hint_range(0.01, 0.5) = 0.05;

varying vec3 v_world_pos;
varying float v_elev;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.53);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Organisk ikke-repeterende fBM-havbølge (roterte oktaver fjerner alt rutenett)
float ocean_fbm(vec2 p, float t) {
	float v = 0.0;
	float amp = 0.50;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	vec2 shift = vec2(t * 0.28, -t * 0.19);
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p + shift);
		p = rot * p * 2.08 + vec2(13.7, 29.3);
		shift = rot * shift * 1.35;
		amp *= 0.48;
	}
	return v;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = (ocean_fbm(wp.xz * 0.055, TIME * wave_speed) - 0.5) * 2.0 * wave_height;
	VERTEX.y += h;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_elev = clamp(h / max(wave_height, 0.001) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	float t = TIME * wave_speed;

	// Flerskals organiske havdønninger + finkrusninger i verdensrommet
	float eps = 0.22;
	float hc = ocean_fbm(xz * 0.16, t) * 0.65 + ocean_fbm(xz * 0.62, t * 1.4) * 0.35;
	float hx = ocean_fbm((xz + vec2(eps, 0.0)) * 0.16, t) * 0.65 + ocean_fbm((xz + vec2(eps, 0.0)) * 0.62, t * 1.4) * 0.35;
	float hz = ocean_fbm((xz + vec2(0.0, eps)) * 0.16, t) * 0.65 + ocean_fbm((xz + vec2(0.0, eps)) * 0.62, t * 1.4) * 0.35;

	vec3 wn = normalize(vec3((hc - hx) * 1.35, 1.0, (hc - hz) * 1.35));
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	NORMAL = vn;

	float ndotv = clamp(dot(vn, normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 4.0);

	// Realistisk mørk sjøfarge med subtil dybdevariasjon og kalde sky-refleksjoner
	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, clamp(hc * 0.65 + fresnel * 0.5, 0.0, 1.0));
	// Naturlig skum kun på skarpe bølgetopper (organisk støy)
	float foam = smoothstep(0.74, 0.90, hc * 0.8 + v_elev * 0.25);
	vec3 col = mix(water_col, foam_color.rgb, foam * 0.38);

	ALBEDO = col;
	METALLIC = 0.08;
	ROUGHNESS = mix(roughness_val, 0.42, foam);
	SPECULAR = 0.90;
	ALPHA = mix(deep_color.a, 0.99, clamp(fresnel * 0.55 + foam * 0.3, 0.0, 1.0));
}
