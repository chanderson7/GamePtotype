## Shared screen pieces: number tiles, a tab bar, titled cards and a bottom bar that stays
## in thumb reach. Settlement, Warband and the map's sheets use them so the game reads
## as one thing.
##
## The rules every screen follows (docs/ui-simplification-plan.md):
## - A number that recurs has an icon, and the icon replaces its word: silver, rations,
##   men, wounded, renown, morale, speed, Regard (`bond`), days (`day`), hours (`clock`).
## - A status is a chip with a shape: ▲ good, ◆ middling, ▼ bad, so it reads without
##   colour; an icon where one exists. Never a coloured word alone.
## - A person is a face; a realm is a banner. A name or realm in text beside its picture
##   is a duplicate.
## - A sentence with two or more numbers is tiles or a chip row.
## - A button is a verb, three words at most. Its cost sits under it (`priced`), and the
##   reason it is greyed sits in a muted line under the row, never in a tooltip.
## - Say it once. A fact on a picture (a badge, a meter, a field mark) is not also a line.
## - Nothing a player reads is under Style.SMALL, and every size goes through
##   Style.text_size.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")

const ICONS := {
	"silver": "res://assets/ui/silver.svg",
	"food": "res://assets/ui/food.svg",
	"renown": "res://assets/ui/renown.svg",
	"men": "res://assets/ui/men.svg",
	"speed": "res://assets/ui/speed.svg",
	"morale": "res://assets/ui/morale.svg",
	"wounded": "res://assets/ui/wounded.svg",
	"battle": "res://assets/ui/battle.svg",
}

static var _icons: Dictionary = {}


## One of the game's small icons, loaded from its SVG (directly, if the editor's import
## cache isn't there, as on a fresh headless checkout).
static func icon(key: String) -> Texture2D:
	if _icons.has(key):
		return _icons[key]
	# The order and siege icons are o_<key>.svg.
	var path := String(ICONS.get(key, "res://assets/ui/o_%s.svg" % key))
	var tex: Texture2D = null
	if path != "":
		if ResourceLoader.exists(path, "Texture2D"):
			tex = load(path) as Texture2D
		elif FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func icon_rect(key: String, size: float = 40.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(key)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A tile: an icon, a big number and a line under it.
static func tile(key: String, value: String, sub: String, tone: Color = Style.TEXT) -> PanelContainer:
	var t := PanelContainer.new()
	t.name = "Tile_%s" % key
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	t.add_child(h)
	h.add_child(icon_rect(key, 40.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var big := Style.label(value, Style.LARGE, tone)
	big.name = "Value"
	v.add_child(big)
	v.add_child(Style.label(sub, Style.SMALL, Style.MUTED))
	return t


## Tiles in rows of `per_row`.
static func tile_grid(tiles: Array, per_row: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = per_row
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for t in tiles:
		g.add_child(t)
	return g


static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## A segmented tab bar. `tabs` is [{id, label, badge}]; tapping calls on_tab(id). The lit
## tab carries a brass underline that slides across when it changes.
static func tab_bar(tabs: Array, current: String, on_tab: Callable, bar_name: String = "Tabs") -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = bar_name
	var box := Style.box(Style.PANEL, Style.RULE, 2, 18)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for t in tabs:
		var b := Button.new()
		b.name = "Tab_%s" % t["id"]
		var badge := int(t.get("badge", 0))
		b.text = String(t["label"]) + ("  %d" % badge if badge > 0 else "")
		var tab_icon := String(t.get("icon", ""))
		if tab_icon != "":
			b.icon = icon(tab_icon)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 30)
			b.add_theme_constant_override("h_separation", 8)
			if String(t["label"]) == "":
				b.tooltip_text = String(t.get("tip", t["id"]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		var on: bool = t["id"] == current
		# A gold tab: something on there (a feast), lit in brass.
		var gold := bool(t.get("gold", false))
		var flat := Style.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 14)
		var lit := Style.box(Color("33290f") if gold else Style.RAISED, Style.BRASS if gold else Style.PLAYER_LIGHT.darkened(0.5), 2, 14)
		lit.border_width_bottom = 4
		lit.border_color = Style.BRASS if gold else Style.PLAYER_LIGHT.darkened(0.5)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, lit if on else flat)
		var ink := (Color("f3d891") if gold else Style.TEXT) if on else (Style.BRASS if badge > 0 or gold else Style.MUTED)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, ink)
		b.pressed.connect(on_tab.bind(String(t["id"])))
		row.add_child(b)
		if on and not Style.motion_reduced():
			# The lit tab settles in: a quick fade and lift.
			b.modulate.a = 0.6
			b.create_tween().tween_property(b, "modulate:a", 1.0, 0.16)
	return bar


## A titled card, with an optional note on the right of the title. Returns the column to
## fill; the card itself is its parent's parent.
## A gold card is something waiting on you: a feast, a promotion, a moment in camp.
static func card(parent: Control, title: String, aside: String = "", aside_color: Color = Style.MUTED, gold: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := Style.box(Color("221d10") if gold else Style.PANEL, Style.BRASS if gold else Style.RULE, 2, 20)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	if title != "" or aside != "":
		var head := HBoxContainer.new()
		v.add_child(head)
		var t := Style.label(title.to_upper(), Style.SMALL, Style.BRASS if gold else Style.MUTED)
		t.name = "CardTitle"
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if aside != "":
			var a := Style.label(aside, Style.SMALL, aside_color)
			a.name = "CardAside"
			head.add_child(a)
	return v


## A bar along the bottom of the screen, above the safe area. `buttons` is one Button or
## an Array of them: Back (if any) on the left, the primary last, on the right and wider.
static func bottom_bar(buttons, insets: Dictionary, bar_name: String = "BottomBar") -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = bar_name
	var box := Style.box(Style.NIGHT, Style.RULE, 0, 0)
	box.border_width_top = 2
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 14
	box.content_margin_bottom = 14 + float(insets.get("bottom", 0))
	bar.add_theme_stylebox_override("panel", box)
	var list: Array = buttons if buttons is Array else [buttons]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)
	for i in list.size():
		var b: Button = list[i]
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 2.0 if list.size() > 1 and i == list.size() - 1 else 1.0
		b.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE))
		row.add_child(b)
	return bar


