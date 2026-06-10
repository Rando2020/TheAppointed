## GameState.gd    Autoload singleton.
## Persists player progress (JP, gold, learned abilities, completed stages)
## across scene transitions.  Never freed between battles.
##
## Save format (user://save.json):
##   version          : int   (must == SAVE_VERSION)
##   gold             : int
##   completed_stages : Array[String]
##   unit_jp          : { uid -> int }
##   unit_learned     : { uid -> Array[String] }
extends Node

# ── Narrative dependencies ───────────────────────────────
# GameConfig exposes class_name GameConfig, so no autoload needed.

# ── Narrative signals (merged from the former narrative GameState) ──
# UI / Soul system connect to these to react to narrative state changes.
signal revelation_tier_changed(new_tier: int)
signal clarity_changed(new_clarity: int)
signal character_crack_event(char_id: String)
signal character_true_name_revealed(char_id: String, true_name: String)
signal boss_defeated(boss_id: String, killed_by: String)
signal soul_encountered(soul_id: String)
signal hub_character_met(hub_char_id: String)
signal run_started(run_number: int)
signal run_ended(run_number: int)

const AbilityDBScript := preload("res://scripts/data/AbilityDB.gd")
const VowSigilDefs := preload("res://scripts/roguelike/VowSigilSystem.gd")
const SAVE_PATH    := "user://save.json"
const SAVE_VERSION := 1

## Which map to load when transitioning into Battle.tscn  (0 = Ashvale, 1 = Crypt)
var selected_map_index: int = 0

## Gold accumulated across all battles
var gold: int = 0

## Stages the player has beaten at least once
var completed_stages: Array[String] = []

## Rewards from the most recent victory  read by ResultsScreen
var pending_rewards: Dictionary = {}

## Roguelike run state
var active_run:           RunState = null
var story_flags:          Array[String] = []
var pending_loot:         Array = []
var pending_boon_offers:  Array = []

## Last run death context  read by ResultsScreen + HubDialogue
var last_run_death: Dictionary = {}
## Run history  floors completed, used by hub dialogue
var runs_completed: int = 0
var best_floor_reached: int = 0

## Items accumulated during the current run (mirrors active_run.inventory)
var run_inventory:        Array = []
var vow_progress:         Dictionary = {}
var sigil_progress:       Dictionary = {}


# ── Narrative state (merged) ─────────────────────────────
var game_title: String = "The Appointed: As Above"
var total_runs: int = 0
var current_run: int = 0
var revelation_tier: int = GameConfig.RevelationTier.TIER_1
var revelation_points: int = 0
var clarity: int = GameConfig.CLARITY.START
var characters: Dictionary = {}        # the seven angels' arc state
var relationships: Dictionary = {}     # 21 pairwise bonds
var hub_characters: Dictionary = {}
var soul_encounters: Dictionary = {}   # SoulResolver owns the per-soul shape
var boss_encounters: Dictionary = {}
var narrative_flags: Dictionary = {}
var run_history: Array = []

## Retrieve and clear the pending deployment array written by DeploymentScreen.
## Call from BattleScene._ready() to get the player's chosen unit positions.
func pop_pending_deployment() -> Array:
	if active_run == null or not active_run.has_meta("pending_deployment"):
		return []
	var dep: Array = active_run.get_meta("pending_deployment", [])
	active_run.remove_meta("pending_deployment")
	return dep
## Highest floor reached this run (for ResultsScreen)
var run_floor_reached:    int   = 0
## Total JP earned this run (for ResultsScreen)
var run_jp_earned:        int   = 0

## Per-unit persistent data.
## unit_id -> {
##   display_name      : String,
##   jp                : int,
##   base_abilities    : Array[String],   (always available, cannot be spent)
##   learned_abilities : Array[String],   (JP-purchased)
##   learnable_abilities: Array[String],  (purchaseable pool)
## }
var unit_registry: Dictionary = {}


func _ready() -> void:
	if not load_save():
		_init_defaults()
		_init_narrative_state()


