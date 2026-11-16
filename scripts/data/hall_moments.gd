## Small things that happen in the hall at a feast: a song made of your deeds, a lord who
## wants to arm-wrestle, an insult across the table, the host asking for news, a quiet word
## in a corner, a round for the hall. At most one a night, never the same one twice at one
## feast. Each has two choices, and each choice uses only what the game already keeps
## (Regard, renown, silver). The numbers are in gatherings.gd; GameState rolls for one
## (hall_moment) and carries the choice out (hall_moment_choose).
extends RefCounted

const Gatherings = preload("res://scripts/data/gatherings.gd")
const Lords = preload("res://scripts/data/lords.gd")
const LordTalk = preload("res://scripts/world/lord_talk.gd")

const IDS := ["bard", "challenge", "insult", "news", "aside", "round"]

const BARD := {
	"vardish": "The harper strikes up something new: the deeds of your company, with more dragons in it than you remember.",
	"kharzani": "A poet rises and recites a qasida on your company's deeds, each verse grander than the last.",
	"ryumon": "A verse is read for your company: a banner in the rain, a river crossed by night. The hall listens.",
}
const ROUND := {
	"vardish": "The ale keeps coming, and the hall looks your way.",
	"kharzani": "The sherbet gives way to wine, and the courtyard looks your way.",
	"ryumon": "The cups go round again, and the hall looks your way.",
}


## Who a moment is about, from the lords in the hall, or {} if no one fits it.
static func _who(gs, g: Dictionary, id: String) -> Dictionary:
	var host_id := int(g.get("host_lord", -1))
	var lords: Array = gs.gathering_lords(g).filter(func(l): return int(l["id"]) != host_id)
	match id:
		"challenge":
			for l in lords:
				if String(l.get("bearing", "")) == Lords.DARING:
					return l
			return lords[0] if not lords.is_empty() else {}
		"insult":
			var worst: Dictionary = {}
			for l in lords:
				var r := LordTalk.regard(gs, l)
				if r < 0 and (worst.is_empty() or r < LordTalk.regard(gs, worst)):
					worst = l
			return worst
		"aside":
			var marks: Dictionary = gs.gathering_record(g)["marks"]
			for l in lords:
				if marks.has(str(int(l["id"]))):
					return l
			for l in lords:
				if gs.first_word_bonus(l) > 0:
					return l
			return {}
		"news":
			if gs.gathering_is_mine(g) or host_id < 0:
				return {}
			return gs.world.lord_by_id(host_id)
	return {}


## Whether moment `id` can happen at `g` now.
static func fits(gs, g: Dictionary, id: String) -> bool:
	match id:
		"challenge", "insult", "aside", "news":
			return not _who(gs, g, id).is_empty()
	return true


## The moment `id` at `g`: {id, title, text, lord_id, choices: [{id, text, tag, ok, why}]}.
static func make(gs, g: Dictionary, id: String) -> Dictionary:
	var culture := String(g.get("culture", "vardish"))
	var l := _who(gs, g, id)
	var lord_id := int(l.get("id", -1))
	var who := LordTalk.short_name(l) if not l.is_empty() else ""
	var host: String = gs.gathering_host_name(g)
	var m := {"id": id, "lord_id": lord_id, "choices": []}
	match id:
		"bard":
			m["title"] = "A song for the company"
			m["text"] = String(BARD.get(culture, BARD["vardish"]))
			m["choices"] = [
				{"id": "stand", "text": "Stand and take the cheers.", "tag": "+%d renown" % Gatherings.BARD_RENOWN, "ok": true},
				{"id": "pass", "text": "Raise your cup to the singer instead.", "tag": "+%d Regard with %s" % [Gatherings.MOMENT_REGARD, host] if host != "you" else "the hall smiles", "ok": true}]
		"challenge":
			m["title"] = "Arm against arm"
			m["text"] = "%s plants an elbow on the table and grins. \"Arm against arm, captain. For the hall.\"" % who
			m["choices"] = [
				{"id": "accept", "text": "Roll up your sleeve.", "tag": "win: +%d Regard, +%d renown · lose: +%d Regard" % [Gatherings.CHALLENGE_WIN_REGARD, Gatherings.CHALLENGE_RENOWN, Gatherings.MOMENT_REGARD], "ok": true},
				{"id": "decline", "text": "Laugh it off.", "tag": "nothing", "ok": true}]
		"insult":
			m["title"] = "A word across the table"
			m["text"] = "%s wonders aloud, for the whole table to hear, whether sellswords wash before they sit with lords." % who
			m["choices"] = [
				{"id": "answer", "text": "Answer in kind.", "tag": "the hall laughs: +%d renown · %d Regard with %s" % [Gatherings.INSULT_RENOWN, Gatherings.INSULT_REGARD, LordTalk.first_name(l)], "ok": true},
				{"id": "pass", "text": "Let it pass.", "tag": "+%d Regard with %s" % [Gatherings.MOMENT_REGARD, host] if host != "you" else "nothing", "ok": true}]
		"news":
			m["title"] = "The host asks for news"
			m["text"] = "%s calls down the table: \"Captain! What news from the roads?\"" % who
			m["choices"] = [
				{"id": "deeds", "text": "Tell of the company's deeds.", "tag": "+%d Regard with %s" % [Gatherings.NEWS_REGARD, LordTalk.first_name(l)], "ok": true},
				{"id": "war", "text": "Tell what the enemy is about.", "tag": "+%d Regard with each lord of %s" % [Gatherings.MOMENT_REGARD, gs.realm_word(String(g.get("realm", "")))], "ok": true}]
		"aside":
			m["title"] = "A quiet word"
			m["text"] = "%s catches your eye and nods toward a quieter corner of the hall." % who
			m["choices"] = [
				{"id": "go", "text": "Go and sit with %s." % LordTalk.first_name(l), "tag": "talk", "ok": true},
				{"id": "pass", "text": "Not now.", "tag": "nothing", "ok": true}]
		"round":
			m["title"] = "Another round"
			m["text"] = String(ROUND.get(culture, ROUND["vardish"]))
			var can: bool = int(gs.silver) >= Gatherings.ROUND_SILVER
			m["choices"] = [
				{"id": "stand", "text": "Stand the hall a round.", "tag": "−%d silver · +%d Regard with every lord" % [Gatherings.ROUND_SILVER, Gatherings.MOMENT_REGARD],
					"ok": can, "why": "" if can else "you haven't %d silver" % Gatherings.ROUND_SILVER},
				{"id": "pass", "text": "Water your wine.", "tag": "nothing", "ok": true}]
	return m


