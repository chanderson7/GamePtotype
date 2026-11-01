## What letters say. Each kind of letter (its template key, as SocialSim.add_letter is
## given it) has a version for each candidate, worded for a courtship ("courting") or a
## friendship ("friend"), and a few short replies you can send back. Pure data and
## rendering; the social sim stores the rendered letter so its words never change.
extends RefCounted

const WorldData = preload("res://scripts/world/world_data.gd")

## A sender's wax seal: the letter pressed into it and its colour.
const SEALS := {
	"edda": {"mark": "C", "color": "b8352a"},
	"farid": {"mark": "H", "color": "1f7a6e"},
	"kaede": {"mark": "K", "color": "2c4fae"},
}

## {place} is where the letter was written, {old} the place the sender had to leave.
const LETTERS := {
	"ch2_invitation": {
		"edda": {
			"courting": {
				"subject": "A chair by the fire",
				"salute": "Captain,",
				"body": [
					"The ledgers balance tonight for the first time since the thaw, and I find I have no one to tell. Thornwall's granary has its roof again. Kettlebrook sends its thanks in turnips, which I am assured is a compliment.",
					"If your road bends toward {place}, the hall keeps a chair by the fire. I would like to hear what you saw on the border, and I would like, I think, simply to see you.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "My cousin asks what you cost. I told him: more than he has.",
			},
			"friend": {
				"subject": "The border villages",
				"salute": "Captain,",
				"body": [
					"You offered help, and I have been a steward too long to let an offer go unanswered. Thornwall's granary has its roof again; Kettlebrook's well does not, and its headman has stopped pretending otherwise.",
					"Come to {place} when the road allows. I will have the tallies laid out and the worst of it marked in red, and you may tell me plainly which of it a free company can mend.",
				],
				"sign": "Edda", "sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "A letter with no business in it",
				"salute": "Captain,",
				"body": [
					"I write a great many letters. Every one of them carries a request, a price, or a warning, usually all three, folded so that nobody can tell which is which.",
					"This one carries none of them. I should like you to come to {place}. There is a courtyard here where the caravans water at dusk, and I have never once had a reason to sit in it. I would like you to be the reason.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "If anyone asks, this was about tariffs.",
			},
			"friend": {
				"subject": "The address people use",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"You were kind enough to offer your company's help, and I am practical enough to accept it. A caravan road east of {place} has gone quiet, and quiet roads are the expensive kind.",
					"Call on me when you pass this way. I will have coffee, a map, and the names of the people who would rather that road stayed closed.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "On the matter of a map",
				"salute": "Captain,",
				"body": [
					"I have found a map of places no one needs: a ford that silted up a century ago, a shrine moved twice, a road that ends at a field. I have been adding to it for years and have never shown it to anyone.",
					"If you come to {place}, I will show it to you. I cannot promise it will be useful. I can promise that you would be the first, and that I have been thinking about the asking for longer than is sensible.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
			"friend": {
				"subject": "A record that needs witnesses",
				"salute": "To the captain of the free company,",
				"body": [
					"The covenant I spoke of has two claimants and one copy, and the copy disagrees with itself. Such things are settled by witnesses, and I need one who belongs to neither clan.",
					"Come to {place} when you can. The work is dull and the tea is worse, but the feud it prevents is neither.",
				],
				"sign": "Kaede", "sign_title": "Archivist of Kitayama",
				"ps": "",
			},
		},
	},
	"relocation": {
		"edda": {
			"courting": {
				"subject": "We left {old}",
				"salute": "Captain,",
				"body": [
					"{old} is lost. We went out by the river gate with the household's ledgers and as many of the village families as would come. I counted them twice on the road; the number did not improve.",
					"We are at {place} now. I am well, which I write first because you will ask it first. I would rather you heard the rest from me in person than from a herald.",
				],
				"sign": "Edda", "sign_title": "of House Caldmoor",
				"ps": "I kept the chair. It is a terrible chair. It came anyway.",
			},
			"friend": {
				"subject": "The household has moved",
				"salute": "Captain,",
				"body": [
					"{old} has fallen, and the household has removed to {place}. The villages are on their own for now, and I mean to change that as soon as I have a roof and a desk again.",
					"If your company is near, I would be glad of a steady pair of hands, and gladder of a friend's face.",
				],
				"sign": "Edda", "sign_title": "Steward of the household",
				"ps": "",
			},
		},
		"farid": {
			"courting": {
				"subject": "A change of address",
				"salute": "Captain,",
				"body": [
					"You will hear that {old} has changed hands, and you will hear it told several ways. Here is mine: I left with the treaty boxes, two clerks, and my good shoes, and I did not look back until the dust hid the walls.",
					"I am at {place}. Write to me here, or better, do not write at all and simply come.",
				],
				"sign": "Farah", "sign_title": "Envoy, for the present without a seat",
				"ps": "",
			},
			"friend": {
				"subject": "A change of address",
				"salute": "To the captain, with the envoy's regards,",
				"body": [
					"{old} has fallen and the envoy's office has moved to {place}. Correspondence will reach me here; caravans, I fear, will take longer to persuade.",
					"Should your company pass, my door is open and my maps are, for once, out of date. I could use a fresh pair of eyes on them.",
				],
				"sign": "Farah", "sign_title": "Envoy of Qasr Hamra",
				"ps": "",
			},
		},
		"kaede": {
			"courting": {
				"subject": "The archive moves",
				"salute": "Captain,",
				"body": [
					"{old} is lost to us, and with it the east wing of the archive. I carried out what I could hold: the covenant boxes, two lineages, and the map. Of course the map.",
					"I am lodged at {place} now, among people who think records are kindling. I find I am counting the days until a particular company passes this way.",
				],
				"sign": "Kaede", "sign_title": "Archivist, lately of {old}",
				"ps": "",
			},
			"friend": {
				"subject": "The archive moves",
				"salute": "To the captain of the free company,",
				"body": [
					"{old} is lost to us, and with it the east wing of the archive. I carried out what I could hold: the covenant boxes, two lineages, and a map that is no use to anyone but me.",
					"I am lodged at {place} now, among people who think records are kindling. If your company passes this way, I would be glad of a face that remembers what we were trying to keep.",
				],
				"sign": "Kaede", "sign_title": "Archivist, lately of {old}",
				"ps": "",
			},
		},
	},
}

## Short answers to each kind of letter: a label for the button, how much it warms them
## (trust, once per letter), and the letter you send. {name} is who you write to.
const REPLIES := {
	"ch2_invitation": [
		{"id": "coming", "label": "I'll come", "trust": 3,
			"courting": ["{name},", "Keep the chair. The company marches for {place} as soon as the horses are shod, and I will be at the front of it, which my sergeant says is bad form for a captain.", "Until then,"],
			"friend": ["{name},", "Count me in. Lay out the tallies; we march for {place} as soon as the horses are shod.", "Yours in good faith,"]},
		{"id": "soon", "label": "When the road allows", "trust": 1,
			"courting": ["{name},", "The road has opinions of its own this week, but it will bend toward {place} soon. I have not forgotten, and I will not.", "Until then,"],
			"friend": ["{name},", "The company is tied up for now. I'll come to {place} when the road allows, and I'll bring hands that can work.", "Yours in good faith,"]},
		{"id": "plain", "label": "A soldier's answer", "trust": 0,
			"courting": ["{name},", "Received. Will come.", "Captain,"],
			"friend": ["{name},", "Received. Will come when able.", "Captain,"]},
	],
	"relocation": [
		{"id": "comfort", "label": "I'm glad you're safe", "trust": 3,
			"courting": ["{name},", "I read your letter twice before I let myself believe the first line. I am sorry about {old}. I am not sorry you are at {place}, because it means you are somewhere.", "Until I see you,"],
			"friend": ["{name},", "I'm sorry about {old}, and glad beyond words you got out. Hold on at {place}; we'll think of what comes next together.", "Your friend,"]},
		{"id": "practical", "label": "Tell me what you need", "trust": 2,
			"courting": ["{name},", "Tell me what you need at {place}: men, silver, or a wagon for that terrible chair. The company is yours to ask.", "Until I see you,"],
			"friend": ["{name},", "Tell me what you need at {place}. Men, silver, wagons. The company is at your disposal.", "Your friend,"]},
		{"id": "plain", "label": "A soldier's answer", "trust": 0,
			"courting": ["{name},", "Heard about {old}. Glad you're out.", "Captain,"],
			"friend": ["{name},", "Heard about {old}. Glad you're out.", "Captain,"]},
	],
}

## How you sign your own letters.
const PLAYER_SIGN := "The Captain"
const PLAYER_SIGN_TITLE := "of the free company"

const ORDINALS := ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
	"eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth", "eighteenth",
	"nineteenth", "twentieth"]


## The letter `key` from `candidate_id`, written as a courtship or a friendship. `ctx`
## gives {place, old, hour}. Missing words fall back to a plain note.
static func render(key: String, candidate_id: String, courting: bool, ctx: Dictionary) -> Dictionary:
	var by_person: Dictionary = LETTERS.get(key, {})
	var versions: Dictionary = by_person.get(candidate_id, {})
	var t: Dictionary = versions.get("courting" if courting else "friend", versions.get("friend", {}))
	if t.is_empty():
		t = {"subject": "A letter", "salute": "Captain,",
			"body": ["I write from {place}, where you will find me if your road comes this way."],
			"sign": String(ctx.get("sender", "A friend")), "sign_title": "", "ps": ""}
	var body: Array = []
	for para in t["body"]:
		body.append(_fill(String(para), ctx))
	var seal: Dictionary = SEALS.get(candidate_id, {"mark": String(t["sign"]).left(1), "color": "8e1f17"})
	return {
		"subject": _fill(String(t["subject"]), ctx),
		"place_line": place_line(String(ctx.get("place", "")), float(ctx.get("hour", 0.0))),
		"salute": _fill(String(t["salute"]), ctx),
		"body": body,
		"sign": String(t["sign"]),
		"sign_title": _fill(String(t["sign_title"]), ctx),
		"ps": _fill(String(t.get("ps", "")), ctx),
		"seal": seal["mark"],
		"seal_color": seal["color"],
		"courting": courting,
	}


## The replies you could send to letter `key`.
static func replies(key: String) -> Array:
	return REPLIES.get(key, [])


static func reply(key: String, reply_id: String) -> Dictionary:
	for r in replies(key):
		if r["id"] == reply_id:
			return r
	return {}


## Your reply as a letter: {salute, body, close, sign, sign_title}.
static func render_reply(key: String, reply_id: String, courting: bool, ctx: Dictionary) -> Dictionary:
	var r := reply(key, reply_id)
	if r.is_empty():
		return {}
	var lines: Array = r["courting" if courting else "friend"]
	return {
		"place_line": place_line(String(ctx.get("from", "")), float(ctx.get("hour", 0.0))),
		"salute": _fill(String(lines[0]), ctx),
		"body": [_fill(String(lines[1]), ctx)],
		"close": _fill(String(lines[2]), ctx),
		"sign": PLAYER_SIGN,
		"sign_title": PLAYER_SIGN_TITLE,
	}


## "Ravensford, the fourteenth day, by lamplight". On the road it's "On the road".
static func place_line(place: String, hour: float) -> String:
	var day := int(hour / 24.0) + 1
	var nth: String = ORDINALS[day - 1] if day <= ORDINALS.size() else "%d%s" % [day, _suffix(day)]
	var h := fmod(hour, 24.0)
	var when := ""
	if h < 5.0 or h >= 20.0:
		when = ", by lamplight"
	elif h < 9.0:
		when = ", at first light"
	elif h >= 17.0:
		when = ", toward evening"
	var where := place if place != "" else "On the road"
	return "%s, the %s day%s" % [where, nth, when]


static func _suffix(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"


static func _fill(text: String, ctx: Dictionary) -> String:
	return text.replace("{place}", String(ctx.get("place", ""))).replace("{old}", String(ctx.get("old", "")))\
		.replace("{name}", String(ctx.get("name", "")))


## A settlement's name, or the id itself if it isn't one.
static func place_name(id: String) -> String:
	return String(WorldData.settlement(id)["name"]) if WorldData.SETTLEMENTS.has(id) else id
