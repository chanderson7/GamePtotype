## The wedding's feast, after "I do". The night is yours, in any order and as much or as
## little as you like: call on your captains for their toasts, dance the first dance, take
## part in her people's custom, go round the tables. Then slip away with her, and the
## closing card says what the day made. Leave in the middle and the feast keeps going
## until dawn or until you ride away; come back from the Court tab. This also holds what
## the whole day shares (who you marry, where, who came, who stands with you, the place
## dressed for it): the ceremony in wedding.gd builds on it. Built on talk_view.gd; the
## rules are in GameState and the social sim.
extends "res://scripts/ui/talk_view.gd"

const TalkView = preload("res://scripts/ui/talk_view.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Relationships = preload("res://scripts/data/relationships.gd")
const Lines = preload("res://scripts/data/wedding_lines.gd")
const Feast = preload("res://scripts/data/wedding_feast_lines.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const Cultures = preload("res://scripts/data/cultures.gd")
const Captains = preload("res://scripts/data/captains.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const SettlementVista = preload("res://scripts/ui/settlement_vista.gd")
const SettlementScene = preload("res://scripts/ui/settlement_scene.gd")
const Dressing = preload("res://scripts/ui/wedding_dressing.gd")

## Places with a painting of their own.
const PAINTED := ["ravensford", "qasr_hamra", "kitayama"]
## Each one's own room, for slipping away at her seat (and the private vows told again).
const ROOMS := {"edda": "common_room", "farid": "envoy_room", "kaede": "archive_room"}

var cand := ""
var person_id := ""
var place := ""
var culture := ""
var _name := ""
var _guests := {}
var _host := {}
var _their := {}
var _vow := ""
## Who stands with you: one of GameState.wedding_seconds, or {}.
var _second := {}
var _breath := false
## The memory being told again, or {} on the day itself.
var _memory := {}
var _banners: Control
## Tonight's toasts: who can be called on, who has spoken, and what was said
## ([{key, kind, ids, lines: [{speaker, text}]}]).
var _toasters: Array = []
var _spoken: Array = []
var _toasts: Array = []
var _heckled := false
var _dance_steps: Array = []
var _visited: Array = []


# ---------------------------------------------------------------- the day, shared

func _nothing(text: String) -> void:
	setup(null, "")
	say("narration", text)
	set_replies([{"id": "leave", "text": "Back", "tone": "quiet", "act": close}])


func _place_name() -> String:
	return String(Data.settlement(place)["name"]) if Data.SETTLEMENTS.has(place) else "the hall"


## Their portrait for the day: dressed for the wedding (her "wedding" outfit, tools/portrait_kit) in any
## expression that was dressed, else their warmest dressed one, else as every day.
func _portrait(expression: String) -> Texture2D:
	for path in ["res://assets/portraits/%s_wedding_%s.png" % [cand, expression],
			"res://assets/portraits/%s_wedding_warm.png" % cand,
			"res://assets/portraits/%s_%s.png" % [cand, expression],
			"res://assets/portraits/%s_neutral.png" % cand]:
		var tex := StoryArt.texture(path)
		if tex != null:
			return tex
	return null


## The place's painting, or the settlement as the game paints it, at the hour.
func _make_backdrop(when: String) -> Control:
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
	if _banners == null or not is_instance_valid(_banners):
		return
	var s := stage.size
	_banners.position = Vector2.ZERO
	_banners.size = s
	var theirs := _banners.get_node("TheirBanner") as Control
	var yours := _banners.get_node("YourBanner") as Control
	theirs.position = Vector2(s.x * 0.05, s.y * 0.48)
	yours.position = Vector2(s.x * 0.95 - maxf(80.0, yours.get_combined_minimum_size().x), s.y * 0.48)


func _dressing() -> Dressing:
	return stage.get_node_or_null("Dressing") as Dressing


## Who stands with you takes the place on the right (your banner makes way for them).
func _second_steps_up() -> void:
	if _second.is_empty():
		return
	set_face("right", CaptainArt.texture(_second["face"]), true, 0.5)
	if _banners != null and is_instance_valid(_banners) and _banners.has_node("YourBanner"):
		(_banners.get_node("YourBanner") as Control).visible = false


func _second_name() -> String:
	return String(_second.get("name", ""))


func _set_chips(chip: String, extra: Array = [], icon_key: String = "rings") -> void:
	var chips := [TalkView.stage_chip(chip, Style.ROMANCE, icon_key)] if chip != "" else []
	chips.append_array(extra)
	set_plate(_name, chips)


func _host_name() -> String:
	return String(_host.get("short", _host.get("name", "")))


func _fill(text: String) -> String:
	return Lines.fill(text, {"name": _name, "place": _place_name(), "host": _host_name() if not _host.is_empty() else "The house",
		"second": _second_name() if not _second.is_empty() else "your second"})


## A line with a small face beside the speaker's name: a guest, a captain, the host.
## `who` is "them" (on the left) or "other" (on the right: who stands with you).
func _say_with_face(text: String, speaker: String, face_record: Dictionary, who: String = "them") -> Control:
	var holder := say(who, text, speaker)
	var bubble := holder.get_node_or_null("Them" if who == "them" else "Other") as Control
	if bubble == null:
		return holder
	var v := bubble.get_child(0) as VBoxContainer
	var face := TextureRect.new()
	face.name = "SpeakerFace"
	face.texture = CaptainArt.texture(face_record)
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.custom_minimum_size = Vector2(36, 48)
	var label := v.get_node_or_null("Speaker") as Label
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(face)
	if label != null:
		v.remove_child(label)
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(label)
	v.add_child(h)
	v.move_child(h, 0)
	return holder


## An icon and a line of words beside it, for a card.
func _icon_line(key: String, text: String, tone: Color = Style.TEXT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var i := Widgets.icon_rect(key, 30)
	i.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(i)
	var l := Style.label(text, Style.SMALL, tone)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h


## Up to the last two captains who fell in your service: "Rowan, and Ilse".
func _fallen_names() -> String:
	var names := []
	for m in GameState.fallen:
		var n := String((m as Dictionary).get("first", ""))
		if n != "" and not names.has(n):
			names.append(n)
	names = names.slice(maxi(0, names.size() - 2))
	return ", and ".join(names)


static func _first(c: Dictionary) -> String:
	return String(c.get("first", c.get("name", "")))


# ---------------------------------------------------------------- the feast

## What the feast has to say about tonight: {done, toasts, heckle, ...} as the day keeps it.
func _feast_state() -> Dictionary:
	return GameState.wedding().get("feast", {})


## The night is yours: what's left to do, what's done (ticked, with what it was), and
## slipping away, which ends it.
func _feast() -> void:
	var done: Array = _feast_state().get("done", [])
	var d := _dressing()
	if d != null:
		d.set_late(done.size())
	var night := TalkView.stage_chip(String(Feast.NIGHT[mini(done.size(), Feast.NIGHT.size() - 1)]), Style.MUTED, "moon")
	night.name = "Night"
	_set_chips("The feast", [night], "cup")
	add_to_log(note(Feast.PROMPT, Style.BRASS))
	var replies := []
	for key in Relationships.WEDDING_FEAST_THINGS:
		replies.append(_thing_reply(String(key), done.has(key)))
	replies.append({"id": "slip", "text": _fill(String(Feast.THINGS["slip"]["text"])), "tag": String(Feast.THINGS["slip"]["tag"]),
		"tone": "quiet", "act": _slip})
	set_replies(replies)


## One thing the night holds, as its reply: ticked once done.
func _thing_reply(key: String, done: bool) -> Dictionary:
	var r := {"id": "feast_" + key, "bare": true}
	match key:
		"toasts":
			r["text"] = String(Feast.THINGS["toasts"]["text"])
			r["icon"] = "cup"
			r["tag"] = String(Feast.THINGS["toasts"]["tag"]) if not GameState.wedding_toasters(int(_second.get("id", -1))).is_empty() else Feast.TOASTS_NO_CAPTAINS
			r["act"] = _toasts_begin
		"dance":
			r["text"] = _fill(String(Feast.THINGS["dance"]["text"]))
			r["icon"] = "dance"
			r["tag"] = String(Feast.THINGS["dance"]["tag"])
			r["act"] = _dance_begin
		"custom":
			var c: Dictionary = Feast.CUSTOM_THING.get(culture, Feast.CUSTOM_THING[Cultures.VARDISH])
			r["text"] = String(c["text"])
			r["icon"] = {Cultures.KHARZANI: "book", Cultures.RYUMON: "lantern"}.get(culture, "inside")
			r["tag"] = String(c["tag"])
			r["act"] = _custom_begin
		"tables":
			var gifts := _gifts().size()
			var n: int = _guests.get("guests", []).size()
			r["text"] = String(Feast.THINGS["tables"]["text"])
			r["icon"] = "men"
			r["tag"] = "%d guest%s · %d gift%s" % [n, "" if n == 1 else "s", gifts, "" if gifts == 1 else "s"]
			r["act"] = _tables
	if done:
		r["done"] = true
		r["tag"] = String(Feast.CUSTOM_DONE.get(culture, "done")) if key == "custom" else String(Feast.DONE.get(key, "done"))
	return r


## A thing at the feast begins: the talk turns to it.
func _begin_thing() -> void:
	clear_log()
	var married := stage.get_node_or_null("MarriedTitle") as Control
	if married != null:
		married.visible = false


# ---------------------------------------------------------------- the toasts

## Your captains speak as themselves, and you run the table: your second first, unasked;
## then whoever you call on, up to three; then the host; then your own cup.
func _toasts_begin() -> void:
	_begin_thing()
	_toasters = GameState.wedding_toasters(int(_second.get("id", -1)))
	_spoken = []
	_toasts = []
	say("you", "A toast! Who's first?" if not _toasters.is_empty() else "A toast!")
	for t in _toasters:
		if String(t["kind"]) == "second":
			_toast(t)
			return
	_call_on()


## Who'll speak (next): each captain still to speak, by face, and (once someone has)
## enough speeches.
func _call_on() -> void:
	var left := _toasters.filter(func(t): return not _spoken.has(String(t["key"])))
	if _spoken.size() >= Relationships.WEDDING_TOASTS_MAX or left.is_empty():
		_host_toast()
		return
	add_to_log(note(Feast.CALL if _spoken.is_empty() else Feast.CALL_NEXT, Style.BRASS))
	var replies := []
	for t in left:
		var who := String(t["name"])
		if String(t["kind"]) == "pair":
			who = "%s and %s" % [who, _first(t["other"])]
		replies.append({"id": "call_" + String(t["key"]), "text": who, "bare": true, "tag": String(t["tag"]),
			"face": CaptainArt.texture(t["face"]), "act": _toast.bind(t)})
	if not _spoken.is_empty():
		replies.append({"id": "toasts_enough", "text": Feast.ENOUGH, "tone": "quiet", "act": _host_toast})
	set_replies(replies)


## A captain's toast, in their own words; then you answer it.
func _toast(t: Dictionary) -> void:
	_spoken.append(String(t["key"]))
	var a: Dictionary = t["captain"]
	var b: Dictionary = t.get("other", {})
	var kind := String(t["kind"])
	var said := []
	for line in Feast.toast_lines(t):
		var c: Dictionary = a if String(line["who"]) == "a" else b
		var speaker := "%s · %s" % [_first(c), "your second" if kind == "second" else "captain"]
		var text := _fill(String(line["text"]))
		_say_with_face(text, speaker, c)
		said.append({"speaker": speaker, "text": text})
	var ids := [int(a["id"])]
	if not b.is_empty():
		ids.append(int(b["id"]))
	_toasts.append({"key": String(t["key"]), "kind": kind, "ids": ids, "lines": said})
	var replies := [{"id": "drink", "text": Feast.DRINK, "act": _after_toast.bind(t, "drink")}]
	if kind == "mourner":
		replies.append({"id": "pour", "text": Feast.fill(Feast.POUR, {"fallen": String(t.get("fallen", ""))}), "act": _after_toast.bind(t, "pour")})
	else:
		replies.append({"id": "heckle", "text": Feast.fill(Feast.HECKLE, {"first": _first(a)}), "act": _after_toast.bind(t, "heckle")})
	set_replies(replies)


func _after_toast(t: Dictionary, how: String) -> void:
	var a: Dictionary = t["captain"]
	match how:
		"heckle":
			_heckled = true
			say("you", Feast.fill(String(Feast.HECKLES[posmod(int(a["id"]), Feast.HECKLES.size())]), {"first": _first(a)}))
			_say_with_face(String(Feast.COMEBACKS.get(String(a.get("temperament", "")), Feast.COMEBACKS[""])), "%s · captain" % _first(a), a)
			express("center", _portrait("amused"), "amused")
			say("them", String(Feast.HER_LAUGH.get(cand, Feast.HER_LAUGH["edda"])), _name)
		"pour":
			say("you", Feast.fill(Feast.POUR, {"fallen": String(t.get("fallen", ""))}))
			say("narration", Feast.fill(Feast.POURED, {"first": _first(a)}))
		_:
			say("you", Feast.DRINK)
			say("narration", String(Feast.DRANK[posmod(_spoken.size() - 1, Feast.DRANK.size())]))
	_call_on()


## The host speaks last of the guests, by bearing; then your cup.
func _host_toast() -> void:
	if not _host.is_empty():
		_say_with_face(Lines.host_toast(String(_host.get("bearing", ""))), "%s · host" % _host_name(), _host["face"])
	add_to_log(note("Raise your cup", Style.BRASS))
	var replies := [{"id": "toast_her", "text": _fill(Lines.YOUR_TOASTS["her"]), "tag": "everyone drinks", "act": _raise.bind("her")},
		{"id": "toast_company", "text": Lines.YOUR_TOASTS["company"], "tag": "your captains will remember it", "act": _raise.bind("company")}]
	var fallen := _fallen_names()
	if fallen != "":
		replies.append({"id": "toast_absent", "text": Lines.YOUR_TOASTS["absent"].replace("{fallen}", fallen), "tag": "the captains you lost", "act": _raise.bind("absent")})
	set_replies(replies)


func _raise(key: String) -> void:
	var toast := _fill(Lines.YOUR_TOASTS[key]).replace("{fallen}", _fallen_names())
	say("you", toast)
	say("them", Lines.AFTER_TOAST[key], _name)
	GameState.wedding_feast_do("toasts", {"toasts": _toasts.duplicate(true), "toast": toast, "heckle": _heckled or bool(_feast_state().get("heckle", false))})
	_feast()


# ---------------------------------------------------------------- the first dance

func _dance_begin() -> void:
	_begin_thing()
	_dance_steps = []
	say("you", Feast.DANCE_ASK)
	say("them", String(Feast.DANCE_YES.get(cand, Feast.DANCE_YES["edda"])), _name)
	sway("center")
	_dance_step(0)


## Three steps, each a pair of choices she answers.
func _dance_step(i: int) -> void:
	if i >= Feast.DANCE_STEPS.size():
		sway("center", 0.0)
		GameState.wedding_feast_do("dance", {"dance": _dance_steps.duplicate()})
		_feast()
		return
	var replies := []
	for ch in Feast.DANCE_STEPS[i]:
		replies.append({"id": "dance_" + String(ch["id"]), "text": String(ch["text"]), "bare": true,
			"act": _danced.bind(i, String(ch["id"]))})
	set_replies(replies)


func _danced(i: int, id: String) -> void:
	_dance_steps.append(id)
	if id == "company":
		say("narration", String(Gatherings.DANCE_ROUND.get(culture, Gatherings.DANCE_ROUND[Cultures.VARDISH])))
	var mood: String = {"turn": "amused", "company": "amused", "follow": "amused"}.get(id, "warm")
	express("center", _portrait(mood), mood)
	say("them", String(Feast.DANCE_ANSWERS.get(cand, Feast.DANCE_ANSWERS["edda"]).get(id, "")), _name)
	_dance_step(i + 1)


# ---------------------------------------------------------------- her people's custom

func _custom_begin() -> void:
	_begin_thing()
	var c := Feast.custom(culture)
	for line in c["intro"]:
		say("narration", _fill(String(line)))
	add_to_log(note(String(c["prompt"]), Style.BRASS))
	var replies := []
	for ch in c["choices"]:
		var o := Feast.custom_choice(culture, String(ch["id"]), not _second.is_empty())
		replies.append({"id": "custom_" + String(o["id"]), "text": _fill(String(o["text"])), "tag": _fill(String(o.get("tag", ""))),
			"bare": bool(o.get("bare", false)), "act": _customed.bind(o)})
	set_replies(replies)


func _customed(o: Dictionary) -> void:
	if not bool(o.get("bare", false)):
		say("you", _fill(String(o["text"])))
	say("narration", _fill(String(o["line"])))
	if culture == Cultures.RYUMON:
		var d := _dressing()
		if d != null:
			d.release_lantern(0.27)
			d.release_lantern(0.73)
		say("narration", _fill(String(Feast.custom(culture).get("after", ""))))
	express("center", _portrait("amused"), "amused")
	GameState.wedding_feast_do("custom", {"custom": String(o["id"])})
	_feast()


# ---------------------------------------------------------------- round the tables

## The gifts, as words: the host's, the absent ruler's, and the company's.
func _gifts() -> Array:
	var out := []
	if not _host.is_empty():
		out.append("%s gives you %s." % [_host_name(), String(Feast.HOST_GIFTS.get(culture, Feast.HOST_GIFTS[Cultures.VARDISH]))])
	if String(_guests.get("gift_from", "")) != "":
		out.append("%s sent %s." % [_guests["gift_from"], Lines.GIFTS.get(culture, "a gift")])
	var company := Feast.COMPANY_GIFT
	for g in _guests.get("guests", []):
		if String(g["kind"]) == "captain" and String((g["face"] as Dictionary).get("specialization", "")) == Captains.QUARTERMASTER:
			company += " " + Feast.RECEIPT % String(g["name"])
			break
	out.append(company)
	return out


func _tables() -> void:
	_begin_thing()
	_visited = []
	say("narration", Feast.TABLES_OPEN)
	var p := PanelContainer.new()
	p.name = "Gifts"
	p.add_theme_stylebox_override("panel", Style.box(Style.PANEL, Style.RULE, 2, 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Widgets.section("The gifts"))
	for line in _gifts():
		v.add_child(_icon_line("chest", String(line)))
	for a in _guests.get("absent", []):
		var l := Style.label("%s stayed away: %s." % [a["name"], a["reason"]], Style.SMALL, Style.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
	add_to_log(p)
	add_to_log(note(Feast.TABLES_PROMPT, Style.BRASS))
	_table_round()


## Every guest, by face: a lord, a captain who didn't toast. Each says a word once.
func _table_round() -> void:
	var toasted := {}
	for t in _feast_state().get("toasts", []):
		for id in t.get("ids", []):
			toasted[int(id)] = true
	var replies := []
	for g in _guests.get("guests", []):
		var kind := String(g["kind"])
		if kind == "captain" and toasted.has(int(g["id"])):
			continue
		var key := "table_%s_%d" % [kind, int(g["id"])]
		replies.append({"id": key, "text": String(g.get("short", g["name"])), "bare": true, "face": CaptainArt.texture(g["face"]),
			"tag": {"host": "the host", "crown_lord": "your lord", "lord": "a friend of the company", "captain": "captain"}.get(kind, ""),
			"done": _visited.has(key), "act": _visit_guest.bind(g, key)})
	replies.append({"id": "tables_back", "text": Feast.TABLES_BACK, "tone": "quiet", "act": _tables_done})
	set_replies(replies)


func _visit_guest(g: Dictionary, key: String) -> void:
	_visited.append(key)
	var kind := String(g["kind"])
	var line := ""
	if kind == "captain":
		line = Feast.captain_line(String((g["face"] as Dictionary).get("temperament", "")))
	else:
		line = Feast.lord_line(String(g.get("bearing", "")), int(g.get("regard", 0)))
	var role: String = {"host": "host", "crown_lord": "your lord", "captain": "captain"}.get(kind, "guest")
	_say_with_face(line, "%s · %s" % [String(g.get("short", g["name"])), role], g["face"])
	_table_round()


func _tables_done() -> void:
	GameState.wedding_feast_do("tables", {"tables": _visited.duplicate()})
	_feast()


# ---------------------------------------------------------------- slipping away

## The night's end: away from the noise, she recalls one thing you did tonight, and one
## last choice.
func _slip() -> void:
	_begin_thing()
	_set_chips("")
	say("you", Feast.SLIP_YOU)
	var at_home := place == String(GameState.world.social.get_candidate_person(cand).get("residence", ""))
	if at_home:
		_to_her_room()
	else:
		var d := _dressing()
		if d != null:
			d.hush(true)
			d.set_late(4)
	if not _second.is_empty():
		remove_face("right")
	Sound.play_music("camp_" + culture)
	say("narration", Feast.SLIP_OUT["room" if at_home else "place"])
	express("center", _portrait("warm"), "warm")
	var feast := _feast_state()
	var done: Array = feast.get("done", [])
	say("them", Feast.recall(cand, {"breath": _breath or bool(GameState.wedding().get("breath", false)), "heckle": bool(feast.get("heckle", false)),
		"dance": done.has("dance"), "custom": done.has("custom"), "vow": true}), _name)
	var replies := []
	for ch in Feast.LAST:
		replies.append({"id": "last_" + String(ch["id"]), "text": String(ch["text"]), "act": _last.bind(String(ch["id"]), String(ch["text"]))})
	set_replies(replies)


## Her room, by night: the stage changes to it, and the day's dressing comes down.
func _to_her_room() -> void:
	var old := _backdrop
	var art := TalkView.room(String(ROOMS.get(cand, "common_room")), "night")
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(art)
	stage.move_child(art, 0)
	_backdrop = art
	for n in ["Dressing", "Banners", "Rite"]:
		var c := stage.get_node_or_null(n)
		if c != null:
			c.queue_free()
	_banners = null
	if old != null and is_instance_valid(old):
		old.queue_free()
	_layout()


func _last(id: String, text: String) -> void:
	say("you", text)
	say("them", String(Feast.LAST_ANSWER.get(cand, Feast.LAST_ANSWER["edda"]).get(id, "")), _name)
	var r: Dictionary = GameState.end_wedding_feast({"last": id})
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "")), Style.MUTED))
	add_to_log(_closing_card())
	var home := String(GameState.world.social.get_candidate_person(cand).get("residence", place))
	var home_name := String(Data.settlement(home)["name"]) if Data.SETTLEMENTS.has(home) else _place_name()
	say("narration", Lines.fill(Lines.AFTER.get(cand, Lines.AFTER["edda"]), {"name": _name, "place": home_name}))
	set_replies([{"id": "done", "text": "Back to the map", "tone": "gold", "bare": true, "act": close}])


## The one closing card: where and when, the memory kept, the night in icons, what the
## marriage pact gives, and what the day cost and earned. "Married" was said on the stage
## at "I do", your words are above in the talk, and Regard was on the guests' badges, so
## none of it is said again here.
func _closing_card() -> Control:
	var w: Dictionary = GameState.wedding()
	var p := PanelContainer.new()
	p.name = "ClosingCard"
	var sb := Style.box(Color("2a1f26"), Style.ROMANCE, 2, 18)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var where := HBoxContainer.new()
	where.alignment = BoxContainer.ALIGNMENT_CENTER
	where.add_theme_constant_override("separation", 18)
	where.add_child(Widgets.icon_value("mappin", _place_name()))
	where.add_child(Widgets.icon_value("day", str(int(w.get("day", int(GameState.world.hour / 24.0) + 1)))))
	v.add_child(where)
	# The night, in icons: the rings, then what you did at the feast.
	var night := HBoxContainer.new()
	night.name = "TheNight"
	night.alignment = BoxContainer.ALIGNMENT_CENTER
	night.add_theme_constant_override("separation", 14)
	var keys := ["rings"]
	for k in w.get("feast", {}).get("done", []):
		if Feast.ICONS.has(k):
			keys.append(String(Feast.ICONS[k]))
	for k in keys:
		var ic := Widgets.icon_rect(String(k), 34)
		ic.modulate = Style.ROMANCE_LIGHT
		night.add_child(ic)
	v.add_child(night)
	v.add_child(_icon_line("rings", "A memory kept. Open it again from %s's page." % _name, Style.ROMANCE_LIGHT))
	# The pact, as three lines: who stands together, what breaks it, what you may ask.
	var person: Dictionary = GameState.world.social.get_candidate_person(cand)
	var pact: Dictionary = GameState.world.social.get_pact(String(person.get("house_id", "")))
	var house: Dictionary = GameState.world.social.get_house(String(person.get("house_id", "")))
	var sites := PackedStringArray()
	for s in pact.get("protected_sites", []):
		if Data.SETTLEMENTS.has(String(s)):
			sites.append(String(Data.settlement(String(s))["name"]))
	var head := _host_name() if not _host.is_empty() else "the head of the house"
	v.add_child(Widgets.section("The marriage pact"))
	v.add_child(_icon_line("keep", "%s and your company stand together." % String(house.get("name", "Her house"))))
	v.add_child(_icon_line("fight", "Attacking %s breaks it." % (" or ".join(sites) if not sites.is_empty() else "her house's lands")))
	v.add_child(_icon_line("silver", "Ask %s for up to %d silver every %d days, for men from his garrison, or to hold a place for you." % [head, Relationships.GRANT_MAX_SILVER, int(Relationships.GRANT_COOLDOWN_DAYS)]))
	# Who came, in words only for what the guest badges didn't say.
	var bits := PackedStringArray()
	var captains: int = _guests.get("guests", []).filter(func(g): return String(g["kind"]) == "captain").size()
	if captains > 0:
		bits.append("Your %d captain%s drank to you, loudly." % [captains, "" if captains == 1 else "s"])
	if String(_guests.get("gift_from", "")) != "":
		bits.append("%s's gift, %s, is in your baggage." % [_guests["gift_from"], Lines.GIFTS.get(culture, "a gift")])
	if not bits.is_empty():
		v.add_child(_icon_line("company", " ".join(bits)))
	# The day's cost (set aside when you planned it) and what it earned.
	var fx := [["silver", Widgets.thousands(int(w.get("reserved_silver", 0)))], ["food", Widgets.thousands(int(w.get("reserved_food", 0)))],
		["renown", Relationships.WEDDING_RENOWN]]
	var cost := Widgets.chip_row(TalkView.fx_chips(fx))
	cost.name = "DayCost"
	cost.alignment = FlowContainer.ALIGNMENT_CENTER
	v.add_child(cost)
	TalkView.land(p, Color(1.5, 1.15, 1.3))
	return p


## Back to the feast after leaving it: what's done is ticked, the night goes on.
func _rejoin() -> void:
	var w: Dictionary = GameState.wedding()
	_vow = String(w.get("vow", ""))
	_breath = bool(w.get("breath", false))
	_heckled = bool(w.get("feast", {}).get("heckle", false))
	var c = GameState.captain_by_id(int(w.get("second", -1))) if int(w.get("second", -1)) >= 0 else null
	if c is Dictionary:
		_second = {"id": int(c["id"]), "name": _first(c), "face": c, "captain": c, "why": ""}
		_second_steps_up()
	express("center", _portrait("amused"), "amused")
	clear_log()
	say("narration", "The feast is still going. Someone has saved you both a seat, and most of a pie.")
	_feast()
