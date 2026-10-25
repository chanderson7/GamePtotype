// The light over the world map, multiplied over everything below it: the hour's
// daylight (gold at dawn and dusk, blue at night), cloud shadows drifting across the
// land and sea, and a soft darkening toward the screen's edges.
shader_type canvas_item;
render_mode blend_mul;

uniform vec2 cam_center = vec2(500.0, 800.0);
uniform float cam_scale = 1.0;
uniform vec2 view_center = vec2(360.0, 640.0);
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 daylight : source_color = vec4(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 map_pos = cam_center + (UV * rect_size - view_center) / cam_scale;
	vec2 drift = vec2(TIME * 1.6, TIME * 0.7);
	float c = noise((map_pos + drift) * 0.005) * 0.7 + noise((map_pos + drift * 1.4) * 0.014) * 0.3;
	float shadow = smoothstep(0.6, 0.85, c) * 0.1;
	vec2 d = UV - 0.5;
	float edge = 1.0 - dot(d, d) * 0.4;
	COLOR = vec4(daylight.rgb * (1.0 - shadow) * edge, 1.0);
}
