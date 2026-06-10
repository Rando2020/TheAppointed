extends Node
# ============================================================
#  THE APPOINTED: AS ABOVE
#  SoulResolver.gd — picks the correct beat for a "?" Soul visit
# ============================================================
#
#  Spec: docs/lore/soul-encounters.md §6 (resolution order)
#
#  Per visit, in order:
#    1. A deliverable courier beat?      -> offer the CHOICE (deliver / withhold)
#    2. A due, unlocked secret convo?    -> serve it
#    3. The next core beat by visit count -> serve it
#    4. Apply `emits` (carried token, angel arc beat) on resolve
#    5. If beat departs the Soul, retire it (commit to loss)
#
#  This resolver is the single source of truth for what a Soul says.
#  It reads/writes GameState. It never picks two beats in one visit.
#
#  TO SET UP:
#  Project > Project Settings > Autoload
#  Add: res://scripts/narrative/SoulResolver.gd as "SoulResolver"
#  (Souls data lives in res://scripts/narrative/Souls.gd as "Souls")
# ============================================================

# Beat kinds the caller (dialogue UI) switches on:
enum Beat { NONE, COURIER_CHOICE, SECRET, CORE, LINGERING }

# Emitted so UI/other systems can react without polling.
signal beat_resolved(soul_id: String, beat: Dictionary)
signal courier_choice_offered(soul_id: String, courier_id: String, beat: Dictionary)
signal soul_departed(soul_id: String, departure_state: String)
signal arc_beat_fired(angel_id: String, arc_beat_id: String)


# ---- PUBLIC ENTRY ------------------------------------------
# Call when the player enters a "?" that has resolved to `soul_id`.
# `party` is an Array[String] of angel ids currently traveling.
# Returns a beat Dictionary the dialogue UI can render. Shape:
#   { "kind": Beat, "soul_id", "dialogue": Array[String], ...meta }
func resolve_visit(soul_id: String, party: Array) -> Dictionary:
	var soul: Dictionary = Souls.get_soul(soul_id)
	if soul.is_empty():
		push_warning("SoulResolver: unknown soul '%s'" % soul_id)
		return {"kind": Beat.NONE}

	var state: Dictionary = _soul_state(soul_id)

	# Retired Souls never resolve again. The loss is permanent.
	if state.get("departed", false):
		return {"kind": Beat.NONE}

	# HOOK 3 — emotional cooldown. After a heavy beat a Soul goes quiet for a
	# few visits ("they said something emotional and have nothing left").
	# SoulSystemWiring tracks the countdown; here we just respect it.
	if Engine.has_singleton("SoulSystemWiring") and SoulSystemWiring.should_skip_for_cooldown(soul_id):
		return {"kind": Beat.NONE, "soul_id": soul_id, "cooldown": true}

	# --- 1. COURIER (offer the choice; do not resolve content yet) ---
	var courier := _find_deliverable_courier(soul, state)
	if not courier.is_empty():
		var beat := {
			"kind": Beat.COURIER_CHOICE,
			"soul_id": soul_id,
			"courier_id": courier.get("id", ""),
			"requires": courier.get("requires", {}),
		}
		courier_choice_offered.emit(soul_id, beat["courier_id"], beat)
		return beat

	# Count this as an encounter from here on (a beat will be served).
	# (Courier choice is counted on resolution instead — see resolve_courier_choice.)

	# --- 2. SECRET CONVO (party-gated, due, unseen) ---
	var secret := _find_due_secret(soul, state, party)
	if not secret.is_empty():
		_mark_encounter(soul_id)
		_mark_secret_seen(soul_id, secret.get("id", ""))
		_apply_emits(secret.get("emits", {}))
		var beat := {
			"kind": Beat.SECRET,
			"soul_id": soul_id,
			"secret_id": secret.get("id", ""),
			"thread": secret.get("thread", ""),
			"dialogue": secret.get("dialogue", []),
			"codex_entry": secret.get("codex_entry", ""),
		}
		_post_resolve(soul, beat)
		return beat

	# --- 3. CORE BEAT (next unseen, gated by visit count) ---
	var core := _next_core_beat(soul, state)
	if not core.is_empty():
		_mark_encounter(soul_id)
		_apply_emits(core.get("emits", {}))
		var beat := {
			"kind": Beat.CORE,
			"soul_id": soul_id,
			"state": core.get("state", ""),
			"dialogue": core.get("dialogue", []),
			"departs": core.get("departs_after", false),
			"departure_note": core.get("departure_note", ""),
		}
		_post_resolve(soul, beat)
		if beat["departs"]:
			_retire(soul_id, "core_complete")
		return beat

	# --- nothing core/secret left. If a courier was withheld, she lingers. ---
	var linger := _next_lingering_beat(soul, state)
	if not linger.is_empty():
		_mark_encounter(soul_id)
		var beat := {
			"kind": Beat.LINGERING,
			"soul_id": soul_id,
			"dialogue": linger,
		}
		_post_resolve(soul, beat)
		return beat

	return {"kind": Beat.NONE}


