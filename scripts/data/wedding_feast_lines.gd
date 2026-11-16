## What is said at the feast after "I do": how the night sets in, the captains' toasts
## (put together from each captain's own record, so no two companies hear the same
## speeches), the first dance, her people's custom, going round the tables (lords, her
## own people, your captains), and slipping away. Words only; the rules are in GameState
## and the social sim. {name} is the one you married, {first} the captain speaking,
## {other} a second captain, {fallen} a friend who fell, {second} who stood with you.
## Written to the voices set out at the top of wedding_lines.gd; captains speak as
## soldiers do at the fire (camp_moments.gd): short, plain, about what they've seen.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Lords = preload("res://scripts/data/lords.gd")

## How the feast sets in, by her people.
const OPEN := {
	Cultures.VARDISH: "The benches are dragged back, a second fire is lit, and a fiddle starts up before anyone has asked for one.",
	Cultures.KHARZANI: "The low table is carried out and long ones carried in. The drummers begin. The sweets come out on brass trays and wait under their cloths.",
	Cultures.RYUMON: "Paper lanterns are lit all along the rail. At the far table a verse-game has started, and somebody is losing it.",
}
## Come back to after leaving it.
const REJOIN := "The feast is still going. Your places have been kept, and so has most of a pie."
const CHIP := "The feast"
## The night moving on, under the plate: one more for each thing done.
const NIGHT := ["early yet", "the second cask is open", "the benches are pushed back",
	"the fire is banked", "the lanterns burn low"]
const PROMPT := "The night is yours"

## What the night holds, as replies.
const THINGS := {
	"toasts": {"text": "Call for the toasts.", "tag": "your captains have something to say", "icon": "cup"},
	"dance": {"text": "Ask {name} to dance.", "tag": "the first dance", "icon": "dance"},
	"tables": {"text": "Go round the tables.", "icon": "men"},
	"slip": {"text": "Slip away with {name}.", "tag": "ends the night"},
}
## The toasts with no captain to give them.
const TOASTS_NO_CAPTAINS := "a few words, and your cup"
## Her people's custom, as its reply.
const CUSTOM_THING := {
	Cultures.VARDISH: {"text": "Pay the door toll.", "tag": "her household's custom"},
	Cultures.KHARZANI: {"text": "Cap the elder's verse.", "tag": "before the sweets are served"},
	Cultures.RYUMON: {"text": "Write a wish on a lantern.", "tag": "one each, over the rail"},
}
## A thing done stays in the list, ticked, with what it was.
const DONE := {"toasts": "the toasts are made", "dance": "you danced", "custom": "done", "tables": "you went round"}
const CUSTOM_DONE := {Cultures.VARDISH: "the toll is paid", Cultures.KHARZANI: "the verse is capped", Cultures.RYUMON: "the lanterns are up"}
## The night's icons, for the closing card.
const ICONS := {"toasts": "cup", "dance": "dance", "custom": "lantern", "tables": "men"}

# ---------------------------------------------------------------- the toasts

## You call for them.
const TOAST_CALL := "Fill your cups. I'm told there are speeches."
const TOAST_CALL_ALONE := "Fill your cups."
const CALL := "Who'll speak?"
const CALL_NEXT := "Who'll speak next?"
const ENOUGH := "That's enough speeches."
const SPEAKER := {"second": "%s · your second", "captain": "%s · captain"}

