# Combat V1 — Resolution Decision Matrix

Status: **PENDING DESIGN FREEZE**

This file is a decision worksheet, not an implementation contract. A row becomes authoritative only after its status is explicitly changed from `PENDING` to `FROZEN` and the corresponding contract tests are added.

## Protected context

Combat V1 already protects these structural decisions:

- canonical stats: `FUE / AGI / TEC / RES / PV` plus Stamina;
- canonical base actions: `light`, `heavy`, `block`, `parry`, `dodge`, `reposition`;
- supported formats: `1v1`, `1v2`, `2v2`;
- LimboAI is policy only;
- `CombatSimulator` is the sole result authority;
- Save v14 remains intact;
- campaign time is monthly;
- the legacy combat implementation is evidence only.

## Decision matrix

### D1 — Target rules

Status: `PENDING`

Question:
- Which actions require a target?
- Which target relationships are legal: enemy, ally, self, none?
- Does legality change between `1v1`, `1v2`, and `2v2`?

Current evidence:
- `CombatPolicy` only validates that a non-empty `target_id` exists.
- Policy Context exposes allies and enemies separately but deliberately calls them target candidates, not legal targets.
- Canonical abilities mostly describe effects on a rival, but `abilities.json` has no formal `target_type` field.
- No recovered repository evidence defines target semantics for the six V1 base actions.

Must not be inferred automatically:
- `block/parry/dodge/reposition` being self-only;
- `light/heavy` requiring an enemy target;
- ally-targeting or interception behavior in `2v2`.

Freeze acceptance criteria:
- every base action has an explicit target requirement;
- every supported format has deterministic legal-target rules;
- `CombatPolicy` rejects illegal relationships;
- Policy Context may then expose `legal_targets` rather than generic candidates.

### D2 — Position and distance model

Status: `PENDING / CONDITIONAL`

Question:
- Does Combat V1 require authoritative distance/position, or is `reposition` an abstract combat-state action?

Current evidence:
- `relentless_pursuit` historically says it closes distance, but there is no authoritative spatial state in the new CombatState.
- The legacy simulator does not provide a reusable V1 spatial model.

Freeze acceptance criteria if included:
- define the minimal authoritative spatial state;
- define how it serializes/carries across a fight;
- define which actions read or modify it;
- define legal ranges without relying on presentation coordinates.

If excluded from V1:
- explicitly mark `reposition` as abstract and remove this item from conditional readiness.

### D3 — Resolution order

Status: `PENDING`

Question:
- How are simultaneous or competing intents ordered?
- What breaks ties?
- How do defensive reactions interact with attacks?

Current evidence:
- Legacy combat simply alternates player attack then enemy attack; that is not suitable evidence for `2v2`, `1v2`, parry, or simultaneous intent resolution.

Freeze acceptance criteria:
- deterministic order for all supported formats;
- deterministic tie handling;
- no hidden dependence on node order, array insertion order, frame timing, or LimboAI execution order.

### D4 — Damage and mitigation

Status: `PENDING`

Question:
- What is the authoritative damage formula for `light` and `heavy`?
- How does `RES` mitigate incoming damage?
- Where do weapon power and armor defense enter the formula?

Current evidence:
- Legacy damage used derived `attack`, ability multipliers, and half of effective defense.
- That formula depends on legacy stats and was not promoted to V1.

Freeze acceptance criteria:
- one deterministic formula per offensive action;
- explicit minimum/maximum behavior;
- explicit RES contribution;
- explicit equipment contribution;
- tests at low/equal/high stat spreads.

### D5 — Armor and vulnerability

Status: `PENDING`

Question:
- Is armor flat, percentage, threshold, durability-based, or another model?
- What does `vulnerable` mean in V1?
- Can block/parry/dodge create vulnerability windows?

Current evidence:
- Legacy abilities contain defense reduction, armor penetration, guard breaking and recovery-defense penalties.
- These are historical effects, not yet mapped to the new action model.

Freeze acceptance criteria:
- armor model is independent of legacy `defense` unless explicitly approved;
- vulnerability has a precise state and duration;
- interaction with abilities/equipment is testable.

### D6 — Stamina costs and recovery

Status: `PENDING`

Question:
- What does each V1 action cost?
- How and when does Stamina recover?
- What happens when an actor cannot pay a cost?

Current evidence:
- Legacy combat uses `energy`, action-specific energy costs and automatic recovery.
- Combat V1 explicitly uses Stamina, so legacy values cannot be copied by renaming the resource.

Freeze acceptance criteria:
- cost for all six base actions;
- legal behavior at insufficient Stamina;
- deterministic recovery timing;
- bounds and carryover rules defined.

### D7 — Accuracy and criticals

Status: `PENDING`

Question:
- Are attacks guaranteed unless defended, probabilistic, contested, or threshold-based?
- Does Combat V1 include critical hits?

Current evidence:
- Legacy combat used RNG hit chance and ability accuracy bonuses.
- No frozen V1 contract currently requires RNG or critical hits.

Freeze acceptance criteria:
- explicit deterministic/probabilistic choice;
- if RNG exists, seed ownership and reproducibility are defined by `CombatSimulator`;
- criticals either receive a precise contract or are explicitly excluded from V1.

### D8 — Stat scaling

Status: `PENDING`

Question:
- Which canonical stats affect which actions and by how much?

Current evidence:
- `FUE`, `AGI`, `TEC`, `RES`, `PV` are structurally canonical.
- Old abilities list legacy `primary_stats`, but include `intelligence` and `endurance`, which are not mapped automatically to Combat V1.

Freeze acceptance criteria:
- every canonical stat has an explicit combat role or is explicitly passive;
- no legacy stat is silently substituted for a canonical stat;
- scaling is bounded enough to avoid invalid or negative outcomes.

### D9 — KO and surrender

Status: `PENDING`

Question:
- What ends a fight?
- Is surrender automatic, policy-driven, morale-driven, or absent from V1?

Current evidence:
- Legacy surrender used a health threshold plus probabilistic morale/tactic modifiers.
- That rule is not authoritative for V1.

Freeze acceptance criteria:
- KO condition defined from PV/state;
- surrender ownership defined: policy intent versus simulator rule;
- no LimboAI branch can directly declare the winner.

### D10 — Carryover

Status: `PENDING`

Question:
- Which combat state persists across consecutive GT fights: PV, Stamina, statuses, substitutions, equipment state, or other fields?

Current evidence:
- GT I requires consecutive series in Months XIII and XX.
- Full carryover behavior has not been frozen.

Freeze acceptance criteria:
- explicit carryover fields per GT format;
- reset boundaries defined;
- substitution effects defined for Month XX;
- deterministic serialization between encounters.

## Action-level freeze checklist

Each of the six V1 actions must eventually define, at minimum:

| Action | Target rule | Stamina | Resolution timing | Stat inputs | State/effect | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `light` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `heavy` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `block` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `parry` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `dodge` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `reposition` | TBD | TBD | TBD | TBD | TBD | PENDING |

## Freeze rule

A design item must not be implemented as authoritative combat math merely because it appears in:

- legacy code;
- an ability description;
- a test fixture;
- a temporary AI proposal;
- a tuning experiment.

It becomes frozen only when the decision is explicitly recorded as `FROZEN`, reflected in code/data contracts, and protected by tests.
