// The sea around the world map: deep out in the open, turquoise over the shallows,
// with a slow swell, drifting glints and surf breathing against the shore. Drawn on a
// screen-filling rect; the uniforms say where the camera looks.
shader_type canvas_item;

uniform sampler2D terrain : filter_linear;
uniform vec2 map_size = vec2(1000.0, 1600.0);
uniform vec2 cam_center = vec2(500.0, 800.0);
uniform float cam_scale = 1.0;
uniform vec2 view_center = vec2(360.0, 640.0);
uniform vec2 rect_size = vec2(720.0, 1280.0);
uniform vec4 deep : source_color = vec4(0.09, 0.2, 0.29, 1.0);
uniform vec4 shallow : source_color = vec4(0.18, 0.44, 0.49, 1.0);
uniform vec4 foam : source_color = vec4(0.86, 0.94, 0.95, 1.0);

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
	vec2 uv = map_pos / map_size;
	// Past the map's edge it's open sea.
	float inside = smoothstep(0.0, 0.03, uv.x) * smoothstep(1.0, 0.97, uv.x)
		* smoothstep(0.0, 0.02, uv.y) * smoothstep(1.0, 0.98, uv.y);
	vec4 t = texture(terrain, uv) * inside;
	float near = t.b * 0.55 + t.g * 0.45;
	vec3 col = mix(deep.rgb, shallow.rgb, smoothstep(0.0, 0.55, near));
	col *= 0.93 + 0.12 * noise(map_pos * 0.018 + vec2(TIME * 0.05, TIME * 0.03));
	float ripple = noise(vec2(map_pos.x * 0.07 + TIME * 0.35, map_pos.y * 0.22 - TIME * 0.1));
	col += vec3(0.07, 0.09, 0.09) * smoothstep(0.76, 0.92, ripple) * (1.0 - near * 0.7);
	float surf = smoothstep(0.16, 0.5, t.r) * (0.55 + 0.45 * sin(TIME * 1.3 - t.g * 14.0));
	col = mix(col, foam.rgb, surf * 0.5);
	COLOR = vec4(col, 1.0);
}
