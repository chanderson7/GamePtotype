## Changes screens with a quick fade through black (an autoload), so one screen never
## snaps into the next. Taps are held off while the screen is dark.
extends CanvasLayer

const OUT := 0.15
const IN := 0.25

var _veil: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veil = ColorRect.new()
	_veil.color = Color(0.03, 0.04, 0.07, 0.0)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


## Fade out, change to the scene at `path`, fade back in.
func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_veil, "color:a", 1.0, OUT)
	await out.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_property(_veil, "color:a", 0.0, IN)
	await back.finished
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
