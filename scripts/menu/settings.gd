## Device settings live outside the warband; returning never advances the campaign.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const SoundToggles = preload("res://scripts/ui/sound_toggles.gd")

func _ready() -> void:
	_build()

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var col := Page.column(self, "Settings", "Changes save automatically on this device.")
	col.add_child(Page.note("AUDIO"))
	col.add_child(SoundToggles.make())
	col.add_child(Page.note("READING & PRESENTATION"))
	col.add_child(Page.note("Larger text for dialogue and shared menus. Reduced motion removes menu scaling, Home drift and battle shake."))
	col.add_child(Page.button("Text size: %d%%" % roundi(Sound.text_scale * 100.0), func():
		var sizes := [1.0, 1.25, 1.5]
		Sound.set_text_scale(sizes[(sizes.find(Sound.text_scale) + 1) % sizes.size()])
		_build()))
	col.add_child(Page.button("Reduced motion: %s" % ("on" if Sound.reduced_motion else "off"), func():
		Sound.set_reduced_motion(not Sound.reduced_motion)
		_build()))
	col.add_child(Page.button("Illustrations: %s" % ("on" if Sound.illustrations_enabled else "off"), func():
		Sound.set_illustrations(not Sound.illustrations_enabled)
		_build()))
	col.add_child(Page.note("LEARN TO PLAY"))
	col.add_child(Page.note("Take a short walkthrough of travel, supplies, battles and captains. You can leave at any time."))
	col.add_child(Page.button("Open tutorial", func():
		Scenes.tutorial_return = "res://scenes/settings.tscn"
		Scenes.go("res://scenes/tutorial.tscn")))
	col.add_child(Page.note("ROMANCE INVITATIONS"))
	col.add_child(Page.note("Controls unsolicited romantic dialogue and prompts. Friendships and house pacts remain available."))
	var rom_btn: Button = null
	var update_rom_text = func():
		if rom_btn != null:
			rom_btn.text = "Romance invitations: %s" % ("Enabled" if Sound.romance_invitations_enabled() else "Disabled")
	rom_btn = Page.button("Romance invitations: %s" % ("Enabled" if Sound.romance_invitations_enabled() else "Disabled"), func():
		Sound.set_romance_invitations(not Sound.romance_invitations_enabled())
		update_rom_text.call())
	col.add_child(rom_btn)
	var back := Page.button("Back", _back, true)
	col.add_child(back)
	var heading := col.get_child(0) as Control
	heading.focus_mode = Control.FOCUS_ALL
	heading.grab_focus()

func _back() -> void:
	Scenes.go(Scenes.settings_return)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
