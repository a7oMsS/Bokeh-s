shader_type canvas_item;

uniform float fog_speed = 0.3;
uniform float fog_scale = 2.5;
uniform float fog_intensity = 0.2;
uniform vec4 fog_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);

// Función de ruido basada en coordenadas UV
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Suaviza el ruido entre los píxeles para que no se vea como grano
float smooth_noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    // Ruido en los vértices de la celda
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    // Interpolación suave
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV;

    // Animación del desplazamiento
    vec2 offset_uv = uv * fog_scale + vec2(TIME * fog_speed, -TIME * fog_speed * 0.5);
    float noise = smooth_noise(offset_uv);

    // Oscilación suave adicional (más movimiento)
    float pulse = 0.5 + 0.5 * sin(TIME * 0.3 + uv.x * 3.0);

    float fog_alpha = noise * pulse * fog_intensity;

    COLOR = vec4(fog_color.rgb, fog_alpha);
}
