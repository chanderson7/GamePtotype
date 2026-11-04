// The battle's grade over the field (under the HUD): colour drained toward grey, for a
// paused or a lost battle.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float grey = 0.0;
uniform float dim = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), grey);
	c *= 1.0 - dim;
	COLOR = vec4(c, 1.0);
}
