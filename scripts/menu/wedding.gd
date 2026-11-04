## The wedding, on the day: the place dressed for it, who came, her vow and yours, the
## rite of her people, the toasts, and one closing card with what it all means. Opened
## from the memory book (Scenes.wedding_replay), it tells the day again as it was and
## changes nothing. Built on talk_view.gd; the rules are in GameState and the social sim.
extends "res://scripts/ui/talk_view.gd"

const TalkView = preload("res://scripts/ui/talk_view.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Lines = preload("res://scripts/data/wedding_lines.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const Dressing = preload("res://scripts/ui/wedding_dressing.gd")

## Places with a painting of their own.
const PAINTED := ["ravensford", "qasr_hamra", "kitayama"]

var cand := ""
var person_id := ""
var place := ""
var culture := ""
var _name := ""
var _guests := {}
var _host := {}
var _their := {}
var _vow := ""
var _toast := ""
## The memory being told again, or {} on the day itself.
var _memory := {}
var _banners: Control


func _ready() -> void:
	var social = GameState.world.social if GameState.world != null else null
	if social == null:
		_nothing("No one is waiting here.")
		return
	if Scenes.wedding_replay != "":
		_memory = _find_memory(social, Scenes.wedding_replay)
		if _memory.is_empty():
			_nothing("That memory has faded.")
			return
		cand = String(_memory.get("candidate", ""))
		place = String(_memory.get("place", ""))
	else:
		if not GameState.wedding_can_begin():
			_nothing("The wedding isn't ready here yet.")
			return
		var w: Dictionary = GameState.wedding()
		cand = String(w["candidate_id"])
		place = String(w["place"])
	var person: Dictionary = social.get_candidate_person(cand)
	person_id = String(person.get("id", ""))
	_name = String(person.get("name", ""))
	culture = String(person.get("culture", ""))
	var when := TalkView.time_word(GameState.world.hour) if _memory.is_empty() else "dusk"
	if bool(_memory.get("private", false)):
		when = "night"
	setup(_make_backdrop(when), _caption(when))
	if not bool(_memory.get("private", false)):
		_dress(when)
	set_face("center", _portrait("warm"), false, 0.9)
	Sound.play_music("camp_" + culture)
	if not _memory.is_empty():
		_tell_again()
		return
	_guests = GameState.wedding_guests()
	for g in _guests["guests"]:
		if String(g["kind"]) == "host":
			_host = g
	_their = Lines.their_vow(cand, social.memory_book(person_id))
	_arrive()


func _nothing(text: String) -> void:
	setup(null, "")
	say("narration", text)
	set_replies([{"id": "leave", "text": "Back", "tone": "quiet", "act": close}])


static func _find_memory(social, id: String) -> Dictionary:
	for c in ["edda", "farid", "kaede"]:
		var p: Dictionary = social.get_candidate_person(c)
		for m in social.memory_book(String(p.get("id", ""))):
			if String(m.get("id", "")) == id:
				var out: Dictionary = m.duplicate()
				out["candidate"] = String(out.get("candidate", c))
				return out
	return {}


func _place_name() -> String:
	return String(Data.settlement(place)["name"]) if Data.SETTLEMENTS.has(place) else "the hall"


func _caption(when: String) -> String:
	if bool(_memory.get("private", false)):
		return "%s's room at %s · night" % [_name, _place_name()]
	return "%s at %s · %s" % ["Remembered" if not _memory.is_empty() else "Your wedding", _place_name(), when]


func _portrait(expression: String) -> Texture2D:
	var tex := StoryArt.texture("res://assets/portraits/%s_%s.png" % [cand, expression])
	return tex if tex != null else StoryArt.texture("res://assets/portraits/%s_neutral.png" % cand)


## The place's painting, or the settlement as the game paints it, at the hour.
func _make_backdrop(when: String) -> Control:
	if bool(_memory.get("private", false)):
		return TalkView.room(String({"edda": "common_room", "farid": "envoy_room", "kaede": "archive_room"}.get(cand, "common_room")), "night")
	if place in PAINTED:
		return TalkView.room(place, when)
	var holder := Control.new()
	holder.name = "Room"
	holder.clip_contents = true
	if not Data.SETTLEMENTS.has(place):
		return holder
	var p := SettlementScene.params(GameState.world, place)
	p["night"] = when == "night"
	var sky := ColorRect.new()
	sky.color = Color("1b2440") if p["night"] else Color("8fb6dc")
	holder.add_child(sky)
	var vista := SettlementVista.from_preset(p, 400.0)
	holder.add_child(vista)
	if when == "dusk":
		vista.modulate = Color(1.0, 0.82, 0.68)
		sky.modulate = vista.modulate
	holder.resized.connect(func():
		var s := holder.size
		var w := s.x
		var h := w * float(SettlementScene.H) / float(SettlementScene.W)
		if h < s.y * 0.72:
			h = s.y * 0.72
			w = h * float(SettlementScene.W) / float(SettlementScene.H)
		vista.custom_minimum_size = Vector2.ZERO
		vista.position = Vector2((s.x - w) * 0.5, s.y - h)
		vista.size = Vector2(w, h)
		sky.size = Vector2(s.x, s.y - h + 2.0))
	return holder


## Bunting, lanterns, petals and both banners.
func _dress(when: String) -> void:
	var d := Dressing.new()
	d.name = "Dressing"
	d.culture = culture
	d.when = when
	stage.add_child(d)
	stage.move_child(d, 1)
	_banners = Control.new()
	_banners.name = "Banners"
	_banners.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_banners)
	stage.move_child(_banners, 2)
	var host_realm: String = GameState.world.owner_of(place) if Data.SETTLEMENTS.has(place) else ""
	var theirs := Widgets.banner(host_realm, Vector2(70, 104))
	theirs.name = "TheirBanner"
	_banners.add_child(theirs)
	var yours: Control
	if GameState.is_crowned():
		yours = Widgets.banner("crown", Vector2(70, 104))
	else:
		yours = PanelContainer.new()
		yours.add_theme_stylebox_override("panel", Style.box(Color(Style.NIGHT, 0.8), Style.BRASS, 3, 6))
		yours.add_child(Widgets.icon_rect("company", 56))
	yours.name = "YourBanner"
	_banners.add_child(yours)
	stage.resized.connect(_place_banners)
	_place_banners.call_deferred()


