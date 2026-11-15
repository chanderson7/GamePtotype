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
## tab carries a brass underline that slides across when it changes. Each tab is a full
## touch target; its words grow with the text setting as far as they fit, then wrap onto
## a second line (the bar grows taller) rather than being cut short. Under a mouse an unlit
## tab lights faintly, and a keyboard's focus shows as a brass ring.
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
	var line_color := Style.PLAYER_LIGHT.darkened(0.5)
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
		# With the text set bigger, a tab with a long word ("Companies") takes more of the
		# row than its short neighbours, so the word keeps its size (at the plain size the
		# tabs are even).
		var longest := 0
		for word in String(t["label"]).split(" ", false):
			longest = maxi(longest, word.length())
		if Style.text_size(Style.SMALL) > Style.SMALL:
			b.size_flags_stretch_ratio = 1.0 + 0.15 * maxi(0, longest - 6)
		b.custom_minimum_size = Vector2(0, Style.TOUCH)
		# Tabs share one row: the words take the full text size where they fit, shrink no
		# further than they used to (_fit_tab_words), and then wrap between words; a word
		# too long for its tab shrinks as far as the plain text size before it would break.
		# Never "…".
		b.set_meta("font_full", Style.text_size(Style.SMALL))
		b.set_meta("font_least", mini(Style.text_size(Style.SMALL), roundi(Style.SMALL * 1.15)))
		b.set_meta("font_floor", mini(Style.text_size(Style.SMALL), Style.SMALL))
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		var on: bool = t["id"] == current
		# A gold tab: something on there (a feast), lit in brass.
		var gold := bool(t.get("gold", false))
		var flat := Style.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 14)
		var lit := Style.box(Color("33290f") if gold else Style.RAISED, Style.BRASS if gold else Style.PLAYER_LIGHT.darkened(0.5), 2, 14)
		if on:
			line_color = Style.BRASS if gold else Style.PLAYER_LIGHT.darkened(0.5)
		var hover := Style.box(Color(Style.RAISED, 0.55), Color(0, 0, 0, 0), 0, 14)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, lit if on else (hover if state.begins_with("hover") else flat))
		b.add_theme_stylebox_override("focus", Style.box(Color(0, 0, 0, 0), Color(Style.BRASS, 0.7), 2, 14))
		var ink := (Color("f3d891") if gold else Style.TEXT) if on else (Style.BRASS if badge > 0 or gold else Style.MUTED)
		for c in ["font_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, ink)
		b.add_theme_color_override("font_hover_color", ink if on or badge > 0 or gold else Style.TEXT)
		b.pressed.connect(on_tab.bind(String(t["id"])))
		row.add_child(b)
	row.sort_children.connect(func(): _fit_tab_words(row))
	_tab_turn(bar, row, tabs, current, bar_name, line_color)
	return bar


## Each tab's words on one line, at the biggest size (up to its "font_full") that fits,
## but no smaller than its "font_least". If they can't share a line they wrap between
## words, each at the biggest size at which every word fits whole, down to "font_floor"
## (the plain text size); only a word too long even then breaks.
static func _fit_tab_words(row: HBoxContainer) -> void:
	if not is_instance_valid(row):
		return
	for c in row.get_children():
		var b := c as Button
		if b == null or b.size.x <= 0.0:
			continue
		var font := b.get_theme_font("font")
		var full := int(b.get_meta("font_full", Style.text_size(Style.SMALL)))
		var least := int(b.get_meta("font_least", full))
		var floor_size := mini(least, int(b.get_meta("font_floor", least)))
		# 10 px to spare: on a phone's screen the glyphs can lay out a few pixels wider than
		# measured here, enough to push a last letter onto a line of its own.
		var room := b.size.x - 28.0 - (38.0 if b.icon != null else 0.0) - 10.0
		var fits := full
		if font != null:
			var line := full
			while line > least and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line).x > room:
				line -= 1
			if font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, line).x <= room:
				fits = line
			else:
				for word in b.text.split(" ", false):
					while fits > floor_size and font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fits).x > room:
						fits -= 1
		if b.get_theme_font_size("font_size") != fits:
			b.add_theme_font_size_override("font_size", fits)


## Where each tab bar's underline last sat, and when, keyed by the bar and its tabs, so a
## bar rebuilt by a tap can slide it on from there: {key: {x, w, id, at}}.
static var _tab_last := {}
## A rebuild this soon after the last is the same page turning, not a fresh visit.
const TAB_TURN_WINDOW := 1500
const TAB_SLIDE := 0.2
const TAB_FADE := 0.18


