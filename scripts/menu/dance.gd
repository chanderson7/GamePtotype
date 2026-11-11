## A dance night at a gathering: the hall with the music starting, and one partner for
## the night. Someone you court counts as time together and is kept as a memory; a lord
## thinks better of you; or you keep to the wall and listen. Built on talk_view.gd; the
## rules are in GameState.
extends "res://scripts/ui/talk_view.gd"

const TalkView = preload("res://scripts/ui/talk_view.gd")
const Data = preload("res://scripts/world/world_data.gd")
const Gatherings = preload("res://scripts/data/gatherings.gd")
const HallScene = preload("res://scripts/ui/hall_scene.gd")
const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const LordVoice = preload("res://scripts/data/lord_voice.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")
const Heraldry = preload("res://scripts/ui/heraldry.gd")
const RomanceStories = preload("res://scripts/data/romance_stories.gd")
const Relationships = preload("res://scripts/data/relationships.gd")

var g: Dictionary = {}
var place := ""


func _ready() -> void:
	var w = GameState.world
	if w == null:
		_nothing("There's no music tonight.")
		return
	g = GameState.gathering_here()
	if g.is_empty():
		_nothing("There's no gathering here tonight.")
		return
	place = String(g["place"])
	var when := TalkView.time_word(w.hour)
	var owner: String = w.owner_of(place)
	var flag := owner if Heraldry.REALM_SIZES.has(owner) else Heraldry.realm_of_culture(Data.culture_of(owner))
	var hall := HallScene.rect(Data.culture_of(Data.settlement(place)["faction"]), flag, "night" if when == "night" else "dusk", place.hash())
	setup(hall, "%s at %s · %s" % [Gatherings.upper_first(String(g["name"])), Data.settlement(place)["name"], when])
	Sound.play_music("camp_" + String(g.get("culture", Data.culture_of(owner))))
	var check: Dictionary = GameState.dance_check(g)
	var guests := TalkView.stage_chip(str(GameState.gathering_lords(g).size()), Style.TEXT, "men")
	guests.tooltip_text = "guests"
	set_plate(Gatherings.upper_first(String(g["name"])), [
		TalkView.stage_chip("the music starts" if bool(check["ok"]) else "between dances", Style.PLAYER_LIGHT, "dance"), guests])
	say("narration", String(Gatherings.DANCE_OPEN.get(String(g.get("culture", "")), Gatherings.DANCE_OPEN["vardish"])))
	if not bool(check["ok"]):
		add_to_log(note("You've danced tonight." if String(check["reason"]) == "you've danced tonight" else String(check["reason"]).capitalize() + ".", Style.MUTED))
		set_replies([{"id": "done", "text": "Back to the hall.", "tone": "quiet", "act": close}])
		return
	_ask()


func _nothing(text: String) -> void:
	setup(null, "")
	say("narration", text)
	set_replies([{"id": "done", "text": "Back", "tone": "quiet", "act": close}])


## Who to ask: someone you know (or have only seen) who is in the hall, a lord's
## kinswoman for his Regard, the round everyone joins, the wall. Never a lord himself.
func _ask() -> void:
	var replies := []
	var absent := []
	for p in GameState.dance_partners(g):
		match String(p["kind"]):
			"romance":
				replies.append({"id": "partner_" + String(p["id"]), "text": "Dance with %s." % String(p["name"]), "icon": "heart", "tag": String(p["tag"]),
					"tone": "gold", "act": _dance.bind("romance", String(p["id"]))})
			"meet":
				replies.append({"id": "meet_" + String(p["id"]), "text": String(p["seen"]), "icon": "heart", "tag": String(p["tag"]),
					"tone": "gold", "act": _dance.bind("meet", String(p["id"]))})
			"kin":
				# "+3 Regard with Lord X · Daring: ..." becomes a Regard chip and the words after it.
				var tag := String(p["tag"])
				var fx := []
				var words := tag.split(" · ", false)
				if not words.is_empty() and String(words[0]).begins_with("+"):
					fx.append(["bond", String(words[0]).to_int()])
					words.remove_at(0)
				words.insert(0, "%s's %s" % [String(p["lord_name"]), String(p["relation"])])
				replies.append({"id": "partner_kin_" + String(p["id"]), "text": "Dance with %s." % String(p["name"]), "icon": "dance", "fx": fx,
					"tag": " · ".join(words), "act": _dance.bind("kin", String(p["id"]))})
			"round":
				replies.append({"id": "round", "text": "Join the round.", "icon": "company", "tag": String(p["tag"]),
					"act": _dance.bind("round", "")})
			"wall":
				replies.append({"id": "wall", "text": "Watch from the wall.", "icon": "eye", "tag": String(p["tag"]),
					"act": _dance.bind("wall", "")})
			"absent":
				absent.append(String(p["tag"]))
	for line in absent:
		add_to_log(note(line, Style.MUTED))
	set_replies(replies, "Ask someone to dance")


