extends Node
## Presses replies on cue for a trailer shot: `plan` is [[seconds, what], ...], where `what`
## is a reply id (the button Reply_<id>) or words on a button. A press waits until its
## button is there and enabled, so a line still being written doesn't lose the tap.

var tree: SceneTree
var plan: Array = []
var _t := 0.0
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	if _next >= plan.size() or _t < float(plan[_next][0]):
		return
	var b := _find(String(plan[_next][1]))
	if b != null:
		b.pressed.emit()
		_next += 1


func _find(what: String) -> Button:
	var scene := tree.current_scene
	if scene == null:
		return null
	var by_id := scene.find_child("Reply_" + what, true, false) as Button
	if by_id != null and by_id.is_visible_in_tree() and not by_id.disabled:
		return by_id
	var low := what.to_lower()
	for c in scene.find_children("*", "Button", true, false):
		var b := c as Button
		if not b.is_visible_in_tree() or b.disabled:
			continue
		var words := b.text
		var label := b.find_child("Text", true, false) as Label
		if label != null:
			words += " " + label.text
		if String(b.name).to_lower().contains(low) or words.to_lower().contains(low):
			return b
	return null
