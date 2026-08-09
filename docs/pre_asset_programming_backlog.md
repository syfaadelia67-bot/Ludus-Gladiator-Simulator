# Ludus Gladiator Simulator — Pre-Asset Programming Backlog

## Purpose

This is the technical exit checklist before production shifts to final assets, animation replacement, visual polish, audio polish and presentation tuning for the demo.

The demo programming gate is **not** “every full-game feature is finished”. It means the complete demo loop from new campaign through Month XX is playable with placeholders, uses canonical monthly rules, has no legacy system acting as hidden gameplay authority, survives save/load and has deterministic automated coverage.

## Status legend

- `[x]` closed and protected by tests/contracts.
- `[~]` partially migrated; usable pieces exist but the authority boundary is not yet closed.
- `[ ]` programming work still required.
- `[BLOCKED]` implementation must wait for a frozen design/data decision; do not invent values.

---

## P0 — Demo blockers: must close before final assets/polish

### 1. Monthly campaign authority

- [x] Canonical player turn is one month via `GameState.get_month()` / `advance_month()`.
- [x] Demo campaign chapters and finale target Months I–XX.
- [x] Legacy week/day advancement methods are compatibility aliases rather than extra simulation ticks.
- [ ] Migrate every active demo consumer from weekly/daily authority to month-native authority or mark it as an adapter-only compatibility layer.
- [ ] Remove weekly terminology from functional UI, blockers, reports and player-facing messages where it no longer represents real time.
- [ ] Add a regression contract proving no demo gameplay system can create additional hidden daily/weekly simulation ticks.

### 2. Economy

- [x] Starting demo balance is frozen at 650 denarii in `economy_rules.json`.
- [x] Monthly operating-cost data is frozen at 88 fixed + 5/slave + 20/gladiator + 10/beast.
- [x] Pure monthly operating-cost calculator exists and rejects legacy daily/weekly formulas.
- [ ] Replace active legacy maintenance/wage calculations in `EconomyManager` with the frozen monthly operating-cost calculation.
- [ ] Define a canonical owned-beast count source before beast maintenance can be charged.
- [ ] Convert insolvency counters and bankruptcy thresholds from day/week semantics to explicit monthly semantics.
- [BLOCKED] Freeze monthly sponsor duration, recurring income, victory bonus/failure penalty cadence and eligibility balance before migrating sponsor contracts.
- [BLOCKED] Freeze monthly loan terms, interest/installment cadence and default rules before migrating loans.
- [ ] Convert ledger/projections/presenters to month-native fields while preserving Save v14 compatibility aliases.
- [ ] End-to-end test insufficient funds, partial payment/default, debt persistence and campaign-defeat interaction on monthly cadence.

### 3. Market

- [~] Character/equipment buying exists and roster/equipment integration works.
- [~] Random character offers receive explicit `resistance`, but the value is currently a compatibility baseline rather than a frozen generation policy.
- [ ] Replace `week_advanced` / three-week refresh authority with a frozen monthly market cadence.
- [BLOCKED] Freeze market refresh cadence and any manual refresh price under monthly economy.
- [BLOCKED] Freeze canonical stat-generation ranges/policy for non-unique recruits, including RES.
- [ ] Ensure generated traits only use the frozen normal-trait catalog and remain mutually compatible.
- [ ] Migrate market copy and countdowns from weeks to months.
- [ ] Save/load and new-campaign reset tests for offer cadence and serials.

### 4. Roster, work, fatigue and recovery

- [~] Roster, jobs, fatigue, morale, loyalty, training and injuries exist.
- [ ] Replace `process_day()` as active management semantics with a month-native work/recovery step or a clearly named adapter that performs exactly one monthly tick.
- [BLOCKED] Freeze monthly output formulas for mining, security, espionage and training before treating current daily formulas as canonical.
- [BLOCKED] Freeze monthly fatigue gain/recovery and injury recovery durations.
- [ ] Rename or isolate `injury_days`, recovery-week text and related weekly fields while keeping Save v14 migration compatibility.
- [ ] Define which management stats can influence Combat V1; unapproved legacy attack/defense/energy formulas must not leak into Combat V1.
- [ ] Verify slave-to-gladiator training promotion on the final monthly cadence.

### 5. Finca / buildings

