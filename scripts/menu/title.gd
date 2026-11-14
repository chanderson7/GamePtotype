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
const SaveSlots = preload("res://scripts/save_slots.gd")
const Opening = preload("res://scripts/menu/opening.gd")
const NewCampaign = preload("res://scripts/menu/new_campaign.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
## The wordmark: the three banners beside the name, and the tagline.
const WORDMARK := "res://assets/branding/wordmark.png"
## The light over the title's map: early morning.
const DAWN := Color(1.0, 0.88, 0.76)

var _new_button: Button
var _backdrop
var _sky: ColorRect
var _drift := 0.0
## The people picked on the first screen.
var _picked := Cultures.VARDISH


func _ready() -> void:
	theme = Style.make_theme()
	# Headless smoke test: `-- --autoplay` starts a Vardish campaign and rides out.
	if Scenes.autoplay():
		GameState.new_campaign(Cultures.VARDISH)
		get_tree().change_scene_to_file.call_deferred("res://scenes/world_map.tscn")
		return
	# A first visit hears the Glass Sea; with a campaign under way, your own realm's tune by
	# the campfire, the fire crackling under it.
	if GameState.has_campaign():
		Sound.play_music("camp_" + GameState.culture)
		Sound.set_loop("camp")
	else:
		Sound.play_music("title")
	_build()


func _exit_tree() -> void:
	Sound.set_loop("")


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
	Page.cap_width(margin, 32)
	margin.add_theme_constant_override("margin_top", 44 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var campaign: bool = GameState.has_campaign()
	var title := _title(80 if campaign else 92)
	col.add_child(title)
	if title.get_node_or_null("Wordmark") == null:
		# No wordmark to show: the name in the display face, and the sea under it.
		var sub := Style.label("The Glass Sea", Style.BODY, Color("d9dcea"))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sub)
	# No campaign, but the autosave was there and couldn't load, or other saves remain:
	# say so and offer those saves, never the first-time screen alone (its next tap would
	# start over).
	var saves_left: bool = not SaveSlots.list().is_empty()
	var stranded: bool = not campaign and (GameState.load_problem != "" or saves_left)
	if campaign:
		col.add_child(_campaign_card())
	elif stranded:
		col.add_child(_stranded_card(saves_left))
		if not saves_left:
			_build_first_time(col)
	else:
		_build_first_time(col)
	# The rest, small, in a row along the bottom.
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_left", 32)
	bar.add_theme_constant_override("margin_right", 32)
	Page.cap_width(bar, 32)
	bar.add_theme_constant_override("margin_top", 10)
	bar.add_theme_constant_override("margin_bottom", 18 + int(insets["bottom"]))
	frame.add_child(bar)
	var row := HBoxContainer.new()
	row.name = "MinorButtons"
	row.add_theme_constant_override("separation", 12)
	# The first time, the big Begin stands over the row, always on screen whatever the
	# phone: the peoples' cards above it scroll.
	if _new_button != null and _new_button.get_parent() == null:
		var bottom := VBoxContainer.new()
		bottom.add_theme_constant_override("separation", 12)
		bar.add_child(bottom)
		bottom.add_child(_new_button)
		bottom.add_child(row)
	else:
		bar.add_child(row)
	if campaign or (stranded and saves_left):
		_new_button = _minor("New campaign", "plus", _on_new)
		_new_button.add_theme_color_override("font_color", Color("c9a9a2"))
		_new_button.add_theme_color_override("icon_normal_color", Color("c9a9a2"))
		row.add_child(_new_button)
	# The first time, Learn to play stands up top by the peoples, not down here.
	if find_child("FirstLearn", true, false) == null:
		row.add_child(_minor("Learn to play", "book", _on_learn))
	row.add_child(_minor("Settings", "gear", func():
		Scenes.settings_return = "res://scenes/title.tscn"
		Scenes.go("res://scenes/settings.tscn")))
	if not Style.motion_reduced():
		col.modulate.a = 0.0
		col.create_tween().tween_property(col, "modulate:a", 1.0, 0.35)
	# The first time Home opens this launch, the opening plays over it: the boot splash
	# comes to life and its title rises into this one.
	if Opening.wanted():
		Opening.played = true
		var layer := CanvasLayer.new()
		layer.name = "Opening"
		layer.layer = 50
		add_child(layer)
		var opening := Opening.new()
		layer.add_child(opening)
		opening.setup(title)


## The title: the wordmark, painted, over the word "Bannerfall" set clear. The opening
## raises a copy of this label (wordmark and all) into its place, so the hand-over is
## the same picture. With no wordmark file, the word itself shows in the display face.
func _title(size: int) -> Label:
	var title := Style.label("Bannerfall", size, Style.BRASS)
	title.name = "HomeTitle"
	# The name is the game's mark, not text to read: it keeps its size whatever the text
	# setting, so the painted wordmark (a little wider than the word) stays on the screen.
	title.add_theme_font_size_override("font_size", size)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	var tex := _wordmark()
	if tex == null:
		return title
	title.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	var mark := TextureRect.new()
	mark.name = "Wordmark"
	mark.texture = tex
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A little wider than the word and twice as tall, so the banners and tagline fit
	# around it; proportional, so the opening's scaled copy carries it the same way.
	mark.anchor_left = -0.08
	mark.anchor_right = 1.08
	mark.anchor_top = -0.45
	mark.anchor_bottom = 1.45
	title.add_child(mark)
	return title


static var _mark_tex: Texture2D = null
static var _mark_tried := false


func _wordmark() -> Texture2D:
	if _mark_tried:
		return _mark_tex
	_mark_tried = true
	if ResourceLoader.exists(WORDMARK, "Texture2D"):
		_mark_tex = load(WORDMARK) as Texture2D
	elif FileAccess.file_exists(WORDMARK):
		var img := Image.load_from_file(WORDMARK)
		if img != null and not img.is_empty():
			_mark_tex = ImageTexture.create_from_image(img)
	return _mark_tex


## A small button with an icon over its word, for the bottom row.
func _minor(text: String, icon: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = Widgets.icon(icon)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(0, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
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
	# Where the company is: the settlement it's at, as Saves paints it; on the road, the camp.
	var here := String(w.player().node) if w != null and w.player() != null else ""
	var camp: Control
	if WorldData.SETTLEMENTS.has(here):
		camp = SettlementVista.make(here, w, 230.0)
	else:
		camp = StoryArt.location("company_camp", 230)
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
	flag.name = "CompanyBanner"
	flag.custom_minimum_size = Vector2(64, 88)
	var realm := "crown" if GameState.is_crowned() else Heraldry.realm_of_culture(GameState.culture)
	flag.draw.connect(func(): Heraldry.realm_banner(flag, realm, Rect2(Vector2.ZERO, flag.size)))
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
		names.add_child(Style.label("Known as %s" % Achievements.DEEDS[GameState.company_title]["title"], Style.SMALL, Color("f3cf7a")))
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
	var where := String(WorldData.settlement(w.player().node)["name"]) if WorldData.SETTLEMENTS.has(here) else "the road"
	var line := HBoxContainer.new()
	line.name = "WhereWhen"
	line.add_theme_constant_override("separation", 18)
	line.add_child(Widgets.icon_value("day", str(h / 24 + 1), Style.MUTED))
	line.add_child(Widgets.icon_value("sun" if h % 24 >= 6 and h % 24 < 19 else "moon", "%02d:00" % (h % 24), Style.MUTED))
	line.add_child(Widgets.icon_value("mappin", where, Style.MUTED))
	bv.add_child(line)
	# The four numbers, the same way Saves shows them: an icon and the number.
	var tiles := Widgets.tile_grid([
		Widgets.tile("men", str(GameState.total_men()), ""),
		Widgets.tile("silver", Widgets.thousands(GameState.silver), ""),
		Widgets.tile("food", str(GameState.food_days()), "days"),
		Widgets.tile("renown", str(GameState.renown), ""),
	], 4)
	tiles.name = "HomeTiles"
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bv.add_child(tiles)
	var faces := _faces()
	if faces != null:
		bv.add_child(faces)
	var waiting := _waiting()
	if not waiting.is_empty():
		bv.add_child(Widgets.section("Waiting for you"))
		for r in waiting:
			bv.add_child(r)
	var go := Button.new()
	go.name = "ContinueButton"
	go.text = "Back to the battle" if GameState.battle_waiting() else "Continue"
	go.icon = Widgets.icon("resume")
	go.custom_minimum_size = Vector2(0, 104)
	go.add_theme_font_size_override("font_size", 34)
	Style.make_primary(go)
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		go.add_theme_color_override(c, Style.BRASS_INK)
	go.pressed.connect(_on_continue)
	# The next step rides with Continue, which is what takes you there.
	var rec: Dictionary = GameState.recommendation()
	if not rec.is_empty():
		var next := HBoxContainer.new()
		next.name = "NextStepPanel"
		next.add_theme_constant_override("separation", 10)
		var ic := Widgets.icon_rect("objective", 28.0)
		ic.modulate = Color("d8cdfa")
		next.add_child(ic)
		var nl := Style.label("Next step: %s" % String(rec.get("title", "Carry on")), Style.SMALL, Color("d8cdfa"))
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.custom_minimum_size.x = 10
		nl.tooltip_text = String(rec.get("body", ""))
		next.add_child(nl)
		bv.add_child(next)
	bv.add_child(go)
	go.grab_focus.call_deferred()
	# Your other saves, under Continue. Ironman has only the one.
	var saves := SaveSlots.list().size()
	if GameState.ironman:
		var iron := Style.label("Ironman · saved as you go", Style.SMALL, Style.MUTED)
		iron.name = "IronmanNote"
		iron.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bv.add_child(iron)
	elif saves > 0:
		var load := Button.new()
		load.name = "LoadSave"
		load.text = "Load a save · %d" % saves
		load.icon = Widgets.icon("saves")
		load.add_theme_constant_override("icon_max_width", 32)
		load.custom_minimum_size = Vector2(0, Style.TOUCH)
		load.pressed.connect(func():
			Scenes.saves_return = "res://scenes/title.tscn"
			Scenes.go("res://scenes/saves.tscn"))
		bv.add_child(load)
	return card


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
	var l := Style.label(list, Style.SMALL, Style.MUTED)
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
			"%s left · +%d silver a day" % [Style.time_short(int(c["days_left"]) * 24.0), int(c.get("daily_pay", 0))], _open_warband.bind("deeds")))
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
		rows.append(_wait_row("WaitWounded", "wounded", Color("3a1d1d"), Color("ffb3a0"), hurt, hurt_sub, _open_warband.bind("companies")))
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
	var h := Style.label(head, Style.SMALL, Style.TEXT)
	h.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.custom_minimum_size.x = 10
	words.add_child(h)
	var s := Style.label(sub, Style.SMALL, Style.MUTED)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.custom_minimum_size.x = 10
	words.add_child(s)
	var arrow := Widgets.icon_rect("advance", 28.0)
	arrow.modulate = Color("6d7699")
	row.add_child(arrow)
	return b


# ---------------------------------------------------------------- no campaign loaded

## The autosave didn't load (or is gone) while other saves remain: what happened, and Load
## a save. With no other saves the first-time screen follows it.
func _stranded_card(saves_left: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "StrandedCard"
	var sb := Style.box(Color(Style.PANEL, 0.96), Color("4d4024"), 2, 26)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 22
	sb.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var ic := Widgets.icon_rect("saves", 40.0)
	ic.modulate = Style.BRASS
	head.add_child(ic)
	var title := "Your autosave is missing"
	var body := "Load one of your saves to carry on."
	if GameState.load_problem == "unreadable":
		title = "Your autosave couldn't be read"
		body = "It's kept on this device as campaign.json.bad. " + ("Your other saves are safe: load one to carry on." if saves_left else "Begin a new campaign below.")
	elif GameState.load_problem == "newer":
		title = "Your autosave is from a newer version"
		body = "It was made with a newer version of Bannerfall and is left as it is. Update the game to carry on" + (", or load another save." if saves_left else ".")
	var t := Style.label(title, Style.LARGE, Style.TEXT)
	t.name = "StrandedTitle"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	v.add_child(Page.note(body, Style.SMALL))
	if saves_left:
		var load_button := Button.new()
		load_button.name = "LoadSave"
		load_button.text = "Load a save · %d" % SaveSlots.list().size()
		load_button.icon = Widgets.icon("saves")
		load_button.add_theme_constant_override("icon_max_width", 32)
		load_button.custom_minimum_size = Vector2(0, 104)
		load_button.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE))
		Style.make_primary(load_button)
		load_button.pressed.connect(func():
			Scenes.saves_return = "res://scenes/title.tscn"
			Scenes.go("res://scenes/saves.tscn"))
		v.add_child(load_button)
		load_button.grab_focus.call_deferred()
	return card


