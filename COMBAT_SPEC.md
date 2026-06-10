# Combat Spec v1 — The Appointed: As Above

Status: **Approved design contract** (June 2026). Godot 4.6 / GDScript only. No JSON data files, no React/JS patterns. New data lives in GDScript constants or Godot Resources, matching `EliteSystem.gd` / `JobTreeData.gd` conventions.

The combat identity in one sentence:
> **CT turns + temper/ether mitigation + two-way Break/Overwhelm + timed SURGE/DEFLECT inputs that deal break damage, build statuses, and carry purchasable passives.**

---

## 1. Layer map — what each system answers

| System | Question it answers | State |
|---|---|---|
| CT turn order (`TurnOrder.gd`) | *When do I act?* | ✅ Built |
| Temper / Ether (`Unit.gd`, `CombatFormula.gd`) | *How much damage gets through?* | ✅ Built (mitigation role) |
| Break / Overwhelm | *Who loses turn economy and becomes vulnerable?* | ❌ To build |
| SURGE / DEFLECT | *Where do execution skill, break damage, and statuses come from?* | 🔶 Step 1 (this session) |
| Status buildup | *How do disables land?* | ❌ To build (replaces % chance) |
| Archetype passives | *Why do enemy compositions matter?* | ❌ To build (layers onto `EliteSystem.gd`) |
| JP economy: break verbs + timing passives | *What do I buy that changes how I play?* | ❌ To build (extends `JobTreeData.gd`) |

No system duplicates another's job. Anything proposed later must answer a question not on this table, or it gets cut.

---

## 2. SURGE / DEFLECT (timed inputs)

Ported from the React reference (`src/game/components/SurgeWindow.jsx`) into native GDScript, upgraded from binary hit/miss to **three tiers**.

- **SURGE**: on the player's offensive ability, a timing bar runs for `WINDOW_DURATION` (base 1.2s). Press inside the zones:
  - **Good zone** (25%–75% of bar): damage ×1.25, break damage ×1.0, buildup ×1.0
  - **Perfect zone** (45%–55%): damage ×1.4, break damage ×1.5, buildup ×1.5
  - **Miss**: damage ×1.0, no break damage, no buildup
- **DEFLECT**: mirrored input when the player is attacked:
  - **Good**: incoming damage ×0.75, incoming break damage ×0.5
  - **Perfect**: incoming damage ×0.6, incoming break damage ×0, fires `perfect_deflect` hook (passives: MP restore, counter-buildup, verb echoes — purchased, not innate)
  - **Miss**: full damage and break damage
- **Modifier hooks** (already consumed by `RunBonuses.gd`): `surge_window_bonus` widens the good zone; `surge_damage_bonus` adds to the damage multiplier. DEFLECT gains parallel keys: `deflect_window_bonus`, `deflect_guard_bonus`.
- Implementation split: `TimingResolver.gd` (pure logic, RefCounted, headless-testable) + `TimingWindow.gd` (UI overlay). UI never computes results; it asks the resolver.

## 3. Break (enemies) / Overwhelm (players)

One meter, asymmetric names. Break is what angels do to chaos-beasts; Overwhelm is what happens to a cracking costume.

- Every unit has `break_meter` (0..`max_break`). SURGE timing is the primary source of break damage; some abilities carry innate break damage (Delayer archetype).
- **Enemy breaks** → enemy is *Broken* for N turns: bonus damage taken, and the attacker's equipped **break verb** fires (see §6).
- **Player overwhelm** → exactly three effects:
  1. **Vulnerable** — bonus damage taken while overwhelmed (this *is* the defense drop; one stat, one icon)
  2. **CT pushback** — current CT reduced (turn delayed); creates the rescue moment
  3. **Costume Integrity loss** — flat by **source**, not act: regular enemy 5, boss 15. Mechanical failure feeds the narrative meter (Job priority-appears at CI ≤ 20 per soul system).
- **Bosses are immune to break-induced CT pushback** unless the attacker's equipped break verb is the boss-key override ("your breaks delay even the undelayable"). Boss break-windows: before a massive telegraphed skill, the boss exposes an enlarged break meter that *must* be broken to cancel the cast.
- Reset: per-battle by default. **"No Respite"** Vow/heat modifier: overwhelm and break persist between encounters within a floor.

## 4. Statuses — the two-road rule

Temper blocks **physical** statuses (pin, bleed, knockdown); Ether blocks **magical** statuses (burn, charm, slow, chill/freeze). Two roads to land one:

