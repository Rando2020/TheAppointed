# The Appointed: As Above — Soul Encounter System

> *"These are not bosses. These are not collectibles. They are the most
> important conversations in the game."*
> — design note, `historicalSouls.js`

This document is the canonical spec for **Historical Souls**: who they are,
how the player meets them, how they unfold across runs, and the three jobs
they do. It defines the data shape and guarantees backward-compatibility with
the souls already written in `archive_react/historicalSouls.js` (Adam, Eve,
Cain, Moses, Elijah, David, Job).

---

## 1. What a Soul is

A Soul is a figure from scripture, myth, or deep history who is **mid-ascent**
on the Mountain — further along their own trial than the party is on theirs.
They are not enemies and not rewards. They are people who already paid the full
cost of a choice and have had a very long time to sit with it.

Every Soul carries a verse, a story, or a silence where the **orthodox telling
required someone to swallow an injustice and call it holy** — and each has had
eternity to stop swallowing it. They speak those buried readings sincerely:
never as cynicism, never fully dismissed, the same rule the bosses follow in
`bossData.js`. Adam owns the first deflection. Eve calls "wanting to understand
was the sin" the most wrong thing anyone ever said about her. That is the lane.

---

## 2. The `?`-node encounter model

Souls are found exactly like Hades' optional characters:

- On a run, a map node may render as **`?`** instead of a known icon.
- Entering it resolves into a Soul (or another `?` event from the general pool).
- A Soul `?` is **optional and missable.** You are never told one is available.
- Each visit delivers **exactly one beat** — one authored chunk of dialogue.
  You do not manage anything. You walk in, you receive it, you leave changed.
  One beat per visit is what makes you come back.

A Soul appears as a `?` only once its `unlockRequirement` is met (e.g. Adam:
`minRuns: 20, minTier: 3`). Until then the node simply never resolves to them.

---

## 3. Emotional threads — one sin, many doors

A sin is **not one feeling.** Each Soul holds a small **pool of emotional
threads** — the cluster of feelings their wound actually contains. Adam's root
is Pride, but across visits he can touch **deflection, shame, grief, and
ownership.** A Soul's arc is the path walked through that pool.

There are two ways a thread gets served:

- **Core arc (fixed by visit count).** The backbone everyone walks. Beat order
  is authored and reliable: visit 1 serves the first core beat, visit 2 the
  second, and so on. This is the existing `encounters[]` array, keyed by
  `runRequired`. Every player who keeps showing up reaches the ending beat.
- **Secret convos (gated by party composition).** Optional side beats that
  unlock only when the right angel has traveled with you enough. These never
  block the core arc; they enrich it. A secret beat is *additional*, slotted in
  the next time you visit after its condition is met.

This is the resolution of the "fixed vs. tilt" question: **fixed core, secret
extras.** Authored and dependable, with replay-driven discovery on top.

### Thread ↔ angel resonance (for secret-convo gating)

Secret convos open when a party member whose sin *resonates* with the thread has
enough `minRunsTogether`. Suggested map (load-bearing pairs in bold):

| Thread        | Resonant angel(s)            | Sin              |
|---------------|------------------------------|------------------|
| shame         | **Cael** (envy), Aeryn (pride) | the I-am-less wound / its armor |
| grief         | Brennan (wrath), Solan (sloth) | what rage and collapse both protect |
| deflection    | Aeryn (pride)                | the refusal to say *I did this* |
| ownership     | (any — this is the core ending) | — |
| wanting       | Seren (lust), Mira (greed)   | desire that forgot the person wanted |
| favoritism    | Cael (envy)                  | being passed over without reason |

---

## 4. The three Soul roles

Every Soul does one or more of three jobs. All three reuse the same beat model;
they are just tags on the data.

### Mirror
The Soul works on **you and your angels.** Their beats deepen a sin and can
emit an **arc beat** that advances a traveling angel's integration
(Assignment → Recognition → Integration → Final Job). Adam grieving shame in
front of Cael is a *Recognition* beat for Cael's Envy line. The Soul is a key
that turns the angel you brought — which fuses party choice (the player's
self-portrait) and Soul encounters into one system.

### Witness
The Soul's real story is with **another Soul**, and you get to watch it resolve
across runs simply by being the one who keeps showing up. You are not the
center — that *is* the lesson. **Adam ↔ Eve** is the load-bearing pair: the
first marriage in history trying to forgive itself, one `?` at a time. Other
natural pairs: **Cain ↔ Adam/Eve** (the favored-against son and the parents who
couldn't shield him), **David ↔ Uriah** (the beloved king and the man his grace
was purchased from), **Moses ↔ the silence** (forgiving a punishment that
outweighed the offense).

