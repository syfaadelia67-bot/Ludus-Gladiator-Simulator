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
- complete exchanges contain 2 intents in `1v1`, 3 in `1v2`, and 4 in `2v2`;
- phase 1 `preparation`: `block`, `parry`, `dodge`, `reposition`;
- phase 2 `offense`: `light`, `heavy`;
- intents inside the same phase are simultaneous and read the same phase-start snapshot;
- there is no initiative stat, initiative roll, actor-first rule, BehaviorTree priority, frame-order priority, or insertion-order priority;
- actor-id sorting is deterministic serialization/debug only, never gameplay priority.

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
- armor comes from canonical equipment `defense` and remains separate from RES;
- Combat V1 has no body-part armor model;
- vulnerability is an explicit runtime state owned by `CombatSimulator`;
- fighters begin combat with `vulnerable = false`;
- exact armor mitigation and penetration remain pending D4.

### D6 — Stamina

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

Authoritative structural rules:
- `stamina` is the canonical combat resource;
- minimum Stamina is 0; negative Stamina makes CombatState invalid;
- insufficient Stamina rejects the action instead of allowing debt/negative resource;
- legacy `energy` values are not copied into V1;
- six action costs, recovery amount and recovery timing remain pending.

### D7 — Accuracy and criticals

Status: `FROZEN STRUCTURE / FORMULA PENDING`

Authoritative structural rules:
- V1 hit resolution uses no RNG;
- critical hits are disabled in Combat V1;
- `CombatSimulator` owns accuracy resolution;
- the deterministic accuracy/avoidance formula remains pending;
- legacy random hit/critical probabilities remain quarantined.

### D8 — Stat scaling

Status: `FROZEN ROLES / WEIGHTS PENDING`

Authoritative roles:
- `FUE` -> offensive power;
- `AGI` -> evasion and reposition;
- `TEC` -> accuracy and parry;
- `RES` -> mitigation and block;
- `PV` -> maximum health;
- legacy `endurance` cannot silently substitute for RES;
- exact coefficients/weights remain pending D4/D7 math.

### D9 — KO and surrender

Status: `FROZEN KO STRUCTURE / SURRENDER RULES PENDING`

Authoritative structural rules:
- runtime health is `current_pv`, distinct from maximum `stats.PV`;
- runtime combat initializes `current_pv = stats.PV`;
- `CombatSimulator` owns KO authority;
- KO occurs when `current_pv <= 0`;
- surrender is not a seventh base action;
- probabilistic surrender is forbidden in V1;
- exact surrender eligibility/trigger rules remain pending.

Runtime support:
- `combat_runtime_state_builder.gd` creates isolated runtime state with `current_pv` and `vulnerable`;
- `combat_rules_d5_d9_contract.gd` centralizes D5-D9 structural contracts;
- resolution readiness distinguishes frozen structure from numeric/eligibility subrules.

### D10 — Carryover

Status: `PENDING`

Question:
- which runtime state persists across consecutive GT fights;
- how `current_pv`, Stamina, vulnerability and later statuses reset/carry;
- how the Month XX substitution interacts with carryover.

## Resolution readiness

Frozen structure:
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

| Action | Target | Timing | Stamina | Stat roles | Math/effect |
| --- | --- | --- | --- | --- | --- |
| `light` | 1 enemy | offense / simultaneous | semantics frozen; cost TBD | FUE offense, TEC accuracy | damage TBD |
| `heavy` | 1 enemy | offense / simultaneous | semantics frozen; cost TBD | FUE offense, TEC accuracy | damage TBD |
| `block` | none explicit | preparation / simultaneous | semantics frozen; cost TBD | RES block | mitigation TBD |
| `parry` | none explicit | preparation / simultaneous | semantics frozen; cost TBD | TEC parry | effect TBD |
| `dodge` | none explicit | preparation / simultaneous | semantics frozen; cost TBD | AGI evasion | effect TBD |
| `reposition` | none explicit | preparation / simultaneous | semantics frozen; cost TBD | AGI reposition | D2/effect TBD |

## Validation checkpoint

Runtime head `7c5cd9551877ac686d3defc0e05f2abfca8dbc53`:
- Core systems suite: **80/80 passed**;
- UI/integration: passed;
- GUT: passed;
- Godot 4.5.2 import/compile/smoke: passed;
- gdformat/gdlint: passed;
- Gitleaks: passed;
- CI Gate: passed.

Subsequent commits only update this decision ledger and do not change runtime contracts.

## Freeze rule

Legacy code, descriptions, fixtures, AI proposals or tuning experiments do not become authority automatically. A decision is frozen only when explicitly approved, reflected in runtime/data contracts, and protected by tests.
