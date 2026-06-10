# Soul System — Godot Wiring Notes

What this pass wired into the live Godot project, and the two small things
Codex needs to finish.

## Autoloads (project.godot)
Registered after the existing gameplay autoloads, in dependency order:

```
Narrative        = res://scripts/autoload/GameState.gd   # the NARRATIVE state
Souls            = res://scripts/narrative/Souls.gd
SoulResolver     = res://scripts/narrative/SoulResolver.gd
CaelPayoff       = res://scripts/narrative/CaelPayoff.gd
SoulSystemWiring = res://scripts/narrative/SoulSystemWiring.gd
```

### Important: two GameStates
The repo has **two** GameState files:
- `scripts/systems/GameState.gd`  → autoloaded as **`GameState`** (gameplay: gold,
  runs, units, save). This is what `StageSelect._gs` points at.
- `scripts/autoload/GameState.gd`  → now autoloaded as **`Narrative`** (revelation
  tier, clarity, characters' arcs, soul_encounters, narrative_flags, signals).

The Soul scripts were repointed from `GameState.` → `Narrative.` so they read the
narrative state without colliding with gameplay state. **This is a deliberate seam.**
A future task should unify these two files; until then the bridge below keeps them
in sync. Flagged so it isn't mistaken for an accident.

## Run-count bridge
`Narrative._bridge_to_run_manager()` connects to the live `RunManager.run_started` /
`run_ended` signals, increments `Narrative.total_runs`, and re-emits the narrative
`run_started(run_number)` / `run_ended(run_number)` the Soul system listens for.
So Soul beat gating (which keys off `total_runs`) advances naturally as the player
does real runs.

## The "?" node hook (StageSelect.gd)
`_on_enter_node()` now checks `_pick_available_soul()` BEFORE a `"mystery"` node
rolls a loot sub-type. If a Soul is eligible, it shows the encounter overlay and
returns; otherwise the original cache/training/shrine/ambush flow runs unchanged.

The overlay (`_show_soul_encounter` / `_render_soul_beat`) is code-built, matching
the existing `_boon_overlay` / mystery-event pattern — no new .tscn required. On a
`COURIER_CHOICE` beat it shows **Give it to her** / **Say nothing**, which call
`SoulResolver.resolve_courier_choice()` and then render the consequence.

## TWO THINGS CODEX MUST FINISH

1. **Provide the run party.** `_current_party_ids()` and `SoulSystemWiring` both look
   for `RunState.get_party_ids()` (doesn't exist yet) and fall back to
   `Narrative.narrative_flags["current_party"]`. Implement one of:
   - add `func get_party_ids() -> Array` to `RunState.gd` returning the deployed
     unit ids, OR
   - set `Narrative.narrative_flags["current_party"]` when the player picks their
     squad at run start.
   Without this, `runs_together/<angel>` never increments, so party-gated secret
   convos (e.g. Adam's shame beat) can't unlock.

2. **Soul pick policy.** `_pick_available_soul()` currently returns the FIRST eligible
   soul. Replace with the intended policy: weighting by location/floor, the Job
   `trigger_condition` (e.g. Job appears when a party member is at min costume
   integrity), and a random/seeded choice so not every "?" is the same soul.

## Verified
- Resolver decision logic: 33/33 assertions pass (Python simulation of the same
  data + the GDScript test's assertions). See `tests/test_soul_resolver.gd`.
- Brace/indent lint clean on all touched files. NOTE: a real Godot headless
  syntax pass (`tools\check_godot_stability.cmd`) is still recommended — this
  env had no Godot binary.