- [x] Full-game building catalog is data-driven; demo availability is seven buildings rather than a structural seven-building limit.
- [x] Demo level cap III and full-game structural cap X are represented in data.
- [ ] Replace hardcoded building-effect formulas with catalog-driven values where the data already owns the effect.
- [BLOCKED] Freeze the Mine upgrade cost; `mine.upgrade_cost_pending` intentionally blocks upgrades today.
- [ ] Verify monthly training/recovery/capacity effects after roster cadence is migrated.
- [ ] Verify every demo building can be constructed/upgraded/blocked correctly with placeholder UI.
- [ ] Ensure non-demo buildings stay visibly/structurally excluded without deleting their full-game data.

### 6. Equipment / forge

- [~] Equipment catalog is data-driven and inventory/equip/unequip/crafting flows exist.
- [~] Combat V1 consumes explicit aggregate equipment `power/defense` snapshots.
- [ ] Freeze the exact demo equipment subset and remove partial legacy items from demo authority where necessary.
- [BLOCKED] Freeze any still-pending equipment numeric balance, forge costs and quality policy that must affect the demo.
- [ ] Decide whether random quality remains part of the demo; if yes, own it in an explicit canonical rule rather than an inherited helper.
- [ ] Remove legacy ability gating from Combat V1 equipment authority; equipment tags may only gate canonical skills after skill mechanics are frozen.
- [ ] Save/load tests for complete equipped slots and Combat V1 snapshot equivalence.

### 7. Canonical skills and progression

- [x] `skills.json` owns the 12 frozen Combat V1 skill identities: 8 general + 4 specialized.
- [x] Frozen-data validation rejects speculative mechanical fields in that identity catalog.
- [ ] Reconcile the old 8-ability `abilities.json` / `GladiatorProgressionManager` path with the new canonical 12-skill model.
- [ ] Update stale preflight tests that still describe the old abilities as canonical.
- [BLOCKED] Freeze mechanical behavior for the 12 skills that will actually be usable in the demo: action mapping, costs, timing, legal targets, equipment requirements and effects.
- [ ] Implement frozen skill mechanics through Combat V1 resolvers rather than through the legacy CombatManager.
- [ ] Migrate specialization mastery/training unlocks to canonical skill IDs.
- [ ] Quarantine or disable any legacy skill/ability effect that has no canonical Combat V1 mapping.

### 8. Combat V1 core

- [x] Canonical stats are FUE / AGI / TEC / RES / PV + Stamina.
- [x] RES is independent persistent `LudusPerson.resistance`.
- [x] 1v1, 1v2 and 2v2 loops are implemented and tested.
- [x] D1 and D3–D10 are frozen/implemented; D2 is not required for current V1.
- [x] `CombatSimulator` is the only combat-result authority.
- [x] LimboAI is policy/intent generation only.
- [ ] Remove/quarantine `combat_manager_weekly.gd` from active canonical demo combat. Its weekly event schedule, attack/defense/energy formulas, RNG injuries and rival generation are legacy.
- [ ] Route every playable demo arena combat through Combat V1 runtime.
- [ ] Connect canonical injuries/career consequences to Combat V1 outcomes after injury rules are frozen.
- [ ] Migrate CombatHistory to canonical Combat V1 results.
- [ ] Add save/quit policy for an in-progress Combat V1 session; either persist it or explicitly prevent saving during combat.

### 9. Playable Combat V1 UI

- [~] Read-only GT I/tiebreak presentation snapshots exist.
- [ ] Build the actual placeholder combat screen/controller around Combat V1.
- [ ] Player fighter selection from live roster.
- [ ] Player action selection and target selection with illegal actions disabled.
- [ ] LimboAI rival intent collection through the existing policy bridge.
- [ ] Exchange advance button/state machine and deterministic result presentation.
- [ ] PV and Stamina state presentation.
- [ ] KO, team win, double-KO and rematch presentation.
- [ ] Consecutive-series carryover presentation for Month XIII and XX.
- [ ] Month XX unilateral substitution UI and validation.
- [ ] Combat result -> TournamentManager -> CampaignManager -> history handoff.
- [ ] Keyboard/gamepad/focus baseline for all combat controls before visual polish.

### 10. GT I rival fighter source