func _init_defaults() -> void:
	# Zane  Arcanist path  Resonant
	_reg("zane", "Zane",
		["fireball", "thunderstrike", "void_pulse"],
		["blizzard", "dark_breath", "elemental_convergence"])
	unit_registry["zane"]["current_job_id"] = "arcanist"
	unit_registry["zane"]["job_jp"]         = { "arcanist": 0 }

	# Mira  Arcanist  Luminary path
	_reg("mira", "Mira Vey",
		["fireball", "cure", "holy_strike"],
		["blizzard", "luminous_barrier", "mass_cure"])
	unit_registry["mira"]["current_job_id"] = "arcanist"
	unit_registry["mira"]["job_jp"]         = { "arcanist": 0 }

	# Kael  Squire  Warder  Void Knight path
	_reg("kael", "Kael",
		["slash", "mighty_strike", "defend"],
		["cover_ally", "iron_wall", "retribution"])
	unit_registry["kael"]["current_job_id"] = "squire"
	unit_registry["kael"]["job_jp"]         = { "squire": 0 }

	# Lyra  Scout  Shadow path
	_reg("lyra", "Lyra",
		["long_shot", "quickstep"],
		["rain_of_arrows", "smoke_screen", "shadow_step"])
	unit_registry["lyra"]["current_job_id"] = "scout"
	unit_registry["lyra"]["job_jp"]         = { "scout": 0 }
	_init_loadout_progress_defaults()


func _init_loadout_progress_defaults() -> void:
	for vow: Dictionary in VowSigilDefs.VOWS:
		var vow_id := str(vow.get("id", ""))
		if not vow_id.is_empty() and not vow_progress.has(vow_id):
			vow_progress[vow_id] = 0
	for sigil: Dictionary in VowSigilDefs.SIGILS:
		var sigil_id := str(sigil.get("id", ""))
		if not sigil_id.is_empty() and not sigil_progress.has(sigil_id):
			sigil_progress[sigil_id] = 0


func get_vow_xp(vow_id: String) -> int:
	return int(vow_progress.get(vow_id, 0))


func get_sigil_xp(sigil_id: String) -> int:
	return int(sigil_progress.get(sigil_id, 0))


func seed_run_loadout(run: RunState) -> void:
	if not run:
		return
	_init_loadout_progress_defaults()
	run.equipped_vow_xp = get_vow_xp(run.equipped_vow_id)
	run.equipped_vow_level = VowSigilDefs.level_for_xp(run.equipped_vow_xp)
	run.equipped_sigil_xp = get_sigil_xp(run.equipped_sigil_id)
	run.equipped_sigil_level = VowSigilDefs.level_for_xp(run.equipped_sigil_xp)


func apply_loadout_xp(amount: int, reason: String = "") -> Dictionary:
	if amount <= 0 or active_run == null:
		return {}
	_init_loadout_progress_defaults()
	var vow_id := active_run.equipped_vow_id
	var sigil_id := active_run.equipped_sigil_id
	var before_vow_level := VowSigilDefs.level_for_xp(get_vow_xp(vow_id))
	var before_sigil_level := VowSigilDefs.level_for_xp(get_sigil_xp(sigil_id))
	vow_progress[vow_id] = get_vow_xp(vow_id) + amount
	sigil_progress[sigil_id] = get_sigil_xp(sigil_id) + amount
	seed_run_loadout(active_run)
	var result := {
		"amount": amount,
		"reason": reason,
		"vow_id": vow_id,
		"vow_level_before": before_vow_level,
		"vow_level_after": active_run.equipped_vow_level,
		"vow_leveled": active_run.equipped_vow_level > before_vow_level,
		"sigil_id": sigil_id,
		"sigil_level_before": before_sigil_level,
		"sigil_level_after": active_run.equipped_sigil_level,
		"sigil_leveled": active_run.equipped_sigil_level > before_sigil_level,
	}
	pending_rewards["loadout_xp"] = int(pending_rewards.get("loadout_xp", 0)) + amount
	pending_rewards["loadout_xp_reason"] = reason
	pending_rewards["loadout_progress"] = result
	save()
	return result


