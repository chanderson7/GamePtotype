## What is said at the ceremony: how the day opens at the place, who stands with you, the
## head of her house on how you came to be standing there, her vow (from a time you
## shared, when there is one) and what she says of what you did for her people, the vows
## you can say and her answer to each, her people's rite a step at a time, the question and
## both answers, and the private vows by one candle. The feast after is in
## wedding_feast_lines.gd. Words only; the rules are in the social sim and GameState.
## {name} is the one you marry, {place} the place, {host} who hosts, {second} who stands
## with you.
##
## How it is written. The day follows a courtship the player has read (romance_stories.gd,
## personal_conversations.gd), and is written to the same voices:
##   Narration: second person, present tense, what can be seen and heard. It doesn't joke.
##   Edda: dry and practical; she manages things rather than say what she feels, and when
##     she does say it, it is one plain sentence that she lets stand.
##   Farah: composed, whole sentences, the language of treaties turned on small things;
##     when she means it the sentence gets short.
##   Kaede: exact, few contractions; she settles a detail before she admits a feeling, and
##     states a preference as a deliberate act.
## Each of them is funny once in a beat, not in every line, and the vows, the answer and
## the last words of the night are meant. Nobody is called bride or groom, and a lord is
## never "he" or "she": the captain and the lords are whoever the player's game made them.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Lords = preload("res://scripts/data/lords.gd")

## Told when there is no wedding to open here.
const NOTHING := {
	"no_one": "No one is waiting here.",
	"faded": "That memory has faded.",
	"not_ready": "The wedding isn't ready here yet.",
}

## How the day opens: the place, by whose it is ("hers", "yours", "other"), then what her
## people have set out for the rite.
const ARRIVAL := {
	"hers": "{place} has turned out for it. Her house's banner hangs over the gate with your company's beside it, a little crooked. Nobody has straightened it.",
	"yours": "{place} is yours, and tonight her house's banner hangs beside your own over the gate. Her household arrived two days ago and has run the place since.",
	"other": "{place} has lent its square for the evening. Her household has filled one side of it and your company the other, and the town leans from its windows to look at both.",
}
const ARRIVAL_SET := {
	Cultures.VARDISH: "The hearth-fire has been carried out from the hall in an iron basket. A red cord lies coiled beside it, and the cook is already crying.",
	Cultures.KHARZANI: "The lamps along the walls are lit before the light has gone. On a low table between her family and your company are a loaf, a dish of salt, and a contract in a hand you know.",
	Cultures.RYUMON: "Three cups stand in a row on a lacquer table. Beside them the register lies open at a clean page, with a brush laid across it.",
}

## Her first words to you.
const STAND := {
	"edda": "I've seen to the benches, the cord and the cook. There is nothing left to see to, which I'm told is the point. Come and stand by me.",
	"farid": "Everyone has asked which courtesy we will use today. I told them ours. We do not have one yet. Stand here, and we will find out what it is.",
	"kaede": "I watched the road from the gate this morning. For the record, I was not keeping one. Stand here, please. I would like to stop watching the road.",
}
## The quiet way on between beats (a tap anywhere does it too).
const GO_ON := "Go on"
const BEGIN := "Take your place beside {name}."
const BEGIN_TAG := "the wedding begins"
const NOT_YET := "Not yet"
const NOT_YET_TAG := "it waits while you're in {place}"

