## Lords gather: in peacetime a realm's ruler, or one of its richer lords, holds a feast or
## a dance at their seat for three nights, and lords ride in from across the realm. The
## rules (how often, who comes, what you can do there) and the words said; the world sim
## and GameState carry them out.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Lords = preload("res://scripts/data/lords.gd")

const FEAST := "feast"
const DANCE := "dance"
## A day at the lists, then a feast: only a crown holds one.
const TOURNEY := "tourney"

# ---------------------------------------------------------------- when

## Once a day a realm at peace with everyone may call one. With the gap and the three
## nights themselves, that's about one every two weeks.
const SEASON_CHANCE := 0.2
## Days after one ends before the same realm holds another.
const GAP_DAYS := 6
## How long one lasts: three nights.
const LENGTH_HOURS := 72.0
## It starts at the first dusk at least this long after it's called.
const LEAD_HOURS := 24.0
const DUSK := 18.0
## How often the ruler hosts at the capital, rather than a rich lord at their own seat.
const RULER_HOSTS := 0.6
## A peace treaty brings a peace feast at the ruler's capital within this many days.
const PEACE_FEAST_DAYS := 2

# ---------------------------------------------------------------- who comes

## Lords within this many hours' ride of the host's seat come.
const REACH_HOURS := 48.0
## The chance a lord of an allied realm comes too.
const ALLY_CHANCE := 0.3
const MAX_GUESTS := 8
## A warband below this share of its full strength stays home to refill.
const MIN_MEN := 0.6
## An enemy army this close to the hall (in hours' ride) breaks it up.
const BREAK_HOURS := 24.0

# ---------------------------------------------------------------- you

## You're invited if the host thinks this well of you (or you serve the realm, hold land
## in it, or rule it).
const INVITE_REGARD := 10
## Your first word with each lord at the table.
const FIRST_WORD := 2
const FIRST_WORD_UNINVITED := 1
const TOAST_RENOWN := 120
const TOAST_REGARD := 2
const GIFT_SILVER := 50
const GIFT_FOOD := 50
const GIFT_REGARD := 5
const GIFT_REALM := 2
## Hearing the gossip takes an hour of the evening.
const GOSSIP_HOURS := 1.0

# ---------------------------------------------------------------- the hall (hall_moments.gd)

## The chance, after your first deed of a night, that something happens in the hall.
const MOMENT_CHANCE := 0.6
## The small warmth most moments bring.
const MOMENT_REGARD := 1
const BARD_RENOWN := 5
const CHALLENGE_WIN_CHANCE := 0.5
const CHALLENGE_WIN_REGARD := 3
const CHALLENGE_RENOWN := 5
const INSULT_RENOWN := 5
const INSULT_REGARD := -3
const NEWS_REGARD := 2
const ROUND_SILVER := 20
const DANCE_LORD := 3
const DANCE_DARING := 4
## A dance with someone you court: trust, kept apart from the visits' own cap, up to
## this many dances over the whole courtship.
const DANCE_TRUST := 1
const DANCE_TRUST_CAP := 3

# ---------------------------------------------------------------- your own

const HOST_SILVER := 300
const HOST_FOOD := 200
const HOST_COOLDOWN_DAYS := 20
## Regard with each lord who comes, once.
const HOST_REGARD := 5
## Lords who think this well of you come when asked.
const HOST_FRIEND_REGARD := 20
## Lords you'd win over come unless they think this little of you.
const HOST_SPURN := -30
## Lords you're persuading start this much more convinced while it lasts, and for a while after.
const HOST_CONVICTION := 10
const HOST_AFTER_HOURS := 72.0
## Leaving out the liege of lords you've asked: a small snub.
const SNUB_REGARD := -3
## Held in a lord's hall, in your name: he's honoured to host it.
const HOST_IN_NAME_REGARD := 5
## Not there on the first night: the lords you were winning over notice.
const ABSENT_KING_REGARD := -3

# ---------------------------------------------------------------- the king's table

