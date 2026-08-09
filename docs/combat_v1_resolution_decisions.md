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
- `CombatPolicy` rejects illegal target semantics;
- Policy Context and the LimboAI Blackboard receive isolated copies of `legal_targets`;
- `target_rules` has been removed from resolution readiness.

### D2 — Position and distance model

Status: `PENDING / CONDITIONAL`

Current recommendation, **not frozen**:
- keep `reposition` abstract in Combat V1;
- do not create coordinates or range bands unless later mechanics require them;
- presentation coordinates never become simulator authority.

### D3 — Resolution order

Status: `FROZEN`

Authoritative exchange model:
- every active fighter submits exactly one valid intent per exchange;
- therefore a complete exchange contains 2 intents in `1v1`, 3 in `1v2`, and 4 in `2v2`;
- phase 1 is `preparation`: `block`, `parry`, `dodge`, `reposition`;
- phase 2 is `offense`: `light`, `heavy`;
- every intent inside one phase is simultaneous and reads the same phase-start snapshot;
- preparation reads `exchange_start` and commits together at the end of the phase;
- offense reads `after_preparation_commit` and commits together at the end of the phase;
- there is no initiative stat, initiative roll, actor-first rule, node-order priority, BehaviorTree priority, frame-order priority, or array-insertion priority in D3;
- same-phase conflicts use `simultaneous` semantics rather than a tiebreak;
- canonical actor-id sorting may be used only for deterministic serialization/debug output and never represents gameplay priority;
- exact effects of defense, damage, accuracy, Stamina and KO remain owned by later freezes.

Runtime contract:
- `combat_resolution_order_boundary.gd` validates CombatState and every submitted intent through the canonical policy contract;
- duplicate actor intents and incomplete exchanges fail closed;
- valid exchanges produce a two-phase resolution plan;
- `get_contract_status()` exposes D3 as frozen;
- `CombatSimulator` exposes the frozen D3 contract in blocker context and advances the next required blocker to D4 `damage_and_mitigation`;
- `resolution_order` has been removed from pending resolution readiness.

Validation coverage:
- `1v1` phase split and snapshots;
- complete `1v2` coverage requirement;
- `2v2` simultaneous phase grouping independent of submission order;
- duplicate actors rejected;
- invalid D1 target semantics rejected before ordering;
- state, submitted intents and returned plans remain isolated copies.

### D4 — Damage and mitigation

Status: `PENDING / NEXT REQUIRED BLOCKER`

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

### D6 — Stamina costs and recovery

Status: `PENDING`

Question:
- cost of all six actions;
- recovery timing;
- insufficient-Stamina behavior.

### D7 — Accuracy and criticals

Status: `PENDING`

Question:
- deterministic, contested, threshold or probabilistic hit model;
- whether V1 includes critical hits.

### D8 — Stat scaling

Status: `PENDING`

Question:
- which `FUE / AGI / TEC / RES / PV` affect which actions and how much.

### D9 — KO and surrender

Status: `PENDING`

Question:
- fight-ending conditions;
- surrender ownership/availability.

### D10 — Carryover

Status: `PENDING`

Question:
- which state persists across consecutive GT fights.

## Action-level freeze checklist

| Action | Target rule | Resolution timing | Stamina | Stat inputs | State/effect | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `light` | exactly 1 enemy | offense / simultaneous | TBD | TBD | TBD | D1 + D3 FROZEN |
| `heavy` | exactly 1 enemy | offense / simultaneous | TBD | TBD | TBD | D1 + D3 FROZEN |
| `block` | no explicit target | preparation / simultaneous | TBD | TBD | TBD | D1 + D3 FROZEN |
| `parry` | no explicit target | preparation / simultaneous | TBD | TBD | TBD | D1 + D3 FROZEN |
| `dodge` | no explicit target | preparation / simultaneous | TBD | TBD | TBD | D1 + D3 FROZEN |
| `reposition` | no explicit target | preparation / simultaneous | TBD | TBD | TBD | D1 + D3 FROZEN |

## Freeze rule

A design item must not become authoritative merely because it appears in legacy code, an ability description, a test fixture, a temporary AI proposal, a tuning experiment, or this worksheet. It becomes frozen only when explicitly approved, reflected in code/data contracts, and protected by tests.
