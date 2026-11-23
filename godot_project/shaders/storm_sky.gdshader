shader_type sky;
// Kinematisk live-action stormhimmel med måneskinn, dramatiske uværsskyer og atmosfærisk horisontglød (Gral).

uniform vec3 zenith_color : source_color = vec3(0.02, 0.04, 0.10);
uniform vec3 horizon_color : source_color = vec3(0.18, 0.14, 0.24);
uniform vec3 cloud_dark : source_color = vec3(0.04, 0.05, 0.09);
uniform vec3 cloud_lit : source_color = vec3(0.68, 0.72, 0.86);
uniform vec3 moon_dir = vec3(0.92, 0.28, -0.25);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.80, -0.60), vec2(0.60, 0.80));
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p = rot * p * 2.05 + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float elev = clamp(dir.y, 0.0, 1.0);

	// Rik natt/skumringsgradient med varm tåkete horisont
	vec3 col = mix(horizon_color, zenith_color, pow(elev, 0.52));

	// Fullmåne + atmosfærisk måneglød
	vec3 mdir = normalize(moon_dir);
	float mdot = max(dot(dir, mdir), 0.0);
	float moon_disc = smoothstep(0.9982, 0.9990, mdot);
	float moon_halo = pow(mdot, 28.0) * 0.45 + pow(mdot, 6.0) * 0.18;
	col += vec3(0.82, 0.88, 1.0) * moon_halo;
	col = mix(col, vec3(1.0, 0.98, 0.90), moon_disc);

	// Stjerner i klare partier høyt på himmelen
	if (dir.y > 0.08) {
		vec2 suv = floor(dir.xz / max(dir.y, 0.15) * 95.0);
		float st = hash21(suv);
		if (st > 0.993) {
			col += vec3(0.75, 0.82, 1.0) * smoothstep(0.08, 0.35, dir.y) * 0.7;
		}
	}

	// Dramatiske uværsskyer projisert på kuppel
	if (dir.y > -0.02) {
		vec2 cuv = dir.xz / (max(dir.y, 0.06) + 0.18);
		float n1 = fbm(cuv * 1.4 + vec2(TIME * 0.008, TIME * 0.004));
		float n2 = fbm(cuv * 2.9 - vec2(TIME * 0.012, -TIME * 0.005));
		float density = smoothstep(0.36, 0.78, n1 * 0.7 + n2 * 0.35);
		float rim = pow(mdot, 4.0) * 0.75 + smoothstep(0.45, 0.85, n2) * 0.25;
		vec3 ccol = mix(cloud_dark, cloud_lit, clamp(rim * (1.0 - density * 0.45), 0.0, 1.0));
		float horizon_fade = smoothstep(-0.02, 0.22, dir.y);
		col = mix(col, ccol, density * 0.86 * horizon_fade);
	}

	// Mørk dis under horisonten (dyp fjellskygge)
	if (dir.y < 0.0) {
		col = mix(horizon_color * 0.55, vec3(0.03, 0.04, 0.06), smoothstep(0.0, -0.25, dir.y));
	}

	COLOR = col;
}