## Carry out choice `choice` of moment `m`: {ok, text, regard: {lord id: change}, renown,
## silver, talk (a lord id to sit with, or -1)}.
static func choose(gs, g: Dictionary, m: Dictionary, choice: String, roll: float = -1.0) -> Dictionary:
	var out := {"ok": true, "text": "", "regard": {}, "renown": 0, "silver": 0, "talk": -1}
	var l: Dictionary = gs.world.lord_by_id(int(m.get("lord_id", -1))) if int(m.get("lord_id", -1)) >= 0 else {}
	var host_id := int(g.get("host_lord", -1))
	var host: Dictionary = gs.world.lord_by_id(host_id) if host_id >= 0 and not gs.gathering_is_mine(g) else {}
	var warm := func(lord: Dictionary, amount: int) -> void:
		if lord.is_empty() or amount == 0:
			return
		LordTalk.change_regard(gs, lord, amount)
		var key := int(lord["id"])
		out["regard"][key] = int(out["regard"].get(key, 0)) + amount
	match [String(m["id"]), choice]:
		["bard", "stand"]:
			gs.renown += Gatherings.BARD_RENOWN
			out["renown"] = Gatherings.BARD_RENOWN
			out["text"] = "The hall drums the tables for you."
		["bard", "pass"]:
			warm.call(host, Gatherings.MOMENT_REGARD)
			out["text"] = "The singer bows. Modesty plays well at the high table."
		["challenge", "accept"]:
			var won := (roll if roll >= 0.0 else randf()) < Gatherings.CHALLENGE_WIN_CHANCE
			if won:
				warm.call(l, Gatherings.CHALLENGE_WIN_REGARD)
				gs.renown += Gatherings.CHALLENGE_RENOWN
				out["renown"] = Gatherings.CHALLENGE_RENOWN
				out["text"] = "You put %s's arm down with a crack of the table. A roar of laughter, and a call for more wine." % LordTalk.first_name(l)
			else:
				warm.call(l, Gatherings.MOMENT_REGARD)
				out["text"] = "Your arm goes down. %s claps you on the back: a good loser is worth a cup." % LordTalk.first_name(l)
			out["won"] = won
		["challenge", "decline"]:
			out["text"] = "You raise your cup instead. The table moves on."
		["insult", "answer"]:
			warm.call(l, Gatherings.INSULT_REGARD)
			gs.renown += Gatherings.INSULT_RENOWN
			out["renown"] = Gatherings.INSULT_RENOWN
			out["text"] = "Your answer gets the bigger laugh. %s does not forget it." % LordTalk.first_name(l)
		["insult", "pass"]:
			warm.call(host, Gatherings.MOMENT_REGARD)
			out["text"] = "You let it go by. The host notices, and approves."
		["news", "deeds"]:
			warm.call(l, Gatherings.NEWS_REGARD)
			out["text"] = "%s listens to every word, and has your cup filled." % LordTalk.first_name(l)
		["news", "war"]:
			for lord in gs.gathering_lords(g):
				if String(lord.get("realm", "")) == String(g.get("realm", "")):
					warm.call(lord, Gatherings.MOMENT_REGARD)
			out["text"] = "Heads lean in down the table. You know things they don't."
		["aside", "go"]:
			out["talk"] = int(m["lord_id"])
			out["text"] = ""
		["aside", "pass"]:
			out["text"] = "You nod back, and stay where you are."
		["round", "stand"]:
			if int(gs.silver) < Gatherings.ROUND_SILVER:
				return {"ok": false, "text": "", "regard": {}, "renown": 0, "silver": 0, "talk": -1}
			gs.silver -= Gatherings.ROUND_SILVER
			out["silver"] = -Gatherings.ROUND_SILVER
			for lord in gs.gathering_lords(g):
				warm.call(lord, Gatherings.MOMENT_REGARD)
			out["text"] = "A cheer goes up, and every cup in the hall is raised to you."
		["round", "pass"]:
			out["text"] = "You keep a clear head. Someone has to."
		_:
			return {"ok": false, "text": "", "regard": {}, "renown": 0, "silver": 0, "talk": -1}
	return out
