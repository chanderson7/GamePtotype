// The land of the world map, drawn in map units. Each realm's polygon brings its own
// color; this mottles it, shades hills lit from the upper left, and turns the shore to
// sand. The terrain texture comes from scripts/world/map_terrain.gd.
shader_type canvas_item;

uniform sampler2D terrain : filter_linear;
uniform vec2 map_size = vec2(1000.0, 1600.0);
// The land picture starts here, in map units (it reaches past the map's edge).
uniform vec2 map_origin = vec2(0.0, 0.0);
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

// The ground is drawn in the same chunky pixels as the trees and towns that stand on it
// (two map units to the pixel): every sample is taken at its pixel's middle, and the
// light and shade are cut into steps, dithered where one step meets the next.
const float PIXEL = 2.0;
const float STEPS = 14.0;
const float BAYER[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

void fragment() {
	vec2 cell = floor(map_pos / PIXEL);
	vec2 mp = (cell + 0.5) * PIXEL;
	float dither = (BAYER[int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4] + 0.5) / 16.0;
	vec2 uv = (mp - map_origin) / map_size;
	// At the far edge of the land picture the land runs on, plain.
	float inside = smoothstep(0.0, 0.03, uv.x) * smoothstep(1.0, 0.97, uv.x)
		* smoothstep(0.0, 0.02, uv.y) * smoothstep(1.0, 0.98, uv.y);
	vec4 t = mix(vec4(1.0, 1.0, 1.0, 0.2), texture(terrain, uv), inside);
	vec2 px = 1.0 / vec2(textureSize(terrain, 0));
	float relief = clamp((texture(terrain, uv - px).a - texture(terrain, uv + px).a) * 10.0, -1.0, 1.0) * inside;
	float shade = (0.95 + 0.1 * noise(mp * 0.025)) * (0.97 + 0.06 * noise(mp * 0.2)) * (1.0 + relief * 0.2);
	shade = floor(shade * STEPS + dither) / STEPS;
	vec3 col = COLOR.rgb * shade;
	float high = step(dither, t.a * 0.6);
	col = mix(col, col * vec3(1.08, 1.06, 1.0), high);
	// The beach: sand up to a stepped edge, a dithered band where it thins into grass.
	float shore = 1.0 - smoothstep(0.62, 0.86, t.r);
	col = mix(col, beach.rgb, step(dither * 0.7 + 0.15, shore) * 0.8);
	COLOR = vec4(col, 1.0);
}
