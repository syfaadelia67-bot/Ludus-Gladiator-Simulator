# Combat V1 — Resolution Decision Matrix

Status: **PARTIALLY FROZEN**

Frozen runtime structure:
- D1 target rules;
- D3 exchange resolution order;
- D5 armor/vulnerability structure;
- D6 Stamina structure;
- D7 accuracy/critical structure;
- D8 canonical stat roles;
- D9 KO structure.

Still pending by design:
- D2 position/distance (conditional);
- D4 damage/mitigation math (next blocker);
- D5 armor mitigation/penetration numbers;
- D6 Stamina costs/recovery numbers and timing;
- D7 deterministic accuracy formula;
- D8 exact stat weights;
- D9 surrender eligibility/trigger rules;
- D10 carryover.

## D5 — Armor and vulnerability

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

- armor source: canonical equipment `defense`;
- armor and RES are separate simulator inputs;
- no body-part armor model in Combat V1;
- vulnerability is explicit runtime state owned by `CombatSimulator`;
- fighters start with `vulnerable = false`;
- exact armor mitigation and penetration remain pending D4.

## D6 — Stamina

Status: `FROZEN STRUCTURE / NUMERIC SUBRULES PENDING`

- `stamina` is canonical;
- minimum is 0;
- negative Stamina invalidates CombatState;
- insufficient Stamina rejects the action;
- legacy `energy` is not promoted;
- exact action costs/recovery amount/recovery timing remain pending.

## D7 — Accuracy and criticals

Status: `FROZEN STRUCTURE / FORMULA PENDING`

- no RNG for V1 hit resolution;
- critical hits disabled in V1;
- accuracy is owned by `CombatSimulator`;
- deterministic accuracy formula remains pending.

## D8 — Stat roles

Status: `FROZEN ROLES / WEIGHTS PENDING`

- FUE -> offensive power;
- AGI -> evasion + reposition;
- TEC -> accuracy + parry;
- RES -> mitigation + block;
- PV -> maximum health;
- `endurance` cannot silently substitute for RES;
- exact weights remain pending.

## D9 — KO and surrender

Status: `FROZEN KO STRUCTURE / SURRENDER RULES PENDING`

- runtime health field: `current_pv`;
- maximum health source: `stats.PV`;
- combat initializes `current_pv = stats.PV`;
- KO occurs at `current_pv <= 0`;
- KO authority belongs to `CombatSimulator`;
- surrender is not a seventh base action;
- probabilistic surrender is forbidden;
- exact surrender rules remain pending.

## Runtime support

- `combat_rules_d5_d9_contract.gd` centralizes D5-D9 structure;
- `combat_runtime_state_builder.gd` creates isolated `current_pv` and `vulnerable` runtime fields;
- `combat_contract.gd` rejects negative Stamina;
- `combat_resolution_readiness.gd` separates frozen structure from pending math/eligibility;
- `CombatSimulator` and `CombatDecisionGateway` expose this separation without inventing resolution values.

## Validation

Runtime head `7c5cd9551877ac686d3defc0e05f2abfca8dbc53` passed:
- Core **80/80**;
- UI/integration;
- GUT;
- Godot 4.5.2 import/compile/smoke;
- gdformat/gdlint;
- Gitleaks;
- CI Gate.

Later commits in this file are documentation-only.

## Freeze rule

Legacy code, descriptions, fixtures, AI proposals and tuning experiments are never authority by themselves. Exact numerical values remain pending until explicitly frozen and contract-tested.