func _reg(uid: String, dname: String,
		base: Array[String], learnable: Array[String]) -> void:
	unit_registry[uid] = {
		"display_name":        dname,
		"jp":                  0,
		"base_abilities":      base,
		"learned_abilities":   [],
		"learnable_abilities": learnable,
		"equipped_abilities":  base.slice(0, min(base.size(), 4)),
		"equipment": {
			"main_hand": "Training Blade",
			"off_hand": "Buckler",
			"head": "Cloth Cap",
			"body": "Traveling Garb",
			"accessory": "Copper Ring",
		},
	}


#  Ability queries

## Full ability list for a unit: base + every JP-purchased ability.
func get_all_abilities(unit_id: String) -> Array[String]:
	if not unit_registry.has(unit_id):
		return []
	var reg: Dictionary = unit_registry[unit_id]
	var equipped: Array = reg.get("equipped_abilities", [])
	if not equipped.is_empty():
		var chosen: Array[String] = []
		for ab: Variant in equipped:
			if knows_ability(unit_id, str(ab)) and str(ab) not in chosen:
				chosen.append(str(ab))
		if not chosen.is_empty():
			return chosen
	var result: Array[String] = []
	result.append_array(reg.get("base_abilities", []))
	for ab: String in reg.get("learned_abilities", []):
		if ab not in result:
			result.append(ab)
	return result


## Returns true if unit already knows the ability (base or learned).
func knows_ability(unit_id: String, ability_id: String) -> bool:
	if not unit_registry.has(unit_id):
		return false
	var reg: Dictionary = unit_registry[unit_id]
	return ability_id in reg.get("base_abilities", []) \
		or ability_id in reg.get("learned_abilities", [])


## Spends JP to learn an ability.  Returns true on success.
func learn_ability(unit_id: String, ability_id: String) -> bool:
	if not unit_registry.has(unit_id):
		return false
	var reg: Dictionary = unit_registry[unit_id]
	if knows_ability(unit_id, ability_id):
		return false
	var ab: Dictionary = AbilityDBScript.get_ability(ability_id)
	var cost: int = ab.get("jp_cost", 9999)
	if reg.get("jp", 0) < cost:
		return false
	reg["jp"] = reg.get("jp", 0) - cost
	reg["learned_abilities"].append(ability_id)
	return true


func get_jp(unit_id: String) -> int:
	if not unit_registry.has(unit_id):
		return 0
	return unit_registry[unit_id].get("jp", 0)


func set_current_job(unit_id: String, job_id: String) -> void:
	if not unit_registry.has(unit_id):
		return
	var reg: Dictionary = unit_registry[unit_id]
	reg["current_job_id"] = job_id
	if not reg.has("job_jp"):
		reg["job_jp"] = {}
	if not reg["job_jp"].has(job_id):
		reg["job_jp"][job_id] = 0
	var job := JobTreeData.get_job(job_id)
	if not job.is_empty():
		reg["learnable_abilities"] = job.get("abilities", [])
	save()


func set_equipped_abilities(unit_id: String, ability_ids: Array) -> void:
	if not unit_registry.has(unit_id):
		return
	var equipped: Array[String] = []
	for ab: Variant in ability_ids:
		var ab_id := str(ab)
		if knows_ability(unit_id, ab_id) and ab_id not in equipped:
			equipped.append(ab_id)
		if equipped.size() >= 4:
			break
	unit_registry[unit_id]["equipped_abilities"] = equipped
	save()


#  Battle results