## Asked who stands with you.
const SECOND_PROMPT := "Who stands with you?"
const SECOND_NONE := "No one. Just the two of us."
## Your second takes their place, by what they are to you.
const SECOND_STANDS := {
	"longest": "{second} takes the place at your shoulder without being shown where it is.",
	"hero": "{second} steps up beside you. The talk in the crowd drops for a moment, and then comes back.",
	"bonded": "{second} steps up beside you, and looks back once at the friend left in the crowd.",
	"newest": "{second} steps up beside you, stands very straight, and does not know what to do with either hand.",
}
## Who hands you what the rite needs.
const SECOND_HANDS := {
	Cultures.VARDISH: "{second} takes the cord from beside the fire and holds it ready.",
	Cultures.KHARZANI: "{second} is given the salt to hold, and holds it in both hands.",
	Cultures.RYUMON: "{second} sets the three cups straight, though they were straight, and steps back.",
}
## What your second says under their breath before the question, by temperament.
const SECOND_WHISPER := {
	Captains.VENGEFUL: "If your knees go, captain, fall my way. I'll say you were pushed.",
	Captains.STEADFAST: "Steady, captain. You've given harder orders than this one.",
	Captains.FRAGILE: "Don't look at me, captain. If you look at me I'll cry, and then we're both lost.",
	"": "Breathe, captain.",
}
const UNDER_BREATH := "%s · under their breath"

## The old words, said over you both: by the head of her house, or (when they couldn't
## come) by an elder of the place.
const OLD_WORDS := "{host} says the old words over you both, and steps back."
const OFFICIANT := "An elder of {place} says the old words over you both, and steps back."
## Before the old words, the head of her house on how you come to be standing here: by
## what you said in their council (chapter 4), "" when the book no longer says. They are
## the one you compromised with, stood against, or sided with and then made it right.
const HOST_WORD := {
	"edda": {
		"negotiate": "This captain stood in my hall and gave me half of what I asked for. The valley is still standing. I have stopped asking for the other half.",
		"support_edda": "This captain stood against me in my own hall. I was angry for a season. Nobody raided the valley that season, and I can count.",
		"repair_promise": "This captain broke faith in my hall to please me, and then paid to mend it. The second pleased me less. I have thought about it more.",
		"": "This house does not give its people away lightly. It is giving one today, and gladly.",
	},
	"farid": {
		"negotiate": "This captain told my council that both houses would keep their dignity. We had not asked for that. We find that we like it.",
		"support_edda": "This captain held this house to a promise Farah made, in front of all of us. Some of us have forgiven it. I am told that is enough for a wedding.",
		"repair_promise": "This captain took our side against Farah once, and then paid for the convoy it cost. We remember the first. She tells us to remember the second.",
		"": "This house has sent Farah to speak for it in every court on the sea. Today she speaks for herself, and we have come to listen.",
	},
	"kaede": {
		"negotiate": "This captain asked our council for a small covenant. It is still standing. We have signed larger things that are not.",
		"support_edda": "This captain told our council that Kaede would not certify a convenient thing. She did not. The record is better for it. So, I am told, are we.",
		"repair_promise": "This captain asked Kaede to sign our version, and then took it back in front of us all. The retraction is in the record. So is today.",
		"": "Kaede has kept this house's record since she could hold a brush. Today the house keeps hers.",
	},
}
const HOST_ROLE := "%s · host"

## Before her vow, what she says of what you did for her people (chapter 3's task); nothing
## when the book no longer says.
const THEIR_ROAD := {
	"edda": {
		"fund_muster": "You paid for a muster to stand over villages you had never seen, and you made no speech about it.",
		"defend_district": "You held the valley when my own hall was telling me to be reasonable.",
		"correspondence": "You carried my letters to three houses and brought back three answers, and there was nothing in any of them for you.",
	},
	"farid": {
		"fund_muster": "You paid for an escort that wore neither house's seal, so that grain could move and nobody had to bow.",
		"defend_district": "You took the first wagons through the crossing yourself, when every sensible voice said to wait.",
		"correspondence": "You carried one letter to two doors and did not improve a word of it.",
	},
	"kaede": {
		"fund_muster": "You paid for a watch drawn from two villages that did not trust each other's copy of anything.",
		"defend_district": "You held the ford until the last witness had crossed and spoken.",
		"correspondence": "You brought me three copies that agreed by accident, and never asked which I wanted to be true.",
	},
}

