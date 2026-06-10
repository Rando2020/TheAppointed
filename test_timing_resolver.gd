## test_timing_resolver.gd
## Headless tests for TimingResolver (SURGE/DEFLECT tiers, zones, bonuses).
## Run: godot --headless --script res://tests/test_timing_resolver.gd

extends SceneTree

const TimingResolverScript := preload("res://scripts/battle/TimingResolver.gd")

var _pass := 0
var _fail := 0


func _init() -> void:
	_run_tests()
	print("Timing resolver tests: %d pass, %d fail" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func _run_tests() -> void:
	# --- classify: tiers at base zones ---
	_eq(TimingResolverScript.classify(0.50), "perfect", "dead center is perfect")
	_eq(TimingResolverScript.classify(0.45), "perfect", "perfect zone start inclusive")
	_eq(TimingResolverScript.classify(0.55), "perfect", "perfect zone end inclusive")
	_eq(TimingResolverScript.classify(0.30), "good", "inside good zone")
	_eq(TimingResolverScript.classify(0.25), "good", "good zone start inclusive")
	_eq(TimingResolverScript.classify(0.75), "good", "good zone end inclusive")
	_eq(TimingResolverScript.classify(0.10), "miss", "early press misses")
	_eq(TimingResolverScript.classify(0.90), "miss", "late press misses")
	_eq(TimingResolverScript.classify(-1.0), "miss", "expired window misses")
	_eq(TimingResolverScript.classify(1.5), "miss", "out-of-range pct misses")

	# --- window bonus widens good zone, never perfect ---
	_eq(TimingResolverScript.classify(0.20, 0.30), "good", "window bonus widens good zone (early side)")
	_eq(TimingResolverScript.classify(0.80, 0.30), "good", "window bonus widens good zone (late side)")
	_eq(TimingResolverScript.classify(0.44, 0.50), "good", "near-perfect stays good even with big bonus")
	var huge_zone: Array[float] = TimingResolverScript.good_zone(5.0)
	_true(huge_zone[0] >= 0.05 and huge_zone[1] <= 0.95, "good zone clamped to sane bounds")

	# --- SURGE results ---
	var s_perfect: Dictionary = TimingResolverScript.resolve_surge(0.50)
	_eq_f(s_perfect["damage_mult"], 1.40, "perfect surge damage mult")
	_eq_f(s_perfect["break_mult"], 1.5, "perfect surge break mult")
	_eq_f(s_perfect["buildup_mult"], 1.5, "perfect surge buildup mult")
	_true(s_perfect["surged"], "perfect counts as surged")

	var s_good: Dictionary = TimingResolverScript.resolve_surge(0.30)
	_eq_f(s_good["damage_mult"], 1.25, "good surge damage mult matches JSX reference")
	_eq_f(s_good["break_mult"], 1.0, "good surge break mult")

	var s_miss: Dictionary = TimingResolverScript.resolve_surge(0.05)
	_eq_f(s_miss["damage_mult"], 1.0, "missed surge is neutral")
	_eq_f(s_miss["break_mult"], 0.0, "missed surge deals no break damage")
	_eq_f(s_miss["buildup_mult"], 0.0, "missed surge builds no status")
	_true(not s_miss["surged"], "miss is not surged")

	# --- SURGE bonuses (RunBonuses shape) ---
	var bonuses := {"surge_window_bonus": 0.20, "surge_damage_bonus": 0.35}
	var s_boosted: Dictionary = TimingResolverScript.resolve_surge(0.30, bonuses)
	_eq_f(s_boosted["damage_mult"], 1.60, "damage bonus stacks additively on good")
	var s_boost_miss: Dictionary = TimingResolverScript.resolve_surge(0.02, bonuses)
	_eq_f(s_boost_miss["damage_mult"], 1.0, "damage bonus does not apply on miss")

	# --- DEFLECT results ---
	var d_perfect: Dictionary = TimingResolverScript.resolve_deflect(0.50)
	_eq_f(d_perfect["damage_mult"], 0.60, "perfect deflect damage reduction")
	_eq_f(d_perfect["break_mult"], 0.0, "perfect deflect blocks all break damage")
	_true(d_perfect["perfect_deflect"], "perfect deflect flags the passive hook")

	var d_good: Dictionary = TimingResolverScript.resolve_deflect(0.30)
	_eq_f(d_good["damage_mult"], 0.75, "good deflect damage reduction")
	_eq_f(d_good["break_mult"], 0.5, "good deflect halves break damage")
	_true(not d_good["perfect_deflect"], "good deflect does not flag perfect hook")

	var d_miss: Dictionary = TimingResolverScript.resolve_deflect(-1.0)
	_eq_f(d_miss["damage_mult"], 1.0, "missed deflect takes full damage")
	_eq_f(d_miss["break_mult"], 1.0, "missed deflect takes full break damage")

	var d_guarded: Dictionary = TimingResolverScript.resolve_deflect(0.30, {"deflect_guard_bonus": 0.15})
	_eq_f(d_guarded["damage_mult"], 0.60, "guard bonus deepens reduction on non-miss")
	var d_guard_floor: Dictionary = TimingResolverScript.resolve_deflect(0.50, {"deflect_guard_bonus": 2.0})
	_eq_f(d_guard_floor["damage_mult"], 0.0, "guard bonus floors at zero, never heals")

	# --- expired convenience ---
	_eq(TimingResolverScript.resolve_expired("surge")["tier"], "miss", "expired surge is a miss")
	_eq(TimingResolverScript.resolve_expired("deflect")["tier"], "miss", "expired deflect is a miss")


func _eq(actual, expected, label: String) -> void:
	if actual == expected:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _eq_f(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) < 0.0001:
		_pass += 1
	else:
		_fail += 1
		print("FAIL: %s — expected %f, got %f" % [label, expected, actual])


func _true(cond: bool, label: String) -> void:
	_eq(cond, true, label)