## A seat at your right hand for one lord; lords of more renown feel passed over.
const HONOUR_REGARD := 8
const PASSED_OVER_REGARD := -2
## A castle granted before everyone: twice the Regard of a quiet grant, and the hall sees it.
const PUBLIC_GRANT_REGARD := 30
const PUBLIC_GRANT_WITNESS := 3
## A petition heard at table, or settled from afar; refused in front of everyone.
const PETITION_TABLE := 5
const PETITION_AFAR := 2
const PETITION_REFUSED := -5
## A petition to be heard costs the evening.
const PETITION_HOURS := 1.0
## The king's speech, in place of a toast.
const SPEECH_RENOWN := 120
const SPEECH_REGARD := 2
## At war, a speech makes the case: lords you're winning over grow this much more convinced,
## and your sworn lords count as ready to ride for this long, whatever their strength.
const SPEECH_CONVICTION := 10
const SPEECH_READY_HOURS := 168.0
## Gifts from the king: silver a head, Regard each.
const KING_GIFT_SILVER := 30
const KING_GIFT_REGARD := 3

# ---------------------------------------------------------------- the tourney

const TOURNEY_PURSE := 100
## Captains of yours who may ride.
const TOURNEY_CAPTAINS := 3
const TOURNEY_RENOWN := 10
const TOURNEY_BOND := 1.5
const TOURNEY_WIN_REGARD := 5
const TOURNEY_ENTRY_REGARD := 2
## A captain unhorsed is sometimes hurt (never killed).
const TOURNEY_WOUND_CHANCE := 0.15

# ---------------------------------------------------------------- between gatherings

## A lord near their capital with nothing better to do sometimes rests there a while.
const REST_CHANCE := 0.25
const REST_REACH := 12.0
const REST_MIN := 12.0
const REST_MAX := 24.0


# ---------------------------------------------------------------- words
##
## How the gatherings are written, in the same register as the wedding (see the notes at
## the top of wedding_lines.gd):
##   Narration is plain: what can be seen and heard. It doesn't joke; the hall does.
##   Each people keeps its own hall. Vardish: a long hall, benches, a harper, the hearth,
##     ale, toasts banged on the table. Kharzani: a courtyard, lanterns, brass trays,
##     sherbet then wine, a poet. Ryumon: a terrace or tatami, cups filled in turn, a verse,
##     the moon.
##   Lords speak by bearing. Daring: loud, wagers and horses, short. Cautious: measured,
##     conditions, counts twice. Honorable: formal, oaths and fairness. Cruel: cold, polite
##     on the surface, everything a transaction.
##   You are whatever the game has made you (a sellsword, a lord's vassal, a crown); a
##     lord is never "he" or "she".

## What each culture calls them.
const NAMES := {
	Cultures.VARDISH: {FEAST: "feast", DANCE: "midsummer dance", TOURNEY: "tourney"},
	Cultures.KHARZANI: {FEAST: "banquet", DANCE: "lantern night", TOURNEY: "lance games"},
	Cultures.RYUMON: {FEAST: "moon-viewing", DANCE: "blossom festival", TOURNEY: "lance trials"},
}