## A captain's toast is three things said one after another, written to follow on: how
## they get to their feet (as your second, or by temperament: two each, by captain id),
## what they have seen of you (the first of `know` that applies), and how they raise the
## cup to her (the way their own people do).
const SECOND_OPEN := [
	"The captain asked me to stand up there today. I'd have stood there unasked.",
	"I stood beside the captain this afternoon and nobody shot at either of us. That was new.",
]
const OPENERS := {
	Captains.VENGEFUL: ["I'm bad at speeches and worse at weddings. Listen anyway.",
		"I've a short temper and a shorter speech."],
	Captains.STEADFAST: ["I'll say this plainly. It's the only way I know.",
		"I'm not one for speeches. I'll say what I've seen."],
	Captains.FRAGILE: ["I wrote this down, and now I can't read it. So I'll just say it.",
		"Give me a moment. All right."],
	"": ["I'll be short.", "Cups up. I'll be quick."],
}
## What they have seen of you: the first that applies.
const WOUNDED := "I was told to stay in my blankets with this. I've followed the captain to worse places than a feast, and in worse shape."
const SPECIALIZATION := {
	Captains.SCOUT: "I ride ahead of this company and tell the captain what's over the next hill. I never saw this coming. I'm glad I was wrong.",
	Captains.QUARTERMASTER: "I keep the company's stores. I know what the captain goes without so the rest of us don't. So tonight the captain eats first.",
	Captains.DRILLMASTER: "I teach this company to hold a line. I can teach anyone that. What it's held for, they learn from the captain.",
	Captains.CHAMPION: "I go in first. That's my place. The captain's is to go back for whoever's last, and I've never once seen it left empty.",
}
const QUIRK := {
	Captains.LUCKY: "They call me lucky. I've walked out of fights I'd no right to. I used to think that was me. It's who I follow.",
	Captains.MENTOR: "The young ones ask me what makes a captain worth following. I've stopped explaining. I point.",
	Captains.BOLD: "I've never been afraid of a charge. I was afraid for the captain today, standing up there. I needn't have been.",
}
const BATTLES_MANY := "I've followed the captain into %d battles and walked out of every one. I don't put that down to my own skill."
const BATTLES_SOME := "I've had %d battles with this company. Not many. Enough to know who I'd follow into the next."
const BATTLES_FEW := "I've not been with the company long. Long enough to see how the captain looks at the wounded, and tonight at {name}."
## How they raise it, the way it's done among their own people: three each, taken in the
## order the toasts are given, so two captains of one people don't end on the same words.
const CLOSERS := {
	Cultures.VARDISH: ["{name}: you've got the best of us. Hearth and road. Drink!",
		"{name}: keep the fire in, and we'll keep bringing the captain back to it. Drink!",
		"To {name} and the captain. Hearth and road!"],
	Cultures.KHARZANI: ["{name}: bread and salt to your house, and a long road shared. Drink!",
		"{name}: may your door stand open and your wells stay sweet. To you both.",
		"To {name} and the captain. Bread, salt, and the road home."],
	Cultures.RYUMON: ["{name}: may the page stay open and the cups stay full. To you both.",
		"{name}: I wish you a long record, and an uneventful one. To you both.",
		"To {name} and the captain. Three cups, and many after."],
}
## A hero companion speaks in their own voice (by hero id).
const HERO_TOASTS := {
	"katherine": "I was cast out of a house for holding a gate against orders. I have belonged to none since, and did not look to. Then I watched these two today. {name}, captain: whatever door you are behind, I will hold it. Drink.",
	"tariq": "The sands have no master, and neither do I. But in the dunes two riders who share one waterskin are kin, whatever their names. So drink slowly, both of you, and ride far. To {name}!",
	"mori": "My lord died at sea and left no heir. I have served no house since. Tonight I am permitted to drink to one. To {name}, and to the captain.",
}
## A bonded pair toasts together, a line each in turn (the first captain first). By bond
## rank: "A", or any other.
const PAIR_TOASTS := {
	"A": ["We couldn't agree which of us should speak.", "We can't agree on much.", "We agree on the captain.",
		"And we've both seen how the captain looks at {name}.", "So that's two things. To you both."],
	"": ["We weren't going to say anything.", "{first} said we ought to.", "I said one of us ought to.",
		"To {name} and the captain. There. That's both of us."],
}
const NEWEST := "I joined this company a few weeks back, for the pay. Nobody said there'd be a wedding. If this is what I've joined, I'm staying."
const MOURNER := "{fallen} had a toast ready for tonight and wouldn't tell me what it was. Said I'd hear it with everyone else. So drink to that one, the one we didn't hear. And to you both."

## After a toast: drink, heckle, or (after a mourner's) pour one for the fallen.
const DRINK := "Drink to that."
const DRANK := ["Cups go up the whole length of the table.", "The table drinks, and the cups come down together.",
	"Everyone drinks. Somebody starts a song and is hushed."]
