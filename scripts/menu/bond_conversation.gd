## Two captains at the fire, face to face: what the company remembers of their battles
## together, then what they say to each other, rank by rank. Tabs for each rank reached
## read its talk again. Narrative only: it changes no battle values or campaign resources.
extends "res://scripts/ui/talk_view.gd"

const CaptainArt = preload("res://scripts/ui/captain_art.gd")
const Captains = preload("res://scripts/data/captains.gd")

var _rank := ""
var _a: Dictionary = {}
var _b: Dictionary = {}


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
	stage.name = "BondConversationPortraits"
	set_face("left", CaptainArt.texture(_a, "warm"), true, 0.62)
	set_face("right", CaptainArt.texture(_b, "warm"), true, 0.62)
	_show(String(conversation["rank"]))


const TalkView = preload("res://scripts/ui/talk_view.gd")


func _exit_tree() -> void:
	Sound.set_loop("")


func _back_text() -> String:
	return "Back to Warband" if Scenes.bond_conversation_return.ends_with("main_menu.tscn") else "Continue"


## The talk at `rank`, with tabs for every rank this bond has reached.
func _show(rank: String) -> void:
	var conversation := GameState.bond_conversation(int(_a["id"]), int(_b["id"]), rank)
	if conversation.is_empty():
		return
	_rank = String(conversation["rank"])
	var points := float(conversation["points"])
	set_plate("%s & %s" % [_a["first"], _b["first"]], [
		TalkView.plate_chip("Rank %s" % _rank, Style.BRASS, "heart"),
		TalkView.plate_chip(GameState.bond_effect_text(Captains.RANK_POINTS[Captains.RANKS.find(_rank)] + 0.01), Style.MORALE_HIGH)])
	clear_log()
	var passages: Array = conversation["passages"]
	# What the company remembers, then their own words.
	for i in passages.size() - 1:
		say("narration", String(passages[i]))
	for line in conversation.get("exchange", []):
		var who: Dictionary = _a if String(line["who"]) == "a" else _b
		say("them" if who == _a else "you", String(line["text"]), String(who["first"]))
	add_to_log(note("A quiet conversation. It changes no battle values or campaign resources.", Style.MUTED))
	GameState.acknowledge_bond_conversation(int(_a["id"]), int(_b["id"]))
	var replies := []
	var top := Captains.rank_for(points)
	if top > 1:
		var tabs := HBoxContainer.new()
		tabs.name = "RankTabs"
		tabs.add_theme_constant_override("separation", 8)
		for i in range(1, top + 1):
			var r := String(Captains.RANKS[i])
			var t := Button.new()
			t.name = "Rank_" + r
			t.text = "Rank " + r
			t.disabled = r == _rank
			t.custom_minimum_size = Vector2(120, 56)
			t.pressed.connect(_show.bind(r))
			tabs.add_child(t)
		replies.append({"id": "ranks", "text": "Their talks, rank by rank", "tone": "quiet", "extra": tabs})
	replies.append({"id": "back", "text": _back_text(), "tone": "quiet", "act": close})
	set_replies(replies)


func _on_close() -> void:
	Scenes.go(Scenes.bond_conversation_return)
