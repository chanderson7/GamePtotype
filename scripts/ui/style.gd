## Shared colors and the UI theme, so the camp and the battle look like one game.
extends RefCounted

const NIGHT := Color("0e1322")
const PANEL := Color("161d33")
const RAISED := Color("1f2846")
const RULE := Color("303b63")
const TEXT := Color("ece5d3")
const MUTED := Color("a6adc8")
const BRASS := Color("d9a944")
const BRASS_INK := Color("1d1505")

const PLAYER := Color("3f6fd8")
const PLAYER_DARK := Color("1d3a80")
const PLAYER_LIGHT := Color("a9c4ff")
const ENEMY := Color("c8443c")
const ENEMY_DARK := Color("74221d")
const ENEMY_LIGHT := Color("ffb7ae")

const FIELD_A := Color("4d7a37")
const FIELD_B := Color("548341")


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), border_width: int = 0, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(RAISED, RULE, 2))
	t.set_stylebox("hover", "Button", box(RAISED.lightened(0.06), MUTED, 2))
	t.set_stylebox("pressed", "Button", box(RAISED.lightened(0.1), BRASS, 2))
	t.set_stylebox("hover_pressed", "Button", box(RAISED.lightened(0.1), BRASS, 2))
	t.set_stylebox("disabled", "Button", box(RAISED.darkened(0.3), RULE, 2))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), BRASS, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_hover_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))

	t.set_stylebox("panel", "PanelContainer", box(PANEL, RULE, 2, 14))
	t.set_stylebox("panel", "Panel", box(PANEL, RULE, 2, 14))

	t.set_stylebox("background", "ProgressBar", box(NIGHT, RULE, 2, 8))
	t.set_stylebox("fill", "ProgressBar", box(BRASS, Color(0, 0, 0, 0), 0, 8))
	return t


## A primary call-to-action style for one button.
static func make_primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", box(BRASS, Color(0, 0, 0, 0), 0))
	button.add_theme_stylebox_override("hover", box(BRASS.lightened(0.08), Color(0, 0, 0, 0), 0))
	button.add_theme_stylebox_override("pressed", box(BRASS.darkened(0.1), Color(0, 0, 0, 0), 0))
	button.add_theme_color_override("font_color", BRASS_INK)
	button.add_theme_color_override("font_hover_color", BRASS_INK)
	button.add_theme_color_override("font_pressed_color", BRASS_INK)
	button.add_theme_color_override("font_focus_color", BRASS_INK)


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
