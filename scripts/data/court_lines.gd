## What is said at your own court once you wear a crown: the speech at your table, a lord
## seated at your right hand, a castle granted before the hall, gifts for every lord, the
## petitions and how their lords take your answer, the war council's counsel, the lists,
## and the raising of the crown itself. Words only; the rules are in crown_court.gd and
## GameState.
##
## Written in the register set out at the top of wedding_lines.gd and gatherings.gd:
## narration plain, lords by bearing (Daring loud and short, Cautious measured and
## conditional, Honorable formal, Cruel cold and transactional). Lords call you "my liege":
## the game doesn't say whether you are a king or a queen, and nor do they. A lord is never
## "he" or "she". {lord} is a lord's short name, {first} their first name.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Lords = preload("res://scripts/data/lords.gd")

const ADDRESS := "my liege"

# ---------------------------------------------------------------- the speech

## What you say when you stand at your own table, by whether your crown is at war. {foe}
## is the realm you fight, {lords} how many lords sit at the table, {holdings} how many
## castles and towns fly your banner. The second line is said only if captains of yours
## have fallen: {fallen} is the last of them.
const SPEECH := {
	"war": "\"{foe} calls us rebels. Look along this table: {lords} lords who chose this banner, and {holdings} walls that fly it. Rebels don't hold walls. When I call, ride.\"",
	"peace": "\"Not long ago there was no banner over this hall. Tonight there are {lords} lords at its table and nobody at its gate. That is what we hold, and we hold it together.\"",
	"fallen": "\"And a cup for {fallen}, and for everyone who should be sitting here and isn't.\"",
}
const SPEECH_HEARD := {
	"war": "The hall is on its feet before you sit down.",
	"peace": "The lords drink standing, and for a moment nobody says anything at all.",
}

# ---------------------------------------------------------------- the right hand

## The lord you seat at your right hand, by bearing.
const HONOURED := {
	Lords.DARING: "{lord} vaults the bench rather than walk round it. \"The right hand! I'll drink from your cup and fight in your front rank, {address}.\"",
	Lords.CAUTIOUS: "{lord} takes the seat slowly, as if it might be taken back. \"You do me more honour than I've earned. I'll set about earning it.\"",
	Lords.HONORABLE: "{lord} bows before sitting. \"I am honoured, {address}, and the hall has seen it. I'll not give you cause to regret it.\"",
	Lords.CRUEL: "{lord} sits, and looks down the table at the lords who didn't. \"A wise choice, {address}.\"",
}
## A lord of more renown, passed over.
const PASSED_OVER := "Further down the table {lord} sets a cup down harder than it needs."

# ---------------------------------------------------------------- a castle granted

## The lord you grant a castle or town to before the whole hall, by bearing. {place} is it.
const GRANTED := {
	Lords.DARING: "{lord} lets out a whoop the length of the hall. \"{place}! I'll hold it against anyone, {address}. I'll hold it against two of anyone.\"",
	Lords.CAUTIOUS: "{lord} stands, and takes a moment over it. \"{place}. I'll see its walls mended and its stores full before the winter. You have my word.\"",
	Lords.HONORABLE: "{lord} kneels where the whole hall can see, and puts their hands between yours. \"{place} is held in your name, {address}, for as long as I live.\"",
	Lords.CRUEL: "{lord} turns the grant in their hands. \"{place}. Generous. The others will remember who was given it.\"",
}
## A castle granted from afar, by letter.
const GRANTED_AFAR := "Your grant of {place} rides to {lord} with the next messenger."

# ---------------------------------------------------------------- gifts from the throne

## Gifts for every lord at your table, by your own people's custom.
const KING_GIFTS := {
	Cultures.VARDISH: "Your steward goes down the table with a silver arm-ring for every lord. They put them on at once. The hall is louder for it.",
	Cultures.KHARZANI: "A robe of honour is laid over every lord's shoulders, one after another down the courtyard. Nobody in Kharzan has to be told what that means.",
	Cultures.RYUMON: "A lacquered box is set before every lord. Inside each is a short sword and a poem in your hand. They are read aloud, one by one.",
}

# ---------------------------------------------------------------- petitions