- [x] Seven canonical rival Ludus identities exist independently from legacy RivalManager.
- [x] `rival_combat_v1_snapshots.json` exists and intentionally contains no invented stats.
- [x] DataRepository loads the catalog and validates future entries.
- [x] Provider requires explicit fighter ID and canonical Combat V1 snapshot; no RNG/fallback generation.
- [BLOCKED] Freeze actual rival gladiator identities, Combat V1 stats, team IDs and equipment snapshots.
- [BLOCKED] Freeze rival fighter availability/selection rules for GT I.
- [ ] Populate the canonical rival snapshot catalog only after those values are frozen.
- [ ] Provide the selected rival snapshot to each GT I combat, not only the championship tiebreak.
- [ ] Ensure legacy `RivalManager` cannot become combat or score authority.

### 11. GT I standings and tiebreaks

- [x] Player GT I series: 9 bouts / max 27 points.
- [x] Seven rival standings entries are explicit external results; no score RNG exists in standings authority.
- [x] Non-podium tiebreak policy = head-to-head then prior-season position.
- [x] Exact 27/9 two-way first-place championship tiebreak = special 1v1, zero points, double KO rematch.
- [x] Championship runtime can resolve standings through CombatSimulator/TournamentManager.
- [ ] Build the real campaign source for the seven rival GT I results without fabricating scorelines.
- [BLOCKED] Freeze how rival-vs-rival GT I results are obtained/scheduled if they are not authored data.
- [ ] Provide canonical head-to-head and prior-season-position data for non-podium ties.
- [BLOCKED] Freeze remaining podium tie shapes or explicitly declare them impossible/out-of-scope in the demo.
- [ ] Wire real tiebreak launch from UI after rival fighter data exists.
- [ ] Save/load coverage across unresolved standings and resolved tiebreaks.

### 12. Beasts

- [x] Canonical identities and behavior restrictions exist for Jabalí, León and Oso.
- [x] Month XVI beast selection is fail-closed while Combat V1 stats are missing.
- [BLOCKED] Freeze FUE / AGI / TEC / RES / PV + Stamina for all three beasts.
- [BLOCKED] Freeze their allowed Combat V1 actions/intent policy.
- [ ] Implement beast -> Combat V1 snapshot adapter.
- [ ] Integrate beast opponent selection into Month XVI once canonical data exists.
- [ ] Test no block/parry/skills/traits/equipment behavior leaks into beasts.

### 13. Monthly events and rival management

- [~] Narrative event choices/chains and rival operations exist.
- [ ] Migrate event scheduling and follow-up delays from `queued_chain_week` / `process_week()` to month-native authority.
- [ ] Replace weekly wording in event chains and requirement feedback.
- [ ] Decide which legacy rival sabotage/espionage operations are in the demo and quarantine the rest.
- [BLOCKED] Freeze monthly rival-operation cadence/cost/risk rules before treating current RNG formulas as canonical.
- [ ] Ensure rival-management RNG can never alter GT I combat stats or standings directly.

### 14. Monthly planning / turn closure

- [~] Weekly planning/closure presenters provide a useful structural prototype.
- [ ] Replace `WeeklyPlanningController` calculations with monthly food/economy/work/combat expectations.
- [ ] Remove `GameState.DAYS_PER_WEEK` from active planning calculations.
- [ ] Define exactly what blocks advancing a month.
- [BLOCKED] Decide whether non-GT months require an arena combat; the legacy manager currently invents a mandatory weekly fight schedule and cannot remain authority.
- [ ] Rename/migrate WeeklyCyclePresentation, WeeklyClosurePresenter, WeeklyCalendarPresenter and WeeklyEventModalPresenter to month-native behavior or strict adapters.
- [ ] Ensure one click advances exactly one month and all subsystems process once in deterministic order.

### 15. Months without GT I

- [ ] Define the playable management/arena loop for Months I–XII, XIV–XV, XVII–XIX.
- [BLOCKED] Freeze which arena opportunities are mandatory/optional outside the three GT I encounters; do not preserve the legacy exhibition/underground/beast schedule by accident.
- [ ] Connect those approved activities to Combat V1 if they involve combat.
- [ ] Ensure CampaignManager objectives/rank progression use only approved demo activities.

### 16. Tutorial / onboarding

- [~] Start screen, initial gladiator selection and tutorial infrastructure exist.
- [ ] Rewrite onboarding around a monthly turn rather than a weekly loop.
- [ ] Teach first purchase, roster/work assignment, finca, equipment and Month XIII GT I preparation with placeholder presentation.
- [ ] Teach monthly blockers without referencing mandatory weekly combat.
- [ ] Ensure tutorial state survives save/load or has an explicit restart policy.

