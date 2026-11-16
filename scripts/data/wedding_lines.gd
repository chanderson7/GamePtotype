## What is said at the ceremony: how the day opens at the place, who stands with you, her
## vow (from a time you shared, when there is one), the vows you can say, each culture's
## rite a step at a time, the question and both answers, and the private vows by one
## candle. The feast after is in wedding_feast_lines.gd. Words only; the rules are in the
## social sim and GameState. {name} is the one you marry, {place} the place, {host} who
## hosts, {second} who stands with you.
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

## Asked who stands with you.
const SECOND_PROMPT := "Who stands with you?"
const SECOND_NONE := "No one. Just the two of us."
## Your second takes their place, by what they are to you.
const SECOND_STANDS := {
	"longest": "{second} steps up beside you, as they have in every line you've ever stood in.",
	"hero": "{second} takes the place at your shoulder as if it had always been theirs.",
	"bonded": "{second} steps up beside you, and glances back once at the friend they left in the crowd.",
	"newest": "{second} steps up beside you, white to the ears, and stands very straight.",
}
## Who hands you what the rite needs.
const SECOND_HANDS := {
	"vardish": "{second} hands you the cord, warm from the fire.",
	"kharzani": "{second} hands you the bread, and holds the salt as if it might run off.",
	"ryumon": "{second} sets the three cups in a row and steps back.",
}
## What your second says under their breath, before the question.
const SECOND_WHISPER := [
	"Breathe, captain. It's only the rest of your life.",
	"Don't lock your knees. I've seen men fall over at these.",
	"I've got the ring. I mean, there's no ring. I've got the cord. It's fine.",
	"Whatever you say next, say it loud. The back row's betting.",
]

## Her face answers the vow you say (by its id in YOURS).
const VOW_FACE := {"promise": "warm", "honest": "neutral", "laugh": "amused"}

## Each culture's rite, a step at a time: plain steps you do, then a choice that is kept.
## {intro, steps: [{id, text, tag, line}], prompt, choices: [{id, text, tag, bare, line}]}.
const RITE_STEPS := {
	Cultures.VARDISH: {
		"intro": "By Vardish custom a red cord is wound once around both your wrists, over the hearth-fire carried out from the hall.",
		"steps": [
			{"id": "wrist", "text": "Hold out your wrist.", "tag": "over the hearth-fire",
				"line": "The cord is passed once through the fire's smoke and laid across your wrist. It smells of pine."},
			{"id": "wind", "text": "Wind it once.", "tag": "around both your wrists",
				"line": "You wind it once around both your wrists. Hers is warm, and perfectly steady. Yours less so."},
		],
		"prompt": "The knot",
		"choices": [
			{"id": "she_ties", "text": "Hold still while she ties it.", "tag": "her knot", "bare": true,
				"line": "{name} ties the knot herself. Of course she does. It holds."},
			{"id": "together", "text": "Tie it together.", "tag": "four hands, one knot", "bare": true,
				"line": "Four hands, one knot, and a great deal of advice from the front row. It holds."},
		],
	},
	Cultures.KHARZANI: {
		"intro": "By Kharzani custom you share bread and salt before witnesses from both houses, and the marriage contract is read aloud.",
		"steps": [
			{"id": "bread", "text": "Break the bread.", "tag": "before both houses",
				"line": "The loaf breaks clean in two. The old women along the wall nod at each other: a good sign, apparently."},
			{"id": "salt", "text": "Salt it, and give her the first piece.", "tag": "the first piece is hers",
				"line": "You salt it and give her the first piece. She eats it solemnly, and then not solemnly at all."},
		],
		"prompt": "The contract is read aloud. One clause is yours to add.",
		"choices": [
			{"id": "door", "text": "The door is never barred to the other, whatever the hour.", "tag": "a clause for home",
				"line": "{name} writes it in herself, in a clean hand, and signs beside it before the ink is dry."},
			{"id": "letters", "text": "Every letter is answered within the month, wherever the war is.", "tag": "a clause for the road",
				"line": "{name} reads it twice, underlines \"every\", and signs."},
			{"id": "lentils", "text": "Neither shall be made to eat the other's lentils.", "tag": "the lentil clause",
				"line": "{name} wrote the rest of it. It is very good. Someone at the back cries at the clause about lentils."},
		],
	},
	Cultures.RYUMON: {
		"intro": "By Ryumon custom there are three small cups, and three sips from each, and then your names are written in the register.",
		"steps": [
			{"id": "cup1", "text": "The first cup: for what was.", "tag": "three sips",
				"line": "Three sips. It is sharp, and then it is warm."},
			{"id": "cup2", "text": "The second: for what is.", "tag": "three sips",
				"line": "Three sips. Across the cups {name} is trying not to smile, and failing."},
			{"id": "cup3", "text": "The third: for what will be.", "tag": "three sips",
				"line": "Three sips. The cups are turned down, and the register is opened to a clean page."},
		],
		"prompt": "How do you sign the register?",
		"choices": [
			{"id": "plain", "text": "Plainly.", "tag": "your name, nothing more", "bare": true,
				"line": "Your name, plainly. {name} writes hers beside it and will not let anyone check the spelling."},
			{"id": "company", "text": "With the company's name under it.", "tag": "the company signs too", "bare": true,
				"line": "Your name, and the company's under it. The archivist sighs at the irregularity, and lets it stand."},
			{"id": "her", "text": "Let her write it.", "tag": "her hand, your name", "bare": true,
				"line": "{name} writes yours herself, and will not let anyone check it."},
		],
	},
}

