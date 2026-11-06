## Talking with someone you court or befriend, face to face in their room: one place for
## your story together (decisions, shown as decisions, with what they do), time spent
## together (visits, where every answer is welcome and nothing is scored), their letters,
## and the memories you share. Built on talk_view.gd; the rules stay in the social sim.
extends "res://scripts/ui/talk_view.gd"

const Relationships = preload("res://scripts/data/relationships.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const Stories = preload("res://scripts/data/personal_conversations.gd")
const Lines = preload("res://scripts/data/romance_talk_lines.gd")
const Letters = preload("res://scripts/data/letters.gd")
const WeddingLines = preload("res://scripts/data/wedding_lines.gd")
const Data = preload("res://scripts/world/world_data.gd")

## Where each person is usually found.
const ROOMS := {"edda": "common_room", "farid": "envoy_room", "kaede": "archive_room"}
const CHAPTERS := 5

## How this screen was opened: "audience" (the story first) or "visits" (time together).
@export var opened_as := "audience"

var cand := "edda"
var person_id := ""
var _name := ""
var _scene_id := ""
var _progress := {}
var _replay := false
var _ch1_topic_done := false
## Their first words this visit, chosen from what has happened since the last.
var _opening := ""


## What has happened since you last came, for Lines.opening. Nothing counts before a
## first visit: a stranger has no "since".
func _facts() -> Dictionary:
	var rel: Dictionary = _rel()
	var w = GameState.world
	var res := String(_social().get_candidate_person(cand).get("residence", ""))
	if not rel.has("last_visit_hour"):
		return {}
	var facts := {"besieged": not w.siege_info(res).is_empty(), "burned": w.burned.has(res),
		"war": GameState.is_at_war_with(String(_house().get("realm", w.owner_of(res)))),
		"night": TalkView.time_word(w.hour) == "night"}
	var since_hour := float(rel.get("last_visit_hour", 0.0))
	var since_battle := int(rel.get("last_visit_battles", 0))
	for m in GameState.fallen:
		if int(m.get("battle", 0)) > since_battle:
			facts["fallen"] = String(m.get("first", m.get("name", "")))
	for s in GameState.army:
		var c: Dictionary = s.get("captain", {})
		if int(c.get("wounded", 0)) > 0:
			facts["wounded"] = String(c.get("first", c.get("name", "")))
	facts["company_hurt"] = GameState.is_wounded()
	for e in w.events:
		if String(e.get("type", "")) == "battle_fought" and bool(e.get("won", false)) and float(e.get("hour", -1.0)) > since_hour \
				and w.hours_to(String(e.get("at", ""))) <= 48.0:
			facts["victory"] = Letters.place_name(String(e.get("at", "")))
	var days := int((w.hour - since_hour) / 24.0)
	if days > 20:
		facts["away"] = days
	return facts


func _ready() -> void:
	cand = Scenes.active_candidate_id if Scenes.active_candidate_id != "" else "edda"
	var social = _social()
	if social == null:
		setup(null, "")
		say("narration", "No one to talk to here.")
		set_replies([{"id": "leave", "text": "Back", "tone": "quiet", "act": close}])
		return
	if opened_as == "visits" and Scenes.active_person_id != "":
		for c in ROOMS:
			if String(social.get_candidate_person(c).get("id", "")) == Scenes.active_person_id:
				cand = c
	var person: Dictionary = social.get_candidate_person(cand)
	person_id = String(person.get("id", ""))
	_name = String(person.get("name", cand.capitalize()))
	setup(TalkView.room(String(ROOMS.get(cand, "common_room")), TalkView.time_word(GameState.world.hour)), _caption())
	set_face("left", _portrait(_expression()), false, 0.98)
	_refresh_plate()
	Sound.set_loop("camp")
	_opening = Lines.opening(cand, _status(), _facts())
	# This visit is now the last one, for next time's opening.
	var rel: Dictionary = _rel()
	rel["last_visit_hour"] = GameState.world.hour
	rel["last_visit_battles"] = GameState.battles
	_hub(true)
	if Scenes.romance_relive != "":
		var sid := Scenes.romance_relive
		Scenes.romance_relive = ""
		if _social().personal_record(person_id)["completed"].has(sid):
			_visit(sid, true)


func _exit_tree() -> void:
	Sound.set_loop("")


const TalkView = preload("res://scripts/ui/talk_view.gd")


func _social():
	return GameState.world.social if GameState.world != null else null


func _rel() -> Dictionary:
	return _social().get_relationship(cand)


func _house() -> Dictionary:
	return _social().get_house(String(_social().get_candidate_person(cand).get("house_id", "")))


func _status() -> String:
	return String(_rel().get("status", Relationships.UNKNOWN))


func _chapter() -> int:
	return int(_social().get_quest("quest_%s" % cand).get("chapter", 1))


func _caption() -> String:
	var res := String(_social().get_candidate_person(cand).get("residence", ""))
	var place := Letters.place_name(res) if res != "" else ""
	return "With %s%s · %s" % [_name, (" at %s" % place) if place != "" else "", TalkView.time_word(GameState.world.hour)]


func _portrait(expression: String) -> Texture2D:
	var tex := StoryArt.texture("res://assets/portraits/%s_%s.png" % [cand, expression])
	return tex if tex != null else StoryArt.texture("res://assets/portraits/%s_neutral.png" % cand)


## How they look at you, by how things stand.
func _expression() -> String:
	var status := _status()
	if bool(_rel().get("strained", false)) or status == Relationships.ENDED:
		return "concerned"
	if int(_rel().get("trust", 0)) >= 50 or status in [Relationships.COURTING, Relationships.COMMITTED, Relationships.ENGAGED, Relationships.MARRIED]:
		return "warm"
	return "neutral" if status == Relationships.UNKNOWN else "thoughtful"


func _refresh_plate() -> void:
	var trust := int(_rel().get("trust", 0))
	if _status() == Relationships.UNKNOWN and trust <= 0:
		set_plate(_name, [TalkView.plate_chip("Not yet met", Style.MUTED)])
		return
	var chips := [TalkView.plate_chip(Relationships.status_label(_status()), Color("e88aa0"), "heart")]
	chips.append(_trust_bar(trust))
	if bool(_rel().get("strained", false)):
		chips.append(TalkView.plate_chip("Strained: a broken promise", Style.ENEMY, "lock"))
	set_plate(_name, chips)


## Trust as a bar, marked where vows and a wedding open.
func _trust_bar(trust: int) -> Control:
	var box := PanelContainer.new()
	box.name = "TrustBar"
	var sb := Style.box(Color(Style.NIGHT, 0.85), Style.RULE, 2, 20)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	box.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Style.label("Trust %d" % trust, Style.SMALL, Style.TEXT))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(120, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.draw.connect(func():
		var r := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(r, Color("1a1f33"))
		bar.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(trust / 100.0, 0.0, 1.0), r.size.y)), Color("e88aa0"))
		var mark := r.size.x * Relationships.TRUST_PUBLIC_WEDDING / 100.0
		bar.draw_line(Vector2(mark, -2), Vector2(mark, r.size.y + 2), Style.BRASS, 2.0))
	h.add_child(bar)
	box.add_child(h)
	return box


