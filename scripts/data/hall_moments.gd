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

## The words: written in the register set out at the top of gatherings.gd. The lord in a
## moment speaks by bearing; what you are (a company, sworn, landed, a crown) is what the
## insult reaches for. {lord} is the lord's short name, {first} their first name, {host}
## the host, {wins} and {battles} your company's record.

const TITLES := {
	"bard": "A song for the company", "challenge": "Arm against arm", "insult": "A word across the table",
	"news": "The host asks for news", "aside": "A quiet word", "round": "Another round",
}

## The song made of your deeds: the hall's own singer, and the record it's made from.
const BARD := {
	"vardish": "The harper strikes up something new: the deeds of your company, {wins} victories in {battles} battles, with more dragons in it than you remember.",
	"kharzani": "A poet rises and recites a qasida on your company: {wins} victories in {battles} battles, each verse grander than the last and none of them quite true.",
	"ryumon": "A verse is read for your company: a banner in the rain, a river crossed by night, {wins} victories in {battles} battles. The hall listens without a sound.",
}
## Before the company has won anything worth a song.
const BARD_NEW := {
	"vardish": "The harper strikes up something new about your company. It is short, because there isn't much to sing yet, and hopeful.",
	"kharzani": "A poet rises with a qasida on your company. It is mostly about what you will do. The poet is generous with the future.",
	"ryumon": "A verse is read for your company: a banner nobody knows yet, on a road nobody has mapped. The hall listens politely.",
}
const BARD_STAND := "Stand and take the cheers."
const BARD_PASS := "Raise your cup to the singer instead."
const BARD_STOOD := "You stand. The hall drums the tables, and the singer adds a verse on the spot."
const BARD_PASSED := "You raise your cup to the singer, who bows low. Modesty plays well at the high table."

## The challenge, by the challenger's bearing.
const CHALLENGE := {
	Lords.DARING: "{lord} plants an elbow on the table and grins. \"Arm against arm, captain. For the hall, and a cask of the host's best.\"",
	Lords.CAUTIOUS: "{lord} sets a cup aside and rolls back one sleeve, unhurried. \"A friendly match, captain. I'm told you're strong. I'd like to know how strong.\"",
	Lords.HONORABLE: "{lord} rises and offers an open hand across the table. \"A trial of arms, captain, the friendly kind. The hall would like to see it.\"",
	Lords.CRUEL: "{lord} leans in on one elbow. \"Arm against arm, captain. Let's see what the hall is paying for.\"",
}
const CHALLENGE_ACCEPT := "Roll up your sleeve."
const CHALLENGE_DECLINE := "Laugh it off."
const CHALLENGE_WON := {
	Lords.DARING: "You put {first}'s arm down with a crack of the table. {first} roars with laughter and calls for the cask.",
	Lords.CAUTIOUS: "You put {first}'s arm down. {first} flexes the hand, considers you, and nods. \"Now I know.\"",
	Lords.HONORABLE: "You put {first}'s arm down. {first} stands and clasps your hand before the whole hall.",
	Lords.CRUEL: "You put {first}'s arm down. {first} smiles, and the smile doesn't move. The hall cheers you anyway.",
}
const CHALLENGE_LOST := {
	Lords.DARING: "Your arm goes down. {first} claps you on the back. \"Again next feast! You nearly had me. You didn't, but nearly.\"",
	Lords.CAUTIOUS: "Your arm goes down. {first} is gracious about it, and fills your cup. A good loser is worth knowing.",
	Lords.HONORABLE: "Your arm goes down. {first} raises your hand anyway. \"A fair match. The hall will drink to both.\"",
	Lords.CRUEL: "Your arm goes down. {first} lets go slowly. \"Better than I expected.\" From {first}, it's almost warm.",
}
const CHALLENGE_DECLINED := "You raise your cup instead and say the host's table is too good to break. The hall laughs, and moves on."

## The insult: what it reaches for depends on what you are.
const INSULT := {
	"company": "{lord} wonders aloud, for the whole table to hear, whether sellswords wash before they sit down with lords.",
	"contract": "{lord} wonders aloud, for the whole table to hear, how much a captain costs by the week, and whether the price includes manners.",
	"fief": "{lord} wonders aloud, for the whole table to hear, how a captain comes by a castle, and whether its last lord was asked.",
	"crown": "{lord} wonders aloud, for the whole table to hear, how long a crown lasts on a head that was selling its sword not long ago.",
}
const INSULT_ANSWER := "Answer in kind."
const INSULT_PASS := "Let it pass."
const INSULT_ANSWERED := "You answer, not loudly. It gets the bigger laugh, and {first} goes red to the ears. {first} will not forget it."
const INSULT_PASSED := "You let it go by and reach for the bread. The host has seen, and approves."

