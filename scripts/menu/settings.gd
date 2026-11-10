## Device settings live outside the warband; returning never advances the campaign.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")
## Room for the bottom bar under the page, above the safe area.
const BAR_ROOM := 124.0

## Whether the developer options are shown (they also show while the readout is on).
var _dev_open := false
## A slider has moved since the settings were last written: they're written when it's let
## go, and on the way out if a keyboard moved it.
var _slid := false


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var insets := Style.safe_insets(get_viewport())
	var col := Page.frame(self, BAR_ROOM + float(insets["bottom"]))
	var heading := Style.label("Settings", 52, Style.BRASS)
	col.add_child(heading)
	col.add_child(Page.note("Changes save automatically on this device.", Style.SMALL))
	col.add_child(Widgets.section("Sound"))
	col.add_child(_switch_row("Music", "", Sound.music_on, Sound.set_music_on))
	col.add_child(_slider_row("Music volume", Sound.music_volume, 0.0, 1.0, Sound.set_music_volume, _percent))
	col.add_child(_switch_row("Sound effects", "", Sound.sounds_on, Sound.set_sounds_on, "Sound"))
	col.add_child(_slider_row("Sound volume", Sound.sound_volume, 0.0, 1.0, func(v: float, save: bool):
		Sound.set_sound_volume(v, save)
		# A click at the new level, so the slider is heard as it moves.
		if not save:
			Sound.play("click", 0.0, 0.0, 0.08), _percent))
	col.add_child(Widgets.section("Reading & motion"))
	# Text size as three A's, each drawn at the size it gives.
	var sizes := [1.0, 1.25, 1.5]
	var size_bar := Widgets.segmented(["A", "A", "A"], maxi(0, sizes.find(Sound.text_scale)), func(i: int):
		Sound.set_text_scale(sizes[i])
		_build(), "TextSize")
	var glyphs := [Style.SMALL, 30, 38]
	var tips := ["100%", "125%", "150%"]
	for i in 3:
		var t := size_bar.find_child("Tab_%d" % i, true, false) as Button
		if t != null:
			t.add_theme_font_size_override("font_size", glyphs[i])
			# Each A keeps the size it stands for, whatever the bar would fit it to.
			t.set_meta("font_full", glyphs[i])
			t.set_meta("font_least", glyphs[i])
			t.tooltip_text = tips[i]
			t.accessibility_name = "Text size %s" % tips[i]
	col.add_child(_control_row("Text size", size_bar))
	col.add_child(_switch_row("Reduced motion", "No opening, menu scaling, Home drift, battle shake or map glides", Sound.reduced_motion, func(on: bool):
		Sound.set_reduced_motion(on)))
	col.add_child(_switch_row("Text appears at once", "In conversations, instead of being written out", Sound.instant_text, func(on: bool):
		Sound.set_instant_text(on)))
	var shakes := [0.0, 0.5, 1.0]
	col.add_child(_control_row("Screen shake", Widgets.segmented(["Off", "Light", "Full"], maxi(0, shakes.find(Sound.shake)), func(i: int):
		Sound.set_shake(shakes[i]), "ScreenShake")))
	col.add_child(_switch_row("Illustrations", "Scenes and portraits throughout the game", Sound.illustrations_enabled, func(on: bool):
		Sound.set_illustrations(on)))
	col.add_child(_switch_row("Vibration", "", Sound.haptics_enabled, func(on: bool):
		Sound.set_haptics(on)))
	# Only a computer has a window to fill.
	if OS.has_feature("pc"):
		col.add_child(_switch_row("Full screen", "Also F11 or Alt+Enter", Sound.fullscreen, func(on: bool):
			Scenes.set_fullscreen(on)))
	col.add_child(Widgets.section("Story"))
	col.add_child(_switch_row("Romance invitations", "Friendships and house pacts stay either way", Sound.romance_invitations_enabled(), func(on: bool):
		Sound.set_romance_invitations(on)))
	col.add_child(Widgets.section("Campaign mode"))
	col.add_child(Widgets.segmented(["Mortal", "Casual"], 1 if GameState.casual_mode else 0, func(i: int):
		GameState.casual_mode = i == 1
		GameState.save_game()
		_build(), "CampaignMode", ["skull", "wounded"]))
	col.add_child(Page.note("Mortal: fallen captains can die for good. Casual: they take severe wounds instead.", Style.SMALL))
	if GameState.has_campaign():
		col.add_child(Widgets.section("Saving"))
		var saving := Page.note("Ironman: the game keeps one save as you go, and there's no going back. Chosen when the campaign began." if GameState.ironman
			else "Save your own from the campaign menu (up to %d). The game also keeps one before each battle and one when you enter a settlement." % SaveSlots.MAX_OWN, Style.SMALL)
		saving.name = "SavingNote"
		col.add_child(saving)
	col.add_child(Widgets.section("Learn to play"))
	var tut := Page.button("Open tutorial", func():
		Scenes.tutorial_return = "res://scenes/settings.tscn"
		Scenes.go("res://scenes/tutorial.tscn"))
	tut.icon = Widgets.icon("book")
	col.add_child(tut)
	# For whoever is building the game, out of the player's way.
	var open := _dev_open or Sound.show_performance
	var dev := Button.new()
	dev.name = "DeveloperToggle"
	dev.flat = true
	dev.text = "Developer"
	dev.icon = Widgets.icon("gear")
	dev.alignment = HORIZONTAL_ALIGNMENT_LEFT
	dev.custom_minimum_size = Vector2(0, Style.TOUCH)
	dev.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	dev.add_theme_color_override("font_color", Style.MUTED)
	dev.pressed.connect(func():
		_dev_open = not open
		_build())
	col.add_child(dev)
	if open:
		col.add_child(_switch_row("Show performance", "What each battle frame costs, at the bottom of the field", Sound.show_performance, func(on: bool):
			Sound.set_show_performance(on)
			_build()))
		col.add_child(Widgets.section("Feel tuning"))
		col.add_child(Page.note("Multipliers on the battle's feel, for judging it on a device. 1.00 is as designed.", Style.SMALL))
		var feel_words := {"shake": "Screen shake", "hitstop": "Hit-stop", "motion": "Men's motion", "camera": "Camera follow", "haptics": "Vibration strength"}
		for key in Sound.FEEL:
			col.add_child(_slider_row(String(feel_words[key]), float(Sound.feel[key]), Sound.FEEL_MIN, Sound.FEEL_MAX,
				func(v: float, save: bool): Sound.set_feel(key, v, save), _times))
		var reset := Page.button("Reset feel", func():
			Sound.reset_feel()
			_build())
		reset.name = "ResetFeel"
		col.add_child(reset)
		if Sound.show_performance:
			# Twelve companies a side, the computer commanding both; your campaign isn't touched.
			var test := Page.button("Test battle: 12 against 12", func():
				if load("res://scripts/battle/battle_screen.gd").test_battle(GameState.culture if GameState.culture != "" else "vardish"):
					Scenes.go_battle())
			test.name = "TestBattle"
			col.add_child(test)
	var bar := Widgets.bottom_bar(Widgets.back_button(_back), insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	heading.focus_mode = Control.FOCUS_ALL
	# Focus starts at the top for keyboards and screen readers, without a box drawn round the title.
	heading.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	heading.grab_focus()


## A setting with an on/off switch at the right, and a short note under its name. A tap
## anywhere on the row flips the switch; a keyboard reaches the switch itself.
func _switch_row(title: String, note: String, on: bool, setter: Callable, word: String = "") -> Control:
	var row := HBoxContainer.new()
	row.name = "Setting_" + title.replace(" ", "")
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, Style.TOUCH)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_PASS
	var t := Style.label(title, Style.BODY, Style.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(t)
	if note != "":
		var n := Style.label(note, Style.SMALL, Style.MUTED)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(n)
	row.add_child(words)
	var sw := Widgets.switch(on, setter, "Switch_" + title.replace(" ", ""), word if word != "" else title)
	# The row takes the tap (the switch would take it twice otherwise: it passes taps on).
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sw)
	Widgets.on_tap(row, func(): sw.button_pressed = not sw.button_pressed)
	row.focus_mode = Control.FOCUS_NONE
	return row