## The hall, as you walk in, by people and night (the first, the second, the last).
const NIGHTS := {
	Cultures.VARDISH: [
		"The long table runs the length of the hall, the hearth at one end and the high seat at the other. A harper plays under the din. Every so often someone stands and bangs the table until the hall hears a toast.",
		"The second night. The benches have been moved closer to the fire, the speeches are shorter, and the harper has been given a stool and a cup.",
		"The last night. The trestles at the far end have been cleared for dancing, and the fiddlers are tuning by the door.",
	],
	Cultures.KHARZANI: [
		"Lanterns hang over the courtyard on long cords. Brass trays go round with sherbet and dates, and a poet near the fountain is reciting to anyone who will stand still.",
		"The second night. The sherbet has given way to wine, the poet has found a rival, and the two of them are trading verses across the fountain.",
		"The last night. The musicians have taken the steps by the arches, and the trays are being carried out of the way.",
	],
	Cultures.RYUMON: [
		"The screens are open to the terrace and the moon. Cups are filled in turn down the low tables, and when someone reads a verse the room goes quiet to hear it.",
		"The second night. The cups go round faster. Someone has begun a verse-game, each guest adding a line, and the lines are getting worse on purpose.",
		"The last night. The tatami at the end of the hall has been cleared, and the drummers are kneeling by the screens.",
	],
}
## The first night's hall, as a line under the hall's picture (settlement screen).
const HALL := {
	Cultures.VARDISH: "A long table, a harper, the hearth, and a toast every few minutes.",
	Cultures.KHARZANI: "Lanterns over the courtyard, brass trays, and a poet who will not stop.",
	Cultures.RYUMON: "Cups filled in turn, the moon through the screens, and a verse now and then.",
}
## The first night, by why it's held, after the hall itself.
const REASON_LINE := {
	"peace": "It is a peace feast. The talk is careful, and nobody is quite sure yet who may be toasted.",
	"victory": "It is a victory feast. The spoils are on the walls, and every story told tonight gets a little longer.",
}

## The herald at the door. {who} is how you are named.
const HERALD := {
	Cultures.VARDISH: "{who}!",
	Cultures.KHARZANI: "Be welcome in this house: {who}!",
	Cultures.RYUMON: "{who}. The house bids you enter.",
}
## How you are named, by what you are: a company, sworn or landed, a crown.
const HERALD_WHO := {
	"company": "The captain of the {people} company",
	"known": ", known as {title}",
	"contract": ", in the pay of {realm}",
	"fief": ", who holds land of {realm}",
	"crown": "The ruler of {crown}",
	"own": "All rise for the ruler of {crown}, whose hall this is!",
}
const HERALD_NOT_ASKED := "The herald runs a finger down the guest list, and then again more slowly. Your name is not on it."
const HERALD_SEEN := "The hall turns to look. Cups are raised."
const HERALD_NOT_SEEN := "Heads turn. A steward waits to see what you will do. You may still sit, lower down the table."

## When the music starts.
const DANCE_OPEN := {
	Cultures.VARDISH: "The fiddles strike up the midsummer reel. The benches go back against the walls, and couples form down the length of the hall.",
	Cultures.KHARZANI: "The musicians begin the slow one. The lanterns sway over the courtyard, and guests drift in from under the arches in pairs.",
	Cultures.RYUMON: "Blossom blows in through the open screens. The dancers form two lines on the tatami, fans ready.",
}

## Someone you court, when you ask.
const DANCE_ROMANCE := {
	"edda": "Edda looks at your hand, then at the room, then takes it. \"The whole household is watching. If you tread on me, I'm telling them you meant it.\"",
	"farid": "Farah has been not looking for you across the courtyard for some time. \"There you are. I had run out of people to pretend to listen to.\"",
	"kaede": "Kaede bows, correctly, and takes your hand. \"I have practised since the last time. From a better book. Please don't count.\"",
}
## The memory it leaves (each dance kept as itself below; this is the fallback).
const DANCE_MEMORY := {
	"edda": "You danced the midsummer reel with Edda. Nobody's feet were harmed. Mostly.",
	"farid": "You danced with Farah under the lanterns, and she stopped pretending.",
	"kaede": "You danced with Kaede on the tatami. The book was wrong about the third step.",
}
## Each dance kept as itself: the first, the second, the third (then round again). What
## she says of each later is in romance_talk_lines.gd (DANCES), and answers these.
const DANCE_MEMORIES := {
	"edda": ["You danced the midsummer reel with Edda. You trod on her foot once, and apologised for the rest of the reel.",
		"A second reel with Edda. You had learned the turn, and the whole household saw that you had.",
		"You danced with Edda until the fiddlers stopped, and the hall went quiet around you."],
	"farid": ["You found Farah under the lanterns, where she was pretending not to look for you.",
		"Farah led the slow one under the arches, and you let her.",
		"The musicians played the slow one twice for you and Farah. Someone had paid them."],
	"kaede": ["You danced with Kaede on the tatami. The book was wrong about the third step, and so were you.",
		"A second dance with Kaede. You bowed correctly, and she almost didn't know you.",
		"You danced with Kaede, and for once she didn't write it down."],
}

