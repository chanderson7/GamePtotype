// A painted portrait, moved without repainting it: the head tilts and nods on a neck that
// gives, and loose hair swings. Lengths are in the painting's own pixels. Every move is 0
// at rest, so with nothing set the painting is drawn exactly as it is.
shader_type canvas_item;

uniform vec2 picture = vec2(384.0, 512.0);
// Above `chin` the head moves whole; by `collar` nothing moves; the neck bends between.
uniform float chin = 226.0;
uniform float collar = 260.0;
// What the head turns about (the base of the neck).
uniform vec2 pivot = vec2(186.0, 252.0);
// The front of the face (where it's nearest the viewer) and how far the head reaches from
// there: toward the far cheek, the back of the head, up, down. A nod moves the front of
// the face more than the edge of the head, which is what makes it a turn and not a slide.
uniform vec2 front = vec2(150.0, 172.0);
uniform vec4 reach = vec4(70.0, 80.0, 95.0, 75.0);
// How freely each pixel of loose hair swings (white: most), from tools/portrait_faces.py.
uniform sampler2D hair : filter_linear, hint_default_black;

uniform float tilt = 0.0;   // degrees
uniform float drop = 0.0;   // pixels the head sinks
uniform float pitch = 0.0;  // pixels the front of the face turns down
uniform float sway = 0.0;   // pixels at the tips of loose hair

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float nearness(vec2 r) {
	vec2 d = r - front;
	float rx = d.x < 0.0 ? -d.x / reach.x : d.x / reach.y;
	float ry = d.y < 0.0 ? -d.y / reach.z : d.y / reach.w;
	float n = clamp(1.0 - rx * rx - ry * ry, 0.0, 1.0);
	return n * n;
}

void fragment() {
	vec2 p = UV * picture;
	float held = 1.0 - smoothstep(chin, collar, p.y);
	float th = radians(-tilt);
	vec2 d = p - pivot;
	vec2 r = pivot + vec2(d.x * cos(th) - d.y * sin(th), d.x * sin(th) + d.y * cos(th) - drop);
	r.y -= pitch * nearness(r);
	vec2 s = p + (r - p) * held;
	s.x -= sway * texture(hair, UV).r;
	COLOR = texture(TEXTURE, clamp(s / picture, vec2(0.0), vec2(1.0))) * tint;
}
