# Combat V1 — Legacy evidence audit

This document records implementation evidence found in the existing legacy combat system. It is **reference material only** and is not a frozen Combat V1 balance contract.

## Legacy authority inspected

- `game/scripts/systems/combat_manager.gd` is only a compatibility wrapper.
- The active legacy implementation is `game/scripts/systems/combat_manager_fixed.gd`.

## Recovered legacy behavior

The old system uses a model that differs materially from Combat V1:

- a `basic_attack` with `energy_cost = 8`, `damage_multiplier = 1.0`, and no accuracy bonus;
- abilities with individual energy costs, damage multipliers, accuracy modifiers and probabilistic status effects;
- a base accuracy expression derived from legacy agility/technique plus progression modifiers;
- tactic-level attack/defense/accuracy modifiers (`aggressive`, `defensive`, `careful`);
- a hit roll driven by RNG and clamped legacy hit chance;
- damage based on legacy `attack`, ability multiplier and effective defense;
- armor penetration as an ability percentage;
- energy regeneration rules and automatic recovery when an action cannot be paid;
- probabilistic bleed, stun, blind, entangle and action-loss effects;
- probabilistic surrender below a configurable health threshold;
- legacy event scheduling and combat authority coupled to `GameState.day`;
- legacy enemy generation tied to old `strength/agility/endurance/technique` fields.

## Why these values are not migrated automatically

Combat V1 has already frozen a different structural contract:

- canonical combat stats are `FUE / AGI / TEC / RES / PV` plus Stamina;
- canonical base actions are `light`, `heavy`, `block`, `parry`, `dodge`, `reposition`;
- LimboAI is policy only and cannot resolve combat outcomes;
- `CombatSimulator` is the sole authoritative resolution boundary;
- supported competitive formats are `1v1`, `1v2`, and `2v2`;
- the monthly campaign is authoritative; legacy day-based combat timing cannot be promoted.

Copying the old formulas directly would therefore freeze several unapproved mappings and balance decisions, especially around RES, Stamina, targeting, action timing and RNG.

## Reusable evidence versus pending design

The legacy code is useful as a historical baseline for later comparison of pacing and lethality. It can inform tuning after the new rules are frozen, but it does **not** currently authorize any numeric Combat V1 formula.

The unresolved resolution decisions are exposed at runtime by `combat_resolution_readiness.gd` and returned by `CombatSimulator` whenever a valid intent reaches the unresolved authority boundary.

`position_and_distance_model` is explicitly conditional: Combat V1 must first decide whether spatial distance belongs in the first authoritative version before it can become a required rule.