# ---------------------------------------------------------------- the dance floor

## The lords stay at the table (the toast, the gift and the first word are theirs); the
## floor holds their households. A lord's kinswoman, his wife, sister or daughter, is
## made once and kept on his house (SocialSim.house_kin), so she is the same woman at the
## next gathering. About one lord in six has no one with him.
const KIN_RELATIONS := ["wife", "wife", "sister", "daughter", "daughter"]
const KIN_NONE_CHANCE := 0.16
## Women's names of each land, for a lord's kin.
const KIN_NAMES := Cultures.WOMEN
## A lady lord has no wife at her side: her kinswoman is her sister or her daughter.
const KIN_RELATIONS_LADY := ["sister", "daughter", "daughter"]
## How many lords' kin are offered a night: the host's, then the guests'.
const KIN_OFFERED := 3
## A lord's kinswoman, when you ask, by the lord's bearing. {name} is hers, {lord} the
## lord's short name, {relation} what she is to them. (A lord may be a lady: no "his".)
const DANCE_KIN_LINES := {
	Lords.CAUTIOUS: "{name} looks to {lord} before she takes your hand, and waits for the smallest of nods. She dances carefully and well. {lord} watches every turn of it.",
	Lords.DARING: "\"At last, someone who isn't a cousin.\" {name} is on the floor before you have finished asking. At the table {lord} laughs out loud and bangs a cup for the fiddlers to go faster.",
	Lords.HONORABLE: "{name} accepts with a curtsey a shade more formal than the room, and takes you through the figure without a fault. At the table {lord} inclines their head to you: their {relation} has been honoured, and so have they.",
	Lords.CRUEL: "{name} gives you her hand as if she had expected to. \"Everyone is watching. They always are.\" {lord} smiles thinly from the table, and seems to count the dance as their own doing.",
}
## The round everyone joins, by culture: Regard with every lord in the hall.
const DANCE_ROUND_REGARD := 1
const DANCE_ROUND := {
	Cultures.VARDISH: "You join the reel where the line breaks, and are passed from hand to hand down the whole length of the hall. By the end of it the lords have watched you make a fool of yourself with everyone else, and like you the better for it.",
	Cultures.KHARZANI: "You step into the lantern circle and are given a place between an old emir and a girl of nine. The circle turns, and turns again, and when the drums stop every face in it is smiling at every other.",
	Cultures.RYUMON: "You take a place in the second line, a fan pressed into your hand, and follow the figure half a beat behind everyone else. Nobody says so. Afterwards several lords bow to you, which is the same as saying so.",
}
## Someone you haven't met, across the hall: how she is pointed out, and what passes when
## you ask her to dance. Her first word; the story's first audience follows from it.
const DANCE_SEEN := {
	"edda": "Ask the woman in Ravensford grey to dance.",
	"farid": "Ask the envoy with the ink-stained fingers to dance.",
	"kaede": "Ask the woman reading by the screens to dance.",
}
const DANCE_MEET := {
	"edda": "She has been arguing quietly with an older man about field horses, and loses the thread when you ask. \"Edda. I keep the tallies at Ravensford.\" She dances as if she has counted the steps beforehand, which she has. \"You lead a company. I know what a company costs a village. Come to Ravensford, and I'll show you the ledger. It's more interesting than it sounds. Slightly.\"",
	"farid": "She looks up from a letter she was reading under the table. \"Farah. I carry Qasr Hamra's words to wherever they need to go.\" Under the lanterns she dances better than she lets on. \"A captain who asks rather than orders. That is rare enough to deserve a second conversation. Find me at Qasr Hamra.\"",
	"kaede": "She marks her place in the scroll with one finger before she closes it. \"Kaede, of the Kitayama archive. I know the steps from a book, so forgive what follows.\" She is wrong about the third step, and laughs at herself. \"The old records have a good deal to say about captains like you. Come to Kitayama, and I'll show you which parts are true.\"",
}
const DANCE_MEET_MEMORY := {
	"edda": "The night you met Edda, over a reel at someone else's feast.",
	"farid": "The night you met Farah, under another house's lanterns.",
	"kaede": "The night you met Kaede, half a step behind the music.",
}
## Someone you've met and no more, when you ask.
const DANCE_ACQUAINTED := {
	"edda": "Edda considers it a moment longer than is polite. \"One. And I'll hear about it if you tread on me.\" She dances well, and talks about the price of seed corn the whole way through.",
	"farid": "Farah raises an eyebrow. \"The captain remembers me. Good.\" She lets you lead, and corrects you twice, kindly, without seeming to.",
	"kaede": "Kaede bows. \"I have been practising, since. From a better book.\" It shows, a little.",
}
## Someone you court who isn't in the hall: where she would be.
const DANCE_ABSENT := {
	"edda": "Edda isn't here. She comes when Ravensford's household does, and is at Ravensford otherwise.",
	"farid": "Farah isn't here. She comes to Kharzan's gatherings and with Qasr Hamra's household, and is at Qasr Hamra otherwise.",
	"kaede": "Kaede isn't here. She comes when Kitayama's household does, and is at Kitayama otherwise.",
}

