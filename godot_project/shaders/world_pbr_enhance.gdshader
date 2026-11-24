shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// 2026 Stilisert 3D-animasjonsfilm PBR-shader (KSGGFREMAKE):
// Bruker direkte de nye lisensierte CC0 PBR-teksturene (Albedo + Normal + ORM) bakt per flate
// med eksakt original UV, mønster og materialskille — pluss diskret stilisert CC0 mikrorelieff
// på store lav-UV fjell-/grotte-/sandflater slik at nærbilder forblir sylskarpe!

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic;

// Stiliserte CC0 detaljkart (for 2D cutaway bedrock og diskret mikrorelieff på store lav-UV flater)
uniform sampler2D pbr_albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pbr_normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pbr_rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;

uniform bool has_albedo_tex = true;
uniform bool has_normal_tex = false;
uniform bool has_orm_tex = false;
uniform bool has_pbr_pack = false;

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy = 0.0;
uniform float base_roughness : hint_range(0.05, 1.0) = 0.70;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.88;
uniform float pbr_blend : hint_range(0.0, 1.0) = 0.0;
uniform float pbr_tile_scale : hint_range(0.02, 2.0) = 0.14;
uniform float micro_detail : hint_range(0.0, 0.45) = 0.0;
uniform float contrast_gamma : hint_range(0.8, 1.4) = 1.02;
uniform float saturation_boost : hint_range(0.75, 1.4) = 1.05;
uniform float wet_water_y = -999.0;
uniform float rim_strength : hint_range(0.0, 0.6) = 0.05;
uniform vec3 rim_color : source_color = vec3(0.88, 0.94, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 alb = albedo_tint.rgb;
	if (has_albedo_tex) {
		alb *= texture(albedo_tex, UV).rgb;
	}
	alb = pow(max(alb, vec3(0.0001)), vec3(contrast_gamma));

	float rough = base_roughness;
	float metal = base_metallic;
	float ao = 1.0;
	vec3 final_nrm = vec3(0.5, 0.5, 1.0);
	bool use_nrm = false;

	if (has_orm_tex) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ao = mix(1.0, clamp(orm.r, 0.45, 1.0), 0.72);
		rough = clamp(orm.g, 0.14, 0.96);
		metal = clamp(max(base_metallic, orm.b), 0.0, 1.0);
	}

	if (has_normal_tex) {
		final_nrm = texture(normal_tex, UV).rgb;
		use_nrm = true;
	}

	// Triplanar stilisert CC0-detalj for 2D undervanns-tverrsnitt ELLER diskret mikrorelieff på store lav-UV flater
	if (has_pbr_pack && (pbr_blend > 0.01 || micro_detail > 0.01)) {
		vec3 wn = normalize(v_world_nrm);
		vec3 w = pow(abs(wn), vec3(4.0));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec2 uv_x = v_world_pos.zy * pbr_tile_scale;
		vec2 uv_y = v_world_pos.xz * pbr_tile_scale;
		vec2 uv_z = v_world_pos.xy * pbr_tile_scale;
		vec3 pa = texture(pbr_albedo_tex, uv_x).rgb * w.x
		        + texture(pbr_albedo_tex, uv_y).rgb * w.y
		        + texture(pbr_albedo_tex, uv_z).rgb * w.z;
		float pa_l = dot(pa, vec3(0.299, 0.587, 0.114));

		if (pbr_blend > 0.01) {
			// 2D undervanns-fjellvegg med myk lagdeling
			float strata = 0.88 + 0.12 * sin(v_world_pos.y * 0.65 + sin(v_world_pos.x * 0.28) * 1.4);
			vec3 cut_col = albedo_tint.rgb * clamp(0.68 + pa_l * 0.65, 0.55, 1.25) * strata;
			alb = mix(alb, cut_col, pbr_blend);
			rough = mix(rough, 0.88, pbr_blend);
			ao = mix(ao, clamp(0.72 + pa_l * 0.35, 0.55, 1.0), pbr_blend);
			use_nrm = false;
		} else {
			// Diskret stilisert mikro-relieff (bevarer 100% originalfargen, fjerner 2007 UV-strekk i grotter/sand/klipper!)
			vec3 pn = texture(pbr_normal_tex, uv_x).rgb * w.x
			        + texture(pbr_normal_tex, uv_y).rgb * w.y
			        + texture(pbr_normal_tex, uv_z).rgb * w.z;
			float detail_mod = clamp(0.84 + pa_l * 0.34, 0.82, 1.18);
			alb *= mix(1.0, detail_mod, micro_detail * 1.25);
			if (use_nrm) {
				final_nrm = normalize(mix(final_nrm * 2.0 - 1.0, pn * 2.0 - 1.0, micro_detail * 1.15)) * 0.5 + 0.5;
			} else {
				final_nrm = mix(vec3(0.5, 0.5, 1.0), pn, micro_detail * 1.4);
				use_nrm = true;
			}
			ao *= mix(1.0, clamp(0.78 + pa_l * 0.30, 0.72, 1.0), micro_detail);
		}
	}

	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, saturation_boost);

	// Myk fuktighet rett over vannflaten (+0.38m)
	float wetness = 0.0;
	if (wet_water_y > -500.0) {
		wetness = 1.0 - smoothstep(wet_water_y - 0.04, wet_water_y + 0.38, v_world_pos.y);
		alb *= mix(1.0, 0.72, wetness * 0.65);
		rough = mix(rough, 0.18, wetness * 0.70);
	}

	if (use_nrm) {
		NORMAL_MAP = final_nrm;
		NORMAL_MAP_DEPTH = normal_strength;
	}

	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 3.8) * rim_strength * (1.0 - wetness * 0.5);

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.0));
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.12, 0.96);
	AO = ao;
	SPECULAR = mix(clamp(0.48 - rough * 0.24, 0.18, 0.44), 0.80, wetness);
	EMISSION = emission_color * emission_energy + rim_color * rim * max(alb, vec3(0.18));
}
