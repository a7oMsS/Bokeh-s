shader_type canvas_item;
render_mode blend_premul_alpha;

void fragment() {
	vec4 c = COLOR;
	c.rgb *= c.a;
	COLOR = c;
}
