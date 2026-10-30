# Bannerfall future plans

**Updated:** 2026-10-30  
**Current baseline:** Romance cast complete; Experience Packages A and B complete.

This file is the short handoff for future work. Detailed designs remain in
[`NEXT.md`](NEXT.md), [`phase-4-plan.md`](phase-4-plan.md),
[`next-features-roadmap.md`](next-features-roadmap.md), and
[`game-feel-and-immersion-roadmap.md`](game-feel-and-immersion-roadmap.md).

## Next gameplay feature: siege resolution

Implement Phase 4.3 siege resolution before adding more broad campaign systems.

1. Marshal armies reaching a hostile castle or town begin a siege.
2. Resolve walls through auto-resolve: castle defense ×1.6, town defense ×1.4.
3. A force around twice the garrison's strength should capture the settlement at least 80%
   of the time in deterministic balance tests.
4. Transfer ownership through `world.set_owner(id, realm)`.
5. Clear old defenders and leave surviving attackers as the new garrison.
6. Add village militia and siege food only within this bounded slice.
7. Show siege state, pressure and outcome through the existing settlement-condition system,
   activity feed and map presentation.

## Next experience feature: Package C — Camp feels like home

Build the company camp from current campaign facts rather than a fixed background.

- Show active captains near their companies, wounded captains resting, and dead captains only
  through the memorial.
- Tint the camp for current terrain and time of day.
- Surface at most one optional recent moment: promotion, bond rank, recovery, shortage,
  victory, defeat or death.
- Let each visible captain or moment open its existing profile, bond scene, report or memorial.
- Add restrained idle motion and camp ambience; reduced motion uses a static tableau.
- Remember dismissed moments so returning to Home does not repeat them.
- Keep all camp reactions optional and derived from saved facts; they must not advance time,
  consume RNG or change resources.

## Campaign sequence after sieges

1. **War and peace overview:** autonomous decisions, readable causes and a clear realm-status page.
2. **Mercenary contracts and lord encounters:** terms, pay, obligations, standing and direct
   conversations with named lords.
3. **Real allied assistance:** house-pact troop calls and politically valid joint battles.
4. **Prisoners and rivals:** capture, ransom, release and remembered treatment.
5. **Small settlement jobs:** bounded work for an independent company between wars.
6. **Captain development:** earned specializations and more optional bond stories.
7. **Recovery and achievements:** accessible recovery options and campaign milestones.
8. **A first fief:** landholding only after the Phase 4 campaign loop is stable.

## Later experience packages

- **Package D — Battlefield pressure:** cue priority, formation animation, clearer morale
  telegraphs and stronger terrain contact.
- **Package E — Consequences follow the company:** carry battle results into the map, camp and
  character reactions.
- **Package F — Siege presence:** blockade pressure, camp staging and capture aftermath built
  on the completed siege rules.
- **Package G — Broader cast:** distinctive lord portraits, encounter staging and authored
  supporting characters.

## Guardrails

- Keep friendship mechanically viable beside romance.
- Preserve captain mortality and battlefield bonds as separate systems.
- Derive presentation from simulation state; do not create a second history or hidden economy.
- Keep phone layouts, 150% text, reduced motion and illustrations-off behavior in every slice.
- Add one complete, testable feature at a time and update `NEXT.md` after each checkpoint.
