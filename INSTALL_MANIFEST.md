# The Appointed — Soul System: install manifest (refreshed)

`appointed_soul_system.zip` mirrors your repo's folder structure. Unzip at the
**repo root** and files land in the right place.

## How to apply
1. Back up / commit current repo state first.
2. Unzip `appointed_soul_system.zip` at the repo root, overwriting.
3. Open in Godot 4; let it parse (or run `godot --headless --check-only`).
4. Run tests: `godot --headless -s res://tests/test_soul_resolver.gd`
   -> expect "45 pass, 0 fail" (33 resolver + 1 run-gate + 3 wiring + 8 pick-policy*).
   (*Section D asserts run headlessly via the Souls autoload stub.)

## NEW files
- godot/scripts/narrative/Souls.gd              — 7 souls + floor affinity + triggers
- godot/scripts/narrative/SoulResolver.gd        — beat selection per "?" visit
- godot/scripts/narrative/CaelPayoff.gd          — Adam->Cael recognition payoff
- godot/scripts/narrative/SoulSystemWiring.gd    — run tracking / endgame seal / cooldown
- godot/tests/test_soul_resolver.gd              — headless tests
- docs/lore/soul-encounters.md                   — Soul system spec
- docs/lore/soul-system-wiring-notes.md          — wiring + open follow-ups
- docs/lore/vessel-strain-design.md              — NEW mechanic design note (not built)

## MODIFIED files (overwrite existing)
- godot/project.godot                  — adds 4 soul autoloads (merge if you've edited it)
- godot/scripts/systems/GameState.gd   — unified narrative+gameplay state, save extended
- godot/scripts/roguelite/RunManager.gd — total_runs++ on start, resets soul_seen_this_run,
                                          emits narrative run_started/run_ended
- godot/scripts/roguelike/RunState.gd  — get_party_ids()
- godot/scripts/ui/StageSelect.gd      — "?" soul check, seed-weighted pick policy,
                                          encounter overlay + courier buttons

## REFERENCE (already in your repo, included for completeness)
- archive_react/historicalSouls.js     — original JS souls (with Adam/Eve new beats)

## DO NOT
- Do not autoload scripts/autoload/GameState.gd (merged & archived to
  archive_react/superseded/). Re-adding re-splits state.

## Soul-pick policy (this update)
- ~55% of eligible "?" nodes become Souls, but AT LEAST ONE soul is guaranteed per
  run (soul_seen_this_run gate, reset at run start).
- Souls weighted by floor affinity (Hades-style regions): adam/eve floors 1-3,
  cain/elijah 2-4, moses/david 3-5, job 1-5.
- Seed-deterministic: same run seed + node = same result; different seeds vary.
- Job ("He Who Held") is a PRIORITY appearance: it jumps the queue whenever a party
  member's Costume Integrity <= 20 (someone's raw and cracked), rather than competing.

## Three progression axes (do not conflate — see vessel-strain-design.md)
1. Job trees (built): JP unlocks jobs.
2. Costume Integrity (built): one-way narrative meter; gates Job-the-soul.
3. Vessel Strain (proposed): recharging class-rotation pressure; ends at shadow
   integration. NOT built yet.
