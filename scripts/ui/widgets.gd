## Shared screen pieces: number tiles, a tab bar, titled cards and a bottom bar that stays
## in thumb reach. Settlement, Warband and the map's sheets use them so the game reads
## as one thing.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")

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
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 72)
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		var on: bool = t["id"] == current
		var flat := Style.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 14)
		var lit := Style.box(Style.RAISED, Style.PLAYER_LIGHT.darkened(0.5), 2, 14)
		lit.border_width_bottom = 4
		lit.border_color = Style.PLAYER_LIGHT.darkened(0.5)
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(state, lit if on else flat)
		var ink := Style.TEXT if on else (Style.BRASS if badge > 0 else Style.MUTED)
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
static func card(parent: Control, title: String, aside: String = "", aside_color: Color = Style.MUTED) -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 20)
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
		var t := Style.label(title.to_upper(), Style.SMALL, Style.MUTED)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if aside != "":
			head.add_child(Style.label(aside, Style.SMALL, aside_color))
	return v


## A bar along the bottom of the screen holding one big button, above the safe area.
static func bottom_bar(button: Button, insets: Dictionary, bar_name: String = "BottomBar") -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = bar_name
	var box := Style.box(Style.NIGHT, Style.RULE, 0, 0)
	box.border_width_top = 2
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 14
	box.content_margin_bottom = 14 + float(insets.get("bottom", 0))
	bar.add_theme_stylebox_override("panel", box)
	button.custom_minimum_size = Vector2(0, 92)
	button.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE))
	bar.add_child(button)
	return bar


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
