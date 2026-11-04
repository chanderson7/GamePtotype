## People & Letters: the people you court or befriend (a card each, and a page of their
## own), house pacts, and the letters they send you, which you can read and answer.
## The screen pauses the map; nothing here spends time except riding off to someone.
extends Control

const StoryArt = preload("res://scripts/ui/story_art.gd")
const Page = preload("res://scripts/ui/menu_page.gd")
const Style = preload("res://scripts/ui/style.gd")
const Widgets = preload("res://scripts/ui/widgets.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const Letters = preload("res://scripts/data/letters.gd")
const WorldData = preload("res://scripts/world/world_data.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const Lords = preload("res://scripts/data/lords.gd")

const CANDIDATES := [RomanceStories.EDDA, RomanceStories.FARID, RomanceStories.KAEDE]
const ROSE := Color("e88aa0")
const PARCHMENT := Color("ecdcb4")
const INK := Color("3a2a16")
const INK_SOFT := Color("6b5230")
const CHAPTERS := 5

var _tab := "people" # "people", "lords", "pacts", "letters"
## Which lords the Lords tab shows: "met", "swear", "war", "crown".
var _lord_filter := "met"
## The person whose page is open, the letter being read, and the reply being previewed.
var _person := ""
var _letter := ""
var _reply := ""
var _scroll: ScrollContainer
var _flash := ""
## Whether the profile shows every memory, or the latest few.
var _all_memories := false


func _ready() -> void:
	if Scenes.people_tab != "":
		_tab = Scenes.people_tab
		Scenes.people_tab = ""
	if Scenes.people_letter != "":
		_tab = "letters"
		_letter = Scenes.people_letter
		Scenes.people_letter = ""
	_build()


func _social():
	var w = GameState.world
	return w.social if w != null else null


# ---------------------------------------------------------------- frame

func _build() -> void:
	for child in get_children():
		child.queue_free()
	theme = Style.make_theme()
	var bg := ColorRect.new()
	bg.color = Color("120e0a") if _letter != "" else Style.NIGHT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var insets := Style.safe_insets(get_viewport())
	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 36 + int(insets["top"]))
	margin.add_theme_constant_override("margin_bottom", 24)
	_scroll.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var social = _social()
	if social == null:
		col.add_child(Page.note("No active world or social records."))
		frame.add_child(_bar([_back_button()], insets))
		return
	if _letter != "":
		_build_reader(col, frame, insets)
		return
	if _person != "":
		_build_profile(col, frame, insets)
		return
	col.add_child(Style.label("People & Letters", 52, Style.BRASS))
	if _flash != "":
		col.add_child(Page.note(_flash, Style.SMALL, Style.BRASS))
		_flash = ""
	var unread: int = social.unread_letters_count()
	col.add_child(Widgets.tab_bar([
		{"id": "people", "label": "People", "badge": 0},
		{"id": "lords", "label": "Lords", "badge": 0},
		{"id": "pacts", "label": "Pacts", "badge": 0},
		{"id": "letters", "label": "Letters", "badge": unread},
	], _tab, _on_tab, "PeopleTabs"))
	match _tab:
		"pacts":
			_build_pacts(col)
		"letters":
			_build_letters(col)
		"lords":
			_build_lords(col)
		_:
			_build_people(col)
	frame.add_child(_bar([_back_button()], insets))


# ---------------------------------------------------------------- lords

## Every lord you've met: what they think of you, what they want, whether they'd swear,
## and where they are. Plan whom to court before riding out.
func _build_lords(col: VBoxContainer) -> void:
	var w = GameState.world
	var met: Array = w.lords.filter(func(l): return LordTalk.met(GameState, l))
	var groups := {
		"met": met,
		"swear": met.filter(func(l): return _could_swear(l)),
		"war": met.filter(func(l): return w.relation_to_player(String(l.get("realm", ""))) == "hostile"),
		"crown": met.filter(func(l): return String(l.get("realm", "")) == WorldData.CROWN),
	}
	var chips := HFlowContainer.new()
	chips.name = "LordFilters"
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	for f in [["met", "Met · %d" % met.size()], ["swear", "Could swear"], ["war", "At war"], ["crown", "Your crown"]]:
		var b := Button.new()
		b.name = "Filter_" + String(f[0])
		b.text = String(f[1])
		b.toggle_mode = true
		b.button_pressed = _lord_filter == f[0]
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		if _lord_filter == f[0]:
			Style.make_primary(b)
		var id := String(f[0])
		b.pressed.connect(func():
			_lord_filter = id
			_build())
		chips.add_child(b)
	col.add_child(chips)
	var shown: Array = groups.get(_lord_filter, met)
	if shown.is_empty():
		col.add_child(Page.note("No one yet. Lords you meet on the road, fight or hold captive are kept here." if _lord_filter == "met" else "No one here yet.", Style.SMALL))
		return
	# Your own first, then whoever thinks best of you.
	shown = shown.duplicate()
	shown.sort_custom(func(a, b):
		var ac := String(a.get("realm", "")) == WorldData.CROWN
		var bc := String(b.get("realm", "")) == WorldData.CROWN
		if ac != bc:
			return ac
		return LordTalk.regard(GameState, a) > LordTalk.regard(GameState, b))
	for l in shown:
		col.add_child(_lord_row(l))


func _could_swear(l: Dictionary) -> bool:
	if not GameState.is_crowned() or bool(l.get("ruler", false)) or String(l.get("realm", "")) == WorldData.CROWN:
		return false
	if String(l.get("captive_of", "")) == "player":
		return GameState.swear_check(int(l["id"]))["ok"]
	return LordTalk.persuade_check(GameState, l)["ok"]


func _lord_row(l: Dictionary) -> Control:
	var w = GameState.world
	var realm := String(l.get("realm", ""))
	var crown := realm == WorldData.CROWN
	var ruler := bool(l.get("ruler", false))
	var panel := PanelContainer.new()
	panel.name = "Lord_%d" % int(l["id"])
	panel.add_theme_stylebox_override("panel", Style.box(Color("2a2210") if crown else Style.PANEL, Style.BRASS if crown else Style.RULE, 2, 14))
	if ruler:
		panel.modulate = Color(1, 1, 1, 0.72)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var face := TextureRect.new()
	face.texture = CaptainArt.texture(LordVoice.portrait_record(l))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(72, 96)
	row.add_child(face)
	var flag_realm := realm if Heraldry.REALM_SIZES.has(realm) else Heraldry.realm_of_culture(String(l.get("culture", "")))
	var flag := Widgets.banner(flag_realm, Vector2(30, 46))
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(flag)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	row.add_child(words)
	var name_label := Style.label(LordTalk.short_name(l), Style.BODY, Style.TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(name_label)
	var bits := PackedStringArray()
	if crown:
		bits.append("Sworn to your crown")
	elif ruler:
		bits.append("Ruler of %s" % String(WorldData.FACTIONS[realm]["name"]) if WorldData.FACTIONS.has(realm) else "A ruler")
	else:
		bits.append(_realm_short(realm))
		bits.append(String(l.get("bearing", "")))
	if String(l.get("captive_of", "")) == "player":
		bits.append("your captive")
	elif w.relation_to_player(realm) == "hostile" and not crown:
		bits.append("at war")
	var fief := String(l.get("fief", ""))
	if fief != "" and not ruler:
		bits.append("holds %s" % WorldData.settlement(fief)["name"])
	var sub := Style.label(" · ".join(bits), Style.SMALL, Style.MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(sub)
	var value := LordTalk.regard(GameState, l)
	var tone := Style.MORALE_HIGH if value >= 10 else (Style.MORALE_MID if value >= -14 else Style.MORALE_LOW)
	words.add_child(Widgets.meter((value + 100.0) / 200.0, tone, 10.0))
	var line := "%s%d Regard" % ["+" if value > 0 else "", value]
	if ruler:
		line = "Rulers never change sides"
	else:
		var note := _lord_note(l)
		if note != "":
			line += " · " + note
	var reg := Style.label(line, Style.SMALL, tone if not ruler else Style.MUTED)
	reg.name = "RegardLine"
	reg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(reg)
	var where := _lord_place(l)
	if where != "":
		var pin := Button.new()
		pin.name = "ShowOnMap"
		pin.icon = Widgets.icon("mappin")
		pin.expand_icon = true
		pin.custom_minimum_size = Vector2(72, 72)
		pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pin.tooltip_text = "Show on map"
		pin.pressed.connect(func():
			Scenes.map_focus = where
			Scenes.go(Scenes.people_return if Scenes.people_return != "" else "res://scenes/world_map.tscn"))
		row.add_child(pin)
	return panel


## What stands out about a lord for you: the job you're doing for them, what they like if
## you've learned it, whether they'd swear.
func _lord_note(l: Dictionary) -> String:
	var t: Dictionary = l.get("talk", {}) if l.get("talk") is Dictionary else {}
	if String(t.get("job", "")) != "":
		return "your job for them"
	if String(l.get("captive_of", "")) == "player":
		if String(l.get("bearing", "")) == Lords.HONORABLE:
			return "won't swear · ransom %d" % int(l.get("ransom_amount", 0))
		return "ransom %d" % int(l.get("ransom_amount", 0))
	if int(t.get("like_known", 0)) == 1:
		return "values %s" % LordTalk.likes(l)
	if int(l.get("met_player", 0)) > 0:
		return "has fought you"
	return ""


## Where a lord is now, to look at on the map: where they ride, else their seat.
func _lord_place(l: Dictionary) -> String:
	var w = GameState.world
	var p = w.party(int(l.get("party", -1)))
	if p != null:
		return String(p.node)
	if String(l.get("state", "")) == "prisoner":
		return ""
	return w.seat_of(l)


func _realm_short(realm: String) -> String:
	if realm == WorldData.CROWN:
		return "Your crown"
	return String(WorldData.FACTIONS[realm]["name"]).replace("Kingdom of ", "").replace("Sultanate of ", "").replace(" Shogunate", "") if WorldData.FACTIONS.has(realm) else realm


func _on_tab(id: String) -> void:
	_tab = id
	_build()


## The fixed bar at the bottom: one or two buttons side by side, in thumb reach.
func _bar(buttons: Array, insets: Dictionary) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = "BottomBar"
	var box := Style.box(Style.NIGHT, Style.RULE, 0, 0)
	box.border_width_top = 2
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 14
	box.content_margin_bottom = 14 + float(insets.get("bottom", 0))
	bar.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	for i in buttons.size():
		var b: Button = buttons[i]
		b.custom_minimum_size.y = 92
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.6 if i == 0 and buttons.size() > 1 else 1.0
		row.add_child(b)
	return bar


func _back_button() -> Button:
	var b := Page.button("Back to the map" if Scenes.people_return.ends_with("world_map.tscn") else "Back", _back)
	b.name = "BackButton"
	return b


func _button(text: String, action: Callable, primary: bool = false, icon: String = "") -> Button:
	var b := Page.button(text, action, primary)
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.clip_text = true
	if icon != "":
		b.icon = Widgets.icon(icon)
		var tint := Style.BRASS_INK if primary else Style.TEXT
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(c, tint)
	return b


# ---------------------------------------------------------------- where you stand

func _candidate_person(cand: String) -> Dictionary:
	return _social().get_candidate_person(cand)


func _chapter(cand: String) -> int:
	return int(_social().get_quest("quest_%s" % cand).get("chapter", 1))


func _status(cand: String) -> String:
	return String(_social().get_relationship(cand).get("status", Relationships.UNKNOWN))


func _met(cand: String) -> bool:
	return _status(cand) != Relationships.UNKNOWN or _chapter(cand) > 1


## Which of the portrait's faces fits how they feel about you.
func _expression(cand: String) -> String:
	var status := _status(cand)
	var trust := int(_social().get_relationship(cand).get("trust", 0))
	if status == Relationships.ENDED:
		return "concerned"
	if trust >= 50 or [Relationships.COURTING, Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED].has(status):
		return "warm"
	if status == Relationships.UNKNOWN:
		return "neutral"
	return "thoughtful"


func _residence(cand: String) -> String:
	return String(_candidate_person(cand).get("residence", ""))


func _ride_text(place: String) -> String:
	var w = GameState.world
	if w == null or place == "" or w.here() == place:
		return ""
	var h: float = w.hours_to(place)
	if h <= 0.0 or h >= INF:
		return ""
	if h < 24.0:
		return "%d hrs" % maxi(1, roundi(h))
	var d := roundi(h / 24.0)
	return "%d day%s" % [d, "" if d == 1 else "s"]


func _unread_from(cand: String) -> Array:
	var out := []
	var pid := String(_candidate_person(cand).get("id", ""))
	for l in _social().letters:
		if String(l.get("sender_id", "")) == pid and not bool(l.get("read", false)):
			out.append(l)
	return out


func _chapter_title(cand: String, n: int) -> String:
	var story: Dictionary = RomanceStories.story_data(cand)
	var ch: Dictionary = story.get("chapters", {}).get(n, {})
	return String(ch.get("title", "Chapter %d" % n))


## One line on what to do next with this person.
func _next_step(cand: String) -> String:
	var p := _candidate_person(cand)
	var name := String(p.get("name", ""))
	var place := Letters.place_name(_residence(cand))
	var ride := _ride_text(_residence(cand))
	var here: bool = GameState.world.here() == _residence(cand)
	var unread := _unread_from(cand)
	if not unread.is_empty() and String(unread[0].get("template_key", "")) == "ch2_invitation":
		return "%s has invited you to %s.%s" % [name, place, (" %s' ride." % ride) if ride != "" else " You're here."]
	if not unread.is_empty():
		return "%s has written to you." % name
	if _chapter(cand) > CHAPTERS or _status(cand) == Relationships.MARRIED:
		return "Your story together is told. Spend time with %s whenever you like." % name
	if not _met(cand):
		return "Seek an audience at %s%s." % [place, (" · %s" % ride) if ride != "" else ""]
	if here:
		var object := String(RomanceStories.candidate_data(cand).get("pronouns", "they/them")).split("/")[1] if String(RomanceStories.candidate_data(cand).get("pronouns", "")).contains("/") else "them"
		return "%s is here. Speak with %s to go on." % [name, object]
	return "Meet %s at %s to go on%s." % [name, place, (" · %s' ride" % ride) if ride != "" else ""]


## The main thing to do with this person: speak (if you're there) or ride to them.
func _main_action(cand: String) -> Button:
	var p := _candidate_person(cand)
	var res := _residence(cand)
	if GameState.world.here() == res:
		var b := _button("Speak with %s" % p.get("name", ""), _speak.bind(cand), true, "talk")
		b.name = "Speak_%s" % cand
		return b
	var b2 := _button("Ride to %s" % Letters.place_name(res), _ride.bind(res), true, "ride")
	b2.name = "Ride_%s" % cand
	return b2


func _speak(cand: String) -> void:
	Scenes.active_candidate_id = cand
	Scenes.active_person_id = String(_candidate_person(cand).get("id", ""))
	Scenes.conversation_return = "res://scenes/people.tscn"
	Scenes.go("res://scenes/conversation.tscn")


func _spend_time(cand: String) -> void:
	Scenes.active_person_id = String(_candidate_person(cand).get("id", ""))
	Scenes.personal_conversation_return = "res://scenes/people.tscn"
	Scenes.go("res://scenes/personal_conversation.tscn")


## Set off for `place` and go back to the map, which shows the road.
func _ride(place: String) -> void:
	var w = GameState.world
	if w != null and place != "" and w.here() != place:
		w.travel(place)
	Scenes.map_focus = place
	GameState.save_game()
	Scenes.go("res://scenes/world_map.tscn")


func _show_on_map(place: String) -> void:
	Scenes.map_focus = place
	Scenes.go("res://scenes/world_map.tscn")


# ---------------------------------------------------------------- pieces

func _card_box(pad: int = 20) -> StyleBoxFlat:
	var sb := Style.box(Style.PANEL, Style.RULE, 2, 22)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


## A portrait in an arched brass frame.
func _framed(cand: String, size: Vector2, dim: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mask := Panel.new()
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arch := StyleBoxFlat.new()
	arch.bg_color = Color("1a2138")
	arch.corner_radius_top_left = int(size.x * 0.5)
	arch.corner_radius_top_right = int(size.x * 0.5)
	arch.corner_radius_bottom_left = 12
	arch.corner_radius_bottom_right = 12
	arch.corner_detail = 12
	mask.add_theme_stylebox_override("panel", arch)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	holder.add_child(mask)
	var pic := StoryArt.candidate_portrait(cand, _expression(cand), size.y * 1.15)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_bottom = size.y * 0.12
	if dim:
		pic.modulate = Color(0.62, 0.62, 0.68)
	mask.add_child(pic)
	var rim := Panel.new()
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var edge := arch.duplicate() as StyleBoxFlat
	edge.draw_center = false
	edge.border_color = Color("6a5226")
	edge.set_border_width_all(3)
	rim.add_theme_stylebox_override("panel", edge)
	holder.add_child(rim)
	return holder


func _chip(text: String, bg: Color, fg: Color, icon: String = "") -> PanelContainer:
	var c := PanelContainer.new()
	var sb := Style.box(bg, Color(fg, 0.35), 1, 16)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	c.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	c.add_child(row)
	if icon != "":
		var ic := Widgets.icon_rect(icon, 22.0)
		ic.modulate = fg
		row.add_child(ic)
	row.add_child(Style.label(text, 19, fg))
	return c


func _status_chip(cand: String) -> PanelContainer:
	var status := _status(cand)
	match status:
		Relationships.COURTING, Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED:
			return _chip(Relationships.status_label(status), Color("4a2232"), Color("ffc2d0"), "heart")
		Relationships.UNKNOWN:
			return _chip("Not yet met", Color("262c40"), Color("b5bcd0"))
		Relationships.ENDED:
			return _chip("Parted", Color("262c40"), Color("b5bcd0"))
	return _chip(Relationships.status_label(status), Color("22385e"), Color("bfe0ff"))


## Trust as a bar with marks where its words change (Reserved, Trusting, Devoted).
func _trust_meter(cand: String) -> Control:
	var trust := int(_social().get_relationship(cand).get("trust", 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	box.add_child(head)
	var l := Style.label("Trust · %s" % Relationships.trust_label(trust), 19, Style.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	head.add_child(Style.label("%d / 100" % trust, 19, Style.MUTED))
	var bar := Control.new()
	bar.name = "TrustBar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func():
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r, Color("0b0f19"))
		bar.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(trust / 100.0, 0.0, 1.0), r.size.y)), ROSE.darkened(0.15))
		for mark in [25, 50, 70]:
			bar.draw_rect(Rect2(r.size.x * mark / 100.0 - 1.0, -3, 3, r.size.y + 6), Color("4a5378"))
		bar.draw_rect(r, Style.RULE, false, 1.0))
	box.add_child(bar)
	return box


## Five beads for the chapters of their story, and the current one's title.
func _beads(cand: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var now := _chapter(cand)
	var dots := Control.new()
	dots.custom_minimum_size = Vector2(CHAPTERS * 34, 26)
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.draw.connect(func():
		for i in CHAPTERS:
			var c := Vector2(13 + i * 34, 13)
			if i < CHAPTERS - 1:
				dots.draw_line(c + Vector2(11, 0), c + Vector2(23, 0), Color("3a3f5a"), 3.0)
			var n := i + 1
			if n < now:
				dots.draw_circle(c, 10, Style.BRASS)
			elif n == now:
				dots.draw_circle(c, 13, Color(Style.BRASS, 0.25))
				dots.draw_circle(c, 10, Style.NIGHT)
				dots.draw_arc(c, 9, 0, TAU, 24, Style.BRASS, 3.0)
			else:
				dots.draw_arc(c, 9, 0, TAU, 24, Color("6a5226"), 3.0))
	row.add_child(dots)
	var t := Style.label("Ch. %d · %s" % [mini(now, CHAPTERS), _chapter_title(cand, mini(now, CHAPTERS))] if now <= CHAPTERS else "Story told", 20, Style.MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(t)
	return row


func _next_box(text: String, icon: String = "ride") -> PanelContainer:
	var box := PanelContainer.new()
	var sb := Style.box(Color("1a2138"), Color("2c3556"), 1, 14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var ic := Widgets.icon_rect(icon, 26.0)
	ic.modulate = Style.BRASS
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var l := Style.label(text, 21, Color("d5dae8"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return box


## Tapping anywhere on `card` that isn't a button opens `cand`'s page.
func _tap_opens(card: Control, cand: String) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(e: InputEvent):
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_open_person(cand))


func _open_person(cand: String) -> void:
	_person = cand
	_build()


# ---------------------------------------------------------------- people

func _build_people(col: VBoxContainer) -> void:
	for cand in CANDIDATES:
		var p := _candidate_person(cand)
		if p.is_empty():
			continue
		if _met(cand):
			col.add_child(_person_card(cand))
		else:
			col.add_child(_stranger_row(cand))
	# So a short list doesn't look like the whole of it.
	var more := Style.label("More people turn up as you travel: lords at court, captains' kin, envoys on the road. Anyone you meet is kept here.", Style.SMALL, Style.MUTED)
	more.name = "PeopleHint"
	more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(more)


func _person_card(cand: String) -> PanelContainer:
	var p := _candidate_person(cand)
	var card := PanelContainer.new()
	card.name = "Person_%s" % cand
	card.add_theme_stylebox_override("panel", _card_box())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	v.add_child(top)
	top.add_child(_framed(cand, Vector2(150, 196)))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 8)
	top.add_child(who)
	var nm := Style.label(String(p.get("name", "")), 40, Style.TEXT)
	var big: Font = Style.display_font()
	if big != null:
		nm.add_theme_font_override("font", big)
	who.add_child(nm)
	var role := Style.label("%s · %s" % [p.get("role", ""), Letters.place_name(_residence(cand))], 20, Style.MUTED)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_child(role)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 6)
	who.add_child(chips)
	chips.add_child(_status_chip(cand))
	var unread := _unread_from(cand)
	if not unread.is_empty():
		chips.add_child(_chip("%d unread" % unread.size() if unread.size() > 1 else "Wrote to you", Color("5a4a1a"), Color("ffe08a"), "mail"))
	who.add_child(_trust_meter(cand))
	v.add_child(_beads(cand))
	v.add_child(_next_box(_next_step(cand), "mail" if not unread.is_empty() else "ride"))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	v.add_child(acts)
	var main := _main_action(cand)
	# Its words wrap, so a long action doesn't push the card off the side of the screen.
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 1.55
	main.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	acts.add_child(main)
	var spend := _button("Spend time", _spend_time.bind(cand), false, "cup")
	spend.name = "SpendTime_%s" % cand
	spend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spend.custom_minimum_size.x = 200
	spend.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	acts.add_child(spend)
	var pin := _button("", _show_on_map.bind(_residence(cand)), false, "mappin")
	pin.tooltip_text = "Show on map"
	pin.custom_minimum_size.x = Style.TOUCH
	acts.add_child(pin)
	_tap_opens(card, cand)
	return card


func _stranger_row(cand: String) -> PanelContainer:
	var p := _candidate_person(cand)
	var card := PanelContainer.new()
	card.name = "Person_%s" % cand
	card.add_theme_stylebox_override("panel", _card_box(14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(_framed(cand, Vector2(92, 120), true))
	var who := VBoxContainer.new()
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_theme_constant_override("separation", 6)
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(who)
	var nm := Style.label(String(p.get("name", "")), 32, Style.TEXT)
	var big: Font = Style.display_font()
	if big != null:
		nm.add_theme_font_override("font", big)
	who.add_child(nm)
	var role := Style.label(String(p.get("role", "")), 20, Style.MUTED)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_child(role)
	var chips := HBoxContainer.new()
	who.add_child(chips)
	chips.add_child(_status_chip(cand))
	var ride := _ride_text(_residence(cand))
	var go := _button(ride if ride != "" else "Here", _ride.bind(_residence(cand)), false, "mappin")
	go.name = "Ride_%s" % cand
	go.custom_minimum_size = Vector2(170, Style.TOUCH)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(go)
	_tap_opens(card, cand)
	return card


# ---------------------------------------------------------------- a person's page

func _build_profile(col: VBoxContainer, frame: VBoxContainer, insets: Dictionary) -> void:
	var cand := _person
	var p := _candidate_person(cand)
	var data: Dictionary = RomanceStories.candidate_data(cand)
	var rel: Dictionary = _social().get_relationship(cand)
	var house: Dictionary = _social().get_house(String(p.get("house_id", "")))
	var top := HBoxContainer.new()
	col.add_child(top)
	var back := _button("", _close_person, false, "back")
	back.name = "ProfileBack"
	back.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	top.add_child(back)
	# The portrait, large, fading into the page.
	var hero := Control.new()
	hero.custom_minimum_size = Vector2(0, 560)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hero)
	hero.draw.connect(func():
		var r := Rect2(Vector2.ZERO, hero.size)
		for i in 24:
			var t := float(i) / 23.0
			hero.draw_rect(Rect2(0, r.size.y * t, r.size.x, r.size.y / 23.0 + 1), Color("2c3a5c").lerp(Style.NIGHT, t)))
	var pic := StoryArt.candidate_portrait(cand, _expression(cand), 600)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero.add_child(pic)
	var fade := Control.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.draw.connect(func():
		for i in 20:
			var t := float(i) / 19.0
			fade.draw_rect(Rect2(0, fade.size.y - 160.0 + t * 160.0, fade.size.x, 9.0), Color(Style.NIGHT, t)))
	hero.add_child(fade)
	var nm := Style.label(String(p.get("name", "")), 60, Style.TEXT)
	nm.name = "ProfileName"
	col.add_child(nm)
	var house_name := String(house.get("name", ""))
	var line := "%s%s · %d" % [p.get("role", data.get("role", "")), (" · " + house_name) if house_name != "" else "", int(data.get("age", 0))]
	col.add_child(Page.note(line, 21, Style.MUTED))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	col.add_child(chips)
	chips.add_child(_status_chip(cand))
	chips.add_child(_chip("At %s" % Letters.place_name(_residence(cand)), Color("262c40"), Color("b5bcd0"), "mappin"))
	var trust := int(rel.get("trust", 0))
	var standing := int(house.get("standing", 0))
	var mems: Array = p.get("memory_log", [])
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	col.add_child(tiles)
	tiles.add_child(_num_tile(str(trust), "trust · %s" % Relationships.trust_label(trust), ROSE))
	tiles.add_child(_num_tile(str(standing), "house · %s" % Relationships.standing_label(standing), Style.TEXT))
	tiles.add_child(_num_tile(str(maxi(mems.size(), (rel.get("memories", []) as Array).size())), "memories", Style.TEXT))
	# The story, chapter by chapter.
	var story: Dictionary = RomanceStories.story_data(cand)
	col.add_child(_heading(String(story.get("title", "Their story"))))
	var now := _chapter(cand)
	for n in range(1, CHAPTERS + 1):
		var state := "done" if n < now else ("now" if n == now else "lock")
		var sub := ""
		if state == "now":
			sub = _next_step(cand)
		elif state == "lock" and n == now + 1:
			sub = "After chapter %d" % now
		col.add_child(_story_step(n, _chapter_title(cand, n), sub, state))
	var interests: Array = data.get("interests", [])
	if not interests.is_empty():
		col.add_child(_heading("%s cares about" % _pronoun(data)))
		var f := HFlowContainer.new()
		f.add_theme_constant_override("h_separation", 8)
		f.add_theme_constant_override("v_separation", 8)
		for s in interests:
			f.add_child(_chip(String(s).capitalize(), Color("1f3a2a"), Color("b8f5b0")))
		col.add_child(f)
	var limits: Array = data.get("boundaries", [])
	if not limits.is_empty():
		col.add_child(_heading("%s won't stand for" % _pronoun(data)))
		var f2 := HFlowContainer.new()
		f2.add_theme_constant_override("h_separation", 8)
		f2.add_theme_constant_override("v_separation", 8)
		for s in limits:
			f2.add_child(_chip(_boundary_words(String(s)), Color("3a1d1d"), Color("ffb3a0")))
		col.add_child(f2)
	col.add_child(_heading("Memories"))
	var book: Array = _social().memory_book(String(p.get("id", "")))
	book.reverse()
	if book.is_empty():
		col.add_child(Page.note("Nothing yet. Every story starts somewhere.", Style.SMALL))
	var limit := book.size() if _all_memories else mini(book.size(), 10)
	for e in book.slice(0, limit):
		col.add_child(_keepsake_row(cand, e))
	if book.size() > limit:
		var more := _button("All %d memories" % book.size(), func():
			_all_memories = true
			_build())
		more.name = "AllMemories"
		col.add_child(more)
	var spend := _button("Spend time", _spend_time.bind(cand), false, "cup")
	spend.name = "SpendTime_%s" % cand
	frame.add_child(_bar([_main_action(cand), spend], insets))


func _pronoun(data: Dictionary) -> String:
	var pr := String(data.get("pronouns", "they/them"))
	return pr.split("/")[0].capitalize()


## "opposes reckless raids" reads as "Reckless raids" under "won't stand for".
func _boundary_words(s: String) -> String:
	for lead in ["opposes ", "rejects ", "demands ", "values ", "respects ", "resists "]:
		if s.begins_with(lead):
			var rest := s.substr(lead.length())
			if lead == "demands ":
				return "Broken " + rest.trim_prefix("kept ") if rest.begins_with("kept ") else "Neglect of " + rest
			if lead == "values ":
				return "Indiscretion" if rest == "discretion" else "Disregard of " + rest
			if lead == "respects ":
				return "Broken " + rest.trim_suffix("s") if rest.ends_with("oaths") else "Disrespect of " + rest
			return rest.capitalize()
	return s.capitalize()


func _close_person() -> void:
	_person = ""
	_build()


func _num_tile(value: String, caption: String, tone: Color) -> PanelContainer:
	var t := PanelContainer.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := Style.box(Style.RAISED, Style.RULE, 1, 14)
	sb.content_margin_left = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	t.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	t.add_child(v)
	v.add_child(Style.label(value, 34, tone))
	v.add_child(Style.label(caption, 17, Style.MUTED))
	return t


func _heading(text: String) -> Label:
	var l := Style.label(text.to_upper(), 19, Style.MUTED)
	return l


func _story_step(n: int, title: String, sub: String, state: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Chapter%d" % n
	row.add_theme_constant_override("separation", 16)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(40, 40)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dot.draw.connect(_draw_step_dot.bind(dot, n, state))
	row.add_child(dot)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(Style.label(title, 24, Style.TEXT if state != "lock" else Color("7d849c")))
	if sub != "":
		var s := Style.label(sub, 19, Color("e6d3a8") if state == "now" else Style.MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(s)
	return row


func _draw_step_dot(dot: Control, n: int, state: String) -> void:
	var c := Vector2(20, 20)
	if state == "done":
		dot.draw_circle(c, 18, Style.BRASS)
		dot.draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 7), c + Vector2(9, -7)]), Style.BRASS_INK, 4.0)
	elif state == "now":
		dot.draw_circle(c, 18, Style.NIGHT)
		dot.draw_arc(c, 17, 0, TAU, 32, Style.BRASS, 4.0)
		dot.draw_string(ThemeDB.fallback_font, Vector2(0, 28), str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Style.BRASS)
	else:
		dot.draw_circle(c, 18, Color("262c40"))
		var lock := Widgets.icon("lock")
		if lock != null:
			dot.draw_texture_rect(lock, Rect2(c - Vector2(11, 11), Vector2(22, 22)), false, Color("79809a"))


const MEMORY_ICONS := {"visit": "cup", "letter": "mail", "decision": "book", "ceremony": "crown", "move": "mappin", "note": "heart"}


## A memory you can open: a visit tells itself again, a letter opens, a decision shows what
## you said and how they answered, a move shows the place.
func _keepsake_row(cand: String, e: Dictionary) -> Control:
	var kind := String(e.get("kind", "note"))
	var b := Button.new()
	b.name = "Memory_%s" % String(e.get("id", ""))
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", Style.box(Color("1b1726"), Color("3a2f45"), 2, 14))
	b.add_theme_stylebox_override("hover", Style.box(Color("221d30"), Color("e88aa0"), 2, 14))
	b.add_theme_stylebox_override("pressed", Style.box(Color("221d30"), Color("e88aa0"), 2, 14))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 10
	row.offset_bottom = -10
	var icon := Widgets.icon_rect(String(MEMORY_ICONS.get(kind, "heart")), 34)
	icon.modulate = ROSE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var when := PackedStringArray()
	if int(e.get("day", 0)) > 0:
		when.append("Day %d" % int(e["day"]))
	var place := String(e.get("place", ""))
	if place != "":
		when.append(Letters.place_name(place))
	if not when.is_empty():
		words.add_child(Style.label(" · ".join(when), 19, Style.BRASS))
	var t := Style.label(String(e.get("text", "")), 21, Color("d5dae8"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(t)
	var detail := Style.label("", 19, Style.MUTED)
	detail.name = "Detail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.visible = false
	words.add_child(detail)
	row.add_child(words)
	b.add_child(row)
	row.minimum_size_changed.connect(func(): b.custom_minimum_size.y = row.get_combined_minimum_size().y + 20)
	b.custom_minimum_size.y = 72
	b.pressed.connect(func(): _open_memory(cand, e, detail))
	return b


func _open_memory(cand: String, e: Dictionary, detail: Label) -> void:
	match String(e.get("kind", "note")):
		"visit":
			Scenes.active_candidate_id = cand
			Scenes.active_person_id = String(_candidate_person(cand).get("id", ""))
			Scenes.romance_relive = String(e.get("scene_id", ""))
			Scenes.personal_conversation_return = "res://scenes/people.tscn"
			Scenes.go("res://scenes/personal_conversation.tscn")
		"letter":
			if String(e.get("letter_id", "")) != "":
				_open_letter(String(e["letter_id"]))
		"move", "ceremony":
			if String(e.get("place", "")) != "":
				_show_on_map(String(e["place"]))
		"decision":
			var said := _decision_said(cand, String(e.get("choice", "")))
			detail.text = said if said != "" else "A choice you made together."
			detail.visible = not detail.visible
		_:
			pass


## What you said, and how they answered, for a chapter decision.
func _decision_said(cand: String, choice: String) -> String:
	var story: Dictionary = RomanceStories.story_data(cand)
	for n in story.get("chapters", {}):
		var ch: Dictionary = story["chapters"][n]
		var options: Array = []
		options.append_array(ch.get("choices", []))
		options.append_array(ch.get("intent_choices", []))
		options.append_array(ch.get("variants", []))
		if ch.has("repair"):
			options.append(ch["repair"])
		for o in options:
			if String(o.get("id", "")) == choice:
				return "You said: \"%s\"\n%s" % [String(o.get("text", "")), String(o.get("response", ""))]
	return ""


func _memory_row(day: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var d := Style.label(day, 19, Style.BRASS)
	d.custom_minimum_size.x = 76
	row.add_child(d)
	var t := Style.label(text, 21, Color("d5dae8"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	return row


# ---------------------------------------------------------------- house pacts

func _build_pacts(col: VBoxContainer) -> void:
	var pact_list: Dictionary = _social().pacts
	if pact_list.is_empty():
		var card := Widgets.card(col, "House pacts")
		card.add_child(Page.note("No house pacts yet. Finish a shared service or a wedding to agree one."))
		return
	for hid in pact_list:
		var pact: Dictionary = pact_list[hid]
		var house: Dictionary = _social().get_house(hid)
		var card := Widgets.card(col, String(house.get("name", "House")), String(pact.get("status", "")).capitalize(), Style.BRASS)
		var sites: Array = pact.get("protected_sites", [])
		var names := []
		for s in sites:
			names.append(Letters.place_name(String(s)))
		card.add_child(Page.note("Protects: %s" % (", ".join(names) if not names.is_empty() else "nothing yet"), Style.SMALL))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var grant := _button("Request grant · 150", func():
			var res := GameState.request_household_grant(hid)
			_flash = "The house sends a grant." if res.get("ok", false) else String(res.get("reason", "Grant unavailable"))
			_build(), false, "silver")
		grant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(grant)
		var sponsor := _button("Sponsor muster · 150", func():
			var res := GameState.sponsor_replacements(hid, String(house.get("seat", "")), "settlement", 150)
			_flash = "Muster sponsored." if res.get("ok", false) else String(res.get("reason", "Sponsorship failed"))
			_build(), false, "men")
		sponsor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sponsor)


# ---------------------------------------------------------------- letters

func _build_letters(col: VBoxContainer) -> void:
	var list: Array = _social().letters
	if list.is_empty():
		var card := Widgets.card(col, "Letters")
		card.add_child(Page.note("No letters in your dispatch bag yet."))
		return
	var unread := list.filter(func(l): return not bool(l.get("read", false)))
	var read := list.filter(func(l): return bool(l.get("read", false)))
	unread.reverse()
	read.reverse()
	if not unread.is_empty():
		col.add_child(_heading("Unread"))
		for l in unread:
			col.add_child(_letter_row(l))
	if not read.is_empty():
		col.add_child(_heading("Read"))
		for l in read:
			col.add_child(_letter_row(l))


func _when(hour: float) -> String:
	var w = GameState.world
	var today := int(w.hour / 24.0) if w != null else 0
	var day := int(hour / 24.0)
	if day == today:
		return "Today"
	if day == today - 1:
		return "Yesterday"
	return "Day %d" % (day + 1)


func _letter_row(l: Dictionary) -> PanelContainer:
	var social = _social()
	var view: Dictionary = social.letter_view(l)
	var cand: String = social.letter_candidate(l)
	var sender: Dictionary = social.get_person(String(l.get("sender_id", "")))
	var read := bool(l.get("read", false))
	var row := PanelContainer.new()
	row.name = "Letter_%s" % l["id"]
	row.add_theme_stylebox_override("panel", _card_box(16))
	if read:
		row.modulate = Color(1, 1, 1, 0.7)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	row.add_child(h)
	var av := Control.new()
	av.custom_minimum_size = Vector2(92, 116)
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(av)
	if cand != "":
		av.add_child(_framed(cand, Vector2(86, 112)))
	var seal := _seal(view, 22.0)
	seal.position = Vector2(56, 78)
	av.add_child(seal)
	var tx := VBoxContainer.new()
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.add_theme_constant_override("separation", 2)
	h.add_child(tx)
	var head := HBoxContainer.new()
	tx.add_child(head)
	var sj := Style.label(String(view.get("subject", "A letter")), 27, Style.TEXT)
	var big: Font = Style.display_font()
	if big != null:
		sj.add_theme_font_override("font", big)
	sj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sj.custom_minimum_size.x = 10
	head.add_child(sj)
	head.add_child(Style.label(_when(float(l.get("created_hour", 0.0))), 18, Style.MUTED))
	var from_line := "%s · %s" % [sender.get("name", "Unknown"), Letters.place_name(String(l.get("destination", "")))]
	if l.has("reply"):
		from_line += " · answered"
	tx.add_child(Style.label(from_line, 19, Style.MUTED))
	var body: Array = view.get("body", [])
	var pv := Style.label(String(body[0]) if not body.is_empty() else "", 22, Color("cdbf9c"))
	var italic := Style.letter_font(true)
	if italic != null:
		pv.add_theme_font_override("font", italic)
	pv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.custom_minimum_size.x = 10
	tx.add_child(pv)
	if not read:
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.draw.connect(func(): dot.draw_circle(Vector2(8, 8), 7, Style.BRASS))
		h.add_child(dot)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(e: InputEvent):
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_open_letter(String(l["id"])))
	return row


func _open_letter(id: String) -> void:
	_letter = id
	_reply = ""
	Sound.play("page", 0.0, 0.05)
	_build()


## A wax seal: the sender's mark in their house colour.
func _seal(view: Dictionary, r: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(r * 2.0 + 4.0, r * 2.0 + 4.0)
	c.size = c.custom_minimum_size
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := Color(String(view.get("seal_color", "8e1f17")))
	var mark := String(view.get("seal", ""))
	c.draw.connect(func():
		var ctr := Vector2(r + 2.0, r + 2.0)
		c.draw_circle(ctr + Vector2(1, 2), r, Color(0, 0, 0, 0.45))
		c.draw_circle(ctr, r, col.darkened(0.2))
		c.draw_circle(ctr - Vector2(r * 0.15, r * 0.15), r * 0.82, col)
		c.draw_arc(ctr, r * 0.72, 0, TAU, 32, col.darkened(0.35), maxf(1.5, r * 0.08))
		var f: Font = Style.display_font()
		if f == null:
			f = ThemeDB.fallback_font
		var fs := int(r * 1.05)
		c.draw_string(f, Vector2(2.0, ctr.y + fs * 0.36), mark, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, col.lightened(0.55)))
	return c


## A sheet of parchment holding a letter: its place and day, greeting, body, signature,
## P.S. and seal. `own` is a letter you write (paler paper, no seal of theirs).
func _parchment(view: Dictionary, own: bool) -> PanelContainer:
	var paper := PanelContainer.new()
	paper.name = "Parchment" if not own else "ReplyParchment"
	var sb := StyleBoxFlat.new()
	sb.bg_color = PARCHMENT if not own else Color("f4ecd8")
	sb.border_color = Color("c9ae74") if not own else Color("d8cba8")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	sb.content_margin_left = 44
	sb.content_margin_right = 44
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	paper.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	paper.add_child(v)
	var roman := Style.letter_font(false)
	var italic := Style.letter_font(true)
	var place := _ink(String(view.get("place_line", "")), 24, INK_SOFT, italic)
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(place)
	v.add_child(_ink(String(view.get("salute", "")), 34, INK, roman))
	for para in view.get("body", []):
		var p := _ink("      " + String(para), 29, INK, roman)
		p.add_theme_constant_override("line_spacing", 4)
		v.add_child(p)
	if view.has("close"):
		var close := _ink(String(view["close"]), 27, INK_SOFT, italic)
		close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(close)
	var sign := _ink(String(view.get("sign", "")), 48, Color("2a1c0c"), italic)
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(sign)
	var title := String(view.get("sign_title", ""))
	if title != "":
		var t := _ink(title, 23, INK_SOFT, italic)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(t)
	var ps := String(view.get("ps", ""))
	if ps != "":
		v.add_child(_ink("P.S. " + ps, 25, Color("4a3618"), italic))
	if not own:
		var seal := _seal(view, 46.0)
		v.add_child(seal)
	return paper


func _ink(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", Style.text_size(size))
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func _build_reader(col: VBoxContainer, frame: VBoxContainer, insets: Dictionary) -> void:
	var social = _social()
	var l: Dictionary = social.get_letter(_letter)
	if l.is_empty():
		_letter = ""
		_build()
		return
	var view: Dictionary = social.letter_view(l)
	l["read"] = true
	l["announced"] = true
	var cand: String = social.letter_candidate(l)
	var sender: Dictionary = social.get_person(String(l.get("sender_id", "")))
	var name := String(sender.get("name", "Unknown"))
	# Who it's from.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var back := _button("", _close_letter, false, "back")
	back.name = "LetterBack"
	back.custom_minimum_size = Vector2(Style.TOUCH, Style.TOUCH)
	head.add_child(back)
	if cand != "":
		head.add_child(_framed(cand, Vector2(64, 80)))
	var who := VBoxContainer.new()
	who.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(who)
	if _reply != "":
		who.add_child(Style.label("To %s" % name, 26, Style.TEXT))
		who.add_child(Style.label("Your reply · read it before it goes", 19, Style.MUTED))
	else:
		who.add_child(Style.label("From %s" % name, 26, Style.TEXT))
		who.add_child(Style.label("%s · %s" % [sender.get("role", ""), _when(float(l.get("created_hour", 0.0))).to_lower()], 19, Style.MUTED))
	var res := String(sender.get("residence", l.get("destination", "")))
	if _reply != "":
		# Your answer, on your own paper, before you send it.
		var mine: Dictionary = social.reply_preview(_letter, _reply, GameState.world.here())
		col.add_child(_parchment(mine, true))
		var send := _button("Send", _send_reply, true, "mail")
		send.name = "SendReply"
		var again := _button("Choose again", func(): _reply = ""; _build(), false, "back")
		again.name = "ChooseAgain"
		frame.add_child(_bar([send, again], insets))
		return
	col.add_child(_parchment(view, false))
	if l.has("reply"):
		if _flash != "":
			col.add_child(Page.note(_flash, Style.SMALL, Style.BRASS))
			_flash = ""
		col.add_child(_heading("Your reply"))
		col.add_child(_parchment(l["reply"].get("letter", {}), true))
	else:
		var options: Array = Letters.replies(String(l.get("template_key", "")))
		if not options.is_empty():
			col.add_child(_heading("Write back"))
			for r in options:
				var b := _button(String(r["label"]), _preview_reply.bind(String(r["id"])), false, "reply")
				b.name = "Reply_%s" % r["id"]
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				col.add_child(b)
	var buttons := []
	if res != "" and GameState.world.here() != res:
		var ride := _ride_text(res)
		var go := _button("Ride to %s%s" % [Letters.place_name(res), (" · " + ride) if ride != "" else ""], _ride.bind(res), true, "ride")
		go.name = "RideFromLetter"
		buttons.append(go)
	var keep := _button("Keep", _close_letter, buttons.is_empty(), "keep")
	keep.name = "KeepLetter"
	buttons.append(keep)
	frame.add_child(_bar(buttons, insets))


func _preview_reply(id: String) -> void:
	_reply = id
	_build()


func _send_reply() -> void:
	var l: Dictionary = _social().get_letter(_letter)
	var who := String(_social().get_person(String(l.get("sender_id", ""))).get("name", "They"))
	var res: Dictionary = _social().reply_letter(_letter, _reply, GameState.world.here())
	_reply = ""
	if res.get("ok", false):
		Sound.play("page", 0.0, 0.05)
		GameState.save_game()
		var gain := int(res.get("trust_change", 0))
		_flash = "Sent. A rider takes it to %s.%s" % [who, (" Trust +%d." % gain) if gain > 0 else ""]
	_build()
	# Down to the reply you just sent.
	await get_tree().process_frame
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _close_letter() -> void:
	_letter = ""
	_reply = ""
	_tab = "letters"
	_build()


func _back() -> void:
	if _letter != "":
		_close_letter()
		return
	if _person != "":
		_close_person()
		return
	Scenes.go(Scenes.people_return)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