### 17. Save v14 and runtime persistence

- [x] Save version stays 14 during current migration and compatibility tests protect it.
- [x] GT I standings/tiebreak resolved state uses existing Save v14-compatible state.
- [ ] Audit every newly active monthly subsystem for required persistence.
- [ ] Decide persistence policy for in-progress Combat V1, consecutive GT series and championship rematch state.
- [ ] Preserve legacy week/day fields only as migration aliases; no new system may reinterpret them independently.
- [ ] New campaign full reset must clear every GT/rival/combat/monthly runtime state.
- [ ] Corrupt/old-save recovery test after the monthly migration is complete.

### 18. Functional UI before art

- [~] Main navigation, finca, dossier, market and tournament presentation infrastructure exists.
- [ ] Complete all placeholder functional routes required for the Month I–XX loop.
- [ ] Ensure every screen has empty, blocked, error and completed/read-only states.
- [ ] Remove contradictory legacy terminology and old combat numbers from tooltips/presenters.
- [ ] Finalize functional localization keys in ES before replacing visual assets; other locales can follow the same stable keys.
- [ ] Baseline scaling/focus/input validation at supported resolutions before pixel-perfect polish.

### 19. Demo finale

- [x] Campaign finale waits for completed GT I classification at/after Month XX.
- [x] Podium = demo victory; no podium = demo defeat in current campaign contract.
- [ ] Ensure unresolved standings/tiebreak prevents premature campaign closure.
- [ ] Final result screen must consume GT I placement/medal and preserve read-only post-campaign access.
- [ ] Save/load completed campaign and continue-to-summary paths after final monthly migration.

### 20. Automated quality gate

- [x] Godot 4.5.2 compile/smoke, gdformat/gdlint, secret scan, Core, UI/integration, GUT and CI Gate exist.
- [ ] Add an end-to-end placeholder-art scenario: New Campaign -> Month XX -> all 9 GT I bouts -> standings -> optional championship tiebreak -> final result -> save/load.
- [ ] Add a contract that fails if canonical demo combat calls legacy CombatManager result generation.
- [ ] Add a contract that fails if a canonical monthly system schedules hidden daily/weekly ticks.
- [ ] Add a pre-asset readiness report that lists unresolved blockers from canonical data/contracts.
- [ ] Require the pre-asset readiness report to be clear before declaring programming complete.

---

## P1 — Important, but may be deferred from the demo programming gate if explicitly scoped out

- [ ] Full career/retirement depth beyond what the demo needs.
- [ ] Advanced transfer-market systems beyond the minimum demo loop.
- [ ] Advanced gladiator rivalry consequences not required by GT I.
- [ ] Full sabotage/espionage metagame beyond the chosen demo actions.
- [ ] Non-demo building behavior: Establo, Santuario, Arena privada, Muralla/Puerta, etc.
- [ ] Full equipment catalog beyond the demo-essential subset.
- [ ] Combat V1 D2 distance/position model unless a frozen skill/future format requires it.
- [ ] Full-game campaign content for Months XXI–CXX and later Grand Tournaments.
- [ ] Roman god meta-progression and ten-year/full-game finale; preserve architecture hooks but do not block demo assets unless the demo directly previews the system.

---

## Pre-asset exit gate

Final asset production and real visual/audio polish may begin when all of the following are true:

1. Month I–XX is playable end-to-end with placeholders.
2. No active demo gameplay authority is secretly daily/weekly.
3. Legacy CombatManager/RivalManager cannot decide canonical Combat V1 or GT I results.
4. Monthly economy, work, market, recovery and event cadence is frozen and implemented.
5. GT I has real canonical rival fighters/results and every reachable tiebreak path is resolvable.
6. Beast paths used by the demo have canonical Combat V1 data, or are explicitly excluded from the demo.
7. Canonical skills/progression have one authority; legacy abilities cannot leak mechanics into Combat V1.
8. Save/load/new-campaign reset are stable across the entire loop.
9. All required screens/actions work with placeholders and final localization keys.
10. Full end-to-end and CI suites are green.

Only after this gate should placeholder graphics be systematically replaced by final character/environment/UI assets and production animation/audio polish.
