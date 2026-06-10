extends Node
# ============================================================
#  THE APPOINTED: AS ABOVE
#  CaelPayoff.gd — the Adam->Cael "envy_recognition" payoff
# ============================================================
#
#  When Adam's shame secret convo fires arc_beat {cael: "envy_recognition"},
#  SoulResolver sets:  narrative_flags["pending_payoff/cael"] = "envy_recognition"
#
#  The payoff must LAND ON THE NEXT RUN, not the same one — so the player
#  feels the dead man's words follow Cael out of the garden and into the world.
#  Dopamine = cause (Adam names Cael) -> visible effect (Cael can't stop hearing it).
#
#  This listens for run_started and, if a payoff is pending for an angel in
#  the party, fires the matching beat once, then clears it.
#
#  TO SET UP: Autoload as "CaelPayoff" (or fold into a general PayoffManager).
# ============================================================

signal payoff_beat(angel_id: String, beat: Dictionary)

# Recognition beats, keyed by angel + arc_beat id. Voice matched to Cael in
# characters.js: fights for everyone's worth but their own; launders wanting
# through causes; "I don't need recognition, the work is the point."
const PAYOFFS := {
	"cael": {
		"envy_recognition": {
			"angel_id": "cael",
			"arc_beat": "envy_recognition",
			"trigger": "run_start",            # lands the run AFTER Adam's convo
			"costume_integrity_delta": -15,    # the costume cracks; this is visible
			"sets_dialogue_tier": 2,           # hub lines deepen
			# A barbed-wire moment: short, intrusive, unwanted clarity.
			"dialogue": [
				"[Cael speaks before the first encounter. Unprompted. Like finishing " +
				"an argument no one else was having.]",
				"The First said something to me. In the garden. I've been carrying it " +
				"the way you carry a stone in your boot — pretending it's the road.",
				"He said I fight for everyone's worth but my own. That I decided the " +
				"question of mine a long time ago and settled it wrong.",
				"[beat]",
				"He's dead. He's been dead since the beginning of dead. " +
				"And he looked at me like he'd read the inside of my chest.",
				"I told him he was wrong. Obviously. The work is the point. " +
				"It's never been about being seen.",
				"[beat]",
				"...I've said that sentence ten thousand times. " +
				"This is the first time I've heard how fast I say it.",
			],
			# A seed the player can chase: Cael's own crack_event becomes reachable.
			"unlocks": ["cael_crack_event_available"],
			"codex_entry": "cael_carries_the_stone",
		}
	}
}

func _ready() -> void:
	if GameState.has_signal("run_started"):
		GameState.run_started.connect(_on_run_started)

func _on_run_started(_run_number: int) -> void:
	var party: Array = _current_party()
	for angel_id in PAYOFFS.keys():
		var pending: String = GameState.narrative_flags.get("pending_payoff/%s" % angel_id, "")
		if pending == "":
			continue
		if not (angel_id in party):
			continue   # they must be present for the words to follow them out
		var beat: Dictionary = PAYOFFS[angel_id].get(pending, {})
		if beat.is_empty():
			continue
		_fire(angel_id, beat)
		GameState.narrative_flags.erase("pending_payoff/%s" % angel_id)

func _fire(angel_id: String, beat: Dictionary) -> void:
	# Visible mechanical echo: the costume cracks.
	if beat.has("costume_integrity_delta") and GameState.characters.has(angel_id):
		var c: Dictionary = GameState.characters[angel_id]
		c["costume_integrity"] = clampi(
			int(c.get("costume_integrity", 100)) + int(beat["costume_integrity_delta"]), 0, 100)
		if beat.has("sets_dialogue_tier"):
			c["current_dialogue_tier"] = maxi(
				int(c.get("current_dialogue_tier", 1)), int(beat["sets_dialogue_tier"]))
		GameState.character_crack_event.emit(angel_id)
	for flag in beat.get("unlocks", []):
		GameState.narrative_flags[flag] = true
	if beat.has("codex_entry"):
		var seen: Array = GameState.narrative_flags.get("codex_seen", [])
		if not seen.has(beat["codex_entry"]):
			seen.append(beat["codex_entry"])
			GameState.narrative_flags["codex_seen"] = seen
	payoff_beat.emit(angel_id, beat)

func _current_party() -> Array:
	if GameState.active_run != null and GameState.active_run.has_method("get_party_ids"):
		return GameState.active_run.get_party_ids()
	return GameState.narrative_flags.get("current_party", [])
