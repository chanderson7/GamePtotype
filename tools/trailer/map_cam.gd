extends Node
## A camera for trailer shots of the map: the HUD put away so the Glass Sea fills the frame,
## and the view drifting from `from` to `to` (map units) while it eases from `scale_from` to
## `scale_to` (screen pixels per map unit, at the 720-wide canvas) over `time` seconds.

var screen
var from := Vector2(500, 700)
var to := Vector2(500, 700)
var scale_from := 1.5
var scale_to := 1.5
var time := 10.0
var hud := false
var _t := 0.0


func setup(c: Dictionary, show_hud: bool) -> void:
	from = c.get("from", from)
	to = c.get("to", to)
	scale_from = float(c.get("scale_from", scale_from))
	scale_to = float(c.get("scale_to", scale_to))
	time = float(c.get("time", time))
	hud = show_hud


func _ready() -> void:
	process_priority = 1000


func _process(delta: float) -> void:
	if screen == null:
		return
	_t += delta
	if not hud:
		for name in ["top_panel", "bottom_bar", "sheet_panel", "pinned_chip"]:
			var p = screen.get(name)
			if p != null and p is CanvasItem:
				p.visible = false
		var vs: Vector2 = screen.get_viewport_rect().size
		screen._view = Rect2(Vector2.ZERO, vs)
	var f := smoothstep(0.0, 1.0, clampf(_t / time, 0.0, 1.0))
	screen.cam_center = from.lerp(to, f)
	screen.cam_scale = lerpf(scale_from, scale_to, f)
	screen._clamp_camera()
	screen._sync_layers()
	screen.queue_redraw()
