## Small motions for the menus: things rising in, popping, pulsing, catching the light.
## Each is cosmetic, bound to the node it moves (it ends when the node goes), and does
## nothing under Reduced motion, leaving the node exactly as it would be at rest.
## Motion inside a container uses scale, rotation and modulate, never position, which the
## container owns; a shake is the one exception and puts the node back where it was.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")


static func on() -> bool:
	return not Style.motion_reduced()


## Fade `node` up from a little smaller, after `delay`: arriving on a page.
static func rise(node: Control, delay: float = 0.0) -> void:
	if node == null or not on():
		return
	node.modulate.a = 0.0
	var t := node.create_tween()
	t.tween_interval(delay)
	t.tween_callback(func():
		node.pivot_offset = Vector2(node.size.x * 0.5, node.size.y)
		node.scale = Vector2(0.94, 0.94))
	t.set_parallel()
	t.chain().tween_property(node, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Rise each of `nodes` in turn, `step` seconds apart, after `delay`.
static func stagger(nodes: Array, step: float = 0.045, delay: float = 0.0) -> void:
	for i in nodes.size():
		if nodes[i] is Control:
			rise(nodes[i], delay + step * mini(i, 14))


## A quick swell and settle: a count that went up, a rank reached.
static func pop(node: Control, size: float = 1.45, delay: float = 0.0) -> void:
	if node == null or not on():
		return
	var t := node.create_tween()
	t.tween_interval(delay)
	t.tween_callback(func(): node.pivot_offset = node.size * 0.5)
	t.tween_property(node, "scale", Vector2(size, size), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A ring of `color` bursting out of `node` and fading: something just earned.
static func ring(node: Control, color: Color = Style.BRASS, delay: float = 0.0, round_shape: bool = true) -> void:
	if node == null or not on():
		return
	var burst := Control.new()
	burst.name = "Ring"
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	burst.set_meta("k", 0.0)
	burst.draw.connect(func():
		var k := float(burst.get_meta("k", 0.0))
		if k <= 0.0 or k >= 1.0:
			return
		var c := Color(color, 1.0 - k)
		var grow := 1.0 + k * 1.6
		if round_shape:
			var r := minf(burst.size.x, burst.size.y) * 0.5
			burst.draw_arc(burst.size * 0.5, r * grow, 0.0, TAU, 40, c, 3.0, true)
		else:
			var sz := burst.size * grow
			burst.draw_rect(Rect2((burst.size - sz) * 0.5, sz), c, false, 3.0))
	node.add_child(burst)
	var t := burst.create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float):
		burst.set_meta("k", v)
		burst.queue_redraw(), 0.0, 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(burst.queue_free)


## Swell and turn slightly, over and over: a clock running out.
static func pulse(node: Control, size: float = 1.2, period: float = 1.2) -> void:
	if node == null or not on():
		return
	var t := node.create_tween().set_loops()
	t.tween_callback(func(): node.pivot_offset = node.size * 0.5)
	t.set_parallel()
	t.chain().tween_property(node, "scale", Vector2(size, size), period * 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "rotation", deg_to_rad(-8.0), period * 0.5).set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(node, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "rotation", 0.0, period * 0.5).set_trans(Tween.TRANS_SINE)


## A band of light crossing `panel` now and then, under its words, inside its rounded
## shape: something waiting on you. `delay` staggers several panels.
static func sheen(panel: Control, delay: float = 0.0, every: float = 4.6, strength: float = 0.17) -> void:
	if panel == null or not on():
		return
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var band := Control.new()
	band.name = "Sheen"
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_meta("x", -1.0)
	band.draw.connect(func():
		var x := float(band.get_meta("x", -1.0))
		if x <= -0.99 or x >= 1.99:
			return
		# The band is drawn across the panel's whole box (it reaches past the content
		# area into the margins), and the panel's shape clips it.
		var r := Rect2(-band.position, panel.size)
		var w := r.size.x * 0.22
		var cx := r.position.x + r.size.x * x
		var slant := r.size.y * 0.35
		var clear := Color(1.0, 0.94, 0.75, 0.0)
		var lit := Color(1.0, 0.94, 0.75, strength)
		var top := r.position.y
		var bottom := r.end.y
		band.draw_polygon(PackedVector2Array([Vector2(cx - w + slant, top), Vector2(cx + slant, top), Vector2(cx, bottom), Vector2(cx - w, bottom)]),
			PackedColorArray([clear, lit, lit, clear]))
		band.draw_polygon(PackedVector2Array([Vector2(cx + slant, top), Vector2(cx + w + slant, top), Vector2(cx + w, bottom), Vector2(cx, bottom)]),
			PackedColorArray([lit, clear, clear, lit])))
	panel.add_child(band)
	panel.move_child(band, 0)
	var t := band.create_tween().set_loops()
	t.tween_interval(every * 0.55 + delay)
	t.tween_method(func(v: float):
		band.set_meta("x", v)
		band.queue_redraw(), -0.3, 1.3, every * 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		band.set_meta("x", -1.0)
		band.queue_redraw())
	t.tween_interval(every * 0.15)


## A soft ring going out from `node`'s middle, again and again: a talk is waiting.
static func ping(node: Control, color: Color = Style.BRASS, delay: float = 0.0) -> void:
	if node == null or not on():
		return
	var ring_node := Control.new()
	ring_node.name = "Ping"
	ring_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring_node.set_meta("k", 0.0)
	ring_node.draw.connect(func():
		var k := float(ring_node.get_meta("k", 0.0))
		if k <= 0.0 or k >= 0.7:
			return
		var r := minf(ring_node.size.x, ring_node.size.y) * 0.5
		ring_node.draw_arc(ring_node.size * 0.5, r * (1.0 + k * 2.0), 0.0, TAU, 32, Color(color, 0.9 * (1.0 - k / 0.7)), 2.0, true))
	node.add_child(ring_node)
	var t := ring_node.create_tween().set_loops()
	t.tween_interval(delay)
	t.tween_method(func(v: float):
		ring_node.set_meta("k", v)
		ring_node.queue_redraw(), 0.0, 1.0, 1.8)


## Shake `node` side to side once, then put it back: a warning arriving.
static func shake(node: Control, delay: float = 0.2) -> void:
	if node == null or not on():
		return
	var t := node.create_tween()
	t.tween_interval(delay)
	var home := [0.0]
	t.tween_callback(func(): home[0] = node.position.x)
	var last := 0.0
	for dx in [-9.0, 8.0, -5.0, 3.0, 0.0]:
		t.tween_method(func(v: float): node.position.x = home[0] + v, last, dx, 0.07)
		last = dx
	t.tween_callback(func(): node.position.x = home[0])


## Fold `node` away (fade and flatten toward its top), then call `done`; at once under
## Reduced motion.
static func fold(node: Control, done: Callable) -> void:
	if node == null or not on():
		done.call()
		return
	node.pivot_offset = Vector2(node.size.x * 0.5, 0.0)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "modulate:a", 0.0, 0.2)
	t.tween_property(node, "scale", Vector2(0.98, 0.2), 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(done)


## Fill a Widgets.meter from `from` to its own fill, after `delay`.
static func grow(meter: Control, from: float = 0.0, delay: float = 0.0, time: float = 0.65) -> void:
	if meter == null or not on():
		return
	var to := float(meter.get_meta("frac", 0.0))
	if is_equal_approx(from, to):
		return
	meter.set_meta("shown", from)
	meter.queue_redraw()
	var t := meter.create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float):
		meter.set_meta("shown", v)
		meter.queue_redraw(), from, to, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Tween a Button's icon colour between `a` and `b`, over and over: a flame on a tab.