## Her vow, from a time you shared (by visit scene): what that visit was about, promised.
const VOWS := {
	"edda_spare_spoon": "All my life I've set a place for whoever might come, and forgotten my own. You put a spoon down for me. So: I will sit at my own table, beside you, and we'll keep the spare place for whoever comes late.",
	"edda_wrong_verse": "I only ever wrote down the respectable version of things. You get the other one: the foolish songs, the wrong last verse. I promise to get things slightly wrong beside you for as long as you'll sing along.",
	"edda_boots_by_door": "I know what it is to wait by a door for someone who is busy with other people's roofs. I won't promise never to be late. I promise that whichever of us is waiting, the other one comes home.",
	"edda_morning_unclaimed": "You asked me what I'd do with a morning that needed nothing from me. It was the hardest question I'd had in years. I promise you mornings like that. Not many; I know myself. But some, and every one of them yours.",
	"edda_ledger_blot": "I keep a page with a blot on it, because a mended thing should show where it was mended. We'll make mistakes, the two of us. I promise not to copy them out clean. I'll mend them where you can see, and keep the page.",
	"edda_place_no_task": "I used to think I had to be useful to be worth someone's afternoon. You came with no errand, and stayed. I promise to sit with you with nothing to offer but that, and to believe you when you say it's enough.",
	"farid_supper_request": "I was trained to ask for a cup of water in language fit to end a siege. So hear how short I can make this. I want to be married to you. I am asking for nothing else.",
	"farid_two_street_names": "Where I was born every street has the name on the sign and the name people use. I promise you the second kind: directions that bring you home, whatever the sign says. Follow the bread. I will be where it leads.",
	"farid_unsealed_letter": "My cousin asked me once if I was happy, and it took me two pages not to answer. I promise you the short answer, every time you ask. Today it is yes. Only yes.",
	"farid_wrong_courtesy": "I once carried a host a gift so grand that she had to hand me a towel to end the evening. I have not forgotten which of those was the kindness. I promise you fewer ceremonies and more dishes dried. You will always matter to me more than the welcome.",
	"farid_own_answer": "A useful answer belongs to everyone it helps, and I have given those all my life. This one is mine. I love you. It serves no house and settles no dispute. I promise to go on giving you that kind.",
	"farid_no_reply_required": "I promise to bring you everything unimportant: the dog with the loaf, the baker's cat, whatever I see that I want you to see. You need never answer. I only want you to be the first to hear it.",
	"kaede_useless_map": "Official maps explain how to reach an obligation. Mine explain why I might stay. I promise to keep drawing you into the second kind, and to tell you, in words, when I would like you to stay.",
	"kaede_bad_mystery": "With real evidence I will always be careful. I promise you the other thing as well: an evening, a bad book, and the two of us wrong about the cabinet. I had not known I wanted a second person in the inquiry. I do.",
	"kaede_margin_name": "There is a name I was called as a child that I have not told you. You said another day would be enough, and meant it. I promise that the day will come, and that you are the only one I will tell.",
	"kaede_missing_street": "I used to correct the map every time the street changed. Now I date each drawing and keep them all. I promise to do the same with us. You will change, and so will I, and none of the days will be an error.",
	"kaede_kept_page": "I once left the only thing that mattered out of a record because it belonged to no one but me. I will not do that today. I was here. I chose this. I am glad. I promise to go on writing it in the first person.",
	"kaede_room_on_map": "I left a space on a map for you once, and did not fill it while I waited. I promise always to leave you one. I will ask where you would sit, and I will not answer for you.",
}
## Her vow when no shared time has a vow of its own.
const VOW_DEFAULT := {
	"edda": "I keep the tallies of a household that has never once balanced, and I've stopped minding. I promise you the same patience, and a place at the table that is yours whether or not you're on time for it.",
	"farid": "I have drafted agreements for half the houses on this sea, and I wanted to win every one. I do not want to win this. I promise to keep it instead.",
	"kaede": "Records outlast the people in them. I would like ours to say that we were happy, and I promise to do what is needed to make that accurate.",
}
const REMEMBERS := "She remembers: %s"

