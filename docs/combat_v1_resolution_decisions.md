# Combat V1 — Resolution Decision Matrix

Status: **PARTIALLY FROZEN**

This file is a decision worksheet and contract ledger. A row becomes authoritative only after its status is explicitly changed from `PENDING` to `FROZEN`, reflected in runtime contracts, and protected by tests.

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

Status: `FROZEN`

Authoritative rules:
- `light`: exactly one enemy target;
- `heavy`: exactly one enemy target;
- `block`: no explicit target; the actor is implicit;
- `parry`: no explicit target; the actor is implicit;
- `dodge`: no explicit target; the actor is implicit;
- `reposition`: no explicit target;
- the six base actions have no ally-targeting in Combat V1;
- the same target-relationship rules apply in `1v1`, `1v2`, and `2v2`.

Runtime contract:
- `combat_action_catalog.gd` stores the frozen target metadata for all six actions;
- `CombatTargetResolver` exposes `legal_targets` from the authoritative CombatState;
- `light` and `heavy` resolve legal targets only from the actor's enemy set;
- `block`, `parry`, `dodge`, and `reposition` expose no explicit legal target;
- `CombatPolicy` rejects missing offensive targets, ally/self offensive targets, unknown targets, and explicit targets on no-target actions;
- Policy Context exposes both descriptive `target_candidates` and authoritative `legal_targets`;
- the LimboAI Blackboard receives isolated copies of `legal_targets` and cannot bypass `CombatPolicy` validation;
- `CombatSimulator` requires D1 target inspection to be `ready` before proceeding to later resolution blockers.

Validation coverage:
- legal targeting is covered in `1v1`, `1v2`, and `2v2`;
- ally-target rejection is covered in `2v2`;
- no-target action rejection is covered;
- catalog, resolver, policy context, Blackboard, simulator, and gateway copy-isolation are protected;
- `target_rules` has been removed from resolution readiness.

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

Status: `PENDING / NEXT REQUIRED BLOCKER`

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
| `light` | exactly 1 enemy | TBD | TBD | TBD | TBD | D1 FROZEN |
| `heavy` | exactly 1 enemy | TBD | TBD | TBD | TBD | D1 FROZEN |
| `block` | no explicit target | TBD | TBD | TBD | TBD | D1 FROZEN |
| `parry` | no explicit target | TBD | TBD | TBD | TBD | D1 FROZEN |
| `dodge` | no explicit target | TBD | TBD | TBD | TBD | D1 FROZEN |
| `reposition` | no explicit target | TBD | TBD | TBD | TBD | D1 FROZEN |

## Freeze rule

A design item must not become authoritative merely because it appears in legacy code, an ability description, a test fixture, a temporary AI proposal, a tuning experiment, or this worksheet. It becomes frozen only when explicitly approved, reflected in code/data contracts, and protected by tests.
