shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Neste-generasjons AAA PBR overflateshader (Sea of Thieves / Uncharted / Pixar-stil):
// Erstatter blasse, uskarpe 2005-teksturer med knivskarpe triplanare 512x512 PBR-materialer
// (eikeplanker, hugget steinmur, arabisk sandstein, skifertak, smidd messing, 2.5D grunnfjell),
// ekte normalmap-detaljer, dyp filmkontrast og våt kystglans – null «fadet» eller «chubby» look!

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic;

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
uniform float base_roughness : hint_range(0.05, 1.0) = 0.68;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.5) = 1.45;
uniform float pbr_blend : hint_range(0.0, 1.0) = 0.55;
uniform float pbr_tile_scale : hint_range(0.05, 4.0) = 0.38;
uniform float contrast_gamma : hint_range(0.8, 1.8) = 1.24;
uniform float saturation_boost : hint_range(0.7, 1.6) = 1.24;
uniform float wet_water_y = -999.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.06;
uniform vec3 rim_color : source_color = vec3(0.85, 0.92, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 orig = albedo_tint.rgb;
	if (has_albedo_tex) {
		orig *= texture(albedo_tex, UV).rgb;
	}
	// Fjern blass 2005-gamma-vask: dypere, rikere og skarpere moderne fargekontrast!
	orig = pow(max(orig, vec3(0.0001)), vec3(contrast_gamma)) * 1.08;

	vec3 alb = orig;
	float rough = base_roughness;
	float metal = base_metallic;
	float ao = 1.0;

	vec3 wn = normalize(v_world_nrm);
	vec3 tri_wn = wn;
	if (has_pbr_pack) {
		vec3 w = abs(wn);
		w = pow(w, vec3(5.0));
		w /= max(w.x + w.y + w.z, 0.0001);

		vec2 uv_x = v_world_pos.zy * pbr_tile_scale;
		vec2 uv_y = v_world_pos.xz * pbr_tile_scale;
		vec2 uv_z = v_world_pos.xy * pbr_tile_scale;

		vec3 pa = texture(pbr_albedo_tex, uv_x).rgb * w.x
		        + texture(pbr_albedo_tex, uv_y).rgb * w.y
		        + texture(pbr_albedo_tex, uv_z).rgb * w.z;
		float pr = texture(pbr_rough_tex, uv_x).r * w.x
		         + texture(pbr_rough_tex, uv_y).r * w.y
		         + texture(pbr_rough_tex, uv_z).r * w.z;

		// Ekte verdensroms UDN triplanar normalmapping – knivskarp 3D-dybde selv på gamle 2005-flater uten UV!
		vec3 tnx = texture(pbr_normal_tex, uv_x).rgb * 2.0 - 1.0;
		vec3 tny = texture(pbr_normal_tex, uv_y).rgb * 2.0 - 1.0;
		vec3 tnz = texture(pbr_normal_tex, uv_z).rgb * 2.0 - 1.0;
		float ns = normal_strength * 0.68;
		tnx.xy *= ns;
		tny.xy *= ns;
		tnz.xy *= ns;
		vec3 nx = vec3(wn.x, tnx.y + wn.y, tnx.x + wn.z);
		vec3 ny = vec3(tny.x + wn.x, wn.y, tny.y + wn.z);
		vec3 nz = vec3(tnz.x + wn.x, tnz.y + wn.y, wn.z);
		tri_wn = normalize(nx * w.x + ny * w.y + nz * w.z);

		// Skarp detalj-syntese: bevar original fargetone på hus/skute, men erstatt all 2005-grøt med skarpe PBR-fibre & fuger!
		float pa_lum = dot(pa, vec3(0.299, 0.587, 0.114));
		float orig_lum = max(dot(orig, vec3(0.299, 0.587, 0.114)), 0.04);
		vec3 tinted_pbr = pa * clamp(orig / orig_lum, vec3(0.38), vec3(2.15)) * clamp(orig_lum * 1.48, 0.35, 1.32);
		vec3 detail_mul = orig * clamp(0.42 + pa_lum * 1.32, 0.22, 1.68);
		alb = mix(detail_mul, mix(tinted_pbr, pa * albedo_tint.rgb, step(0.85, pbr_blend)), pbr_blend);
		rough = mix(base_roughness, pr, 0.65);
		ao = clamp(0.56 + pa_lum * 0.60, 0.38, 1.0);
	}

	if (has_orm_tex) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ao = min(ao, mix(1.0, orm.r, 0.85));
		rough = mix(rough, clamp(orm.g * 0.90, 0.12, 0.96), 0.30);
		metal = max(base_metallic, orm.b);
	}

	// Rik moderne fargemetning uten blass pastell-haze
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, saturation_boost);

	// Våt, mørk og blank kystsone langs bryggene og vannlinjen
	float wetness = 0.0;
	if (wet_water_y > -500.0) {
		wetness = 1.0 - smoothstep(wet_water_y - 0.1, wet_water_y + 1.15, v_world_pos.y);
		alb *= mix(1.0, 0.52, wetness * 0.84);
	}
	rough = mix(rough, 0.14, wetness * 0.85);

	// Påfør skarp verdensroms PBR-normal (eller original normal på bossmodeller uten PBR-pakke)
	if (has_pbr_pack) {
		NORMAL = normalize((VIEW_MATRIX * vec4(tri_wn, 0.0)).xyz);
	} else if (has_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength * 0.85;
	}

	// Diskret fysisk kantglans (ingen melkehvit tåke-vask!)
	float ndotv = clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 4.2) * rim_strength;

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.05));
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.10, 0.96);
	AO = ao;
	SPECULAR = mix(clamp(0.62 - rough * 0.45, 0.16, 0.58), 0.92, wetness);
	EMISSION = emission_color * emission_energy + rim_color * rim * 0.10;
}