## What you can say: three vows for each of them, none of them wrong.
const VOW_PROMPT := "Your vow. None of them is wrong."
const YOURS := {
	"edda": [
		{"id": "promise", "text": "Wherever the war takes the company, there's one road I know by heart, and it ends at your door. I'll walk it every time I can.", "tag": "a promise"},
		{"id": "honest", "text": "I can't promise you a quiet life. I can promise you won't carry the valley alone again.", "tag": "the plain truth"},
		{"id": "laugh", "text": "I'll learn every cousin's name, and who owes whom a horse. Give me a year or two.", "tag": "to make her laugh"},
	],
	"farid": [
		{"id": "promise", "text": "However many borders close, I'll find the road that's open and take it back to you.", "tag": "a promise"},
		{"id": "honest", "text": "I've no gift for speeches. I'll say things badly, and too short, and I'll mean them.", "tag": "the plain truth"},
		{"id": "laugh", "text": "I'll learn the courtesies. The short ones. Start me on the one for soup.", "tag": "to make her laugh"},
	],
	"kaede": [
		{"id": "promise", "text": "Put it in the record: I'll come back. Every time. Hold me to the page.", "tag": "a promise"},
		{"id": "honest", "text": "I don't know how long the war lasts. I know where I'll be standing when it's over, if you'll have me there.", "tag": "the plain truth"},
		{"id": "laugh", "text": "I promise never to correct your maps. Not even the one with the cat.", "tag": "to make her laugh"},
	],
}
## Her face answers the vow you say (by its id in YOURS), and then she does.
const VOW_FACE := {"promise": "warm", "honest": "neutral", "laugh": "amused"}
const VOW_ANSWER := {
	"edda": {
		"promise": "Then I'll stop counting the days you're gone and count the ones you're home. It's the shorter column. I mean to lengthen it.",
		"honest": "That's a smaller promise than people make at weddings. It's the one I wanted.",
		"laugh": "Two, at least. And you'll still get the horse wrong. Stand closer.",
	},
	"farid": {
		"promise": "I have kept roads open for strangers for years. It is a new thing to have one kept for me. Thank you.",
		"honest": "Short, and meant. You have described the only kind of sentence I trust.",
		"laugh": "It is five words long. I will teach you tonight. Do not let my aunts see how quickly you learn.",
	},
	"kaede": {
		"promise": "I will enter it. I do not usually record promises; they are not yet facts. I am making an exception, on the evidence so far.",
		"honest": "That is an honest blank. I can keep one of those. I will keep the place beside it, too.",
		"laugh": "The cat's attendance is uncertain. Yours I intend to rely on.",
	},
}