## The one Back button: the back arrow and a word, never brass.
static func back_button(callback: Callable, label: String = "Back", button_name: String = "Back") -> Button:
	var b := Button.new()
	b.name = button_name
	b.text = label
	b.icon = icon("back")
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.add_theme_constant_override("icon_max_width", 34)
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, Style.MUTED)
	b.pressed.connect(callback)
	return b


## A number on a tile counting to its new value, so a purchase is felt as well as seen.
static func tick_to(label: Label, from: int, to: int, fmt: Callable) -> void:
	if label == null or from == to or Style.motion_reduced():
		if label != null:
			label.text = fmt.call(to)
		return
	label.text = fmt.call(from)
	var t := label.create_tween()
	t.tween_method(func(v: float): label.text = fmt.call(int(round(v))), float(from), float(to), 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var flash := label.get_theme_color("font_color")
	label.add_theme_color_override("font_color", Style.BRASS)
	t.tween_callback(func(): label.add_theme_color_override("font_color", flash))


## A realm's banner on its pole, sized to fit `size`.
static func banner(realm: String, size: Vector2) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func(): Heraldry.realm_banner(c, realm if Heraldry.REALM_SIZES.has(realm) else "bandits", Rect2(Vector2.ZERO, size)))
	return c


## A portrait in an arched brass frame. `pic` fills the arch and is cropped to it;
## `overhang` lets the picture run past the bottom edge (a share of the height), which
## lifts a painted face into the arch.
static func framed(pic: TextureRect, size: Vector2, dim: bool = false, overhang: float = 0.12) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := Panel.new()
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arch := StyleBoxFlat.new()
	arch.bg_color = Color("1a2138")
	arch.corner_radius_top_left = int(size.x * 0.5)
	arch.corner_radius_top_right = int(size.x * 0.5)
	arch.corner_radius_bottom_left = 12
	arch.corner_radius_bottom_right = 12
	arch.corner_detail = 12
	mask.add_theme_stylebox_override("panel", arch)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	holder.add_child(mask)
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_bottom = size.y * overhang
	if dim:
		pic.modulate = Color(0.62, 0.62, 0.68)
	mask.add_child(pic)
	var rim := Panel.new()
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := arch.duplicate() as StyleBoxFlat
	edge.draw_center = false
	edge.border_color = Color("6a5226")
	edge.set_border_width_all(3)
	rim.add_theme_stylebox_override("panel", edge)
	holder.add_child(rim)
	return holder


## How far a finger may move between press and release and still count as a tap, in
## viewport units. It matches gui/common/default_scroll_deadzone in project.godot: past
## it, the page under the finger scrolls instead.
const TAP_SLOP := 16.0


