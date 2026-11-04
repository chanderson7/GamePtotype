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
	set_plate(Gatherings.upper_first(String(g["name"])), [
		TalkView.plate_chip("the music starts" if bool(check["ok"]) else "between dances", Style.PLAYER_LIGHT, "dance"),
		TalkView.plate_chip("%d guests" % GameState.gathering_lords(g).size(), Style.MORALE_HIGH)])
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


## Who to ask.
func _ask() -> void:
	add_to_log(note("Ask someone to dance", Style.BRASS))
	var replies := []
	for p in GameState.dance_partners(g):
		match String(p["kind"]):
			"romance":
				replies.append({"id": "partner_" + String(p["id"]), "text": "Dance with %s." % String(p["name"]), "tag": String(p["tag"]),
					"tone": "gold", "act": _dance.bind("romance", String(p["id"]))})
			"lord":
				replies.append({"id": "partner_lord_" + String(p["id"]), "text": "Dance with %s." % String(p["name"]), "tag": String(p["tag"]),
					"act": _dance.bind("lord", String(p["id"]))})
			"wall":
				replies.append({"id": "wall", "text": "Watch from the wall.", "tag": String(p["tag"]), "tone": "quiet",
					"act": _dance.bind("wall", "")})
	set_replies(replies)


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
			var bits := PackedStringArray(["Time together"])
			if int(r["trust"]) > 0:
				bits.append("+%d trust" % int(r["trust"]))
			bits.append("kept as a memory")
			add_to_log(note(" · ".join(bits) + ".", Color("e58fa8")))
			set_plate(String(person.get("name", "")), [TalkView.plate_chip("dancing", Color("e58fa8"), "dance")])
		"lord":
			var l: Dictionary = GameState.world.lord_by_id(int(id))
			set_face("center", CaptainArt.texture(LordVoice.portrait_record(l)), true, 0.8)
			say("you", "Will you dance?")
			say("narration", String(r["text"]))
			add_to_log(note("+%d Regard with %s." % [int(r["regard"]), LordTalk.short_name(l)]))
			set_plate(LordTalk.short_name(l), [TalkView.plate_chip("dancing", Style.PLAYER_LIGHT, "dance")])
		"wall":
			say("narration", String(r["text"]))
			var gossip: Dictionary = r.get("gossip", {})
			if bool(gossip.get("ok", false)):
				add_to_log(note("Gossip: %s" % String(gossip["text"]), Style.BRASS))
	set_replies([{"id": "done", "text": "Back to the hall.", "tone": "quiet", "act": close}])


func _portrait(cand: String) -> Texture2D:
	var tex: Texture2D = StoryArt.texture("res://assets/portraits/%s_warm.png" % cand)
	return tex if tex != null else StoryArt.texture("res://assets/portraits/%s_neutral.png" % cand)


func _on_close() -> void:
	GameState.save_game()
	Scenes.go(Scenes.dance_return)
