shader_type canvas_item;

// Tu textura de ruido configurada desde el inspector
uniform sampler2D noise_tex : repeat_enable, filter_linear;

uniform vec4 color_dark : source_color = vec4(0.06, 0.05, 0.09, 1.0);
uniform vec4 color_bleed : source_color = vec4(0.32, 0.04, 0.22, 1.0);

// 0.0 = densidad completa (sano), 1.0 = a punto de dispersarse.
uniform float damage_ratio : hint_range(0.0, 1.0) = 0.0;

uniform float fog_speed : hint_range(0.0, 1.0) = 0.15;
uniform float uv_scale : hint_range(0.1, 5.0) = 1.0; 
uniform float edge_softness : hint_range(0.0, 0.3) = 0.12;

uniform float base_density : hint_range(0.1, 2.0) = 1.1;
uniform float hardness : hint_range(0.0, 1.0) = 0.85;

varying float v_circle_mask;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	
	// Máscara circular para suavizar o limitar los bordes exteriores
	float circle_mask = smoothstep(1.0, 1.0 - edge_softness, dist);
	v_circle_mask = circle_mask;

	// 1. Distorsión (Warping) para el efecto de humo fluido
	vec2 wave_uv = (UV * uv_scale) + vec2(TIME * fog_speed * 0.5);
	vec2 distortion = texture(noise_tex, wave_uv).rg * 0.2;
	
	// 2. Coordenadas finales con desplazamiento de tiempo y distorsión
	vec2 scrolled_uv = (UV * uv_scale) + distortion + vec2(TIME * fog_speed, -TIME * fog_speed * 0.6);
	
	// 3. Muestreo de la textura de ruido
	float noise_val = texture(noise_tex, scrolled_uv).r;

	// 4. Lógica de densidad reactiva al daño
	float current_density = base_density - (damage_ratio * 0.65);
	float shape = noise_val * circle_mask * current_density;

	// 5. Corte duro para el estilo "pintura/concept art"
	float alpha_cut = smoothstep(1.0 - hardness, 1.0 - hardness + 0.05, shape);

	// 6. Colores base y sangrado por daño
	vec3 base_col = color_dark.rgb * (0.7 + noise_val * 0.5);
	vec3 final_col = mix(base_col, color_bleed.rgb, damage_ratio * (0.5 + noise_val * 0.5));

	// 7. Núcleo denso púrpura (solo visible cuando la entidad está sana)
	float core_mask = smoothstep(0.5, 0.8, noise_val * circle_mask);
	final_col = mix(final_col, color_bleed.rgb, core_mask * (1.0 - damage_ratio));

	COLOR = vec4(final_col * COLOR.rgb, alpha_cut * COLOR.a);
}

// Interacción con Light2D preservada
void light() {
	LIGHT = vec4(LIGHT_COLOR.rgb * LIGHT_ENERGY, v_circle_mask * COLOR.a);
}