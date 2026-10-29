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

## Morale, from steady to breaking.
const MORALE_HIGH := Color("6fcf5a")
const MORALE_MID := Color("e8c547")
const MORALE_LOW := Color("e2553f")

## Type sizes, in viewport units (720 wide, so one unit is about 0.55 pt on a phone).
## Nothing a player needs to read goes below SMALL, about 12 pt.
const SMALL := 22
const BODY := 26
const LARGE := 30

## Touch targets: a button is never shorter than this, about 44 pt.
const TOUCH := 80.0


## The phone's safe area, as insets in viewport units: {top, bottom}. Zero on desktop,
## where the window isn't under a notch or a home indicator.
static func safe_insets(vp: Viewport) -> Dictionary:
	var out := {"top": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return out
	var safe := DisplayServer.get_display_safe_area()
	var scale := vp.get_visible_rect().size.y / win.y
	out["top"] = maxf(0.0, float(safe.position.y)) * scale
	out["bottom"] = maxf(0.0, win.y - float(safe.end.y)) * scale
	return out


static func morale_color(morale: float) -> Color:
	if morale > 60.0:
		return MORALE_HIGH
	return MORALE_MID if morale > 42.0 else MORALE_LOW


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
	t.default_font_size = text_size(BODY)
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


## Ease a panel into view: it fades in and rises the last little way from `anchor`
## (0.5, 1 grows from its bottom middle; 0.5, 0.5 from its center).
static func ease_in(panel: Control, anchor: Vector2 = Vector2(0.5, 1.0)) -> void:
	if motion_reduced():
		panel.modulate.a = 1.0
		panel.scale = Vector2.ONE
		return
	panel.pivot_offset = panel.size * anchor
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.92) if anchor.y > 0.9 else Vector2(0.9, 0.9)
	var t := panel.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.14)
	t.tween_property(panel, "scale", Vector2.ONE, 0.22)


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", text_size(size))
	l.add_theme_color_override("font_color", color)
	return l


static func presentation_settings() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Sound") if tree != null else null

static func text_size(base: int) -> int:
	var settings := presentation_settings()
	var scale: float = settings.text_scale if settings != null else 1.0
	# Body text gets the full setting; display headings grow gently to preserve space.
	return roundi(base * (scale if base <= 36 else minf(scale, 1.15)))

static func motion_reduced() -> bool:
	var settings := presentation_settings()
	return bool(settings.reduced_motion) if settings != null else false

static func illustrations_on() -> bool:
	var settings := presentation_settings()
	return bool(settings.illustrations_enabled) if settings != null else true
