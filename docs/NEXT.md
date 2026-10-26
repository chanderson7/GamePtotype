# Where to pick up

For a fresh session: read this, then `docs/phase-4-plan.md`. Don't re-read the whole
codebase; the plan names the files each step touches.

## State (on `main`)

- Phase 3 is done; every gate passes.
- Phase 4.1 (owners, wars, 21 settlements, save v5) and 4.2 (lords on the map) are done:
  see their "As built" notes in `docs/phase-4-plan.md`.
- **Next: 4.3**, one piece per session, committing and pushing after each:
  1. Garrisons in castles and towns, grown daily from the realm treasury
     (`realms[r]["treasury"]` in `scripts/world/world_sim.gd`; tunables in
     `scripts/data/lords.gd`).
  2. Armies: a realm at war has its marshal (highest-renown lord) gather 2–3 lords and
     ride at an enemy castle or town.
  3. Sieges by auto-resolve with walls (castle ×1.6, town ×1.4), then
     `world.set_owner(id, realm)`. Gate: twice the garrison's strength takes it ≥ 80%.
- Then 4.4 (war and peace), 4.5 (contracts and lord encounters), 4.6, 4.7.

## How to work here

- Godot 4.7 headless. If it isn't installed, download the standard Linux build into the
  scratchpad. Always run with `timeout`: a script that fails to parse leaves Godot idle
  forever.
- Tests: `godot --headless --path . --script res://tests/run_tests.gd` (about 10 minutes).
  `-- --balance` adds the slow gates (about an hour); run it only at the end of a phase.
- To run a few checks, copy `run_tests.gd` with an `_init()` that calls only those
  `_check_*` functions into `tests/_partial_*.gd` (ignored locally), and delete it after.
- `--check-only` can't see autoloads (`GameState`, `Sound`): "Identifier not found:
  GameState" is expected.
- Godot's JSON doesn't read every float back to the last bit; compare saved worlds as
  the lord save test does, not bit for bit.
- Battle gates are noisy: 48 battles move about ±10 points by chance. Check a surprising
  result on a second batch of seeds before tuning anything.
- The container can restart and kill background runs; re-run them.
- Don't commit `.uid` or `.import` files.
