## The lords of the three realms: their names, bearings, warbands and purses. Pure data
## and small formulas; the world sim moves them. Tune the lords here.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")
const Troops = preload("res://scripts/data/troops.gd")

## Lords a realm has besides its ruler.
const PER_REALM := 4

## How a lord goes about the war, which weights what he chooses to do.
const DARING := "Daring"         # raids at worse odds, and further from home
const CAUTIOUS := "Cautious"     # keeps to his own lands, and goes home sooner
const HONORABLE := "Honorable"   # hunts bandits and defends before he raids
const CRUEL := "Cruel"           # raids whenever he can
const BEARINGS := [DARING, CAUTIOUS, HONORABLE, CRUEL]
const BEARING_TEXT := {
	DARING: "takes risks for glory",
	CAUTIOUS: "keeps to his own lands",
	HONORABLE: "guards the roads before he raids",
	CRUEL: "burns villages whenever he can",
}

## What a realm calls its lords, and the houses they come from.
const TITLE := {Cultures.VARDISH: "Lord", Cultures.KHARZANI: "Emir", Cultures.RYUMON: "Daimyo"}
const HOUSES := {
	Cultures.VARDISH: ["Ashcombe", "Brightwater", "Caldmoor", "Dunmere", "Eastbrook", "Fairholt"],
	Cultures.KHARZANI: ["al-Sahir", "ibn Rashad", "al-Qamari", "ibn Tahir", "al-Zeyrani", "ibn Malik"],
	Cultures.RYUMON: ["Kuroda", "Hosokawa", "Matsuda", "Ikeda", "Sakai", "Mori"],
}

## A lord's warband: squads by renown, between these, like a band's but bigger and more
## often trained.
const SQUADS_MIN := 5
const SQUADS_MAX := 9
const RENOWN_PER_SQUAD := 40
const START_RENOWN := [40, 80, 120, 160]
## Share of a lord's squads that are trained branches, at no renown and at most.
const TRAINED_SHARE := 0.2
const TRAINED_SHARE_MAX := 0.6

## Silver. A realm's treasury takes in what each kind of place it holds pays a day (a
## burned village pays nothing), starts with TREASURY_START, and pays its lords' wages, at
## WAGE_SHARE of what you'd pay (their men are fed from the land). A lord keeps the loot he
## takes, starts with START_SILVER, and pays for his recruits from it, the treasury making
## up what he can't.
const INCOME := {"village": 40, "castle": 90, "town": 220}
const TREASURY_START := 3000
const WAGE_SHARE := 0.5
const START_SILVER := 300
## Lords' recruits come out of the treasury only while it keeps this much back for wages.
const TREASURY_RESERVE := 2000
## Standing garrisons: towns house more men, castles a greater share of trained troops.
## Each role is one squad; the first TRAINED squads use their culture's first branch.
const GARRISON_ROLES := {
	"castle": [Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS, Troops.ARCHERS],
	"town": [Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS,
		Troops.INFANTRY, Troops.SPEARMEN, Troops.ARCHERS],
}
const GARRISON_TRAINED := {"castle": 2, "town": 1}
## Start half staffed. Daily recruits are paid at recruit prices after lords' upkeep
## and refills, leaving TREASURY_RESERVE untouched. No recruitment debt is carried.
const GARRISON_START_SHARE := 0.5
const GARRISON_RECRUITS_PER_DAY := {"castle": 4, "town": 6}
## Renown stops growing here.
const RENOWN_MAX := 400

## Map units an hour.
const SPEED := 36.0
## Hours between a lord's decisions.
const THINK_HOURS := 3.0
## He goes home to refill below this share of his full warband, and rides out again above
## REFILLED. At home he gets back this share a day, paid for at recruit prices.
const REFILL_BELOW := 0.5
const REFILLED := 0.9
const REFILL_PER_DAY := 0.25
## A lord who loses his warband is back at his seat, with what's left of it, this many
## hours later.
const REGROUP_HOURS := 24.0
## Raiding a village takes this many hours; then it burns, and pays nothing and offers no
## recruits for BURNED_DAYS. The raider takes this much silver.
const RAID_HOURS := 6.0
const BURNED_DAYS := 7
const RAID_LOOT := 150
## How far, in hours of riding, a lord will go for each job.
const HUNT_HOURS := 6.0
const DEFEND_HOURS := 18.0
const RAID_HOURS_AWAY := 30.0
## Hours a patrolling lord lingers at each place he visits.
const LINGER_MIN := 2.0
const LINGER_MAX := 6.0


static func title(culture: String) -> String:
	return String(TITLE.get(culture, "Lord"))


## How many squads a lord of `renown` leads.
static func squads_for(renown: int) -> int:
	return clampi(SQUADS_MIN + renown / RENOWN_PER_SQUAD, SQUADS_MIN, SQUADS_MAX)


## The share of his squads that are trained, by renown.
static func trained_share(renown: int) -> float:
	return minf(TRAINED_SHARE_MAX, TRAINED_SHARE + renown * 0.002)