# ---------------------------------------------------------------- first time

func _build_first_time(col: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 40
	col.add_child(gap)
	var lead := Style.label("Build a warband. Lead the battle.\nMake your name.", Style.BODY, Color("d9dcea"))
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(lead)
	# New here: the lessons first, where they can't be missed.
	var learn := PanelContainer.new()
	learn.name = "FirstLearn"
	var lb := Style.box(Style.PANEL, Style.BRASS, 2, 20)
	lb.set_content_margin_all(16)
	learn.add_theme_stylebox_override("panel", lb)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	learn.add_child(lv)
	var new_here := Style.label("New to Bannerfall? Six short lessons show how to ride, pay your men and fight.", Style.SMALL, Style.TEXT)
	new_here.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(new_here)
	var learn_button := Page.button("Learn to play", _on_learn)
	learn_button.name = "LearnToPlay"
	learn_button.icon = Widgets.icon("book")
	lv.add_child(learn_button)
	col.add_child(learn)
	var hd := Widgets.section("Begin your warband")
	hd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hd)
	# The same card New campaign shows, tappable as a whole to pick it.
	for c in Cultures.ORDER:
		var card := NewCampaign.people_card(c, 150.0)
		var tap := Button.new()
		tap.name = "People_%s" % c
		tap.toggle_mode = true
		tap.tooltip_text = String(Cultures.info(c)["people"])
		var clear := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			tap.add_theme_stylebox_override(st, clear)
		tap.add_theme_stylebox_override("focus", Style.box(Color(0, 0, 0, 0), Color(Style.BRASS, 0.6), 2, 20))
		tap.pressed.connect(_pick_people.bind(c))
		card.add_child(tap)
		col.add_child(card)
	_new_button = Button.new()
	_new_button.name = "BeginButton"
	_new_button.custom_minimum_size = Vector2(0, 104)
	_new_button.add_theme_font_size_override("font_size", Style.text_size(Style.LARGE))
	Style.make_primary(_new_button)
	_new_button.pressed.connect(_on_new)
	# Not in the column: _build puts it in the bar at the bottom of the screen.
	_pick_people(_picked)
	_new_button.grab_focus.call_deferred()


