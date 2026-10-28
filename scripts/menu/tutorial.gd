## Optional, replayable introduction. No world time, troops or money change here.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const LESSONS := [
	["Ride the Glass Sea", "Tap a settlement, then Ride there. Drag to look around; pinch or scroll to zoom. Double-tap to find your warband.", "Time passes only while you travel or wait. The campaign menu and encounters pause time so you can decide."],
	["Keep your company supplied", "Watch silver and days of food on the map. Each day your men need wages and a ration each. Shortfalls cause desertion.", "Enter a settlement to buy food and hire recruits. Villages sell cheaper food; towns let you refill and train squads."],
	["Choose your fights", "Scouts estimate the danger when bandits block your road. Lead the battle, send your men in, or withdraw when allowed.", "Sending men in is quick but costs more lives. Victories pay silver, food and renown; renown increases your squad cap."],
	["Command the battle", "Before fighting, use Auto-place or tap a squad card and the field. Press Fight when ready. Hold braces your line; Advance moves it toward the enemy.", "Select a squad to target an enemy or move to open ground. Drag to form a line. Spears stop horse, horse catch bows, bows beat foot, and foot beat spears. Pause to give orders."],
	["Use ground and abilities", "Select a squad to use its ability: Shield wall protects infantry, Schiltron guards spears from every side, Volley shakes enemies, and Wheel lets cavalry charge again.", "Heights help archers and downhill attacks. Woods shelter troops from arrows but slow movement. Fords leave men vulnerable. Use the ground and save your abilities for the right moment."],
	["Know your captains", "Every squad has a captain. Captains fighting side by side build bonds: C restores morale nearby; B and A also improve damage.", "Fallen captains may be wounded or killed. Open Warband from the map menu to see squads, bonds and the fallen. When your first bond forms, a short introduction explains how to use it."],
]
var step := 0

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var lesson: Array = LESSONS[step]
	var col := Page.column(self, "Learn to play", "Optional tutorial · %d of %d" % [step + 1, LESSONS.size()])
	var progress := ProgressBar.new()
	progress.max_value = LESSONS.size()
	progress.value = step + 1
	progress.show_percentage = false
	progress.custom_minimum_size.y = 10
	col.add_child(progress)
	col.add_child(Page.note(String(lesson[0]), 38, Style.TEXT))
	col.add_child(Page.note(String(lesson[1]), Style.BODY, Style.TEXT))
	col.add_child(Page.note(String(lesson[2])))
	var next := Page.button("Finish tutorial" if step == LESSONS.size() - 1 else "Next", _next, true)
	col.add_child(next)
	if step > 0:
		col.add_child(Page.button("Previous", func():
			step -= 1
			_build()))
	col.add_child(Page.button("Skip tutorial" if step == 0 else "Leave tutorial", _leave))
	next.grab_focus()

func _next() -> void:
	if step == LESSONS.size() - 1:
		_leave()
	else:
		step += 1
		_build()

func _leave() -> void:
	Scenes.go(Scenes.tutorial_return)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
