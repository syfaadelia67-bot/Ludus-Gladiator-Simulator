# Ludus Gladiator Simulator — Pre-Asset Programming Backlog

## Canonical status

**Status: CLOSED for the demo pre-assets programming gate.**

Canonical validated checkpoint: `a175723fb72ee8252c295c92e8d19a228319d104`.

At this checkpoint:

- `DemoPreAssetReadiness.blocker_count = 0`.
- `programming_complete_allowed = true`.
- `final_assets_allowed = true`.
- Save schema remains version 14.
- Godot version remains 4.5.2.
- Repository Hygiene, Part 3 Format Probe, Godot CI and the complete Godot Tests workflow are green.
- Godot Tests includes compile/smoke, gdformat, gdlint, secret scan, GUT, Core systems, UI/integration and CI Gate.

The previous long-form checklist in this file represented the migration backlog while programming was still open. It is preserved in Git history; it is no longer the source of truth for readiness.

## Closed demo programming scope

The following demo systems are frozen, implemented and protected by automated contracts/tests:

- One canonical player turn equals one month.
- Demo campaign runs Months I–XX.
- GT I encounters occur in Months XIII, XVI and XX.
- Non-GT demo months are management-only; additional Arena content is deferred to the full game.
- Monthly economy uses the frozen operating cost contract: 88 fixed + 5 per slave + 20 per gladiator + 10 per beast.
- Sponsors, loans and bankruptcy remain preserved for Save v14 compatibility but are fail-closed in the demo until their monthly balance is designed.
- Market cadence is month-native and authored-offer based; legacy procedural refresh authority is disabled.
- Roster work, training, fatigue, injury recovery and treatment are month-native.
- Demo equipment/forge uses the authored 15-item catalog, frozen quality multipliers and canonical Combat V1 equipment snapshots.
- Canonical skills are the 12 approved Combat V1 skills. Rank 1 is usable in the demo with real runtime effects, Stamina costs, target rules and equipment requirements under `CombatSimulator` authority.
- Skill ranks 2/3 remain authored but are not enabled until a canonical persistent mastery source exists.
- Combat V1 supports 1v1, 1v2 and 2v2; 3v3 remains outside V1.
- `CombatSimulator` remains the only damage/KO/winner authority; LimboAI remains policy/intent generation only.
- Rival Combat V1 snapshots are canonical for all seven Ludi.
- GT I rival standings accept explicit external results only; no rival score RNG is authoritative.
- Jabalí, León and Oso have canonical Combat V1 stats and beast restrictions.
- Monthly event cadence is frozen from authored values using one legacy turn = one month; legacy hidden ticks are non-authoritative.
- Rival management uses the seven canonical Ludi, authored operation balance and month-native retaliation while remaining isolated from GT I snapshots/standings.
- The demo equipment, roster, economy, market, events, rival management, campaign and combat routes preserve Save v14 compatibility.
- Functional placeholder UI exists for the programmed demo routes and is covered by UI/integration contracts.

## Pre-assets exit gate

The programming gate is considered clear only while all of the following remain true:

1. `DemoPreAssetReadiness` reports zero blockers.
2. `programming_complete_allowed` is true.
3. `final_assets_allowed` is true.
4. No daily/weekly compatibility API regains independent demo simulation authority.
5. Legacy CombatManager/RivalManager cannot decide canonical Combat V1 or GT I results.
6. Save schema remains v14 unless a separately approved migration requires otherwise.
7. All required GitHub Actions validation jobs are green.
8. Any blocker discovered by the final technical audit or the upcoming human Godot playtest reopens this gate until corrected.

## Explicitly deferred and non-blocking

These items are **not** part of the closed demo programming gate and must not be treated as unfinished demo blockers:

- Full-game campaign content after Month XX, including the 120-month / 10-year structure.
- Roman god meta-progression and the full-game finale.
- Non-demo buildings such as Stables, Sanctuary, private Arena and Wall/Gate.
- Full-game equipment catalog expansion beyond the demo-authored subset.
- Combat V1 D2 distance/position unless a future approved mechanic requires it.
- Skill mastery persistence and activation of ranks 2/3.
- Monthly sponsor/loan/bankruptcy balance; these systems are fail-closed in the demo.
- Additional non-GT Arena opportunities for the full game.
- Advanced sabotage, transfer-market, retirement and career depth beyond the demo scope.

## Next gates

Programming closure does **not** mean the project skips validation. The next gates are:

1. Final technical consistency audit with no feature expansion.
2. Human local playtest in Godot from new campaign through the demo flow.
3. Any reproducible blocker found by either gate returns to programming and must be fixed before final asset replacement.
4. Only after those gates remain clear should placeholder art/audio be systematically replaced by final production assets.