## The question, in her people's words: asked of her, then of you.
const QUESTION := {
	Cultures.VARDISH: {"her": "{name}, will you have this one, hearth and road?",
		"you": "And you, captain. Will you have {name}, hearth and road?"},
	Cultures.KHARZANI: {"her": "Before these witnesses, and by this contract: {name}, do you consent?",
		"you": "Before these witnesses, and by this contract: captain, do you consent?"},
	Cultures.RYUMON: {"her": "{name}: is it your will that these names stand together in the register?",
		"you": "Captain: is it your will that these names stand together in the register?"},
}
## In Qasr Hamra the bride is asked three times and answers on the third: the form matters.
const ASKED_AGAIN := {
	Cultures.KHARZANI: ["{name} says nothing. The form matters.",
		"Still nothing. Someone at the back is counting on their fingers."],
}
## When no lord hosts, the old priest asks it.
const PRIEST_ASKS := "The old priest turns to {name}, and asks it in the old words."
## Her answer, in her own voice.
const ANSWER := {
	"edda": "I do. Write it down before I think of conditions.",
	"farid": "I do. I'd have said so the first time.",
	"kaede": "I do. It's the first thing I've said in years that I didn't want to check.",
}
## "Take a breath": nobody moves. Your second mutters (or, with no one beside you, the
## hall waits), and she raises an eyebrow in her own way.
const BREATH := "Nobody moves."
const BREATH_SECOND := "Captain. The words. Any time."
const BREATH_ALONE := "Somewhere at the back a cup is set down, very carefully."
const BREATH_HER := {
	"edda": "Edda raises one eyebrow: the look she keeps for late deliveries.",
	"farid": "Farah raises an eyebrow, very slightly. In Qasr Hamra that is a whole speech.",
	"kaede": "Kaede raises an eyebrow and, without looking down, uncaps her brush.",
}
## The moment it's said: the seal, in one line.
const SEAL := {
	Cultures.VARDISH: "The knot holds. Someone cuts the cord's ends with a flourish, and the hall roars.",
	Cultures.KHARZANI: "The contract is signed, both names, and sanded dry. The courtyard roars.",
	Cultures.RYUMON: "The ink is dry. Your names stand together in the register, and the terrace erupts.",
}
## Asked in her room, with no one to ask it: she asks you herself.
const PRIVATE_ASK := {
	"edda": "Well? Do you?",
	"farid": "There's no one here to ask it properly, so I will. Do you?",
	"kaede": "There's no register tonight. So I'll ask, and I'll remember. Do you?",
}
const PRIVATE_ANSWER := {
	"edda": "Then so do I. There. Done. Don't tell my cousin how easy it was.",
	"farid": "And I do. No witnesses. I find I don't need any.",
	"kaede": "So do I. I'll remember it exactly. I won't need to write it down.",
}

## Her vow, from a time you shared (by visit scene).
const VOWS := {
	"edda_spare_spoon": "I used to set a spare spoon for whoever came. I'd like it to be you. Every evening, for as long as there are evenings.",
	"edda_wrong_verse": "I'll sing you the wrong ending every time, and you'll pretend it's the right one. That's the whole vow. It's a good one.",
	"edda_boots_by_door": "Leave your boots by the door. Leave them crooked. I'll straighten them, and I'll be glad there's someone to straighten them for.",
	"edda_morning_unclaimed": "Give me one morning that belongs to no one, now and then. I'll give you all the rest.",
	"edda_ledger_blot": "You can blot my ledger any time you like. I won't scrape it out. I'll keep it, like the first one.",
	"edda_place_no_task": "I promise to sit with you with nothing to do. It's the hardest thing I know how to promise.",
	"farid_supper_request": "I promise to ask for what I want in few words. Here are three: I want you.",
	"farid_two_street_names": "The city has two names for every street. I have one for home now, and it's yours.",
	"farid_unsealed_letter": "Every letter I write you I'll leave unsealed. You should never have to break anything to reach me.",
	"farid_wrong_courtesy": "I'll get the courtesies wrong for you, on purpose, forever. Some things should be done badly and gladly.",
	"farid_own_answer": "You asked me once what I thought, not what I was told. I'll keep answering. That's my vow.",
	"farid_no_reply_required": "I'll tell you unimportant news for the rest of my life, and you never have to reply. Just listen.",
	"kaede_useless_map": "I'll put you on every map I make, even the useless ones. Especially those.",
	"kaede_bad_mystery": "We'll get things wrong together and like our answer better. I'd rather be wrong with you than right alone.",
	"kaede_margin_name": "I wrote a private name in a margin once. Today I write it in the register, where anyone can read it.",
	"kaede_missing_street": "If the road moves, I'll walk it with you. I've stopped correcting the map; I'd rather keep the company.",
	"kaede_kept_page": "I'm keeping this page. Whoever asks who wrote it, I'll say we did.",
	"kaede_room_on_map": "There's a place on my map with a little smudge on it. It's where you are. I won't fix it.",
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


## The rite's steps for `culture` (see RITE_STEPS).
static func rite_steps(culture: String) -> Dictionary:
	return RITE_STEPS.get(culture, RITE_STEPS[Cultures.VARDISH])


## The rite's choice with `id`, or {}.
static func rite_choice(culture: String, id: String) -> Dictionary:
	for c in rite_steps(culture)["choices"]:
		if String(c["id"]) == id:
			return c
	return {}


static func question(culture: String) -> Dictionary:
	return QUESTION.get(culture, QUESTION[Cultures.VARDISH])


static func host_toast(bearing: String) -> String:
	return String(HOST_TOASTS.get(bearing, HOST_TOASTS[Lords.HONORABLE]))
