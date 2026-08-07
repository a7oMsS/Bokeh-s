shader_type canvas_item;

uniform vec4 glass_base_color : source_color = vec4(0.0, 0.173, 0.161, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.0, 0.22, 0.184, 1.0);
uniform vec4 border_color : source_color = vec4(0.784, 0.78, 0.0, 1.0);

uniform float border_size : hint_range(0.001, 0.5) = 0.005;
uniform float stripe_count : hint_range(1.0, 20.0) = 10.615;
uniform float stripe_width : hint_range(0.05, 1.0) = 0.837;
uniform float stripe_angle : hint_range(0.0, 1.0) = 0.528;

uniform float width_variation : hint_range(0.0, 2.0) = 1.572;
uniform float random_seed = 10;

uniform float angle_osc_speed : hint_range(0.0, 2.0) = 0.2;
uniform float angle_osc_amplitude : hint_range(0.0, 1.0) = 0.3;

// Nuevo uniform para controlar la velocidad de oscilación
uniform float stripe_osc_speed : hint_range(0.0, 5.0) = 0.1;
// Intensidad de la oscilación (qué tanto se mueve el patrón)
uniform float stripe_osc_amplitude : hint_range(0.0, 1.0) = 0.3;

// Suavizado de bordes
uniform float edge_softness : hint_range(0.0, 5.0) = 0.02;

uniform float blur_amount : hint_range(0.0, 5.0) = 1.5;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

vec4 blur_sample(vec2 uv) {
	// tamaño del texel en UV (1 / resolución de pantalla)
	vec2 texel = vec2(1.0) / vec2(textureSize(SCREEN_TEXTURE, 0))*blur_amount;
    vec4 col = vec4(0.0);
    col += texture(SCREEN_TEXTURE, uv + texel * vec2(-1.0, -1.0));
    col += texture(SCREEN_TEXTURE, uv + texel * vec2( 1.0, -1.0));
    col += texture(SCREEN_TEXTURE, uv + texel * vec2(-1.0,  1.0));
    col += texture(SCREEN_TEXTURE, uv + texel * vec2( 1.0,  1.0));
    return col * 0.25; // promedio
}

float hash(float n) {
    return fract(sin(n * 91.3458 + random_seed) * 47453.5453);
}

void fragment() {
    // Coordenada diagonal continua
	float angle_mod = 1.0 + angle_osc_amplitude * cos(TIME * angle_osc_speed);
	float diagonal_coord = UV.x * (1.0 - stripe_angle) + UV.y * stripe_angle * angle_mod;

	// Oscilación tipo “sombra de árbol”
	float osc = sin(TIME * stripe_osc_speed) * stripe_osc_amplitude;
	osc += sin(TIME * (stripe_osc_speed * 0.37)) * (stripe_osc_amplitude * 0.5);

	// Aquí no sumamos un scroll constante, sino este desplazamiento que va y viene
	diagonal_coord = diagonal_coord * stripe_count + osc;

    // Índice de la franja
    float stripe_index = floor(diagonal_coord);

    // Ancho variable
    float rnd = hash(stripe_index);
    float local_width = stripe_width * mix(1.0 - width_variation, 1.0 + width_variation, rnd);

    // Patrón repetitivo
    float repeating_pattern = fract(diagonal_coord);

    // Mask con bordes suaves
    float stripe_mask = smoothstep(local_width, local_width - edge_softness, repeating_pattern);

    // 7. Colores
	vec4 blurred_bg = blur_sample(SCREEN_UV);
	vec4 final_color = mix(blurred_bg, glass_base_color, 0.6);
	vec4 final_color_stripes = mix(blurred_bg, stripe_color, 0.6);
    final_color.rgb = mix(final_color.rgb, final_color_stripes.rgb, stripe_mask);


        COLOR = final_color;

}
