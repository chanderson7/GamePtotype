## Credits and licences, from Settings: who made what the game is built from, and the
## licences that come with it. Godot's own notice and its components' come from the engine
## (Engine.get_license_text, get_copyright_info, get_license_info); the fonts' licence is
## shipped beside them (assets/fonts/OFL.txt, in every preset's include filter). A licence's
## full text is shown only when asked for: all of them together run to some 80,000 letters.
extends Control
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
## Room for the bottom bar under the page, above the safe area.
const BAR_ROOM := 124.0
const FONT_LICENSE := "res://assets/fonts/OFL.txt"


func _ready() -> void:
	var insets := Style.safe_insets(get_viewport())
	var col := Page.frame(self, BAR_ROOM + float(insets["bottom"]))
	var heading := Style.label("Credits & licences", 52, Style.BRASS)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(heading)
	col.add_child(Page.note("%s %s" % [ProjectSettings.get_setting("application/config/name", "Bannerfall"),
		ProjectSettings.get_setting("application/config/version", "")], Style.SMALL))

	col.add_child(Widgets.section("Music and sound"))
	col.add_child(Page.note("The orchestra plays instruments recorded for the VS Chamber Orchestra Community Edition by Versilian Studios, given to the public domain (CC0). The battle's blows are built from its recorded metal and wood; every other sound is made for the game.", Style.SMALL, Style.TEXT))

	col.add_child(Widgets.section("Fonts"))
	col.add_child(Page.note("Cinzel, copyright 2020 The Cinzel Project Authors.\nIM FELL English, copyright 2007 Igino Marini, with Reserved Font Name IM FELL English.\nBoth under the SIL Open Font License 1.1.", Style.SMALL, Style.TEXT))
	var ofl := FileAccess.get_file_as_string(FONT_LICENSE) if FileAccess.file_exists(FONT_LICENSE) else ""
	col.add_child(_unfolding("SIL Open Font License 1.1", func(): return reflow(ofl) if ofl != "" else "https://openfontlicense.org", "Licence_OFL"))

	col.add_child(Widgets.section("Godot Engine"))
	col.add_child(Page.note("Made with the Godot Engine (godotengine.org).", Style.SMALL, Style.TEXT))
	var godot := Page.note(reflow(Engine.get_license_text()), Style.SMALL)
	godot.name = "GodotLicense"
	col.add_child(godot)

	col.add_child(Widgets.section("Parts of the engine"))
	col.add_child(Page.note("The Godot Engine is built with these, each under the licence named; the licences' words follow.", Style.SMALL))
	var parts := VBoxContainer.new()
	parts.name = "Components"
	parts.add_theme_constant_override("separation", 10)
	for c in Engine.get_copyright_info():
		if String(c.get("name", "")) == "Godot Engine":
			continue
		var lines := PackedStringArray()
		var licences := PackedStringArray()
		for part in c.get("parts", []):
			for who in part.get("copyright", []):
				if not lines.has(String(who)):
					lines.append(String(who))
			if not licences.has(String(part.get("license", ""))):
				licences.append(String(part.get("license", "")))
		var row := Page.note("%s\n© %s\n%s" % [c["name"], "; ".join(lines), ", ".join(licences)], Style.SMALL)
		parts.add_child(row)
	col.add_child(parts)

	col.add_child(Widgets.section("Licence texts"))
	var info := Engine.get_license_info()
	var names := info.keys()
	names.sort()
	for n in names:
		var key := String(n)
		col.add_child(_unfolding(key, func(): return reflow(String(info[key])), "Licence_" + key.validate_node_name()))

	var bar := Widgets.bottom_bar(Widgets.back_button(_back), insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	heading.focus_mode = Control.FOCUS_ALL
	heading.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	heading.grab_focus()


## A licence's words as paragraphs that wrap to the phone: a line the text was broken at
## (they're set for an 80-column screen) runs on into the next; short lines (headings,
## list items), rules of dashes and blank lines stay as they are.
static func reflow(text: String) -> String:
	var out := PackedStringArray()
	var last := ""
	for line in text.replace("\r", "").split("\n"):
		var t := line.strip_edges()
		var rule := t != "" and t.replace("-", "").replace("=", "").replace("*", "").strip_edges() == ""
		var runs_on := last.length() >= 50 and not last.ends_with(")") and not last.ends_with("-") and not rule
		if t != "" and runs_on and not out.is_empty():
			out[out.size() - 1] = out[out.size() - 1] + " " + t
		else:
			out.append(t)
		last = line.strip_edges() if t != "" else ""
	return "\n".join(out)


## A licence by name that opens to its full words when tapped (written out then, not before).
func _unfolding(title: String, words: Callable, node_name: String) -> Control:
	var box := VBoxContainer.new()
	box.name = node_name
	box.add_theme_constant_override("separation", 6)
	var toggle := Button.new()
	toggle.name = "Toggle"
	toggle.text = title
	toggle.flat = true
	toggle.toggle_mode = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.icon = Widgets.icon("book")
	toggle.custom_minimum_size = Vector2(0, Style.TOUCH)
	toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	box.add_child(toggle)
	var text := Page.note("", Style.SMALL)
	text.name = "Text"
	text.visible = false
	box.add_child(text)
	toggle.toggled.connect(func(on: bool):
		if on and text.text == "":
			text.text = String(words.call())
		text.visible = on)
	return box


func _back() -> void:
	Scenes.go("res://scenes/settings.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
