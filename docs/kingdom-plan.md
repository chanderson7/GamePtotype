# Your own kingdom: rebellion, crown lands and alliances

**Status:** first slice implemented 2026-10-31. Follows Feature 12 (a first fief).

## Player value

A landed company that has outgrown its liege can raise its own banner. The fief becomes the
seat of a new realm, the old liege comes to take it back, and the company decides which
realms to stand with, what to storm, and when to sue for peace.

## Rules (first slice)

**Raising the banner.** At its own fief, a company with renown 200 or more, no mercenary
contract and a fief it still holds can declare a crown. The fief passes to a new realm,
*the crown* (`WorldData.CROWN`), which takes the company's culture for its colors and
troops. The former liege declares war on it at once. Nothing else changes hands, and the
step cannot be undone except by losing every holding.

**Crown lands.** Every castle or town the company storms while crowned joins the crown
(the existing siege flow; `siege_realm()` returns the crown). Each day crown holdings pay
half their dues to the company's purse and half to the crown treasury, which raises their
garrisons the same way realms do. Crown holdings are drawn in brass on the map.

**War and peace.** The crown is a realm: lords at war with it treat the company as hostile,
its fief is a target for marshal armies (and the company can hold its walls), and AI war
weariness applies. After 7 days at war the company can *sue for peace* with a realm whose
weariness is at least 30; it ends with a truce and no tribute.

**Alliances.** A crown can propose an alliance to any realm at war with one of the crown's
enemies. An allied realm counts as friendly: its lords greet the company, it can ride with
their armies, and lead their assaults. An alliance ends if the crown and that realm come to
blows, or when the realm stops sharing an enemy with the crown.

**Not in this slice:** crown vassals or lords of your own, granting fiefs, a court, crown
marriages as treaties, rebellion inside your realm, or a victory condition. The sandbox
continues regardless.

## Acceptance checks

- Declaring needs the fief, the renown and no contract; the liege goes to war at once.
- Storming walls while crowned grows the crown; holdings pay the purse and treasury daily.
- Allied lords are friendly; an alliance needs a shared enemy and ends without one.
- Suing for peace needs time at war and an exhausted enemy, and leaves a truce.
- Saves keep the crown, its holdings and alliances; existing saves load unchanged.
