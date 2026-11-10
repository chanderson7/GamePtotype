## What is said at a wedding: how the day opens at the place, her vow (from a time you
## shared, when there is one), the vows you can say, each culture's rite, the toasts, and
## the private vows by one candle. Words only; the rules are in the social sim and GameState.
## {name} is the one you marry, {place} the place, {host} who hosts, {captain} the captain
## who toasts.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Lords = preload("res://scripts/data/lords.gd")

## How the day opens, by whose place it is ("hers", "yours", "other").
const ARRIVAL := {
	"hers": "Half of {place} has found a reason to be out tonight. {host}'s banners hang from every lamp; your company's hangs beside them, a little crooked.",
	"yours": "{place} is yours, and tonight it looks it: your banner over the gate, your people lining the street, and {name}'s house banner hung beside yours.",
	"other": "{place} lends you its square for the evening. Strangers lean from windows; your company has made itself at home in the inn, as companies do.",
}

## Her line asking you to stand beside her.
const STAND := {
	"edda": "Everyone's looking at you. That's the point, I'm told. Come and stand here.",
	"farid": "I have written eleven speeches for today and I am going to say none of them. Come here.",
	"kaede": "The register is open, the ink is fresh, and I have checked the spelling of your name four times. Come.",
}

## Who reads the old words, when no lord hosts.
const OFFICIANT := "An old priest of {place} reads the old words. Then the square goes quiet."

## Her vow, from a time you shared (by visit scene).
const VOWS := {
	"edda_spare_spoon": "My mother laid one place more than she had people. I've laid it every night since. From today it isn't spare. It's yours.",
	"edda_wrong_verse": "I'll keep your books until I die. Every month, by the first. That's the most loving thing I know how to say.",
	"edda_boots_by_door": "I've counted this household in every night for twelve years. I vow to count you in for all the rest, and not sit down until you're home.",
	"edda_morning_unclaimed": "One hour a day with nothing in my hands but yours. I've practised. I'm still bad at it. I'll go on.",
	"edda_ledger_blot": "There's a page in my black book I never want to write on again. I vow to do everything a steward can to keep it so.",
	"edda_place_no_task": "I spent twelve years at the door so I'd never have to sit at the table. I'm sitting. I'm staying sat.",
	"edda_who_set_your_place": "Forty-two notches. The last one's you. I shan't cut another; the count's come out.",
	"edda_home_on_time": "I'll be home on time, and so will you, as often as roads allow. And when they don't, I'll be at the door.",
	"farid_supper_request": "Two truths and no lie: I love you, and I will. I couldn't think of a third thing worth saying.",
	"farid_two_street_names": "I was born on a crooked street and carried off it in a chair. You walked me back down. I'll walk with you anywhere.",
	"farid_unsealed_letter": "I told my brother a road was safe, and I've feared plain words ever since. Here are plain ones: I'm yours.",
	"farid_wrong_courtesy": "You've seen me on a floor with the envoy taken off. I vow you'll always have that one. The other's for hire.",
	"farid_own_answer": "I wrote 'no' once, and it was the truest thing I'd written. Today I write the other word.",
	"farid_no_reply_required": "I'll bring you unimportant news for the rest of my life, with nothing tied to it. You needn't reply. Only listen.",
	"farid_said_plainly": "Five words, no exits. I've three more: all my days.",
	"farid_short_answer": "I stood on the Salt Road and told my brother I was happy. I vow to keep it true.",
	"kaede_useless_map": "You were a source. Then you were a file. Now you are the only account I intend to keep for the rest of my life.",
	"kaede_bad_mystery": "I would burn the world for you. It is a quotation. I have verified that I mean it.",
	"kaede_margin_name": "I wrote one name in a margin and was beaten for it. I write yours in the register, where no one may scrape it out.",
	"kaede_missing_street": "I have drawn a hundred places I have never seen. I vow to see them with you, and correct every map.",
	"kaede_kept_page": "My record of you lost its objectivity some time ago. I vow never to recover it.",
	"kaede_room_on_map": "I walked through a gate because you were beside it. I vow to go on walking through them.",
	"kaede_preference_stated": "I entered one preference, and it was you. I vow never to strike it out.",
	"kaede_name_used": "You hold the one name nobody else may use. Today I take yours, and give you the rest of mine.",
}

## Her vow when no shared time has a vow of its own.
const VOW_DEFAULT := {
	"edda": "I keep tallies for a living. I've stopped counting the reasons. That's how you know.",
	"farid": "I have negotiated a great many agreements. This is the only one I never wanted to win. I only wanted to keep it.",
	"kaede": "Records outlast people. I'd like ours to say we were happy, and I'd like it to be true.",
}

