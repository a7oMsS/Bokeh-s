shader_type canvas_item;
render_mode blend_add, unshaded;

uniform float skew_factor_x : hint_range(-1.0, 1.0) = 0.0;
uniform float skew_factor_y : hint_range(-1.0, 1.0) = 0.0;

void vertex() {
    VERTEX.y -= skew_factor_y * VERTEX.x;
    VERTEX.x -= skew_factor_x * VERTEX.y;
}
