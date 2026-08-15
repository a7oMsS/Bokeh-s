shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 color_dark : source_color = vec4(0.06, 0.05, 0.09, 1.0);
uniform vec4 color_bleed : source_color = vec4(0.32, 0.04, 0.22, 1.0);
uniform float damage_ratio : hint_range(0.0, 1.0) = 0.0;
uniform float fog_speed : hint_range(0.0, 1.0) = 0.15;
uniform float uv_scale : hint_range(0.1, 5.0) = 1.0;
uniform float edge_softness : hint_range(0.0, 0.3) = 0.12;
uniform float base_density : hint_range(0.1, 2.0) = 1.1;
uniform float hardness : hint_range(0.0, 1.0) = 0.85;
uniform float reveal_strength : hint_range(0.0, 1.0) = 0.85;

uniform float padding : hint_range(1.0, 2.0) = 1.4;
uniform float protrusion_amount : hint_range(0.0, 0.8) = 0.35;
uniform float facet_count : hint_range(2.0, 6.0) = 3.0;
uniform float radial_weight : hint_range(0.0, 1.0) = 0.6;

varying float v_circle_mask;

void fragment() {
	vec2 uv = (UV - 0.5) * padding;
	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x);

	// --- Silueta no circular: lóbulos/protuberancias ---
	vec2 lobe_sample = vec2(0.5) + 0.28 * vec2(cos(angle), sin(angle)) + vec2(TIME * fog_speed * 0.2, 0.0);
	float lobe_noise = texture(noise_tex, lobe_sample).r;
	float protrusion = (lobe_noise - 0.5) * protrusion_amount;
	float effective_edge = 1.0 - protrusion;
	float circle_mask = smoothstep(effective_edge, effective_edge - edge_softness, dist);
	v_circle_mask = circle_mask;

	// --- Normal falsa de esfera: alimenta el Fresnel de light() y el
	// muestreo de ruido con foreshortening, justo abajo ---
	vec2 normal_xy = uv * 2.0;
	float normal_z = sqrt(clamp(1.0 - dot(normal_xy, normal_xy), 0.0, 1.0));
	vec3 fake_normal = normalize(vec3(normal_xy, normal_z));
	NORMAL_MAP = fake_normal * 0.5 + 0.5;

	// --- Ruido interior muestreado por ángulo (longitud/latitud), no por
	// scroll lineal -- se comprime cerca del borde como rotaría de verdad
	// sobre una esfera, en vez de deslizarse parejo ---
	float longitude = atan(normal_xy.x, normal_z);
	float latitude = normal_xy.y * 0.5 + 0.5;
	vec2 sphere_uv = vec2(longitude / (2.0 * PI) + 0.5 - TIME * fog_speed, latitude) * uv_scale;
	float noise_val = texture(noise_tex, sphere_uv).r;

	float current_density = base_density - (damage_ratio * 0.65);
	float shape = noise_val * circle_mask * current_density;
	float alpha_cut = smoothstep(1.0 - hardness, 1.0 - hardness + max(edge_softness, 0.01), shape);

	// --- Relleno faceteado: placas duras en softness bajo (~0.12), blur
	// completo en softness alto (~0.25) ---
	float radial_shade = 1.0 - smoothstep(0.0, 1.0, dist);
	float raw = noise_val * facet_count;
	float hard_step = floor(raw + 0.5) / facet_count;
	float facet_blend = clamp(smoothstep(0.12, 0.25, edge_softness), 0.0, 1.0);
	float faceted = mix(hard_step, noise_val, facet_blend);
	float shading = clamp(mix(faceted, radial_shade, radial_weight), 0.0, 1.0);

	vec3 base_col = color_dark.rgb * (0.5 + shading * 0.7);
	vec3 final_col = mix(base_col, color_bleed.rgb, damage_ratio * (0.5 + shading * 0.5));

	float core_edge = max(edge_softness, 0.01);
	float core_mask = smoothstep(0.5 - core_edge, 0.5 + core_edge, shading * circle_mask);
	final_col = mix(final_col, color_bleed.rgb, core_mask * (1.0 - damage_ratio));

	COLOR = vec4(final_col * COLOR.rgb, alpha_cut * COLOR.a);
}

void light() {
	float fresnel = pow(1.0 - NORMAL.z, 2.0);
	float n_dot_l = max(0.0, dot(NORMAL, LIGHT_DIRECTION));

	vec3 tinted = COLOR.rgb * LIGHT_COLOR.rgb * (LIGHT_ENERGY * 30.0) * n_dot_l;
	vec3 rim = LIGHT_COLOR.rgb * fresnel * reveal_strength;

	LIGHT = vec4(tinted + rim, v_circle_mask * COLOR.a);
}