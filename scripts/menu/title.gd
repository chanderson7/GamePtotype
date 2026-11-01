## Home: your company on a card (where you are, what you have, your captains, and what's
## waiting for you) over the Glass Sea at dawn, drifting slowly past; or, the first time,
## the three peoples to begin with.
extends Control

const Style = preload("res://scripts/ui/style.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const MapBackdrop = preload("res://scripts/world/map_backdrop.gd")
const SKY_SHADER = preload("res://shaders/map_sky.gdshader")
const StoryArt = preload("res://scripts/ui/story_art.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Achievements = preload("res://scripts/data/achievements.gd")
## The light over the title's map: early morning.
const DAWN := Color(1.0, 0.88, 0.76)

var _confirmation: ConfirmationDialog
var _new_button: Button
var _backdrop
var _sky: ColorRect
var _drift := 0.0
## The people picked on the first screen.
var _picked := Cultures.VARDISH


func _ready() -> void:
	theme = Style.make_theme()
	# Headless smoke test: `-- --autoplay` starts a Vardish campaign and rides out.
	if OS.get_cmdline_user_args().has("--autoplay"):
		GameState.new_campaign(Cultures.VARDISH)
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn")
		return
	Sound.play_music("title")
	_build()


func _build() -> void:
	# The sea fills the screen; the land sits on it (both drawn below this screen's own
	# controls).
	_backdrop = MapBackdrop.new()
	add_child(_backdrop)
	_sky = ColorRect.new()
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.material = _backdrop.shader_material(SKY_SHADER)
	(_sky.material as ShaderMaterial).set_shader_parameter("daylight", DAWN)
	add_child(_sky)
	# The map shows through at the top and darkens behind the card.
	var veil := Control.new()
	veil.name = "Veil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.draw.connect(func():
		var sz := veil.size
		var steps := 40
		for i in steps:
			var t := float(i) / float(steps - 1)
			var a := lerpf(0.25, 0.45, clampf(t / 0.16, 0.0, 1.0)) if t < 0.16 else lerpf(0.45, 0.93, clampf((t - 0.16) / 0.16, 0.0, 1.0))
			if t > 0.32:
				a = lerpf(0.93, 0.97, (t - 0.32) / 0.68)
			veil.draw_rect(Rect2(0, sz.y * float(i) / steps, sz.x, sz.y / steps + 1.0), Color(Style.NIGHT, a)))
	add_child(veil)
	_point_backdrop()
	var insets := Style.safe_insets(get_viewport())
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 44 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var campaign: bool = GameState.has_campaign()
	var title := Style.label("Bannerfall", 80 if campaign else 92, Style.BRASS)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	col.add_child(title)
	var sub := Style.label("The Glass Sea", Style.BODY, Color("d9dcea"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	if campaign:
		col.add_child(_campaign_card())
	else:
		_build_first_time(col)
	# The rest, small, in a row along the bottom.
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_left", 32)
	bar.add_theme_constant_override("margin_right", 32)
	bar.add_theme_constant_override("margin_top", 10)
	bar.add_theme_constant_override("margin_bottom", 18 + int(insets["bottom"]))
	frame.add_child(bar)
	var row := HBoxContainer.new()
	row.name = "MinorButtons"
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	if campaign:
		_new_button = _minor("New campaign", "plus", _on_new)
		_new_button.add_theme_color_override("font_color", Color("c9a9a2"))
		_new_button.add_theme_color_override("icon_normal_color", Color("c9a9a2"))
		row.add_child(_new_button)
	row.add_child(_minor("Learn to play", "book", func():
		Scenes.tutorial_return = "res://scenes/title.tscn"
		Scenes.go("res://scenes/tutorial.tscn")))
	row.add_child(_minor("Settings", "gear", func():
		Scenes.settings_return = "res://scenes/title.tscn"
		Scenes.go("res://scenes/settings.tscn")))
	if not Style.motion_reduced():
		col.modulate.a = 0.0
		col.create_tween().tween_property(col, "modulate:a", 1.0, 0.35)


## A small button with an icon over its word, for the bottom row.
func _minor(text: String, icon: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = Widgets.icon(icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(0, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Style.SMALL)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(c, Style.TEXT)
	b.pressed.connect(callback)
	return b


# ---------------------------------------------------------------- your company

func _campaign_card() -> PanelContainer:
	var w = GameState.world
	var info := Cultures.info(GameState.culture)
	var card := PanelContainer.new()
	card.name = "CampaignCard"
	var sb := Style.box(Color(Style.PANEL, 0.96), Color("4d4024"), 2, 26)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	# The camp, with your banner and name over it.
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 230)
	hero.clip_contents = true
	v.add_child(hero)
	var camp := StoryArt.location("company_camp", 230)
	camp.name = "HomeCampIllustration"
	camp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(camp)
	var fade := Control.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.draw.connect(func():
		for i in 24:
			var t := float(i) / 23.0
			fade.draw_rect(Rect2(0, fade.size.y * (0.35 + 0.65 * t), fade.size.x, fade.size.y * 0.65 / 23.0 + 1.0), Color(Style.PANEL, 0.97 * t)))
	hero.add_child(fade)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 16)
	who.anchor_top = 1.0
	who.anchor_bottom = 1.0
	who.anchor_right = 1.0
	who.offset_left = 22
	who.offset_top = -96
	who.offset_bottom = -12
	hero.add_child(who)
	var flag := Control.new()
	flag.custom_minimum_size = Vector2(56, 84)
	var cloth: Color = info["color"]
	flag.draw.connect(func():
		flag.draw_line(Vector2(5, 0), Vector2(5, 84), Color("cbb27a"), 3.0)
		Heraldry.flag(flag, Vector2(7, 4), Vector2(46, 56), cloth, cloth.darkened(0.45), true))
	who.add_child(flag)
	var names := VBoxContainer.new()
	names.size_flags_vertical = Control.SIZE_SHRINK_END
	names.add_theme_constant_override("separation", 0)
	who.add_child(names)
	var nm := Style.label("Your %s warband" % info["people"], 38, Style.TEXT)
	var big: Font = Style.display_font()
	if big != null:
		nm.add_theme_font_override("font", big)
	names.add_child(nm)
	if GameState.company_title != "" and Achievements.DEEDS.has(GameState.company_title):
		names.add_child(Style.label("Known as %s" % Achievements.DEEDS[GameState.company_title]["title"], 21, Color("f3cf7a")))
	var body := MarginContainer.new()
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 22)
	body.add_theme_constant_override("margin_top", 14)
	body.add_theme_constant_override("margin_bottom", 22)
	v.add_child(body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 16)
	body.add_child(bv)
	var h := int(w.hour)
	var where := String(WorldData.settlement(w.player().node)["name"])
	var line := Style.label("Day %d · %02d:00 · near %s" % [h / 24 + 1, h % 24, where], Style.SMALL, Style.MUTED)
	line.name = "WhereWhen"
	bv.add_child(line)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	bv.add_child(tiles)
	tiles.add_child(_tile("men", str(GameState.total_men()), "men"))
	tiles.add_child(_tile("silver", Widgets.thousands(GameState.silver), "silver"))
	tiles.add_child(_tile("food", "%dd" % GameState.food_days(), "food"))
	tiles.add_child(_tile("renown", str(GameState.renown), "renown"))
	var faces := _faces()
	if faces != null:
		bv.add_child(faces)
	var waiting := _waiting()
	if not waiting.is_empty():
		bv.add_child(Style.label("WAITING FOR YOU", 19, Style.MUTED))
		for r in waiting:
			bv.add_child(r)
	var go := Button.new()
	go.name = "ContinueButton"
	go.text = "Continue"
	go.icon = Widgets.icon("resume")
	go.custom_minimum_size = Vector2(0, 104)
	go.add_theme_font_size_override("font_size", 34)
	Style.make_primary(go)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		go.add_theme_color_override(c, Style.BRASS_INK)
	go.pressed.connect(_on_continue)
	bv.add_child(go)
	go.grab_focus.call_deferred()
	return card


func _tile(icon: String, value: String, caption: String) -> PanelContainer:
	var t := PanelContainer.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Style.box(Style.RAISED, Style.RULE, 1, 14)
	sb.content_margin_left = 10
	sb.content_margin_right = 6
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	t.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	t.add_child(row)
	row.add_child(Widgets.icon_rect(icon, 34.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -4)
	row.add_child(v)
	v.add_child(Style.label(value, 30, Style.TEXT))
	v.add_child(Style.label(caption, 16, Style.MUTED))
	return t


## Your captains' faces in a row, and their names.
func _faces() -> Control:
	var caps := []
	for e in GameState.army:
		var c = e.get("captain")
		if typeof(c) == TYPE_DICTIONARY and CaptainArt.texture(c) != null:
			caps.append(c)
	if caps.is_empty():
		return null
	var row := HBoxContainer.new()
	row.name = "CaptainFaces"
	row.add_theme_constant_override("separation", 16)
	var stack := Control.new()
	var shown := mini(caps.size(), 6)
	stack.custom_minimum_size = Vector2(56 + (shown - 1) * 46, 76)
	row.add_child(stack)
	for i in shown:
		var c: Dictionary = caps[i]
		var frame := Panel.new()
		frame.position = Vector2(i * 46, 0)
		frame.size = Vector2(60, 76)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arch := Style.box(Color("1a2138"), Color("6a5226"), 3, 10)
		arch.corner_radius_top_left = 30
		arch.corner_radius_top_right = 30
		frame.add_theme_stylebox_override("panel", arch)
		frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		stack.add_child(frame)
		var pic := CaptainArt.portrait(c, Vector2(60, 76))
		pic.position = Vector2.ZERO
		frame.add_child(pic)
	var first := PackedStringArray()
	for c in caps:
		first.append(String(c.get("first", "")))
	var list := ", ".join(first.slice(0, first.size() - 1)) + " and " + first[first.size() - 1] if first.size() > 1 else first[0]
	var l := Style.label(list, 20, Style.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	return row


## What's pending, each a row that goes straight there: letters, a contract, the
## wounded, and the next step.
func _waiting() -> Array:
	var rows := []
	var w = GameState.world
	if w.social != null:
		var unread: Array = w.social.letters.filter(func(x): return not bool(x.get("read", false)))
		if not unread.is_empty():
			var l: Dictionary = unread[unread.size() - 1]
			var sender := String(w.social.get_person(String(l.get("sender_id", ""))).get("name", "A friend"))
			var place := String(l.get("destination", ""))
			var head := "A letter from %s" % sender
			if String(l.get("template_key", "")) == "ch2_invitation" and WorldData.SETTLEMENTS.has(place):
				head = "%s has invited you to %s" % [sender, WorldData.settlement(place)["name"]]
			var sub := "%d unread letter%s" % [unread.size(), "" if unread.size() == 1 else "s"]
			rows.append(_wait_row("WaitLetters", "mail", Color("5a4a1a"), Color("ffe08a"), head, sub, func():
				Scenes.people_return = "res://scenes/world_map.tscn"
				Scenes.people_letter = String(l["id"])
				Scenes.go("res://scenes/people.tscn")))
	var c: Dictionary = GameState.contract
	if not c.is_empty() and int(c.get("days_left", 0)) > 0 and WorldData.FACTIONS.has(String(c.get("realm", ""))):
		var realm := String(WorldData.FACTIONS[c["realm"]]["name"])
		rows.append(_wait_row("WaitContract", "keep", Color("22385e"), Color("bfe0ff"), "Contract with %s" % realm,
			"%d days left · %d silver a day" % [int(c["days_left"]), int(c.get("daily_pay", 0))], _open_warband.bind("deeds")))
	var hurt := ""
	var hurt_sub := ""
	var men := 0
	for e in GameState.army:
		men += int(e.get("wounded", 0))
		var cap = e.get("captain")
		if hurt == "" and typeof(cap) == TYPE_DICTIONARY and int(cap.get("wounded", 0)) > 0:
			hurt = "%s is wounded" % String(cap.get("first", "A captain"))
			var n := int(cap["wounded"])
			hurt_sub = "out for %d more battle%s" % [n, "" if n == 1 else "s"]
	if hurt == "" and men > 0:
		hurt = "%d men are wounded" % men
		hurt_sub = "healing in camp"
	if hurt != "":
		rows.append(_wait_row("WaitWounded", "plus", Color("3a1d1d"), Color("ffb3a0"), hurt, hurt_sub, _open_warband.bind("companies")))
	var rec: Dictionary = GameState.recommendation()
	if not rec.is_empty():
		var r := _wait_row("NextStepPanel", "renown", Color("3a3156"), Color("d8cdfa"), String(rec.get("title", "Carry on")),
			"Next step · " + String(rec.get("body", "")), _on_continue)
		rows.append(r)
	return rows


func _open_warband(tab: String) -> void:
	Scenes.warband_tab = tab
	Scenes.go("res://scenes/main_menu.tscn")


func _wait_row(name: String, icon: String, bg: Color, fg: Color, head: String, sub: String, action: Callable) -> Button:
	var b := Button.new()
	b.name = name
	b.custom_minimum_size = Vector2(0, 92)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := Style.box(Color("1a2138"), Color("2c3556"), 1, 16)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", Style.box(Color("1f2846"), Color("3d4a78"), 1, 16))
	b.add_theme_stylebox_override("pressed", Style.box(Color("141a2e"), Color("3d4a78"), 1, 16))
	b.add_theme_stylebox_override("focus", Style.box(Color(0, 0, 0, 0), Color(Style.BRASS, 0.6), 2, 16))
	b.pressed.connect(action)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var dot := PanelContainer.new()
	dot.add_theme_stylebox_override("panel", Style.box(bg, Color(0, 0, 0, 0), 0, 26))
	dot.custom_minimum_size = Vector2(52, 52)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Widgets.icon_rect(icon, 28.0)
	ic.modulate = fg
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.add_child(ic)
	row.add_child(dot)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	var h := Style.label(head, 22, Style.TEXT)
	h.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.custom_minimum_size.x = 10
	words.add_child(h)
	var s := Style.label(sub, 18, Style.MUTED)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.custom_minimum_size.x = 10
	words.add_child(s)
	var arrow := Style.label("›", 34, Color("6d7699"))
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	return b


# ---------------------------------------------------------------- first time

func _build_first_time(col: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 90
	col.add_child(gap)
	var lead := Style.label("Build a company. Lead the battle.\nMake your name.", Style.BODY, Color("d9dcea"))
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lead)
	var hd := Style.label("BEGIN YOUR COMPANY", 19, Style.MUTED)
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hd)
	for c in Cultures.ORDER:
		col.add_child(_people_card(c))
	_new_button = Button.new()
	_new_button.name = "BeginButton"
	_new_button.custom_minimum_size = Vector2(0, 104)
	_new_button.add_theme_font_size_override("font_size", 32)
	Style.make_primary(_new_button)
	_new_button.pressed.connect(_on_new)
	col.add_child(_new_button)
	_pick_people(_picked)
	_new_button.grab_focus.call_deferred()


const STRENGTHS := {
	"vardish": ["Shield walls", "Crossbows", "Knights"],
	"kharzani": ["Horse archers", "Javelins", "Fast"],
	"ryumon": ["Longbows", "Spear blocks", "Samurai"],
}


func _people_card(culture: String) -> Button:
	var info := Cultures.info(culture)
	var b := Button.new()
	b.name = "People_%s" % culture
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 210)
	b.pressed.connect(_pick_people.bind(culture))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20
	row.offset_right = -20
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var flag := Control.new()
	flag.custom_minimum_size = Vector2(70, 110)
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cloth: Color = info["color"]
	flag.draw.connect(func():
		flag.draw_line(Vector2(6, 0), Vector2(6, 110), Color("cbb27a"), 3.0)
		Heraldry.flag(flag, Vector2(8, 6), Vector2(58, 76), cloth, cloth.darkened(0.45), true))
	row.add_child(flag)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var nm := Style.label(String(info["people"]), 36, Style.TEXT)
	var big: Font = Style.display_font()
	if big != null:
		nm.add_theme_font_override("font", big)
	v.add_child(nm)
	v.add_child(Style.label(String(info["realm"]), 19, Style.BRASS))
	var bl := Style.label(String(info["blurb"]), 19, Color("c9cfdf"))
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(bl)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(chips)
	for s in STRENGTHS.get(culture, []):
		var chip := PanelContainer.new()
		var cs := Style.box(Color("262c40"), Color("3a425e"), 1, 12)
		cs.content_margin_left = 10
		cs.content_margin_right = 10
		chip.add_theme_stylebox_override("panel", cs)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(Style.label(String(s), 16, Color("c9cfdf")))
		chips.add_child(chip)
	return b


## Picks a people on the first screen: its card lights up and the big button names it.
func _pick_people(culture: String) -> void:
	_picked = culture
	for c in Cultures.ORDER:
		var card := find_child("People_%s" % c, true, false) as Button
		if card == null:
			continue
		var on: bool = c == culture
		card.button_pressed = on
		var sb := Style.box(Color(Style.PANEL, 0.96), Style.BRASS if on else Style.RULE, 3 if on else 1, 22)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			card.add_theme_stylebox_override(st, sb)
	if _new_button != null:
		_new_button.text = "Begin as the %s" % Cultures.info(culture)["people"]


func _process(delta: float) -> void:
	if _backdrop != null:
		if not Style.motion_reduced():
			_drift += delta
		_point_backdrop()


## The camera drifts in a slow loop over the three realms.
func _point_backdrop() -> void:
	var vs := get_viewport_rect().size
	var center := Vector2(500.0 + cos(_drift * 0.035) * 250.0, 800.0 + sin(_drift * 0.024) * 480.0)
	_backdrop.point_camera(center, vs.x / 560.0, vs * 0.5, vs, [_sky])


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 92)
	b.add_theme_font_size_override("font_size", Style.LARGE)
	b.pressed.connect(callback)
	return b


func _on_continue() -> void:
	Scenes.go("res://scenes/world_map.tscn")


## A deliberate confirmation replaces the timed second tap.
func _on_new() -> void:
	if not GameState.has_campaign():
		Scenes.new_campaign_pick = _picked
		Scenes.go("res://scenes/new_campaign.tscn")
		return
	if _confirmation == null:
		_confirmation = ConfirmationDialog.new()
		_confirmation.title = "Start a new campaign?"
		_confirmation.dialog_text = "Choosing a people will replace your saved campaign.\nYour current progress will be lost."
		_confirmation.ok_button_text = "Choose a new people"
		_confirmation.cancel_button_text = "Keep my campaign"
		_confirmation.confirmed.connect(func(): Scenes.go("res://scenes/new_campaign.tscn"))
		add_child(_confirmation)
	_confirmation.popup_centered(Vector2i(620, 260))
	_confirmation.get_cancel_button().grab_focus()