func _after_change() -> void:
	_refresh_plate()
	change_face("left", _portrait(_expression()))


# ---------------------------------------------------------------- the hub

## A visit opens as a conversation: their greeting, then a few things you might say, in
## your own words, with what each one is under it, and one way to take your leave.
func _hub(first: bool = false) -> void:
	_scene_id = ""
	set_stage_share(STAGE_SHARE)
	clear_log()
	say("them", (_opening if _opening != "" else Lines.greeting(cand, _status())) if first else "What else is on your mind?", _name)
	if bool(_rel().get("strained", false)):
		add_to_log(note("Things are strained between you since a broken promise. %s will hear you out on it." % _name, Style.MORALE_LOW))
	var replies := []
	# The story first.
	var ch := _chapter()
	var story: Dictionary = RomanceStories.story_data(cand)
	var cinfo: Dictionary = story.get("chapters", {}).get(ch, {})
	if _social().wedding_active(cand):
		var w: Dictionary = GameState.wedding()
		var tag: String = {"planning": "choose where", "postponed": "postponed · choose a new place",
			"preparing": "at %s · %s" % [Letters.place_name(String(w.get("place", ""))), "being made ready"],
			"ready": "ready at %s · ride there" % Letters.place_name(String(w.get("place", "")))}.get(String(w["state"]), "")
		replies.append({"id": "wedding", "text": "About our wedding…", "tag": tag, "tone": "gold", "act": _wedding_talk})
	elif not cinfo.is_empty() and _status() != Relationships.ENDED and not (ch >= CHAPTERS and _status() in [Relationships.MARRIED, Relationships.FRIENDSHIP]):
		var open: Dictionary = _social().chapter_open(cand, GameState.world.hour)
		if bool(open["ok"]):
			replies.append({"id": "story", "text": Lines.story_opener(cand, ch), "tag": "Chapter %d · %s" % [ch, cinfo.get("title", "")],
				"tone": "gold", "act": _story})
		else:
			replies.append({"id": "story", "text": Lines.story_opener(cand, ch), "tag": "Chapter %d · %s" % [ch, String(open["reason"])], "tone": "locked"})
	# Their letter, when one waits for an answer.
	var letter_waits := false
	for l in _social().letters:
		if String(l.get("sender_id", "")) == person_id and not bool(l.get("read", false)):
			var lid := String(l.get("id", ""))
			letter_waits = true
			replies.append({"id": "letter", "text": Lines.LETTER_OPENER, "tag": "read and answer it", "act": func():
				Scenes.people_letter = lid
				Scenes.go("res://scenes/people.tscn")})
			break
	# Time together: the next visit or two, as something you'd say.
	var visits: Array = _social().available_personal_conversations(person_id, GameState.personal_conversation_context())
	var record: Dictionary = _social().personal_record(person_id)
	var open := visits.filter(func(v): return bool(v.get("ok", false)) and not bool(v.get("replay", false)))
	var locked := visits.filter(func(v): return not bool(v.get("ok", false)))
	var fresh := 0
	for v in open.slice(0, 1 if letter_waits else 2):
		var id := String(v["scene_id"])
		var title := String(Stories.SCENES[id]["title"])
		if record["in_progress"].has(id):
			replies.append({"id": "visit_" + id, "text": Lines.VISIT_RESUME, "tag": "resume · " + title, "act": _visit.bind(id, false)})
		else:
			replies.append({"id": "visit_" + id, "text": Lines.VISIT_OPENERS[mini(fresh, Lines.VISIT_OPENERS.size() - 1)],
				"tag": "time together · " + title, "act": _visit.bind(id, false)})
			fresh += 1
	if open.is_empty() and not locked.is_empty():
		# When today's visit is spent, say that rather than the next visit's prerequisite.
		var today := locked.filter(func(v): return bool(v.get("today", false)))
		var why: Dictionary = today[0] if not today.is_empty() else locked[0]
		replies.append({"id": "visits_locked", "text": Lines.VISIT_OPENERS[0], "tag": String(why.get("reason", "not yet")), "tone": "locked"})
	if not _social().memory_book(person_id).is_empty():
		replies.append({"id": "remember", "text": "Remember when…", "tag": "your memories together", "act": _remember})
	replies.append({"id": "leave", "text": Lines.leaving(_status()), "tone": "quiet", "act": close})
	set_replies(replies)