## The lit tab's underline slides over from the tab it left, and the page under the bar
## (everything after it in its column) fades up, when the bar is rebuilt by a tab change.
## Arriving on a screen, the line is simply there.
static func _tab_turn(bar: PanelContainer, row: HBoxContainer, tabs: Array, current: String, bar_name: String, line_color: Color) -> void:
	var ids := PackedStringArray()
	for t in tabs:
		ids.append(String(t["id"]))
	var key := "%s|%s" % [bar_name, ",".join(ids)]
	var last: Dictionary = _tab_last.get(key, {})
	var now := Time.get_ticks_msec()
	var turning: bool = not last.is_empty() and String(last.get("id", "")) != current \
		and now - int(last.get("at", 0)) < TAB_TURN_WINDOW and not Style.motion_reduced()
	var line := Control.new()
	line.name = "TabLine"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(line)
	# The line runs from where it was (`from`) to the lit tab (`to`, kept current as the row
	# lays out) by `k`, 0 to 1.
	var at := {"from": Vector2(float(last.get("x", -1.0)), float(last.get("w", 0.0))), "to": Vector2(-1.0, 0.0), "k": 0.0 if turning else 1.0}
	line.draw.connect(func():
		var to: Vector2 = at["to"]
		if to.y <= 0.0:
			return
		var from: Vector2 = at["from"] if Vector2(at["from"]).y > 0.0 else to
		var r: Vector2 = from.lerp(to, float(at["k"]))
		line.draw_rect(Rect2(r.x, line.size.y - 4.0, r.y, 4.0), line_color))
	row.sort_children.connect(func():
		var lit := row.get_node_or_null("Tab_%s" % current) as Control
		if lit == null or not is_instance_valid(line):
			return
		at["to"] = Vector2(lit.position.x + 10.0, maxf(0.0, lit.size.x - 20.0))
		line.queue_redraw()
		_tab_last[key] = {"x": Vector2(at["to"]).x, "w": Vector2(at["to"]).y, "id": current, "at": Time.get_ticks_msec()})
	if turning:
		line.ready.connect(func():
			var t := line.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			t.tween_method(func(v: float):
				at["k"] = v
				line.queue_redraw(), 0.0, 1.0, TAB_SLIDE))
	if not turning:
		_tab_last[key] = {"x": float(last.get("x", -1.0)), "w": float(last.get("w", 0.0)), "id": current, "at": now}
		return
	# The page under the bar turns: what follows the bar in its column fades up in a
	# quick stagger.
	bar.ready.connect(func(): _turn_page.call_deferred(bar))


## Fade up what follows a tab bar in its column, in a quick stagger: the page turning.
static func _turn_page(bar: Control) -> void:
	if not is_instance_valid(bar):
		return
	var col := bar.get_parent()
	if col == null:
		return
	var after := false
	var n := 0
	for c in col.get_children():
		if c == bar:
			after = true
			continue
		if not after or not (c is CanvasItem) or not (c as CanvasItem).visible:
			continue
		var ci := c as CanvasItem
		ci.modulate.a = 0.0
		var t := ci.create_tween()
		t.tween_interval(0.03 * mini(n, 4))
		t.tween_property(ci, "modulate:a", 1.0, TAB_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		n += 1


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
	# In a wide window the bar runs edge to edge, its buttons in the page's centred column.
	bar.resized.connect(func():
		var side := 32.0 + maxf(0.0, (bar.size.x - Style.COLUMN_MAX) * 0.5)
		if not is_equal_approx(box.content_margin_left, side):
			box.content_margin_left = side
			box.content_margin_right = side)
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
	# Escape and the phone's back button press it when the screen doesn't use them itself.
	b.set_meta("back", true)
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.add_theme_constant_override("icon_max_width", 34)
	b.add_theme_constant_override("h_separation", 10)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.BODY))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, Style.MUTED)
	b.pressed.connect(callback)
	return b


## A number on a tile counting to its new value, so a purchase is felt as well as seen.
static func tick_to(label: Label, from: int, to: int, fmt: Callable, key: String = "") -> void:
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
	# What it cost or brought rises off the number, the way a purse gives or takes.
	if key != "":
		float_up(label, effect(key, to - from))


## How long a floating number rises, and how far.
const FLOAT_TIME := 1.0
const FLOAT_RISE := 70.0


