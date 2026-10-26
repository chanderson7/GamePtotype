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

## Men standing among trees: blows struck at them from outside the wood land this much
## softer (the trunks break up the attack), and arrows aimed in (below) often hit a trunk.
const WOODS_MELEE_COVER := 0.80

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

## Fighting on a slope: a blow struck straight up a full slope (one rising SLOPE_MAX_RISE
## over SLOPE_SAMPLE_DIST) loses this share of its force, and one struck down it gains as
## much. It goes by the slope where the striker stands, not by how much higher he stands
## than the man he hits: two men close enough to trade blows are never far apart in height.
const SLOPE_DAMAGE := 0.40

## Men standing in a shallow ford: the blows they take land harder (+25%), and their own
## land softer (-20%), with the water round their legs.
const WATER_DAMAGE_TAKEN_MULT := 1.25
const WATER_DAMAGE_DEALT_MULT := 0.80


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


## Melee damage multiplier for a blow struck on `slope` (positive: uphill, at most 1).
static func slope_damage_mult(slope: float) -> float:
	return 1.0 - SLOPE_DAMAGE * clampf(slope, -1.0, 1.0)
