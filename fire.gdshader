shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform float time_scale = 1.0;
uniform float flame_height = 1.6;
uniform float flame_width = 1.0;
uniform vec3 core_color : source_color = vec3(1.0, 0.95, 0.6);
uniform vec3 mid_color : source_color = vec3(1.0, 0.5, 0.05);
uniform vec3 edge_color : source_color = vec3(0.9, 0.15, 0.02);
uniform float intensity = 1.4;

varying vec2 uv_v;

float hash(vec2 p) {
p = fract(p * vec2(123.34, 456.21));
p += dot(p, p + 45.32);
return fract(p.x * p.y);
}

float noise(vec2 p) {
vec2 i = floor(p);
vec2 f = fract(p);
f = f * f * (3.0 - 2.0 * f);
float a = hash(i);
float b = hash(i + vec2(1.0, 0.0));
float c = hash(i + vec2(0.0, 1.0));
float d = hash(i + vec2(1.0, 1.0));
return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
float v = 0.0;
float a = 0.5;
for (int i = 0; i < 5; i++) {
v += a * noise(p);
p *= 2.05;
a *= 0.5;
}
return v;
}

void vertex() {
uv_v = UV;
}

void fragment() {
vec2 uv = uv_v;
// Fire is a "column" — taper toward the top
float y = uv.y;
float center_x = 0.5 + sin(y * 4.0 + TIME * 1.8) * 0.06;
float horizontal_dist = abs(uv.x - center_x);
float taper = mix(0.42, 0.08, y);
float column = 1.0 - smoothstep(taper * 0.75, taper, horizontal_dist);

// Vertical fade — strongest in the middle, dies at top
float top_fade = 1.0 - smoothstep(0.55, 1.0, y);
float bottom_fade = smoothstep(0.0, 0.15, y);
float shape = column * top_fade * bottom_fade;

// Flowing noise — 2 layers scrolling upward at different speeds
vec2 noise_uv1 = vec2(uv.x * 5.5, uv.y * 3.5 - TIME * 2.4);
vec2 noise_uv2 = vec2(uv.x * 4.0 - 0.3, uv.y * 2.5 - TIME * 3.5);
float n1 = fbm(noise_uv1);
float n2 = fbm(noise_uv2);
float flame_noise = mix(n1, n2, 0.55);

// Erode shape with noise so edges flicker and tongues form
float edge_noise = mix(0.55, 1.0, flame_noise);
float body = shape * edge_noise;
body = smoothstep(0.05, 0.55, body);

// Color gradient — hot white/yellow at base, orange middle, red top
float heat = mix(1.0, 0.2, y) * (0.6 + 0.4 * flame_noise);
vec3 fire_col = mix(edge_color, mid_color, min(1.0, heat * 1.5));
fire_col = mix(fire_col, core_color, smoothstep(0.55, 1.0, heat));

// Small bright spots where noise peaks (sparks/hot cores)
float hotspots = smoothstep(0.72, 0.95, flame_noise) * shape;
fire_col += vec3(1.0, 0.85, 0.4) * hotspots * 0.9;

ALBEDO = fire_col * intensity;
EMISSION = fire_col * intensity;
ALPHA = body;
}
