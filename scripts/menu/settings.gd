## Device settings live outside the warband; returning never advances the campaign.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const SoundToggles = preload("res://scripts/ui/sound_toggles.gd")

func _ready() -> void:
	var col := Page.column(self, "Settings", "Changes save automatically on this device.")
	col.add_child(Page.note("AUDIO"))
	col.add_child(SoundToggles.make())
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
	back.grab_focus()

func _back() -> void:
	Scenes.go(Scenes.settings_return)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