# ---------------------------------------------------------------- your story

func _story() -> void:
	var ch := _chapter()
	var cinfo: Dictionary = RomanceStories.story_data(cand).get("chapters", {}).get(ch, {})
	if not bool(_social().chapter_open(cand, GameState.world.hour)["ok"]):
		_hub()
		return
	clear_log()
	_face(String(cinfo.get("face", "")))
	_tell(String(cinfo.get("text", "")))
	var replies := []
	var strained := bool(_rel().get("strained", false))
	var repair: Dictionary = cinfo.get("repair", {})
	if strained and not repair.is_empty():
		replies.append(_decision(repair))
	match ch:
		1:
			if not _ch1_topic_done:
				add_to_log(note("Talk first; then say what you mean to be to %s." % _name, Style.MUTED))
				for c in cinfo.get("choices", []):
					var said := String(c["text"])
					var resp := String(c["response"])
					var face := String(c.get("face", ""))
					replies.append({"id": "topic_" + String(c["id"]), "text": said, "tag": String(c.get("tag", "talk")), "act": func():
						_ch1_topic_done = true
						say("you", said)
						_face(face)
						_tell(resp)
						_intents(cinfo)})
			else:
				_intents(cinfo)
				return
		2, 4:
			if not (ch == 4 and strained):
				for c in cinfo.get("choices", []):
					replies.append(_decision(c))
		3:
			for v in cinfo.get("variants", []):
				replies.append(_decision(v))
		5:
			var romantic := bool(_rel().get("romantic_intent", false))
			for c in cinfo.get("final_choices", []):
				if String(c["id"]).begins_with("marry") and not romantic:
					continue
				replies.append(_decision(c))
	replies.append({"id": "back", "text": "Not now.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _intents(cinfo: Dictionary) -> void:
	add_to_log(note(String(cinfo.get("intent_prompt", "What do you mean to be to each other?")), Style.BRASS))
	var replies := []
	for it in cinfo.get("intent_choices", []):
		replies.append(_decision(it))
	replies.append({"id": "back", "text": "Not now.", "tone": "quiet", "act": _hub})
	set_replies(replies)


## Authored text into the talk: narration centred, their words in their bubble, yours in
## yours (see RomanceStories.beats).
func _tell(text: String) -> void:
	for b in RomanceStories.beats(text):
		var line := String(b["text"])
		match String(b["speaker"]):
			"Narrator":
				# Older text kept their words in quotes.
				if (line.begins_with("'") and line.ends_with("'")) or (line.begins_with("\"") and line.ends_with("\"")):
					say("them", _strip_quotes(line), _name)
				else:
					say("narration", line)
			"You":
				say("you", line)
			_:
				say("them", line, _name)


## How they look as they say it ("" leaves the face as it is).
func _face(expression: String) -> void:
	if expression != "":
		change_face("left", _portrait(expression))


static func _strip_quotes(s: String) -> String:
	var t := s.strip_edges()
	if (t.begins_with("'") and t.ends_with("'")) or (t.begins_with("\"") and t.ends_with("\"")):
		return t.substr(1, t.length() - 2)
	return t


## A story choice as something you say, with what it is under it: the task, a cost, a
## change in how things stand, a promise broken. Never a score.
func _decision(c: Dictionary) -> Dictionary:
	var choice_id := String(c["id"])
	var text := String(c["text"])
	var prev: Dictionary = GameState.preview_social_choice(cand, choice_id)
	if not bool(prev.get("ok", false)):
		return {"id": "decide_" + choice_id, "text": text, "tag": String(prev.get("reason", "not now")), "tone": "locked"}
	var bits := PackedStringArray()
	if String(c.get("tag", "")) != "":
		bits.append(String(c["tag"]))
	bits.append_array(_costs(prev))
	var grave := bool(c.get("strained", false)) or choice_id == "part_respectfully"
	return {"id": "decide_" + choice_id, "text": text, "tag": " · ".join(bits), "tone": String(c.get("tone", "red" if grave else "gold")),
		"act": _decide.bind(c, prev)}


## What a choice costs or changes, in words: silver, rations, how things will stand.
func _costs(prev: Dictionary) -> PackedStringArray:
	var bits := PackedStringArray()
	if int(prev.get("cost_silver", 0)) > 0:
		bits.append("%d silver" % int(prev["cost_silver"]))
	if int(prev.get("cost_food", 0)) > 0:
		bits.append("%d rations" % int(prev["cost_food"]))
	var ns := String(prev.get("new_status", ""))
	if ns != "" and ns != _status():
		bits.append("now %s" % Relationships.status_label(ns).to_lower())
	return bits


## Everything a choice does, with its numbers: for the step that asks you to be sure.
func _effects(prev: Dictionary) -> String:
	var bits := PackedStringArray()
	var t := int(prev.get("trust_change", 0))
	if t != 0:
		bits.append("%s%d trust" % ["+" if t > 0 else "", t])
	var st := int(prev.get("standing_change", 0))
	if st != 0:
		bits.append("%s%d house standing" % ["+" if st > 0 else "", st])
	bits.append_array(_costs(prev))
	return " · ".join(bits) if not bits.is_empty() else "it stays between you"


func _decide(c: Dictionary, prev: Dictionary, confirmed: bool = false) -> void:
	var choice_id := String(c["id"])
	var text := String(c["text"])
	if bool(prev.get("requires_confirmation", false)) and not confirmed:
		say("you", text)
		add_to_log(note(String(prev.get("confirmation_text", "Are you sure?")), Style.BRASS))
		set_replies([
			{"id": "confirm", "text": "Yes. I mean it.", "tag": _effects(prev), "tone": "red" if bool(c.get("strained", false)) or choice_id == "part_respectfully" else "gold",
				"act": _decide.bind(c, prev, true)},
			{"id": "back", "text": "Not yet.", "tone": "quiet", "act": _story}])
		return
	var res: Dictionary = GameState.apply_social_choice(cand, choice_id)
	if not bool(res.get("ok", false)):
		add_to_log(note(String(res.get("reason", "That can't be done now.")), Style.MORALE_LOW))
		return
	if not confirmed:
		say("you", text)
	_face(String(c.get("face", "")))
	_tell(String(c.get("response", "")))
	var reaction := _reaction(prev)
	if reaction != null:
		add_to_log(reaction)
	_ch1_topic_done = false
	_after_change()
	if choice_id == "marry_public":
		_where(false)
		return
	if choice_id == "marry_private":
		_private_vows()
		return
	set_replies([_back_or_leave()])


## What changed, told as how they and their house take it, not as a sum.
func _reaction(prev: Dictionary) -> Control:
	var chips := []
	var t := int(prev.get("trust_change", 0))
	if t > 0:
		chips.append(TalkView.plate_chip("%s trusts you more" % _name, Color("e88aa0"), "heart"))
	elif t < 0:
		chips.append(TalkView.plate_chip("%s is hurt" % _name, Style.ENEMY_LIGHT, "heart"))
	var st := int(prev.get("standing_change", 0))
	if st > 0:
		chips.append(TalkView.plate_chip("%s's house takes note" % _name, Style.BRASS, "home"))
	elif st < 0:
		chips.append(TalkView.plate_chip("%s's house is displeased" % _name, Style.ENEMY_LIGHT, "home"))
	for cost in _costs(prev):
		chips.append(TalkView.plate_chip(cost, Style.MUTED))
	if chips.is_empty():
		return null
	var row := HFlowContainer.new()
	row.name = "Reaction"
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	for c in chips:
		row.add_child(c)
	if not Style.motion_reduced():
		row.modulate.a = 0.0
		row.create_tween().tween_property(row, "modulate:a", 1.0, 0.3)
	return row


## The two quiet ways on from the end of something: more talk, or leaving.
func _back_or_leave() -> Dictionary:
	return {"row": [{"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub},
		{"id": "leave", "text": "Another time.", "tone": "quiet", "act": close}]}


# ---------------------------------------------------------------- the wedding

## Where you'll marry: her seat, yours, or another friendly town near you.
func _where(cost_note: bool = true) -> void:
	var w: Dictionary = GameState.wedding()
	add_to_log(note("Where will you marry?", Style.BRASS))
	if cost_note:
		add_to_log(note("%d silver and %d rations are set aside for it, and come back if it's called off." % [int(w.get("reserved_silver", 0)), int(w.get("reserved_food", 0))], Style.MUTED))
	var replies := []
	var others := []
	for p in GameState.wedding_places(cand):
		var days := _ride_text(float(p["hours"]))
		match String(p["kind"]):
			"hers":
				replies.append(_place_reply(p, "Here in %s, with your house." % p["name"] if p["hours"] < 1.0 else "At %s, with your house." % p["name"],
					"Her house's seat · %s · ready %s" % [days, GameState._when_text(_social().wedding_ready_hour(GameState.world.hour))]))
			"yours":
				replies.append(_place_reply(p, "At %s, under my own banner." % p["name"], "Your seat · %s · you host" % days))
			_:
				others.append(p)
	if not others.is_empty():
		replies.append({"id": "elsewhere", "text": "Somewhere else we both know.", "tag": "a friendly town or castle near you", "act": _elsewhere.bind(others)})
	replies.append({"id": "later", "text": "Let's decide later.", "tone": "quiet", "tag": "stay engaged · no hurry", "act": _hub})
	set_replies(replies)


func _elsewhere(others: Array) -> void:
	say("you", "Somewhere else we both know.")
	var replies := []
	for p in others:
		replies.append(_place_reply(p, "At %s." % p["name"], "%s · ready %s" % [_ride_text(float(p["hours"])), GameState._when_text(_social().wedding_ready_hour(GameState.world.hour))]))
	replies.append({"id": "back", "text": "Back", "tone": "quiet", "act": _where})
	set_replies(replies)


func _place_reply(p: Dictionary, text: String, tag: String) -> Dictionary:
	if not bool(p["ok"]):
		return {"id": "place_" + String(p["id"]), "text": text, "tag": String(p["reason"]).capitalize(), "tone": "locked"}
	return {"id": "place_" + String(p["id"]), "text": text, "tag": tag, "tone": "gold", "act": _choose_place.bind(String(p["id"]), text)}


static func _ride_text(hours: float) -> String:
	if hours < 1.0:
		return "you're here"
	if hours < 20.0:
		return "%d hours' ride" % ceili(hours)
	var d := ceili(hours / 24.0)
	return "%d day%s' ride" % [d, "" if d == 1 else "s"]


func _choose_place(place: String, text: String) -> void:
	var r: Dictionary = GameState.choose_wedding_place(place)
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Not there.")), Style.MORALE_LOW))
		return
	say("you", text)
	say("them", "%s, then. I'll send word when it's ready. Don't you dare be late. Actually, be as late as you need. Just come." % Letters.place_name(place), _name)
	add_to_log(note("Your wedding at %s · ready %s · it waits for you there" % [Letters.place_name(place), GameState._when_text(float(GameState.wedding()["ready_hour"]))], Style.MORALE_HIGH))
	set_replies([_back_or_leave()])


func _wedding_talk() -> void:
	clear_log()
	var w: Dictionary = GameState.wedding()
	say("you", "About our wedding…")
	match String(w["state"]):
		"planning":
			say("them", "We still haven't said where. I have a list. It's not a short list.", _name)
			_where()
			return
		"postponed":
			say("them", "%s can't have us now: %s. So, somewhere else?" % [Letters.place_name(String(w.get("place", ""))), String(w.get("postponed_reason", "you'll have heard why"))], _name)
			_where()
			return
		"ready":
			say("them", "Everything's ready at %s. Come when you can; it waits for you." % Letters.place_name(String(w["place"])), _name)
		_:
			say("them", "It's at %s, %s. I'm counting the days. Don't tell anyone." % [Letters.place_name(String(w["place"])), GameState._when_text(float(w["ready_hour"]))], _name)
	set_replies([
		{"id": "move", "text": "Let's hold it somewhere else.", "tag": "choose a new place", "act": func():
			say("you", "Let's hold it somewhere else.")
			_where()},
		{"id": "call_off", "text": "Let's call it off, for now.", "tone": "red", "tag": "what was set aside comes back", "act": _call_off},
		{"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub}])


func _call_off(confirmed: bool = false) -> void:
	if not confirmed:
		say("you", "Let's call it off, for now.")
		add_to_log(note("Call off the wedding? You stay together, as before; what was set aside comes back.", Style.BRASS))
		set_replies([{"id": "confirm", "text": "Yes. Call it off.", "tone": "red", "act": _call_off.bind(true)},
			{"id": "back", "text": "No, keep it.", "tone": "quiet", "act": _wedding_talk}])
		return
	var r: Dictionary = GameState.cancel_wedding()
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "")), Style.MORALE_LOW))
		return
	say("them", "All right. I'm not going anywhere. Ask me again when the time is right.", _name)
	add_to_log(note("Called off · %d silver and %d rations back" % [int(r.get("silver", 0)), int(r.get("food", 0))], Style.MUTED))
	_after_change()
	set_replies([_back_or_leave()])


## Private vows, right here: her room at night, one candle, your words and hers.
func _private_vows() -> void:
	if _backdrop is TextureRect:
		(_backdrop as TextureRect).modulate = Color(0.5, 0.54, 0.78)
	var house: Dictionary = _house()
	var host := String(GameState.world.social.get_person(String(house.get("head_person_id", ""))).get("name", "The head of the house"))
	say("narration", "No guests, no banners. A candle, the door shut, the household asleep below.")
	say("them", WeddingLines.fill(WeddingLines.PRIVATE.get(cand, ""), {"host": host}), _name)
	var their: Dictionary = WeddingLines.their_vow(cand, _social().memory_book(person_id))
	say("them", String(their["text"]), _name)
	add_to_log(note("Your vow. No wrong answers.", Style.MUTED))
	var replies := []
	for v in WeddingLines.yours(cand):
		var said := String(v["text"])
		replies.append({"id": "vow_" + String(v["id"]), "text": said, "tag": String(v["tag"]), "act": func():
			say("you", said)
			GameState.record_private_vows(cand, said, String(their["text"]))
			add_to_log(_keepsake("A memory kept: vows in %s's room at %s, by one candle." % [_name, Letters.place_name(String(_social().get_candidate_person(cand).get("residence", "")))], "rings"))
			add_to_log(note("%s wasn't asked: %d standing · no marriage pact yet. Their good word can still be earned." % [String(house.get("name", "Her house")), Relationships.STANDING_PRIVATE_VOWS_PENALTY], Style.MORALE_LOW))
			set_replies([_back_or_leave()])})
	set_replies(replies)


# ---------------------------------------------------------------- time together

func _visit(scene_id: String, replay: bool) -> void:
	_replay = replay
	_scene_id = scene_id
	if replay:
		var rec: Dictionary = _social().personal_record(person_id)
		_progress = {"node": 0, "choice": -1, "context": rec["completed"][scene_id]["context"].duplicate(true)}
		Stories.normalize_reader(scene_id, _progress)
	else:
		var r: Dictionary = GameState.personal_conversation_action(person_id, scene_id, "begin")
		if not bool(r.get("ok", false)):
			add_to_log(note(String(r.get("reason", "Not now.")), Style.MORALE_LOW))
			return
		_progress = r["progress"]
	set_stage_share(0.38)
	var setting := String(Stories.SCENES[scene_id].get("setting", ROOMS.get(cand, "common_room")))
	if _backdrop is TextureRect and StoryArt.texture("res://assets/locations/%s.png" % setting) != null:
		(_backdrop as TextureRect).texture = StoryArt.texture("res://assets/locations/%s.png" % setting)
	_render_visit()


func _sequence() -> Array:
	return Stories.beats(_scene_id, int(_progress["node"]), int(_progress["choice"]), _progress["context"])


func _render_visit() -> void:
	clear_log()
	var scene: Dictionary = Stories.SCENES[_scene_id]
	say("narration", ("Remembered · %s" if _replay else "%s") % scene["title"])
	var shown := []
	if int(_progress["node"]) == 1:
		shown.append_array(Stories.beats(_scene_id, 0, -1, _progress["context"]))
	var seq := _sequence()
	shown.append_array(seq.slice(0, int(_progress["beat"]) + 1))
	var face := ""
	for beat in shown:
		var who := String(beat["speaker"])
		if who == "Narrator":
			say("narration", String(beat["text"]))
		elif who == "You":
			say("you", String(beat["text"]))
		else:
			say("them", String(beat["text"]), _name)
			face = String(beat.get("expression", face))
	if face != "":
		change_face("left", _portrait(face))
	var pos := int(_progress["beat"])
	var summary := {"id": "summary", "text": "Short version", "tone": "quiet", "act": _summary}
	var later := {"id": "later", "text": "Another time", "tone": "quiet", "act": _hub}
	if pos < seq.size() - 1:
		# Tap anywhere, or Go on; leave for later at any point, and before your answer
		# you can also cut it short.
		var replies := [{"id": "continue", "text": "Go on", "tone": "quiet", "act": _advance}]
		replies.append({"row": [summary, later]} if int(_progress["node"]) == 0 and not _replay else later)
		set_replies(replies)
		_continue = _advance
	elif int(_progress["node"]) == 0:
		add_to_log(note("No wrong answers.", Style.MUTED))
		var replies := []
		for i in scene["choices"].size():
			replies.append({"id": "say_%d" % i, "text": String(scene["choices"][i]), "act": _respond.bind(i)})
		if not _replay:
			replies.append(summary)
		set_replies(replies)
	elif _replay:
		set_replies([{"id": "finish", "text": "Close the memory", "tone": "quiet", "act": _hub}])
	else:
		set_replies([{"id": "finish", "text": "Keep this memory", "tone": "gold", "bare": true, "act": _finish.bind("finish")}])


func _advance() -> void:
	if _replay:
		_progress["beat"] = mini(int(_progress["beat"]) + 1, _sequence().size() - 1)
	else:
		var r: Dictionary = GameState.personal_conversation_action(person_id, _scene_id, "advance")
		if not bool(r.get("ok", false)):
			return
		_progress = r["progress"]
	_render_visit()


func _respond(choice: int) -> void:
	if _replay:
		_progress["choice"] = choice
		_progress["node"] = 1
		_progress["beat"] = 0
	else:
		var r: Dictionary = GameState.personal_conversation_action(person_id, _scene_id, "choose", choice)
		if not bool(r.get("ok", false)):
			return
		_progress = r["progress"]
	_render_visit()


func _summary() -> void:
	clear_log()
	say("narration", String(Stories.SCENES[_scene_id]["summary"]))
	_finish("summary")


func _finish(action: String) -> void:
	var scene: Dictionary = Stories.SCENES[_scene_id]
	var r: Dictionary = GameState.personal_conversation_action(person_id, _scene_id, action)
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Not now.")), Style.MORALE_LOW))
		return
	var claims: int = _social().personal_record(person_id)["bonus_claims"].size()
	var line := "A memory kept: %s" % scene["memory"]
	if int(r.get("trust_change", 0)) > 0:
		line += "\nTime together: +%d trust (%d of %d)." % [int(r["trust_change"]), claims, Relationships.PERSONAL_CONVERSATION_CAP]
	add_to_log(_keepsake(line))
	_after_change()
	set_replies([_back_or_leave()])


func _keepsake(text: String, icon: String = "cup") -> Control:
	var p := PanelContainer.new()
	p.name = "Keepsake"
	p.add_theme_stylebox_override("panel", Style.box(Color("2a1f26"), Color("e88aa0"), 2, 14))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(Widgets.icon_rect(icon, 36))
	var l := Style.label(text, Style.SMALL, Style.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	p.add_child(h)
	if not Style.motion_reduced():
		p.modulate.a = 0.0
		p.create_tween().tween_property(p, "modulate:a", 1.0, 0.3)
	return p


# ---------------------------------------------------------------- remembering

func _remember() -> void:
	clear_log()
	say("you", "Remember when…")
	say("them", "Which time?", _name)
	var replies := []
	var book: Array = _social().memory_book(person_id)
	book.reverse()
	for m in book.slice(0, 6):
		var when := ("Day %d" % int(m["day"])) if int(m.get("day", 0)) > 0 else ""
		replies.append({"id": "memory_" + String(m["id"]), "text": String(m["text"]), "bare": true, "tag": when, "act": _recall.bind(m)})
	replies.append({"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _recall(m: Dictionary) -> void:
	clear_log()
	say("narration", String(m["text"]))
	say("them", Lines.callback(m), _name)
	var replies := []
	var sid := String(m.get("scene_id", ""))
	if String(m.get("kind", "")) == "visit" and _social().personal_record(person_id)["completed"].has(sid):
		replies.append({"id": "relive", "text": "Tell it again", "bare": true, "tag": "a memory · changes nothing", "act": _visit.bind(sid, true)})
	elif String(m.get("kind", "")) == "ceremony" and sid == "wedding":
		var mid := String(m["id"])
		replies.append({"id": "relive", "text": "Tell it again", "bare": true, "tag": "your wedding · changes nothing", "act": func():
			Scenes.wedding_replay = mid
			Scenes.wedding_return = Scenes.personal_conversation_return if opened_as == "visits" else Scenes.conversation_return
			Scenes.go("res://scenes/wedding.tscn")})
	replies.append({"id": "more", "text": "Remember something else.", "tone": "quiet", "act": _remember})
	replies.append({"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _on_close() -> void:
	Scenes.go(Scenes.personal_conversation_return if opened_as == "visits" else Scenes.conversation_return)
