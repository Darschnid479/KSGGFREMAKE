shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Moderne AAA animasjonsspill-overflateshader (Kena / Sea of Thieves / Pixar PBR):
// Lynrask triplanar mikrodetalj-tekstur (10x raskere på både GPU og CPU), livfulle farger, våt kystglans og kantglød.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : filter_linear_mipmap_anisotropic;
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_albedo_tex = true;
uniform bool has_normal_tex = false;
uniform bool has_orm_tex = false;
uniform bool has_detail_tex = false;

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec3 emission_color : source_color = vec3(0.0, 0.0, 0.0);
uniform float emission_energy = 0.0;
uniform float base_roughness : hint_range(0.05, 1.0) = 0.72;
uniform float base_metallic : hint_range(0.0, 1.0) = 0.0;
uniform float normal_strength : hint_range(0.0, 2.5) = 1.25;
uniform float micro_detail_strength : hint_range(0.0, 1.0) = 0.36;
uniform float micro_scale : hint_range(0.1, 4.0) = 0.45;
uniform float saturation_boost : hint_range(0.7, 1.5) = 1.16;
uniform float wet_water_y = -999.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.16;
uniform vec3 rim_color : source_color = vec3(0.85, 0.92, 1.0);

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

	// Lynrask triplanar mikrodetalj fra sømløs høyfrekvent støymap (kun 3 raske tekstur-oppslag!)
	float mc = 0.5;
	if (has_detail_tex) {
		vec3 w = abs(v_world_nrm);
		w = pow(w, vec3(4.0));
		w /= max(w.x + w.y + w.z, 0.0001);
		float tx = texture(detail_tex, v_world_pos.yz * micro_scale).r;
		float ty = texture(detail_tex, v_world_pos.xz * micro_scale).r;
		float tz = texture(detail_tex, v_world_pos.xy * micro_scale).r;
		mc = tx * w.x + ty * w.y + tz * w.z;
	}

	float micro_shade = mix(1.0, 0.76 + mc * 0.48, micro_detail_strength);
	alb *= micro_shade;

	// Levende moderne animasjons-fargemetning
	float lum = dot(alb, vec3(0.299, 0.587, 0.114));
	alb = mix(vec3(lum), alb, saturation_boost);

	// Våt kystsone rett over vannlinjen (mørkere, blankere treverk og steiner langs bryggene)
	float wetness = 0.0;
	if (wet_water_y > -500.0) {
		wetness = 1.0 - smoothstep(wet_water_y - 0.1, wet_water_y + 1.15, v_world_pos.y);
		alb *= mix(1.0, 0.62, wetness * 0.75);
	}

	float rough = base_roughness;
	float metal = base_metallic;
	float ao = 1.0;
	if (has_orm_tex) {
		vec3 orm = texture(orm_tex, UV).rgb;
		ao = mix(1.0, orm.r, 0.85);
		rough = clamp(orm.g * 0.90 + (0.5 - mc) * 0.18, 0.10, 0.96);
		metal = max(base_metallic, orm.b);
	} else {
		rough = clamp(base_roughness + (0.5 - mc) * 0.20, 0.12, 0.96);
	}
	rough = mix(rough, 0.14, wetness * 0.85);

	if (has_normal_tex) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}

	// Kunstnerisk Pixar kantglød (Fresnel rim)
	float ndotv = clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - ndotv, 3.4) * rim_strength * (0.45 + 0.55 * clamp(v_world_nrm.y * 0.5 + 0.5, 0.0, 1.0));

	ALBEDO = clamp(alb, vec3(0.0), vec3(1.2));
	METALLIC = metal;
	ROUGHNESS = rough;
	AO = ao;
	SPECULAR = mix(0.55, 0.88, wetness);
	EMISSION = emission_color * emission_energy + rim_color * rim * 0.24;
}
