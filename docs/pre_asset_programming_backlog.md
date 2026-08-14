# Ludus Gladiator Simulator — Pre-Asset Programming Backlog

## Canonical status

**Status: CLOSED for the demo pre-assets programming gate.**

The authoritative checkpoint is the latest fully green HEAD of PR #7 on `feature/monthly-campaign-foundation`. A newer HEAD must not replace the canonical checkpoint until Repository Hygiene, Part 3 Format Probe, Godot CI and the complete Godot Tests workflow are green on that same SHA.

The closed gate requires:

- `DemoPreAssetReadiness.blocker_count = 0`.
- `programming_complete_allowed = true`.
- `final_assets_allowed = true`.
- Save schema remains version 14.
- Godot version remains 4.5.2.
- Godot Tests includes compile/smoke, gdformat, gdlint, secret scan, GUT, Core systems, UI/integration and CI Gate.

The previous long-form checklist represented the migration backlog while programming was still open. It remains available in Git history; the runtime readiness gate and current PR contract are the source of truth.

## Closed demo programming scope

The following demo systems are frozen, implemented and protected by automated contracts/tests:

- One canonical player turn equals one month.
- Demo campaign runs Months I–XX.
- The first Grand Tournament is player-facing **Torneo de Marte**.
- Torneo de Marte encounters occur in Months XIII, XVI and XX.
- Regular months support management **and** Arena activity; they are not management-only.
- Bajo Mundo is an optional non-GT Arena competition available during the demo.
- Official minor/monthly competitions coexist with the management loop outside the Grand Tournament progression.
- Torneo de Marte months may coexist with non-GT Arena opportunities.
- Non-GT competitions never award Torneo de Marte progression points.
- Non-GT Combat V1 supports 1v1, 1v2 and 2v2.
- Monthly economy uses the frozen operating cost contract: 88 fixed + 5 per slave + 20 per gladiator + 10 per beast.
- Sponsors, loans and bankruptcy remain preserved for Save v14 compatibility but are fail-closed in the demo until their monthly balance is designed.
- Market cadence is month-native and authored-offer based; legacy procedural refresh authority is disabled.
- Roster work, training, fatigue, injury recovery and treatment are month-native.
- Demo equipment/forge uses the authored 15-item catalog, frozen quality multipliers and canonical Combat V1 equipment snapshots.
- Canonical skills are the 12 approved Combat V1 skills. Rank 1 is usable in the demo with real runtime effects, Stamina costs, target rules and equipment requirements under `CombatSimulator` authority.
- Skill ranks 2/3 remain authored but are not enabled until a canonical persistent mastery source exists.
- Combat V1 supports 1v1, 1v2 and 2v2; 3v3 remains outside V1.
- `CombatSimulator` remains the only damage/KO/winner authority; LimboAI remains policy/intent generation only.
- Player and rival combat decisions both pass through the LimboAI policy path.
- The player Tactical Plan is configured before combat and has hard priority over legal fallback actions.
- The final Arena flow is zero-input after start: one `INICIAR COMBATE` action launches autobattle until `encounter_finished`.
- Manual action, target and resolve-exchange controls are not part of the final player-facing combat flow.
- Rival Combat V1 snapshots are canonical for all seven Ludi.
- GT rival standings accept explicit external results only; no rival score RNG is authoritative.
- Jabalí, León and Oso have canonical Combat V1 stats and beast restrictions.
- Monthly event cadence is frozen from authored values using one legacy turn = one month; legacy hidden ticks are non-authoritative.
- Rival management uses the seven canonical Ludi, authored operation balance and month-native retaliation while remaining isolated from GT snapshots/standings.
- A read-only Combat presentation event adapter projects resolved simulator facts for presentation without gaining damage, hit, Stamina, KO or winner authority.
- Presentation events include exchange start, declared actions, Stamina spend/recovery, resolved attacks, knockouts and combat finish.
- The demo equipment, roster, economy, market, events, rival management, campaign and combat routes preserve Save v14 compatibility.
- Functional placeholder UI exists for the programmed demo routes and is covered by UI/integration contracts.

## Pre-assets exit gate

The programming gate is considered clear only while all of the following remain true:

1. `DemoPreAssetReadiness` reports zero blockers.
2. `programming_complete_allowed` is true.
3. `final_assets_allowed` is true.
4. No daily/weekly compatibility API regains independent demo simulation authority.
5. Legacy CombatManager/RivalManager cannot decide canonical Combat V1 or tournament results.
6. Save schema remains v14 unless a separately approved migration requires otherwise.
7. All required GitHub Actions validation jobs are green on the same HEAD.
8. Arena remains one-start autobattle with no mandatory mid-fight player input.
9. Presentation code remains a consumer of simulator facts and cannot alter combat mathematics.
10. Any blocker discovered by technical or human functional QA reopens this gate until corrected.

## Explicitly deferred and non-blocking

These items are **not** unfinished demo programming blockers:

- Full-game campaign content after Month XX, including the 120-month / 10-year structure.
- Roman-god meta-progression and the full-game finale.
- Non-demo buildings such as Stables, Sanctuary, private Arena and Wall/Gate.
- Full-game equipment catalog expansion beyond the demo-authored subset.
- Combat V1 D2 distance/position as a mathematical mechanic.
- Skill mastery persistence and activation of ranks 2/3.
- Monthly sponsor/loan/bankruptcy balance; these systems are fail-closed in the demo.
- Full-game expansion of casual, underground and tournament content beyond the demo calendar.
- Advanced sabotage, transfer-market, retirement and career depth beyond the demo scope.
- Final 3D models, rigs, animations, Arena environments, audio, VFX and production UI assets.

## Next gates

Programming closure does **not** mean production is complete. The next gates are:

1. Keep the full CI matrix green after every hardening change.
2. Run final technical consistency audits without reopening feature scope unnecessarily.
3. Run human functional playtests from a new campaign through the complete Demo flow.
4. Convert the resolved combat presentation-event stream into the future 2.5D staging/animation layer without changing simulator authority.
5. Replace placeholder art/audio systematically with final production assets only after the functional route remains stable.
6. Validate 3D staging, animation readability, collision/spacing, camera framing and performance for 1v1, 1v2 and 2v2.
7. Run balance, save/load, release-build and Steam QA before declaring the Demo release-ready.