1. **Earned road** — while the relevant layer is intact, direct status application is impossible. Strip the layer → abilities carrying that status apply it outright.
2. **Buildup road** — SURGE-timed hits add status *buildup* regardless of armor: **50% rate while the protecting layer is intact, 100% once stripped**. At 100% buildup the status triggers, guaranteed. No % chance rolls anywhere — execution earns certainty.
3. **Turn decay while the layer is intact**: base −10%/turn. Tiered by rank (uses `EliteSystem.gd` tiers): Marked −15%, Elite −20%, Champion/Boss −25%+. Once the layer is stripped, decay stops — pressure sticks on broken armor.
4. UI rule: the buildup bar renders dimmed/slowed while the protecting layer is up. Readable at a glance, no tooltip.
5. **Migration note**: all existing chance-based status sources convert to buildup (e.g. the `cursed` elite prefix's `chance: 0.35` burn becomes burn buildup on hit).

v1 status set (small, deep): **chill→freeze, burn, pin, charm**. Each status exposes four tunable dials for items/boons: *rate, trigger cap, decay, spread*.

## 5. Monster archetypes & elites

Base archetype passives (learnable Act 1) + elite twists that **break learned rules, not scale numbers**. Layered onto the existing `EliteSystem.gd` tier/prefix rolls, PoE-style: elite = base archetype + 1 upgraded passive (from that archetype's pool) + 1 generic modifier; Act 3+ adds a second modifier.

| Archetype | Base passive | Elite twist (examples — pool of 2–3 each) |
|---|---|---|
| Brute | Follow-up attack on overwhelmed targets | Follow-ups displace (knockback into hazards/pawn range) |
| Pawn | All pawns converge within 2 of a broken unit | Converged pawns drain HP/MP while adjacent |
| Sniper | +Range vs. overwhelmed units | 50% of shots bypass temper and **pin** |
| Caster | CT refund on breaking a unit | Casts chain to units sharing element/status |
| Delayer | High break damage, low HP damage | Hits shrink your SURGE/DEFLECT windows for a turn |
| Warden | Unbreakable until linked unit breaks | Inherits dead link's break passive |
| Mimic | Copies last player unit's break verb | **Steals** it — hostage until the mimic dies |
| Howler | When broken, arms all allied break passives 2 turns | (punishes "break everything fast" habit) |

**Fairness guardrails**: every elite has a visual tell (corrupted/gilded rig variant); first encounter with each elite twist is **scripted, then enters the random pool**; an **exclusion table** bans unwinnable roll combinations, validated by Python simulation (assert no roll exceeds a threat-score ceiling — same methodology as the soul-pick policy). Narrative: learning archetype grammar = proto-communication with the chaos-beasts (Babel inversion).

## 6. JP economy

Three purchase categories per job (extends `JobTreeData.gd`):
1. **Break verbs** — each job sells 1–2; **exactly one equipped** at a time. Categories: offensive (cast twice, follow-up), tempo (delay enemy CT, extra turn), reactive (on ally/self overwhelm → gain guard, heal, redirect). One rare job equips two — **gated on shadow-integration progress**, not JP alone. The boss-key override is a purchasable verb available to a small set of jobs.
2. **SURGE passives** — e.g. final SURGE hit pushes target 1 tile; missed timings refund partial CT (purchasable forgiveness).
3. **DEFLECT passives** — e.g. perfect DEFLECT restores MP (battery-mage); reflects break damage.

Sin identity lives in *which* verbs/passives appear in each job's pool, plus flavor — not hard-bound verbs.

## 7. Items & boons (PoE-style experimentation surface)

Both layers exist: **gear** (persistent, meta-progression spine) and **boons** (per-run variance, `BoonSystem.gd`). Tier philosophy:
- **Common**: dial-turners (+buildup rate, slower decay)
- **Rare**: rule-benders (perfect DEFLECT applies counter-chill buildup; overwhelm-triggered effects)
- **Unique**: rule-breakers, cross-system (buildup never decays; first status each battle triggers at 50%; DEFLECT applies your equipped break verb to the attacker)

Counter-effects (counter-chill etc.) are item identity, not base rules.

## 8. Build order (each step playable before the next)

1. **SURGE/DEFLECT** — `TimingResolver.gd` + `TimingWindow.gd` + tests ← *this session*
2. **Break/Overwhelm** — meter on `Unit.gd`, break damage through `CombatResolver.gd`, overwhelm effects, boss windows
3. **Status buildup** — accumulator + decay tiers, convert chance-based sources
4. **Archetype passives** — base layer + elite twist pools + exclusion table (Python-validated)
5. **Break verbs & timing passives** — JP economy extension
6. **Training room** — hub scene (trial chamber, captured chaos-beasts); doubles as the dev tuning sandbox for all of the above
