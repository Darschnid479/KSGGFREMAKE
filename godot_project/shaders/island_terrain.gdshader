shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// AAA stilisert øy-terrengshader (Sea of Thieves / Pixar-stil):
// Sann lineær fargeromskonvertering (dype mettede farger!), skarpe lagdelte fjellklipper,
// kyststein, vindribler i ørkensand, jungelmose og glødende lavasprukk på Gral.

uniform int theme_id = 0; // 0=harbor, 1=castle(Gral), 2=desert(Fata Morgana), 3=jungle(Maga Khan), 4=palm(Skattejakt)
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying float v_height;

vec3 to_lin(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(2.2));
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_height = VERTEX.y;
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	float n_macro = texture(noise_tex, xz * 0.045).r;
	float n_med = texture(noise_tex, xz * 0.14 + vec2(0.37, 0.61)).r;
	float n_fine = texture(noise_tex, xz * 0.44 + vec2(0.19, 0.83)).r;
	float strata = sin(v_height * 4.2 + n_macro * 6.5) * 0.5 + 0.5;
	float ridge_noise = abs(n_med - 0.5) * 2.0;

	float up = clamp(v_world_nrm.y, 0.0, 1.0);
	// Skarpe fjellklipper på alle bratte skråninger + eksponerte fjellrygger!
	float slope_cliff = 1.0 - smoothstep(0.68, 0.91, up + (n_med - 0.5) * 0.12);
	float high_rock = smoothstep(4.2, 7.6, v_height + (n_macro - 0.5) * 2.0) * smoothstep(0.38, 0.72, n_med);
	float cliff_mask = clamp(max(slope_cliff, high_rock * 0.85), 0.0, 1.0);

	// Temabaserte rike sRGB-paletter konvertert til ekte lineær PBR-farge!
	vec3 sand_col = to_lin(vec3(0.84, 0.68, 0.40));
	vec3 grass_a = to_lin(vec3(0.14, 0.42, 0.16));
	vec3 grass_b = to_lin(vec3(0.28, 0.54, 0.18));
	vec3 path_col = to_lin(vec3(0.56, 0.40, 0.24));
	vec3 cliff_dark = to_lin(vec3(0.20, 0.18, 0.17));
	vec3 cliff_lit = to_lin(vec3(0.42, 0.37, 0.32));
	vec3 peak_col = to_lin(vec3(0.34, 0.31, 0.29));
	vec3 em_col = vec3(0.0);

	if (theme_id == 1) {
		// Gral: Skummel mørk vulkansk basalt, mørk forhekset lyng + glødende lilla/oransje magiske sprekker!
		sand_col = to_lin(vec3(0.20, 0.18, 0.24));
		grass_a = to_lin(vec3(0.14, 0.18, 0.20));
		grass_b = to_lin(vec3(0.22, 0.17, 0.28));
		path_col = to_lin(vec3(0.18, 0.15, 0.22));
		cliff_dark = to_lin(vec3(0.09, 0.08, 0.13));
		cliff_lit = to_lin(vec3(0.26, 0.22, 0.34));
		peak_col = to_lin(vec3(0.18, 0.16, 0.24));
		float crack = smoothstep(0.70, 0.88, n_fine) * smoothstep(1.0, 5.2, v_height) * clamp(cliff_mask + 0.35, 0.0, 1.0);
		em_col = mix(vec3(0.55, 0.12, 0.95), vec3(1.0, 0.34, 0.08), strata) * crack * 1.6;
	} else if (theme_id == 2) {
		// Fata Morgana: Rike gyldne sanddyner med vindribler + varme terrakotta sandsteinsklipper + grønn oaseflekk!
		float ripples = sin(xz.x * 2.5 + xz.y * 1.6 + n_med * 3.8) * 0.5 + 0.5;
		sand_col = to_lin(mix(vec3(0.86, 0.67, 0.34), vec3(0.94, 0.78, 0.46), ripples * 0.7));
		grass_a = to_lin(mix(vec3(0.76, 0.52, 0.22), vec3(0.88, 0.68, 0.36), ripples));
		grass_b = to_lin(vec3(0.68, 0.44, 0.19));
		path_col = to_lin(vec3(0.58, 0.34, 0.16));
		cliff_dark = to_lin(vec3(0.42, 0.22, 0.11));
		cliff_lit = to_lin(vec3(0.68, 0.42, 0.20));
		peak_col = to_lin(vec3(0.58, 0.34, 0.16));
	} else if (theme_id == 3) {
		// Maga Khans øy: Dyp frodig smaragd-jungel, mørk vulkansk moseklippe og gylne strender
		sand_col = to_lin(vec3(0.78, 0.62, 0.34));
		grass_a = to_lin(vec3(0.08, 0.32, 0.11));
		grass_b = to_lin(vec3(0.20, 0.48, 0.14));
		path_col = to_lin(vec3(0.38, 0.28, 0.16));
		cliff_dark = to_lin(vec3(0.16, 0.17, 0.14));
		cliff_lit = to_lin(vec3(0.32, 0.34, 0.24));
		peak_col = to_lin(vec3(0.25, 0.24, 0.20));
	} else if (theme_id == 4) {
		// Skattejakt-øya: Varm karibisk strand, gresskledde klipper og lys kalkstein
		sand_col = to_lin(vec3(0.88, 0.74, 0.42));
		grass_a = to_lin(vec3(0.16, 0.44, 0.15));
		grass_b = to_lin(vec3(0.32, 0.58, 0.18));
		path_col = to_lin(vec3(0.62, 0.48, 0.28));
		cliff_dark = to_lin(vec3(0.28, 0.23, 0.17));
		cliff_lit = to_lin(vec3(0.52, 0.45, 0.34));
		peak_col = to_lin(vec3(0.44, 0.38, 0.28));
	}

	// Organisk gress-/sandblanding + tydelige stier og fargevariasjon
	vec3 flat_col = mix(grass_a, grass_b, smoothstep(0.22, 0.78, n_macro * 0.62 + n_med * 0.38));
	float dirt_trail = smoothstep(0.56, 0.80, ridge_noise) * smoothstep(1.2, 2.8, v_height) * (1.0 - smoothstep(4.8, 6.8, v_height));
	flat_col = mix(flat_col, path_col, dirt_trail * 0.52);

	float beach_t = smoothstep(0.55, 1.85, v_height + (n_med - 0.5) * 0.75);
	vec3 ground = mix(sand_col, flat_col, beach_t);

	// Dyp turkis-mørk havbunn under vannlinjen
	float underwater = 1.0 - smoothstep(-2.6, 0.15, v_height);
	ground = mix(ground, mix(to_lin(vec3(0.05, 0.14, 0.22)), sand_col * 0.65, smoothstep(-4.8, 0.0, v_height)), underwater);

	// Fjelltopp-stein
	float peak_t = smoothstep(5.4, 9.0, v_height + (n_macro - 0.5) * 1.6);
	ground = mix(ground, peak_col, peak_t * 0.72);

	// Skarp lagdelt klippevegg med dype skyggesprekker
	float strata_band = smoothstep(0.22, 0.80, strata * 0.7 + n_fine * 0.3);
	vec3 cliff_col = mix(cliff_dark, cliff_lit, strata_band);
	vec3 alb = mix(ground, cliff_col, cliff_mask * smoothstep(-0.15, 0.75, v_height));

	// Tydelig finkornet stein-/jordkontrast + mørk sprekk-AO i daler og foten av klipper
	alb *= (0.78 + 0.42 * n_fine);
	float crevice_ao = mix(1.0, 0.76, cliff_mask * (1.0 - strata_band));
	alb *= crevice_ao;

	// Våt, mørkere strandlinje rett ved bølgeskvulpet
	float wet = (1.0 - smoothstep(-0.1, 0.62, v_height)) * smoothstep(-1.4, -0.05, v_height);
	alb *= mix(1.0, 0.58, wet * 0.75);

	// Skarp prosedyrell normalmap fra xz-projeksjon (betydelig dypere på klipper!)
	NORMAL_MAP = texture(detail_normal_tex, xz * 0.28).rgb;
	NORMAL_MAP_DEPTH = mix(1.05, 2.25, cliff_mask);

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(mix(0.88, 0.70, cliff_mask), 0.18, wet);
	METALLIC = 0.02;
	SPECULAR = mix(0.42, 0.85, wet);
	EMISSION = em_col;
}
