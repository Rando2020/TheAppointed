## TimingResolver.gd
## Pure logic for SURGE/DEFLECT timed inputs. No UI, no input handling —
## headless-testable (see tests/test_timing_resolver.gd).
## UI layer (TimingWindow.gd) feeds it a press time; it returns a result dict.
##
## Spec: docs/COMBAT_SPEC.md §2. Ported from the archived React reference
## (src/game/components/SurgeWindow.jsx) and upgraded from binary hit/miss
## to three tiers (perfect / good / miss), with DEFLECT as the mirrored
## defensive input and structured outputs for the Break/buildup systems.

class_name TimingResolver
extends RefCounted

const WINDOW_DURATION_MS := 1200.0

## Zone boundaries as fraction of the window (base, before bonuses).
const GOOD_START := 0.25
const GOOD_END := 0.75
const PERFECT_START := 0.45
const PERFECT_END := 0.55

## Tier multipliers — SURGE (offense).
const SURGE_TIERS: Dictionary = {
	"perfect": {"damage_mult": 1.40, "break_mult": 1.5, "buildup_mult": 1.5},
	"good":    {"damage_mult": 1.25, "break_mult": 1.0, "buildup_mult": 1.0},
	"miss":    {"damage_mult": 1.00, "break_mult": 0.0, "buildup_mult": 0.0},
}

## Tier multipliers — DEFLECT (defense). Applied to INCOMING values.
const DEFLECT_TIERS: Dictionary = {
	"perfect": {"damage_mult": 0.60, "break_mult": 0.0},
	"good":    {"damage_mult": 0.75, "break_mult": 0.5},
	"miss":    {"damage_mult": 1.00, "break_mult": 1.0},
}


## Returns the good-zone bounds [start, end] widened symmetrically by
## window_bonus (e.g. 0.20 from boons via RunBonuses "surge_window_bonus").
## The perfect zone never widens — perfection stays earned.
static func good_zone(window_bonus: float = 0.0) -> Array[float]:
	var half_extra: float = (GOOD_END - GOOD_START) * window_bonus * 0.5
	var start: float = clampf(GOOD_START - half_extra, 0.05, PERFECT_START)
	var end: float = clampf(GOOD_END + half_extra, PERFECT_END, 0.95)
	return [start, end]


## Classifies a press at `pct` (0..1 through the window) into a tier.
## pct < 0 means no press (window expired).
static func classify(pct: float, window_bonus: float = 0.0) -> String:
	if pct < 0.0 or pct > 1.0:
		return "miss"
	if pct >= PERFECT_START and pct <= PERFECT_END:
		return "perfect"
	var zone := good_zone(window_bonus)
	if pct >= zone[0] and pct <= zone[1]:
		return "good"
	return "miss"


## SURGE result for a press at `pct`.
## bonuses: {"surge_window_bonus": float, "surge_damage_bonus": float}
## (shape matches RunBonuses.gd aggregation).
static func resolve_surge(pct: float, bonuses: Dictionary = {}) -> Dictionary:
	var window_bonus: float = bonuses.get("surge_window_bonus", 0.0)
	var tier := classify(pct, window_bonus)
	var t: Dictionary = SURGE_TIERS[tier]
	var damage_mult: float = t["damage_mult"]
	if tier != "miss":
		damage_mult += bonuses.get("surge_damage_bonus", 0.0)
	return {
		"kind": "surge",
		"tier": tier,
		"surged": tier != "miss",
		"damage_mult": damage_mult,
		"break_mult": t["break_mult"],
		"buildup_mult": t["buildup_mult"],
		"press_pct": pct,
	}


## DEFLECT result for a press at `pct`.
## bonuses: {"deflect_window_bonus": float, "deflect_guard_bonus": float}
## deflect_guard_bonus further reduces incoming damage on non-miss tiers.
## "perfect_deflect" flag is the hook point for purchased passives
## (MP restore, counter-buildup, verb echoes) — consumed by CombatResolver,
## never resolved here.
static func resolve_deflect(pct: float, bonuses: Dictionary = {}) -> Dictionary:
	var window_bonus: float = bonuses.get("deflect_window_bonus", 0.0)
	var tier := classify(pct, window_bonus)
	var t: Dictionary = DEFLECT_TIERS[tier]
	var damage_mult: float = t["damage_mult"]
	if tier != "miss":
		damage_mult = maxf(damage_mult - bonuses.get("deflect_guard_bonus", 0.0), 0.0)
	return {
		"kind": "deflect",
		"tier": tier,
		"deflected": tier != "miss",
		"perfect_deflect": tier == "perfect",
		"damage_mult": damage_mult,
		"break_mult": t["break_mult"],
		"press_pct": pct,
	}


## Convenience for the UI layer: result when the window expires unpressed.
static func resolve_expired(kind: String) -> Dictionary:
	return resolve_surge(-1.0) if kind == "surge" else resolve_deflect(-1.0)
