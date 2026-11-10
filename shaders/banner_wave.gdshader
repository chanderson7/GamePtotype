// A banner's cloth in the wind. The cloth is drawn flat into a texture; here its rows (or
// columns) shift with a wave that travels away from where it is held and grows toward the
// free edge, and the folds catch a little light. Nothing moves at the held edge.
shader_type canvas_item;

// 0: held along the left edge (a staff); 1: held along the top (a crossbar).
uniform int held = 0;
// How far the free edge swings, in UV, and how many folds run across the cloth.
uniform float amp = 0.035;
uniform float folds = 7.0;
uniform float speed = 2.6;
// The empty margin around the cloth in the texture, in UV, so the swing stays inside it.
uniform float margin = 0.08;

void fragment() {
	float along = held == 1 ? UV.y : UV.x;
	float u = clamp((along - margin) / (1.0 - 2.0 * margin), 0.0, 1.0);
	float phase = TIME * speed - along * folds;
	float d = sin(phase) * amp * u;
	vec2 uv = held == 1 ? vec2(UV.x + d, UV.y) : vec2(UV.x, UV.y + d);
	vec4 c = texture(TEXTURE, uv);
	c.rgb *= 1.0 + cos(phase) * 0.09 * u;
	COLOR = c;
}
