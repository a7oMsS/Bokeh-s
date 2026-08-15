shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 color_a : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.7, 0.4, 1.0);
uniform int shape;
uniform float smoothness : hint_range(0.0, 1.0) = 0.085;
uniform float padding : hint_range(1.0, 3.0) = 1.65;

float sdCircle(vec2 p) { return length(p) - 0.9; }
float sdBox(vec2 p) { return max(abs(p.x), abs(p.y)) - 0.9; }
float sdEquilateralTriangle(vec2 p) {
    const float k = sqrt(3.0);
    p.x = abs(p.x) - 0.85;
    p.y = p.y + 1.0/k;
    if( p.x+k*p.y>0.0 ) p = vec2(p.x-k*p.y,-k*p.x-p.y)/2.0;
    p.x -= clamp( p.x, -2.0, 0.0 );
    return -length(p)*sign(p.y);
}
float sdStar5(vec2 p) {
    const float r = 0.9;
    const float k1x = 0.809016994; const float k2x = 0.309016994;
    const float k1y = 0.587785252; const float k2y = 0.951056516;
    const float k1z = 0.726542528; const vec2 v1 = vec2(k1x, -k1y);
    const vec2 v2 = vec2(-k1x, -k1y); const vec2 v3 = vec2(k2x, -k2y);
    p.x = abs(p.x); p -= 2.0 * max(dot(v1, p), 0.0) * v1;
    p -= 2.0 * max(dot(v2, p), 0.0) * v2; p.x = abs(p.x); p.y -= r;
    return length(p - v3 * clamp(dot(p, v3), 0.0, k1z * r)) * sign(p.y * v3.x - p.x * v3.y);
}
float sdStar4(vec2 p) {
    float r = 0.9; int n = 4; float m = 2.5;
    float an = 3.1415926535 / float(n); float en = 3.1415926535 / m;
    vec2 acs = vec2(cos(an), sin(an)); vec2 ecs = vec2(cos(en), sin(en));
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = length(p) * vec2(cos(bn), abs(sin(bn)));
    p -= r * acs; p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}
float sdHexagon(vec2 p){
    const float r = 0.85; const vec3 k = vec3(-0.866025404,0.5,0.577350269);
    p = abs(p); p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    return length(p)*sign(p.y);
}
float sdRhombus(vec2 p) {
    p = abs(p); float d = p.x + p.y - 0.9;
    return d * 0.707107;
}
float sdHeart(vec2 p ){
    p *= 0.7; p.y += 0.6; p.x = abs(p.x);
    if( p.y+p.x> 1.0 ) return sqrt(dot(p-vec2(0.25,0.75),p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;
    return sqrt(min(dot(p-vec2(0.00,1.00),p-vec2(0.00,1.00)), dot(p-0.5*max(p.x+p.y,0.0),p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

float sdf_shape(vec2 p) {
    if (shape == 0) return sdCircle(p);
    if (shape == 1) return sdBox(p);
    if (shape == 2) return sdEquilateralTriangle(p);
    if (shape == 3) return sdStar5(p);
    if (shape == 4) return sdStar4(p);
    if (shape == 5) return sdHexagon(p);
    if (shape == 6) return sdRhombus(p);
    if (shape == 7) return sdHeart(p);
    return sdCircle(p);
}

void fragment() {
    vec4 modulate_in = COLOR;

    vec2 uv = UV - 0.5;
    float d = sdf_shape(uv * 2.0 * padding);

    float soft = max(smoothness, 0.035);
    if (shape == 3 || shape == 4) { soft = 0.065; }
    else if (shape == 5 || shape == 1) { soft = 0.09; }

    if (d > soft * 7.5) { COLOR = vec4(0.0); discard; }

    float core   = pow(smoothstep(soft * 0.95, -soft * 1.9, d), 1.6);
    float body   = smoothstep(soft * 2.6, -soft * 0.8, d) * 0.96;
    float halo   = smoothstep(soft * 7.0, -soft * 3.5, d) * 0.18;
    float bubble = smoothstep(soft * 1.3, -soft * 0.85, d) *
                   smoothstep(soft * 3.5, soft * 1.2, d) * 0.5;

    float ca = soft * 0.20;
    float r = smoothstep(ca * 1.4, -soft * 0.7, sdf_shape((uv + vec2(ca*0.9, ca*0.2)) * 2.0 * padding));
    float b = smoothstep(ca * 1.1, -soft * 0.7, sdf_shape((uv - vec2(ca*0.8, ca*0.25)) * 2.0 * padding));

    vec3 base_col = mix(color_a.rgb, color_b.rgb, UV.x);
    vec3 col = base_col * vec3(r * 1.08, body * 0.97, b * 1.1);

    float intensity = core * 1.75 + body * 1.4 + halo * 0.4 + bubble * 1.1;
    vec3 final_color = col * intensity * modulate_in.rgb;
    float alpha = (core * 0.82 + body * 0.65) * color_a.a * 0.85 * modulate_in.a;

    COLOR = vec4(final_color, alpha);
}