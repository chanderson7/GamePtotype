## Shared, scrollable menu layout with safe-area padding and keyboard-friendly buttons.
extends RefCounted
const Style = preload("res://scripts/ui/style.gd")

## The one page shell: the night background, a scroll, margins clear of the notch and the
## home bar, and the column to fill (separation 18). Every full-screen menu starts here.
## In a window wider than a phone the column stays phone-width, centred (cap_width).
static func frame(root: Control, bottom_room: float = 0.0) -> VBoxContainer:
	root.theme = Style.make_theme()
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.name = "PageScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_bottom = -bottom_room
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var insets := Style.safe_insets(root.get_viewport()) if root.is_inside_tree() else {"top": 0.0, "bottom": 0.0}
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	cap_width(margin, 32)
	margin.add_theme_constant_override("margin_top", 48 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + (0 if bottom_room > 0.0 else int(insets["bottom"])))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.name = "PageColumn"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	return col


static func column(root: Control, heading: String, subtitle: String) -> VBoxContainer:
	root.theme = Style.make_theme()
	var bg := ColorRect.new()
	bg.color = Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var insets := Style.safe_insets(root.get_viewport())
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	cap_width(margin, 36)
	margin.add_theme_constant_override("margin_top", 48 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + int(insets["bottom"]))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	col.add_child(note(heading, 52, Style.BRASS))
	col.add_child(note(subtitle))
	return col

## Keep what `margin` holds to Style.COLUMN_MAX wide, centred: its side margins grow from
## `side` as the window gets wider than a phone (a computer held landscape, a tablet), but
## never so far that what it holds no longer fits.
## The width it measures is the room its parent gives it, not its own: content wider than
## the screen would otherwise grow the margins, which grow the content, without end. The
## resize its own change causes is let pass.
static func cap_width(margin: MarginContainer, side: int) -> void:
	margin.resized.connect(func():
		if margin.has_meta("capping"):
			return
		var room: float = margin.get_parent_area_size().x
		# The column is COLUMN_MAX at most, but never narrower than what it holds needs
		# (big text can ask for more): the margins give way first.
		var column := minf(room - side * 2.0, Style.COLUMN_MAX)
		for k in margin.get_children():
			if k is Control:
				column = maxf(column, (k as Control).get_combined_minimum_size().x)
		var wide := maxi(side, int((room - column) * 0.5))
		if margin.get_theme_constant("margin_left") != wide:
			margin.set_meta("capping", true)
			margin.add_theme_constant_override("margin_left", wide)
			margin.add_theme_constant_override("margin_right", wide)
			margin.remove_meta("capping"))


## Words that wrap. In a row they take the room left beside the rest (a wrapping label with
## no width of its own breaks after every letter); in a column this changes nothing.
static func note(text: String, size: int = Style.BODY, color: Color = Style.MUTED) -> Label:
	var label := Style.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.y = Style.TOUCH
	b.pressed.connect(action)
	if primary:
		Style.make_primary(b)
	return b