## Called by BattleScene on victory.  Awards JP to surviving player units.
func apply_victory(map_id: String, rewards: Dictionary,
		player_unit_ids: Array[String]) -> void:
	var gld: int = rewards.get("gold", 0)
	var jp_gain: int = rewards.get("jp", 0)
	gold += gld
	run_jp_earned += jp_gain
	for uid in player_unit_ids:
		if unit_registry.has(uid):
			unit_registry[uid]["jp"] = unit_registry[uid].get("jp", 0) + jp_gain
	if map_id not in completed_stages:
		completed_stages.append(map_id)
	pending_rewards = {
		"gold":    gld,
		"jp":      jp_gain,
		"map_id":  map_id,
		"units":   player_unit_ids.duplicate(),
	}
	save()   # auto-save on every victory




# ============================================================
#  NARRATIVE STATE & BEHAVIOR (merged from former narrative GameState)
#  State-only merge: these methods mutate narrative fields and emit
#  narrative signals. No gameplay/combat behavior was changed.
# ============================================================

func _init_narrative_state():
	_init_characters()
	_init_relationships()
	_init_hub_characters()
	_init_soul_encounters()
	_init_boss_encounters()
	_init_narrative_flags()

func _init_characters():
	var char_ids = ["aeryn", "cael", "brennan", "solan", "mira", "tobias", "seren"]
	for char_id in char_ids:
		characters[char_id] = {
			"id": char_id,
			"human_name": "",  # Will be set by Characters.gd
			"true_name": null,
			"true_name_fragments": 0,
			"costume_integrity": 100,
			"current_job": "",
			"level": 1,
			"intimacy_unlocked": {},
			"hub_visits": 0,
			"crack_event_triggered": false,
			"resolution_reached": false,
			"current_dialogue_tier": 1,
		}

func _init_relationships():
	# All 21 pairwise relationships (7 choose 2)
	var pairs = [
		["aeryn", "cael"], ["aeryn", "brennan"], ["aeryn", "solan"],
		["aeryn", "mira"], ["aeryn", "tobias"], ["aeryn", "seren"],
		["cael", "brennan"], ["cael", "solan"], ["cael", "mira"],
		["cael", "tobias"], ["cael", "seren"],
		["brennan", "solan"], ["brennan", "mira"], ["brennan", "tobias"],
		["brennan", "seren"],
		["solan", "mira"], ["solan", "tobias"], ["solan", "seren"],
		["mira", "tobias"], ["mira", "seren"],
		["tobias", "seren"]
	]
	for pair in pairs:
		var key = "_".join(pair)
		relationships[key] = {
			"intimacy": 0,
			"moments_shared": [],
			"tension_dialogue_unlocked": false
		}

func _init_hub_characters():
	var hub_ids = ["azrael", "lilith", "aurora", "ereshkigal", "somnus", "osiris", "anamnesis", "archivist"]
	for hub_id in hub_ids:
		hub_characters[hub_id] = {
			"met": false,
			"conversations": 0,
			"gifts_given": [],
			"dialogue_tier": 1
		}
	# Special fields
	hub_characters.archivist["knows_the_truth"] = false
	hub_characters.somnus["dream_reveals_given"] = []
	hub_characters.anamnesis["visits"] = 0
	hub_characters.anamnesis["fragments_returned"] = []
	hub_characters.osiris["introduced"] = false

func _init_soul_encounters():
	var soul_ids = ["adam", "eve", "cain", "moses", "elijah", "david", "job"]
	for soul_id in soul_ids:
		soul_encounters[soul_id] = _fresh_soul_state()

## Canonical per-soul state shape. MUST match what SoulResolver._soul_state()
## creates lazily, so a seeded entry and a lazily-created one are identical.
## (encounter_state/"met" from the old prototype shape are derived, not stored:
##  met == encounters_seen > 0; encounter_state is read from the served beat.)
func _fresh_soul_state() -> Dictionary:
	return {
		"encounters_seen": 0,
		"core_index": 0,
		"secrets_seen": [],
		"courier_resolved": {},
		"lingering_index": 0,
		"departed": false,
	}

