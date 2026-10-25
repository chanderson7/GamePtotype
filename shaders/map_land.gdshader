// The land of the world map, drawn in map units. Each realm's polygon brings its own
// color; this mottles it, shades hills lit from the upper left, and turns the shore to
// sand. The terrain texture comes from scripts/world/map_terrain.gd.
shader_type canvas_item;

uniform sampler2D terrain : filter_linear;
uniform vec2 map_size = vec2(1000.0, 1600.0);
uniform vec4 beach : source_color = vec4(0.86, 0.79, 0.6, 1.0);

varying vec2 map_pos;

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

void vertex() {
	map_pos = VERTEX;
}

void fragment() {
	vec2 uv = map_pos / map_size;
	// Past the map's edge the land runs on, plain: no shore, no hills.
	float inside = smoothstep(0.0, 0.03, uv.x) * smoothstep(1.0, 0.97, uv.x)
		* smoothstep(0.0, 0.02, uv.y) * smoothstep(1.0, 0.98, uv.y);
	vec4 t = mix(vec4(1.0, 1.0, 1.0, 0.2), texture(terrain, uv), inside);
	vec2 px = 1.0 / vec2(textureSize(terrain, 0));
	float relief = clamp((texture(terrain, uv - px).a - texture(terrain, uv + px).a) * 10.0, -1.0, 1.0) * inside;
	vec3 col = COLOR.rgb;
	col *= 0.95 + 0.1 * noise(map_pos * 0.025);
	col *= 0.97 + 0.06 * noise(map_pos * 0.2);
	col *= 1.0 + relief * 0.2;
	col = mix(col, col * vec3(1.08, 1.06, 1.0), t.a * 0.6);
	float shore = 1.0 - smoothstep(0.62, 0.86, t.r);
	col = mix(col, beach.rgb, shore * 0.8);
	COLOR = vec4(col, 1.0);
}