## Make `control` call `action` when tapped, without stopping the page from scrolling
## when a drag starts on it: the touch passes on to the page, and a release counts as a
## tap only if the finger hardly moved since the press.
static func on_tap(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.gui_input.connect(func(e: InputEvent):
		var mb := e as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			control.set_meta("tap_from", mb.global_position)
		elif control.has_meta("tap_from"):
			var from: Vector2 = control.get_meta("tap_from")
			control.remove_meta("tap_from")
			if from.distance_to(mb.global_position) <= TAP_SLOP:
				action.call())


## A thin bar filled to `frac` (0 to 1) in `color`, on a dark track. `marks` are
## fractions where a thin notch is drawn (a rank threshold, a need line).
static func meter(frac: float, color: Color, height: float = 14.0, marks: Array = []) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(40, height)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_style_box(Style.box(Style.NIGHT, Style.RULE, 2, int(height / 2)), Rect2(Vector2.ZERO, c.size))
		var w := maxf(height, (c.size.x - 4.0) * clampf(frac, 0.0, 1.0))
		if frac > 0.0:
			c.draw_style_box(Style.box(color, Color(0, 0, 0, 0), 0, int(height / 2)), Rect2(Vector2(2, 2), Vector2(w, c.size.y - 4.0)))
		for m in marks:
			var x := 2.0 + (c.size.x - 4.0) * clampf(float(m), 0.0, 1.0)
			c.draw_line(Vector2(x, -2.0), Vector2(x, c.size.y + 2.0), Style.TEXT, 2.0))
	c.set_meta("frac", frac)
	return c


## A small rounded chip and its text. A status chip leads with a shape in `tone` (▲ good,
## ◆ middling, ▼ bad, so it reads without colour); a quantity chip leads with its icon
## instead (`icon_key`, tinted `tone` unless tone is plain TEXT). A gold chip is an honour
## or something waiting: a promotion, a feast, a crown.
static func chip(text: String, tone: Color, shape: String = "", icon_key: String = "", gold: bool = false) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := Style.box(Color("33290f") if gold else Style.RAISED, Style.BRASS if gold else Style.RULE, 2, 40)
	sb.content_margin_left = 12 if icon_key != "" else 14
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	panel.add_child(h)
	if icon_key != "":
		var ic := icon_rect(icon_key, 28.0)
		ic.name = "Icon"
		if tone != Style.TEXT:
			ic.modulate = tone
		h.add_child(ic)
	if shape != "" or icon_key == "":
		if shape == "":
			shape = "▲" if tone == Style.MORALE_HIGH else ("◆" if tone == Style.MORALE_MID else "▼")
		var mark := Style.label(shape, Style.SMALL, tone)
		mark.name = "Shape"
		h.add_child(mark)
	if text != "":
		var t := Style.label(text, Style.SMALL, Color("f3d891") if gold else Style.TEXT)
		t.name = "Text"
		h.add_child(t)
	return panel


## A quantity with its icon and no word: silver 150, men 12/12, a clock and "8 h".
static func stat(key: String, text: String, tone: Color = Style.TEXT) -> PanelContainer:
	var c := chip(text, Style.TEXT, "", key)
	c.name = "Stat_%s" % key
	if tone != Style.TEXT:
		(c.get_child(0).get_node("Text") as Label).add_theme_color_override("font_color", tone)
	return c


## What a choice does to a number: the icon and a signed amount, green up and red down.
## `suffix` follows the number ("/day").
static func effect(key: String, amount: int, suffix: String = "") -> PanelContainer:
	var tone := Style.MORALE_HIGH if amount > 0 else (Style.ENEMY_LIGHT if amount < 0 else Style.MUTED)
	var c := stat(key, "%s%s%s" % ["+" if amount > 0 else ("−" if amount < 0 else ""), thousands(absi(amount)), suffix], tone)
	c.name = "Effect_%s" % key
	return c


## An icon and a number inline, with no chip around them: a cost under a button, a line
## of figures in a row.
static func icon_value(key: String, text: String, tone: Color = Style.TEXT, size: int = Style.SMALL) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "Value_%s" % key
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon_rect(key, 26.0 if size <= Style.SMALL else 32.0))
	var l := Style.label(text, size, tone)
	l.name = "Text"
	h.add_child(l)
	return h