const HECKLE := "Heckle {first}."
const HECKLES := ["Louder, {first}. The far tables are missing it.", "{first}, that's more than you said all last season.",
	"Sit down, {first}, before you start on a second verse."]
const COMEBACKS := {
	Captains.VENGEFUL: "I'll remember that, captain. I've a long memory, and it's a short night.",
	Captains.STEADFAST: "Noted, captain. I'll take it up with you at drill.",
	Captains.FRAGILE: "I knew it. I knew I should have let someone else go first.",
	"": "And that's the thanks I get.",
}
const HER_LAUGH := {
	"edda": "Don't. They'll expect it at every supper.",
	"farid": "Among my people that passes for affection. I see it does among yours.",
	"kaede": "I am not writing that down. I would like it noted that I was tempted.",
}
const POUR := "Pour one for {fallen}."
const POURED := "{first} fills a cup and sets it at the end of the table. It stays there, full, for the rest of the night."

# ---------------------------------------------------------------- the first dance

const DANCE_ASK := "Dance with me."
const DANCE_YES := {
	"edda": "I should warn you that I learned in a kitchen, between the table and the door. Mind the benches.",
	"farid": "There is a form for this. There are several. I would like to do none of them correctly.",
	"kaede": "I have read the steps. I am aware that is not the same as knowing them. Please be patient with the difference.",
}
## Three steps, each a pair of choices.
const DANCE_STEPS := [
	[{"id": "lead", "text": "Lead."}, {"id": "follow", "text": "Let her lead."}],
	[{"id": "turn", "text": "Turn her under your arm."}, {"id": "simple", "text": "Keep it simple."}],
	[{"id": "company", "text": "Wave the company in."}, {"id": "ours", "text": "Keep this one for the two of you."}],
]
## What she says to each.
const DANCE_ANSWERS := {
	"edda": {
		"lead": "You lead the way you march: straight on, and trust the ground. All right. I'll trust it too.",
		"follow": "I'm to steer? Then we're going round the fire twice, and past my cousin, so he sees.",
		"turn": "Nobody has spun me since I was nine. Do it again, before I remember I'm the steward.",
		"simple": "Good. I can't count steps and look at you both. I'd rather look.",
		"company": "Here they come. Your whole company dances as if it were still in column.",
		"ours": "Let them wait one song. I've waited on everyone in this hall. They can manage it once.",
	},
	"farid": {
		"lead": "You are leading with great confidence and no knowledge. I have built treaties on less. Go on.",
		"follow": "You would let me, in front of my aunts? Then turn left. They will talk of nothing else for a year.",
		"turn": "You practised that. No, do not deny it. I am touched, and I am going to tell everyone.",
		"simple": "Yes. Simply. I have had enough of doing elaborate things well.",
		"company": "Look at them. Not one of them knows the form. It is the best circle I have ever stood in.",
		"ours": "One song that is nobody's business but ours. I did not know to ask for that. Thank you.",
	},
	"kaede": {
		"lead": "Left. Your other left. No, keep going. I would rather follow you wrong than stop.",
		"follow": "Then I shall count aloud. It is the only way I know. One. Two. You may smile; I can see that you want to.",
		"turn": "I did not know that was permitted. Do it again, please. I wish to be sure of what happened.",
		"simple": "Good. I would like to remember this one step at a time.",
		"company": "It is a mess now. I find I like it. That is two preferences in one day.",
		"ours": "Only us, for this one. I would like there to be one thing tonight that has no witnesses.",
	},
}

# ---------------------------------------------------------------- her people's custom

