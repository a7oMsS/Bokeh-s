shader_type canvas_item;

uniform float border_width = 0.07;
uniform vec4 color_a : source_color;
uniform float size = 0.0;
uniform int forma;
uniform float blur;

float sdCircle(vec2 p) {
    return length(p) - 0.9;
}

float sdBox(vec2 p) {
    return max(abs(p.x), abs(p.y)) - 0.9;
}

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
    const float k1x = 0.809016994; // cos(π/5) = ¼(√5+1)
    const float k2x = 0.309016994; // sin(π/10) = ¼(√5-1)
    const float k1y = 0.587785252; // sin(π/5) = ¼√(10-2√5)
    const float k2y = 0.951056516; // cos(π/10) = ¼√(10+2√5)
    const float k1z = 0.726542528; // tan(π/5) = √(5-2√5)
    const vec2 v1 = vec2(k1x, -k1y);
    const vec2 v2 = vec2(-k1x, -k1y);
    const vec2 v3 = vec2(k2x, -k2y);
    p.x = abs(p.x);
    p -= 2.0 * max(dot(v1, p), 0.0) * v1;
    p -= 2.0 * max(dot(v2, p), 0.0) * v2;
    p.x = abs(p.x);
    p.y -= r;
    return length(p - v3 * clamp(dot(p, v3), 0.0, k1z * r)) * sign(p.y * v3.x - p.x * v3.y);
}

// SDF para una estrella de 4 puntas
float sdStar4(vec2 p) {
    float r = 0.9;
    int n = 4;
    float m = 2.5;
    float an = 3.1415926535 / float(n); // Ángulo por sector
    float en = 3.1415926535 / m;        // Ángulo de la punta
    vec2 acs = vec2(cos(an), sin(an));
    vec2 ecs = vec2(cos(en), sin(en));

    // Reducir al primer sector
    float bn = mod(atan(p.x, p.y), 2.0 * an) - an;
    p = length(p) * vec2(cos(bn), abs(sin(bn)));

    // Calcular la distancia
    p -= r * acs;
    p += ecs * clamp(-dot(p, ecs), 0.0, r * acs.y / ecs.y);
    return length(p) * sign(p.x);
}

// SDF para un hexágono
float sdHexagon(vec2 p){
    const float r = 0.85;
    const vec3 k = vec3(-0.866025404,0.5,0.577350269);
    p = abs(p);
    p -= 2.0*min(dot(k.xy,p),0.0)*k.xy;
    p -= vec2(clamp(p.x, -k.z*r, k.z*r), r);
    return length(p)*sign(p.y);
}

// SDF para un rombo
float sdRhombus(vec2 p) {
    p = abs(p); // Simetría
    float d = p.x + p.y - 0.9; // Distancia manhattan rotada 45°
    return d * 0.707107; // Normalizar para que sea un rombo con "radio" 0.7
}

// SDF para un corazón
float sdHeart(vec2 p ){
    p *= 0.7;
    p.y += 0.6;
    p.x = abs(p.x);

    if( p.y+p.x> 1.0 )
        return sqrt(dot(p-vec2(0.25,0.75),p-vec2(0.25,0.75))) - sqrt(2.0)/4.0;

    return sqrt(min(dot(p-vec2(0.00,1.00),p-vec2(0.00,1.00)),
                    dot(p-0.5*max(p.x+p.y,0.0),p-0.5*max(p.x+p.y,0.0)))) * sign(p.x-p.y);
}

float sdf_shape(vec2 p) {
    if (forma == 0) {
        return sdCircle(p);
    } else if (forma == 1) {
        return sdBox(p);
    } else if (forma == 2) {
        return sdEquilateralTriangle(p);
    } else if (forma == 3) {
        return sdStar5(p);
    } else if (forma == 4) {
        return sdStar4(p);
    } else if (forma == 5) {
        return sdHexagon(p);
    } else if (forma == 6) {
        return sdRhombus(p);
    } else if (forma == 7) {
        return sdHeart(p);
    }
    return sdCircle(p); // Valor por defecto
}

void fragment() {
    vec2 uv = (UV - vec2(0.5)) * 2.0;
    float d = sdf_shape(uv);
    float scale = clamp(size, 0.7, 1.0);

    float border = border_width * scale;
    float alpha = smoothstep(border, border - blur*0.5, abs(d));
	// Combinar color_a con modulate (COLOR.rgb contiene self.modulate)

    vec3 final_color = color_a.rgb * COLOR.rgb;
    COLOR = vec4(final_color, alpha * COLOR.a);
}
