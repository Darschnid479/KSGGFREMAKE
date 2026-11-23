shader_type canvas_item;
// Kinematisk 2.5D animasjons-overlay for mellomsekvensene:
// Levende svevende lysstøv/glør, varm solstråle-glød og filmatisk vignette.

uniform vec4 mood_color : source_color = vec4(1.0, 0.82, 0.42, 1.0);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.42;
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.22;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.53);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 d = uv - vec2(0.5);
	float vig = smoothstep(0.32, 0.82, length(d));

	// Svevende lysstøv / glør som stiger sakte over bildet
	float mote_glow = 0.0;
	for (int i = 0; i < 18; i++) {
		float fi = float(i);
		float spd = 0.03 + hash21(vec2(fi, 1.7)) * 0.05;
		float px = fract(hash21(vec2(fi, 3.1)) + sin(TIME * 0.4 + fi) * 0.04);
		float py = fract(hash21(vec2(fi, 7.3)) - TIME * spd);
		vec2 p = vec2(px, py);
		float dist = length((uv - p) * vec2(1.77, 1.0));
		float pulse = 0.55 + 0.45 * sin(TIME * 2.4 + fi * 2.1);
		mote_glow += smoothstep(0.018, 0.002, dist) * pulse * 0.45;
	}

	// Subtil lysglød fra øvre hjørne
	float ray = exp(-length((uv - vec2(0.5, 0.25)) * vec2(1.2, 1.8)) * 2.2) * shimmer_strength * (0.85 + 0.15 * sin(TIME * 1.4));

	vec3 col = mood_color.rgb * (mote_glow + ray);
	float alpha = clamp(vig * vignette_strength + mote_glow * 0.75 + ray * 0.25, 0.0, 0.92);
	// Mørk film-vignette i kantene, lysende støv i midten
	vec3 out_col = mix(vec3(0.02, 0.02, 0.04), col, clamp((mote_glow + ray) * 2.2, 0.0, 1.0));
	COLOR = vec4(out_col, alpha);
}
