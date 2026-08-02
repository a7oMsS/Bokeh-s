shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform vec4 color_b : source_color = vec4(0.0, 0.0, 1.0, 1.0);

uniform float radius : hint_range(0.0, 0.5) = 0.1;          // radio esquinas en UV
uniform float border_softness : hint_range(0.0, 0.05) = 0.003; // suavizado
uniform float outline_thickness : hint_range(0.0, 0.1) = 0.03; // grosor del borde

uniform int estilo;

void fragment() {
    vec2 p = UV - 0.5;

    vec3 base_col;
    base_col = mix(color_a.rgb, color_b.rgb, UV.y);

    vec3 col = vec3(0.0);
    col = base_col;

    COLOR = vec4(col, 1.0);
}
