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
const PARCHMENT := Color("ecdcb4")
const INK := Color("3a2a16")
const INK_SOFT := Color("6b5230")
const CHAPTERS := 5
## What sponsoring a muster at a house's seat costs.
const MUSTER_COST := 150

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
var _insets := {}
## Room the bottom bar takes under the page, above the safe area.
const BAR_ROOM := 124.0


func _ready() -> void:
	if Scenes.people_tab != "":
		_tab = Scenes.people_tab
		Scenes.people_tab = ""
	if Scenes.people_letter != "":
		_tab = "letters"
		_letter = Scenes.people_letter
		_unfold = true
		Scenes.people_letter = ""
	_build()


func _social():
	var w = GameState.world
	return w.social if w != null else null


# ---------------------------------------------------------------- frame

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var insets := Style.safe_insets(get_viewport())
	_insets = insets
	var col := Page.frame(self, BAR_ROOM + float(insets["bottom"]))
	(get_node("Background") as ColorRect).color = Color("120e0a") if _letter != "" else Style.NIGHT
	_scroll = get_node("PageScroll") as ScrollContainer

	var social = _social()
	if social == null:
		col.add_child(Page.note("No active world or social records."))
		_set_bar([_back_button()])
		return
	if _letter != "":
		_build_reader(col)
		return
	if _person != "":
		_build_profile(col)
		return
	col.add_child(Style.label("People & Letters", 52, Style.BRASS))
	if _flash != "":
		col.add_child(Page.note(_flash, Style.SMALL, Style.BRASS))
		_flash = ""
	var unread: int = social.unread_letters_count()
	col.add_child(Widgets.tab_bar([
		{"id": "people", "label": "People", "badge": 0, "icon": "heart"},
		{"id": "lords", "label": "Lords", "badge": 0, "icon": "crown"},
		{"id": "pacts", "label": "Pacts", "badge": 0, "icon": "keep"},
		{"id": "letters", "label": "Letters", "badge": unread, "icon": "mail"},
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
	_set_bar([_back_button()])


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
	var ids := ["met", "swear", "war", "crown"]
	var filters := Widgets.segmented(["Met %d" % met.size(), "Could swear", "At war", "Yours"], maxi(0, ids.find(_lord_filter)), func(i: int):
		_lord_filter = String(ids[i])
		_build(), "LordFilters", ["", "bond", "fight", "crown"])
	for t in filters.find_children("Tab_*", "Button", true, false):
		(t as Button).custom_minimum_size.y = Style.TOUCH
	col.add_child(filters)
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
	# Your own sworn lords in brass; rulers, who never change sides, behind a quiet edge.
	var edge := Style.BRASS if crown else (Color(Style.MUTED, 0.35) if ruler else Style.RULE)
	panel.add_theme_stylebox_override("panel", Style.box(Color("2a2210") if crown else Style.PANEL, edge, 2, 14))
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
	words.add_theme_constant_override("separation", 6)
	row.add_child(words)
	var name_label := Style.name_label(LordTalk.short_name(l), Style.BODY)
	words.add_child(name_label)
	# The realm is the banner; the rest are marks.
	var chips: Array = []
	if crown:
		chips.append(Widgets.chip("Sworn to you", Style.BRASS, "", "crown", true))
	elif ruler:
		chips.append(Widgets.chip("Ruler", Style.BRASS, "", "crown"))
	elif String(l.get("bearing", "")) != "":
		chips.append(Widgets.chip(String(l["bearing"]), Style.MUTED, "◇"))
	var captive := String(l.get("captive_of", "")) == "player"
	if captive:
		chips.append(Widgets.chip("Captive", Style.MUTED, "", "lock"))
		chips.append(Widgets.stat("silver", Widgets.thousands(int(l.get("ransom_amount", 0)))))
		if String(l.get("bearing", "")) == Lords.HONORABLE:
			chips.append(Widgets.chip("Won't swear", Style.MORALE_LOW))
	elif w.relation_to_player(realm) == "hostile" and not crown:
		chips.append(Widgets.chip("At war", Style.ENEMY_LIGHT, "", "fight"))
	# The head of a house you married into, or swore a pact with.
	var pact: Dictionary = _social().pact_for_lord(int(l["id"]))
	if String(pact.get("origin", "")) == "marriage":
		var kin := Widgets.chip("Kin by marriage", Style.ROMANCE, "", "rings")
		kin.name = "KinChip"
		chips.append(kin)
	elif not pact.is_empty():
		var sworn := Widgets.chip("Sworn pact", Style.BRASS, "", "keep")
		sworn.name = "PactChip"
		chips.append(sworn)
	var fief := String(l.get("fief", ""))
	if fief != "" and not ruler:
		chips.append(Widgets.chip(String(WorldData.settlement(fief)["name"]), Style.TEXT, "", "keep"))
	var t: Dictionary = l.get("talk", {}) if l.get("talk") is Dictionary else {}
	if String(t.get("job", "")) != "":
		chips.append(Widgets.chip("Your job", Style.BRASS, "", "objective"))
	elif not captive and int(l.get("met_player", 0)) > 0 and int(t.get("like_known", 0)) != 1:
		chips.append(Widgets.chip("Fought you", Style.MUTED, "", "battle"))
	words.add_child(Widgets.chip_row(chips))
	# Regard: the meter, and its number beside it.
	var value := LordTalk.regard(GameState, l)
	var tone := Style.MORALE_HIGH if value >= 10 else (Style.MORALE_MID if value >= -14 else Style.MORALE_LOW)
	var regard := HBoxContainer.new()
	regard.name = "RegardLine"
	regard.add_theme_constant_override("separation", 10)
	regard.add_child(Widgets.meter((value + 100.0) / 200.0, Style.MUTED if ruler else tone, 10.0))
	regard.add_child(Widgets.icon_value("bond", "%s%d" % ["+" if value > 0 else "", value], Style.MUTED if ruler else tone))
	words.add_child(regard)
	if int(t.get("like_known", 0)) == 1 and not ruler:
		var likes := Style.label("Values %s" % LordTalk.likes(l), Style.SMALL, Style.MUTED)
		likes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(likes)
	var where := _lord_place(l)
	if where != "":
		var pin := Widgets.icon_button("mappin", func():
			Scenes.map_focus = where
			Scenes.go(Scenes.people_return if Scenes.people_return != "" else "res://scenes/world_map.tscn"), "Show on map", "ShowOnMap")
		row.add_child(pin)
	return panel


## Where a lord is now, to look at on the map: where they ride, else their seat.
func _lord_place(l: Dictionary) -> String:
	var w = GameState.world
	var p = w.party(int(l.get("party", -1)))
	if p != null:
		return String(p.node)
	if String(l.get("state", "")) == "prisoner":
		return ""
	return w.seat_of(l)


func _on_tab(id: String) -> void:
	_tab = id
	_pulse_unread = id == "letters"
	_build()


## The fixed bar at the bottom, in thumb reach: Back on the left, the main action last.
func _set_bar(buttons: Array) -> void:
	var bar := Widgets.bottom_bar(buttons, _insets)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bar)
	for b in buttons:
		(b as Button).autowrap_mode = TextServer.AUTOWRAP_OFF
		(b as Button).clip_text = true


func _back_button() -> Button:
	return Widgets.back_button(_back, "Back", "BackButton")


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
	return Style.time_short(h)


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


## One line on what to do next with this person. On the card the place has its own chip,
## so `with_place` false leaves it out.
func _next_step(cand: String, with_place: bool = true) -> String:
	var p := _candidate_person(cand)
	var name := String(p.get("name", ""))
	var place := Letters.place_name(_residence(cand))
	var at := (" at %s" % place) if with_place else ""
	var here: bool = GameState.world.here() == _residence(cand)
	var unread := _unread_from(cand)
	if not unread.is_empty() and String(unread[0].get("template_key", "")).ends_with("_invitation"):
		return "%s has invited you%s." % [name, (" to %s" % place) if with_place else ""]
	if not unread.is_empty():
		return "%s has written to you." % name
	var post: Dictionary = _social().post_state(cand, GameState.world.hour)
	if bool(post.get("ok", false)):
		return "%s has one more matter to ask of you%s." % [name, at]
	if _chapter(cand) > CHAPTERS or _status(cand) == Relationships.MARRIED:
		return "Your story together is told. Spend an evening with %s whenever you like%s." % [name, at]
	if not _met(cand):
		return "Seek an audience%s." % at
	if not _social().task(cand).is_empty():
		return "Keep your promise to %s: it's in your journal." % name
	if _social().intent_open(cand):
		return "You never said what you mean to be to %s. Tell her%s." % [name, at]
	var open: Dictionary = _social().chapter_open(cand, GameState.world.hour)
	if not bool(open["ok"]):
		return "Not yet: %s. Time together is always welcome%s." % [String(open["reason"]), at]
	if here:
		var object := String(RomanceStories.candidate_data(cand).get("pronouns", "they/them")).split("/")[1] if String(RomanceStories.candidate_data(cand).get("pronouns", "")).contains("/") else "them"
		return "%s is here. Speak with %s to go on." % [name, object]
	return "Meet %s%s to go on." % [name, at]


## The main thing to do with this person: speak (if you're there) or ride to them.
func _main_action(cand: String) -> Button:
	var p := _candidate_person(cand)
	var res := _residence(cand)
	if GameState.world.here() == res:
		var b := _button("Speak", _speak.bind(cand), true, "talk")
		b.name = "Speak_%s" % cand
		b.tooltip_text = "Speak with %s" % p.get("name", "")
		return b
	var b2 := _button("Ride", _ride.bind(res), true, "ride")
	b2.tooltip_text = "Ride to %s" % Letters.place_name(res)
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
	var pic := StoryArt.candidate_portrait(cand, _expression(cand), size.y * 1.15)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return Widgets.framed(pic, size, dim)


## Where someone is, and how far: the one place on a card. Tapping shows it on the map.
func _place_chip(place: String) -> Button:
	var ride := _ride_text(place)
	var b := Button.new()
	b.name = "ShowOnMap"
	b.text = Letters.place_name(place) + ((" · " + ride) if ride != "" else " · here")
	b.icon = Widgets.icon("mappin")
	b.tooltip_text = "Show on map"
	b.custom_minimum_size = Vector2(0, Style.TOUCH)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_constant_override("icon_max_width", 28)
	b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	b.add_theme_stylebox_override("normal", Style.box(Style.RAISED, Style.RULE, 2, 40))
	b.pressed.connect(_show_on_map.bind(place))
	return b


## Where you stand with them, as a chip: a heart while courting, rings once promised.
func _status_chip(cand: String) -> PanelContainer:
	var status := _status(cand)
	match status:
		Relationships.MARRIED:
			return Widgets.chip("Married", Style.ROMANCE, "", "rings")
		Relationships.ENGAGED:
			return Widgets.chip(Relationships.status_label(status), Style.ROMANCE, "", "rings")
		Relationships.COURTING, Relationships.COMMITTED:
			return Widgets.chip(Relationships.status_label(status), Style.ROMANCE, "", "heart")
		Relationships.UNKNOWN:
			return Widgets.chip("Not yet met", Style.MUTED, "◇")
		Relationships.ENDED:
			return Widgets.chip("Parted", Style.MUTED, "▽")
		Relationships.ACQUAINTED:
			return Widgets.chip(Relationships.status_label(status), Style.PLAYER_LIGHT, "", "talk")
	return Widgets.chip(Relationships.status_label(status), Style.PLAYER_LIGHT, "", "bond")


## A house's standing with you, Allied to Hostile, with its shape.
func _standing_chip(standing: int) -> PanelContainer:
	var tone := Style.MORALE_HIGH if standing >= 25 else (Style.MORALE_MID if standing >= 0 else Style.MORALE_LOW)
	return Widgets.chip(Relationships.standing_label(standing), tone)


## Trust as a bar with marks where its words change (Reserved, Trusting, Devoted).
func _trust_meter(cand: String) -> Control:
	var trust := int(_social().get_relationship(cand).get("trust", 0))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var l := Style.label(Relationships.trust_label(trust), Style.SMALL, Style.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var value := Widgets.icon_value("bond", "%d" % trust, Style.ROMANCE_LIGHT)
	head.add_child(value)
	var bar := Widgets.meter(trust / 100.0, Style.ROMANCE.darkened(0.15), 14.0, [0.25, 0.5, 0.7])
	bar.name = "TrustBar"
	box.add_child(bar)
	# Back from a visit, trust is seen to have moved: the bar fills from where it stood
	# and the number counts to the new one. Each page built in the same frame shows it.
	var seen: Dictionary = Scenes.people_seen.get(cand, {})
	var was := int(seen.get("trust", trust))
	if was != trust:
		bar.ready.connect(func(): Widgets.fill_from(bar, was / 100.0))
		var number := value.get_node_or_null("Text") as Label
		if number != null:
			var as_number := func(v: int) -> String: return str(v)
			number.ready.connect(func(): Widgets.tick_to(number, was, trust, as_number))
	_note_seen.call_deferred(cand, "trust", trust)
	return box


## Remember what the page showed of `cand` once this frame's building is done.
func _note_seen(cand: String, key: String, value: int) -> void:
	var seen: Dictionary = Scenes.people_seen.get(cand, {})
	seen[key] = value
	Scenes.people_seen[cand] = seen


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
	var t := Style.label(_chapter_title(cand, mini(now, CHAPTERS)) if now <= CHAPTERS else "Story told", Style.SMALL, Style.MUTED)
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
	var l := Style.label(text, Style.SMALL, Color("d5dae8"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return box


## Tapping anywhere on `card` that isn't a button opens `cand`'s page.
func _tap_opens(card: Control, cand: String) -> void:
	Widgets.on_tap(card, _open_person.bind(cand))


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
	who.add_child(Style.name_label(String(p.get("name", "")), Style.TITLE_SIZE))
	var role := Style.label(String(p.get("role", "")), Style.SMALL, Style.MUTED)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_child(role)
	var chips := [_status_chip(cand)]
	var unread := _unread_from(cand)
	if not unread.is_empty():
		chips.append(Widgets.chip(str(unread.size()) if unread.size() > 1 else "New", Style.BRASS, "", "mail"))
	who.add_child(Widgets.chip_row(chips))
	who.add_child(_trust_meter(cand))
	v.add_child(_beads(cand))
	v.add_child(_place_chip(_residence(cand)))
	v.add_child(_next_box(_next_step(cand, false), "mail" if not unread.is_empty() else "objective"))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	v.add_child(acts)
	var spend := _button("Spend time", _spend_time.bind(cand), false, "cup")
	spend.name = "SpendTime_%s" % cand
	spend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spend.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	acts.add_child(spend)
	var main := _main_action(cand)
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_stretch_ratio = 1.4
	main.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
	acts.add_child(main)
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
	who.add_child(Style.name_label(String(p.get("name", "")), Style.LARGE))
	var role := Style.label(String(p.get("role", "")), Style.SMALL, Style.MUTED)
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.add_child(role)
	who.add_child(Widgets.chip_row([_status_chip(cand)]))
	# Riding there is the one thing to do; the button says how long it takes.
	var ride := _ride_text(_residence(cand))
	var go := _button(ride if ride != "" else "Here", _ride.bind(_residence(cand)), false, "ride")
	go.name = "Ride_%s" % cand
	go.tooltip_text = "Ride to %s" % Letters.place_name(_residence(cand))
	go.custom_minimum_size = Vector2(150, Style.TOUCH)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(go)
	_tap_opens(card, cand)
	return card


# ---------------------------------------------------------------- a person's page

func _build_profile(col: VBoxContainer) -> void:
	var cand := _person
	var p := _candidate_person(cand)
	var data: Dictionary = RomanceStories.candidate_data(cand)
	var rel: Dictionary = _social().get_relationship(cand)
	var house: Dictionary = _social().get_house(String(p.get("house_id", "")))
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
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	var nm := Style.name_label(String(p.get("name", "")), 60)
	nm.name = "ProfileName"
	col.add_child(nm)
	var line := "%s · %d" % [p.get("role", data.get("role", "")), int(data.get("age", 0))]
	col.add_child(Page.note(line, Style.SMALL, Style.MUTED))
	var chips: Array = [_status_chip(cand)]
	if _status(cand) == Relationships.MARRIED:
		for m in _social().memory_book(String(p.get("id", ""))):
			if String(m.get("kind", "")) == "ceremony":
				chips.append(Widgets.stat("day", str(int(m.get("day", 1)))))
	var trust := int(rel.get("trust", 0))
	var standing := int(house.get("standing", 0))
	if not house.is_empty():
		chips.append(_standing_chip(standing))
	col.add_child(Widgets.chip_row(chips))
	col.add_child(_place_chip(_residence(cand)))
	var mems: Array = p.get("memory_log", [])
	var memories := maxi(mems.size(), (rel.get("memories", []) as Array).size())
	var house_name := String(house.get("name", ""))
	col.add_child(Widgets.tile_grid([
		Widgets.tile("bond", str(trust), Relationships.trust_label(trust), Style.ROMANCE_LIGHT),
		Widgets.tile("keep", "%s%d" % ["+" if standing > 0 else "", standing], "house" if house_name == "" else house_name.replace("House ", "")),
		Widgets.tile("journal", str(memories), "memories"),
	], 3))
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
		var likes: Array = []
		for s in interests:
			likes.append(Widgets.chip(String(s).capitalize(), Style.MORALE_HIGH, "▲"))
		col.add_child(Widgets.chip_row(likes))
	var limits: Array = data.get("boundaries", [])
	if not limits.is_empty():
		col.add_child(_heading("%s won't stand for" % _pronoun(data)))
		var dislikes: Array = []
		for s in limits:
			dislikes.append(Widgets.chip(_boundary_words(String(s)), Style.MORALE_LOW, "▼"))
		col.add_child(Widgets.chip_row(dislikes))
	col.add_child(_heading("Memories"))
	var book: Array = _social().memory_book(String(p.get("id", "")))
	book.reverse()
	if book.is_empty():
		col.add_child(Page.note("Nothing yet. Every story starts somewhere.", Style.SMALL))
	var limit := book.size() if _all_memories else mini(book.size(), 10)
	# Memories made since this page last showed them glow as they're shown.
	var known: Dictionary = Scenes.people_seen.get(cand, {})
	var fresh := book.size() - int(known.get("memories", book.size()))
	var shown := 0
	for e in book.slice(0, limit):
		var row := _keepsake_row(cand, e)
		col.add_child(row)
		if shown < fresh:
			_glow_later(row)
		shown += 1
	_note_seen.call_deferred(cand, "memories", book.size())
	if book.size() > limit:
		var more := _button("All %d memories" % book.size(), func():
			_all_memories = true
			_build())
		more.name = "AllMemories"
		col.add_child(more)
	var spend := _button("Spend time", _spend_time.bind(cand), false, "cup")
	spend.name = "SpendTime_%s" % cand
	var back := Widgets.back_button(_close_person, "Back", "ProfileBack")
	_set_bar([back, spend, _main_action(cand)])


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


func _heading(text: String) -> Label:
	return Widgets.section(text)


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
	words.add_child(Style.label(title, Style.BODY, Style.TEXT if state != "lock" else Color("7d849c")))
	if sub != "":
		var s := Style.label(sub, Style.SMALL, Color("e6d3a8") if state == "now" else Style.MUTED)
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
		dot.draw_string(ThemeDB.fallback_font, Vector2(0, 28), str(n), HORIZONTAL_ALIGNMENT_CENTER, 40, Style.text_size(Style.SMALL), Style.BRASS)
	else:
		dot.draw_circle(c, 18, Color("262c40"))
		var lock := Widgets.icon("lock")
		if lock != null:
			dot.draw_texture_rect(lock, Rect2(c - Vector2(11, 11), Vector2(22, 22)), false, Color("79809a"))


func _glow_later(node: Control) -> void:
	if Style.motion_reduced():
		return
	for i in 2:
		await get_tree().process_frame
	if is_instance_valid(node) and node.is_inside_tree():
		Widgets.flash(node)


const MEMORY_ICONS := {"visit": "cup", "letter": "mail", "decision": "book", "ceremony": "rings", "move": "mappin", "note": "heart", "dance": "dance"}


## A memory you can open: a visit tells itself again, a letter opens, a decision shows what
## you said and how they answered, a move shows the place.
func _keepsake_row(cand: String, e: Dictionary) -> Control:
	var kind := String(e.get("kind", "note"))
	var b := Button.new()
	b.name = "Memory_%s" % String(e.get("id", ""))
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", Style.box(Color("1b1726"), Color("3a2f45"), 2, 14))
	b.add_theme_stylebox_override("hover", Style.box(Color("221d30"), Style.ROMANCE, 2, 14))
	b.add_theme_stylebox_override("pressed", Style.box(Color("221d30"), Style.ROMANCE, 2, 14))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.offset_top = 10
	row.offset_bottom = -10
	var icon := Widgets.icon_rect(String(MEMORY_ICONS.get(kind, "heart")), 34)
	icon.modulate = Style.ROMANCE
	row.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var marks: Array = []
	if int(e.get("day", 0)) > 0:
		marks.append(Widgets.icon_value("day", str(int(e["day"])), Style.BRASS))
	var place := String(e.get("place", ""))
	if place != "":
		marks.append(Widgets.icon_value("mappin", Letters.place_name(place), Style.BRASS))
	if not marks.is_empty():
		var when := HBoxContainer.new()
		when.add_theme_constant_override("separation", 16)
		when.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for m in marks:
			when.add_child(m)
		words.add_child(when)
	var t := Style.label(String(e.get("text", "")), Style.SMALL, Color("d5dae8"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(t)
	var detail := Style.label("", Style.SMALL, Style.MUTED)
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
		"ceremony" when String(e.get("scene_id", "")) == "wedding":
			Scenes.wedding_replay = String(e.get("id", ""))
			Scenes.wedding_return = "res://scenes/people.tscn"
			Scenes.go("res://scenes/wedding.tscn")
		"move", "ceremony", "dance":
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
				return "You said: \"%s\"\n%s" % [String(o.get("text", "")), RomanceStories.plain(String(o.get("response", "")))]
	return ""


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
		var card := Widgets.card(col, String(house.get("name", "House")))
		card.get_parent().name = "Pact_%s" % hid
		# The house's banner and how it stands with you, then the places it protects.
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 14)
		card.add_child(head)
		var lord = _house_lord(hid)
		var realm := String(lord.get("realm", "")) if lord != null else ""
		if lord != null and not Heraldry.REALM_SIZES.has(realm):
			realm = Heraldry.realm_of_culture(String(lord.get("culture", "")))
		if realm != "":
			var flag := Widgets.banner(realm, Vector2(30, 46))
			flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(flag)
		var marks: Array = [_standing_chip(int(house.get("standing", 0)))]
		if String(pact.get("status", "active")) != "active":
			marks.append(Widgets.chip(String(pact.get("status", "")).capitalize(), Style.MORALE_LOW))
		for site in pact.get("protected_sites", []):
			marks.append(Widgets.chip(Letters.place_name(String(site)), Style.TEXT, "", "keep"))
		var mark_row := Widgets.chip_row(marks)
		mark_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(mark_row)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		# A grant brings silver in; a muster sends it out for men. The real amounts, and
		# why not, under each.
		var preview := _grant_preview(hid)
		var grant := _button("Grant", func():
			var res := GameState.request_household_grant(hid)
			_flash = ("The house sends %d silver." % int(res.get("amount", 0))) if res.get("ok", false) else String(res.get("reason", "Grant unavailable"))
			_build(), false, "silver")
		grant.name = "RequestGrant"
		grant.disabled = not bool(preview.get("ok", false))
		grant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gain: Array = [] if grant.disabled else [["silver", "+%d" % int(preview.get("amount", 0)), Style.MORALE_HIGH]]
		row.add_child(Widgets.priced(grant, gain, String(preview.get("reason", ""))))
		var cost := MUSTER_COST
		var sponsor := _button("Muster", func():
			var res := GameState.sponsor_replacements(hid, String(house.get("seat", "")), "settlement", cost)
			_flash = "Muster sponsored." if res.get("ok", false) else String(res.get("reason", "Sponsorship failed"))
			_build(), false, "men")
		sponsor.name = "SponsorMuster"
		sponsor.disabled = GameState.silver < cost
		sponsor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(Widgets.priced(sponsor, [["silver", "−%d" % cost]], "Need %d more silver" % (cost - GameState.silver)))


## What the house would grant now, without asking: {ok, amount, reason}.
func _grant_preview(hid: String) -> Dictionary:
	var lord = _house_lord(hid)
	if lord == null:
		return {"ok": false, "reason": "Their lord is away."}
	var last := float(_social().limits.get("last_grant_hour", -999.0))
	var check := Relationships.can_grant(lord, GameState.world.hour, last)
	if not check["ok"]:
		var reason := String(check.get("reason", ""))
		if reason.contains("cooldown"):
			reason = "Again in %s" % Style.time_short(last + Relationships.GRANT_COOLDOWN_HOURS - GameState.world.hour)
		elif reason.contains("purse"):
			reason = "Their purse is low"
		check["reason"] = reason
	return check


## The lord at the head of a house, or null.
func _house_lord(hid: String):
	var house: Dictionary = _social().get_house(hid)
	var head: Dictionary = _social().get_person(String(house.get("head_person_id", "")))
	var lord_id := int(head.get("lord_id", -1))
	for l in GameState.world.lords:
		if int(l["id"]) == lord_id:
			return l
	return null


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
		# Read letters fold to a line each, under the face of whoever wrote them.
		var senders: Array = []
		var by_sender := {}
		for l in read:
			var sid := String(l.get("sender_id", ""))
			if not by_sender.has(sid):
				by_sender[sid] = []
				senders.append(sid)
			by_sender[sid].append(l)
		for sid in senders:
			col.add_child(_sender_group(sid, by_sender[sid]))


const LETTER_ICONS := {"invitation": "cup", "relocation": "mappin", "wedding": "rings"}


## A letter's kind as an icon: an invitation is a cup, a move a pin, a wedding rings.
func _letter_icon(l: Dictionary) -> String:
	var key := String(l.get("template_key", ""))
	for k in LETTER_ICONS:
		if key.contains(k):
			return LETTER_ICONS[k]
	return "mail"


## One sender's read letters: their face and name, then a line per letter.
func _sender_group(sender_id: String, letters: Array) -> PanelContainer:
	var social = _social()
	var sender: Dictionary = social.get_person(sender_id)
	var cand: String = social.letter_candidate(letters[0])
	var panel := PanelContainer.new()
	panel.name = "From_%s" % sender_id
	panel.add_theme_stylebox_override("panel", _card_box(14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	if cand != "":
		var face := _framed(cand, Vector2(64, 82))
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	v.add_child(Style.name_label(String(sender.get("name", "Unknown")), Style.BODY))
	for l in letters:
		var view: Dictionary = social.letter_view(l)
		var b := Button.new()
		b.name = "Letter_%s" % l["id"]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = String(view.get("subject", "A letter"))
		b.icon = Widgets.icon(_letter_icon(l))
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size = Vector2(10, Style.TOUCH)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_constant_override("icon_max_width", 28)
		b.add_theme_constant_override("h_separation", 12)
		b.add_theme_font_size_override("font_size", Style.text_size(Style.SMALL))
		b.pressed.connect(_open_letter.bind(String(l["id"])))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.add_child(b)
		if l.has("reply"):
			var answered := Widgets.icon_rect("reply", 26.0)
			answered.name = "Answered"
			answered.tooltip_text = "Answered"
			answered.modulate = Style.MUTED
			line.add_child(answered)
		line.add_child(Style.label(_when(float(l.get("created_hour", 0.0))), Style.SMALL, Style.MUTED))
		v.add_child(line)
	return panel


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
	var kind := Widgets.icon_rect(_letter_icon(l), 30.0)
	kind.modulate = Style.BRASS
	head.add_child(kind)
	var sj := Style.label(String(view.get("subject", "A letter")), Style.BODY, Style.TEXT)
	var big: Font = Style.display_font()
	if big != null:
		sj.add_theme_font_override("font", big)
	sj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sj.custom_minimum_size.x = 10
	head.add_child(sj)
	head.add_child(Style.label(_when(float(l.get("created_hour", 0.0))), Style.SMALL, Style.MUTED))
	var from := HBoxContainer.new()
	from.add_theme_constant_override("separation", 12)
	from.add_child(Style.label(String(sender.get("name", "Unknown")), Style.SMALL, Style.MUTED))
	var dest := String(l.get("destination", ""))
	if dest != "":
		from.add_child(Widgets.icon_value("mappin", Letters.place_name(dest), Style.MUTED))
	if l.has("reply"):
		from.add_child(Widgets.icon_rect("reply", 24.0))
	tx.add_child(from)
	var body: Array = view.get("body", [])
	var pv := Style.label(String(body[0]) if not body.is_empty() else "", Style.SMALL, Color("cdbf9c"))
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
		dot.name = "Unread"
		h.add_child(dot)
		if _pulse_unread:
			Widgets.pulse(dot)
			set_deferred("_pulse_unread", false)
	Widgets.on_tap(row, _open_letter.bind(String(l["id"])))
	return row


## A letter just opened (or a reply just written out, or sent) unfolds on the page that
## shows it; other rebuilds of the reader leave it lying open.
var _unfold := false
var _sent_now := false
## The unread dots beat once when the Letters tab is come to.
var _pulse_unread := true


func _open_letter(id: String) -> void:
	_letter = id
	_reply = ""
	_unfold = true
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


func _build_reader(col: VBoxContainer) -> void:
	var social = _social()
	var l: Dictionary = social.get_letter(_letter)
	if l.is_empty():
		_letter = ""
		_build()
		return
	var view: Dictionary = social.letter_view(l)
	l["read"] = true
	l["announced"] = true
	var unfold := _unfold
	var sent_now := _sent_now
	_unfold = false
	_sent_now = false
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
		who.add_child(Style.label("To %s" % name, Style.BODY, Style.TEXT))
		who.add_child(Style.label("Your reply, before it goes", Style.SMALL, Style.MUTED))
	else:
		who.add_child(Style.label("From %s" % name, Style.BODY, Style.TEXT))
		who.add_child(Style.label("%s · %s" % [sender.get("role", ""), _when(float(l.get("created_hour", 0.0))).to_lower()], Style.SMALL, Style.MUTED))
	var res := String(sender.get("residence", l.get("destination", "")))
	if _reply != "":
		# Your answer, on your own paper, before you send it.
		var mine: Dictionary = social.reply_preview(_letter, _reply, GameState.world.here())
		var draft := _parchment(mine, true)
		col.add_child(draft)
		if unfold:
			Widgets.unfold(draft)
		var send := _button("Send", _send_reply, true, "mail")
		send.name = "SendReply"
		var again := _button("Change", func(): _reply = ""; _build(), false, "back")
		again.name = "ChooseAgain"
		_set_bar([again, send])
		return
	var paper := _parchment(view, false)
	col.add_child(paper)
	if unfold:
		Widgets.unfold(paper)
	if l.has("reply"):
		if _flash != "":
			var went := Page.note(_flash, Style.SMALL, Style.BRASS)
			col.add_child(went)
			Widgets.flash_soon(went)
			_flash = ""
		col.add_child(_heading("Your reply"))
		var sent := _parchment(l["reply"].get("letter", {}), true)
		col.add_child(sent)
		# Sent this moment: your answer is laid under theirs.
		if sent_now:
			Widgets.unfold(sent)
	else:
		var options: Array = Letters.replies(String(l.get("template_key", "")), social.letter_candidate(l))
		if not options.is_empty():
			col.add_child(_heading("Write back"))
			for r in options:
				var b := _button(String(r["label"]), _preview_reply.bind(String(r["id"])), false, "reply")
				b.name = "Reply_%s" % r["id"]
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				col.add_child(b)
	var keep := _button("Keep", _close_letter, false, "keep")
	keep.name = "KeepLetter"
	var buttons := [keep]
	if res != "" and GameState.world.here() != res:
		var ride := _ride_text(res)
		var go := _button("Ride · %s" % ride if ride != "" else "Ride", _ride.bind(res), true, "ride")
		go.name = "RideFromLetter"
		go.tooltip_text = "Ride to %s" % Letters.place_name(res)
		buttons.append(go)
	else:
		Style.make_primary(keep)
	_set_bar(buttons)


func _preview_reply(id: String) -> void:
	_reply = id
	_unfold = true
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
		_sent_now = true
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