# ---- COURIER CHOICE RESOLUTION -----------------------------
# Called by the dialogue UI after the player chooses on a COURIER_CHOICE beat.
# `deliver` = true to hand it over, false to withhold. Returns the content beat.
func resolve_courier_choice(soul_id: String, courier_id: String, deliver: bool) -> Dictionary:
	var soul: Dictionary = Souls.get_soul(soul_id)
	var cb := _courier_by_id(soul, courier_id)
	if cb.is_empty():
		return {"kind": Beat.NONE}

	_mark_encounter(soul_id)
	var token: String = cb.get("requires", {}).get("has_carried", "")

	if deliver:
		var od: Dictionary = cb.get("on_deliver", {})
		GameState.narrative_flags["carried/" + token] = "delivered"
		var beat := {
			"kind": Beat.COURIER_CHOICE,
			"soul_id": soul_id,
			"delivered": true,
			"dialogue": od.get("dialogue", []),
			"codex_entry": od.get("codex_entry", ""),
		}
		_apply_emits(od.get("emits", {}))
		_post_resolve(soul, beat)
		if od.has("unlocks_departure"):
			_retire(soul_id, od["unlocks_departure"])   # she leaves at peace
		return beat
	else:
		var ow: Dictionary = cb.get("on_withhold", {})
		# No penalty — only guilt. Token marked withheld; she lingers, recoverable
		# while present. The window only seals when the Soul is forced to depart
		# (see seal_unresolved_souls at run/endgame boundaries).
		GameState.narrative_flags["carried/" + token] = "withheld"
		var st := _soul_state(soul_id)
		st["courier_withheld"] = courier_id
		var beat := {
			"kind": Beat.COURIER_CHOICE,
			"soul_id": soul_id,
			"delivered": false,
			"dialogue": ow.get("dialogue", []),
			"codex_entry": ow.get("codex_entry", ""),
		}
		_post_resolve(soul, beat)
		return beat


# ---- PERMANENT LOSS (your call #3) -------------------------
# Call at the hard endgame boundary. Any Soul still carrying an undelivered
# message departs UN-reconciled, and that state is sealed into the ending.
# This is meant to hurt. The choice mattered.
func seal_unresolved_souls() -> void:
	for soul_id in Souls.all_ids():
		var st := _soul_state(soul_id)
		if st.get("departed", false):
			continue
		if st.has("courier_withheld"):
			GameState.narrative_flags["ending/unreconciled/" + soul_id] = true
			_retire(soul_id, "departed_unreconciled")


# ---- INTERNALS: selection ----------------------------------
func _find_deliverable_courier(soul: Dictionary, state: Dictionary) -> Dictionary:
	for cb in soul.get("courier_beats", []):
		if state.get("courier_resolved", {}).has(cb.get("id", "")):
			continue
		var token: String = cb.get("requires", {}).get("has_carried", "")
		if token != "" and GameState.narrative_flags.get("carried/" + token, "") == "held":
			return cb
	return {}

func _find_due_secret(soul: Dictionary, state: Dictionary, party: Array) -> Dictionary:
	var seen: Array = state.get("secrets_seen", [])
	var visits: int = state.get("encounters_seen", 0)
	for sc in soul.get("secret_convos", []):
		var sid: String = sc.get("id", "")
		if seen.has(sid):
			continue
		var unlock: Dictionary = sc.get("unlock", {})
		if visits < int(unlock.get("min_encounters", 0)):
			continue
		# insert_before: only surface while the gating core beat is still ahead
		if sc.has("insert_before"):
			var next_core := _next_core_beat(soul, state)
			if next_core.is_empty() or int(next_core.get("run_required", 0)) >= int(sc["insert_before"]):
				pass  # the before-beat is still ahead (or none left) -> still allowed
			# if the gate beat already passed, the secret is missed — skip it
			if not next_core.is_empty() and int(next_core.get("run_required", 0)) > int(sc["insert_before"]):
				continue
		if _party_resonates(unlock.get("party_resonance", {}), party):
			return sc
	return {}

func _next_core_beat(soul: Dictionary, state: Dictionary) -> Dictionary:
	var idx: int = state.get("core_index", 0)
	var core: Array = soul.get("encounters", [])
	if idx >= core.size():
		return {}
	var beat: Dictionary = core[idx]
	# Gate by run count: only serve once the player's run total has reached it.
	if GameState.total_runs < int(beat.get("run_required", 0)):
		return {}
	return beat

