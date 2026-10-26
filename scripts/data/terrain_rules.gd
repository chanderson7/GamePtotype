## Tunable numbers for battlefield terrain.
##
## Controls how hills, woods, river fords, and rocky passes alter troop movement,
## missile ranges, melee strikes, charges, and morale.
extends RefCounted

## Speed multiplier for foot soldiers moving through woods (25% slower).
const WOODS_SPEED_FOOT := 0.75
## Speed multiplier for cavalry moving through woods (50% slower).
const WOODS_SPEED_HORSE := 0.50
## Speed multiplier for troops wading through a shallow river ford (50% slower).
const FORD_SPEED := 0.50

## Chance (50%) an incoming arrow aimed into woods hits tree trunks or branches.
const WOODS_ARROW_BLOCK := 0.50
## Morale shock multiplier (50%) for archery volleys hitting targets sheltered in woods.
const WOODS_VOLLEY_SHOCK := 0.50

## Slope movement penalty factor: uphill speed is speed * (1.0 - 0.3 * slope).
const UPHILL_SLOPE_PENALTY := 0.30
## Slope movement bonus factor: downhill speed is speed * (1.0 + 0.1 * slope).
const DOWNHILL_SLOPE_BONUS := 0.10
## Distance in arena units ahead to sample elevation when calculating slope.
const SLOPE_SAMPLE_DIST := 60.0
## Height rise over SLOPE_SAMPLE_DIST that represents a full 1.0 (steep) slope.
const SLOPE_MAX_RISE := 0.30

## Archer range multiplier factor per unit height difference: range * (1.0 + 0.5 * max(0, dh)).
const HEIGHT_RANGE_FACTOR := 0.50
## Maximum bonus range an elevated shooter can gain (+25%).
const HEIGHT_RANGE_CAP := 0.25

## Melee damage scaling factor: dmg * (1.0 + 0.5 * clamp(att_h - def_h, -0.5, 0.5)).
const HEIGHT_DAMAGE_FACTOR := 0.50
## Maximum height advantage difference considered for damage bonus/penalty.
const HEIGHT_DAMAGE_CLAMP := 0.50

## Damage multiplier on troops fighting in shallow water (+25% damage taken).
const WATER_DAMAGE_TAKEN_MULT := 1.25


## Multiplier on movement speed based on slope in the direction of travel.
## Positive slope is uphill, negative is downhill.
static func slope_speed_mult(slope: float) -> float:
	if slope > 0.0:
		return maxf(0.1, 1.0 - UPHILL_SLOPE_PENALTY * slope)
	elif slope < 0.0:
		return 1.0 + DOWNHILL_SLOPE_BONUS * (-slope)
	return 1.0


## Range multiplier for ranged units based on height advantage.
## diff = shooter_height - target_height.
static func height_range_mult(diff: float) -> float:
	var boost := maxf(0.0, diff) * HEIGHT_RANGE_FACTOR
	return 1.0 + minf(HEIGHT_RANGE_CAP, boost)


## Melee damage multiplier based on attacker vs defender elevation.
## Uphill attackers do less damage; downhill attackers do more.
static func height_damage_mult(att_h: float, def_h: float) -> float:
	var diff := clampf(att_h - def_h, -HEIGHT_DAMAGE_CLAMP, HEIGHT_DAMAGE_CLAMP)
	return 1.0 + HEIGHT_DAMAGE_FACTOR * diff