func _init_boss_encounters():
	var boss_ids = ["the_righteous_one", "the_keeper", "the_devoted", "the_wrathful", "the_mirror"]
	for boss_id in boss_ids:
		boss_encounters[boss_id] = {
			"total_fights": 0,
			"last_killed_by": null,
			"player_fled": false,
			"talk_path_attempted": false,
			"talk_path_completed": false,
			"current_dialogue_loop": null
		}
	# Mirror special fields
	boss_encounters.the_mirror["total_appearances"] = 0
	boss_encounters.the_mirror["characters_targeted"] = []
	boss_encounters.the_mirror["last_target"] = null

func _init_narrative_flags():
	# Tier 1
	narrative_flags["first_enemy_hesitation"] = false
	narrative_flags["first_run_complete"] = false
	# Tier 2
	narrative_flags["enemy_spoke_words"] = false
	# Crack events
	for char_id in ["aeryn", "cael", "brennan", "solan", "mira", "tobias", "seren"]:
		narrative_flags[char_id + "_crack_event_complete"] = false
	# More flags added as needed during gameplay

#  Run Lifecycle

func narrative_begin_run():
	current_run += 1
	total_runs += 1
	clarity = GameConfig.CLARITY.START
	run_started.emit(current_run)

func narrative_end_run(summary: Dictionary):
	# summary: {soulsHelped, bossesDefeated, bossesFled, clarityAtEnd, etc.}
	run_history.append({
		"run": current_run,
		"summary": summary
	})
	run_ended.emit(current_run)


#  Roguelike Battle Flow



#  Revelation

func gain_revelation(points: int, source: String = ""):
	revelation_points += points
	var new_tier = GameConfig.calculate_tier_from_points(revelation_points)
	if new_tier != revelation_tier:
		revelation_tier = new_tier
		revelation_tier_changed.emit(revelation_tier)

#  Clarity

func gain_clarity(amount: int, reason: String = ""):
	clarity = clampi(clarity + amount, GameConfig.CLARITY.MIN, GameConfig.CLARITY.MAX)
	clarity_changed.emit(clarity)

func lose_clarity(amount: int, reason: String = ""):
	clarity = clampi(clarity - amount, GameConfig.CLARITY.MIN, GameConfig.CLARITY.MAX)
	clarity_changed.emit(clarity)

#  Character Arcs

func trigger_crack_event(char_id: String):
	if not characters.has(char_id):
		return

	var char = characters[char_id]
	char.crack_event_triggered = true
	char.costume_integrity = max(0, char.costume_integrity + GameConfig.COSTUME_INTEGRITY.CRACK_EVENT)

	gain_clarity(GameConfig.CLARITY.CRACK_EVENT_TRIGGERED)
	gain_revelation(30, "crack_event_" + char_id)
	narrative_flags[char_id + "_crack_event_complete"] = true

	character_crack_event.emit(char_id)

func lower_costume(char_id: String, amount: int):
	if not characters.has(char_id):
		return
	var char = characters[char_id]
	char.costume_integrity = max(0, char.costume_integrity + amount)  # amount is negative

func add_true_name_fragment(char_id: String):
	if not characters.has(char_id):
		return
	var char = characters[char_id]
	char.true_name_fragments += 1
	lower_costume(char_id, GameConfig.COSTUME_INTEGRITY.TRUE_NAME_FRAGMENT)
	gain_clarity(GameConfig.CLARITY.TRUE_NAME_FRAGMENT)

func reveal_true_name(char_id: String, true_name: String):
	if not characters.has(char_id):
		return
	var char = characters[char_id]
	char.true_name = true_name
	char.costume_integrity = 0
	gain_revelation(50, "true_name_" + char_id)
	gain_clarity(GameConfig.CLARITY.TRUE_NAME_FRAGMENT)
	character_true_name_revealed.emit(char_id, true_name)

func reach_resolution(char_id: String):
	if not characters.has(char_id):
		return
	characters[char_id].resolution_reached = true
	gain_revelation(100, "resolution_" + char_id)

#  Relationships

func get_relationship_key(char_a: String, char_b: String) -> String:
	var pair = [char_a, char_b]
	pair.sort()
	return "_".join(pair)