## Each culture's rite, a step at a time: plain steps you do, then a choice that is kept.
## {intro, steps: [{id, text, tag, line}], prompt, choices: [{id, text, tag, bare, line}],
## after (narration once the choice is made, optional)}.
const RITE_STEPS := {
	Cultures.VARDISH: {
		"intro": "The Vardish rite is short. A red cord is passed through the smoke of the hearth-fire and wound once round both your wrists, and the knot is tied where everyone can see it.",
		"steps": [
			{"id": "wrist", "text": "Hold out your wrist.", "tag": "over the hearth-fire",
				"line": "You hold your wrist over the fire. The cord comes through the smoke and is laid across it, warm, smelling of pine."},
			{"id": "wind", "text": "Wind it once.", "tag": "round both your wrists",
				"line": "{name} lays her wrist against yours, and you wind the cord once round both. Her pulse is quicker than her face admits."},
		],
		"prompt": "The knot",
		"choices": [
			{"id": "she_ties", "text": "Hold still while she ties it.", "tag": "her knot", "bare": true,
				"line": "{name} ties it one-handed, quickly: the knot she uses on grain sacks. She tests it twice. It will not come undone by itself."},
			{"id": "together", "text": "Tie it together.", "tag": "an end each", "bare": true,
				"line": "You take one end and she takes the other. It takes three tries and comes out lopsided. {name} looks at it, and leaves it exactly as it is."},
		],
	},
	Cultures.KHARZANI: {
		"intro": "The Kharzani rite is done before witnesses from both houses. Bread is broken, salted and shared, and then the contract is read aloud, every clause.",
		"steps": [
			{"id": "bread", "text": "Break the bread.", "tag": "before both houses",
				"line": "The loaf breaks unevenly, and you are holding the larger half. Along the wall an old woman nods, as if that settles something."},
			{"id": "salt", "text": "Salt it, and give her the first piece.", "tag": "the first piece is hers",
				"line": "You salt a piece and hold it out. {name} eats it and salts one for you, and for the length of a mouthful neither side has anything to object to."},
		],
		"prompt": "The contract is read aloud. One clause is left for you to add.",
		"choices": [
			{"id": "door", "text": "The door is never barred to the other, whatever the hour.", "tag": "a clause for home",
				"line": "{name} writes it in herself, and reads it back under her breath, once, to hear how it sounds."},
			{"id": "letters", "text": "Every letter is answered, however short the answer.", "tag": "a clause for the road",
				"line": "{name} writes it in. After \"however short\" she adds two words in the margin: \"especially then.\""},
			{"id": "supper", "text": "No request for supper shall exceed five words.", "tag": "the soup clause",
				"line": "{name} laughs before she can stop herself, in front of both houses. She counts the clause on her fingers, finds eight words, and writes it in as it stands."},
		],
		"after": "The reading comes to the last clause: the one {name} wrote herself and showed to nobody. It is one word long, and it is read out to both houses. \"Yes.\"",
	},
	Cultures.RYUMON: {
		"intro": "The Ryumon rite is three cups and three sips from each, taken without a word. Then both names are written in the register, and the page is witnessed.",
		"steps": [
			{"id": "cup1", "text": "The first cup: for what was.", "tag": "three sips",
				"line": "Three sips. It is sharp, and then warm. {name} watches you over the rim of hers."},
			{"id": "cup2", "text": "The second: for what is.", "tag": "three sips",
				"line": "Three sips. It is quiet enough to hear the lanterns move on their strings."},
			{"id": "cup3", "text": "The third: for what will be.", "tag": "three sips",
				"line": "Three sips. The cups are turned down, and the brush is held out to you handle first."},
		],
		"prompt": "How do you sign the register?",
		"choices": [
			{"id": "plain", "text": "Plainly.", "tag": "your name, nothing more", "bare": true,
				"line": "You write your name. {name} writes hers beside it, closer than the ruled column allows, and does not correct it."},
			{"id": "company", "text": "With the company's name under it.", "tag": "the company signs too", "bare": true,
				"line": "You write your name, and the company's beneath it. That is not the form. {name} blots it herself, so that it stands."},
			{"id": "her", "text": "Give her the brush.", "tag": "her hand, your name", "bare": true,
				"line": "{name} writes your name as though she has written it before. She has. You can tell by the third stroke."},
		],
	},
}

