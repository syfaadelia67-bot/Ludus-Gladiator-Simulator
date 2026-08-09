# Combat V1 — Resolution Decision Matrix

Status: **PARTIALLY FROZEN**

D1 target rules and D3 exchange resolution order are frozen. D5-D9 now also have frozen structural contracts while their exact numeric/eligibility subrules remain pending.

## D5 — Armor and vulnerability

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

- armor source is canonical equipment `defense`;
- armor and RES are separate simulator inputs;
- no body-part armor model in Combat V1;
- vulnerability is an explicit runtime state owned by `CombatSimulator`;
- fighters start `vulnerable = false`;
- exact armor mitigation and penetration remain pending D4.

## D6 — Stamina

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

- `stamina` is canonical;
- minimum is 0; negative Stamina invalidates CombatState;
- insufficient Stamina rejects the action;
- legacy `energy` is not promoted;
- exact action costs, recovery amount and recovery timing remain pending.

## D7 — Accuracy and criticals

Status: `FROZEN STRUCTURE / FORMULA PENDING`

- no RNG for V1 hit resolution;
- critical hits are disabled in V1;
- `CombatSimulator` owns accuracy resolution;
- deterministic accuracy formula remains pending.

## D8 — Stat roles

Status: `FROZEN ROLES / WEIGHTS PENDING`

- FUE -> offensive power;
- AGI -> evasion + reposition;
- TEC -> accuracy + parry;
- RES -> mitigation + block;
- PV -> maximum health;
- legacy `endurance` cannot silently substitute for RES;
- exact stat weights remain pending.

## D9 — KO and surrender

Status: `FROZEN KO STRUCTURE / SURRENDER RULES PENDING`

- runtime health field: `current_pv`;
- maximum health source: `stats.PV`;
- combat initializes `current_pv = stats.PV`;
- KO occurs at `current_pv <= 0`;
- KO authority belongs to `CombatSimulator`;
- surrender is not a seventh base action;
- probabilistic surrender is forbidden;
- exact surrender eligibility/trigger rules remain pending.

## Runtime support

- `combat_rules_d5_d9_contract.gd` centralizes D5-D9 structure;
- `combat_runtime_state_builder.gd` creates isolated `current_pv` and `vulnerable` fields;
- `combat_contract.gd` rejects negative Stamina;
- readiness distinguishes frozen structure from pending math/eligibility;
- `CombatSimulator` and `CombatDecisionGateway` expose this separation.

## Remaining blockers

- D2 position/distance: conditional;
- D4 damage/mitigation math: **next required blocker**;
- D5 armor mitigation/penetration values;
- D6 Stamina costs/recovery;
- D7 deterministic accuracy formula;
- D8 exact stat weights;
- D9 surrender rules;
- D10 carryover.

## Validation

Runtime head `7c5cd9551877ac686d3defc0e05f2abfca8dbc53` passed Core **80/80**, UI/integration, GUT, Godot 4.5.2 compile/smoke, gdformat/gdlint, Gitleaks and CI Gate. Later commits to this file are documentation-only.

## Freeze rule

Legacy code, descriptions, fixtures, AI proposals and tuning experiments are never authority by themselves. Exact numerical values remain pending until explicitly frozen and contract-tested.
