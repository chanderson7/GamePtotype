## Device settings live outside the warband; returning never advances the campaign.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const SaveSlots = preload("res://scripts/save_slots.gd")

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var col := Page.column(self, "Settings", "Changes save automatically on this device.")
	col.add_child(Page.note("SOUND"))
	col.add_child(_switch_row("Music", "", Sound.music_on, Sound.set_music_on))
	col.add_child(_switch_row("Sound effects", "", Sound.sounds_on, Sound.set_sounds_on, "Sound"))
	col.add_child(Page.note("READING & MOTION"))
	col.add_child(Page.note("Text size", Style.BODY, Style.TEXT))
	var sizes := [1.0, 1.25, 1.5]
	var size_bar := Widgets.segmented(["100%", "125%", "150%"], maxi(0, sizes.find(Sound.text_scale)), func(i: int):
		Sound.set_text_scale(sizes[i])
		_build(), "TextSize")
	col.add_child(size_bar)
	col.add_child(_switch_row("Reduced motion", "No opening, menu scaling, Home drift or battle shake", Sound.reduced_motion, func(on: bool):
		Sound.set_reduced_motion(on)))
	col.add_child(Page.note("Screen shake in battle", Style.BODY, Style.TEXT))
	var shakes := [0.0, 0.5, 1.0]
	col.add_child(Widgets.segmented(["Off", "Light", "Full"], maxi(0, shakes.find(Sound.shake)), func(i: int):
		Sound.set_shake(shakes[i]), "ScreenShake"))
	col.add_child(_switch_row("Illustrations", "Scenes and portraits throughout the game", Sound.illustrations_enabled, func(on: bool):
		Sound.set_illustrations(on)))
	col.add_child(_switch_row("Vibration", "", Sound.haptics_enabled, func(on: bool):
		Sound.set_haptics(on)))
	col.add_child(_switch_row("Show performance", "What each battle frame costs, at the bottom of the field", Sound.show_performance, func(on: bool):
		Sound.set_show_performance(on)
		_build()))
	if Sound.show_performance:
		# Twelve companies a side, the computer commanding both; your campaign isn't touched.
		var test := Page.button("Test battle: 12 against 12", func():
			if load("res://scripts/battle/battle_screen.gd").test_battle(GameState.culture if GameState.culture != "" else "vardish"):
				Scenes.go("res://scenes/battle.tscn"))
		test.name = "TestBattle"
		col.add_child(test)
	col.add_child(Page.note("STORY"))
	col.add_child(_switch_row("Romance invitations", "Friendships and house pacts stay either way", Sound.romance_invitations_enabled(), func(on: bool):
		Sound.set_romance_invitations(on)))
	col.add_child(Page.note("CAMPAIGN MODE"))
	col.add_child(Widgets.segmented(["Iron Company", "Casual"], 1 if GameState.casual_mode else 0, func(i: int):
		GameState.casual_mode = i == 1
		GameState.save_game()
		_build(), "CampaignMode"))
	col.add_child(Page.note("In Iron Company, fallen captains can die for good. In Casual, they take severe wounds instead.", Style.SMALL))
	if GameState.has_campaign():
		col.add_child(Page.note("SAVING"))
		var saving := Page.note("Ironman: the game keeps one save as you go, and there's no going back. Chosen when the campaign began." if GameState.ironman
			else "Save your own from the campaign menu (up to %d). The game also keeps one before each battle and one when you enter a settlement." % SaveSlots.MAX_OWN, Style.SMALL)
		saving.name = "SavingNote"
		col.add_child(saving)
	col.add_child(Page.note("LEARN TO PLAY"))
	col.add_child(Page.button("Open tutorial", func():
		Scenes.tutorial_return = "res://scenes/settings.tscn"
		Scenes.go("res://scenes/tutorial.tscn")))
	var back := Page.button("Back", _back, true)
	col.add_child(back)
	var heading := col.get_child(0) as Control
	heading.focus_mode = Control.FOCUS_ALL
	# Focus starts at the top for keyboards and screen readers, without a box drawn round the title.
	heading.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	heading.grab_focus()

## A setting with an on/off switch at the right, and a short note under its name.
func _switch_row(title: String, note: String, on: bool, setter: Callable, word: String = "") -> Control:
	var row := HBoxContainer.new()
	row.name = "Setting_" + title.replace(" ", "")
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 76)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	words.add_child(Style.label(title, Style.BODY, Style.TEXT))
	if note != "":
		var n := Style.label(note, Style.SMALL, Style.MUTED)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(n)
	row.add_child(words)
	row.add_child(Widgets.switch(on, setter, "Switch_" + title.replace(" ", ""), word if word != "" else title))
	return row


func _back() -> void:
	Scenes.go(Scenes.settings_return)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
