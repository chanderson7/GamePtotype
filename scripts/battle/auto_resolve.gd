## Settles a fight without playing it: for battles you choose not to command. Pure
## logic, fast enough for the map to settle any number of fights.
##
## Each side's strength is the sum over its squads of men, a per-man value for the troop
## type, veterancy (which raises both health and damage, so it counts twice), and how
## well the type does against the other side's mix (the counter bonuses, softened). Like
## a real battle the side with more strength usually wins, and the closer the fight the
## more the winner loses. The constants are fitted to the full battle sim; the test suite
## checks they still agree with it.
extends RefCounted

const Troops = preload("res://scripts/data/troops.gd")
const Captains = preload("res://scripts/data/captains.gd")
const Units = preload("res://scripts/data/units.gd")

## What one man of each type is worth in a stand-up fight.
const VALUE := {
	Troops.INFANTRY: 1.0,
	Troops.SPEARMEN: 0.85,
	Troops.ARCHERS: 1.0,
	Troops.CAVALRY: 1.35,
}
## How much of a counter bonus carries into the reckoning (1 = all of it).
const COUNTER_WEIGHT := 0.5
## Luck on the day: each side's strength is scaled by a factor this far either side of 1.
const LUCK := 0.12
## Share of its men the winner loses, at a ratio of strengths r (loser / winner):
## WIN_LOSS_SCALE * r^WIN_LOSS_POWER. Fitted to 240 battles of the full sim: about 3%
## in a rout, about a quarter in an even fight.
const WIN_LOSS_SCALE := 0.30
const WIN_LOSS_POWER := 1.5
## Share the loser loses: LOSE_LOSS_BASE + LOSE_LOSS_SCALE * r. In the full sim a broken
## army loses a little under half its men whatever the odds; the rest get away.
const LOSE_LOSS_BASE := 0.47
const LOSE_LOSS_SCALE := -0.06
## When you send your men in without commanding them, they lose this many more.
const UNLED := 1.25


## A side's fighting strength against `foes`. Squads are {type, men, xp, level?}.
## Modified by terrain ground advantage and site conditions when `site` is given.
static func strength(army: Array, foes: Array, site = null, is_player: bool = true) -> float:
	var foe_men := 0.0
	var mix := {}
	for f in foes:
		var m := float(f.get("men", 0))
		foe_men += m
		mix[f["type"]] = float(mix.get(f["type"], 0.0)) + m
	var total := 0.0
	var total_men := 0.0
	var cav_men := 0.0
	var archer_men := 0.0
	for s in army:
		var men := float(s.get("men", 0))
		if men <= 0.0:
			continue
		total_men += men
		var type := String(s["type"])
		if type == Troops.CAVALRY:
			cav_men += men
		elif type == Troops.ARCHERS:
			archer_men += men
		var level := int(s.get("level", Troops.level_for(int(s.get("xp", 0)))))
		var power := Troops.power_for(level)
		var counter := 1.0
		if foe_men > 0.0:
			counter = 0.0
			var bonus: Dictionary = Troops.stats(type)["bonus"]
			for t in mix:
				var b := float(bonus.get(t, 1.0))
				counter += float(mix[t]) / foe_men * (1.0 + (b - 1.0) * COUNTER_WEIGHT)
		total += men * float(VALUE.get(type, 1.0)) * power * power * counter

		var unit_id: String = s.get("unit", "")
		if unit_id != "" and Units.has(unit_id):
			var u_mech := Units.mechanics(unit_id, level)
			var armor_factor := 1.0 + float(u_mech.get("armor", 0.0)) * 0.5
			var pierce_factor := 1.0 + float(u_mech.get("piercing", 0.0)) * 0.25
			var sweep_factor := 1.15 if u_mech.get("sweep", false) else 1.0
			var javelin_factor := 1.1 if int(u_mech.get("javelins", 0)) > 0 else 1.0
			var steady_factor := 1.08 if u_mech.get("steady", false) else 1.0
			total += men * float(VALUE.get(type, 1.0)) * power * power * counter * (armor_factor * pierce_factor * sweep_factor * javelin_factor * steady_factor - 1.0)

	if site is Dictionary:
		var st: String = site.get("type", "open")
		var fair: bool = bool(site.get("fair", true))
		if not fair and not is_player:
			total *= 1.10 # Enemy holds the better ground
		if total_men > 0.0:
			var cav_share := cav_men / total_men
			var archer_share := archer_men / total_men
			if st == "river":
				total *= (1.0 - 0.15 * cav_share) # Fords hurt cavalry-heavy armies
			elif st == "woods":
				total *= (1.0 - 0.10 * cav_share + 0.05 * archer_share)

	return total


