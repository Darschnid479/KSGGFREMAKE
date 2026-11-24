shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
// Moderne AAA animasjonsspill-hav (Sea of Thieves / Kena-stil):
// Ekte dybdeabsorpsjon (turkis grunne -> safirblått dyp), automatisk hvitt kystskum rundt brygger/øyer,
// undervanns-kaustikk, refraksjon, sky-speiling og glitrende solrefleksjoner.

uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform vec4 deep_color : source_color = vec4(0.012, 0.14, 0.28, 1.0);
uniform vec4 mid_color : source_color = vec4(0.02, 0.34, 0.46, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.08, 0.64, 0.68, 1.0);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.55, 0.35, -0.75);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.92, 0.72);
uniform float wave_speed : hint_range(0.1, 3.0) = 0.95;
uniform float wave_height : hint_range(0.0, 1.5) = 0.20;
uniform float depth_fade : hint_range(0.2, 16.0) = 4.2;
uniform float foam_width : hint_range(0.05, 3.5) = 0.85;
uniform float cloud_shadow_strength : hint_range(0.0, 0.5) = 0.0;
uniform float sparkle_strength : hint_range(0.0, 2.0) = 1.1;

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

float ocean_fbm(vec2 p, float t) {
	float v = 0.0;
	float amp = 0.50;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	vec2 shift = vec2(t * 0.30, -t * 0.21);
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p + shift);
		p = rot * p * 2.06 + vec2(13.7, 29.3);
		shift = rot * shift * 1.32;
		amp *= 0.48;
	}
	return v;
}

// Skimrende undervanns-kaustikknett
float caustics(vec2 p, float t) {
	float c1 = abs(vnoise(p * 1.8 + vec2(t * 0.45, -t * 0.35)) - 0.5);
	float c2 = abs(vnoise(p * 2.4 - vec2(t * 0.32, t * 0.48)) - 0.5);
	return pow(1.0 - clamp(min(c1, c2) * 3.4, 0.0, 1.0), 3.0);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = (ocean_fbm(wp.xz * 0.065, TIME * wave_speed) - 0.5) * 2.0 * wave_height;
	VERTEX.y += h;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_elev = clamp(h / max(wave_height, 0.001) * 0.5 + 0.5, 0.0, 1.0);
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	float t = TIME * wave_speed;

	// Flerskals organiske havbølger + skarpe mikrobølger
	float eps = 0.20;
	float hc = ocean_fbm(xz * 0.18, t) * 0.62 + ocean_fbm(xz * 0.72, t * 1.45) * 0.38;
	float hx = ocean_fbm((xz + vec2(eps, 0.0)) * 0.18, t) * 0.62 + ocean_fbm((xz + vec2(eps, 0.0)) * 0.72, t * 1.45) * 0.38;
	float hz = ocean_fbm((xz + vec2(0.0, eps)) * 0.18, t) * 0.62 + ocean_fbm((xz + vec2(0.0, eps)) * 0.72, t * 1.45) * 0.38;

	vec3 wn = normalize(vec3((hc - hx) * 1.75, 1.0, (hc - hz) * 1.75));
	vec3 vn = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	NORMAL = vn;

	// Ekte lineær vanndybde fra DEPTH_TEXTURE
	float raw_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc_bg = vec4(SCREEN_UV * 2.0 - 1.0, raw_depth, 1.0);
	vec4 view_bg = INV_PROJECTION_MATRIX * ndc_bg;
	view_bg.xyz /= max(view_bg.w, 0.0001);
	float bg_dist = -view_bg.z;
	float frag_dist = -VERTEX.z;
	float water_depth = max(bg_dist - frag_dist, 0.0);

	// Subtil refraksjon i grunne områder
	vec2 refract_uv = clamp(SCREEN_UV + wn.xz * 0.016 * clamp(water_depth * 0.4, 0.0, 1.0), vec2(0.002), vec2(0.998));
	vec3 bg_col = texture(screen_tex, refract_uv).rgb;

	// Beer-Lambert dybdefarge: krystallklar turkis i grunne -> dyp karibisk safir
	float shallow_t = exp(-water_depth / max(depth_fade, 0.1));
	vec3 body_col = mix(deep_color.rgb, mid_color.rgb, smoothstep(0.0, 0.65, shallow_t + hc * 0.22));
	body_col = mix(body_col, shallow_color.rgb, smoothstep(0.35, 0.95, shallow_t));

	// Glitrende kaustikk på grunne områder (under brygger/rundt strender)
	float caust = caustics(xz * 0.55, t) * shallow_t * 0.55;
	vec3 refracted = mix(body_col, bg_col * mix(vec3(0.45, 0.88, 0.90), vec3(1.0), shallow_t) + vec3(0.18, 0.52, 0.56) * caust, clamp(shallow_t * 0.72, 0.0, 0.78));

	// Fresnel himmel-speiling + varm solglans
	vec3 view_dir = normalize(VIEW);
	float ndotv = clamp(dot(vn, view_dir), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 4.2);

	vec3 sdir_v = normalize((VIEW_MATRIX * vec4(normalize(sun_dir), 0.0)).xyz);
	vec3 half_v = normalize(sdir_v + view_dir);
	float spec_broad = pow(max(dot(vn, half_v), 0.0), 64.0) * 0.26;
	float spec_glint = pow(max(dot(vn, half_v), 0.0), 260.0) * 0.85 * sparkle_strength;

	// Mykt organisk kystskum langs strender og brygger (null harde hvite streker!)
	float foam_breakup = ocean_fbm(xz * 2.1, t * 0.9);
	float shore_wave = sin(water_depth * 6.5 - t * 2.4 + hc * 3.5) * 0.5 + 0.5;
	float shore_edge = smoothstep(0.01, 0.16, water_depth);
	float shore_foam = smoothstep(foam_width * 0.65, 0.08, water_depth) * smoothstep(0.44, 0.82, shore_wave * 0.48 + foam_breakup * 0.72) * 0.48;
	float crest_foam = smoothstep(0.79, 0.94, hc * 0.76 + v_elev * 0.26) * 0.26;
	float foam = clamp(shore_foam + crest_foam, 0.0, 0.75);

	// Myke drivende skyskygger på verdenskartet
	float cloud_sh = 1.0;
	if (cloud_shadow_strength > 0.001) {
		float cn = vnoise(xz * 0.024 + vec2(t * 0.04, t * 0.025));
		cloud_sh = mix(1.0, 0.62, smoothstep(0.42, 0.75, cn) * cloud_shadow_strength * 2.0);
	}

	vec3 final_col = refracted * cloud_sh;
	final_col = mix(final_col, mix(mid_color.rgb, sun_tint, 0.28), fresnel * 0.34);
	final_col = mix(final_col, foam_color.rgb, foam);

	ALBEDO = final_col;
	EMISSION = sun_tint * (spec_broad * 0.18 + spec_glint * (1.0 - foam * 0.8)) * cloud_sh;
	METALLIC = 0.02;
	ROUGHNESS = mix(0.09, 0.56, foam);
	SPECULAR = 0.75;
	ALPHA = mix(mix(0.78, 0.95, shore_edge), 0.98, foam);
}
