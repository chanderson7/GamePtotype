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

## Each dance kept as itself: the first, the second, the third (then round again).
const DANCE_MEMORIES := {
	"edda": ["You danced the midsummer reel with Edda. Nobody's feet were harmed. Mostly.",
		"A second reel with Edda. You had learned the turn; she pretended not to notice.",
		"You danced with Edda until the fiddlers stopped, and the hall went quiet around you."],
	"farid": ["You danced with Farah under the lanterns, and she stopped pretending.",
		"Farah led the slow one under the arches, and you let her.",
		"The musicians played the slow one twice for you and Farah. Someone had paid them."],
	"kaede": ["You danced with Kaede on the tatami. The book was wrong about the third step.",
		"A second dance with Kaede. You bowed correctly; she laughed anyway.",
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
	Lords.CAUTIOUS: "{name} glances at {lord} before she takes your hand, and gets the smallest of nods. She dances carefully, and well, and {lord} watches every turn.",
	Lords.DARING: "\"At last, someone who isn't a cousin.\" {name} is on the floor before you finish asking. {lord} laughs out loud from the table and bangs a cup for the fiddlers to go faster.",
	Lords.HONORABLE: "{name} accepts with a curtsey a shade more formal than the room, and leads you through the figure without a fault. At the table {lord} inclines their head to you: their {relation} has been honoured, and so have they.",
	Lords.CRUEL: "{name} takes your hand as if she expected it. \"Everyone is watching. They always are.\" {lord} smiles thinly from the table, and seems to count it as their own doing.",
}
## The round everyone joins, by culture: Regard with every lord in the hall.
const DANCE_ROUND_REGARD := 1
const DANCE_ROUND := {
	Cultures.VARDISH: "You join the reel where the line breaks, and are passed hand to hand down the whole length of the hall. By the end of it the lords have seen you make a fool of yourself with the rest of them, and like you the better for it.",
	Cultures.KHARZANI: "You step into the lantern circle and are given a place between an old emir and a girl of nine. The circle turns, and turns, and when the drums stop every face in it is smiling at every other.",
	Cultures.RYUMON: "You take your place in the second line, a fan pressed into your hand, and follow the figure a half-beat behind everyone else. Nobody says so. Several lords bow to you after, which is the same thing as saying so.",
}
## Someone you haven't met, across the hall: how she is pointed out, and what passes when
## you ask her to dance. Her first word; the story's first audience follows from it.
const DANCE_SEEN := {
	"edda": "Ask the woman in Ravensford grey to dance.",
	"farid": "Ask the envoy with the ink-stained fingers to dance.",
	"kaede": "Ask the woman reading by the screens to dance.",
}
const DANCE_MEET := {
	"edda": "She has been arguing quietly with an older man about field horses, and loses the thread when you ask. \"I'm Edda. I keep Ravensford's tallies, which is to say I keep Ravensford.\" She dances as if she has counted the steps. \"You lead a company. I've seen what companies cost a village. Come to Ravensford some day, and I'll show you the ledger.\"",
	"farid": "She looks up from the letter she was pretending not to read under the table. \"Farah. I carry Qasr Hamra's words where they need to go.\" Under the lanterns she dances better than she lets on. \"A captain who asks instead of orders. That's rare enough to be worth a second conversation. Find me at Qasr Hamra.\"",
	"kaede": "She marks her place in the scroll with a finger before she closes it. \"Kaede, of the Kitayama archive. I know the steps from a book, so forgive what follows.\" She is wrong about the third step and laughs at it. \"You'd be surprised what the old records say about captains like you. Come to Kitayama, and I'll show you.\"",
}
const DANCE_MEET_MEMORY := {
	"edda": "The night you met Edda, over a reel at someone else's feast.",
	"farid": "The night you met Farah, under another house's lanterns.",
	"kaede": "The night you met Kaede, a half-step behind the music.",
}
## Someone you've met and no more, when you ask.
const DANCE_ACQUAINTED := {
	"edda": "Edda considers it a moment longer than is polite. \"One. And you'll hear about it if you tread on me.\" She dances well, and talks of grain prices the whole way through.",
	"farid": "Farah raises an eyebrow. \"The captain remembers me. Good.\" She lets you lead, and corrects you twice, kindly.",
	"kaede": "Kaede bows. \"I have been practising, since. From a better book.\" It shows, a little.",
}
## Someone you court who isn't in the hall: where she would be.
const DANCE_ABSENT := {
	"edda": "Edda isn't here. She comes when Ravensford's household does, and is at Ravensford otherwise.",
	"farid": "Farah isn't here. She comes to Kharzan's gatherings and with Qasr Hamra's household, and is at Qasr Hamra otherwise.",
	"kaede": "Kaede isn't here. She comes when Kitayama's household does, and is at Kitayama otherwise.",
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
