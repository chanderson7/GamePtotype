## Optional, replayable introduction. No world time, troops or money change here.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const TutorialArt = preload("res://scripts/ui/tutorial_art.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
## Room for the bottom bar under the page, above the safe area.
const BAR_ROOM := 124.0
const LESSONS := [
	["Ride the Glass Sea", "Tap a settlement, then Ride there. Drag to look around; pinch or scroll to zoom. Double-tap to find your warband.", "Time passes only while you travel or wait. The campaign menu and encounters pause time so you can decide."],
	["Keep your warband supplied", "Watch silver and days of food on the map. Each day your men need wages and a ration each. Shortfalls cause desertion.", "Enter a settlement to buy food and hire recruits. Villages sell cheaper food; towns let you refill and train companies. Short of silver? Take a contract from the notice board under Work: a courier run pays without a battle."],
	["Choose your fights", "Scouts estimate the danger when bandits block your road. Lead the battle, send your men in, or withdraw: Withdraw pulls you back to the last settlement you passed, though a quicker, far stronger lord can ride you down.", "Sending men in is quick but costs more lives. Victories pay silver, food and renown; renown raises how many companies you can lead. Half the men who fall come back wounded: they rejoin as they heal, and still eat and draw pay. A defeat costs half a day and sends you back to your people's capital."],
	["Command the battle", "Before fighting, use Auto-place or tap a company's card and then the field. Press Fight when ready. A company that holds for two seconds is braced: it hits harder and takes less from the front. Advance moves it toward the enemy and gives that up.", "Select a company, then tap an enemy to attack it, or tap open ground and tap the ring again to march there. Drag a line to form up along it. Spears stop horse, horse catch bows, bows beat foot, and foot beat spears. Pause or hold the hourglass to think; orders still work."],
	["Use ground and abilities", "Select a company to use its ability: Shield wall protects infantry, Schiltron guards spears from every side, Volley shakes enemies, and Wheel lets cavalry charge again.", "Heights help archers and downhill attacks. Woods shelter troops from arrows but slow movement. Fords leave men vulnerable. Use the ground and save your abilities for the right moment."],
	["Know your captains", "Every company has a captain. Captains fighting side by side build bonds: C restores morale nearby; B and A also improve damage.", "Fallen captains may be wounded or killed. Open Warband from the map menu to see companies, bonds and the fallen. When your first bond forms, a short introduction explains how to use it. In the long run you can serve a realm, win a fief with walls and raise your own crown: Warband, then Deeds, shows each step under Toward a crown."],
]
var step := 0

func _ready() -> void:
	# Opened once, the lessons needn't switch themselves on for a first campaign (see
	# new_campaign.gd, which reads this mark from the settings file).
	Sound.mark_hint_seen("device", "tutorial_seen")
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var lesson: Array = LESSONS[step]
	var insets := Style.safe_insets(get_viewport())
	var col := Page.frame(self, BAR_ROOM + float(insets["bottom"]))
	# The title with the way out beside it, then the lesson's place in six as pips.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var title := Style.label("Learn to play", 52, Style.BRASS)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(title)
	var skip := Button.new()
	skip.name = "SkipTutorial"
	skip.flat = true
	skip.text = "Skip tutorial" if step == 0 else "Leave tutorial"
	skip.custom_minimum_size = Vector2(0, Style.TOUCH)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	skip.add_theme_color_override("font_color", Style.MUTED)
	skip.pressed.connect(_leave)
	head.add_child(skip)
	col.add_child(_pips())
	if Style.illustrations_on():
		col.add_child(TutorialArt.make(step))
	col.add_child(Page.note(String(lesson[0]), 38, Style.TEXT))
	col.add_child(Page.note(String(lesson[1]), Style.BODY, Style.TEXT))
	col.add_child(Page.note(String(lesson[2])))
	var buttons := []
	if step > 0:
		var prev := Widgets.back_button(func():
			step -= 1
			_build(), "Previous", "Previous")
		buttons.append(prev)
	var last := step == LESSONS.size() - 1
	var next := Button.new()
	next.name = "Next"
	next.text = "Finish tutorial" if last else "Next"
	next.icon = Widgets.icon("resume" if last else "advance")
	next.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	Style.make_primary(next)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		next.add_theme_color_override(c, Style.BRASS_INK)
	next.pressed.connect(_next)
	buttons.append(next)
	var bar := Widgets.bottom_bar(buttons, insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	next.grab_focus()


## Six pips, the ones done in brass and this one ringed.
func _pips() -> Control:
	var c := Control.new()
	c.name = "Progress"
	c.custom_minimum_size = Vector2(0, 26)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = "%d of %d" % [step + 1, LESSONS.size()]
	c.draw.connect(func():
		for i in LESSONS.size():
			var at := Vector2(13 + i * 34, 13)
			if i < step:
				c.draw_circle(at, 9, Style.BRASS)
			elif i == step:
				c.draw_circle(at, 9, Style.NIGHT)
				c.draw_arc(at, 9, 0, TAU, 24, Style.BRASS, 3.0)
			else:
				c.draw_arc(at, 9, 0, TAU, 24, Style.RULE, 3.0))
	return c


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
