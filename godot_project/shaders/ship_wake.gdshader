shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;
// Organisk skummende V-kjølvann bak sjørøverskip (Sea of Thieves / Wind Waker-stil) – ingen harde kanter!

uniform vec4 foam_color : source_color = vec4(0.95, 0.99, 1.0, 1.0);
uniform float speed = 2.6;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.53);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
	           mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	// UV.x: 0..1 på tvers av kjølvannet (0.5 = midten), UV.y: 0 ved hekken -> 1 langt bak
	float side = abs(UV.x - 0.5) * 2.0; // 0 i midten, 1 på ytterkant
	float dist = UV.y;

	// Animerte V-bølger som brer seg ut fra kjølen
	float n1 = vnoise(vec2(UV.x * 7.0, UV.y * 10.0 - TIME * speed));
	float n2 = vnoise(vec2(UV.x * 16.0 + 3.1, UV.y * 22.0 - TIME * speed * 1.4));
	float froth = n1 * 0.65 + n2 * 0.35;

	// To myke skumstriper langs V-kantene + lett virvel i midten
	float v_arms = smoothstep(0.32, 0.72, side) * (1.0 - smoothstep(0.76, 1.0, side));
	float center_swirl = (1.0 - smoothstep(0.0, 0.45, side)) * 0.42;
	float ripple = sin(dist * 18.0 - TIME * speed * 2.2 + side * 4.0) * 0.5 + 0.5;

	float fade_len = (1.0 - smoothstep(0.15, 0.98, dist)) * smoothstep(0.0, 0.08, dist);
	float mask = (v_arms * (0.65 + 0.35 * ripple) + center_swirl) * smoothstep(0.28, 0.78, froth) * fade_len;

	ALBEDO = foam_color.rgb;
	ALPHA = clamp(mask * 0.82, 0.0, 0.88);
}