## A number rises off `anchor` and fades: what a tap cost or brought, or a lord's Regard
## by his face. It floats on the top layer, so the page can rebuild under it. Nothing
## floats under Reduced motion (the number is on the page already).
static func float_up(anchor: Control, chip: Control, delay: float = 0.0) -> void:
	if anchor == null or not is_instance_valid(anchor) or not anchor.is_inside_tree() or Style.motion_reduced():
		chip.free()
		return
	var top: Node = anchor.get_tree().root.get_node_or_null("Scenes")
	if top == null:
		chip.free()
		return
	chip.name = "Float_%s" % chip.name
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.top_level = true
	chip.theme = Style.make_theme()
	chip.modulate.a = 0.0
	top.add_child(chip)
	# The number it rises off may belong to a page built this very frame, which then lays
	# out and gets its scroll back: place the chip once all that has happened.
	_float_from(anchor, chip, delay)


static func _float_from(anchor: Control, chip: Control, delay: float) -> void:
	var tree := chip.get_tree()
	for i in 2:
		await tree.process_frame
	if not is_instance_valid(chip):
		return
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		chip.queue_free()
		return
	chip.reset_size()
	var r := anchor.get_global_rect()
	chip.position = Vector2(r.position.x + (r.size.x - chip.size.x) * 0.5, r.position.y - chip.size.y * 0.35)
	chip.pivot_offset = chip.size * 0.5
	chip.scale = Vector2(0.6, 0.6)
	var t := chip.create_tween().set_parallel()
	t.tween_interval(delay)
	var at := delay
	t.tween_property(chip, "modulate:a", 1.0, 0.1).set_delay(at)
	t.tween_property(chip, "scale", Vector2.ONE, 0.25).set_delay(at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(chip, "position:y", chip.position.y - FLOAT_RISE, FLOAT_TIME).set_delay(at).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(chip, "modulate:a", 0.0, 0.35).set_delay(at + FLOAT_TIME - 0.35)
	t.chain().tween_callback(chip.queue_free)


## Regard that changed in the last moment rises as "+5" by each lord's face on `page`
## (any face drawn with CourtUI.lord_face carries its lord's id). Call it once the page
## is built; changes for lords with no face on the page are let go.
static func show_regard(page: Node) -> void:
	if page == null or not page.is_inside_tree():
		return
	var gs: Node = page.get_tree().root.get_node_or_null("GameState")
	if gs == null or not ("regard_events" in gs):
		return
	var events: Array = gs.regard_events
	if events.is_empty():
		return
	gs.regard_events = []
	var now := Time.get_ticks_msec()
	var faces := {}
	for n in page.find_children("*", "Control", true, false):
		if n.has_meta("lord_id") and (n as Control).is_visible_in_tree() and live(n):
			var id := int(n.get_meta("lord_id"))
			if not faces.has(id):
				faces[id] = n
	var by_lord := {}
	for e in events:
		if now - int(e.get("at", 0)) > REGARD_FLOAT_WINDOW:
			continue
		var id := int(e["id"])
		by_lord[id] = int(by_lord.get(id, 0)) + int(e["amount"])
	var k := 0
	for id in by_lord:
		if faces.has(id) and int(by_lord[id]) != 0:
			float_up(faces[id], effect("bond", int(by_lord[id])), 0.06 * k)
			k += 1


## What a tap just made or changed shows itself: it glows brass and settles in with a
## small pop. Nothing under Reduced motion.
static func flash(node: Control) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree() or Style.motion_reduced():
		return
	node.pivot_offset = node.size * 0.5
	node.modulate = Color(1.45, 1.25, 0.7)
	node.scale = Vector2(0.96, 0.96)
	var t := node.create_tween().set_parallel()
	t.tween_property(node, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Wait for a control built this frame to be laid out (two frames). False if it has gone
## in the meantime, or was never on a page.
static func _settled(node: Control) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false
	var tree := node.get_tree()
	for i in 2:
		await tree.process_frame
		if not is_instance_valid(node) or not node.is_inside_tree():
			return false
	return true


## Run `go` now if `node` is on a page, or as soon as it is.
static func _when_placed(node: Control, go: Callable) -> void:
	if node.is_inside_tree():
		go.call()
	else:
		node.ready.connect(go, CONNECT_ONE_SHOT)


## Glow something a rebuilt page now shows (see flash), once it has been laid out. It can
## be asked for before the control is on the page.
static func flash_soon(node: Control) -> void:
	if node == null or Style.motion_reduced():
		return
	var go := func() -> void:
		if await _settled(node) and live(node):
			flash(node)
	_when_placed(node, go)


## A letter unfolds: it opens downward from its top edge as it fades up. There at once
## under Reduced motion.
static func unfold(node: Control) -> void:
	if node == null or Style.motion_reduced():
		return
	node.modulate.a = 0.0
	var go := func() -> void:
		if not await _settled(node):
			return
		node.pivot_offset = Vector2(node.size.x * 0.5, 0)
		node.scale = Vector2(1.0, 0.12)
		var t := node.create_tween().set_parallel()
		t.tween_property(node, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "modulate:a", 1.0, 0.2)
	_when_placed(node, go)


## A mark that wants noticing beats a few times (an unread letter's dot).
static func pulse(node: Control, times: int = 2) -> void:
	if node == null or Style.motion_reduced():
		return
	var go := func() -> void:
		if not await _settled(node):
			return
		node.pivot_offset = node.size * 0.5
		var t := node.create_tween()
		for i in times:
			t.tween_property(node, "scale", Vector2(1.5, 1.5), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(node, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_when_placed(node, go)


## Someone or something steps into its place on a page from `offset` away, fading up. It
## waits for the page to lay it out first (its container owns where it rests). There at
## once under Reduced motion.
static func step_in(node: Control, offset: Vector2, delay: float = 0.0) -> void:
	if node == null or Style.motion_reduced():
		return
	node.modulate.a = 0.0
	var go := func() -> void:
		if not await _settled(node):
			return
		var rest := node.position
		node.position = rest + offset
		var t := node.create_tween().set_parallel()
		t.tween_property(node, "position", rest, 0.4).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "modulate:a", 1.0, 0.28).set_delay(delay)
	if node.is_inside_tree():
		go.call()
	else:
		node.ready.connect(go, CONNECT_ONE_SHOT)


## A mark struck onto a page (a rank, a role): it comes down large and lands with a
## little overshoot. There at once under Reduced motion.
static func stamp(node: Control, delay: float = 0.0) -> void:
	if node == null or Style.motion_reduced():
		return
	node.modulate.a = 0.0
	var go := func() -> void:
		if not await _settled(node):
			return
		node.pivot_offset = node.size * 0.5
		node.scale = Vector2(1.9, 1.9)
		var t := node.create_tween().set_parallel()
		t.tween_property(node, "scale", Vector2.ONE, 0.28).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "modulate:a", 1.0, 0.12).set_delay(delay)
	if node.is_inside_tree():
		go.call()
	else:
		node.ready.connect(go, CONNECT_ONE_SHOT)


## Whether `n` is on the page to stay: neither it nor anything above it is about to be
## freed (a page rebuilt this frame still holds its old copy until the frame ends).
static func live(n: Node) -> bool:
	var up := n
	while up != null:
		if up.is_queued_for_deletion():
			return false
		up = up.get_parent()
	return true


## How old a Regard change may be and still rise on the page that shows it.
const REGARD_FLOAT_WINDOW := 2500


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
## tap only if the finger hardly moved since the press. A keyboard reaches it too: it
## takes focus (shown by a brass ring, not drawn when a pointer gave it focus) and Enter
## or Space taps it.
static func on_tap(control: Control, action: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.focus_mode = Control.FOCUS_ALL
	control.focus_entered.connect(control.queue_redraw)
	control.focus_exited.connect(func():
		if control.has_meta("pointer_focus"):
			control.remove_meta("pointer_focus")
		control.queue_redraw())
	control.draw.connect(func():
		if control.has_focus() and not control.has_meta("pointer_focus"):
			control.draw_style_box(Style.box(Color(0, 0, 0, 0), Style.BRASS, 2, 16), Rect2(Vector2.ZERO, control.size)))
	control.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_accept") and not e.is_echo():
			control.accept_event()
			action.call()
			return
		var mb := e as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			control.set_meta("pointer_focus", true)
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
		var now := float(c.get_meta("frac", frac))
		var w := maxf(height, (c.size.x - 4.0) * clampf(now, 0.0, 1.0))
		if now > 0.0:
			c.draw_style_box(Style.box(color, Color(0, 0, 0, 0), 0, int(height / 2)), Rect2(Vector2(2, 2), Vector2(w, c.size.y - 4.0)))
		for m in marks:
			var x := 2.0 + (c.size.x - 4.0) * clampf(float(m), 0.0, 1.0)
			c.draw_line(Vector2(x, -2.0), Vector2(x, c.size.y + 2.0), Style.TEXT, 2.0))
	c.set_meta("frac", frac)
	return c


## A meter filling (or draining) from `from` to the share it was made with, so a change
## is seen. At once under Reduced motion.
static func fill_from(m: Control, from: float) -> void:
	if m == null or Style.motion_reduced():
		return
	var to := float(m.get_meta("frac", 0.0))
	if is_equal_approx(from, to):
		return
	m.set_meta("frac", from)
	var step := func(v: float) -> void:
		m.set_meta("frac", v)
		m.queue_redraw()
	var t := m.create_tween()
	t.tween_interval(0.15)
	t.tween_method(step, from, to, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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
		if is_instance_valid(shade) and not shade.is_queued_for_deletion() and not shade.has_meta("dismissed"):
			dismiss_sheet(shade)
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
	# In a wide window the sheet keeps to the phone-width column, centred.
	var fit := func():
		if is_instance_valid(panel):
			var side := maxf(0.0, (shade.size.x - Style.COLUMN_MAX) * 0.5)
			panel.offset_left = side
			panel.offset_right = -side
	shade.resized.connect(fit)
	fit.call()
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


## Take a sheet's shade off the page at once (so the page, and anything that looks for
## it by name, sees it gone) and let it fade and sink on the top layer before it's freed.
static func dismiss_sheet(shade: Control) -> void:
	shade.set_meta("dismissed", true)
	var host := shade.get_parent()
	var top: Node = shade.get_tree().root.get_node_or_null("Scenes") if shade.is_inside_tree() else null
	if Style.motion_reduced() or top == null or host == null:
		shade.queue_free()
		return
	# The sheet keeps the look it had on the page once it leaves it.
	var up: Node = host
	while up != null and not (up is Control and (up as Control).theme != null):
		up = up.get_parent()
	if up != null and shade.theme == null:
		shade.theme = (up as Control).theme
	shade.name = "%s_closing" % shade.name
	shade.reparent(top)
	top.move_child(shade, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in shade.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := shade.get_node_or_null("SheetPanel") as Control
	var t := shade.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(shade, "color:a", 0.0, Style.EASE_OUT_TIME + 0.04)
	if panel != null:
		t.tween_property(panel, "position:y", panel.position.y + 36.0, Style.EASE_OUT_TIME + 0.04)
		t.tween_property(panel, "modulate:a", 0.0, Style.EASE_OUT_TIME + 0.04)
	t.chain().tween_callback(shade.queue_free)


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
## Requirements, each met or still to do. The mark reads without colour or a special
## glyph: a filled disc with a tick drawn in it when met, an open ring when not. Each
## step is {id, title, done, detail}.
static func checklist(steps: Array, list_name: String = "Checklist") -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = list_name
	box.add_theme_constant_override("separation", 14)
	for s in steps:
		var done: bool = bool(s.get("done", false))
		var row := HBoxContainer.new()
		row.name = "Step_%s" % String(s.get("id", ""))
		row.add_theme_constant_override("separation", 14)
		row.set_meta("done", done)
		var mark := Control.new()
		mark.name = "Met" if done else "Open"
		mark.custom_minimum_size = Vector2(30, 30)
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.draw.connect(func():
			var c := mark.size * 0.5
			var r := minf(mark.size.x, mark.size.y) * 0.5 - 2.0
			if done:
				mark.draw_circle(c, r, Style.MORALE_HIGH)
				mark.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.5, 0.0), c + Vector2(-r * 0.12, r * 0.42), c + Vector2(r * 0.55, -r * 0.4)]),
					Style.NIGHT, 3.0, true)
			else:
				mark.draw_arc(c, r, 0.0, TAU, 32, Style.MUTED, 2.5, true))
		row.add_child(mark)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 2)
		var title := Style.label(String(s.get("title", "")), Style.BODY, Style.MUTED if done else Style.TEXT)
		title.name = "StepTitle"
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(title)
		var detail := String(s.get("detail", ""))
		if detail != "":
			var d := Style.label(detail, Style.SMALL, Style.MUTED)
			d.name = "StepDetail"
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.add_child(d)
		row.add_child(words)
		box.add_child(row)
	return box


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
	# A full touch target; the switch drawn in it stays its old size.
	b.custom_minimum_size = Vector2(104, Style.TOUCH)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_ALL
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(state, clear)
	b.add_theme_stylebox_override("focus", Style.box(Color(0, 0, 0, 0), Style.BRASS, 2, 28))
	b.draw.connect(func():
		var lit := b.button_pressed
		var track_size := Vector2(minf(b.size.x - 8.0, 88.0), minf(b.size.y - 12.0, 40.0))
		var track := Rect2((b.size - track_size) * 0.5, track_size)
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