## {intro: [narration], prompt, choices: [{id, text, tag, bare, line, needs}], after
## (narration once it's done), after_her (what she says of it)}. A choice that `needs`
## "second" is offered only with someone beside you; its "alone" variant otherwise.
const CUSTOMS := {
	Cultures.VARDISH: {
		"intro": ["Her household has barred the hall door with a bench. It is the custom in the north: nobody who marries into the house goes through that door until the toll is paid.",
			"The cook stands in front of it, red-eyed, arms folded, and names the price."],
		"prompt": "Pay the toll",
		"choices": [
			{"id": "coin", "text": "Pay in coin.", "tag": "a silver penny", "bare": true,
				"line": "You set a silver penny on the bench. The cook looks at it for a long moment, puts it away somewhere safe, and lifts the bench alone."},
			{"id": "song", "text": "Pay with a song.", "tag": "you know one verse", "bare": true,
				"line": "You sing the one verse you know. The household comes in on the second, which you don't, and carries it. The bench is lifted before the end."},
			{"id": "wrestle", "text": "Send {second} to arm-wrestle the cook.", "tag": "for the company's honour", "bare": true, "needs": "second",
				"line": "{second} rolls up a sleeve. It takes a long minute, and the table creaks. Neither will say afterwards who won. The bench is moved.",
				"alone": {"text": "Arm-wrestle the cook yourself.", "tag": "for your own honour",
					"line": "You roll up a sleeve. The cook lets you win, slowly enough for everyone to see it being allowed, and lifts the bench."}},
		],
		"after": "The cook kisses {name} on the forehead, says nothing to you at all, and goes back to the kitchen.",
	},
	Cultures.KHARZANI: {
		"intro": ["The sweets stay under their cloths until the one who has married into the house caps an elder's verse. The eldest aunt stands, and the courtyard quiets.",
			"\"The rose is shy before the dawn, and opens only once...\""],
		"prompt": "Cap the verse",
		"choices": [
			{"id": "good", "text": "...and once is all the garden needs, if the gardener is true.", "tag": "a good line",
				"line": "A murmur goes round the courtyard. The aunt inclines her head by a finger's width and sits, and the cloths come off the trays."},
			{"id": "terrible", "text": "...unlike my horse, who opens every gate he sees.", "tag": "a terrible line",
				"line": "Silence. Then the aunt laughs until she has to be helped to her seat, and the cloths come off the trays."},
			{"id": "whisper", "text": "Let {second} whisper you the line.", "tag": "{second} has one ready", "bare": true, "needs": "second",
				"line": "{second} leans in, and you say it word for word. It is very good. The aunt studies {second} for some time, and the cloths come off the trays.",
				"alone": {"text": "Let {name} whisper you the line.", "tag": "she has one ready",
					"line": "{name} gives it to you behind her sleeve. The aunt chooses not to have seen, and the cloths come off the trays."}},
		],
		"after_her": "My aunt approves of you. She will deny it by morning, so remember that you saw it.",
	},
	Cultures.RYUMON: {
		"intro": ["Paper lanterns and brushes are passed along the tables. Each of you writes one wish, lights it, and lets it go over the rail.",
			"{name} writes hers without stopping to think, and shields it with her sleeve."],
		"prompt": "What do you wish for?",
		"choices": [
			{"id": "her", "text": "For her.", "tag": "you write her name", "bare": true,
				"line": "You write her name and nothing after it. The two lanterns go up side by side, and keep rising after you can no longer tell which is which."},
			{"id": "company", "text": "For the company.", "tag": "every one of them home", "bare": true,
				"line": "You write: every one of them home. Your captains watch that lantern until it is gone, and for a while after."},
			{"id": "peace", "text": "For an end to the war.", "tag": "the largest wish", "bare": true,
				"line": "You write it small, because it is large. The two lanterns rise together into the dark."},
		],
		"after_her": "I will not tell you what I wrote. A wish is not a record. It does not have to be shown to be kept.",
	},
}

# ---------------------------------------------------------------- round the tables

