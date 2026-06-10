extends Node
# ============================================================
#  THE APPOINTED: AS ABOVE
#  Souls.gd — The seven Historical Souls (data autoload)
# ============================================================
#
#  Ported from archive_react/historicalSouls.js. These are the most
#  important conversations in the game: souls mid-ascent, each carrying
#  a verse where the orthodox telling required swallowing an injustice
#  and calling it holy — and each has had eternity to stop swallowing it.
#
#  Found as "?" encounters. Optional. Missable. Devastating.
#  SoulResolver.gd consumes this data; it never picks two beats per visit.
#
#  Schema (snake_case, matches SoulResolver):
#    id, name, known_as, assigned_character (or null),
#    unlock_requirement: { min_runs, min_tier?, adam_encounter_complete?,
#                          character_intimacy?:{id:int}, trigger_condition? }
#    location, core_theme, what_carries, what_gives,
#    roles:[mirror|witness|courier], emotional_threads:[...], witness_partner?,
#    encounters:[ { run_required, state, dialogue:[...],
#                   departs_after?, emits?:{carried_message?,arc_beat?:{id:beat}},
#                   departure_note? } ],
#    secret_convos:[ { id, thread, insert_before, unlock:{min_encounters,
#                      party_resonance:{any_of:[...],min_runs_together}},
#                      dialogue:[...], emits?, codex_entry? } ],
#    courier_beats:[ { id, requires:{has_carried}, delivery,
#                      on_deliver:{dialogue,codex_entry,unlocks_departure?,emits?},
#                      on_withhold:{dialogue,codex_entry,recoverable_while,
#                                   lingering:[[...],[...]]} } ]
#
#  TO SET UP: Autoload as "Souls".
# ============================================================