static func flicker_icon(button: Button, a: Color, b: Color, period: float = 1.1) -> void:
	if button == null or not on():
		return
	var prop := "theme_override_colors/icon_normal_color"
	var t := button.create_tween().set_loops()
	t.tween_property(button, prop, b, period * 0.45).set_trans(Tween.TRANS_SINE)
	t.tween_property(button, prop, a, period * 0.55).set_trans(Tween.TRANS_SINE)


## A lit candle, `height` tall, its flame swaying and breathing; still under Reduced motion.
static func candle(height: float = 62.0) -> Control:
	var c := Control.new()
	c.name = "Candle"
	c.custom_minimum_size = Vector2(height * 0.42, height)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("t", 0.0)
	c.draw.connect(func():
		var t := float(c.get_meta("t", 0.0))
		var w := c.size.x
		var h := c.size.y
		var stick := Rect2(w * 0.3, h * 0.55, w * 0.4, h * 0.45)
		c.draw_rect(stick, Color("d8cfb8"))
		c.draw_rect(Rect2(stick.position, Vector2(stick.size.x * 0.35, stick.size.y)), Color("b9ad92"))
		var sway := sin(t * 7.3) * 0.6 + sin(t * 12.1) * 0.4
		var tall := 1.0 + (sin(t * 9.7) * 0.06 if on() else 0.0)
		var base := Vector2(w * 0.5, stick.position.y - 1.0)
		var tip := base + Vector2(sway * w * 0.08 if on() else 0.0, -h * 0.38 * tall)
		# The glow, then the flame: a drop, wide low and pointed at the top.
		for i in 3:
			var r := h * (0.34 - i * 0.08)
			c.draw_circle(base + Vector2(0, -h * 0.14), r, Color(1.0, 0.72, 0.25, 0.05 + 0.03 * i))
		var flame := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			flame.append(base + Vector2(cos(a) * w * 0.3, -sin(a) * w * 0.22))
		flame.append(tip)
		c.draw_colored_polygon(flame, Color("f3b63f"))
		var core := PackedVector2Array()
		for p in flame:
			core.append(base + (p - base) * 0.55)
		c.draw_colored_polygon(core, Color("fff6d0")))
	if on():
		var tw := c.create_tween().set_loops()
		tw.tween_method(func(v: float):
			c.set_meta("t", v)
			c.queue_redraw(), 0.0, TAU * 4.0, TAU * 4.0 / 7.0)
	return c