## The expected outcome with no luck: {player_wins, ratio, lost} where ratio is the
## weaker side's strength over the stronger's, and lost about how many men you'd lose
## sending them in without you.
static func odds(player: Array, enemy: Array, site = null) -> Dictionary:
	var a := strength(player, enemy, site, true)
	var b := strength(enemy, player, site, false)
	var r := minf(a, b) / maxf(1.0, maxf(a, b))
	var shares := _loss_shares(r)
	var men := 0
	for s in player:
		men += int(s.get("men", 0))
	var share: float = shares[0] if a >= b else shares[1]
	return {"player_wins": a >= b, "ratio": r, "player": a, "enemy": b,
		"lost": int(round(men * minf(1.0, share * UNLED)))}


## Settle the fight. `led` is false when the player sends their men in without
## commanding them, which costs extra men. Returns the same shape as
## BattleSim.result_for(PLAYER), plus "enemy_squads" with the enemy's survivors.
static func resolve(player: Array, enemy: Array, rng: RandomNumberGenerator, led: bool = false, site = null) -> Dictionary:
	var a := strength(player, enemy, site, true) * (1.0 + rng.randf_range(-LUCK, LUCK))
	var b := strength(enemy, player, site, false) * (1.0 + rng.randf_range(-LUCK, LUCK))
	var won := a >= b
	var loss := _loss_shares(minf(a, b) / maxf(1.0, maxf(a, b)))
	var mine: float = loss[0] if won else loss[1]
	var theirs: float = loss[1] if won else loss[0]
	if not led:
		mine = minf(1.0, mine * UNLED)
	var squads := {}
	var lost := 0
	var enemy_lost := 0
	var enemy_squads := {}
	for s in enemy:
		var men := int(s.get("men", 0))
		var dead := _losses(men, theirs, rng)
		enemy_lost += dead
		enemy_squads[int(s["id"])] = {"men": men - dead}
	# Kills go to your squads by their share of your strength.
	var shares := []
	var share_total := 0.0
	for s in player:
		var share := strength([s], enemy)
		shares.append(share)
		share_total += share
	var kills_left := enemy_lost
	for i in player.size():
		var s: Dictionary = player[i]
		var men := int(s.get("men", 0))
		var dead := _losses(men, mine, rng)
		lost += dead
		var kills := int(round(enemy_lost * shares[i] / maxf(1.0, share_total)))
		kills = mini(kills, kills_left)
		kills_left -= kills
		var entry := {"men": men - dead, "kills": kills}
		var c = s.get("captain")
		if typeof(c) == TYPE_DICTIONARY and int(c.get("wounded", 0)) == 0:
			entry["captain"] = _captain_fate(c, men, dead, rng)
		squads[int(s["id"])] = entry
	return {"won": won, "reason": "auto", "squads": squads, "lost": lost, "killed": enemy_lost,
		"time": 0.0, "bonds": {}, "enemy_squads": enemy_squads}


## [winner's, loser's] share of men lost when the weaker side has `r` of the stronger's
## strength.
static func _loss_shares(r: float) -> Array:
	return [WIN_LOSS_SCALE * pow(r, WIN_LOSS_POWER), LOSE_LOSS_BASE + LOSE_LOSS_SCALE * r]


## Men lost from a squad of `men` at a loss rate `rate`, give or take.
static func _losses(men: int, rate: float, rng: RandomNumberGenerator) -> int:
	var expected := men * clampf(rate * rng.randf_range(0.7, 1.3), 0.0, 1.0)
	return clampi(int(round(expected)), 0, men)


## A captain falls with a chance that grows with how badly the squad was hurt; then the
## same death roll as on the field, with a friendly squad assumed close by.
static func _captain_fate(c: Dictionary, men: int, dead: int, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"id": int(c["id"]), "fate": "fine", "roll": 0, "needed": 0, "kills": 0, "words": ""}
	var hurt := float(dead) / maxf(1.0, float(men))
	if rng.randf() >= hurt * 0.6:
		return out
	var chance := Captains.death_chance(c, men - dead >= men * 0.5, true)
	var roll := rng.randi_range(1, 100)
	out["roll"] = roll
	out["needed"] = chance + 1
	out["fate"] = "killed" if roll <= chance else "wounded"
	var words: Array = Captains.LAST_WORDS if out["fate"] == "killed" else Captains.WOUNDED_WORDS
	out["words"] = words[rng.randi_range(0, words.size() - 1)]
	return out