## Watching from the wall.
const DANCE_WALL := "You keep to the wall with a cup, and watch who dances with whom. It tells you more than the table did."

## Your toast, in the hall's own way, by why it's held: a feast like any other, a peace,
## a victory. {host} is the host.
const TOASTS := {
	Cultures.VARDISH: {
		"": "You stand and bang the table until the hall hears you. \"To {host}, and the roof over all our heads.\" They drink, and bang the table back.",
		"peace": "You stand and bang the table until the hall hears you. \"To {host}, and to a winter with nobody on the roads but merchants.\" The hall drinks to that longer than to anything else tonight.",
		"victory": "You stand and bang the table until the hall hears you. \"To {host}, and to the ones who won it and aren't here to drink.\" The hall stands to drink, and sits in silence a moment after.",
	},
	Cultures.KHARZANI: {
		"": "You raise your cup when the music rests. \"To {host}'s house: may its courtyard never lack for guests.\" The poet makes a verse of it before you've sat down.",
		"peace": "You raise your cup when the music rests. \"To {host}'s house, and to roads where a caravan fears nothing but the weather.\" The poet makes a verse of it, and for once nobody argues.",
		"victory": "You raise your cup when the music rests. \"To {host}'s house, whose walls are still standing, and to those who kept them so.\" The poet begins a verse, and stops, and lets it be.",
	},
	Cultures.RYUMON: {
		"": "When the cup comes to you, you offer a verse instead of a toast. It is not a good verse. They are kind about it, and {host} smiles.",
		"peace": "When the cup comes to you, you offer a verse: a river with no one on the far bank. It is not a good verse, but {host} asks you to say it again.",
		"victory": "When the cup comes to you, you offer a verse for the dead of both sides. It is plain, and the room is quiet after it. {host} bows to you.",
	},
}

## The host's thanks for a gift, by bearing and what you brought ("silver" or "food").
const GIFT_THANKS := {
	Lords.CAUTIOUS: {"silver": "\"Generous. Thank you. It will go where it's needed, and I'll know where that was.\"",
		"food": "\"Rations. Sensible. More use than plate in a hard season. Thank you.\""},
	Lords.DARING: {"silver": "\"A guest who brings something! Sit by me. You can tell me how you came by it.\"",
		"food": "\"Rations! Well, you know what feeds an army. Sit by me.\""},
	Lords.HONORABLE: {"silver": "\"You honour this house, captain. It will not be forgotten.\"",
		"food": "\"Bread for the hall, from someone who knows what it is to go without. You honour this house.\""},
	Lords.CRUEL: {"silver": "\"Hm. Better than most bring. I'll remember who gave it.\"",
		"food": "\"Rations. How practical. I'll see the kitchen has them.\""},
}

