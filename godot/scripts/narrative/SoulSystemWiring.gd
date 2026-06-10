extends Node
# ============================================================
#  SoulSystemWiring.gd — INTEGRATION GLUE (for Codex to wire in)
# ============================================================
#
#  The Soul system (SoulResolver + Souls + CaelPayoff) needs three hooks
#  that don't exist in the codebase yet. This file centralizes them so the
#  wiring is in one reviewable place. Add as autoload "SoulSystemWiring",
#  AFTER GameState/Souls/SoulResolver in the autoload order.
#
#  HOOK 1 — runs_together accounting
#    SoulResolver gates secret convos on narrative_flags["runs_together/<id>"].
#    Nothing increments it yet. We do it on run_ended: every angel who was in
#    the party that run gets +1. Requires a per-run party record (see _party_of_run).
#
#  HOOK 2 — the endgame / point-of-no-return boundary
#    seal_unresolved_souls() must be called when the player crosses into the
#    final sequence. That boundary isn't built. Per design, it should be reached
#    via a COMBINATION of signals, not a single flag:
#      - enough bosses beaten (the mountain's mid/high tiers cleared), AND
#      - enough total runs, AND
#      - the party's revelation tier is maxed.
#    _check_endgame_boundary() evaluates that combination and fires once.
#
#  HOOK 3 — emotional cooldown ("they have nothing left to say")
#    After a Soul delivers an emotionally heavy beat (secret convo, courier
#    content, or a 'late' core beat), they go quiet for a few visits before the
#    next beat is available — they've spent themselves. This is tracked per soul
#    as a cooldown the resolver should respect. We expose set/should-skip helpers
#    and recommend SoulResolver consult them (see PATCH NOTE below).
# ============================================================

# Tune these to taste.
const RUNS_TOGETHER_PER_RUN := 1
const ENDGAME_MIN_BOSSES := 4         # mid/high-tier fortress souls talked-or-beaten
const ENDGAME_MIN_RUNS := 45          # past Adam's (40) and Eve's (35) late beats
const ENDGAME_REQUIRE_MAX_TIER := true
const HEAVY_BEAT_COOLDOWN := 2        # visits a Soul stays quiet after a heavy beat

var _endgame_fired := false

func _ready() -> void:
	if GameState.has_signal("run_ended"):
		GameState.run_ended.connect(_on_run_ended)
	if GameState.has_signal("boss_defeated"):
		GameState.boss_defeated.connect(_on_boss_event)
	# Soul beats can also push us toward the boundary (e.g. final Soul departs).
	if SoulResolver.has_signal("soul_departed"):
		SoulResolver.soul_departed.connect(_on_soul_departed)
	if SoulResolver.has_signal("beat_resolved"):
		SoulResolver.beat_resolved.connect(_on_beat_resolved)


# ---- HOOK 1: runs_together ----------------------------------
func _on_run_ended(_run_number: int) -> void:
	for angel_id in _party_of_run():
		var key := "runs_together/%s" % angel_id
		GameState.narrative_flags[key] = int(GameState.narrative_flags.get(key, 0)) + RUNS_TOGETHER_PER_RUN
	_check_endgame_boundary()

func _party_of_run() -> Array:
	# Prefer an explicit per-run party record. Adjust to wherever the run stores it.
	if GameState.active_run != null and GameState.active_run.has_method("get_party_ids"):
		return GameState.active_run.get_party_ids()
	if GameState.narrative_flags.has("current_party"):
		return GameState.narrative_flags["current_party"]
	return []


# ---- HOOK 2: endgame boundary -------------------------------
func _on_boss_event(_boss_id: String, _killed_by: String) -> void:
	_check_endgame_boundary()

func _on_soul_departed(_soul_id: String, _state: String) -> void:
	_check_endgame_boundary()

func _check_endgame_boundary() -> void:
	if _endgame_fired:
		return
	var bosses_done := int(GameState.narrative_flags.get("bosses_resolved_count", _count_bosses()))
	var runs_ok := GameState.total_runs >= ENDGAME_MIN_RUNS
	var bosses_ok := bosses_done >= ENDGAME_MIN_BOSSES
	var tier_ok := (not ENDGAME_REQUIRE_MAX_TIER) or _is_max_tier()
	if runs_ok and bosses_ok and tier_ok:
		_endgame_fired = true
		GameState.narrative_flags["endgame_boundary_crossed"] = true
		SoulResolver.seal_unresolved_souls()   # permanent loss commits here

func _count_bosses() -> int:
	var n := 0
	for v in GameState.boss_encounters.values():
		if typeof(v) == TYPE_DICTIONARY and (v.get("defeated", false) or v.get("talked", false)):
			n += 1
	return n

func _is_max_tier() -> bool:
	# GameConfig.RevelationTier max is TIER_5 in this project.
	return GameState.revelation_tier >= 5


# ---- HOOK 3: emotional cooldown -----------------------------
# Heavy beats spend the Soul. Mark a cooldown when one resolves.
func _on_beat_resolved(soul_id: String, beat: Dictionary) -> void:
	var heavy := beat.get("kind") == SoulResolver.Beat.SECRET \
		or beat.get("kind") == SoulResolver.Beat.COURIER_CHOICE \
		or (beat.get("kind") == SoulResolver.Beat.CORE and beat.get("state") == "late")
	if heavy:
		set_cooldown(soul_id, HEAVY_BEAT_COOLDOWN)

func set_cooldown(soul_id: String, visits: int) -> void:
	GameState.narrative_flags["soul_cooldown/%s" % soul_id] = visits

# SoulResolver should call this at the top of resolve_visit and, if true,
# return a short "still sitting with it" beat or Beat.NONE instead of advancing.
func should_skip_for_cooldown(soul_id: String) -> bool:
	var key := "soul_cooldown/%s" % soul_id
	var left := int(GameState.narrative_flags.get(key, 0))
	if left <= 0:
		return false
	GameState.narrative_flags[key] = left - 1
	return true

# ============================================================
#  PATCH NOTE for SoulResolver.resolve_visit (optional, HOOK 3):
#  Near the top, after the departed check, add:
#
#      if Engine.has_singleton("SoulSystemWiring") \
#         and SoulSystemWiring.should_skip_for_cooldown(soul_id):
#          return {"kind": Beat.NONE, "soul_id": soul_id, "cooldown": true}
#
#  This makes a Soul go quiet for HEAVY_BEAT_COOLDOWN visits after a heavy
#  beat — "they said something emotional and have nothing left for a while."
# ============================================================