## The lessons, back to Home after.
func _on_learn() -> void:
	Scenes.tutorial_return = "res://scenes/title.tscn"
	Scenes.go("res://scenes/tutorial.tscn")


## Picks a people on the first screen: its card lights up and the big button names it.
func _pick_people(culture: String) -> void:
	_picked = culture
	for c in Cultures.ORDER:
		var tap := find_child("People_%s" % c, true, false) as Button
		if tap == null:
			continue
		var on: bool = c == culture
		tap.button_pressed = on
		NewCampaign.light_card(tap.get_parent() as PanelContainer, on)
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


## Full frames while the opening plays over Home (see FramePacer).
func keeps_full_pace() -> bool:
	return get_node_or_null("Opening") != null


func _on_continue() -> void:
	# A battle the phone closed mid-fight picks up where it was.
	Scenes.go("res://scenes/battle.tscn" if GameState.battle_waiting() else "res://scenes/world_map.tscn")


## A deliberate confirmation replaces the timed second tap. Starting over deletes every
## save, so it asks whenever there's anything to lose: a campaign, saves of your own or
## kept for you, or an autosave this version can't read but a newer one can.
func _on_new() -> void:
	var saves_left: bool = not SaveSlots.list().is_empty()
	if not GameState.has_campaign() and not saves_left and GameState.load_problem != "newer":
		Scenes.new_campaign_pick = _picked
		Scenes.go("res://scenes/new_campaign.tscn")
		return
	if has_node("NewCampaignSheet"):
		return
	var col := Widgets.sheet(self, "Start again?", "NewCampaignSheet")
	var lose := "Choosing a people replaces your saved campaign. Its progress will be lost."
	if not GameState.has_campaign():
		lose = "Choosing a people starts a new campaign. Your saves will be deleted." if saves_left \
			else "Choosing a people starts a new campaign in place of the autosave from a newer version."
	col.add_child(Page.note(lose))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var replace := Page.button("Choose a new people", func(): Scenes.go("res://scenes/new_campaign.tscn"))
	replace.name = "ReplaceCampaign"
	replace.add_theme_color_override("font_color", Style.ENEMY_LIGHT)
	replace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(replace)
	var keep := Page.button("Keep my campaign", func(): Widgets.close_sheet(col), true)
	keep.name = "KeepCampaign"
	keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(keep)
	keep.grab_focus.call_deferred()