const TABLES_OPEN := "You go round the tables with a cup that is never allowed to stay empty."
const TABLES_PROMPT := "Who do you stop with?"
const TABLES_BACK := "Back to the feast."
const TABLE_TAGS := {"host": "the host", "crown_lord": "your lord", "lord": "a friend of the company", "captain": "captain"}
const TABLE_ROLES := {"host": "host", "crown_lord": "your lord", "captain": "captain", "lord": "guest"}
## A lord, by bearing: warm when they think well of you (Regard of LORD_WARM or more).
const LORD_WARM := 30
const LORD_LINES := {
	Lords.CAUTIOUS: {"warm": "A sound match. I looked for the weakness in it and found none. I looked twice.",
		"cool": "My congratulations. I shall be watching how the pact holds."},
	Lords.DARING: {"warm": "I had money on you running for the hills, captain. I have never been so glad to pay.",
		"cool": "A handsome wedding. Not enough horses in it, but handsome."},
	Lords.HONORABLE: {"warm": "You kept faith with her house before there was anything in it for you. I'll remember that when you need a friend.",
		"cool": "My congratulations, captain. Keep your oaths, and you and I will have no quarrel."},
	Lords.CRUEL: {"warm": "You have married into walls and a garrison. Sensible. I hope you are fond of her as well.",
		"cool": "Enjoy the night, captain. There are not many like it in a war."},
}
## The host, the head of her house, by bearing: a word about her, since they know her.
const HOST_TABLE := {
	Lords.CAUTIOUS: "{name} has served this house better than it has served her. I know it. I mean to do better by you both.",
	Lords.DARING: "I chose your gift myself. {name} would have given you something sensible, and one of us had to be extravagant.",
	Lords.HONORABLE: "You are of this house now, captain. That is no courtesy. If you are in need, send to me.",
	Lords.CRUEL: "{name} is the only one of my kin who has never asked me for anything. See that she never has to.",
}
## Her own people, who have come to see it: each is someone she told you about. {id, name,
## tag, line}.
const HER_PEOPLE := {
	"edda": [
		{"id": "cousin", "name": "Edda's cousin", "tag": "the one with the speech",
			"line": "I had a speech. She allowed me a minute and I took two. I've known her all her life, and that's the first time she has let me. You'll do, captain."},
		{"id": "cook", "name": "The cook", "tag": "red-eyed",
			"line": "She has fed this whole house since she was tall enough to see over the table, and never once sat down first. See that she sits down."},
	],
	"farid": [
		{"id": "aunt", "name": "Farah's aunt", "tag": "of Crooked Lantern",
			"line": "I sent a letter of hers back unopened once. It was addressed like a tax demand. Today she has looked like my niece from morning to night. Keep her that way."},
		{"id": "cousin", "name": "Farah's cousin", "tag": "who asked if she was happy",
			"line": "I asked her once if she was happy. She took two pages to tell me the roads were safe. Last month she wrote again. One line. I have it with me."},
	],
	"kaede": [
		{"id": "teacher", "name": "Kaede's teacher", "tag": "who asked who the record was for",
			"line": "I taught her to leave nothing out of a record. Then I spent ten years teaching her that she was allowed to be in one. Today she is in one. I am content."},
		{"id": "ferryman", "name": "The old ferryman", "tag": "a witness",
			"line": "I was asked to witness. I charge for remembering, as a rule. This one I'll remember free."},
	],
}
## A captain who didn't toast, by temperament.
const CAPTAIN_LINES := {
	Captains.VENGEFUL: "Anyone who spoils tonight answers to me. I've told the whole company. Twice.",
	Captains.STEADFAST: "A good day, captain. Eat something. You've been on your feet since dawn.",
	Captains.FRAGILE: "I cried at the vows. I thought nobody saw. Everybody saw.",
	"": "Congratulations, captain. The company's glad of it. You should hear them at the far table.",
}
## The gifts, as words: the host's, by her people, the absent ruler's, and the company's.
const GIFTS_TITLE := "The gifts"
const HOST_GIVES := "%s gives you %s."
const RULER_SENT := "%s sent %s."
const STAYED_AWAY := "%s stayed away: %s."
const HOST_GIFTS := {
	Cultures.VARDISH: "a pair of good grey horses",
	Cultures.KHARZANI: "a carpet that took two years to weave",
	Cultures.RYUMON: "a sword rack of black lacquer",
}
const COMPANY_GIFT := "The company passed a helmet round and bought you a copper kettle. It has a dent. They say it came like that."
const RECEIPT := "%s wrote down who gave what, and how little."

# ---------------------------------------------------------------- slipping away

