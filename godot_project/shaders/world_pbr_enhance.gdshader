shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// 2026 Ultra-HD 4K Stilisert 3D-animasjonsfilm PBR-shader (KSGGFREMAKE):
// 1. Leser sylskarpe bakte 4K/2K CC0 PBR-teksturer (Albedo + Normal + ORM) med eksakt original UV.
// 2. Kombinerer verdensrom-triplanar 4K CC0 stein-/fjell-/tre-/sand-detalj via Reoriented Normal Mapping (RNM)
//    + kavitets-AO + mikro-ruhet slik at selv enorme grottevegger og borgmurer er knivskarpe i nærbilde!

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic;

// 4K verdensrom-triplanar CC0 detaljkart (fjerner 100% av 2007 UV-strekk på fjell, grotter, mur og gulv!)
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
uniform float normal_strength : hint_range(0.0, 2.5) = 1.15;
uniform float pbr_blend : hint_range(0.0, 1.0) = 0.0;
uniform float pbr_tile_scale : hint_range(0.02, 2.0) = 0.22;
uniform float micro_detail : hint_range(0.0, 0.85) = 0.0;
uniform float contrast_gamma : hint_range(0.8, 1.4) = 1.02;
uniform float saturation_boost : hint_range(0.75, 1.4) = 1.05;
uniform float wet_water_y = -999.0;
uniform float rim_strength : hint_range(0.0, 0.6) = 0.05;
uniform vec3 rim_color : source_color = vec3(0.88, 0.94, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

// Rekonstruerer eksakt tangent-rom normal Z fra RG-kanalene (støtter både 2-kanals RGTC/BC5 og RGB-normalkart!)
vec3 unpack_normal_bc5(vec2 rg) {
	vec2 xy = rg * 2.0 - 1.0;
	float z = sqrt(clamp(1.0 - dot(xy, xy), 0.04, 1.0));
	return normalize(vec3(xy, z));
}

// Reoriented Normal Mapping (Barré-Brisebois & Hill): bevarer full dybde i både bakt OG 4K detalj-normalkart!
vec3 rnm_blend(vec3 n1, vec3 n2) {
	vec3 t = n1 + vec3(0.0, 0.0, 1.0);
	vec3 u = n2 * vec3(-1.0, -1.0, 1.0);
	return normalize(t * dot(t, u) - u * t.z);
}

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
	vec3 final_nrm = vec3(0.0, 0.0, 1.0);
	bool use_nrm = false;

	if (has_orm_tex) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ao = mix(1.0, clamp(orm.r, 0.40, 1.0), 0.78);
		rough = clamp(orm.g, 0.14, 0.96);
		metal = clamp(max(base_metallic, orm.b), 0.0, 1.0);
	}

	if (has_normal_tex) {
		final_nrm = unpack_normal_bc5(texture(normal_tex, UV).rg);
		use_nrm = true;
	}

	// 4K verdensrom-triplanar stein-/fjell-/tre-/sand-relieff (null blurry 2007 UV-strekk i grotter, borger og klipper!)
	if (has_pbr_pack && (pbr_blend > 0.01 || micro_detail > 0.01)) {
		vec3 wn = normalize(v_world_nrm);
		vec3 w = pow(abs(wn), vec3(5.0));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec2 uv_x = v_world_pos.zy * pbr_tile_scale;
		vec2 uv_y = v_world_pos.xz * pbr_tile_scale;
		vec2 uv_z = v_world_pos.xy * pbr_tile_scale;

		vec3 pa = texture(pbr_albedo_tex, uv_x).rgb * w.x
		        + texture(pbr_albedo_tex, uv_y).rgb * w.y
		        + texture(pbr_albedo_tex, uv_z).rgb * w.z;
		vec2 pn_rg = texture(pbr_normal_tex, uv_x).rg * w.x
		           + texture(pbr_normal_tex, uv_y).rg * w.y
		           + texture(pbr_normal_tex, uv_z).rg * w.z;
		float pr = texture(pbr_rough_tex, uv_x).r * w.x
		         + texture(pbr_rough_tex, uv_y).r * w.y
		         + texture(pbr_rough_tex, uv_z).r * w.z;

		float pa_l = dot(pa, vec3(0.299, 0.587, 0.114));
		vec3 pn = unpack_normal_bc5(pn_rg);

		if (pbr_blend > 0.01) {
			// 2D undervanns-fjellvegg med skarp lagdelt berggrunn og dypt relieff
			float strata = 0.86 + 0.14 * sin(v_world_pos.y * 0.72 + sin(v_world_pos.x * 0.30) * 1.4);
			vec3 cut_col = albedo_tint.rgb * clamp(0.56 + pa_l * 0.88, 0.42, 1.35) * strata;
			alb = mix(alb, cut_col, pbr_blend);
			rough = mix(rough, clamp(0.68 + (pr - 0.5) * 0.35, 0.45, 0.94), pbr_blend);
			ao = mix(ao, clamp(0.58 + pa_l * 0.52, 0.42, 1.0), pbr_blend);
			final_nrm = normalize(mix(vec3(0.0, 0.0, 1.0), pn, 0.65));
			use_nrm = true;
		} else {
			// Knivskarpt 4K detalj-overlay + RNM normalkart (bevarer 100% originalfargene men gir skarp 4K stein/tre-struktur!)
			float detail_mod = clamp(0.64 + pa_l * 0.76, 0.58, 1.42);
			alb *= mix(1.0, detail_mod, micro_detail);
			// Subtil naturlig fargetone fra 4K CC0-materialet i sprekker og relieff
			vec3 pa_chroma = clamp(pa / max(pa_l, 0.08), vec3(0.82), vec3(1.18));
			alb *= mix(vec3(1.0), pa_chroma, micro_detail * 0.35);

			vec3 pn_scaled = normalize(vec3(pn.xy * (micro_detail * 1.35), max(pn.z, 0.25)));
			if (use_nrm) {
				final_nrm = rnm_blend(final_nrm, pn_scaled);
			} else {
				final_nrm = pn_scaled;
				use_nrm = true;
			}
			rough = clamp(mix(rough, clamp(rough + (pr - 0.5) * 0.42, 0.22, 0.96), micro_detail), 0.14, 0.96);
			ao *= mix(1.0, clamp(0.62 + pa_l * 0.48, 0.52, 1.0), micro_detail * 0.85);
		}
	}

	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, saturation_boost);

	// Fuktighet og blank våt stein/tre rett over vannflaten (+0.42m)
	float wetness = 0.0;
	if (wet_water_y > -500.0) {
		wetness = 1.0 - smoothstep(wet_water_y - 0.04, wet_water_y + 0.42, v_world_pos.y);
		alb *= mix(1.0, 0.68, wetness * 0.68);
		rough = mix(rough, 0.16, wetness * 0.75);
	}

	if (use_nrm) {
		NORMAL_MAP = final_nrm * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_strength;
	}

	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 3.8) * rim_strength * (1.0 - wetness * 0.5);

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.0));
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.12, 0.96);
	AO = ao;
	SPECULAR = mix(clamp(0.50 - rough * 0.26, 0.18, 0.48), 0.84, wetness);
	EMISSION = emission_color * emission_energy + rim_color * rim * max(alb, vec3(0.18));
}
