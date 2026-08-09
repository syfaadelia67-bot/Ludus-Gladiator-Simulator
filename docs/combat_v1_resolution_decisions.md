# Combat V1 — Resolution Decision Matrix

Status: **PARTIALLY FROZEN**

Frozen: D1 target rules, D3 exchange order, and D5-D9 structural contracts. Exact combat coefficients remain pending until explicitly frozen and tested.

## D5 — Armor and vulnerability
- armor source: canonical equipment `defense`;
- armor and RES remain separate;
- no body-part armor in V1;
- vulnerability is explicit simulator-owned runtime state;
- initial `vulnerable = false`;
- mitigation/penetration numbers remain pending D4.

## D6 — Stamina
- canonical field: `stamina`;
- minimum 0; negative values invalidate CombatState;
- insufficient Stamina rejects the action;
- legacy `energy` is not authoritative;
- costs/recovery amount/recovery timing remain pending.

## D7 — Accuracy and criticals
- no RNG for V1 hit resolution;
- critical hits disabled in V1;
- accuracy owned by `CombatSimulator`;
- deterministic accuracy formula remains pending.

## D8 — Stat roles
- FUE -> offensive power;
- AGI -> evasion + reposition;
- TEC -> accuracy + parry;
- RES -> mitigation + block;
- PV -> maximum health;
- legacy `endurance` cannot silently become RES;
- exact weights remain pending.

## D9 — KO and surrender
- runtime health: `current_pv`;
- max health: `stats.PV`;
- runtime initializes `current_pv = stats.PV`;
- KO at `current_pv <= 0` under `CombatSimulator` authority;
- surrender is not a seventh base action;
- probabilistic surrender forbidden;
- exact surrender rules remain pending.

## Runtime support
- `combat_rules_d5_d9_contract.gd` centralizes D5-D9 structure;
- `combat_runtime_state_builder.gd` creates isolated `current_pv` and `vulnerable` fields;
- `combat_contract.gd` rejects negative Stamina;
- resolution readiness separates frozen structure from pending math/eligibility;
- simulator/gateway expose both states without inventing values.

## Remaining blockers
1. D4 damage/mitigation math — next required blocker.
2. D5 armor numeric mitigation/penetration.
3. D6 Stamina cost/recovery values.
4. D7 deterministic accuracy formula.
5. D8 exact stat weights.
6. D9 surrender eligibility/trigger rules.
7. D10 carryover.
8. D2 position/distance remains conditional.

## Validation
Runtime head `7c5cd9551877ac686d3defc0e05f2abfca8dbc53` passed Core **80/80**, UI/integration, GUT, Godot 4.5.2 compile/smoke, gdformat/gdlint, Gitleaks and CI Gate. Later edits to this ledger are documentation-only.

## Freeze rule
Legacy code, descriptions, fixtures, AI proposals and tuning experiments never become authority automatically. Numeric values remain pending until explicitly frozen and contract-tested.