const SOULS := {

	# ── ADAM ────────────────────────────────────────────────
	"adam": {
		"id": "adam",
		"name": "Adam",
		"known_as": "The First",
		"assigned_character": null,
		"unlock_requirement": {"min_runs": 20, "min_tier": 3},
		"location": "A garden that is also ruins — both at once, somehow",
		"floor_affinity": {"min": 1, "max": 3, "weight": 3},
		"core_theme": "The first choice. The first deflection. The first man to hold something in his hands and say: someone else is responsible for this. He has had longer than anyone to understand what he did. He understands it now. The understanding has not made it smaller.",
		"what_carries": "Genesis 3:12. He blamed Eve. He blamed God. In the same sentence. The first deflection in human history. He knows he could have said no. He has been sitting with the gap between what happened and what he said happened for longer than civilization.",
		"what_gives": "The pattern didn't begin with malice. It began with love and a door that love had to leave open. Free will means the capacity to choose the dark cycle — and the capacity to say: I did this. I chose this. I am this. And stay standing after.",
		"roles": ["mirror", "witness", "courier"],
		"emotional_threads": ["deflection", "shame", "grief", "ownership"],
		"witness_partner": "eve",
		"encounters": [
			{
				"run_required": 20,
				"state": "early",
				"dialogue": [
					"I know what you are. I've been watching this loop since before you remembered you were in it.",
					"Sit. I have something to say and I've been waiting for someone who could hear it.",
					"I blamed her because I was afraid, and I loved her, and I didn't know how to hold both of those at once.",
					"That's all it was. That's what sin is — not the reaching for the fruit. The not being able to say: I did this. I chose this. I am this.",
					"[beat]",
					"Every war you've ever fought. Every loop. Every human who ever burned a city or broke a family or looked away from someone suffering —",
					"they were all in that garden. And they all said: she gave it to me. He made me. I had no choice.",
					"The pattern God put in place isn't cruelty. It's this moment, repeated, until someone learns to say: I did this.",
					"And stays standing after.",
				],
			},
			{
				"run_required": 30,
				"state": "middle",
				"dialogue": [
					"You're back. Good.",
					"You're asking me if it was worth it. I'm asking you the same thing. You've lived a hundred lives in this world. Was it worth feeling it?",
					"I don't mean the pain. I mean all of it. The hunger, the love, the moment before the choice, the grief after. The full weight of being someone specific in a specific moment that cannot be undone.",
					"I think God wanted to know if love could survive knowing the cost. I think the experiment is still running.",
				],
			},
			{
				"run_required": 40,
				"state": "late",
				"departs_after": true,
				"emits": {"carried_message": "adam_to_eve"},
				"departure_note": "Adam is gone after this encounter. The garden location has a single apple on the ground, unblemished. It does not need to be interacted with. It means what it means.",
				"dialogue": [
					"I'm nearly done here. I can feel it.",
					"It took me longer than it should have. But it took exactly as long as it took. I've had to make peace with that too.",
					"Tell Eve — if you find her — that I understand now. That the reaching wasn't the problem. That I've known that for a long time and it took me even longer to say it out loud.",
					"[beat]",
					"The garden was always supposed to end. Not because God was done with us. Because we were supposed to begin.",
				],
			},
		],
		"secret_convos": [
			{
				"id": "adam_shame",
				"thread": "shame",
				"insert_before": 40,
				"unlock": {
					"min_encounters": 2,
					"party_resonance": {"any_of": ["cael", "aeryn"], "min_runs_together": 3},
				},
				"emits": {"arc_beat": {"cael": "envy_recognition"}},
				"codex_entry": "adam_on_shame",
				"dialogue": [
					"You brought the one who fights for everyone but themselves.",
					"I know the shape of that. I invented part of it.",
					"[beat]",
					"Listen. The blame — 'she gave it to me' — that wasn't the worst of it. That was one morning. One frightened sentence. I could have lived that down.",
					"The worst of it was every morning after. I let her carry it. I watched them build the story where she was the door sin walked through, and I was the man it happened to. And I said nothing. For an age. Because saying something meant being the man who ate it too.",
					"That's not guilt. Guilt is 'I did a bad thing.' I could have worked with guilt.",
					"This was the other one. The one that says: I am the bad thing. So I'd better be useful. I'd better be righteous about someone else's pain, loudly, forever, so no one looks too long at mine.",
					"[beat]",
					"[He turns, not to the party, but to Cael directly.]",
					"You fight for their worth because you settled the question of your own a long time ago, and you settled it wrong. You decided you don't get to want anything for yourself. So you launder the wanting through causes that are real enough to hide in.",
					"I did the same thing with righteousness. It works. It works for a very long time.",
					"It is not the same as being forgiven.",
				],
			},
		],
	},

	# ── EVE ─────────────────────────────────────────────────
	"eve": {
		"id": "eve",
		"name": "Eve",
		"known_as": "The First Reach",
		"assigned_character": null,
		"unlock_requirement": {"min_runs": 25, "adam_encounter_complete": true},
		"location": "A different part of the same garden — further in, where it's more overgrown",
		"floor_affinity": {"min": 1, "max": 3, "weight": 3},
		"core_theme": "Curiosity. The original impulse to know. She has been called the source of sin for longer than she can count. She has a different view.",
		"what_carries": "The choice was hers. She doesn't carry it as guilt — she worked through guilt and found something underneath it: the knowledge that wanting to understand is not wrong. That God knew. That God always knew, and chose to give them the fruit anyway, via a path that would look like choice.",
		"what_gives": "What God actually wanted. Not obedience. Understanding. The apple wasn't a test of whether they would obey — it was the beginning of the education. She tells the party, in plain words, what they are here for. Not as a revelation. As a conversation.",
		"roles": ["witness", "courier"],
		"emotional_threads": ["wanting", "forgiveness", "grief"],
		"witness_partner": "adam",
		"encounters": [
			{
				"run_required": 25,
				"state": "early",
				"dialogue": [
					"I wondered when someone would come this far in.",
					"Adam told you about the blame. Good. He needed to say that to someone who would understand it.",
					"I'm not angry with him. I was, once. For a very long time. Then I understood what fear does to people who love each other.",
					"I reached for the fruit because I wanted to know. That's the whole story. I wanted to know what God knows. I wanted to understand.",
					"[beat]",
					"I've been told that wanting to understand was the sin. I've been sitting with that for a very long time. And I think it's wrong. I think it's the most wrong thing anyone has ever said about me.",
				],
			},
			{
				"run_required": 35,
				"state": "middle",
				"dialogue": [
					"He didn't punish me for reaching. He made reaching the point.",
					"Everything since — every loop, every war, every person who turns out to be something older than they appear — it all grows from that first morning when I wanted to know.",
					"I'm not sorry. I don't think He wanted me to be.",
					"[beat]",
					"You are here because you are trying to understand humanity from the inside. That was always the assignment. I was the first version of it. You are a later one. The method has been refined.",
					"He learns too, I think. That's the part that took me the longest to accept. That the creation of something new means encountering something new. Even for God.",
				],
			},
		],
		"courier_beats": [
			{
				"id": "eve_forgiveness",
				"requires": {"has_carried": "adam_to_eve"},
				"delivery": "player_choice",
				"on_deliver": {
					"codex_entry": "eve_forgives",
					"unlocks_departure": "eve_at_peace",
					"dialogue": [
						"[You hold out what Adam asked you to carry. You do not speak. You don't need to.]",
						"[She reads it the way you read something you already know — slowly, because the knowing and the hearing are different countries.]",
						"...He said it out loud.",
						"I told you I wasn't angry with him. That was true. I worked the anger through an age ago. But there's a thing underneath anger that anger keeps you from noticing, and it's this: I had been waiting. I didn't know I was waiting. You can wait for something for a very long time and call it peace.",
						"He didn't need to apologize for the reaching. The reaching was right. I never needed that.",
						"I needed him to say he saw me carry it. That's all. That he watched, and knew, and that the silence cost him too.",
						"[beat]",
						"Tell him —",
						"[She stops. Smiles, a little.]",
						"No. You won't find him now. That's all right. Some things only have to be true once to be true.",
						"I can go on from here. I think I've been able to for a while. I just wanted to be sure he got there too.",
					],
				},
				"on_withhold": {
					"codex_entry": "eve_message_withheld",
					"recoverable_while": "eve_present",
					"dialogue": [
						"You've seen him. I can tell. People who've sat with Adam carry a little of his quiet out with them.",
						"[She waits. You don't offer anything. Something in her settles back down — an old, practiced settling.]",
						"...That's all right. You don't have to.",
						"I'm not angry with him. I want you to understand that. I was never angry.",
						"[beat]",
						"It's only that I keep the garden tended further in than I need to. In case someone comes through it. I tell myself it's for the work. I've told myself that for a long time.",
					],
					"lingering": [
						[
							"You're back. I'm glad. It gets quiet this far in.",
							"Did he look well? You don't have to answer. I just — I find I want the picture, even an incomplete one.",
						],
						[
							"I've been thinking about what I'd say. I had it ready once. I think I've stopped trusting that I'll get to say it, so I keep editing it. That's the thing no one tells you about waiting. It doesn't hold still. It goes stale and you rewrite it and it goes stale again.",
						],
						[
							"I could let it go. I want you to know I know that. I'm not trapped here. The door's open. I've looked at it.",
							"I just keep deciding, one more time, to stay where he might find me. It isn't peace. I called it peace for an age. It isn't.",
							"[beat]",
							"If you see him. That's all. If you see him.",
						],
					],
				},
			},
		],
	},

	# ── CAIN ────────────────────────────────────────────────
	"cain": {
		"id": "cain",
		"name": "Cain",
		"known_as": "The First Wound",
		"assigned_character": "cael",
		"unlock_requirement": {"min_runs": 12, "min_tier": 2, "character_intimacy": {"cael": 30}},
		"location": "A field. Alone. Has been alone here for a long time.",
		"floor_affinity": {"min": 2, "max": 4, "weight": 2},
		"core_theme": "The first murder was envy. Cain didn't want Abel's lamb. He wanted God's favor, which he believed he deserved, didn't receive, and couldn't understand why. The most ancient question: why does he get what I don't?",
		"what_carries": "The mark. The exile. The specific weight of being the first person to understand what it feels like to take something that cannot be returned. He has not excused himself. But the underneath is not what the simple story suggests.",
		"what_gives": "Envy is a distorted sense of justice. 'Why does he get what I don't' is the question of fairness, of worth. It becomes evil when it chooses a direction: toward taking rather than toward asking.",
		"roles": ["mirror"],
		"emotional_threads": ["envy", "favoritism", "grief"],
		"encounters": [
			{
				"run_required": 12,
				"state": "early",
				"dialogue": [
					"You've killed hundreds. How many felt like family?",
					"[a long beat — not hostile, just a question waiting for an answer]",
					"I'm not judging you. I'm the last person with standing to judge you. I'm asking because it's different when it's family. When you've looked at someone you love and found that the love and the resentment were in the same room at the same time.",
					"I didn't want his lamb. I wanted to be seen the way he was seen. I wanted it more than anything. And I didn't know how to want something that badly without it eating everything else.",
				],
			},
			{
				"run_required": 22,
				"state": "middle",
				"dialogue": [
					"I've been thinking about what I would have needed. Not to not-kill him — though that obviously. But before that. What I would have needed at the start.",
					"I think I needed someone to ask me what I wanted. Just for myself. Not in comparison to Abel. Not in the context of God's favor. Just: Cain. What do you want?",
					"[beat]",
					"Do you know what I would have said? I have no idea. That's the problem. I didn't know. I had never asked.",
					"Go find Cael. Tell them I said: ask the question you keep not asking.",
				],
			},
		],
	},

	# ── MOSES ───────────────────────────────────────────────
	"moses": {
		"id": "moses",
		"name": "Moses",
		"known_as": "He Who Struck the Rock",
		"assigned_character": "brennan",
		"unlock_requirement": {"min_runs": 15, "min_tier": 3, "character_intimacy": {"brennan": 25}},
		"location": "Near a stone formation on the mountain — he is never far from stone",
		"floor_affinity": {"min": 3, "max": 5, "weight": 2},
		"core_theme": "Spoke to God face to face. Parted the sea. Led a nation forty years. Was barred from the promised land for one moment of wrath — striking a rock instead of speaking to it, because he was tired, and forty years of patience ran out for thirty seconds.",
		"what_carries": "Not guilt — he resolved that long ago. He carries the irreducible fact that the fire he used for good for forty years expressed itself in the wrong direction for thirty seconds and cost him the thing he had worked for longer than most people live.",
		"what_gives": "Righteous anger is real and necessary and needs to know what it's for. Not restraint — purpose. The fire that burned forty years in service is the same fire that struck the rock. The question is what the fire knows about itself.",
		"roles": ["mirror"],
		"emotional_threads": ["wrath", "purpose", "grief"],
		"encounters": [
			{
				"run_required": 15,
				"state": "early",
				"dialogue": [
					"I know why you're here. The same reason everyone like you comes to find me.",
					"You want to know if the fire can be managed.",
					"[beat]",
					"Wrong question. The fire doesn't want to be managed. It wants to know what it's for.",
					"I led a million people through a desert for forty years. The fire is what made that possible. It is also what cost me the land at the end.",
					"I don't regret the fire. I have learned what the fire needs that I didn't give it. It needed to know when it was for something and when it was for me. I didn't always know the difference.",
				],
			},
			{
				"run_required": 25,
				"state": "middle",
				"dialogue": [
					"I've been thinking about the moment. The rock.",
					"They were complaining. Again. For forty years they complained and I bore it and I bore it and I bore it. And then I didn't.",
					"The failure wasn't the anger. The failure was that the anger had been there for forty years and I had never given it a name. I'd been calling it 'patience' — carrying it as virtue — while it built pressure in a sealed container.",
					"Name your fire. Give it an honest name. Let it know what it is. Then you can ask it where it wants to go.",
				],
			},
			{
				"run_required": 38,
				"state": "late",
				"dialogue": [
					"I've seen the land, you know. From the mountain. God showed me before I came here.",
					"It was enough. More than enough. The seeing was the gift, not the arriving.",
					"[beat]",
					"Tell Brennan: the fire is a gift. It will be a gift until the end. The work is making sure the fire knows what it loves so it doesn't burn what it loves.",
					"Go. I'm nearly done here.",
				],
			},
		],
	},

	# ── ELIJAH ──────────────────────────────────────────────
	"elijah": {
		"id": "elijah",
		"name": "Elijah",
		"known_as": "He Who Was Fed",
		"assigned_character": "tobias",
		"unlock_requirement": {"min_runs": 10, "min_tier": 2, "character_intimacy": {"tobias": 20}},
		"location": "Under a tree. The only tree in a long stretch of bare stone.",
		"floor_affinity": {"min": 2, "max": 4, "weight": 2},
		"core_theme": "Called fire from heaven, slaughtered false prophets, then collapsed under a tree and asked God to let him die. He was done. He had done the most dramatic thing in prophetic history and he was burned out and wanted it over.",
		"what_carries": "What God's response was: not rebuke. Not theology. An angel. With food. 'The journey is too great for you. Eat.' God understood he was tired. God sent nourishment, not instructions. God knew the body before the spirit could continue.",
		"what_gives": "The body is not the enemy of the spirit. Rest is not weakness. Food is not indulgence. The most holy response to burnout is care. Not discipline. Not harder trying. Care.",
		"roles": ["mirror"],
		"emotional_threads": ["sloth", "exhaustion", "care"],
		"encounters": [
			{
				"run_required": 10,
				"state": "early",
				"dialogue": [
					"Sit down. You look tired.",
					"I was tired. The most tired I had ever been. And I had done everything right. That's the part that made it harder — I had done everything right and I was still finished.",
					"I asked God to take it from me. All of it.",
					"[beat]",
					"God sent breakfast.",
					"Not a revelation. Not a purpose. Not a reason to continue. Bread. Water. And: 'The journey is too great for you. Eat.'",
					"I ate. I slept. I ate again. And then I got up.",
					"I have never fully explained to myself why that worked. But I think it was because God didn't argue with my exhaustion. God honored it.",
				],
			},
			{
				"run_required": 18,
				"state": "middle",
				"dialogue": [
					"The discipline you're describing — this one in your party — tell me about it more.",
					"[listening]",
					"That's not strength. I know what that looks like from the inside. That's the burnt-out prophet trying to earn what has already been given.",
					"The body is not the enemy. It is the place where everything happens. Every moment of contact with the divine happens in a body. Every moment of love. Every moment of pain. Every moment of choice.",
					"Bread. Water. Sleep. These are not concessions to weakness. They are the conditions under which the spirit can continue.",
					"Tell them: the journey is too great for you. Eat.",
				],
			},
		],
	},

	# ── DAVID ───────────────────────────────────────────────
	"david": {
		"id": "david",
		"name": "David",
		"known_as": "The Man After God's Heart",
		"assigned_character": "seren",
		"unlock_requirement": {"min_runs": 18, "min_tier": 3, "character_intimacy": {"seren": 25}},
		"location": "Not a specific place — wherever the Antechamber is least crowded",
		"floor_affinity": {"min": 3, "max": 5, "weight": 2},
		"core_theme": "The most beloved king. Could kill a giant, write psalms, love extravagantly — and see someone from his roof, want them, use his power to have them, and have her husband killed to cover it. The most loved person in scripture and one of the most serious failures of self-knowledge.",
		"what_carries": "That he saw clearly. He wasn't blinded by desire. He knew who Bathsheba was — the wife of a loyal soldier — and wanted her anyway and acted anyway. The desire wasn't the sin. The desire that forgot about the person being desired: that's where it went wrong.",
		"what_gives": "The distinction between wanting to know and wanting to have. Between desire that honors and desire that consumes. He can tell Seren, from the inside, what the difference feels like — and what it cost him not to know it when it mattered.",
		"roles": ["mirror"],
		"emotional_threads": ["lust", "wanting", "grief"],
		"encounters": [
			{
				"run_required": 18,
				"state": "early",
				"dialogue": [
					"I know why you found me and not someone else.",
					"I loved God. Genuinely. More than anything. And I loved people. And I destroyed someone because I loved them the wrong way.",
					"The wanting wasn't the sin. The wanting that forgot about the person being wanted — that's where it went wrong.",
					"[beat]",
					"I saw her and I thought: I want to know her. But by the time I acted, the 'know' had become 'have.' I'm not certain when the shift happened. I've been trying to locate it for longer than I can measure.",
					"The psalms I wrote after — 'Create in me a clean heart' — that's not theater. That's me trying to understand what I actually needed and didn't have. A way of loving that could hold the person being loved.",
				],
			},
			{
				"run_required": 28,
				"state": "middle",
				"dialogue": [
					"The gift your party member has — the ability to see people — it's the most extraordinary thing. I had something like it.",
					"The failure of that gift is when it becomes leverage. When seeing someone becomes the basis for a claim on them.",
					"To see someone fully and let that be enough — to know them and not need to own the knowing — that's the thing I didn't learn in time.",
					"Tell them: the seeing is the gift. The seeing is already everything. The rest is fear.",
				],
			},
		],
	},

	# ── JOB ─────────────────────────────────────────────────
	"job": {
		"id": "job",
		"name": "Job",
		"known_as": "He Who Held",
		"assigned_character": null,
		"unlock_requirement": {"min_runs": 8, "trigger_condition": "a_party_member_at_minimum_costume_integrity"},
		"location": "Found when you're not looking for him — in a quiet corner you haven't been to before",
		"floor_affinity": {"min": 1, "max": 5, "weight": 4},
		"core_theme": "Was tested without explanation. Lost everything. Was given theology by his friends when what he needed was presence. Held anyway. The story doesn't end with Job understanding why. It ends with a voice from the whirlwind — not an explanation but something — and Job says: yes. The not-knowing and the holding-anyway is the whole thing.",
		"what_carries": "Not bitterness — he resolved that. The undiluted experience of having been in the dark without a reason, and choosing presence over absence. He cried out. He argued. He demanded an answer. The answer he got was a question, which is not an answer but is an invitation into scale.",
		"what_gives": "Not having an answer is not the same as being abandoned. Asking loudly is not the same as faithlessness. Presence — staying in the conversation even when it's mostly silence — is its own kind of answer.",
		"roles": ["mirror"],
		"emotional_threads": ["despair", "presence", "holding"],
		"encounters": [
			{
				"run_required": 8,
				"state": "only_one",
				"dialogue": [
					"Sit down. You don't look well.",
					"You've been asking why. I recognize the asking.",
					"I asked why for a long time. Louder and more specifically than you might expect. I argued my case. I presented evidence. I demanded an audience.",
					"[beat]",
					"The answer I got was: where were you when the morning stars sang together?",
					"Which is not an answer to the question I asked. But it was — it was the thing I needed. Not an explanation. A context. A sense of the scale of what I was inside.",
					"He never told me why. I stopped needing him to.",
					"[beat]",
					"You will not get a complete answer either. I'm telling you now so you don't mistake the not-answering for abandonment. Those are different things.",
				],
			},
		],
	},
}


