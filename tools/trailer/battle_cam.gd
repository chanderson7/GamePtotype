extends Node
## A camera for trailer shots of a battle: the HUD put away so the field fills the frame,
## and the view held on the fighting, closer than the game's own camera goes.
## It runs after the battle screen each frame and overrides the camera the screen chose,
## keeping the screen's own shake and punch.
##   mode "clash":  the middle of the squads in contact (all of them before contact)
##   mode "follow": one squad of the given `type` and `team` (0 yours, 1 theirs)
##   mode "pan":    from `from` to `to` (arena coordinates, 840x1260) over `time` seconds

const Sim = preload("res://scripts/battle/battle_sim.gd")

const OVERSCAN := Vector2(220, 220)

var screen
var mode := "clash"
var zoom := 2.8
var zoom_to := -1.0
var zoom_time := 6.0
var follow_type := "cavalry"
var follow_team := 0
var pan_from := Vector2(420, 630)
var pan_to := Vector2(420, 630)
var pan_time := 8.0
var ease := 1.2
var hud := false
var _t := 0.0
var _center := Vector2.ZERO
var _z := 1.0
var _started := false
var _followed = null


func setup(c: Dictionary, show_hud: bool) -> void:
	mode = String(c.get("mode", "clash"))
	zoom = float(c.get("zoom", 2.8))
	zoom_to = float(c.get("zoom_to", -1.0))
	zoom_time = float(c.get("zoom_time", 6.0))
	follow_type = String(c.get("type", "cavalry"))
	follow_team = int(c.get("team", 0))
	pan_from = c.get("from", pan_from)
	pan_to = c.get("to", pan_to)
	pan_time = float(c.get("time", 8.0))
	ease = float(c.get("ease", 1.2))
	hud = show_hud


func _ready() -> void:
	process_priority = 1000


func _process(delta: float) -> void:
	if screen == null or screen.sim == null:
		return
	_t += delta
	if not hud:
		for p in [screen.top_panel, screen.bottom_panel, screen.hint_toast, screen.inspect_pill, screen.objective_chip]:
			if p != null:
				p.visible = false
		var vs: Vector2 = screen.get_viewport_rect().size
		# The view runs past the frame on every side by the same margin: centred as before,
		# with the slow handle (drawn in its lower right corner) out of the picture.
		screen._view = Rect2(-OVERSCAN, vs + OVERSCAN * 2.0)
		screen._fit_scale = maxf(0.1, minf(vs.x / Sim.ARENA.x, vs.y / Sim.ARENA.y))
	var want := _want_center()
	var want_z := zoom
	if zoom_to > 0.0:
		want_z = lerpf(zoom, zoom_to, smoothstep(0.0, 1.0, clampf(_t / zoom_time, 0.0, 1.0)))
	if not _started:
		_started = true
		_center = want
		_z = want_z
	var k := 1.0 - exp(-delta * ease)
	_center = _center.lerp(want, k if mode != "pan" else 1.0)
	_z = lerpf(_z, want_z, 1.0 if zoom_to > 0.0 else k)
	screen.cam_center = _center
	screen.cam_zoom = _z
	screen._apply_camera()
	screen._redraw()


func _want_center() -> Vector2:
	var sim = screen.sim
	match mode:
		"pan":
			var f := smoothstep(0.0, 1.0, clampf(_t / pan_time, 0.0, 1.0))
			return pan_from.lerp(pan_to, f)
		"follow":
			if _followed == null or not _followed.is_active():
				_followed = null
				for sq in sim.squads:
					if sq.team == follow_team and sq.type == follow_type and sq.is_active():
						_followed = sq
						break
			if _followed != null:
				return _followed.avg
	var sum := Vector2.ZERO
	var w := 0.0
	for sq in sim.squads:
		if not sq.is_active():
			continue
		var k := 4.0 if sq.in_contact or sq.engaged else 0.25
		sum += sq.avg * k * float(sq.alive_n)
		w += k * float(sq.alive_n)
	return sum / w if w > 0.0 else Sim.ARENA * 0.5