const SLIP_YOU := "Come away. They won't miss us for a while."
const SLIP_OUT := {
	"room": "You go up the back stair to her room. Below, the feast goes on without you, and does not seem to mind.",
	"place": "You walk out past the last of the lanterns. Behind you the feast goes on, and does not seem to mind.",
}
## What she recalls of the night: the first of these that you did (see recall).
const RECALL_ORDER := ["breath", "heckle", "dance", "custom", "vow"]
const RECALL := {
	"edda": {
		"breath": "You took a breath before you said it. I watched you take it. I'd have waited longer than that, you know. I've had the practice.",
		"heckle": "You heckled your own captain at your own wedding, and the whole hall loved you for it. I've been trying to win that hall for ten years.",
		"dance": "I didn't count the steps. Not one of them. I want that known.",
		"custom": "The cook let you through. She has turned two of my cousins' suitors back from that bench.",
		"vow": "I heard every word of your vow. I'm not going to say it back to you. I'm going to keep it.",
	},
	"farid": {
		"breath": "You took a breath. In the length of it I prepared three replies to a refusal. I am pleased to have wasted the work.",
		"heckle": "You heckled your own captain, and they adored you for it. I have spent my life choosing words nobody could mind. I should like to learn the other way.",
		"dance": "We did none of the forms. My feet have never been so badly instructed, or so happy.",
		"custom": "My aunt has asked three people about you since the verse. She only asks about people she means to keep.",
		"vow": "I have heard a great many promises read aloud. Yours is the first I did not check for the clause that undoes it.",
	},
	"kaede": {
		"breath": "You paused before you answered. One breath. I did not mind. I would like you always to take the time you need before you say a thing to me.",
		"heckle": "You shouted at your own captain, and everyone laughed. I have noted that it was affection. I had to ask someone.",
		"dance": "I lost count at the second turn of the dance, and did not start again. That has not happened before.",
		"custom": "I watched your lantern longer than my own. I do not know what you wrote. I find I can leave it unknown.",
		"vow": "I remember your vow word for word. I am not going to write it down. I want to find out whether I can keep a thing without paper.",
	},
}
## The last choice of the night, and what she says to it.
const LAST := [
	{"id": "stay", "text": "Stay up until the lanterns go out."},
	{"id": "sleep", "text": "Sleep. The war will keep."},
]
const LAST_ANSWER := {
	"edda": {"stay": "All of them? Then sit. I've nothing to see to, and I mean to enjoy that for as long as it lasts.",
		"sleep": "Sleep, then. I've set two places for the morning. I counted myself first."},
	"farid": {"stay": "Until the last one. I will tell you unimportant things, and you need not answer any of them.",
		"sleep": "The war will keep. For one night I am carrying nobody's message. Not even my own."},
	"kaede": {"stay": "Then I will name them for you as they go out. There are forty-one. I may lose count. I do not mind if I do.",
		"sleep": "Sleep. I will leave the lamp lit. Tonight it may be a symbol."},
}
const BACK_TO_MAP := "Back to the map"

## The closing card.
const CARD := {
	"memory": "A memory kept. Open it again from %s's page.",
	"pact": "The marriage pact",
	"together": "%s and your company stand together.",
	"breaks": "Attacking %s breaks it.",
	"lands": "her house's lands",
	"ask": "Ask %s for up to %d silver every %d days, for men from the garrison, or to hold a place for you.",
	"head": "the head of the house",
	"captains": "Your %d captain%s drank to you, and will say so for a month.",
	"gift": "%s's gift, %s, is in your baggage.",
}

## At the fire, a few nights on.
const CAMP_TITLE := "Still telling it"
const CAMP_RETELL := "%s is telling the wedding again at the fire. The toast has grown a verse since last night."
const CAMP_DAYS := 7


static func fill(text: String, ctx: Dictionary) -> String:
	var out := text
	for k in ctx:
		out = out.replace("{%s}" % k, String(ctx[k]))
	return out


## A captain's toast in their own words: how they start (as your second, or by
## temperament), what they have seen of you (wounded tonight, their role, their quirk,
## their battles), and how they raise it (the way their own people do; `nth` is how many
## toasts came before, see CLOSERS).
static func captain_toast(c: Dictionary, as_second: bool = false, nth: int = 0) -> String:
	var id := int(c.get("id", 0))
	var opens: Array = SECOND_OPEN if as_second else OPENERS.get(String(c.get("temperament", "")), OPENERS[""])
	return "%s %s %s" % [String(opens[posmod(id, opens.size())]), know(c), closer(c, nth)]