func _place_banners() -> void:
	if _banners == null:
		return
	var s := stage.size
	_banners.position = Vector2.ZERO
	_banners.size = s
	var theirs := _banners.get_node("TheirBanner") as Control
	var yours := _banners.get_node("YourBanner") as Control
	theirs.position = Vector2(s.x * 0.05, s.y * 0.48)
	yours.position = Vector2(s.x * 0.95 - maxf(80.0, yours.get_combined_minimum_size().x), s.y * 0.48)


func _set_chips(chip: String, extra: Array = []) -> void:
	var chips := [TalkView.plate_chip(chip, Color("e88aa0"), "heart")]
	chips.append_array(extra)
	set_plate(_name, chips)


func _host_name() -> String:
	return String(_host.get("short", _host.get("name", "")))


func _fill(text: String) -> String:
	return Lines.fill(text, {"name": _name, "place": _place_name(), "host": _host_name() if not _host.is_empty() else "The house"})


# ---------------------------------------------------------------- the day

func _arrive() -> void:
	var lords: int = _guests["guests"].size()
	_set_chips("Wedding day", [TalkView.plate_chip("%d guest%s" % [lords, "" if lords == 1 else "s"], Style.MORALE_HIGH)])
	clear_log()
	var hers := String(GameState.world.social.get_candidate_person(cand).get("residence", ""))
	var kind := "hers" if place == hers else ("yours" if place == GameState.wedding_seat() else "other")
	say("narration", _fill(Lines.ARRIVAL[kind]))
	add_to_log(_guest_card())
	say("them", Lines.STAND.get(cand, Lines.STAND["edda"]), _name)
	set_replies([
		{"id": "begin", "text": "Take your place beside %s." % _name, "bare": true, "tone": "gold", "tag": "the wedding begins", "act": _vows},
		{"id": "later", "text": "Not yet", "tone": "quiet", "tag": "it waits while you're in %s" % _place_name(), "act": close}])


