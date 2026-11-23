shader_type sky;
// Kinematisk AAA animasjons-stormhimmel for Gral:
// Lysende fullmåne med kratre, sølvkantede uværsskyer, skarpe 3D-stjerner (ingen streker) og fjelltåke.

uniform vec3 zenith_color : source_color = vec3(0.03, 0.05, 0.14);
uniform vec3 horizon_color : source_color = vec3(0.14, 0.18, 0.32);
uniform vec3 cloud_dark : source_color = vec3(0.05, 0.07, 0.15);
uniform vec3 cloud_lit : source_color = vec3(0.58, 0.68, 0.88);
uniform vec3 moon_dir = vec3(0.74, 0.36, -0.56);

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

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
		p = rot * p * 2.05 + vec2(17.1, 31.7);
		amp *= 0.49;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;
	float elev = clamp(y, 0.0, 1.0);

	// Rik natt-blå til indigo himmelgradient
	vec3 col = mix(horizon_color, zenith_color, pow(elev, 0.55));

	// Skarpe 3D-stjerner uten noen horisont-forvrengning
	if (y > 0.05) {
		vec3 scell = floor(dir * 190.0);
		vec3 sfr = fract(dir * 190.0) - 0.5;
		float sh = hash31(scell);
		if (sh > 0.992) {
			float srad = smoothstep(0.28, 0.02, length(sfr));
			float twinkle = 0.72 + 0.28 * sin(TIME * 2.5 + sh * 400.0);
			col += vec3(0.76, 0.86, 1.0) * srad * twinkle * smoothstep(0.05, 0.28, y) * 1.1;
		}
	}

	// Stor detaljert fullmåne + atmosfærisk sølvblå måneglød
	vec3 mdir = normalize(moon_dir);
	float mdot = max(dot(dir, mdir), 0.0);
	float moon_disc = smoothstep(0.9965, 0.9974, mdot);
	float moon_halo = pow(mdot, 36.0) * 0.70 + pow(mdot, 7.0) * 0.26;
	col += vec3(0.58, 0.74, 1.0) * moon_halo;
	if (moon_disc > 0.001) {
		float crater = fbm(dir.xy * 42.0 + dir.z * 18.0);
		vec3 moon_col = mix(vec3(0.84, 0.89, 0.96), vec3(1.18, 1.16, 1.08), smoothstep(0.32, 0.72, crater));
		col = mix(col, moon_col, moon_disc);
	}

	// Dramatiske sølvkantede uværsskyer
	if (y > -0.06) {
		vec2 cuv = dir.xz / (max(y, 0.08) + 0.20);
		float warp = fbm(cuv * 0.8 + vec2(TIME * 0.006, 0.0));
		float n1 = fbm(cuv * 1.25 + vec2(warp * 0.45, -warp * 0.35) + vec2(TIME * 0.009, TIME * 0.004));
		float n2 = fbm(cuv * 2.65 - vec2(TIME * 0.011, -TIME * 0.005));
		float density = smoothstep(0.38, 0.76, n1 * 0.70 + n2 * 0.36);

		// Sølv-blå månekant + svakt magisk fiolett uværslys
		float silver_rim = pow(mdot, 5.0) * 1.15 + smoothstep(0.46, 0.84, n2) * 0.34;
		vec3 ccol = mix(cloud_dark, cloud_lit, clamp(silver_rim * (1.0 - density * 0.38), 0.0, 1.0));
		ccol += vec3(0.18, 0.12, 0.34) * smoothstep(0.55, 0.85, n1) * 0.35;

		float fade = smoothstep(-0.05, 0.18, y);
		col = mix(col, ccol, density * 0.88 * fade);
	}

	// Myk månelyst fjelltåke langs og under horisonten (fjerner hard svart kant!)
	float mist_band = exp(-abs(y + 0.02) * 9.0);
	col = mix(col, vec3(0.18, 0.23, 0.38), mist_band * 0.58);
	if (y < 0.0) {
		float low_mist = fbm(dir.xz * 2.2 + vec2(TIME * 0.005, 0.0));
		vec3 valley_col = mix(vec3(0.06, 0.09, 0.18), vec3(0.16, 0.20, 0.34), low_mist * 0.7);
		col = mix(col, valley_col, smoothstep(0.0, -0.26, y));
	}

	COLOR = col;
}