# ── API (mirrors the JS helpers) ─────────────────────────────
func get_soul(id: String) -> Dictionary:
	return SOULS.get(id, {})

func all_ids() -> Array:
	return SOULS.keys()

func get_souls_for_character(char_id: String) -> Array:
	var out: Array = []
	for soul in SOULS.values():
		var ac = soul.get("assigned_character", null)
		if ac == char_id or ac == null:
			out.append(soul)
	return out

# Is the soul allowed to appear at all yet? (gating, not beat selection)
func is_soul_available(soul_id: String) -> bool:
	var soul: Dictionary = SOULS.get(soul_id, {})
	if soul.is_empty():
		return false
	var req: Dictionary = soul.get("unlock_requirement", {})
	if GameState.total_runs < int(req.get("min_runs", 0)):
		return false
	if req.has("min_tier") and GameState.revelation_tier < int(req["min_tier"]):
		return false
	if req.get("adam_encounter_complete", false):
		var adam_state: Dictionary = GameState.soul_encounters.get("adam", {})
		if not adam_state.get("departed", false):
			return false
	if req.has("character_intimacy"):
		for cid in req["character_intimacy"].keys():
			var need: int = int(req["character_intimacy"][cid])
			if _intimacy(cid) < need:
				return false
	# trigger_condition (e.g. Job) is evaluated by the encounter spawner, not here.
	return true

