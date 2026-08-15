shader_type canvas_item;
uniform vec4 bg_color : source_color = vec4(0.0295, 0.0295, 0.0295, 1.0);

void fragment() {
	COLOR = bg_color;
}