## The host asks for news, by bearing.
const NEWS := {
	Lords.DARING: "{lord} calls down the table: \"Captain! Tell us about the fighting. The real fighting, not the reports.\"",
	Lords.CAUTIOUS: "{lord} catches your eye down the table. \"Captain. What are the roads like? I'd value a soldier's account.\"",
	Lords.HONORABLE: "{lord} raises a hand for quiet. \"Captain, you've come far. Tell the hall what you have seen.\"",
	Lords.CRUEL: "{lord} calls down the table: \"Captain! What news? Who is losing?\"",
}
const NEWS_DEEDS := "Tell of the company's deeds."
const NEWS_WAR := "Tell what the enemy is about."
const NEWS_TOLD_DEEDS := "{first} listens to every word, and has your cup filled before you've finished."
const NEWS_TOLD_WAR := "Heads lean in all down the table. You know things they don't, and they will remember who told them."

## A quiet word, by bearing.
const ASIDE := {
	Lords.DARING: "{lord} catches your eye and jerks their head toward the doors to the yard. Something they'd rather not shout.",
	Lords.CAUTIOUS: "{lord} catches your eye, glances at the high table, and nods toward a quieter corner.",
	Lords.HONORABLE: "{lord} sends a servant down the table: would the captain spare a moment, away from the noise?",
	Lords.CRUEL: "{lord} is watching you over a cup, and tips it toward the shadows by the wall.",
}
const ASIDE_GO := "Go and sit with {first}."
const ASIDE_PASS := "Not now."
const ASIDE_PASSED := "You nod back, and stay where you are. {first} shrugs, and looks for someone else."

## Another round.
const ROUND := {
	"vardish": "The ale keeps coming. The hall has noticed you haven't stood a round yet.",
	"kharzani": "The sherbet has given way to wine, and the courtyard has noticed you haven't stood a round yet.",
	"ryumon": "The cups go round again. The hall has noticed you haven't filled them yet.",
}
const ROUND_STAND := "Stand the hall a round."
const ROUND_PASS := "Water your wine."
const ROUND_STOOD := "A cheer goes up, and every cup in the hall is raised to you."
const ROUND_PASSED := "You keep a clear head. Someone has to."


static func _by(lines: Dictionary, l: Dictionary) -> String:
	return String(lines.get(String(l.get("bearing", "")), lines[Lords.HONORABLE]))


static func _fill(text: String, l: Dictionary, extra: Dictionary = {}) -> String:
	var ctx := {"lord": LordTalk.short_name(l) if not l.is_empty() else "", "first": LordTalk.first_name(l) if not l.is_empty() else ""}
	ctx.merge(extra, true)
	return Gatherings.fill(text, ctx)


