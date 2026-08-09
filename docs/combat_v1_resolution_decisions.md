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
- `CombatTargetResolver` owns candidate classification for `1v1`, `1v2`, and `2v2`.
- `CombatTargetResolver.inspect_action_targets()` returns `pending_design_freeze` with reason `target_rules_not_frozen` for all six base actions and never exposes `legal_targets` while D1 is pending.
- `CombatSimulator` surfaces D1 as `blocking_requirement = target_rules` and attaches isolated `blocking_context` without resolving combat.
- `CombatDecisionGateway` propagates the same blocker with an independent deep copy; policy rejection exposes no simulator blocker.
- Canonical abilities mostly describe effects on a rival, but `abilities.json` has no formal `target_type` field.
- No recovered repository evidence defines target semantics for the six V1 base actions.

Structural implementation status:
- candidate discovery: `IMPLEMENTED / NON-AUTHORITATIVE`;
- D1 pending boundary: `IMPLEMENTED`;
- legal-target semantics: `NOT FROZEN`;
- target relationship enforcement: `NOT IMPLEMENTED` by design until freeze.

Current simplest design candidate, **PROPOSAL ONLY**:
- `light` / `heavy`: exactly one enemy target;
- `block` / `parry` / `dodge`: no explicit target; actor is implicit;
- `reposition`: no explicit target;
- no ally-targeting for the six base actions in V1;
- same relationship rules in `1v1`, `1v2`, and `2v2`.

Approval boundary:
- this proposal remains non-authoritative while D1 is `PENDING`;
- documentation cannot alter runtime behavior;
- it must not change `CombatPolicy`, `CombatTargetResolver`, action contracts, LimboAI, or simulator resolution until D1 is explicitly `FROZEN`;
- activation requires relationship/format contract tests.

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
- `relentless_pursuit` historically says it “closes distance”, but its stored mechanics are damage/evasion/initiative modifiers rather than coordinates or range bands.
- `cast_net` historically reduces mobility through an entangled status, again without an authoritative position field.
- The legacy combatant state has combat stats/statuses but no authoritative `position`, `distance`, `range`, lane or arena coordinate.
- The legacy combat loop has no movement or range validation.
- Current CombatState intentionally has no authoritative spatial state.
- Presentation coordinates are not simulation authority.

Evidence-based recommendation, **not frozen**:
- prefer an abstract `reposition` action for Combat V1;
- do not add authoritative coordinates/range bands unless a later combat rule demonstrably requires them;
- express pursuit, entangle and mobility effects as simulator states/modifiers where possible.

If excluded from V1:
- explicitly mark `reposition` as abstract;
- define its non-spatial effect under the action-effect freeze;
- remove `position_and_distance_model` from conditional readiness.

If included:
- define minimal authoritative spatial state, carryover, affected actions and legal ranges independent of presentation coordinates.

### D3 — Resolution order

Status: `PENDING`

Question:
- How are simultaneous or competing intents ordered?
- What breaks ties?
- How do defensive reactions interact with attacks?

Current evidence:
- Legacy combat alternates player attack and enemy attack, which is side-biased and insufficient for `1v2`/`2v2`.
- Historical `relentless_pursuit` contains `retain_initiative_on_hit`, but there is no reusable V1 initiative state.
- Historical action-loss/stun behavior does not define a general ordering model.
- `parry`, `block`, and `dodge` require explicit interaction timing with offensive intents.
- LimboAI execution order cannot decide simulator order.

Evidence-based constraint, **not frozen**:
- resolution should be exchange-based and deterministic from CombatState/intents;
- node order, frame timing, BehaviorTree tick timing and collection insertion order must never decide priority;
- initiative/tie-break ownership belongs to `CombatSimulator` and must be reproducible.

Freeze acceptance criteria:
- deterministic order and tie handling in all supported formats;
- explicit attack/defense interaction timing;
- explicit multi-intent handling in `1v2` and `2v2`.

### D4 — Damage and mitigation

Status: `PENDING`

Question:
- authoritative `light`/`heavy` damage;
- RES mitigation;
- weapon and armor contribution.

Current evidence:
- legacy formula depends on old derived attack/defense and was not promoted.

Freeze acceptance criteria:
- deterministic formula per offensive action;
- explicit bounds, RES and equipment contribution;
- low/equal/high spread tests.

### D5 — Armor and vulnerability

Status: `PENDING`

Question:
- armor model;
- precise vulnerability state/duration;
- defensive-action interactions.

Current evidence:
- legacy abilities have defense reduction, penetration, guard break and recovery penalties, but they are historical only.

Freeze acceptance criteria:
- precise armor model independent of legacy unless approved;
- precise vulnerability semantics;
- testable interaction with abilities/equipment.

### D6 — Stamina costs and recovery

Status: `PENDING`

Question:
- cost of all six actions;
- recovery timing;
- insufficient-Stamina behavior.

Current evidence:
- legacy uses `energy`; values cannot be copied by renaming it Stamina.

Freeze acceptance criteria:
- six explicit costs;
- deterministic recovery and bounds;
- legal insufficient-resource behavior;
- carryover interaction defined.

### D7 — Accuracy and criticals

Status: `PENDING`

Question:
- deterministic, contested, threshold or probabilistic hit model;
- whether V1 includes critical hits.

Current evidence:
- legacy uses RNG; V1 does not yet require RNG.

Freeze acceptance criteria:
- explicit model;
- if RNG exists, simulator-owned seed/reproducibility;
- criticals precisely defined or explicitly excluded.

### D8 — Stat scaling

Status: `PENDING`

Question:
- which `FUE / AGI / TEC / RES / PV` affect which actions and how much.

Current evidence:
- canonical stats are structural; legacy `intelligence/endurance` are not automatic substitutes.

Freeze acceptance criteria:
- explicit role for every canonical stat;
- no silent legacy substitution;
- bounded scaling.

### D9 — KO and surrender

Status: `PENDING`

Question:
- fight-ending conditions;
- surrender ownership/availability.

Current evidence:
- legacy surrender is probabilistic and not authoritative.

Freeze acceptance criteria:
- KO defined from V1 state;
- surrender ownership defined;
- LimboAI cannot declare winner directly.

### D10 — Carryover

Status: `PENDING`

Question:
- which state persists across consecutive GT fights.

Current evidence:
- Months XIII and XX require consecutive series; exact carryover is not frozen.

Freeze acceptance criteria:
- explicit carryover fields/reset boundaries;
- Month XX substitution effects;
- deterministic serialization between encounters.

## Action-level freeze checklist

| Action | Target rule | Stamina | Resolution timing | Stat inputs | State/effect | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `light` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `heavy` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `block` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `parry` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `dodge` | TBD | TBD | TBD | TBD | TBD | PENDING |
| `reposition` | TBD | TBD | TBD | TBD | TBD | PENDING |

## Freeze rule

A design item must not become authoritative merely because it appears in legacy code, an ability description, a test fixture, a temporary AI proposal, a tuning experiment, or this worksheet. It becomes frozen only when explicitly marked `FROZEN`, reflected in code/data contracts, and protected by tests.