func _next_lingering_beat(soul: Dictionary, state: Dictionary) -> Array:
	var cid: String = state.get("courier_withheld", "")
	if cid == "":
		return []
	var cb := _courier_by_id(soul, cid)
	var lines: Array = cb.get("on_withhold", {}).get("lingering", [])
	var li: int = state.get("lingering_index", 0)
	if li >= lines.size():
		return lines[lines.size() - 1] if lines.size() > 0 else []  # repeat the last ache
	state["lingering_index"] = li + 1
	return lines[li]


# ---- INTERNALS: predicates / emits -------------------------
func _party_resonates(res: Dictionary, party: Array) -> bool:
	if res.is_empty():
		return true
	var any_of: Array = res.get("any_of", [])
	var need: int = int(res.get("min_runs_together", 0))
	for angel_id in any_of:
		if angel_id in party and _runs_together(angel_id) >= need:
			return true
	return false

func _apply_emits(emits: Dictionary) -> void:
	if emits.is_empty():
		return
	if emits.has("carried_message"):
		var tok: String = emits["carried_message"]
		# Only set to held if not already delivered/withheld.
		if not GameState.narrative_flags.has("carried/" + tok):
			GameState.narrative_flags["carried/" + tok] = "held"
	if emits.has("arc_beat"):
		for angel_id in emits["arc_beat"].keys():
			_fire_arc_beat(angel_id, emits["arc_beat"][angel_id])

func _fire_arc_beat(angel_id: String, arc_beat_id: String) -> void:
	var key := "arc_beat/%s/%s" % [angel_id, arc_beat_id]
	if GameState.narrative_flags.get(key, false):
		return
	GameState.narrative_flags[key] = true
	# Queue the visible payoff for the NEXT run so the link lands with weight.
	GameState.narrative_flags["pending_payoff/%s" % angel_id] = arc_beat_id
	arc_beat_fired.emit(angel_id, arc_beat_id)


# ---- INTERNALS: state bookkeeping --------------------------
func _soul_state(soul_id: String) -> Dictionary:
	if not GameState.soul_encounters.has(soul_id):
		# Use the single canonical factory so seeded and lazily-created
		# entries are always identical in shape.
		if GameState.has_method("_fresh_soul_state"):
			GameState.soul_encounters[soul_id] = GameState._fresh_soul_state()
		else:
			GameState.soul_encounters[soul_id] = {
				"encounters_seen": 0,
				"core_index": 0,
				"secrets_seen": [],
				"courier_resolved": {},
				"lingering_index": 0,
				"departed": false,
			}
	return GameState.soul_encounters[soul_id]

func _mark_encounter(soul_id: String) -> void:
	var st := _soul_state(soul_id)
	st["encounters_seen"] = int(st.get("encounters_seen", 0)) + 1
	GameState.soul_encountered.emit(soul_id)

func _mark_secret_seen(soul_id: String, secret_id: String) -> void:
	var st := _soul_state(soul_id)
	if not st["secrets_seen"].has(secret_id):
		st["secrets_seen"].append(secret_id)

func _post_resolve(soul: Dictionary, beat: Dictionary) -> void:
	# advance core pointer only when a core beat was actually served
	if beat.get("kind") == Beat.CORE:
		var st := _soul_state(beat["soul_id"])
		st["core_index"] = int(st.get("core_index", 0)) + 1
	if beat.has("codex_entry") and beat["codex_entry"] != "":
		var seen: Array = GameState.narrative_flags.get("codex_seen", [])
		if not seen.has(beat["codex_entry"]):
			seen.append(beat["codex_entry"])
			GameState.narrative_flags["codex_seen"] = seen
	beat_resolved.emit(beat.get("soul_id", ""), beat)

func _retire(soul_id: String, departure_state: String) -> void:
	var st := _soul_state(soul_id)
	st["departed"] = true
	st["departure_state"] = departure_state
	soul_departed.emit(soul_id, departure_state)

func _runs_together(angel_id: String) -> int:
	return int(GameState.narrative_flags.get("runs_together/" + angel_id, 0))

func _courier_by_id(soul: Dictionary, courier_id: String) -> Dictionary:
	for cb in soul.get("courier_beats", []):
		if cb.get("id", "") == courier_id:
			return cb
	return {}

# Mark a courier beat resolved (called by UI after content shown).
func mark_courier_resolved(soul_id: String, courier_id: String) -> void:
	var st := _soul_state(soul_id)
	if not st.has("courier_resolved"):
		st["courier_resolved"] = {}
	st["courier_resolved"][courier_id] = true