## The question, in her people's words: asked of her, then of you.
const QUESTION_CHIP := "The question"
const QUESTION := {
	Cultures.VARDISH: {"her": "{name}. Will you have this one, at the hearth and on the road?",
		"you": "Captain. Will you have {name}, at the hearth and on the road?"},
	Cultures.KHARZANI: {"her": "Before these witnesses and by this contract: {name}, do you consent?",
		"you": "Before these witnesses and by this contract: captain, do you consent?"},
	Cultures.RYUMON: {"her": "{name}. Is it your will that these names stand together?",
		"you": "Captain. Is it your will that these names stand together?"},
}
## Among the Kharzani she is asked three times and answers the third: the first asking is
## her family's, the second the witnesses', and the third her own.
const ASKED_AGAIN := {
	Cultures.KHARZANI: ["{name} says nothing. The first asking is for her family to hear.",
		"Nothing again. The second is for the witnesses. The third is hers."],
}
## When no lord hosts, the elder asks it.
const ELDER_ASKS := "The elder turns to {name} and asks it, in her people's words."
## Her answer.
const ANSWER := {
	"edda": "I do. I started a list of reasons this morning, and stopped at one. I do.",
	"farid": "I do. That is my own answer. Nobody drafted it for me.",
	"kaede": "I do. I have not checked it against anything. I find I do not need to.",
}
const I_DO := "I do."
const I_DO_TAG := "hold it, or just say it"
## "Take a breath": nobody moves. Your second mutters (or, with no one beside you, the
## place waits), and she waits in her own way.
const BREATHE := "Take a breath."
const BREATH := "Nobody moves."
const BREATH_SECOND := "Captain. That was the question."
const BREATH_ALONE := "Somewhere behind you a cup is set down, very carefully."
const BREATH_HER := {
	"edda": "Edda does not prompt you. She waits with her hands still, as if she had all evening.",
	"farid": "Farah's face does not change. One finger taps the contract, once, where your name is.",
	"kaede": "Kaede holds the brush where it is, a drop of ink gathering at its tip, and does not let it fall.",
}
## The moment it's said: the seal, in one line.
const MARRIED := "Married"
const SEAL := {
	Cultures.VARDISH: "The ends of the cord are cut and thrown on the fire. The knot stays on your wrists, and the yard roars.",
	Cultures.KHARZANI: "Both names are signed, and the ink is sanded dry. Her family and your company are on their feet, and for once they are making the same noise.",
	Cultures.RYUMON: "The page is witnessed and blotted. Then the quiet breaks all at once, and somebody is beating a drum.",
}

## The quiet way: in her room, by one candle. She speaks, you each say a vow, and with no
## one there to ask the question she asks it herself.
const PRIVATE_SCENE := "No guests and no banners. One candle, the door shut, the household asleep below."
const PRIVATE := {
	"edda": "No cousins, no cook, no speech from {host}. One candle. I keep looking for something to arrange, and there's only you.",
	"farid": "No witnesses, no seals, nobody to hear how it sounds. I thought I would miss them. I do not.",
	"kaede": "Nothing will be written down tonight. I have decided that. It is the first decision of its kind I have made.",
}
const PRIVATE_ASK := {
	"edda": "There's nobody here to ask it, so I will. Will you have me? At the hearth and on the road.",
	"farid": "There is no one to ask it three times. I will ask it once, and mean it three times over. Do you consent?",
	"kaede": "There is no register and no witness. I will ask it anyway. Is it your will that we stand together?",
}
const PRIVATE_ANSWER := {
	"edda": "Then so do I. Done. Sit down; there's nothing else on the list.",
	"farid": "And I do. Nobody heard it but you. That turns out to be everyone I needed.",
	"kaede": "So do I. There is no record of it. I will remember it exactly, and that will have to serve.",
}

## Each culture's rite in two lines, for a wedding kept before the day was played by hand.
const RITES := {
	Cultures.VARDISH: [
		"A red cord was passed through the smoke of the hearth-fire and wound once round both your wrists.",
		"{name} tied the knot herself, and tested it twice.",
	],
	Cultures.KHARZANI: [
		"You shared bread and salt before witnesses from both houses, and the contract was read aloud.",
		"The last clause was hers, and one word long.",
	],
	Cultures.RYUMON: [
		"There were three cups, and three sips from each, and then both names were written in the register.",
		"{name} wrote hers beside yours, closer than the ruled column allowed.",
	],
}

## The host's toast at the feast, by bearing.
const HOST_TOASTS := {
	Lords.CAUTIOUS: "I have watched this match for a year, looking for the fault in it. I have not found one. That is the longest speech of praise I know how to make.",
	Lords.DARING: "I would have carried {name} off on a fast horse and spared us all the benches. She tells me she was asked, and said yes. I admit that is better. Drink!",
	Lords.HONORABLE: "{name} has kept faith with this house all her life. Keep faith with her, captain, and this house is yours to call on.",
	Lords.CRUEL: "Our enemies are yours now, captain, and yours are ours. I have a list. We will speak of it when the cups are down.",
}

