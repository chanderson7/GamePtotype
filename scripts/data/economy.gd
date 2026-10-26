## The warband's economy: what men cost to hire, pay, feed and train, what beating
## bandits brings in, and how renown grows the warband. Pure data and small formulas.
## Tune the campaign's pace here.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")
const Units = preload("res://scripts/data/units.gd")

## What a new warband starts with.
const START_SILVER := 400
const START_FOOD_DAYS := 5

## Silver per man to hire a fresh recruit, or to replace a man lost.
const RECRUIT_COST := {
	Troops.INFANTRY: 9,
	Troops.SPEARMEN: 8,
	Troops.ARCHERS: 11,
	Troops.CAVALRY: 22,
}
## Silver per man per day, for a squad at level 1. Each level above adds half again.
const WAGE := {
	Troops.INFANTRY: 0.6,
	Troops.SPEARMEN: 0.6,
	Troops.ARCHERS: 0.75,
	Troops.CAVALRY: 1.2,
}
const WAGE_PER_LEVEL := 0.5
## Training a squad up a level costs this share of its recruit price per man, times the
## level it's training from.
const TRAIN_SHARE := 0.75

## Every man eats one ration a day. Villages sell food cheaper than towns.
const FOOD_PRICE := {"village": 0.2, "town": 0.3, "castle": 0.3}
## A warband that can't pay or feed its men loses this share of every squad each day.
const DESERTION := 0.1

## Beating a bandit band: a bounty, plus silver and food taken from each man cut down.
const BOUNTY := 120
const SILVER_PER_KILL := 8
const FOOD_PER_KILL := 2
const RENOWN_PER_BAND := 10
const KILLS_PER_RENOWN := 4

## Squads you can lead: SQUADS_BASE, one more for every RENOWN_PER_SQUAD renown, up to
## MAX_SQUADS.
const SQUADS_BASE := 6
const RENOWN_PER_SQUAD := 60
const MAX_SQUADS := 12

## Recruit offers in each settlement come back this many hours after they're taken.
const OFFER_REFRESH_HOURS := 72.0


static func recruit_cost(type: String, men: int) -> int:
	var role := Units.role(type) if Units.has(type) else type
	var mult := Units.cost_mult(type) if Units.has(type) else 1.0
	return int(ceil(int(RECRUIT_COST.get(role, 10)) * mult * men))


static func daily_wage(squad: Dictionary) -> float:
	var unit_id: String = squad.get("unit", "")
	var role: String = Units.role(unit_id) if Units.has(unit_id) else String(squad.get("type", Troops.INFANTRY))
	var wage_mult: float = Units.wage_mult(unit_id) if Units.has(unit_id) else 1.0
	var level := int(squad.get("level", 1))
	var per_man := float(WAGE.get(role, 1.0)) * (1.0 + WAGE_PER_LEVEL * (level - 1)) * wage_mult
	return per_man * int(squad.get("men", 0))


## Silver to train a squad from its level to the next.
static func train_cost(squad: Dictionary, target_unit_id: String = "") -> int:
	var unit_id: String = target_unit_id if target_unit_id != "" else squad.get("unit", "")
	var role: String = Units.role(unit_id) if Units.has(unit_id) else String(squad.get("type", Troops.INFANTRY))
	var cost_mult: float = Units.cost_mult(unit_id) if Units.has(unit_id) else 1.0
	var level := int(squad.get("level", 1))
	return int(ceil(RECRUIT_COST.get(role, 10) * cost_mult * TRAIN_SHARE * level * int(squad.get("men", 0))))


static func squad_cap(renown: int) -> int:
	return mini(MAX_SQUADS, SQUADS_BASE + renown / RENOWN_PER_SQUAD)


## What beating a band of `killed` men brings in: {silver, food, renown}.
static func spoils(killed: int) -> Dictionary:
	return {"silver": BOUNTY + SILVER_PER_KILL * killed, "food": FOOD_PER_KILL * killed,
		"renown": RENOWN_PER_BAND + killed / KILLS_PER_RENOWN}
