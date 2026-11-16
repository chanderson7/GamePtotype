## What is said in married life (MarriedLife): asking her help and how she answers, her
## house's help, coming with you and going home, the fire on the road, being taken and
## coming home, and the notes on the map. Words only; letters are in letters.gd. {name} is
## her name; other keys as each line says.
extends RefCounted

## Asking for help, from her talk.
const HELP_OPENER := "I need your help with something."
const HELP_PROMPT := "What do you need?"
const HELP_BACK := "Nothing. It can wait."

## Her ask, as you'd put it, and its tag.
const ASK := {
	"edda": {"text": "Send a supply train to the company.", "tag": "food and silver from the household", "icon": "food"},
	"farid": {"text": "Carry a letter for me.", "tag": "a truce, or a good word", "icon": "mail"},
	"kaede": {"text": "Look something up for me.", "tag": "a place, or a lord", "icon": "book"},
}
## Her answer when she can do it, before you say where or what.
const ASK_YES := {
	"edda": "Where's it going? Tell me, and I'll have the cart loaded before you've finished your cup.",
	"farid": "To whom? I'll ride myself. Letters carried by envoys get read; letters carried by couriers get lost.",
	"kaede": "Which? A place or a person. I'll have it by tomorrow, or by tonight if you let me skip supper.",
}
const SUPPLY_PROMPT := "Where should the train go?"
const ENVOY_PROMPT := "Who should she ride to?"
const LOOKUP_PROMPT := "What should she look up?"
## Her answer when it's done.
const SUPPLY_SENT := {
	"edda": "It'll leave at first light: {food} rations and {silver} silver. Keep to the roads near {place} and it'll find you.",
}
const ENVOY_SENT := {
	"farid": "Then I'll ride to {place}. Don't fight anyone important until I'm back.",
}
const LOOKUP_SENT := {
	"kaede": "{subject}. I'll write it up properly. You'll have it by tomorrow.",
}
const LOOKUP_NOW := {
	"kaede": "{subject}. Give me an hour with the satchel. I brought the useful maps. Some of them.",
}
## When there's nowhere to send it, or no one to ask.
const NOTHING_TO_ASK := {
	"edda": "There's nowhere safe to send a cart just now. Get somewhere with walls and ask me again.",
	"farid": "There's no one to write to just now. Nobody is angry with you. Enjoy it; it won't last.",
	"kaede": "There's nothing near enough to look up. Ride somewhere and ask me again.",
}

## Her house's help.
const MEN_TEXT := "Ask your house for men."
const MEN_TAG := "up to %d from the garrison here · their wages are yours"
const MEN_DONE := "{lord} sends {men} men from the garrison. They'll grumble about your rations for a week, and then they'll be yours."
const HOLD_TEXT := "Ask your house to hold a place for me."
const HOLD_TAG := "%s rides there with the house's men for two days"
const HOLD_PROMPT := "Where should they hold?"
const HOLD_DONE := "{lord} will ride for {place} today and hold it two days. They like being asked. Don't say I told you."

## Coming with you, and going home.
const JOIN_TEXT := "Come with me for a while."
const JOIN_TAG := "she rides with the company · her help comes twice as often · if you lose, she can be taken"
const JOIN_YES := {
	"edda": "The household can count its own spoons for a season. I'll fetch my boots. The good ones.",
	"farid": "An envoy on campaign. My mother will say it's undignified. I'll write and tell her all about it.",
	"kaede": "I'll bring the travelling desk and the useful maps. And the useless ones, in case.",
}
const HOME_TEXT := "Ride home. I'll see you there."
const HOME_TAG := "back at %s when the road allows"
const HOME_YES := {
	"edda": "Home, then. Someone has to keep the tallies honest. Come back to me in one piece.",
	"farid": "I'll go. Write to me, unimportantly and often.",
	"kaede": "I'll go back to the archive. I'll mark where you are on the map every night. In pencil.",
}
## By the company's fire, opening her talk on the road.
const ON_ROAD_GREETING := {
	"edda": ["The quartermaster and I have reached an understanding. He's terrified of me. Sit down.",
		"Your sergeant snores in three keys. I've started a tally. Sit with me."],
	"farid": ["Your company has more opinions than a council of emirs, and better manners. Sit with me.",
		"I've been teaching your sergeant the short courtesies. He's hopeless. Sit."],
	"kaede": ["I've drawn the camp. Your tent is in the wrong place on it. I'm not moving it. Sit.",
		"The roads here aren't on any map I own. I'm delighted. Sit with me."],
}
## At the fire, a moment with her (camp_moments).
const FIRE := {
	"edda": ["Edda is going through the quartermaster's ledgers by the fire, and has found two barrels nobody can account for. She looks thrilled.",
		"Edda sits with the cooks at the fire and has them laughing at a story about her cousin and a horse.",
		"Edda has taken off her boots by the fire and set them side by side, and then, after a moment, put yours beside them."],
	"farid": ["Farah is at the fire writing a letter in very small script, and covers it with her hand when you come near.",
		"Farah has taught half the company a Kharzani card game, and is winning, politely.",
		"Farah sits a little apart from the fire, watching the road, and moves over when you come to sit."],
	"kaede": ["Kaede has spread a map across two shields by the fire and is arguing with it under her breath.",
		"Kaede is asking the newest recruits where they come from, and writing every answer down.",
		"Kaede has fallen asleep at the fire with a pencil in her hand. Someone has put a cloak over her."],
}
const FIRE_TITLE := "By the fire"

## Being taken, and coming home.
const TAKEN_NOTE := "{captor} took {name} when the company broke. A road home is in your Journal."
const HOME_NOTE := {
	"battle": "{name} is free: you beat {captor}. She rides home.",
	"ransom": "{name} is free: her ransom is paid. She rides home.",
	"escaped": "{name} walked free when {captor} fell. She's home.",
	"house": "{name}'s house paid for her when you didn't come. She's home.",
}
const ROAD_HOME_MEMORY := {
	"battle": "The road home: you beat %s and brought her out.",
	"ransom": "The road home: you paid what %s asked.",
	"escaped": "The road home: she walked free when %s fell.",
	"house": "The road home: her house paid %s, when you didn't come.",
}
const RANSOM_TEXT := "Ransom"
const HELD_LINE := "Held by {captor}"

## On the map.
const SUPPLY_MET_NOTE := "{name}'s supply train meets you at {place}: {food} rations and {silver} silver."
const SUPPLY_LOST_NOTE := "Bandits took {name}'s supply train near {at}."

## What came of an envoy's letter.
const TRUCE_GRANTED := "{ruler} received me, after a morning of being kept waiting by people paid to keep envoys waiting. {realm} will let your company pass in peace."
const TRUCE_REFUSED := "{ruler} would not receive me. {realm} thinks too ill of you just now; I'd let it cool before I try again."
const TRUCE_NOT_NEEDED := "By the time I arrived, {realm} had already forgiven you. I stayed for supper anyway."
const WORD_GIVEN := "I spoke well of you to {lord}, who thinks a little better of you now. And better of me, which was the harder part."
const WORD_MISSED := "{lord} wasn't to be found. I left the letter. I don't know that anyone will read it."


static func fill(text: String, ctx: Dictionary) -> String:
	var out := text
	for k in ctx:
		out = out.replace("{%s}" % k, String(ctx[k]))
	return out