## What you can say: three vows for each of them, none of them wrong.
const YOURS := {
	"edda": [
		{"id": "promise", "text": "I'll come home to it. Every time I can, and I'll write when I can't.", "tag": "a promise"},
		{"id": "honest", "text": "I can't promise the war ends. I can promise you won't face it alone.", "tag": "honest"},
		{"id": "laugh", "text": "I'll even learn which cousin owes whom a horse.", "tag": "make her laugh"},
	],
	"farid": [
		{"id": "promise", "text": "Wherever the roads close, I'll find the one back to you.", "tag": "a promise"},
		{"id": "honest", "text": "I'm a soldier, not an envoy. I'll say it badly, and I'll mean all of it.", "tag": "honest"},
		{"id": "laugh", "text": "I'll even learn the courtesies. Some of them. The short ones.", "tag": "make her laugh"},
	],
	"kaede": [
		{"id": "promise", "text": "Write it down: I'll come back. Every time. You can check the record.", "tag": "a promise"},
		{"id": "honest", "text": "I don't know how long the war lasts. I know who I want waiting at the end of it.", "tag": "honest"},
		{"id": "laugh", "text": "I promise never to correct your spelling. Even of my own name.", "tag": "make her laugh"},
	],
}

## Each culture's rite, as a few lines of narration.
const RITES := {
	Cultures.VARDISH: [
		"By Vardish custom a red cord is wound once around both your wrists, over the hearth-fire carried out from the hall.",
		"{name} ties the knot herself. Of course she does. It holds.",
	],
	Cultures.KHARZANI: [
		"By Kharzani custom you share bread and salt before witnesses from both houses, and the marriage contract is read aloud.",
		"{name} wrote it. It is very good. Someone at the back cries at the clause about lentils.",
	],
	Cultures.RYUMON: [
		"By Ryumon custom there are three small cups, and three sips from each, and then your names are written in the register.",
		"{name} writes yours herself and will not let anyone check it.",
	],
}

## Your longest-serving captain's toast (one, by the captain's id).
const CAPTAIN_TOASTS := [
	"Captain's never asked me for a toast, so I'll keep it short. To {name}, the one person who can make the captain sit still.",
	"I've followed the captain through mud, rivers and one very bad inn. Never thought I'd follow them here. To the two of you.",
	"To {name}. Look after the captain; we've had the job long enough and we'd like a rest.",
	"I had a speech. The lads drank it. To {name}, and the captain, and no battles for at least a week.",
	"We've buried friends and won fights we shouldn't have. Tonight we get to cheer for once. To {name}!",
	"The captain told me not to say anything embarrassing. So: to {name}, who could do better, and chose not to.",
]

## The host's toast, by bearing.
const HOST_TOASTS := {
	Lords.CAUTIOUS: "Look after her. She has looked after this house long enough; it is someone's turn to look after her.",
	Lords.DARING: "I'd have stolen her away on horseback, myself. But a wedding has its charms. Drink!",
	Lords.HONORABLE: "Keep your word to her as you have kept it to this house, and you will never want for friends here.",
	Lords.CRUEL: "Our house is your house now. Mind you don't make me regret it.",
}

## Raising your cup.
const YOUR_TOASTS := {
	"her": "To {name}.",
	"company": "To the company, who got me here.",
	"absent": "To absent friends: {fallen}.",
}

## What she says after you raise your cup.
const AFTER_TOAST := {
	"her": "Sit down before they make you give a speech.",
	"company": "They heard you. Look at them pretending they didn't.",
	"absent": "They'd have liked tonight. I wish I'd known them.",
}

## The quiet way: in her room, by one candle.
const PRIVATE := {
	"edda": "{host} will sulk for a month. I find I don't mind.",
	"farid": "No witnesses, no contract, no speeches. My mother would faint. I've never felt more sure.",
	"kaede": "There's nothing to write down tonight. I'll remember it instead.",
}

## Where she'll be afterward.
const AFTER := {
	"edda": "{name} keeps the household at {place} and writes when you're away. Visit any time.",
	"farid": "{name} keeps the envoy's office at {place}, and your letters at the top of the pile.",
	"kaede": "{name} goes back to the archive at {place}, and has started a page with both your names on it.",
}

## A gift sent by a ruler who didn't come.
const GIFTS := {
	Cultures.VARDISH: "a silver cup",
	Cultures.KHARZANI: "a bolt of red silk",
	Cultures.RYUMON: "a lacquered writing box",
}


static func fill(text: String, ctx: Dictionary) -> String:
	var out := text
	for k in ctx:
		out = out.replace("{%s}" % k, String(ctx[k]))
	return out


## Her vow: from the most recent time you shared that has one, else her own default.
## Returns {text, scene_id ("" when the default), day}.
static func their_vow(cand: String, memories: Array) -> Dictionary:
	for i in range(memories.size() - 1, -1, -1):
		var m: Dictionary = memories[i]
		if String(m.get("kind", "")) == "visit" and VOWS.has(String(m.get("scene_id", ""))):
			return {"text": VOWS[String(m["scene_id"])], "scene_id": String(m["scene_id"]), "day": int(m.get("day", 0))}
	return {"text": String(VOW_DEFAULT.get(cand, VOW_DEFAULT["edda"])), "scene_id": "", "day": 0}


static func yours(cand: String) -> Array:
	return YOURS.get(cand, YOURS["edda"])


static func rite(culture: String) -> Array:
	return RITES.get(culture, RITES[Cultures.VARDISH])


static func captain_toast(captain_id: int) -> String:
	return CAPTAIN_TOASTS[posmod(captain_id, CAPTAIN_TOASTS.size())]


static func host_toast(bearing: String) -> String:
	return String(HOST_TOASTS.get(bearing, HOST_TOASTS[Lords.HONORABLE]))