## What an hour's listening turns up. {lord} is the lord, {first} their first name,
## {ruler} whom they serve, {why} what sours them, {band} a band, {news} the latest news.
const GOSSIP := {
	"sour": "{lord} {why}, and says so after the second cup, loud enough for the end of the table. {first} might hear you out.",
	"trouble": "{lord} is plagued by {band}, and keeps coming back to it. {first} would pay to see them gone.",
	"war": "The talk down the table is all of one thing: {news}",
	"quiet": {
		Cultures.VARDISH: "Talk of the harvest, a horse race, and whose cousin is marrying whom. Nothing worth the hour, but the ale was good.",
		Cultures.KHARZANI: "Talk of the price of pepper, a poet's feud, and whose daughter refused whom. Nothing worth the hour, but the dates were good.",
		Cultures.RYUMON: "Talk of the moon, a disputed verse, and a ferry that sank with nobody on it. Nothing worth the hour, but the cups were full.",
	},
}
## Why a lord is sour with their ruler, as the gossip puts it.
const SOUR := {
	"landless": "has no castle of their own, and has stopped pretending not to mind",
	"lost": "lost {place}, and blames {ruler} for it",
	"burned": "watched {place} burn while {ruler} sat at home",
	"weary": "is weary of the war, and of {ruler} for making it",
}

## A night with nothing in it, at its end.
const QUIET_NIGHT := "A quiet night. Nobody thinks better or worse of you for it."

## An invitation, as the letter reads.
const INVITE := "{host} holds the {name} at {place}, three nights from {when}. You are invited: {why}."
const NOT_INVITED := "{host} holds the {name} at {place}, three nights from {when}."


## "feast", "lantern night"... for a culture and kind.
static func kind_name(culture: String, kind: String) -> String:
	var names: Dictionary = NAMES.get(culture, NAMES[Cultures.VARDISH])
	return String(names.get(kind, kind))


## Fill {name}-style blanks in a line.
static func fill(text: String, ctx: Dictionary) -> String:
	var out := text
	for k in ctx:
		out = out.replace("{%s}" % String(k), String(ctx[k]))
	return out


## "Lantern night": the first letter up, the rest as written.
static func upper_first(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)


## "the first night", "the second night"...
static func night_word(n: int) -> String:
	return ["the first night", "the second night", "the third night", "the last night"][clampi(n - 1, 0, 3)]


## The hall on night `n` (1 to 3) of a gathering of `culture`, held for `reason`: the
## hall itself, and on the first night why it's held.
static func night_line(culture: String, n: int, reason: String = "") -> String:
	var lines: Array = NIGHTS.get(culture, NIGHTS[Cultures.VARDISH])
	var out := String(lines[clampi(n - 1, 0, lines.size() - 1)])
	if n <= 1 and REASON_LINE.has(reason):
		out += " " + String(REASON_LINE[reason])
	return out


## Your toast in a hall of `culture`, held for `reason`, to `host`.
static func toast(culture: String, reason: String, host: String) -> String:
	var by: Dictionary = TOASTS.get(culture, TOASTS[Cultures.VARDISH])
	return fill(String(by.get(reason, by[""])), {"host": host})


## The host's thanks for a gift of `what` ("silver" or "food"), by bearing.
static func gift_thanks(bearing: String, what: String) -> String:
	var by: Dictionary = GIFT_THANKS.get(bearing, GIFT_THANKS[Lords.HONORABLE])
	return String(by.get(what, by["silver"]))


## Nothing worth the hour, in a hall of `culture`.
static func quiet_gossip(culture: String) -> String:
	var q: Dictionary = GOSSIP["quiet"]
	return String(q.get(culture, q[Cultures.VARDISH]))
