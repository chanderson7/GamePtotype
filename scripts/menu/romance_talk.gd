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
## Her account of chapter 3's deed, told once at the first visit after it was done.
var _untold := ""
## Which page of memories "Remember when…" shows (newest first).
var _memory_page := 0
## How many memories show on a page of "Remember when…".
const MEMORY_PAGE := 6
## Things that stay true for a while (a war, a siege, a burned hall): they open one visit,
## then the greeting for how things stand comes back, until they end and begin again.
const LASTING_FACTS := ["besieged", "burned", "war"]
## Those things as they stand now, whether or not they were told (see _note_visit).
var _lasting_now := {}


## What has happened since you last came, for Lines.opening. Nothing counts before a
## first visit: a stranger has no "since".
func _facts() -> Dictionary:
	var rel: Dictionary = _rel()
	var w = GameState.world
	var res := String(_social().get_candidate_person(cand).get("residence", ""))
	_lasting_now = {"besieged": not w.siege_info(res).is_empty(), "burned": w.burned.has(res),
		"war": GameState.is_at_war_with(String(_house().get("realm", w.owner_of(res))))}
	if not rel.has("last_visit_hour"):
		return {}
	var facts := {"night": TalkView.time_word(w.hour) == "night"}
	var told: Array = rel.get("told_facts", [])
	for key in LASTING_FACTS:
		facts[key] = bool(_lasting_now[key]) and not told.has(key)
	var since_hour := float(rel.get("last_visit_hour", 0.0))
	var since_battle := int(rel.get("last_visit_battles", 0))
	for m in GameState.fallen:
		if int(m.get("battle", 0)) > since_battle:
			facts["fallen"] = String(m.get("first", m.get("name", "")))
	# A wound, or the company's hurt, counts when it's new since you last came.
	var seen_wounded: Array = rel.get("seen_wounded", [])
	for s in GameState.army:
		var c: Dictionary = s.get("captain", {}) if s.get("captain") is Dictionary else {}
		if int(c.get("wounded", 0)) > 0 and not seen_wounded.has(str(int(c.get("id", -1)))):
			facts["wounded"] = String(c.get("first", c.get("name", "")))
	facts["company_hurt"] = GameState.is_wounded() and not bool(rel.get("seen_hurt", false))
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
	var facts := _facts()
	var rel: Dictionary = _rel()
	_opening = Lines.opening(cand, _status(), facts, int(rel.get("visits", 0)))
	_note_visit(Lines.opening_key(cand, facts))
	_untold = _social().take_untold(cand)
	# This visit is now the last one, for next time's opening.
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


## What this visit saw, for the next one's "since": the lasting things she has spoken of
## (forgotten once they end), the captains already wounded, the company's hurt, and the
## count of visits (their greetings take turns).
func _note_visit(spoken: String) -> void:
	var rel: Dictionary = _rel()
	var told: Array = (rel.get("told_facts", []) as Array).duplicate()
	for key in LASTING_FACTS:
		if not bool(_lasting_now.get(key, false)):
			told.erase(key)
		elif key == spoken and not told.has(key):
			told.append(key)
	rel["told_facts"] = told
	var hurt: Array = []
	for s in GameState.army:
		var c = s.get("captain")
		if c is Dictionary and int(c.get("wounded", 0)) > 0:
			hurt.append(str(int(c.get("id", -1))))
	rel["seen_wounded"] = hurt
	rel["seen_hurt"] = GameState.is_wounded()
	rel["visits"] = int(rel.get("visits", 0)) + 1


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
		set_plate(_name, [TalkView.stage_chip("Not yet met", Style.MUTED, "", "·")])
		return
	# How things stand as a badge, trust as a meter, a strain as a lock.
	var chips := [TalkView.stage_chip(Relationships.status_label(_status()), Style.ROMANCE, TalkView.status_icon(_status()))]
	chips.append(_trust_bar(trust))
	if bool(_rel().get("strained", false)):
		chips.append(TalkView.stage_chip("Strained", Style.ENEMY_LIGHT, "lock"))
	set_plate(_name, chips)


