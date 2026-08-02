shader_type canvas_item;

uniform vec4 color_start : source_color = vec4(1.0, 0.0, 0.0, 1.0); // Rojo
uniform vec4 color_end : source_color = vec4(0.0, 0.0, 1.0, 1.0);   // Azul
uniform float gradient_speed = 0.5;
const float gradient_angle = -PI/4.0; // 0 para horizontal, PI/2 para vertical
uniform float gradient_width = 0.5; // Ancho de la zona de transición del gradiente

void fragment() {
    // Obtenemos las coordenadas UV del píxel actual
    // El 'SCREEN_UV' es relativo a la pantalla completa, 'UV' es relativo al nodo.
    // Usaremos UV para que el gradiente se mueva dentro del label.
    vec2 uv_rotated = UV;

    // Rotar las UVs si es necesario para el ángulo del gradiente
    float cos_angle = cos(gradient_angle);
    float sin_angle = sin(gradient_angle);
    mat2 rotation_matrix = mat2(vec2(cos_angle, -sin_angle), vec2(sin_angle, cos_angle));

    // Rotamos las UVs alrededor del centro (0.5, 0.5) del nodo
    uv_rotated = (uv_rotated - vec2(0.5)) * rotation_matrix + vec2(0.5);

    // Calcular el factor de movimiento basado en el tiempo
    float time_factor = TIME * gradient_speed;

    // Calcular la posición del gradiente
    // Agregamos el factor de tiempo a la coordenada relevante (ej. uv_rotated.x para horizontal)
    float gradient_position = uv_rotated.x + time_factor;

    // Convertimos el gradiente a un rango de 0 a 1 con un ancho de transición
    float t = smoothstep(0.0 - gradient_width, 1.0 + gradient_width, mod(gradient_position, 2.0));

    // Si queremos que vaya de un lado a otro en vez de "reiniciar"
    // float t = abs(mod(gradient_position, 2.0) - 1.0); // triangular wave from 0 to 1 to 0

    // Interpolar entre los colores
    vec4 gradient_color = mix(color_start, color_end, t);

    // Obtener el color del texto original (del Label)
    vec4 text_color = texture(TEXTURE, UV);

    // Aplicar el gradiente solo donde hay texto
    COLOR = vec4(gradient_color.rgb, text_color.a);
}