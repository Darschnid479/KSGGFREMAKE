shader_type sky;
// 2026 Stilisert 4K 360-graders animasjonsfilm-himmel (KSGGFREMAKE):
// Bruker våre nybygde 4K (4096x2048) stiliserte biom-himmelpanoramer (Poly Haven CC0 PureSky
// + fjerne malte fjell-, klippe-, øy- og ørkensilhuetter) med myk skydrift og storm-lynglød!

uniform sampler2D sky_pano : source_color, filter_linear_mipmap, repeat_enable;
uniform float exposure : hint_range(0.4, 2.5) = 1.08;
uniform float rotation_offset : hint_range(-6.283, 6.283) = 0.0;
uniform float cloud_drift_speed : hint_range(0.0, 0.02) = 0.0018;
uniform float storm_flash_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec3 storm_flash_color : source_color = vec3(0.55, 0.78, 1.0);
uniform float horizon_mist_strength : hint_range(0.0, 0.6) = 0.08;
uniform vec3 horizon_mist_color : source_color = vec3(0.20, 0.30, 0.36);

void sky() {
	vec3 dir = normalize(EYEDIR);
	float az = atan(dir.z, dir.x) + rotation_offset;
	float u = fract(az / 6.2831853 + 0.5);
	float v = clamp(0.5 - asin(clamp(dir.y, -1.0, 1.0)) / 3.14159265, 0.001, 0.999);

	// Subtil skydrift kun høyt over horisonten slik at fjerne fjell/klipper alltid står fjellstøtt!
	float cloud_mask = smoothstep(0.14, 0.34, dir.y);
	float u_cloud = fract(u + TIME * cloud_drift_speed);
	vec3 col_static = texture(sky_pano, vec2(u, v)).rgb;
	vec3 col_drift = texture(sky_pano, vec2(u_cloud, v)).rgb;
	vec3 col = mix(col_static, col_drift, cloud_mask * 0.45);

	// Volumetrisk intern lynglød i tordenskyene for Gral-borgen (null tynne sikksakk-streker!)
	if (storm_flash_strength > 0.01 && dir.y > 0.05) {
		float pulse1 = pow(max(0.0, sin(TIME * 1.7) * sin(TIME * 4.3 + 0.7)), 4.0);
		float pulse2 = pow(max(0.0, cos(TIME * 1.1 + 2.1) * sin(TIME * 3.1)), 5.0);
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		float bright_clouds = smoothstep(0.16, 0.52, lum) * smoothstep(0.05, 0.28, dir.y);
		float spot1 = exp(-pow(sin((az - 1.2) * 0.5), 2.0) * 8.0);
		float spot2 = exp(-pow(sin((az + 1.8) * 0.5), 2.0) * 10.0);
		float flash = (pulse1 * spot1 + pulse2 * spot2 + 0.18 * (spot1 + spot2)) * bright_clouds;
		col += storm_flash_color * flash * storm_flash_strength;
	}

	// Myk atmosfærisk horisontdis
	if (horizon_mist_strength > 0.001) {
		float band = exp(-abs(dir.y) * 18.0);
		col = mix(col, horizon_mist_color, band * horizon_mist_strength);
	}

	COLOR = col * exposure;
}
