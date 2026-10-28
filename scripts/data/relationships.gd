## Constants, thresholds, status labels, and pure eligibility helpers for personal
## relationships, courtships, marriages, and house pacts. Pure data and formulas.
extends RefCounted

const Cultures = preload("res://scripts/data/cultures.gd")

## Relationship states.
const UNKNOWN := "unknown"
const ACQUAINTED := "acquainted"
const COURTING := "courting"
const COMMITTED := "committed"
const ENGAGED := "engaged"
const MARRIED := "married"
const FRIENDSHIP := "friendship"
const ENDED := "ended"

## Trust range: 0 to 100.
const TRUST_MIN := 0
const TRUST_MAX := 100
const TRUST_PUBLIC_WEDDING := 60
const TRUST_PRIVATE_VOWS := 60
const TRUST_INTRO_REWARD := 10
const TRUST_PERSONAL_REWARD := 15
const TRUST_SHARED_REWARD := 15
const TRUST_CH4_HONEST := 15
const TRUST_CH4_BREACH := -10
const TRUST_CH4_REPAIR := 25
const TRUST_CH5_FINAL := 10
const TRUST_BREACH_PENALTY := -20

## House standing range: -100 to 100.
const STANDING_MIN := -100
const STANDING_MAX := 100
const STANDING_PACT_THRESHOLD := 25
const STANDING_WEDDING_THRESHOLD := 25
const STANDING_PACT_BONUS := 10
const STANDING_PRIVATE_VOWS_PENALTY := -10
const STANDING_BREACH_PENALTY := -25

## Ceremonies.
const CEREMONY_HOURS := 6.0
const PUBLIC_CEREMONY_SILVER := 100
const PUBLIC_CEREMONY_FOOD := 100
const PRIVATE_CEREMONY_SILVER := 0
const PRIVATE_CEREMONY_FOOD := 0

## Escrow & Support Projects.
const MAX_ESCROW_SPONSOR := 300
const ESCROW_EXPIRY_DAYS := 7
const ESCROW_EXPIRY_HOURS := 168.0

## Emergency Household Grant.
const GRANT_MAX_SILVER := 150
const LORD_MIN_RESERVE := 300
const GRANT_COOLDOWN_DAYS := 14
const GRANT_COOLDOWN_HOURS := 336.0

## Max active pacts (one per candidate house).
const MAX_PACTS := 3


static func trust_label(trust: int) -> String:
	if trust >= 70:
		return "Devoted"
	elif trust >= 50:
		return "Trusting"
	elif trust >= 25:
		return "Reserved"
	return "Wary"


static func standing_label(standing: int) -> String:
	if standing >= 60:
		return "Allied"
	elif standing >= 25:
		return "Favorable"
	elif standing >= 0:
		return "Neutral"
	elif standing >= -25:
		return "Suspicious"
	return "Hostile"


static func status_label(status: String) -> String:
	match status:
		UNKNOWN: return "Unknown"
		ACQUAINTED: return "Acquainted"
		COURTING: return "Courting"
		COMMITTED: return "Committed"
		ENGAGED: return "Engaged"
		MARRIED: return "Married"
		FRIENDSHIP: return "Sworn Friend"
		ENDED: return "Parted"
		_: return status.capitalize()


## Whether courtship can begin with this candidate.
static func can_court(rel: Dictionary, candidate: Dictionary, invitations_enabled: bool, current_partner_id: String) -> Dictionary:
	if not invitations_enabled:
		return {"ok": false, "reason": "Romance invitations are disabled in Settings."}
	if current_partner_id != "" and current_partner_id != String(candidate.get("id", "")):
		return {"ok": false, "reason": "You are already courting or wed to someone else."}
	var status: String = rel.get("status", UNKNOWN)
	if status == MARRIED:
		return {"ok": false, "reason": "Already married."}
	if status == ENDED:
		return {"ok": false, "reason": "You have parted ways."}
	return {"ok": true, "reason": ""}


## Check whether public marriage can proceed.
static func can_marry_public(rel: Dictionary, house: Dictionary) -> Dictionary:
	var trust: int = int(rel.get("trust", 0))
	var standing: int = int(house.get("standing", 0))
	var romantic: bool = bool(rel.get("romantic_intent", false))
	if not romantic:
		return {"ok": false, "reason": "Mutual romantic intent has not been chosen."}
	if trust < TRUST_PUBLIC_WEDDING:
		return {"ok": false, "reason": "Requires at least %d trust (currently %d)." % [TRUST_PUBLIC_WEDDING, trust]}
	if standing < STANDING_WEDDING_THRESHOLD:
		return {"ok": false, "reason": "Requires at least %d house standing (currently %d)." % [STANDING_WEDDING_THRESHOLD, standing]}
	if bool(rel.get("strained", false)):
		return {"ok": false, "reason": "Unresolved breach between you; resolve it first."}
	return {"ok": true, "reason": ""}


## Check whether private vows can proceed.
static func can_marry_private(rel: Dictionary) -> Dictionary:
	var trust: int = int(rel.get("trust", 0))
	var romantic: bool = bool(rel.get("romantic_intent", false))
	if not romantic:
		return {"ok": false, "reason": "Mutual romantic intent has not been chosen."}
	if trust < TRUST_PRIVATE_VOWS:
		return {"ok": false, "reason": "Requires at least %d trust (currently %d)." % [TRUST_PRIVATE_VOWS, trust]}
	if bool(rel.get("strained", false)):
		return {"ok": false, "reason": "Unresolved breach between you; resolve it first."}
	return {"ok": true, "reason": ""}


## Check whether sworn friendship pact can proceed.
static func can_swear_friendship(rel: Dictionary, house: Dictionary) -> Dictionary:
	var standing: int = int(house.get("standing", 0))
	if standing < STANDING_PACT_THRESHOLD:
		return {"ok": false, "reason": "Requires at least %d house standing (currently %d)." % [STANDING_PACT_THRESHOLD, standing]}
	if bool(rel.get("strained", false)):
		return {"ok": false, "reason": "Unresolved breach with household; resolve it first."}
	return {"ok": true, "reason": ""}


## Check emergency grant eligibility.
static func can_grant(lord: Dictionary, current_hour: float, last_grant_hour: float) -> Dictionary:
	if current_hour < last_grant_hour + GRANT_COOLDOWN_HOURS:
		var days_left := ceilf((last_grant_hour + GRANT_COOLDOWN_HOURS - current_hour) / 24.0)
		return {"ok": false, "reason": "Household grant is on cooldown (%d days remaining)." % int(days_left)}
	var purse: int = int(lord.get("silver", 0))
	var available: int = purse - LORD_MIN_RESERVE
	if available <= 0:
		return {"ok": false, "reason": "Lord's purse is too low (must retain at least %d silver)." % LORD_MIN_RESERVE}
	var amount := mini(GRANT_MAX_SILVER, available)
	return {"ok": true, "amount": amount, "reason": ""}