## Who came: their faces in a row, then who stayed away and who sent a gift.
func _guest_card() -> Control:
	var p := PanelContainer.new()
	p.name = "WhoCame"
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Style.label("WHO CAME · %d" % _guests["guests"].size(), Style.SMALL - 2, Style.BRASS))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 8)
	v.add_child(row)
	for g in _guests["guests"]:
		var cell := VBoxContainer.new()
		cell.name = "Guest_%s_%d" % [g["kind"], int(g["id"])]
		cell.custom_minimum_size = Vector2(86, 0)
		cell.add_theme_constant_override("separation", 2)
		var face := TextureRect.new()
		face.texture = CaptainArt.texture(g["face"])
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.custom_minimum_size = Vector2(72, 96)
		cell.add_child(face)
		var nm := Style.label(String(g.get("short", g["name"])).get_slice(" ", 0), Style.SMALL - 4, Style.TEXT)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		cell.add_child(nm)
		var role: String = {"host": "host", "lord": "Regard %+d" % int(g.get("regard", 0)), "crown_lord": "your lord", "captain": "captain"}.get(String(g["kind"]), "")
		var rl := Style.label(role, Style.SMALL - 6, Style.BRASS if String(g["kind"]) == "host" else (Style.MORALE_HIGH if String(g["kind"]) == "lord" else Style.MUTED))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(rl)
		row.add_child(cell)
	var bits := PackedStringArray()
	if String(_guests.get("gift_from", "")) != "":
		bits.append("%s sent %s instead." % [_guests["gift_from"], Lines.GIFTS.get(culture, "a gift")])
	for a in _guests["absent"]:
		bits.append("%s stayed away: %s." % [a["name"], a["reason"]])
	if not bits.is_empty():
		var l := Style.label(" ".join(bits), Style.SMALL - 2, Style.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	return p


func _vows() -> void:
	Sound.play("bell", 0.0, 0.0)
	_set_chips("Wedding day")
	clear_log()
	if _host.is_empty():
		say("narration", _fill(Lines.OFFICIANT))
	else:
		say("narration", "%s reads the old words. Then stops, looks at %s, and everyone goes quiet." % [_host_name(), _name])
	_their_vow(String(_their.get("text", "")), String(_their.get("scene_id", "")), int(_their.get("day", 0)))
	add_to_log(note("Your vow. No wrong answers.", Style.MUTED))
	var replies := []
	for v in Lines.yours(cand):
		replies.append({"id": "vow_" + String(v["id"]), "text": String(v["text"]), "tag": String(v["tag"]), "act": _said_vow.bind(String(v["text"]))})
	set_replies(replies)


## Her vow, and (when it comes from a time you shared) which one she remembers.
func _their_vow(text: String, scene_id: String, day: int) -> void:
	var holder := say("them", text, _name)
	if scene_id == "" or not Stories.SCENES.has(scene_id):
		return
	var v := (holder.get_child(0) as Control).get_child(0) as VBoxContainer
	var h := HBoxContainer.new()
	h.name = "Remembers"
	h.add_theme_constant_override("separation", 6)
	var i := Widgets.icon_rect("cup", 22)
	i.modulate = Color("f6cdd9")
	h.add_child(i)
	h.add_child(Style.label("She remembers: %s%s" % [String(Stories.SCENES[scene_id]["title"]).to_lower(), (" · Day %d" % day) if day > 0 else ""], Style.SMALL - 4, Color("f6cdd9")))
	v.add_child(h)


func _said_vow(text: String) -> void:
	_vow = text
	say("you", text)
	_rite()


func _rite() -> void:
	for line in Lines.rite(culture):
		say("narration", _fill(String(line)))
	var captain := {}
	for g in _guests["guests"]:
		if String(g["kind"]) == "captain" and (captain.is_empty() or int(g.get("battles", 0)) > int(captain.get("battles", 0))):
			captain = g
	if not captain.is_empty():
		_say_with_face(_fill(Lines.captain_toast(int(captain["id"]))), "%s · captain" % String(captain["name"]), captain["face"])
	if not _host.is_empty():
		_say_with_face(Lines.host_toast(String(_host.get("bearing", ""))), "%s · host" % _host_name(), _host["face"])
	add_to_log(note("Raise your cup", Style.BRASS))
	var replies := [{"id": "toast_her", "text": _fill(Lines.YOUR_TOASTS["her"]), "tag": "everyone drinks", "act": _raise.bind("her")},
		{"id": "toast_company", "text": Lines.YOUR_TOASTS["company"], "tag": "your captains will remember it", "act": _raise.bind("company")}]
	var fallen := _fallen_names()
	if fallen != "":
		replies.append({"id": "toast_absent", "text": Lines.YOUR_TOASTS["absent"].replace("{fallen}", fallen), "tag": "the captains you lost", "act": _raise.bind("absent")})
	set_replies(replies)


## Up to the last two captains who fell in your service: "Rowan, and Ilse".
func _fallen_names() -> String:
	var names := []
	for m in GameState.fallen:
		var n := String((m as Dictionary).get("first", ""))
		if n != "" and not names.has(n):
			names.append(n)
	names = names.slice(maxi(0, names.size() - 2))
	return ", and ".join(names)


## A guest's line with their small face beside their name.
func _say_with_face(text: String, speaker: String, face_record: Dictionary) -> void:
	var holder := say("them", text, speaker)
	var v := (holder.get_child(0) as Control).get_child(0) as VBoxContainer
	var label := v.get_child(0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var face := TextureRect.new()
	face.name = "SpeakerFace"
	face.texture = CaptainArt.texture(face_record)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(36, 48)
	v.remove_child(label)
	h.add_child(face)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(label)
	v.add_child(h)
	v.move_child(h, 0)


func _raise(key: String) -> void:
	_toast = _fill(Lines.YOUR_TOASTS[key]).replace("{fallen}", _fallen_names())
	say("you", _toast)
	say("them", Lines.AFTER_TOAST[key], _name)
	_finish()


func _finish() -> void:
	var r: Dictionary = GameState.finish_wedding({"vow": _vow, "their_vow": String(_their.get("text", "")), "toast": _toast})
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Something went wrong.")), Style.MORALE_LOW))
		set_replies([{"id": "leave", "text": "Back to the map", "tone": "quiet", "act": close}])
		return
	Sound.play("bell", 0.0, 0.0)
	_set_chips("Married")
	change_face("center", _portrait("amused"))
	var title := Style.label("Married", Style.TITLE_SIZE, Style.BRASS)
	title.name = "MarriedTitle"
	var display := Style.display_font()
	if display != null:
		title.add_theme_font_override("font", display)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_to_log(title)
	var sub := Style.label("%s and you · %s · day %d" % [_name, _place_name(), int(GameState.world.hour / 24.0) + 1], Style.SMALL, Style.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_to_log(sub)
	add_to_log(_keepsake("A memory kept. Married %s at %s. You promised: \"%s\" You drank: \"%s\"\nOpen it again from %s's page." % [_name, _place_name(), _vow, _toast, _name]))
	add_to_log(_pact_card(r.get("pact", {})))
	var came := PackedStringArray()
	for x in r.get("regard", []):
		came.append("%s +%d Regard" % [x["name"], int(x["amount"])])
	var captains: int = r.get("guests", []).filter(func(g): return String(g["kind"]) == "captain").size()
	var who := " · ".join(came)
	if captains > 0:
		who += ("\n" if who != "" else "") + "Your %d captain%s drank to you, loudly." % [captains, "" if captains == 1 else "s"]
	if String(_guests.get("gift_from", "")) != "":
		who += "\n%s's gift, %s, is in your baggage." % [_guests["gift_from"], Lines.GIFTS.get(culture, "a gift")]
	add_to_log(_card("Who came", who if who != "" else "Your company, and the town."))
	var w: Dictionary = GameState.wedding()
	add_to_log(note("%d silver and %d rations, set aside when you planned it · +%d renown" % [int(w.get("reserved_silver", 0)), int(w.get("reserved_food", 0)), int(r.get("renown", 0))], Style.BRASS))
	var home := String(GameState.world.social.get_candidate_person(cand).get("residence", place))
	var home_name := String(Data.settlement(home)["name"]) if Data.SETTLEMENTS.has(home) else _place_name()
	say("narration", Lines.fill(Lines.AFTER.get(cand, Lines.AFTER["edda"]), {"name": _name, "place": home_name}))
	set_replies([{"id": "done", "text": "Back to the map", "tone": "gold", "bare": true, "act": close}])


func _pact_card(pact: Dictionary) -> Control:
	var house: Dictionary = GameState.world.social.get_house(String(pact.get("house_id", "")))
	var sites := PackedStringArray()
	for s in pact.get("protected_sites", []):
		if Data.SETTLEMENTS.has(String(s)):
			sites.append(String(Data.settlement(String(s))["name"]))
	var head := _host_name() if not _host.is_empty() else "the head of the house"
	var text := "%s and your company stand together. Attacking %s breaks it. Ask %s for up to %d silver every %d days, and for help refilling troops." % [
		String(house.get("name", "Her house")), " or ".join(sites) if not sites.is_empty() else "her house's lands", head,
		Relationships.GRANT_MAX_SILVER, int(Relationships.GRANT_COOLDOWN_DAYS)]
	return _card("The marriage pact", text)


func _card(title: String, body: String) -> Control:
	var p := PanelContainer.new()
	p.name = "Card"
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(Style.label(title.to_upper(), Style.SMALL - 4, Style.BRASS))
	var l := Style.label(body, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	p.add_child(v)
	return p


func _keepsake(text: String) -> Control:
	var p := PanelContainer.new()
	p.name = "Keepsake"
	p.add_theme_stylebox_override("panel", Style.box(Color("2a1f26"), Color("e88aa0"), 2, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var i := Widgets.icon_rect("rings", 36)
	i.modulate = Color("f6cdd9")
	h.add_child(i)
	var l := Style.label(text, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	return p


# ---------------------------------------------------------------- remembered

func _tell_again() -> void:
	_set_chips("Remembered")
	clear_log()
	var m := _memory
	if bool(m.get("private", false)):
		say("narration", "No guests, no banners. A candle, the door shut, the household asleep below.")
		say("them", _fill(Lines.PRIVATE.get(cand, "")), _name)
	else:
		say("narration", "Your wedding at %s, day %d." % [_place_name(), int(m.get("day", 1))])
		var guests: Array = m.get("guests", [])
		if not guests.is_empty():
			say("narration", "Who came: %s." % ", ".join(PackedStringArray(guests)))
	if String(m.get("their_vow", "")) != "":
		say("them", String(m["their_vow"]), _name)
	if String(m.get("vow", "")) != "":
		say("you", String(m["vow"]))
	if not bool(m.get("private", false)):
		for line in Lines.rite(culture):
			say("narration", _fill(String(line)))
	if String(m.get("toast", "")) != "":
		say("you", String(m["toast"]))
	add_to_log(_keepsake(String(m.get("text", ""))))
	set_replies([{"id": "finish", "text": "Close the memory", "tone": "quiet", "act": close}])


func _on_close() -> void:
	Scenes.wedding_replay = ""
	Scenes.go(Scenes.wedding_return)
