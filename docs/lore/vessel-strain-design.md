# Vessel Strain — future mechanic (design note, NOT yet built)

Captured from a design conversation so it isn't lost. This is distinct from
**Costume Integrity** and must NOT reuse that field/name.

## The three separate axes (keep them separate)
1. **Job trees** (BUILT): JP unlocks advanced jobs; `JobTreeData.meets_prerequisites`.
   Pure combat progression. "Jobs earned by leveling other jobs."
2. **Costume Integrity** (BUILT): one-way narrative meter, 100 -> 0, drops when an
   angel's human disguise cracks (Soul met, crack event, Mirror, True Name frag).
   Measures "how much you still hide from yourself." Job (the soul) appears when a
   party member's Costume Integrity <= 20.
3. **Vessel Strain** (PROPOSED, this note): a gameplay resource that DRAINS as you
   keep running the same job on a character and RECHARGES while they rest in other
   classes. Measures "how long you can wear one face before you must try another."

## Vessel Strain behavior
- Each character accrues strain on their *currently equipped job* as runs/battles use it.
- At a low threshold, that job is temporarily locked ("the vessel needs to rest"),
  forcing the player to rotate to another class for that character.
- Strain recharges while the job is unused across runs.
- **Payoff:** once a character completes their **shadow integration** (their four-beat
  arc -> final job), they stop losing strain — they've earned the right to be that
  thing without it costing them. This is the mechanical reward for theme completion.

## Why separate from Costume Integrity
Overloading one field with two meanings (permanent self-knowledge vs. recharging
class-rotation pressure) would reintroduce exactly the kind of dual-meaning bug the
GameState unification removed. Different names, different fields, different curves.

## Open questions for when we build it
- Strain rate per battle vs. per run? Per-job or per-character pool?
- Does heat/difficulty affect drain?
- Where does "shadow integration complete" get recorded (likely a narrative_flag
  per character, set when their final job unlocks)?
