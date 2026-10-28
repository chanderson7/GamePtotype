## Two buttons, Music and Sound, each switching itself on and off. Used on the
## dedicated Settings page.
extends RefCounted

const Style = preload("res://scripts/ui/style.gd")


static func make() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_toggle("Music", Sound.music_on, Sound.set_music_on))
	row.add_child(_toggle("Sound", Sound.sounds_on, Sound.set_sounds_on))
	return row


static func _toggle(word: String, on: bool, setter: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Style.SMALL)
	b.toggle_mode = true
	b.button_pressed = on
	b.text = "%s: %s" % [word, "on" if on else "off"]
	b.toggled.connect(func(now: bool):
		setter.call(now)
		b.text = "%s: %s" % [word, "on" if now else "off"])
	return b