## A verb button with its cost under it: "Hire" over silver 180. `costs` is [[key, text]]
## or [[key, text, tone]]. Returns the column; the button is its first child.
static func priced(button: Button, costs: Array, why_not: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "%sPriced" % button.name
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = button.size_flags_horizontal
	v.size_flags_stretch_ratio = button.size_flags_stretch_ratio
	if button.custom_minimum_size.y < Style.TOUCH:
		button.custom_minimum_size.y = Style.TOUCH
	v.add_child(button)
	if not costs.is_empty():
		var row := HBoxContainer.new()
		row.name = "Cost"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		for c in costs:
			var tone: Color = c[2] if c.size() > 2 else (Style.MUTED if button.disabled else Style.TEXT)
			row.add_child(icon_value(String(c[0]), String(c[1]), tone))
		v.add_child(row)
	if why_not != "" and button.disabled:
		var l := Style.label(why_not, Style.SMALL, Style.MUTED)
		l.name = "WhyNot"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v


## A small number in a red circle: unread letters, people waiting. Hidden at zero.
static func count_badge(n: int, badge_name: String = "Badge") -> PanelContainer:
	var p := PanelContainer.new()
	p.name = badge_name
	var sb := Style.box(Style.ENEMY, Style.NIGHT, 2, 20)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Style.label(str(n) if n < 100 else "99+", Style.SMALL, Color.WHITE)
	l.name = "Count"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.visible = n > 0
	return p


## A rank: the letter in a brass ring (C, B, A).
static func rank_badge(letter: String, size: float = 44.0) -> Control:
	var c := Control.new()
	c.name = "Rank_%s" % letter
	c.custom_minimum_size = Vector2(size, size)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = "Rank %s" % letter
	var font_size := Style.text_size(Style.SMALL if size < 52.0 else Style.BODY)
	c.draw.connect(func():
		var r := minf(c.size.x, c.size.y) / 2.0
		var mid := c.size / 2.0
		c.draw_circle(mid, r, Color("33290f"))
		c.draw_arc(mid, r - 1.5, 0.0, TAU, 32, Style.BRASS, 3.0, true)
		var font := c.get_theme_default_font()
		var w := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		c.draw_string(font, Vector2(mid.x - w / 2.0, mid.y + font_size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f3d891")))
	return c


## A choice drawn as a tile: a big icon over its word, brass-edged when lit.
static func icon_tile(key: String, label: String, lit: bool, callback: Callable, tile_name: String = "") -> Button:
	var b := Button.new()
	b.name = tile_name if tile_name != "" else "IconTile_%s" % key
	b.text = label
	b.icon = icon(key)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.add_theme_constant_override("icon_max_width", 48)
	b.custom_minimum_size = Vector2(120, 116)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	if lit:
		for state in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(state, Style.box(Color("33290f"), Style.BRASS, 3))
		for c in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
			b.add_theme_color_override(c, Style.BRASS)
	b.pressed.connect(callback)
	return b


## A square button that is only an icon (the info "i", a close ✕, a talk bubble). The
## word goes in the tooltip.
static func icon_button(key: String, callback: Callable, tip: String, button_name: String = "", size: float = Style.TOUCH) -> Button:
	var b := Button.new()
	b.name = button_name if button_name != "" else "IconButton_%s" % key
	b.icon = icon(key)
	b.tooltip_text = tip
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(size * 0.5))
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(callback)
	return b


## A number over its cap with a meter under it: rations in a granary, men in a garrison.
## `gain` is the muted line under the number; `full_text` replaces it, in red, at the cap.
static func store_tile(tile_name: String, key: String, have: int, cap: int, gain: String, full_text: String = "") -> PanelContainer:
	var t := PanelContainer.new()
	t.name = tile_name
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Style.box(Style.NIGHT, Style.RULE, 2, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	t.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	t.add_child(v)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	v.add_child(line)
	if key != "":
		line.add_child(icon_rect(key, 34.0))
	var big := Style.label(thousands(have), Style.LARGE, Style.TEXT)
	big.name = "Value"
	line.add_child(big)
	var of := Style.label("/ %s" % thousands(cap), Style.SMALL, Style.MUTED)
	of.name = "Cap"
	of.size_flags_vertical = Control.SIZE_SHRINK_END
	line.add_child(of)
	var full := have >= cap and full_text != ""
	var note := Style.label(full_text if full else gain, Style.SMALL, Style.ENEMY_LIGHT if full else Style.MUTED)
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.visible = note.text != ""
	v.add_child(note)
	v.add_child(meter(float(have) / maxf(1.0, float(cap)), Style.MORALE_LOW if full else Style.BRASS, 12.0))
	return t


## A bottom sheet over `host`: a shade that closes it when tapped, a grip, a title with
## one ✕, and the column this returns to fill. It scrolls when taller than most of the
## screen. Close it with `close_sheet(column)`; `on_close` runs when it goes.
static func sheet(host: Control, title: String, sheet_name: String = "Sheet", on_close: Callable = Callable()) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.name = sheet_name
	shade.color = Color(0.012, 0.02, 0.04, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(shade)
	var close := func():
		if is_instance_valid(shade) and not shade.is_queued_for_deletion():
			shade.queue_free()
			if on_close.is_valid():
				on_close.call()
	shade.set_meta("close", close)
	shade.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			close.call())
	var panel := PanelContainer.new()
	panel.name = "SheetPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := Style.box(Style.PANEL.lightened(0.02), Style.RULE, 2, 28)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 14
	sb.content_margin_bottom = 32 + float(Style.safe_insets(host.get_viewport())["bottom"]) if host.is_inside_tree() else 32.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)
	var grip := Panel.new()
	grip.custom_minimum_size = Vector2(80, 8)
	grip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grip.add_theme_stylebox_override("panel", Style.box(Style.RULE, Color(0, 0, 0, 0), 0, 4))
	outer.add_child(grip)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	outer.add_child(head)
	var t := Style.label(title, Style.TITLE_SIZE if title.length() <= 18 else Style.LARGE, Style.BRASS)
	t.name = "SheetTitle"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(t)
	var x := icon_button("cancel", close, "Close", "CloseSheet")
	head.add_child(x)
	var scroll := ScrollContainer.new()
	scroll.name = "SheetScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.name = "SheetBody"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	col.set_meta("close", close)
	# Grow with the content up to three quarters of the screen, then scroll.
	col.resized.connect(func():
		if is_instance_valid(scroll) and host.is_inside_tree():
			scroll.custom_minimum_size.y = minf(col.get_combined_minimum_size().y, host.get_viewport_rect().size.y * 0.72))
	if host.is_inside_tree():
		Style.ease_in(panel)
	return col


## Close the sheet that holds `node` (any node inside it, or its shade).
static func close_sheet(node: Node) -> void:
	var n := node
	while n != null:
		if n.has_meta("close"):
			(n.get_meta("close") as Callable).call()
			return
		n = n.get_parent()


## A row of chips that wraps.
static func chip_row(chips: Array) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	for c in chips:
		row.add_child(c)
	return row


## A small grey heading in capitals, for sections within a card or sheet.
static func section(text: String) -> Label:
	var l := Style.label(text.to_upper(), Style.SMALL, Style.MUTED)
	return l


## An on/off switch: brass with the knob right when on. `on_toggle` gets the new state.
static func switch(on: bool, on_toggle: Callable, switch_name: String = "Switch", word: String = "") -> Button:
	var b := Button.new()
	b.name = switch_name
	# The words ("Music: on") are there for screen readers and tests, drawn invisibly.
	if word != "":
		b.text = "%s: %s" % [word, "on" if on else "off"]
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color(0, 0, 0, 0))
		b.add_theme_font_size_override("font_size", 1)
	b.toggle_mode = true
	b.button_pressed = on
	b.custom_minimum_size = Vector2(96, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, clear)
	b.add_theme_stylebox_override("focus", Style.box(Color(0, 0, 0, 0), Style.BRASS, 2, 28))
	b.draw.connect(func():
		var lit := b.button_pressed
		var track := Rect2(Vector2(4, 6), b.size - Vector2(8, 12))
		b.draw_style_box(Style.box(Color("c9a046") if lit else Color("2a3458"), Color(0, 0, 0, 0), 0, int(track.size.y / 2)), track)
		var r := track.size.y / 2.0 - 4.0
		var cx := track.end.x - r - 4.0 if lit else track.position.x + r + 4.0
		b.draw_circle(Vector2(cx, track.get_center().y), r, Style.TEXT))
	b.toggled.connect(func(state: bool):
		if word != "":
			b.text = "%s: %s" % [word, "on" if state else "off"]
		b.queue_redraw()
		on_toggle.call(state))
	return b


## A row of choices where one is picked, like a set of radio buttons drawn as one bar.
## `on_pick` gets the picked index.
## `icons` puts an icon on each option; an option whose label is "" is icon-only.
static func segmented(options: Array, current: int, on_pick: Callable, bar_name: String = "Segments", icons: Array = []) -> PanelContainer:
	var tabs := []
	for i in options.size():
		var t := {"id": str(i), "label": String(options[i])}
		if i < icons.size() and String(icons[i]) != "":
			t["icon"] = String(icons[i])
		tabs.append(t)
	var bar := tab_bar(tabs, str(current), func(id: String): on_pick.call(int(id)), bar_name)
	bar.set_meta("picked", current)
	return bar