## How a lord takes your answer: settled, by bearing; then what was done, by kind. {place}
## is the place in question, {band} the band to be hunted.
const PETITION_THANKS := {
	Lords.DARING: "\"Ha! I knew you'd see it my way, {address}.\"",
	Lords.CAUTIOUS: "\"Thank you, {address}. I'll not ask again lightly.\"",
	Lords.HONORABLE: "\"You are just, {address}. The hall has seen it.\"",
	Lords.CRUEL: "\"Good. I'll remember it.\"",
}
const PETITION_DONE := {
	"rebuild": "100 silver from the treasury goes to rebuild {place}.",
	"heard": "You hear {lord} out to the end, without interrupting.",
	"heard_table": "You hear {lord} out over the length of an evening, before the whole table, without interrupting.",
	"bandits": "You take up the hunt for {band} yourself.",
}
## Refused, by bearing.
const PETITION_REFUSED := {
	Lords.DARING: "{lord} laughs, too loudly, and drinks.",
	Lords.CAUTIOUS: "{lord} bows, says nothing, and does not forget it.",
	Lords.HONORABLE: "{lord} bows stiffly. \"As you will, {address}.\"",
	Lords.CRUEL: "{lord} smiles. \"Of course, {address}.\" It is not a pleasant smile.",
}
const PETITION_REFUSED_HALL := "The hall goes quiet while you say it."

# ---------------------------------------------------------------- the war council

## What a lord counsels, by bearing: two each, the lord's id choosing which. {place} is
## the place they name.
const COUNSEL := {
	Lords.DARING: ["\"{place}. Give me the first ladder, {address}.\"",
		"\"Why are we sitting? {place} is right there. I'll be over the wall before they've finished arguing about it.\""],
	Lords.CAUTIOUS: {"relieve": ["\"{place} holds out for us. Break that siege before we start one of our own.\"",
			"\"Our people are shut up in {place}. If it falls while we march elsewhere, every lord here will ask why.\""],
		"march": ["\"Hold what we have, {address}. Ride the border, and let them come to us.\"",
			"\"We have walls enough to defend. Let them spend themselves on ours.\""]},
	Lords.CRUEL: ["\"Burn their villages and their lords will come out to us. It's cheaper than a siege.\"",
		"\"Every field we burn is a soldier they can't feed. Let them starve, {address}, and then let them talk.\""],
	Lords.HONORABLE: {"relieve": ["\"Our people at {place} are starving behind their walls. We go to them first.\"",
			"\"{place} kept faith with us. We keep faith with {place}. Nothing else is worth discussing.\""],
		"storm": ["\"{place}'s walls are high. High walls fall to patience. And we burn no farms on the way.\"",
			"\"Take {place}, and take it cleanly. Let them see what kind of crown this is.\""]},
	"": ["\"I'll ride where you ride, {address}.\""],
}
## A place a lord's counsel names, when the war has given them none.
const THEIR_WALLS := "their walls"

# ---------------------------------------------------------------- the lists

## One bout, at the pass it was decided (first, second, third). {won} {lost}.
const BOUT := [
	"{won} meets {lost} square at the first pass and puts them clean out of the saddle.",
	"Both lances break at the first meeting. At the second pass {won} catches {lost} under the shield, and {lost} goes over the crupper.",
	"Two passes and nothing but splinters. At the third pass {lost} reels, grabs for the pommel, and goes down. The bout is {won}'s.",
]
const BOUT_HURT := "{lost} doesn't get up at once, and is carried from the lists."
## The day's end: your captain takes it, or a lord's champion.
const LISTS_YOURS := "{winner} wins the {name}. The crowd has your company's name in its mouth, and the purse is yours: {silver} silver, and +{renown} renown."
const LISTS_THEIRS := "{winner} wins the {name} and the purse. {lord} is on their feet cheering their own rider (+{regard} Regard)."

# ---------------------------------------------------------------- the crown raised

## The moment your banner goes up over your seat. {place} is the seat, {liege} the realm
## you cast off.
const CROWN_RAISED := "Your banner goes up over {place}, and the old one comes down. The garrison cheers; the town watches in silence. {liege} will not forgive it: it is war."


static func fill(text: String, ctx: Dictionary) -> String:
	var out := text.replace("{address}", ADDRESS)
	for k in ctx:
		out = out.replace("{%s}" % String(k), str(ctx[k]))
	return out


## A line from `lines` by bearing (Honorable's, if the bearing has none).
static func by_bearing(lines: Dictionary, bearing: String) -> String:
	return String(lines.get(bearing, lines.get(Lords.HONORABLE, "")))


## What a lord of `bearing` counsels (`aim`: storm, relieve, march, raid), the `pick`th
## of their two.
static func counsel(bearing: String, aim: String, pick: int) -> String:
	var v = COUNSEL.get(bearing, COUNSEL[""])
	if v is Dictionary:
		v = (v as Dictionary).get(aim, (v as Dictionary).values()[0])
	var lines: Array = v
	return String(lines[posmod(pick, lines.size())])
