## Shared, scrollable menu layout with safe-area padding and keyboard-friendly buttons.
extends RefCounted
const Style = preload("res://scripts/ui/style.gd")

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
	margin.add_theme_constant_override("margin_top", 48 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 40 + int(insets["bottom"]))
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	margin.add_child(col)
	col.add_child(note(heading, 52, Style.BRASS))
	col.add_child(note(subtitle))
	return col

static func note(text: String, size: int = Style.BODY, color: Color = Style.MUTED) -> Label:
	var label := Style.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

static func button(text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = Style.TOUCH
	b.pressed.connect(action)
	if primary:
		Style.make_primary(b)
	return b
