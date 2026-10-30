## Tunables and constants for realm politics, war weariness, truces, and treaties.
extends RefCounted

## Maximum weariness value (100 = completely exhausted).
const WEARINESS_MAX := 100.0

## Weariness gained per soldier casualty in battle or siege.
const WEARINESS_CASUALTY := 0.05

## Weariness gained when a castle or town is lost to an enemy.
const WEARINESS_LOST_HOLDING := 15.0

## Weariness gained when a bound village is burned.
const WEARINESS_LOST_VILLAGE := 3.0

## Weariness gained when a friendly lord's warband is routed in the field.
const WEARINESS_LORD_ROUTED := 5.0

## Base weariness accumulated per day at war.
const WEARINESS_DAY_AT_WAR := 0.25

## Weariness decay per day while at peace with all realms.
const WEARINESS_PEACE_DECAY := 0.50

## Weariness threshold where a realm actively seeks peace.
const PEACE_THRESHOLD := 60.0

## Winning realm weariness threshold above which it accepts peace unconditionally.
const PEACE_ACCEPT_THRESHOLD := 40.0

## Enforced truce duration in days after signing peace (no wars between them).
const TRUCE_DAYS := 30

## Duration in days that the defeated realm pays tribute.
const TRIBUTE_DAYS := 20

## Base daily silver paid in tribute by the defeated realm.
const TRIBUTE_BASE := 25

## Extra daily tribute per point of weariness difference between the realms.
const TRIBUTE_PER_WEARINESS_DIFF := 0.5

## Maximum daily tribute a defeated realm can be forced to pay.
const TRIBUTE_MAX := 75

## Maximum weariness a realm can have to voluntarily declare war.
const WAR_READY_WEARINESS := 25.0

## Mainland fortified holdings (castles and towns). Total = 6.
## Holding 4 or more (>= 55% / more than half) triggers Ryumon intervention.
const MAINLAND_TOTAL_SEATS := 6
const HEGEMONY_SEATS_THRESHOLD := 4
const MAINLAND_SEATS := ["highcliff", "ravensford", "marchgate", "khalun", "zeyra", "qasr_hamra"]