## A setting's name on the left and its control on the right.
func _control_row(title: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.name = "Setting_" + title.replace(" ", "")
	row.add_theme_constant_override("separation", 16)
	var l := Style.label(title, Style.BODY, Style.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = 1.3
	row.add_child(control)
	return row


## A setting's name over a slider, with its value said at the right. `setter(value, save)`
## is called as it moves (save false) and when it's let go (save true).
func _slider_row(title: String, value: float, lo: float, hi: float, setter: Callable, say: Callable) -> Control:
	var box := VBoxContainer.new()
	box.name = "Setting_" + title.replace(" ", "")
	box.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new()
	var t := Style.label(title, Style.BODY, Style.TEXT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var shown := Style.label(String(say.call(value)), Style.SMALL, Style.MUTED)
	shown.name = "Value"
	head.add_child(shown)
	box.add_child(head)
	var slider := HSlider.new()
	slider.name = "Slider_" + title.replace(" ", "")
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, Style.TOUCH * 0.7)
	slider.accessibility_name = title
	_style_slider(slider)
	slider.value_changed.connect(func(v: float):
		shown.text = String(say.call(v))
		_slid = true
		setter.call(v, false))
	slider.drag_ended.connect(func(_changed: bool):
		_slid = false
		setter.call(slider.value, true))
	box.add_child(slider)
	return box


static func _percent(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


static func _times(v: float) -> String:
	return "×%.2f" % v


## A brass slider: a dark groove, filled brass up to a round grabber.
static func _style_slider(slider: HSlider) -> void:
	var groove := Style.box(Style.NIGHT, Style.RULE, 2, 8)
	groove.content_margin_top = 6
	groove.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", groove)
	var fill := Style.box(Style.BRASS, Color(0, 0, 0, 0), 0, 8)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", _knob(Style.BRASS))
	slider.add_theme_icon_override("grabber_highlight", _knob(Style.BRASS.lightened(0.2)))
	slider.add_theme_icon_override("grabber_disabled", _knob(Style.MUTED))


static var _knobs := {}


static func _knob(col: Color) -> Texture2D:
	var key := col.to_html()
	if _knobs.has(key):
		return _knobs[key]
	var n := 40
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a := clampf(n * 0.5 - 1.0 - d, 0.0, 1.0)
			var ink := Style.BRASS_INK if d > n * 0.5 - 4.0 else col
			img.set_pixel(x, y, Color(ink, a))
	var tex := ImageTexture.create_from_image(img)
	_knobs[key] = tex
	return tex


func _exit_tree() -> void:
	# A keyboard moved a slider (no drag to end): write the settings now.
	if _slid:
		Sound.set_sound_volume(Sound.sound_volume)


func _back() -> void:
	Scenes.go(Scenes.settings_return)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