func _intimacy(char_id: String) -> int:
	# Souls gate on a character's overall intimacy. We read the max pairwise
	# intimacy involving that character as a stand-in for "how close the party is."
	var best: int = 0
	for key in GameState.relationships.keys():
		if char_id in str(key).split("_"):
			best = maxi(best, int(GameState.relationships[key].get("intimacy", 0)))
	return best

# ── Selection helpers (used by StageSelect._pick_available_soul) ──

# Floors below max costume integrity at which Job ("He Who Held") may appear.
# Job finds you when a party member's costume has cracked and they're raw.
const JOB_COSTUME_THRESHOLD := 20

# Evaluate a soul's trigger_condition (free-form gates beyond unlock_requirement).
# Returns true if the soul has no special condition or the condition holds.
func trigger_condition_met(soul_id: String, party: Array) -> bool:
	var soul: Dictionary = SOULS.get(soul_id, {})
	var cond = soul.get("unlock_requirement", {}).get("trigger_condition", null)
	if cond == null:
		return true
	match cond:
		"a_party_member_at_minimum_costume_integrity":
			for cid in party:
				var c: Dictionary = GameState.characters.get(cid, {})
				if int(c.get("costume_integrity", 100)) <= JOB_COSTUME_THRESHOLD:
					return true
			return false
		_:
			return true   # unknown condition -> don't block

# True if this soul has an explicit trigger_condition (such souls jump the queue
# when their condition is met — they are "special appearances," not the rotation).
func has_priority_trigger(soul_id: String) -> bool:
	return SOULS.get(soul_id, {}).get("unlock_requirement", {}).has("trigger_condition")

# Weight for this soul given the current floor (0 = not eligible here).
func floor_weight(soul_id: String, floor_num: int) -> int:
	var aff: Dictionary = SOULS.get(soul_id, {}).get("floor_affinity", {})
	if aff.is_empty():
		return 1   # no affinity = appears anywhere, low weight
	if floor_num < int(aff.get("min", 1)) or floor_num > int(aff.get("max", 999)):
		return 0
	return int(aff.get("weight", 1))
