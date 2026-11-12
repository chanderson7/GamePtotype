## Two captains at the fire, face to face: what the company remembers of their battles
## together, then what they say to each other. Their talks go in order, rank C, then B,
## then A, none skipped: a pair that reached A in one go hears B first, then A. Once all
## are heard, the latest is told again. When one of them has fallen, the survivor sits by
## the empty place, and the fallen's face is shown greyed. Narrative only: it changes no
## battle values or campaign resources.
extends "res://scripts/ui/talk_view.gd"

const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Feeling = preload("res://scripts/data/feeling.gd")

## How long the one listening takes to show how a line lands (seconds into it).
const TAKES_IT := 0.45

var _rank := ""
var _a: Dictionary = {}
var _b: Dictionary = {}
## The survivor's talk by a fallen friend's place.
var _memorial := false
## The one listening, about to react.
var _reacting = null


func _ready() -> void:
	Sound.set_loop("camp")
	var conversation := GameState.bond_conversation(Scenes.active_bond_a_id, Scenes.active_bond_b_id)
	setup(TalkView.room("company_camp", "night"), "Your camp · night · by the fire")
	if conversation.is_empty():
		say("narration", "The fire has gone quiet. These captains can no longer share this conversation.")
		set_replies([{"id": "back", "text": _back_text(), "tone": "quiet", "act": close}])
		return
	_a = conversation["a"]
	_b = conversation["b"]
	_memorial = bool(conversation.get("memorial", false))
	stage.name = "BondConversationPortraits"
	set_face("left", CaptainArt.texture(_a, "grief" if _memorial else "warm"), true, 0.62)
	set_face("right", CaptainArt.texture(_b, "" if _memorial else "warm"), true, 0.62, _memorial)
	# They blink, whatever face they wear (the one remembered doesn't).
	_blinks("left", _a, "grief" if _memorial else "warm")
	if not _memorial:
		_blinks("right", _b, "warm")
	if _memorial:
		_show_memorial(conversation)
		return
	var next := GameState.next_bond_talk(int(_a["id"]), int(_b["id"]))
	_show(next if next != "" else String(conversation["rank"]))


## By the empty place: what the company remembers, then the survivor's own words.
func _show_memorial(conversation: Dictionary) -> void:
	_rank = String(conversation["rank"])
	var lost := String(_b.get("first", _b.get("name", "")))
	var badge: Array = [Widgets.rank_badge(_rank, 48.0)]
	set_plate(String(_a["first"]) + " & " + lost + " · remembered", badge)
	clear_log()
	var passages: Array = conversation["passages"]
	var lines := []
	for i in passages.size() - 1:
		lines.append({"who": "narration", "text": String(passages[i])})
	# What they say to the empty place: grief, under whatever else it holds.
	var temper := String(_a.get("temperament", ""))
	for line in conversation.get("exchange", []):
		var text := String(line["text"])
		var feel := Feeling.read(text, temper, "grief")
		var mood := String(feel["mood"])
		if mood in ["warm", "amused", "laugh", "tease", "proud", "shy"]:
			mood = "sad"                         # a fond word here is a sad one
		lines.append({"who": "them", "text": text, "speaker": String(_a["first"]),
			"then": _mourns.bind(mood, String(Feeling.gesture_for(mood)))})
	say_in_turn(lines)
	set_replies([{"id": "back", "text": _back_text(), "tone": "primary", "act": close}])


const TalkView = preload("res://scripts/ui/talk_view.gd")


func _exit_tree() -> void:
	Sound.set_loop("")


func _back_text() -> String:
	return "Back to Warband" if Scenes.bond_conversation_return.ends_with("main_menu.tscn") else "Continue"


