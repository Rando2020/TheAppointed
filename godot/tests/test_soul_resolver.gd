extends SceneTree
# ============================================================
#  test_soul_resolver.gd — headless playthrough of the Soul system
# ============================================================
#  Run: godot --headless -s res://tests/test_soul_resolver.gd
#
#  Simulates:
#    A) Adam x3 with Cael in party -> 3 core beats in order, shame secret
#       convo surfaces before the run-40 beat, fires cael:envy_recognition,
#       Adam departs and emits adam_to_eve.
#    B) Courier DELIVER branch -> Eve forgiveness, departs at peace.
#    C) Courier WITHHOLD branch -> guilt, lingering beats in order, then
#       seal_unresolved_souls() departs her unreconciled.
#
#  Uses a stub GameState so the test is self-contained and does not depend
#  on autoload wiring. SoulResolver/Souls/CaelPayoff read a global named
#  GameState; we inject the stub via Engine for the duration of the test.
# ============================================================

const SoulResolver := preload("res://scripts/narrative/SoulResolver.gd")
const Souls := preload("res://scripts/narrative/Souls.gd")

var _pass := 0
var _fail := 0

func _init() -> void:
	_run()
	print("Soul resolver tests: %d pass, %d fail" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)

func _run() -> void:
	# --- shared stubs ---
	var gs := _make_gamestate_stub()
	var souls := Souls.new()
	var resolver := SoulResolver.new()
	# Inject globals the scripts expect by name.
	Engine.register_singleton("GameState", gs)
	Engine.register_singleton("Souls", souls)

	# ===== A) ADAM x3 with Cael in party =====
	var party := ["cael", "aeryn"]
	# Cael has 3 runs together so the shame secret can unlock.
	gs.narrative_flags["runs_together/cael"] = 3

	gs.total_runs = 20
	var b1 := resolver.resolve_visit("adam", party)
	_eq(b1.get("kind"), SoulResolver.Beat.CORE, "A1 first Adam visit is a CORE beat")
	_eq(b1.get("state"), "early", "A1 first Adam beat is 'early'")
	_true(str(b1.get("dialogue")[0]).begins_with("I know what you are"), "A1 correct early dialogue")

	# Second visit: encounters_seen now 1; min_encounters for shame is 2, so NOT yet.
	gs.total_runs = 30
	var b2 := resolver.resolve_visit("adam", party)
	_eq(b2.get("kind"), SoulResolver.Beat.CORE, "A2 second Adam visit is CORE (shame not yet due)")
	_eq(b2.get("state"), "middle", "A2 second Adam beat is 'middle'")

	# Third visit: encounters_seen now 2 -> shame secret unlocks, inserts BEFORE run-40.
	gs.total_runs = 40
	var b3 := resolver.resolve_visit("adam", party)
	_eq(b3.get("kind"), SoulResolver.Beat.SECRET, "A3 shame secret surfaces before the late beat")
	_eq(b3.get("secret_id"), "adam_shame", "A3 it is the adam_shame convo")
	_true(gs.narrative_flags.get("arc_beat/cael/envy_recognition", false),
		"A3 fired cael:envy_recognition arc beat")
	_eq(gs.narrative_flags.get("pending_payoff/cael", ""), "envy_recognition",
		"A3 queued Cael payoff for next run")

	# Fourth visit: now the run-40 late/ownership beat -> departs + emits token.
	var b4 := resolver.resolve_visit("adam", party)
	_eq(b4.get("kind"), SoulResolver.Beat.CORE, "A4 late beat serves after the secret")
	_eq(b4.get("state"), "late", "A4 is the 'late' ownership beat")
	_true(b4.get("departs"), "A4 Adam departs after late beat")
	_eq(gs.narrative_flags.get("carried/adam_to_eve", ""), "held", "A4 emitted carried token 'held'")
	_true(gs.soul_encounters["adam"].get("departed", false), "A4 Adam retired")

	# Fifth visit: Adam is gone. Nothing resolves.
	var b5 := resolver.resolve_visit("adam", party)
	_eq(b5.get("kind"), SoulResolver.Beat.NONE, "A5 departed Adam never resolves again")

	# ===== A6) total_runs gates the NEXT core beat =====
	# Fresh soul (cain: first core beat requires run 12). Below threshold -> NONE.
	var gsr := _make_gamestate_stub()
	Engine.register_singleton("GameState", gsr)
	gsr.total_runs = 5
	var r_lo := resolver.resolve_visit("cain", ["cael"])
	_eq(r_lo.get("kind"), SoulResolver.Beat.NONE, "A6 core beat withheld below required run")
	# Advance total_runs past the gate -> the early beat now serves.
	gsr.total_runs = 12
	var r_hi := resolver.resolve_visit("cain", ["cael"])
	_eq(r_hi.get("kind"), SoulResolver.Beat.CORE, "A6 advancing total_runs surfaces the core beat")
	_eq(r_hi.get("state"), "early", "A6 it is the early beat")

	# ===== B) EVE — DELIVER branch =====
	var gs_b := _make_gamestate_stub()
	gs_b.narrative_flags["carried/adam_to_eve"] = "held"   # carrying it
	Engine.register_singleton("GameState", gs_b)
	gs_b.total_runs = 25

	# First Eve visit offers the courier CHOICE (not content yet).
	var e1 := resolver.resolve_visit("eve", party)
	_eq(e1.get("kind"), SoulResolver.Beat.COURIER_CHOICE, "B1 Eve offers courier choice when carrying")
	_eq(e1.get("courier_id"), "eve_forgiveness", "B1 correct courier id")

	# Player chooses DELIVER.
	var e_del := resolver.resolve_courier_choice("eve", "eve_forgiveness", true)
	_true(e_del.get("delivered"), "B2 deliver returns delivered=true")
	_eq(gs_b.narrative_flags.get("carried/adam_to_eve", ""), "delivered", "B2 token marked delivered")
	_true(gs_b.soul_encounters["eve"].get("departed", false), "B2 Eve departs (at peace) on deliver")
	_eq(gs_b.soul_encounters["eve"].get("departure_state", ""), "eve_at_peace", "B2 departure is eve_at_peace")

	# ===== C) EVE — WITHHOLD branch + permanent seal =====
	var gs_c := _make_gamestate_stub()
	gs_c.narrative_flags["carried/adam_to_eve"] = "held"
	Engine.register_singleton("GameState", gs_c)
	gs_c.total_runs = 25

	var c1 := resolver.resolve_visit("eve", party)
	_eq(c1.get("kind"), SoulResolver.Beat.COURIER_CHOICE, "C1 Eve offers courier choice")
	var c_with := resolver.resolve_courier_choice("eve", "eve_forgiveness", false)
	_true(not c_with.get("delivered"), "C2 withhold returns delivered=false")
	_eq(gs_c.narrative_flags.get("carried/adam_to_eve", ""), "withheld", "C2 token marked withheld")
	_true(not gs_c.soul_encounters["eve"].get("departed", false), "C2 Eve lingers (not departed) on withhold")

	# Subsequent visits serve lingering beats in order. Core beats also still due
	# (run 25/35), but withheld lingering should surface since courier is unresolved-by-departure.
	# Mark the courier resolved so the resolver moves past the choice and into core/lingering.
	resolver.mark_courier_resolved("eve", "eve_forgiveness")
	# Advance core beats first (they gate by run count: 25 then 35).
	var c_core1 := resolver.resolve_visit("eve", party)   # run 25 early
	_eq(c_core1.get("state"), "early", "C3 core 'early' still served while lingering")
	gs_c.total_runs = 35
	var c_core2 := resolver.resolve_visit("eve", party)   # run 35 middle
	_eq(c_core2.get("state"), "middle", "C4 core 'middle' served")
	# Now core exhausted -> lingering beats begin, in order.
	var c_l1 := resolver.resolve_visit("eve", party)
	_eq(c_l1.get("kind"), SoulResolver.Beat.LINGERING, "C5 first lingering beat")
	_true(str(c_l1.get("dialogue")[0]).begins_with("You're back. I'm glad"), "C5 lingering #1 text")
	var c_l2 := resolver.resolve_visit("eve", party)
	_eq(c_l2.get("kind"), SoulResolver.Beat.LINGERING, "C6 second lingering beat")
	_true(str(c_l2.get("dialogue")[0]).begins_with("I've been thinking about what I'd say"), "C6 lingering #2 text")
	var c_l3 := resolver.resolve_visit("eve", party)
	_true(str(c_l3.get("dialogue")[-1]).begins_with("If you see him"), "C7 lingering #3 ends on the ache")

	# Endgame seal: she departs UNRECONCILED, sealed into the ending.
	resolver.seal_unresolved_souls()
	_true(gs_c.soul_encounters["eve"].get("departed", false), "C8 seal departs Eve")
	_eq(gs_c.soul_encounters["eve"].get("departure_state", ""), "departed_unreconciled", "C8 unreconciled state")
	_true(gs_c.narrative_flags.get("ending/unreconciled/eve", false), "C8 sealed into ending flags")

	# ===== D) SOUL-PICK POLICY (Souls.gd helpers) =====
	var gsd := _make_gamestate_stub()
	Engine.register_singleton("GameState", gsd)
	# floor gating
	_eq(souls.floor_weight("moses", 1), 0, "D moses not eligible on floor 1")
	_true(souls.floor_weight("adam", 1) > 0, "D adam eligible on floor 1")
	_eq(souls.floor_weight("adam", 5), 0, "D adam not eligible on floor 5")
	# Job trigger gated on costume integrity
	gsd.characters = {"cael": {"costume_integrity": 100}}
	_eq(souls.trigger_condition_met("job", ["cael"]), false, "D Job blocked when costume intact")
	gsd.characters = {"cael": {"costume_integrity": 15}}
	_eq(souls.trigger_condition_met("job", ["cael"]), true, "D Job triggers when costume cracked")
	_true(souls.has_priority_trigger("job"), "D Job has a priority trigger")
	_true(not souls.has_priority_trigger("adam"), "D Adam has no priority trigger")
	# non-job soul never blocked by trigger
	_eq(souls.trigger_condition_met("adam", ["cael"]), true, "D Adam ungated by trigger")

	# cleanup
	Engine.unregister_singleton("GameState")
	Engine.unregister_singleton("Souls")
	souls.free()
	resolver.free()
	gs.free(); gs_b.free(); gs_c.free()

# ---- stub GameState (only the fields SoulResolver/Souls touch) ----
func _make_gamestate_stub() -> Node:
	var n := Node.new()
	n.set("total_runs", 0)
	n.set("revelation_tier", 5)
	n.set("soul_encounters", {})
	n.set("relationships", {})
	n.set("characters", {})
	n.set("narrative_flags", {})
	# SoulResolver calls GameState.soul_encountered.emit(...). Provide a dummy
	# via a script with the signal, since Node has no such signal by default.
	var stub_script := GDScript.new()
	stub_script.source_code = """
extends Node
signal soul_encountered(soul_id)
var total_runs := 0
var revelation_tier := 5
var soul_encounters := {}
var relationships := {}
var characters := {}
var narrative_flags := {}
var active_run = null
"""
	stub_script.reload()
	n.set_script(stub_script)
	return n

func _eq(got, exp, label: String) -> void:
	if got == exp:
		_pass += 1
		print("PASS %s" % label)
	else:
		_fail += 1
		print("FAIL %s (got=%s exp=%s)" % [label, str(got), str(exp)])

func _true(cond: bool, label: String) -> void:
	if cond:
		_pass += 1
		print("PASS %s" % label)
	else:
		_fail += 1
		print("FAIL %s" % label)