func gain_intimacy(char_a: String, char_b: String, amount: int):
	var key = get_relationship_key(char_a, char_b)
	if not relationships.has(key):
		return
	relationships[key].intimacy += amount
	if relationships[key].intimacy >= 15:
		relationships[key].tension_dialogue_unlocked = true

func add_shared_moment(char_a: String, char_b: String, moment_id: String):
	var key = get_relationship_key(char_a, char_b)
	if not relationships.has(key):
		return
	if moment_id not in relationships[key].moments_shared:
		relationships[key].moments_shared.append(moment_id)

#  Hub Characters

func meet_hub_character(hub_char_id: String):
	if not hub_characters.has(hub_char_id):
		return
	if hub_characters[hub_char_id].met:
		return  # Already met
	hub_characters[hub_char_id].met = true
	gain_revelation(10, "hub_met_" + hub_char_id)
	hub_character_met.emit(hub_char_id)

func hub_conversation(hub_char_id: String):
	if not hub_characters.has(hub_char_id):
		return
	hub_characters[hub_char_id].conversations += 1
	gain_clarity(GameConfig.CLARITY.HUB_RELATIONSHIP_MOMENT)

	# Auto-advance dialogue tier
	var convos = hub_characters[hub_char_id].conversations
	var current_tier = hub_characters[hub_char_id].dialogue_tier
	if convos >= 8:
		hub_characters[hub_char_id].dialogue_tier = min(5, current_tier + 1)
	elif convos >= 4:
		hub_characters[hub_char_id].dialogue_tier = min(4, current_tier + 1)

func give_hub_gift(hub_char_id: String, gift_id: String):
	if not hub_characters.has(hub_char_id):
		return
	if gift_id in hub_characters[hub_char_id].gifts_given:
		return  # Already gave this gift
	hub_characters[hub_char_id].gifts_given.append(gift_id)
	gain_revelation(15, "gift_" + hub_char_id)

func archivist_learns_truth():
	hub_characters.archivist.knows_the_truth = true
	gain_revelation(40, "archivist_truth")
	narrative_flags.archivist_tier4_conversation = true

#  Souls

func meet_soul(soul_id: String):
	if not soul_encounters.has(soul_id):
		return
	if soul_encounters[soul_id].met:
		return
	soul_encounters[soul_id].met = true
	soul_encounters[soul_id].encounter_state = "early"
	gain_revelation(20, "soul_" + soul_id)
	gain_clarity(GameConfig.CLARITY.SOUL_CONVERSATION)
	soul_encountered.emit(soul_id)

func advance_soul_encounter(soul_id: String, new_state: String):
	if not soul_encounters.has(soul_id):
		return
	soul_encounters[soul_id].encounter_state = new_state
	gain_revelation(25, "soul_advance_" + soul_id)

func soul_departs(soul_id: String):
	if not soul_encounters.has(soul_id):
		return
	soul_encounters[soul_id].departed = true
	soul_encounters[soul_id].encounter_state = "departed"
	gain_revelation(40, "soul_depart_" + soul_id)
	narrative_flags[soul_id + "_departed"] = true

#  Bosses

func boss_fight_complete(boss_id: String, killed_by_char_id: String):
	if not boss_encounters.has(boss_id):
		return
	boss_encounters[boss_id].total_fights += 1
	boss_encounters[boss_id].last_killed_by = killed_by_char_id
	boss_encounters[boss_id].current_dialogue_loop = total_runs
	boss_defeated.emit(boss_id, killed_by_char_id)

func boss_talk_path_attempted(boss_id: String):
	if not boss_encounters.has(boss_id):
		return
	boss_encounters[boss_id].talk_path_attempted = true

func boss_talk_path_complete(boss_id: String):
	if not boss_encounters.has(boss_id):
		return
	boss_encounters[boss_id].talk_path_completed = true
	gain_revelation(60, "boss_talk_" + boss_id)
	gain_clarity(GameConfig.CLARITY.BOSS_DIALOGUE_UNLOCKED)

