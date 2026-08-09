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

### D4 — Damage and mitigation

Status: `PENDING / NEXT REQUIRED BLOCKER`

Still deliberately unresolved:
- authoritative `light` / `heavy` damage values and formula;
- exact FUE scaling;
- exact RES mitigation;
- weapon power contribution;
- armor numeric mitigation and penetration.

Legacy attack/defense formulas are evidence only and have not been promoted.

### D5 — Armor and vulnerability

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

Authoritative structural rules:
- armor comes from canonical equipment `defense` rather than being silently folded into RES;
- armor and RES remain separate simulator inputs;
- Combat V1 has no body-part armor model;
- vulnerability is an explicit runtime combat state owned by `CombatSimulator`;
- fighters begin combat with `vulnerable = false`;
- exact armor mitigation and penetration values remain pending D4.

### D6 — Stamina

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

Authoritative structural rules:
- `stamina` is the canonical combat resource;
- Stamina has a minimum of 0 and negative values are invalid CombatState;
- an action that lacks the required Stamina must fail closed rather than create debt or negative Stamina;
- legacy `energy` values are not copied into V1;
- exact costs for the six actions, recovery amount and recovery timing remain pending.

### D7 — Accuracy and criticals

Status: `FROZEN STRUCTURE / FORMULA PENDING`

Authoritative structural rules:
- V1 hit resolution does not use RNG;
- V1 critical hits are disabled;
- `CombatSimulator` owns accuracy resolution;
- the exact deterministic accuracy/avoidance formula remains pending;
- legacy random hit/critical probabilities are not authoritative.

### D8 — Stat scaling

Status: `FROZEN ROLES / WEIGHTS PENDING`

Authoritative stat roles:
- `FUE` -> offensive power;
- `AGI` -> evasion and reposition;
- `TEC` -> accuracy and parry;
- `RES` -> mitigation and block;
- `PV` -> maximum health;
- legacy `endurance` cannot silently substitute for RES;
- exact coefficients/weights remain pending alongside D4/D7 math.

### D9 — KO and surrender

Status: `FROZEN KO STRUCTURE / SURRENDER RULES PENDING`

Authoritative structural rules:
- runtime health is `current_pv`, distinct from maximum `stats.PV`;
- new runtime combat state initializes `current_pv = stats.PV`;
- `CombatSimulator` owns KO authority;
- KO occurs when `current_pv <= 0`;
- surrender is not a seventh base combat action;
- probabilistic surrender is forbidden in V1;
- exact surrender eligibility/trigger rules remain pending and cannot declare a winner outside simulator authority.

Runtime support:
- `combat_runtime_state_builder.gd` creates isolated runtime state with `current_pv` and `vulnerable`;
- `combat_rules_d5_d9_contract.gd` is the central structural ledger for D5-D9;
- resolution readiness now distinguishes frozen structure from unresolved numeric/eligibility subrules.

### D10 — Carryover

Status: `PENDING`

Question:
- which runtime state persists across consecutive GT fights;
- how `current_pv`, Stamina, vulnerability and future statuses reset or carry;
- how the Month XX substitution interacts with carryover.

## Resolution readiness after D5-D9 structural freeze

Frozen structural requirements:
- `target_rules`;
- `resolution_order`;
- `armor_and_vulnerability_structure`;
- `stamina_structure`;
- `accuracy_and_critical_structure`;
- `stat_scaling_roles`;
- `ko_structure`.

Still pending:
- `damage_and_mitigation`;
- `armor_numeric_mitigation`;
- `armor_penetration`;
- `stamina_cost_table`;
- `stamina_recovery_amount`;
- `stamina_recovery_timing`;
- `accuracy_formula`;
- `stat_scaling_weights`;
- `surrender_rules`;
- `carryover`.

Conditional:
- `position_and_distance_model`.

## Action-level freeze checklist

| Action | Target rule | Resolution timing | Stamina | Stat roles | Effect/math | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `light` | exactly 1 enemy | offense / simultaneous | resource semantics frozen; cost TBD | FUE offense, TEC accuracy | damage TBD | D1 + D3 + D6-D8 STRUCTURE |
| `heavy` | exactly 1 enemy | offense / simultaneous | resource semantics frozen; cost TBD | FUE offense, TEC accuracy | damage TBD | D1 + D3 + D6-D8 STRUCTURE |
| `block` | no explicit target | preparation / simultaneous | resource semantics frozen; cost TBD | RES block | exact mitigation TBD | D1 + D3 + D5-D8 STRUCTURE |
| `parry` | no explicit target | preparation / simultaneous | resource semantics frozen; cost TBD | TEC parry | exact effect TBD | D1 + D3 + D6-D8 STRUCTURE |
| `dodge` | no explicit target | preparation / simultaneous | resource semantics frozen; cost TBD | AGI evasion | exact effect TBD | D1 + D3 + D6-D8 STRUCTURE |
| `reposition` | no explicit target | preparation / simultaneous | resource semantics frozen; cost TBD | AGI reposition | D2/effect TBD | D1 + D3 + D6-D8 STRUCTURE |

## Validation checkpoint

Runtime head `7c5cd9551877ac686d3defc0e05f2abfca8dbc53` was validated with:

- Core systems suite: **80/80 passed**;
- UI/integration suite: passed;
- GUT behavior suite: passed;
- Godot 4.5.2 import/compile/smoke: passed;
- gdformat/gdlint: passed;
- Gitleaks: passed;
- CI Gate: passed.

The subsequent commits only update this decision ledger and do not change runtime contracts.

## Freeze rule

A design item must not become authoritative merely because it appears in legacy code, an ability description, a test fixture, a temporary AI proposal, a tuning experiment, or this worksheet. It becomes frozen only when explicitly approved, reflected in code/data contracts, and protected by tests.
