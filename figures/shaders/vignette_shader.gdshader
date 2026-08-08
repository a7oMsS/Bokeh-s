shader_type canvas_item;

uniform vec4 color_dark : source_color = vec4(0.06, 0.05, 0.09, 1.0);
uniform vec4 color_bleed : source_color = vec4(0.32, 0.04, 0.22, 1.0);

// 0.0 = densidad completa (sano), 1.0 = a punto de dispersarse.
// Vignette.gd lo actualiza cada vez que take_damage() o la regeneracion
// cambian la densidad.
uniform float damage_ratio : hint_range(0.0, 1.0) = 0.0;

uniform float fog_speed : hint_range(0.0, 1.0) = 0.15;
uniform float fog_scale : hint_range(1.0, 6.0) = 3.0;
uniform float edge_softness : hint_range(0.0, 0.3) = 0.12;

// Mismo ruido que ya usas en fog.gdshader -- reutilizado a proposito para
// que la "textura de humo" comparta lenguaje visual con el resto del juego.
float rand(vec2 co) {
	return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float circle_mask = smoothstep(1.0, 1.0 - edge_softness, dist);

	vec2 noise_uv = UV * fog_scale + vec2(TIME * fog_speed, -TIME * fog_speed * 0.6);
	float fog = smooth_noise(noise_uv) * 0.6 + smooth_noise(noise_uv * 2.3) * 0.3;

	vec3 base_col = color_dark.rgb * (0.7 + fog * 0.5);
	vec3 final_col = mix(base_col, color_bleed.rgb, damage_ratio * (0.5 + fog * 0.5));

	// Igual que el resto de tus shaders de Figure: multiplica por COLOR
	// entrante para que modulate siga controlando alpha (aparicion/dispersion).
	COLOR = vec4(final_col * COLOR.rgb, circle_mask * COLOR.a);
}
