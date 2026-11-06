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

## What each culture calls them.
const NAMES := {
	Cultures.VARDISH: {FEAST: "feast", DANCE: "midsummer dance", TOURNEY: "tourney"},
	Cultures.KHARZANI: {FEAST: "banquet", DANCE: "lantern night", TOURNEY: "lance games"},
	Cultures.RYUMON: {FEAST: "moon-viewing", DANCE: "blossom festival", TOURNEY: "archery contest"},
}

## The hall, as you walk in.
const HALL := {
	Cultures.VARDISH: "The long table runs the length of the hall. A harper plays under the din, and every few minutes someone stands to shout a toast.",
	Cultures.KHARZANI: "Brass trays go round the courtyard under the lanterns, and a poet is losing an argument with the musicians.",
	Cultures.RYUMON: "Cups are filled in turn down the low tables. Someone reads a verse about the moon, and the hall goes quiet to hear it.",
}

## When the music starts.
const DANCE_OPEN := {
	Cultures.VARDISH: "The fiddles strike up the midsummer reel. Couples form down the length of the hall, and the benches are pushed back to the walls.",
	Cultures.KHARZANI: "The musicians start the slow one. Lanterns sway over the courtyard, and the guests drift in from the arches in pairs.",
	Cultures.RYUMON: "Blossom drifts in through the open screens. The dancers form two lines on the tatami, fans ready.",
}

## Someone you court, when you ask.
const DANCE_ROMANCE := {
	"edda": "Edda looks at your hand, then at the room, then takes it. \"If you step on my feet in front of the whole household, I'm telling everyone it was on purpose.\"",
	"farid": "Farah has been pretending not to look for you, and doing it badly. \"Finally. I'd run out of people to pretend to listen to.\"",
	"kaede": "Kaede bows, very correctly, and then laughs at herself. \"I learned this one from a book. Forgive me in advance.\"",
}

## The memory it leaves.
const DANCE_MEMORY := {
	"edda": "You danced the midsummer reel with Edda. Nobody's feet were harmed. Mostly.",
	"farid": "You danced with Farah under the lanterns, and she stopped pretending.",
	"kaede": "You danced with Kaede on the tatami. The book was wrong about the third step.",
}

## A lord you ask, by bearing.
const DANCE_LORD_LINES := {
	Lords.CAUTIOUS: "\"I don't usually. But I suppose one can't hurt.\" They dance carefully, and well.",
	Lords.DARING: "\"Ha! I was hoping someone would ask.\" They spin you twice more than the music calls for.",
	Lords.HONORABLE: "\"It would be my honour.\" They lead correctly and thank you after.",
	Lords.CRUEL: "\"You've a nerve.\" They dance anyway, and seem to enjoy being watched doing it.",
}

## Watching from the wall.
const DANCE_WALL := "You keep to the wall with a cup, and listen."

## Your toast, by culture: the hall's way of raising a cup.
const TOASTS := {
	Cultures.VARDISH: "You stand and bang the table until the hall hears you. \"To {host}, and to the roof over all our heads.\" They drink, and bang the table back.",
	Cultures.KHARZANI: "You raise your cup when the music rests. \"To {host}'s house: may its courtyard never lack for guests.\" A poet makes a verse of it on the spot.",
	Cultures.RYUMON: "When the cup comes to you, you offer a verse instead of a toast. It is not a good verse. They are kind about it, and {host} smiles.",
}

## The host's thanks for a gift.
const GIFT_THANKS := {
	Lords.CAUTIOUS: "\"Generous. Thank you. I'll see it's put to good use.\"",
	Lords.DARING: "\"A guest who brings something! Sit by me.\"",
	Lords.HONORABLE: "\"You honour this house. It won't be forgotten.\"",
	Lords.CRUEL: "\"Hm. Better than most bring.\"",
}

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