func _dance(kind: String, id: String) -> void:
	var r: Dictionary = GameState.dance(g, kind, id)
	if not bool(r.get("ok", false)):
		_ask()
		return
	Sound.play("page", 0.0, 0.05)
	match kind:
		"romance":
			var person: Dictionary = GameState.world.social.get_candidate_person(id)
			set_face("center", _portrait(id), false, 0.9)
			say("you", "Dance with me.")
			say("narration", String(r["text"]))
			# What it gives was on the button; the result is the memory, once.
			add_to_log(keepsake("A dance with %s, kept as a memory." % String(person.get("name", "")), "dance"))
			set_plate(String(person.get("name", "")), [TalkView.stage_chip("dancing", Style.ROMANCE, "dance")])
		"meet":
			var person: Dictionary = GameState.world.social.get_candidate_person(id)
			var who := String(person.get("name", ""))
			set_face("center", _portrait(id), false, 0.9)
			say("you", "Will you dance?")
			say("narration", String(r["text"]))
			add_to_log(keepsake("You met %s. Kept as a memory." % who, "dance"))
			set_plate(who, [TalkView.stage_chip("met tonight", Style.ROMANCE, "heart")])
			if bool(r.get("intent", false)):
				_meet_intents(id, who)
				return
		"kin":
			var l: Dictionary = GameState.world.lord_by_id(int(id))
			var kin: Dictionary = GameState.world.social.house_kin(l)
			set_face("center", CaptainArt.texture(LordVoice.kin_record(l, kin)), true, 0.8)
			say("you", "Will you dance?")
			say("narration", String(r["text"]))
			add_to_log(TalkView.fx_note([], "%s thinks better of you." % LordTalk.first_name(l)))
			set_plate("%s, %s's %s" % [String(kin.get("name", "")), String(r["lord_name"]), String(kin.get("relation", ""))],
				[TalkView.stage_chip("dancing", Style.PLAYER_LIGHT, "dance")])
		"round":
			say("narration", String(r["text"]))
			add_to_log(TalkView.fx_note([], "Every lord in the hall thinks a little better of you (%d)." % int(r["lords"])))
			set_plate("The round", [TalkView.stage_chip("dancing", Style.PLAYER_LIGHT, "dance")])
		"wall":
			say("narration", String(r["text"]))
			var gossip: Dictionary = r.get("gossip", {})
			if bool(gossip.get("ok", false)):
				add_to_log(note("Gossip: %s" % String(gossip["text"]), Style.BRASS))
	set_replies([{"id": "done", "text": "Back to the hall.", "tone": "quiet", "act": close}])


## As the music ends she asks what brought you: the story's own first question, with its
## own answers (court her, as a friend, nothing decided), the same as at her first
## audience. Answered here, the first chapter is done and the next follows by letter; put
## off, the audience at her seat asks it.
func _meet_intents(cid: String, who: String) -> void:
	var cinfo: Dictionary = RomanceStories.story_data(cid).get("chapters", {}).get(1, {})
	var replies := []
	for it in cinfo.get("intent_choices", []):
		var choice_id := String(it["id"])
		var prev: Dictionary = GameState.preview_social_choice(cid, choice_id)
		if not bool(prev.get("ok", false)):
			replies.append({"id": "decide_" + choice_id, "text": String(it["text"]), "tag": String(prev.get("reason", "not now")), "tone": "locked"})
			continue
		var bits := PackedStringArray()
		if String(it.get("tag", "")) != "":
			bits.append(String(it["tag"]))
		var ns := String(prev.get("new_status", ""))
		if ns != "" and ns != Relationships.ACQUAINTED:
			bits.append("now %s" % Relationships.status_label(ns).to_lower())
		replies.append({"id": "decide_" + choice_id, "text": String(it["text"]), "tag": " · ".join(bits), "tone": String(it.get("tone", "gold")),
			"act": _meet_decide.bind(cid, who, it)})
	replies.append({"id": "done", "text": "Not tonight. Back to the hall.", "tone": "quiet", "tag": "she'll ask at %s" % _seat_name(cid), "act": close})
	set_replies(replies, String(cinfo.get("intent_prompt", "What do you mean to be to each other?")))


func _meet_decide(cid: String, who: String, it: Dictionary) -> void:
	var res: Dictionary = GameState.apply_social_choice(cid, String(it["id"]))
	if not bool(res.get("ok", false)):
		add_to_log(note(String(res.get("reason", "That can't be done now.")), Style.MORALE_LOW))
		return
	say("you", String(it["text"]))
	var face := String(it.get("face", ""))
	if face != "":
		change_face("center", _portrait_face(cid, face))
	# Her answer: her own lines in her bubble, the rest as narration.
	for part in String(it.get("response", "")).split("\n\n", false):
		var line := String(part).strip_edges()
		if line.begins_with(who + ":"):
			say("them", line.trim_prefix(who + ":").strip_edges(), who)
		else:
			say("narration", line)
	var status := String(GameState.world.social.get_relationship(cid).get("status", ""))
	if status == Relationships.COURTING:
		add_to_log(TalkView.fx_note([], "You are courting %s. Her letter will say when to come." % who, Style.ROMANCE))
	elif String(it.get("intent", "")) == "friendship":
		add_to_log(TalkView.fx_note([], "%s counts you a friend. Her letter will say when to come." % who))
	else:
		add_to_log(TalkView.fx_note([], "Nothing decided. She'll ask again, at %s or by letter." % _seat_name(cid), Style.MUTED))
	set_replies([{"id": "done", "text": "Back to the hall.", "tone": "quiet", "act": close}])


func _seat_name(cid: String) -> String:
	var person: Dictionary = GameState.world.social.get_candidate_person(cid)
	var seat := String(person.get("residence", ""))
	return String(Data.settlement(seat)["name"]) if Data.SETTLEMENTS.has(seat) else "her seat"


func _portrait_face(cand: String, expression: String) -> Texture2D:
	var tex: Texture2D = StoryArt.texture("res://assets/portraits/%s_%s.png" % [cand, expression])
	return tex if tex != null else _portrait(cand)


func _portrait(cand: String) -> Texture2D:
	var tex: Texture2D = StoryArt.texture("res://assets/portraits/%s_warm.png" % cand)
	return tex if tex != null else StoryArt.texture("res://assets/portraits/%s_neutral.png" % cand)


func _on_close() -> void:
	GameState.save_game()
	Scenes.go(Scenes.dance_return)