func player_fled_boss(boss_id: String):
	if not boss_encounters.has(boss_id):
		return
	boss_encounters[boss_id].player_fled = true
	lose_clarity(abs(GameConfig.CLARITY.FALLEN_ARGUMENT_FLED))

func mirror_appeared(target_char_id: String):
	var mirror = boss_encounters.the_mirror
	mirror.total_appearances += 1
	if target_char_id not in mirror.characters_targeted:
		mirror.characters_targeted.append(target_char_id)
	mirror.last_target = target_char_id

#  Narrative Flags

func set_flag(flag_name: String, value: bool = true):
	narrative_flags[flag_name] = value

func get_flag(flag_name: String) -> bool:
	return narrative_flags.get(flag_name, false)

#  Getters

func get_character(char_id: String) -> Dictionary:
	return characters.get(char_id, {})

func get_relationship(char_a: String, char_b: String) -> Dictionary:
	var key = get_relationship_key(char_a, char_b)
	return relationships.get(key, {})

func get_hub_character(hub_char_id: String) -> Dictionary:
	return hub_characters.get(hub_char_id, {})

func get_soul_encounter(soul_id: String) -> Dictionary:
	return soul_encounters.get(soul_id, {})

func get_boss_encounter(boss_id: String) -> Dictionary:
	return boss_encounters.get(boss_id, {})