## What the insult reaches for: what you are.
static func _what_you_are(gs) -> String:
	if gs.is_crowned():
		return "crown"
	if gs.has_fief() and not bool(gs.player_fief.get("lost", false)):
		return "fief"
	if gs.has_contract():
		return "contract"
	return "company"


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
	var host: String = gs.gathering_host_name(g)
	var m := {"id": id, "lord_id": lord_id, "choices": [], "title": String(TITLES.get(id, ""))}
	match id:
		"bard":
			var song: Dictionary = BARD if int(gs.wins) >= 3 else BARD_NEW
			m["text"] = Gatherings.fill(String(song.get(culture, song["vardish"])), {"wins": str(int(gs.wins)), "battles": str(int(gs.battles))})
			m["choices"] = [
				{"id": "stand", "text": BARD_STAND, "tag": "+%d renown" % Gatherings.BARD_RENOWN, "ok": true},
				{"id": "pass", "text": BARD_PASS, "tag": "+%d Regard with %s" % [Gatherings.MOMENT_REGARD, host] if host != "you" else "the hall smiles", "ok": true}]
		"challenge":
			m["text"] = _fill(_by(CHALLENGE, l), l)
			m["choices"] = [
				{"id": "accept", "text": CHALLENGE_ACCEPT, "tag": "win: +%d Regard, +%d renown · lose: +%d Regard" % [Gatherings.CHALLENGE_WIN_REGARD, Gatherings.CHALLENGE_RENOWN, Gatherings.MOMENT_REGARD], "ok": true},
				{"id": "decline", "text": CHALLENGE_DECLINE, "tag": "nothing", "ok": true}]
		"insult":
			m["text"] = _fill(String(INSULT[_what_you_are(gs)]), l)
			m["choices"] = [
				{"id": "answer", "text": INSULT_ANSWER, "tag": "the hall laughs: +%d renown · %d Regard with %s" % [Gatherings.INSULT_RENOWN, Gatherings.INSULT_REGARD, LordTalk.first_name(l)], "ok": true},
				{"id": "pass", "text": INSULT_PASS, "tag": "+%d Regard with %s" % [Gatherings.MOMENT_REGARD, host] if host != "you" else "nothing", "ok": true}]
		"news":
			m["text"] = _fill(_by(NEWS, l), l)
			m["choices"] = [
				{"id": "deeds", "text": NEWS_DEEDS, "tag": "+%d Regard with %s" % [Gatherings.NEWS_REGARD, LordTalk.first_name(l)], "ok": true},
				{"id": "war", "text": NEWS_WAR, "tag": "+%d Regard with each lord of %s" % [Gatherings.MOMENT_REGARD, gs.realm_word(String(g.get("realm", "")))], "ok": true}]
		"aside":
			m["text"] = _fill(_by(ASIDE, l), l)
			m["choices"] = [
				{"id": "go", "text": _fill(ASIDE_GO, l), "tag": "talk", "ok": true},
				{"id": "pass", "text": ASIDE_PASS, "tag": "nothing", "ok": true}]
		"round":
			m["text"] = String(ROUND.get(culture, ROUND["vardish"]))
			var can: bool = int(gs.silver) >= Gatherings.ROUND_SILVER
			m["choices"] = [
				{"id": "stand", "text": ROUND_STAND, "tag": "−%d silver · +%d Regard with every lord" % [Gatherings.ROUND_SILVER, Gatherings.MOMENT_REGARD],
					"ok": can, "why": "" if can else "you haven't %d silver" % Gatherings.ROUND_SILVER},
				{"id": "pass", "text": ROUND_PASS, "tag": "nothing", "ok": true}]
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
			out["text"] = BARD_STOOD
		["bard", "pass"]:
			warm.call(host, Gatherings.MOMENT_REGARD)
			out["text"] = BARD_PASSED
		["challenge", "accept"]:
			var won := (roll if roll >= 0.0 else randf()) < Gatherings.CHALLENGE_WIN_CHANCE
			if won:
				warm.call(l, Gatherings.CHALLENGE_WIN_REGARD)
				gs.renown += Gatherings.CHALLENGE_RENOWN
				out["renown"] = Gatherings.CHALLENGE_RENOWN
				out["text"] = _fill(_by(CHALLENGE_WON, l), l)
			else:
				warm.call(l, Gatherings.MOMENT_REGARD)
				out["text"] = _fill(_by(CHALLENGE_LOST, l), l)
			out["won"] = won
		["challenge", "decline"]:
			out["text"] = CHALLENGE_DECLINED
		["insult", "answer"]:
			warm.call(l, Gatherings.INSULT_REGARD)
			gs.renown += Gatherings.INSULT_RENOWN
			out["renown"] = Gatherings.INSULT_RENOWN
			out["text"] = _fill(INSULT_ANSWERED, l)
		["insult", "pass"]:
			warm.call(host, Gatherings.MOMENT_REGARD)
			out["text"] = INSULT_PASSED
		["news", "deeds"]:
			warm.call(l, Gatherings.NEWS_REGARD)
			out["text"] = _fill(NEWS_TOLD_DEEDS, l)
		["news", "war"]:
			for lord in gs.gathering_lords(g):
				if String(lord.get("realm", "")) == String(g.get("realm", "")):
					warm.call(lord, Gatherings.MOMENT_REGARD)
			out["text"] = NEWS_TOLD_WAR
		["aside", "go"]:
			out["talk"] = int(m["lord_id"])
			out["text"] = ""
		["aside", "pass"]:
			out["text"] = _fill(ASIDE_PASSED, l)
		["round", "stand"]:
			if int(gs.silver) < Gatherings.ROUND_SILVER:
				return {"ok": false, "text": "", "regard": {}, "renown": 0, "silver": 0, "talk": -1}
			gs.silver -= Gatherings.ROUND_SILVER
			out["silver"] = -Gatherings.ROUND_SILVER
			for lord in gs.gathering_lords(g):
				warm.call(lord, Gatherings.MOMENT_REGARD)
			out["text"] = ROUND_STOOD
		["round", "pass"]:
			out["text"] = ROUND_PASSED
		_:
			return {"ok": false, "text": "", "regard": {}, "renown": 0, "silver": 0, "talk": -1}
	return out