## The talk at `rank`, then the way on: their next talk if one waits, or back.
func _show(rank: String) -> void:
	var conversation := GameState.bond_conversation(int(_a["id"]), int(_b["id"]), rank)
	if conversation.is_empty():
		return
	_rank = String(conversation["rank"])
	set_plate("%s & %s" % [_a["first"], _b["first"]], _rank_marks(_rank))
	clear_log()
	var passages: Array = conversation["passages"]
	# What the company remembers, then their own words: the first captain on the left, the
	# second on the right in a neutral bubble (your blue is for you). Told a line at a
	# time, the one speaking lit and the one listening quiet; a tap brings it all.
	# Each line is said with the feeling in its words (and its speaker's temper), and the
	# other takes it in a moment later: a joke is smiled at, a fear met with comfort, the
	# names of the absent heard with lowered eyes by both.
	var lines := []
	for i in passages.size() - 1:
		lines.append({"who": "narration", "text": String(passages[i]), "then": _hear.bind(Feeling.scene(String(passages[i])))})
	for line in conversation.get("exchange", []):
		var who: Dictionary = _a if String(line["who"]) == "a" else _b
		var hearer: Dictionary = _b if who == _a else _a
		var text := String(line["text"])
		var feel := Feeling.read(text, String(who.get("temperament", "")))
		var react := Feeling.reaction(String(feel["mood"]), text, String(hearer.get("temperament", "")))
		lines.append({"who": "them" if who == _a else "other", "text": text, "speaker": String(who["first"]),
			"then": _speaks.bind(String(feel["mood"]), String(feel["gesture"]), react)})
	_listen()
	say_in_turn(lines, _listen)
	GameState.acknowledge_bond_conversation(int(_a["id"]), int(_b["id"]), _rank)
	var next := GameState.next_bond_talk(int(_a["id"]), int(_b["id"]))
	if next != "":
		set_replies([{"id": "next", "text": "Their next talk · Rank %s" % next, "tone": "primary", "act": _show.bind(next)}])
	else:
		set_replies([{"id": "back", "text": _back_text(), "tone": "primary", "act": close}])


## One of them speaks, lit, with the feeling of what they say on their face (`mood`) and
## in their body (`move`: TalkView.gesture); the other listens, and a moment in shows how
## it lands (`react`).
func _speaks(side: String, mood: String = "", move: String = "", react: String = "") -> void:
	spotlight(side)
	var other := "right" if side == "left" else "left"
	_wear(side, _a if side == "left" else _b, mood)
	gesture(side, move)
	_stop_reacting()
	if Style.motion_reduced() or not is_inside_tree():
		_takes_it(other, react)
		return
	var t := create_tween()
	_reacting = t
	t.tween_interval(TAKES_IT)
	t.tween_callback(_takes_it.bind(other, react))


## The one listening shows how a line lands: their face, and a laugh or a lean with it.
func _takes_it(side: String, mood: String) -> void:
	_wear(side, _a if side == "left" else _b, mood)
	var move := Feeling.gesture_for(mood)
	gesture(side, move if move in ["bounce", "back"] else "")


## Something told (not said): both hear it, and wear what it holds (Feeling.scene).
func _hear(_side: String, mood: String) -> void:
	_stop_reacting()
	spotlight("")
	_wear("left", _a, mood if mood != "" else "warm")
	_wear("right", _b, mood if mood != "" else "warm")


## By the empty place, the survivor says each line as it is felt.
func _mourns(_side: String, mood: String, move: String) -> void:
	_wear("left", _a, mood)
	gesture("left", move)


func _stop_reacting() -> void:
	if _reacting is Tween and (_reacting as Tween).is_valid():
		(_reacting as Tween).kill()
	_reacting = null


## Between lines and once all is said: both lit, glad of each other.
func _listen() -> void:
	_stop_reacting()
	spotlight("")
	_wear("left", _a, "warm")
	_wear("right", _b, "warm")
	gesture("left", "")
	gesture("right", "")


## A captain wears `mood`, and blinks and talks in it.
func _wear(side: String, captain: Dictionary, mood: String) -> void:
	change_face(side, CaptainArt.texture(captain, mood))
	_blinks(side, captain, mood)


func _blinks(side: String, captain: Dictionary, mood: String) -> void:
	set_blink(side, CaptainArt.texture(captain, mood), CaptainArt.texture(captain, mood + "/shut"),
		CaptainArt.texture(captain, mood + "/half"), CaptainArt.texture(captain, mood + "/talk"))


## A bond's rank as its badge, with what it does in battle as chips: morale back each
## second nearby, and the damage it adds from rank B.
static func _rank_marks(rank: String) -> Array:
	var i := maxi(0, Captains.RANKS.find(rank))
	var out: Array = [Widgets.rank_badge(rank, 48.0)]
	out.append(TalkView.stage_chip("+%.1f/s" % Captains.RANK_REGEN[i], Style.TEXT, "morale"))
	var damage := roundi(Captains.RANK_POWER[i] * 100.0)
	if damage > 0:
		out.append(TalkView.stage_chip("+%d%%" % damage, Style.TEXT, "fight"))
	return out


func _on_close() -> void:
	Scenes.go(Scenes.bond_conversation_return)