### Courier
You can **carry words between Souls** who are too wounded to say them directly.
A beat may `emit` a `carriedMessage` token; another Soul may gate a beat behind
`hasCarried`. Delivery is a **player choice** — you may withhold it, and
withholding has consequences. The protagonist is **silent**: you choose to
deliver, and the receiving Soul simply *receives* it (no protagonist VO now;
this leaves room for future voice work). Carrying truth between the wounded is
the player's quiet thesis — it is exactly what the angels are learning to be.

---

## 5. Worked example — Adam + Eve

Adam is **Mirror + Witness + Courier.** His existing three core beats
(`runRequired` 20/30/40) are preserved verbatim; below shows the *additions*
in plain terms, then §6 gives the drop-in data.

**Core arc (fixed, unchanged):**
1. Visit @ run 20 — *deflection.* "I blamed her because I was afraid."
2. Visit @ run 30 — *grief/meaning.* "Was it worth feeling it?"
3. Visit @ run 40 — *ownership.* "Tell Eve — if you find her — that I understand
   now." Emits courier token `adam_to_eve`. **Adam departs.** Apple on the ground.

**Secret convo (party-gated) — Adam on shame:**
Slots in *before* the run-40 ownership beat, the next visit after the condition
is met: you've sat with Adam ≥ 2 times **and** Cael (or Aeryn) has
`minRunsTogether ≥ 3`. Adam stops talking about the apple and grieves **what he
did to Eve** — not the blame as event, but the shame of having been the kind of
man who let her carry it for all of history. Emits arc beat
`cael: "envy_recognition"`. This is the Mirror job: hearing it turns Cael.

**Courier beat — delivering Adam to Eve:**
Once you hold `adam_to_eve` and reach an Eve `?`, you are offered the **choice**
to deliver it. Eve's gated **forgiveness** beat only opens if you do. If you
withhold, Eve's arc stalls on a quieter beat and a codex note marks the
un-delivered message — recoverable only while Eve remains (she departs at her
own late beat).

---

## 6. Data shape (drop-in, backward-compatible)

All new keys are **additive**. Any Soul lacking them behaves exactly as today.

```js
soulId: {
  // ── existing keys (unchanged) ──
  id, name, knownAs, assignedCharacter,
  unlockRequirement,            // { minRuns, minTier, soulComplete? }
  location, coreTheme,
  whatHeCarries, whatHeGives,
  encounters: [ /* CORE ARC — existing array, keyed by runRequired */
    { runRequired, state, dialogue:[...], departureNote?,
      emits?: { carriedMessage?: "token", arcBeat?: { angelId: "beatId" } } }
  ],

  // ── new: additive metadata ──
  roles: ["mirror", "witness", "courier"],   // any subset
  emotionalThreads: ["deflection","shame","grief","ownership"],
  witnessPartner: "eve",                       // for witness/courier pairs

  // ── new: party-gated side beats (never block core arc) ──
  secretConvos: [
    {
      id: "adam_shame",
      thread: "shame",
      insertBefore: 40,                        // appears before this runRequired beat
      unlock: {
        minEncounters: 2,
        partyResonance: { anyOf: ["cael","aeryn"], minRunsTogether: 3 }
      },
      dialogue: [ /* the shame conversation */ ],
      emits: { arcBeat: { cael: "envy_recognition" } }
    }
  ],

  // ── new: courier inbound (gated beats that need a delivered token) ──
  courierBeats: [
    {
      id: "eve_forgiveness",
      requires: { hasCarried: "adam_to_eve" },
      delivery: "playerChoice",                // offered, not automatic
      onDeliver:  { dialogue:[...], codexEntry:"eve_forgives" },
      onWithhold: { dialogue:[...], codexEntry:"eve_message_withheld",
                    recoverableWhile: "eve_present" }
    }
  ]
}
```

### Runtime resolution order (per `?` visit)
1. Is a `courierBeat` deliverable here and unseen? → offer the **choice**.
2. Is a `secretConvo` unlocked, unseen, and due (`insertBefore`)? → serve it.
3. Otherwise serve the **next core `encounters[]` beat** by visit count.
4. On any beat, apply `emits` (set `carriedMessage`, fire `arcBeat`).
5. If the served beat has `departsAfter`/`departureNote`, retire the Soul.

### Save/codex state to track
- `encountersSeen[soulId]` (int) — drives core arc + `minEncounters`.
- `runsTogether[angelId]` (int) — drives `partyResonance`.
- `carried[token]` = `"held" | "delivered" | "withheld"`.
- `arcBeats[angelId]` = set of fired beat ids — drives integration progress.
- `secretsSeen[]`, `codexEntries[]` — unlock tracking + Hades-style nudges.

---

## 7. Authoring rules

- One beat per visit. Never dump two on one `?`.
- Core arc must stand alone and must always reach its ending beat for any player
  who keeps showing up. Secret convos are *bonus*, never required.
- Heterodox readings are sincere and never the butt of a joke.
- A delivered truth should cost the deliverer something to carry, and a withheld
  one should ache. Both are valid. Both are remembered.
- Some Souls leave before the game ends. Do not soften this. It is the grace.
