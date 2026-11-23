shader_type sky;
// Kinematisk mørk gotisk stormhimmel for Gral-borgen:
// Dyp skummel uværshimmel, lysende fullmåne, lilla-blå tordenskyer og skarpe forgrenede lynnedslag!

uniform vec3 zenith_color : source_color = vec3(0.012, 0.018, 0.055);
uniform vec3 horizon_color : source_color = vec3(0.065, 0.075, 0.165);
uniform vec3 cloud_dark : source_color = vec3(0.020, 0.022, 0.055);
uniform vec3 cloud_lit : source_color = vec3(0.42, 0.54, 0.82);
uniform vec3 moon_dir = vec3(0.76, 0.38, -0.52);

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

// Skarp sikksakk-lynstråle på himmelkuppelen
float sky_bolt(float az, float el, float center_az, float top_el, float seed, float width) {
	if (el > top_el || el < -0.02) {
		return 0.0;
	}
	float t = clamp((top_el - el) / max(top_el + 0.02, 0.1), 0.0, 1.0);
	// Flerskals sikksakk-forskyvning
	float zig = (vnoise(vec2(t * 14.0 + seed, seed * 3.1)) - 0.5) * 0.13
	          + (vnoise(vec2(t * 34.0 + seed * 2.0, seed * 7.7)) - 0.5) * 0.045;
	float d = abs(az - (center_az + zig));
	float core = smoothstep(width, 0.0, d);
	float halo = exp(-d / (width * 4.5)) * 0.55;
	float vfade = smoothstep(top_el, top_el - 0.06, el) * smoothstep(-0.02, 0.04, el);
	return (core * 2.2 + halo) * vfade;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;
	float elev = clamp(y, 0.0, 1.0);
	float az = atan(dir.z, dir.x); // -PI..PI

	// Skummel mørk midnattsblå-fiolett stormgradient
	vec3 col = mix(horizon_color, zenith_color, pow(elev, 0.48));

	// Skarpe 3D-stjerner høyt over uværsskyene
	if (y > 0.12) {
		vec3 scell = floor(dir * 195.0);
		vec3 sfr = fract(dir * 195.0) - 0.5;
		float sh = hash31(scell);
		if (sh > 0.993) {
			float srad = smoothstep(0.26, 0.02, length(sfr));
			col += vec3(0.76, 0.86, 1.0) * srad * smoothstep(0.12, 0.38, y) * 0.9;
		}
	}

	// Stor dramatisk fullmåne med kratre + sølvblå halo
	vec3 mdir = normalize(moon_dir);
	float mdot = max(dot(dir, mdir), 0.0);
	float moon_disc = smoothstep(0.9964, 0.9973, mdot);
	float moon_halo = pow(mdot, 34.0) * 0.65 + pow(mdot, 7.0) * 0.24;
	col += vec3(0.48, 0.66, 1.0) * moon_halo;
	if (moon_disc > 0.001) {
		float crater = fbm(dir.xy * 42.0 + dir.z * 18.0);
		vec3 moon_col = mix(vec3(0.82, 0.88, 0.96), vec3(1.22, 1.20, 1.12), smoothstep(0.32, 0.72, crater));
		col = mix(col, moon_col, moon_disc);
	}

	// Tunge, skumle tordenskyer med intern elektrisk lilla-blå glød
	float flash1 = 0.68 + 0.32 * sin(TIME * 3.1) * sin(TIME * 7.3);
	float flash2 = 0.62 + 0.38 * cos(TIME * 2.4 + 1.2) * cos(TIME * 6.1);

	if (y > -0.05) {
		vec2 cuv = dir.xz / (max(y, 0.07) + 0.18);
		float warp = fbm(cuv * 0.85 + vec2(TIME * 0.007, 0.0));
		float n1 = fbm(cuv * 1.35 + vec2(warp * 0.50, -warp * 0.40) + vec2(TIME * 0.011, TIME * 0.005));
		float n2 = fbm(cuv * 2.85 - vec2(TIME * 0.014, -TIME * 0.006));
		float density = smoothstep(0.32, 0.74, n1 * 0.68 + n2 * 0.38);

		float silver_rim = pow(mdot, 5.0) * 1.1 + smoothstep(0.48, 0.85, n2) * 0.30;
		vec3 ccol = mix(cloud_dark, cloud_lit, clamp(silver_rim * (1.0 - density * 0.45), 0.0, 1.0));

		// Elektrisk lynglød inne i tordenskyene rundt lynnedslagene!
		float storm_glow1 = exp(-pow(az - (-0.42), 2.0) * 9.0) * exp(-pow(y - 0.24, 2.0) * 18.0) * flash1;
		float storm_glow2 = exp(-pow(az - (0.34), 2.0) * 10.0) * exp(-pow(y - 0.22, 2.0) * 18.0) * flash2;
		ccol += vec3(0.52, 0.62, 1.0) * (storm_glow1 + storm_glow2) * 1.15;
		ccol += vec3(0.24, 0.10, 0.44) * smoothstep(0.45, 0.82, n1) * 0.45;

		float fade = smoothstep(-0.04, 0.16, y);
		col = mix(col, ccol, density * 0.92 * fade);
	}

	// Dramatiske forgrenede lynnedslag som slår ned bak Gral-borgen!
	float b1 = sky_bolt(az, y, -0.42, 0.34, 1.3, 0.007) * flash1;
	float b1_branch = sky_bolt(az, y, -0.35, 0.22, 4.7, 0.0045) * flash1 * 0.75;
	float b2 = sky_bolt(az, y, 0.34, 0.30, 8.9, 0.0065) * flash2;
	float b2_branch = sky_bolt(az, y, 0.27, 0.19, 12.1, 0.004) * flash2 * 0.70;
	float total_bolt = b1 + b1_branch + b2 + b2_branch;
	col += mix(vec3(0.55, 0.74, 1.0), vec3(1.5, 1.55, 1.8), clamp(total_bolt * 0.7, 0.0, 1.0)) * total_bolt;

	// Skummel mørk fjelltåke langs horisonten og dalen under borgen
	float mist_band = exp(-abs(y + 0.01) * 10.0);
	col = mix(col, vec3(0.11, 0.12, 0.24), mist_band * 0.55);
	if (y < 0.0) {
		float low_mist = fbm(dir.xz * 2.4 + vec2(TIME * 0.006, 0.0));
		vec3 valley_col = mix(vec3(0.025, 0.03, 0.07), vec3(0.09, 0.10, 0.20), low_mist * 0.75);
		col = mix(col, valley_col, smoothstep(0.0, -0.24, y));
	}

	COLOR = col;
}
