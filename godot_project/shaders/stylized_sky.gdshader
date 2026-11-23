shader_type sky;
// Moderne AAA animasjonsspill-himmel (Sea of Thieves / Kena / Pixar-stil):
// Rik atmosfærisk gradient, gyllen solskive med Mie-glød og malte volumetriske cumulusskyer.

uniform vec3 zenith_color : source_color = vec3(0.08, 0.34, 0.78);
uniform vec3 mid_color : source_color = vec3(0.24, 0.62, 0.94);
uniform vec3 horizon_color : source_color = vec3(0.96, 0.84, 0.66);
uniform vec3 ground_color : source_color = vec3(0.06, 0.16, 0.28);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.72);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.97, 0.90);
uniform vec3 cloud_shadow : source_color = vec3(0.42, 0.56, 0.78);
uniform vec3 sun_dir = vec3(0.55, 0.28, -0.78);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.46;
uniform float sun_size : hint_range(0.005, 0.08) = 0.024;
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.007;

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

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.50;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.06 + vec2(19.3, 37.1);
		amp *= 0.48;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sdir = normalize(sun_dir);
	float y = dir.y;
	float elev = clamp(y, 0.0, 1.0);

	// 3-trinns levende animasjons-himmelgradient
	vec3 sky_low = mix(horizon_color, mid_color, smoothstep(0.0, 0.34, elev));
	vec3 col = mix(sky_low, zenith_color, smoothstep(0.20, 0.88, elev));

	// Varm atmosfærisk Mie-spredning rundt solen
	float sdot = max(dot(dir, sdir), 0.0);
	float sun_glow_wide = pow(sdot, 5.0) * 0.36;
	float sun_glow_tight = pow(sdot, 42.0) * 0.72;
	float sun_disc = smoothstep(1.0 - sun_size * 0.045, 1.0 - sun_size * 0.012, sdot);
	col += sun_color * (sun_glow_wide * (1.0 - elev * 0.55) + sun_glow_tight);
	col = mix(col, sun_color * 2.2, sun_disc);

	// Malte fluffy cumulusskyer med gyllen/sølv kantglød og myke undersider
	if (y > -0.02) {
		float proj = max(y, 0.045) + 0.14;
		vec2 cuv = dir.xz / proj * 1.15;
		vec2 drift = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.42);
		float warp = fbm(cuv * 0.75 + drift * 0.6);
		float n_base = fbm(cuv * 1.10 + vec2(warp * 0.55, -warp * 0.45) + drift);
		float n_puff = fbm(cuv * 2.35 - drift * 0.8);

		float thresh = mix(0.76, 0.34, cloud_coverage);
		float density = smoothstep(thresh, thresh + 0.28, n_base * 0.72 + n_puff * 0.34);

		// Retningsbestemt sky-belysning (lyse topper mot solen, maleriske blå-fiolette skygger under)
		vec2 sun_off = normalize(sdir.xz + vec2(0.0001)) * 0.14;
		float n_toward_sun = fbm((cuv + sun_off) * 1.10 + vec2(warp * 0.55, -warp * 0.45) + drift);
		float self_lit = clamp(0.55 + (n_base - n_toward_sun) * 2.8 + (n_puff - 0.45) * 0.45, 0.0, 1.0);
		float silver_lining = pow(sdot, 8.0) * (1.0 - density * 0.55) * 0.95;

		vec3 ccol = mix(cloud_shadow, cloud_lit, smoothstep(0.18, 0.88, self_lit));
		ccol += sun_color * silver_lining * 0.65;
		// Myk oppløsning mot horisonten så skyene aldri kuttes hardt
		float horiz_fade = smoothstep(-0.01, 0.20, y);
		col = mix(col, ccol, density * 0.92 * horiz_fade);
	}

	// Myk atmosfærisk horisontdis + dyp hav-speiling under horisonten
	float horiz_band = exp(-abs(y) * 14.0);
	col = mix(col, mix(horizon_color, sun_color, pow(sdot, 3.0) * 0.35), horiz_band * 0.32);

	if (y < 0.0) {
		col = mix(horizon_color * 0.85, ground_color, smoothstep(0.0, -0.22, y));
	}

	COLOR = col;
}