## How a captain raises the cup: their own people's words, the `nth` of them in turn.
static func closer(c: Dictionary, nth: int = 0) -> String:
	var lines: Array = CLOSERS.get(String(c.get("culture", "")), CLOSERS[Cultures.VARDISH])
	return String(lines[posmod(nth, lines.size())])


## What a captain has seen of you: the first that applies.
static func know(c: Dictionary) -> String:
	if int(c.get("wounded", 0)) > 0:
		return WOUNDED
	var spec := String(c.get("specialization", ""))
	if SPECIALIZATION.has(spec):
		return String(SPECIALIZATION[spec])
	var quirk := String(c.get("quirk", ""))
	if QUIRK.has(quirk):
		return String(QUIRK[quirk])
	var n := int(c.get("battles", 0))
	if n >= 10:
		return BATTLES_MANY % n
	if n >= 3:
		return BATTLES_SOME % n
	return BATTLES_FEW


## A toast (one of GameState.wedding_toasters) as the lines said: [{who ("a", or "b" for
## a pair's second captain), text}], before {name} is filled in. `nth` is how many toasts
## came before it.
static func toast_lines(t: Dictionary, nth: int = 0) -> Array:
	var c: Dictionary = t["captain"]
	var first := String(c.get("first", c.get("name", "")))
	var own := String(HERO_TOASTS.get(String(c.get("hero_id", "")), "")) if bool(c.get("is_hero", false)) else ""
	match String(t.get("kind", "")):
		"second":
			return [{"who": "a", "text": own if own != "" else captain_toast(c, true, nth)}]
		"hero":
			return [{"who": "a", "text": own if own != "" else captain_toast(c, false, nth)}]
		"pair":
			var other: Dictionary = t.get("other", {})
			var lines: Array = PAIR_TOASTS.get(String(t.get("rank", "")), PAIR_TOASTS[""])
			var out := []
			for i in lines.size():
				out.append({"who": "a" if i % 2 == 0 else "b",
					"text": fill(String(lines[i]), {"first": first, "other": String(other.get("first", other.get("name", "")))})})
			return out
		"newest":
			return [{"who": "a", "text": "%s %s" % [NEWEST, closer(c, nth)]}]
		"mourner":
			return [{"who": "a", "text": fill(MOURNER, {"fallen": String(t.get("fallen", ""))})}]
	return [{"who": "a", "text": captain_toast(c, false, nth)}]


## The host's word at the tables, by bearing (before {name} is filled in).
static func host_table(bearing: String) -> String:
	return String(HOST_TABLE.get(bearing, HOST_TABLE[Lords.HONORABLE]))


## A lord's word at the tables, by bearing and how well they think of you.
static func lord_line(bearing: String, regard: int) -> String:
	var lines: Dictionary = LORD_LINES.get(bearing, LORD_LINES[Lords.HONORABLE])
	return String(lines["warm" if regard >= LORD_WARM else "cool"])


static func captain_line(temperament: String) -> String:
	return String(CAPTAIN_LINES.get(temperament, CAPTAIN_LINES[""]))


## Her own people at the tables (see HER_PEOPLE).
static func her_people(cand: String) -> Array:
	return HER_PEOPLE.get(cand, [])


static func custom(culture: String) -> Dictionary:
	return CUSTOMS.get(culture, CUSTOMS[Cultures.VARDISH])


## The custom's choice with `id` as it was offered: with someone beside you (`second` is
## true) or alone. {} if there's no such choice.
static func custom_choice(culture: String, id: String, second: bool) -> Dictionary:
	for ch in custom(culture)["choices"]:
		if String(ch["id"]) != id:
			continue
		var out: Dictionary = (ch as Dictionary).duplicate()
		if String(ch.get("needs", "")) == "second" and not second:
			out.merge(ch.get("alone", {}), true)
		return out
	return {}


## What she recalls of the night: the first of RECALL_ORDER that `did` holds (true).
static func recall(cand: String, did: Dictionary) -> String:
	var lines: Dictionary = RECALL.get(cand, RECALL["edda"])
	for k in RECALL_ORDER:
		if bool(did.get(k, false)):
			return String(lines[k])
	return String(lines["vow"])
