## Draws fewer frames while nothing is happening, to spare a phone's battery: after
## IDLE_AFTER seconds without a touch, a screen that isn't moving by itself is drawn at
## IDLE_FPS (its smoke and pennants still move, at half the frames). A screen keeps the
## full pace while it says so: keeps_full_pace() on the current scene (the battle while
## it's fought, the map while time runs, Home while the opening plays). A touch brings the
## full pace back at once. Off without a screen (headless tests) and under Movie Maker.
## A child of the Scenes autoload.
extends Node

const IDLE_FPS := 30
const IDLE_AFTER := 2.0

## Whether frames are being spared now.
var idle := false
var _last_input_ms := 0
var _enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_input_ms = Time.get_ticks_msec()
	_enabled = DisplayServer.get_name() != "headless" and not OS.get_cmdline_args().has("--write-movie")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton \
			or event is InputEventMouseMotion or event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventMagnifyGesture or event is InputEventPanGesture:
		touched()


## Something was touched (or a key pressed): the full pace, now and for IDLE_AFTER.
func touched() -> void:
	_last_input_ms = Time.get_ticks_msec()
	_set_idle(false)


func _process(_delta: float) -> void:
	_set_idle(_enabled and Time.get_ticks_msec() - _last_input_ms > int(IDLE_AFTER * 1000.0) and not scene_busy())


## Whether the current scene says it's moving by itself.
func scene_busy() -> bool:
	var cur := get_tree().current_scene
	return cur != null and cur.has_method("keeps_full_pace") and bool(cur.call("keeps_full_pace"))


func _set_idle(on: bool) -> void:
	if on == idle:
		return
	idle = on
	Engine.max_fps = IDLE_FPS if on else 0