## Trust as a meter, marked where a public wedding opens.
func _trust_bar(trust: int) -> Control:
	var box := PanelContainer.new()
	box.name = "TrustBar"
	box.tooltip_text = "Trust %d" % trust
	var sb := Style.box(Color(Style.NIGHT, 0.85), Style.RULE, 2, 40)
	sb.content_margin_left = 12
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	box.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var heart := Widgets.icon_rect("heart", 26.0)
	heart.modulate = Style.ROMANCE
	h.add_child(heart)
	h.add_child(Style.label(str(trust), Style.SMALL, Style.TEXT))
	var bar := Widgets.meter(trust / 100.0, Style.ROMANCE, 14.0, [Relationships.TRUST_PUBLIC_WEDDING / 100.0])
	bar.custom_minimum_size.x = 120
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	if first and _untold != "":
		# What came of chapter 3's task, in her words, the first time you're back.
		_tell(_untold)
		_untold = ""
		add_to_log(note("Done, as you promised. The next chapter follows.", Style.MORALE_HIGH))
	else:
		say("them", (_opening if _opening != "" else Lines.greeting(cand, _status(), int(_rel().get("visits", 0)))) if first else "What else is on your mind?", _name)
	if bool(_rel().get("strained", false)):
		add_to_log(note("Things are strained between you since a broken promise. %s will hear you out on it." % _name, Style.MORALE_LOW))
	var replies := []
	# What you never said at the first audience, first of all.
	if _social().intent_open(cand):
		replies.append({"id": "intent", "text": Lines.INTENT_OPENER, "icon": "heart", "tag": "say what you mean to be to %s" % _name,
			"tone": "gold", "act": _intent_again})
	# The story first.
	var ch := _chapter()
	var story: Dictionary = RomanceStories.story_data(cand)
	var cinfo: Dictionary = story.get("chapters", {}).get(ch, {})
	var post: Dictionary = _social().post_state(cand, GameState.world.hour)
	var promised: Dictionary = _social().task(cand)
	if _social().wedding_active(cand):
		var w: Dictionary = GameState.wedding()
		var tag: String = {"planning": "choose where", "postponed": "postponed · choose a new place",
			"preparing": "at %s · %s" % [Letters.place_name(String(w.get("place", ""))), "being made ready"],
			"ready": "ready at %s · ride there" % Letters.place_name(String(w.get("place", "")))}.get(String(w["state"]), "")
		replies.append({"id": "wedding", "text": "About our wedding…", "icon": "rings", "tag": tag, "tone": "gold", "act": _wedding_talk})
	elif ch == 3 and not promised.is_empty():
		replies.append(_task_reply(promised))
	elif bool(post.get("available", false)):
		# After the vows: one more matter, told as a sixth chapter.
		var project: Dictionary = RomanceStories.post_project(cand)
		if bool(post.get("ok", false)):
			replies.append({"id": "story", "text": Lines.story_opener(cand, CHAPTERS + 1), "icon": "book",
				"tag": "Chapter %d · %s" % [CHAPTERS + 1, String(project.get("title", ""))], "tone": "gold", "act": _post})
		elif not bool(post.get("done", false)):
			replies.append({"id": "story", "text": Lines.story_opener(cand, CHAPTERS + 1),
				"tag": "Chapter %d · %s" % [CHAPTERS + 1, String(post.get("reason", ""))], "tone": "locked"})
	elif not cinfo.is_empty() and _status() != Relationships.ENDED and not (ch >= CHAPTERS and _status() in [Relationships.MARRIED, Relationships.FRIENDSHIP]):
		var open: Dictionary = _social().chapter_open(cand, GameState.world.hour)
		if bool(open["ok"]):
			replies.append({"id": "story", "text": Lines.story_opener(cand, ch), "icon": "book", "tag": "Chapter %d · %s" % [ch, cinfo.get("title", "")],
				"tone": "gold", "act": _story})
		else:
			replies.append({"id": "story", "text": Lines.story_opener(cand, ch), "tag": "Chapter %d · %s" % [ch, String(open["reason"])], "tone": "locked"})
	# Their letter, when one waits for an answer.
	var letter_waits := false
	for l in _social().letters:
		if String(l.get("sender_id", "")) == person_id and not bool(l.get("read", false)):
			var lid := String(l.get("id", ""))
			letter_waits = true
			replies.append({"id": "letter", "text": Lines.LETTER_OPENER, "icon": "mail", "tag": "a letter waits", "act": func():
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
			replies.append({"id": "visit_" + id, "text": Lines.VISIT_RESUME, "icon": "resume", "tag": "resume · " + title, "act": _visit.bind(id, false)})
		else:
			replies.append({"id": "visit_" + id, "text": Lines.VISIT_OPENERS[mini(fresh, Lines.VISIT_OPENERS.size() - 1)],
				"icon": "cup", "tag": "time together · " + title, "act": _visit.bind(id, false)})
			fresh += 1
	var together: bool = _status() in [Relationships.MARRIED, Relationships.FRIENDSHIP]
	if open.is_empty() and not locked.is_empty() and not (together and fresh == 0):
		# When today's visit is spent, say that rather than the next visit's prerequisite.
		var today := locked.filter(func(v): return bool(v.get("today", false)))
		var why: Dictionary = today[0] if not today.is_empty() else locked[0]
		replies.append({"id": "visits_locked", "text": Lines.VISIT_OPENERS[0], "tag": String(why.get("reason", "not yet")), "tone": "locked"})
	# Married or sworn: an evening together is always there to be had.
	if together:
		replies.append({"id": "together", "text": Lines.TOGETHER_OPENER, "icon": "cup", "tag": "an evening together", "act": _together})
	# Her house's good word, which a wedding or a pact needs: a muster at its seat.
	var favour: Dictionary = _social().favour_check(cand, GameState.world.hour)
	if bool(favour.get("ok", false)) or String(favour.get("reason", "")).begins_with("again in"):
		var seat := Letters.place_name(String(_house().get("seat", "")))
		if bool(favour.get("ok", false)) and GameState.silver >= int(favour["silver"]):
			replies.append({"id": "favour", "text": Lines.FAVOUR_OPENER, "icon": "keep", "fx": [["silver", -int(favour["silver"])]],
				"tag": "pay for a muster at %s · her house's good word" % seat, "act": _favour})
		else:
			replies.append({"id": "favour", "text": Lines.FAVOUR_OPENER, "fx": [["silver", -int(favour["silver"])]],
				"tag": String(favour.get("reason", "")) if not bool(favour.get("ok", false)) else "need %d silver" % int(favour["silver"]), "tone": "locked"})
	if not _social().memory_book(person_id).is_empty():
		replies.append({"id": "remember", "text": "Remember when…", "icon": "journal", "tag": "your memories together", "act": _remember.bind(0)})
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


## What you mean to be to each other. Asked again later (`late`), it can't be put off by
## saying nothing: "Not now." simply leaves it for another day.
func _intents(cinfo: Dictionary, late: bool = false) -> void:
	add_to_log(note(String(cinfo.get("intent_prompt", "What do you mean to be to each other?")), Style.BRASS))
	var replies := []
	for it in cinfo.get("intent_choices", []):
		if late and String(it.get("intent", "")) == "none":
			continue
		replies.append(_decision(it))
	replies.append({"id": "back", "text": "Not now.", "tone": "quiet", "act": _hub})
	set_replies(replies)


## The first audience's question, never answered: you bring it up again.
func _intent_again() -> void:
	clear_log()
	say("you", Lines.INTENT_OPENER)
	_face("thoughtful")
	say("them", String(Lines.INTENT_AGAIN.get(cand, "You never said, that first day.")), _name)
	_intents(RomanceStories.story_data(cand).get("chapters", {}).get(1, {}), true)


# ---------------------------------------------------------------- chapter 3's task

## The journal job for chapter 3's promise, if it's still in the journal, or {}.
func _task_job(t: Dictionary) -> Dictionary:
	var id := String(t.get("job_id", ""))
	if id == "":
		return {}
	for j in GameState.active_jobs:
		if String(j.get("id", "")) == id:
			return j
	return {}


## The hub's line for a promise not yet kept: in the journal, or (if the job lapsed) taken up again.
func _task_reply(t: Dictionary) -> Dictionary:
	var choice := String(t.get("choice", ""))
	var title := String(RomanceStories.choice_data(cand, choice).get("name", "Your promise"))
	if not _task_job(t).is_empty():
		return {"id": "story", "text": Lines.story_opener(cand, 3), "icon": "objective", "tag": "Chapter 3 · %s · in your journal" % title,
			"act": _task_waiting.bind(choice)}
	return {"id": "story", "text": "I gave you my word. I'll see it done.", "icon": "objective",
		"tag": "Chapter 3 · %s · a job in your journal" % title, "tone": "gold", "act": _take_task.bind(true)}


func _task_waiting(choice: String) -> void:
	clear_log()
	say("you", Lines.story_opener(cand, 3))
	_face("concerned")
	say("them", String(Lines.TASK_WAITING.get(cand, {}).get(choice, "It isn't done yet, captain.")), _name)
	add_to_log(note("Your promise waits in the journal. The chapter ends when it's done.", Style.MUTED))
	set_replies([_back_or_leave()])


## Put chapter 3's task in the journal as a job, bound to her seat and villages.
func _take_task(spoken: bool = false) -> void:
	var closed: Array = []
	for realm in Data.FACTIONS:
		if GameState.is_at_war_with(String(realm)):
			closed.append(String(realm))
	var job: Dictionary = _social().story_job(cand, GameState.world, closed)
	if spoken:
		clear_log()
		say("you", "I gave you my word. I'll see it done.")
	if job.is_empty():
		add_to_log(note("There's nothing to be done about it just now. Ask again later.", Style.MORALE_LOW))
	else:
		GameState.active_jobs.append(job)
		GameState.save_game()
		add_to_log(note("In your journal: %s." % String(job.get("title", "a promise")), Style.MORALE_HIGH))
	set_replies([_back_or_leave()])


# ---------------------------------------------------------------- after the vows

func _post() -> void:
	var project: Dictionary = RomanceStories.post_project(cand)
	if not bool(_social().post_state(cand, GameState.world.hour).get("ok", false)):
		_hub()
		return
	clear_log()
	say("you", Lines.story_opener(cand, CHAPTERS + 1))
	_face(String(project.get("face", "")))
	_tell(String(project.get("text", "")))
	var replies := []
	for c in project.get("choices", []):
		replies.append({"id": "post_" + String(c["id"]), "text": String(c["text"]), "tag": String(c.get("tag", "")), "tone": "gold",
			"act": _post_decide.bind(c)})
	replies.append({"id": "back", "text": "Not now.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _post_decide(c: Dictionary) -> void:
	var r: Dictionary = _social().apply_post(cand, String(c["id"]), GameState.world.hour)
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Not now.")), Style.MORALE_LOW))
		return
	GameState.save_game()
	say("you", String(c["text"]))
	_face(String(c.get("face", "")))
	_tell(String(c.get("response", "")))
	var reaction := _reaction({"standing_change": int(r.get("standing_change", 0))})
	if reaction != null:
		add_to_log(reaction)
	add_to_log(keepsake("A memory kept: %s" % String(c.get("memory", "")), "book"))
	_after_change()
	set_replies([_back_or_leave()])


## An evening together, married or sworn: nothing to decide, nothing kept count of.
func _together() -> void:
	clear_log()
	say("you", Lines.TOGETHER_OPENER)
	var rel: Dictionary = _rel()
	var n := int(rel.get("evenings", 0))
	rel["evenings"] = n + 1
	say("narration", Lines.together(cand, _status(), n))
	_face("warm")
	set_replies([_back_or_leave()])


## Pay for a muster at her house's seat: its standing rises (a wedding or a pact needs it).
func _favour() -> void:
	var check: Dictionary = _social().favour_check(cand, GameState.world.hour)
	var cost := int(check.get("silver", Relationships.FAVOUR_SILVER))
	if not bool(check.get("ok", false)) or GameState.silver < cost:
		add_to_log(note(String(check.get("reason", "")) if not bool(check.get("ok", false)) else "You need %d silver." % cost, Style.MORALE_LOW))
		return
	var r: Dictionary = _social().house_favour(cand, GameState.world.hour)
	if not bool(r.get("ok", false)):
		add_to_log(note(String(r.get("reason", "Not now.")), Style.MORALE_LOW))
		return
	GameState.sponsor_replacements(String(r["house_id"]), String(r["seat"]), "settlement", cost)
	clear_log()
	say("you", Lines.FAVOUR_OPENER)
	_face("warm")
	say("them", String(Lines.FAVOUR_THANKS.get(cand, "Thank you.")), _name)
	add_to_log(TalkView.fx_note([["silver", -cost]], "A muster at %s, paid for" % Letters.place_name(String(r["seat"])), Style.MUTED))
	var reaction := _reaction({"standing_change": int(r.get("standing_change", 0))})
	if reaction != null:
		add_to_log(reaction)
	_after_change()
	set_replies([_back_or_leave()])


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
	if String(c.get("promise", "")) != "":
		bits.append("a job in your journal")
	var now := _new_status(prev)
	if now != "":
		bits.append(now)
	var grave := bool(c.get("strained", false)) or choice_id == "part_respectfully"
	return {"id": "decide_" + choice_id, "text": text, "tag": " · ".join(bits), "fx": _costs(prev),
		"tone": String(c.get("tone", "red" if grave else "gold")), "act": _decide.bind(c, prev)}


## What a choice costs, as chips on its button (and only there): silver and rations.
func _costs(prev: Dictionary) -> Array:
	var fx := []
	if int(prev.get("cost_silver", 0)) > 0:
		fx.append(["silver", -int(prev["cost_silver"])])
	if int(prev.get("cost_food", 0)) > 0:
		fx.append(["food", -int(prev["cost_food"])])
	return fx


## How things will stand after a choice, in words ("now courting"), or "".
func _new_status(prev: Dictionary) -> String:
	var ns := String(prev.get("new_status", ""))
	if ns != "" and ns != _status():
		return "now %s" % Relationships.status_label(ns).to_lower()
	return ""


## What a choice does to trust and to their house, with its numbers: for the step that
## asks you to be sure. The costs were on the button you pressed and aren't said again.
func _effects(prev: Dictionary) -> Array:
	var fx := []
	var t := int(prev.get("trust_change", 0))
	if t != 0:
		fx.append(["heart", t])
	var st := int(prev.get("standing_change", 0))
	if st != 0:
		fx.append(["keep", st])
	return fx


func _decide(c: Dictionary, prev: Dictionary, confirmed: bool = false) -> void:
	var choice_id := String(c["id"])
	var text := String(c["text"])
	if bool(prev.get("requires_confirmation", false)) and not confirmed:
		say("you", text)
		add_to_log(note(String(prev.get("confirmation_text", "Are you sure?")), Style.BRASS))
		var fx := _effects(prev)
		set_replies([
			{"id": "confirm", "text": "Yes. I mean it.", "fx": fx, "tag": "it stays between you" if fx.is_empty() else "",
				"tone": "red" if bool(c.get("strained", false)) or choice_id == "part_respectfully" else "gold",
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
	if bool(res.get("task", false)):
		# Promised, not yet done: her word on it, and the job in your journal.
		_tell(String(c.get("promise", "")))
		_ch1_topic_done = false
		_after_change()
		_take_task()
		return
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


## What changed, told once, as how they and their house take it, not as a sum. The cost
## was on the button and the numbers on the step that asked you to be sure.
func _reaction(prev: Dictionary) -> Control:
	var chips := []
	var t := int(prev.get("trust_change", 0))
	if t > 0:
		chips.append(Widgets.chip("%s trusts you more" % _name, Style.ROMANCE, "", "heart"))
	elif t < 0:
		chips.append(Widgets.chip("%s is hurt" % _name, Style.ENEMY_LIGHT, "", "heart"))
	var st := int(prev.get("standing_change", 0))
	if st > 0:
		chips.append(Widgets.chip("%s's house takes note" % _name, Style.BRASS, "", "keep"))
	elif st < 0:
		chips.append(Widgets.chip("%s's house is displeased" % _name, Style.ENEMY_LIGHT, "", "keep"))
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

## Where you'll marry: her seat, yours, or another friendly town near you. Each place shows
## its ride as a clock; what's set aside for it shows once, as chips.
func _where(cost_note: bool = true) -> void:
	var w: Dictionary = GameState.wedding()
	add_to_log(note("Where will you marry?", Style.BRASS))
	if cost_note:
		add_to_log(TalkView.fx_note([["silver", Widgets.thousands(int(w.get("reserved_silver", 0)))], ["food", Widgets.thousands(int(w.get("reserved_food", 0)))]],
			"set aside; it comes back if it's called off", Style.MUTED))
	var replies := []
	var others := []
	var ready := "ready %s" % GameState._when_text(_social().wedding_ready_hour(GameState.world.hour))
	for p in GameState.wedding_places(cand):
		match String(p["kind"]):
			"hers":
				replies.append(_place_reply(p, "Here in %s, with your house." % p["name"] if p["hours"] < 1.0 else "At %s, with your house." % p["name"],
					"her house's seat · " + ready, "keep"))
			"yours":
				replies.append(_place_reply(p, "At %s, under my own banner." % p["name"], "your seat · you host", "crown"))
			_:
				others.append(p)
	if not others.is_empty():
		replies.append({"id": "elsewhere", "text": "Somewhere else we both know.", "icon": "mappin", "tag": "a friendly town or castle near you",
			"act": _elsewhere.bind(others)})
	replies.append({"id": "later", "text": "Let's decide later.", "tone": "quiet", "tag": "stay engaged · no hurry", "act": _hub})
	set_replies(replies)


func _elsewhere(others: Array) -> void:
	say("you", "Somewhere else we both know.")
	var replies := []
	var ready := "ready %s" % GameState._when_text(_social().wedding_ready_hour(GameState.world.hour))
	for p in others:
		replies.append(_place_reply(p, "At %s." % p["name"], ready, "mappin"))
	replies.append({"id": "back", "text": "Back", "tone": "quiet", "act": _where})
	set_replies(replies)


func _place_reply(p: Dictionary, text: String, tag: String, icon_key: String) -> Dictionary:
	if not bool(p["ok"]):
		return {"id": "place_" + String(p["id"]), "text": text, "tag": String(p["reason"]).capitalize(), "tone": "locked"}
	var hours := float(p["hours"])
	var ride := [["clock", "here" if hours < 1.0 else Style.time_short(hours)]]
	return {"id": "place_" + String(p["id"]), "text": text, "icon": icon_key, "fx": ride, "tag": tag, "tone": "gold",
		"act": _choose_place.bind(String(p["id"]), text)}


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
	add_to_log(TalkView.fx_note([["silver", int(r.get("silver", 0))], ["food", int(r.get("food", 0))]], "Called off: what was set aside is back", Style.MUTED))
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
			add_to_log(keepsake("A memory kept: vows in %s's room at %s, by one candle." % [_name, Letters.place_name(String(_social().get_candidate_person(cand).get("residence", "")))], "rings"))
			add_to_log(TalkView.fx_note([["keep", Relationships.STANDING_PRIVATE_VOWS_PENALTY]],
				"%s wasn't asked: no marriage pact yet. Their good word can still be earned." % String(house.get("name", "Her house")), Style.MORALE_LOW))
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
	var fx := []
	if int(r.get("trust_change", 0)) > 0:
		fx = [["heart", int(r["trust_change"])], ["cup", "%d of %d" % [claims, Relationships.PERSONAL_CONVERSATION_CAP]]]
	add_to_log(keepsake("A memory kept: %s" % scene["memory"], "cup", fx))
	_after_change()
	set_replies([_back_or_leave()])


# ---------------------------------------------------------------- remembering

## Your memories together, newest first, a page at a time; further back and more recent
## turn the pages.
func _remember(page: int = -1) -> void:
	if page >= 0:
		_memory_page = page
	clear_log()
	say("you", "Remember when…")
	say("them", "Which time?" if _memory_page == 0 else "Further back, then.", _name)
	var replies := []
	var book: Array = _social().memory_book(person_id)
	book.reverse()
	var pages := maxi(1, ceili(book.size() / float(MEMORY_PAGE)))
	_memory_page = clampi(_memory_page, 0, pages - 1)
	var from := _memory_page * MEMORY_PAGE
	for m in book.slice(from, from + MEMORY_PAGE):
		var when := [["day", str(int(m["day"]))]] if int(m.get("day", 0)) > 0 else []
		replies.append({"id": "memory_" + String(m["id"]), "text": String(m["text"]), "bare": true, "fx": when, "act": _recall.bind(m)})
	var turn := []
	if _memory_page > 0:
		turn.append({"id": "newer", "text": "More recent…", "tone": "quiet", "act": _remember.bind(_memory_page - 1)})
	if _memory_page < pages - 1:
		turn.append({"id": "older", "text": "Further back…", "tone": "quiet", "tag": "page %d of %d" % [_memory_page + 1, pages], "act": _remember.bind(_memory_page + 1)})
	if not turn.is_empty():
		replies.append({"row": turn})
	replies.append({"id": "back", "text": "Something else.", "tone": "quiet", "act": _hub})
	set_replies(replies)


func _recall(m: Dictionary) -> void:
	clear_log()
	say("narration", String(m["text"]))
	say("them", Lines.callback(m, cand), _name)
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