## Raising your own cup, and what she says after.
const RAISE := "Raise your cup"
const YOUR_TOASTS := {
	"her": "To {name}, who said yes.",
	"company": "To the company, who got me here in one piece.",
	"absent": "To {fallen}, who should be at this table.",
}
const YOUR_TOAST_TAGS := {"her": "everyone drinks", "company": "your captains will remember it", "absent": "the captains you lost"}
const AFTER_TOAST := {
	"edda": {
		"her": "Sit down. You've said it; now you have to eat.",
		"company": "They heard that. Look at them not looking at you.",
		"absent": "I'd have set places for them. I will, at the next one.",
	},
	"farid": {
		"her": "Briefly put. I could not have drafted it better, and I did try.",
		"company": "Half of them have found something in their eye. I like your company.",
		"absent": "I never met them. Tell me about them tonight. I would like to know who I am missing.",
	},
	"kaede": {
		"her": "Accurate. Sit down, please. They are all looking at me.",
		"company": "Several of them are wiping their faces. I will not record which.",
		"absent": "Give me their names afterwards. They should be written somewhere that lasts.",
	},
}

## Where she'll be afterward.
const AFTER := {
	"edda": "{name} keeps the household at {place}. There is a place set for you there now, whether or not you're expected.",
	"farid": "{name} keeps the envoy's office at {place}, and reads your letters before the ones with seals.",
	"kaede": "{name} goes back to the archive at {place}. The page with both your names on it is in her own box, not the council's.",
}

## A gift sent by a ruler who didn't come.
const GIFTS := {
	Cultures.VARDISH: "a silver cup",
	Cultures.KHARZANI: "a bolt of red silk",
	Cultures.RYUMON: "a lacquered writing box",
}

## The day told again from her memory book.
const TOLD := {
	"chip": "Remembered",
	"day": "Your wedding at %s, day %d.",
	"guests": "Who came: %s.",
	"second": "%s stood with you.",
	"breath": "You took a breath first. %s",
	"close": "Close the memory",
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


## What you did on the way here, as her memory book has it: {task: what you did for her
## people (chapter 3's choice), council: what you said in her house's council (chapter 4's;
## the mending, if you broke your word and mended it)}. "" where the book no longer says.
static func road(memories: Array) -> Dictionary:
	var out := {"task": "", "council": ""}
	for m in memories:
		if String(m.get("kind", "")) != "decision":
			continue
		var choice := String(m.get("choice", ""))
		match int(m.get("chapter", 0)):
			3:
				out["task"] = choice
			4:
				if choice != "decline":
					out["council"] = choice
	return out


## What she says of what you did for her people, before her vow; "" when there is nothing.
static func their_road(cand: String, task: String) -> String:
	return String(THEIR_ROAD.get(cand, {}).get(task, ""))


## The head of her house on how you come to be standing here, by what you said in council.
static func host_word(cand: String, council: String) -> String:
	var lines: Dictionary = HOST_WORD.get(cand, HOST_WORD["edda"])
	return String(lines.get(council, lines[""]))


static func yours(cand: String) -> Array:
	return YOURS.get(cand, YOURS["edda"])


## Which of your vows `text` was (its id in YOURS), or "".
static func vow_id(cand: String, text: String) -> String:
	for v in yours(cand):
		if String(v["text"]) == text:
			return String(v["id"])
	return ""


## What she says to the vow you said; "" for a vow she has no answer to.
static func vow_answer(cand: String, id: String) -> String:
	return String(VOW_ANSWER.get(cand, {}).get(id, ""))


## What your second says under their breath, by temperament.
static func whisper(captain: Dictionary) -> String:
	return String(SECOND_WHISPER.get(String(captain.get("temperament", "")), SECOND_WHISPER[""]))


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


## What she says after you raise your cup to `key` (her, company, absent).
static func after_toast(cand: String, key: String) -> String:
	return String(AFTER_TOAST.get(cand, AFTER_TOAST["edda"]).get(key, ""))