#  Persistence

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes current state to disk.  Silent on failure.
func save() -> void:
	var unit_jp:        Dictionary = {}
	var unit_learned:   Dictionary = {}
	var unit_jobs:      Dictionary = {}
	var unit_job_jp:    Dictionary = {}
	var unit_equipped:  Dictionary = {}
	var unit_equipment: Dictionary = {}
	for uid in unit_registry:
		var reg: Dictionary = unit_registry[uid]
		unit_jp[uid]        = reg.get("jp", 0)
		unit_learned[uid]   = reg.get("learned_abilities", []).duplicate()
		unit_jobs[uid]      = reg.get("current_job_id", "")
		unit_job_jp[uid]    = reg.get("job_jp", {}).duplicate()
		unit_equipped[uid]  = reg.get("equipped_abilities", []).duplicate()
		unit_equipment[uid] = reg.get("equipment", {}).duplicate()

	var data: Dictionary = {
		"version":          SAVE_VERSION,
		"gold":             gold,
		"completed_stages": completed_stages.duplicate(),
		"story_flags":      story_flags.duplicate(),
		"unit_jp":          unit_jp,
		"unit_learned":     unit_learned,
		"unit_jobs":        unit_jobs,
		"unit_job_jp":      unit_job_jp,
		"unit_equipped":    unit_equipped,
		"unit_equipment":   unit_equipment,
		"vow_progress":     vow_progress.duplicate(),
		"sigil_progress":   sigil_progress.duplicate(),
		"narrative": {
			"total_runs":        total_runs,
			"current_run":       current_run,
			"revelation_tier":   revelation_tier,
			"revelation_points": revelation_points,
			"clarity":           clarity,
			"characters":        characters.duplicate(true),
			"relationships":     relationships.duplicate(true),
			"hub_characters":    hub_characters.duplicate(true),
			"soul_encounters":   soul_encounters.duplicate(true),
			"boss_encounters":   boss_encounters.duplicate(true),
			"narrative_flags":   narrative_flags.duplicate(true),
			"run_history":       run_history.duplicate(true),
		},
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_warning("GameState.save: could not open %s for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Loads save file.  Returns false if no file or format mismatch.
## On success populates gold, completed_stages, and per-unit JP/learned.
func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("GameState.load_save: JSON parse failed or not a dict.")
		return false

	var data: Dictionary = parsed as Dictionary
	if data.get("version", 0) != SAVE_VERSION:
		push_warning("GameState.load_save: version mismatch  starting fresh.")
		return false

	# Populate registry with defaults first so learnable/base lists are intact
	_init_defaults()

	gold = int(data.get("gold", 0))

	completed_stages.clear()
	for s: Variant in data.get("completed_stages", []):
		completed_stages.append(str(s))

	story_flags.clear()
	for flag: Variant in data.get("story_flags", []):
		story_flags.append(str(flag))

	var saved_jp:        Dictionary = data.get("unit_jp", {})
	var saved_learned:   Dictionary = data.get("unit_learned", {})
	var saved_jobs:      Dictionary = data.get("unit_jobs", {})
	var saved_job_jp:    Dictionary = data.get("unit_job_jp", {})
	var saved_equipped:  Dictionary = data.get("unit_equipped", {})
	var saved_equipment: Dictionary = data.get("unit_equipment", {})
	var saved_vow_progress: Variant = data.get("vow_progress", {})
	var saved_sigil_progress: Variant = data.get("sigil_progress", {})
	vow_progress = {}
	if saved_vow_progress is Dictionary:
		vow_progress = (saved_vow_progress as Dictionary).duplicate()
	sigil_progress = {}
	if saved_sigil_progress is Dictionary:
		sigil_progress = (saved_sigil_progress as Dictionary).duplicate()
	_init_loadout_progress_defaults()

	for uid: String in unit_registry:
		if saved_jp.has(uid):
			unit_registry[uid]["jp"] = int(saved_jp[uid])
		if saved_learned.has(uid):
			var raw: Array = saved_learned[uid]
			var typed: Array[String] = []
			for ab: Variant in raw:
				typed.append(str(ab))
			unit_registry[uid]["learned_abilities"] = typed
		if saved_jobs.has(uid):
			unit_registry[uid]["current_job_id"] = str(saved_jobs[uid])
		if saved_job_jp.has(uid) and saved_job_jp[uid] is Dictionary:
			unit_registry[uid]["job_jp"] = (saved_job_jp[uid] as Dictionary).duplicate()
		if saved_equipped.has(uid) and saved_equipped[uid] is Array:
			var eq: Array[String] = []
			for ab: Variant in saved_equipped[uid]:
				eq.append(str(ab))
			unit_registry[uid]["equipped_abilities"] = eq
		if saved_equipment.has(uid) and saved_equipment[uid] is Dictionary:
			unit_registry[uid]["equipment"] = (saved_equipment[uid] as Dictionary).duplicate()
	# ── Narrative state (merged) ──
	_init_narrative_state()   # seed defaults, then overlay saved values
	if data.has("narrative") and data["narrative"] is Dictionary:
		var nar: Dictionary = data["narrative"]
		total_runs        = int(nar.get("total_runs", total_runs))
		current_run       = int(nar.get("current_run", current_run))
		revelation_tier   = int(nar.get("revelation_tier", revelation_tier))
		revelation_points = int(nar.get("revelation_points", revelation_points))
		clarity           = int(nar.get("clarity", clarity))
		if nar.get("characters") is Dictionary:      characters      = (nar["characters"] as Dictionary).duplicate(true)
		if nar.get("relationships") is Dictionary:   relationships   = (nar["relationships"] as Dictionary).duplicate(true)
		if nar.get("hub_characters") is Dictionary:  hub_characters  = (nar["hub_characters"] as Dictionary).duplicate(true)
		if nar.get("soul_encounters") is Dictionary: soul_encounters = (nar["soul_encounters"] as Dictionary).duplicate(true)
		if nar.get("boss_encounters") is Dictionary: boss_encounters = (nar["boss_encounters"] as Dictionary).duplicate(true)
		if nar.get("narrative_flags") is Dictionary: narrative_flags = (nar["narrative_flags"] as Dictionary).duplicate(true)
		if nar.get("run_history") is Array:          run_history     = (nar["run_history"] as Array).duplicate(true)

	return true


## Wipes the save file and resets in-memory state to defaults.
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save.json")
	gold = 0
	completed_stages.clear()
	story_flags.clear()
	pending_rewards.clear()
	vow_progress.clear()
	sigil_progress.clear()
	unit_registry.clear()
	_init_defaults()
