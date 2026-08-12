# Point 3 — Human local Godot playtest protocol

Status: IN PROGRESS
Validated starting checkpoint: `60b2187302f8239395a01de2a77327761b291f03`
Engine: Godot 4.5.2
Save schema: v14
Scope: demo Months I–XX

## Purpose

Point 3 is the first gate that depends on real human interaction with the running game. Automated CI is already green. This pass is intended to find interaction, navigation, presentation, state-continuity, and real-flow defects that automated contracts can miss.

Any reproducible blocker discovered here reopens programming. Final asset replacement remains blocked only by reproducible gameplay defects, not by visual placeholder quality.

## Evidence rule

For every defect, capture:

- current month;
- screen/system;
- exact action performed;
- expected result;
- observed result;
- whether the error repeats after reload;
- Godot debugger/error text when present;
- screenshot when the defect is visual/navigation related.

Severity:

- P0: crash, save corruption, campaign cannot continue, wrong authoritative combat result.
- P1: required demo path blocked, duplicated monthly processing, GT I cannot complete, state lost after load.
- P2: important UI/action mismatch with a workaround.
- P3: cosmetic/presentation issue that does not block play.

P0/P1 reopens programming immediately. P2 is fixed before asset replacement if it affects the demo flow. P3 is tracked unless it indicates a contract mismatch.

## Phase A — New campaign and initial state

1. Launch the project from `res://scenes/Main.tscn`.
2. Confirm the title screen appears and does not expose the campaign behind the overlay.
3. Confirm Continue is disabled when no valid save exists.
4. Select New Campaign.
5. Verify Dominus/Domina selector works.
6. Enter a name shorter than two characters and confirm campaign start is rejected with a readable validation message.
7. Enter a valid name.
8. Cycle through all four origins and confirm the origin description and bonuses update without stale text.
9. Start a campaign.
10. Confirm the campaign opens without a duplicate title overlay.
11. Confirm the HUD shows `MES 1`.
12. Record starting denarii, food, ore, reputation and roster count.
13. Close to title/menu if available and Continue the saved campaign.
14. Confirm Month 1 and the initial resources/roster are unchanged after load.

Pass condition: new campaign creation, first save and immediate load are lossless.

## Phase B — Core management navigation

From Month 1, visit each required demo system at least once:

- Finca
- Barracones
- Personal
- Mercado
- Forja
- Vínculos
- Arena
- Campaña
- Eventos
- Rivales
- Economía
- Torneos
- Progresión
- Personalidad
- Transferencias
- Historial

For every route verify:

- the expected screen opens;
- there is a usable route back or to another system;
- the HUD remains visible/consistent where intended;
- no system opens behind another modal;
- no button stays permanently disabled after returning;
- no screen displays weekly authority as current gameplay semantics;
- no placeholder button performs an undocumented authoritative action.

Pass condition: no dead-end navigation or inaccessible required demo system.

## Phase C — Representative Month 1 management action

1. Inspect roster and one gladiator dossier.
2. Change at least one worker/gladiator assignment where allowed.
3. Perform one training-related interaction.
4. Visit Mercado and inspect current authored offers.
5. Visit Forja/Equipment and inspect one equipment action that is available with current resources.
6. Visit Economía and record the projected monthly operating cost.
7. Confirm Arena says this is a management month with no GT.
8. Advance Month 1 exactly once.
9. Observe the monthly closure/event presentation.
10. Confirm the HUD moves to `MES 2`, never to Week/Day 2 as active semantics.
11. Compare resources against the expected monthly economy report.
12. Confirm roster fatigue/training/recovery changes happen once.
13. Press no additional advance action during a pending modal; confirm duplicate month processing cannot be triggered.

Pass condition: one player action closes exactly one canonical month.

## Phase D — Save v14 mid-campaign continuity

At a regular management month after at least one state-changing action:

1. Record month, denarii, food, ore, reputation.
2. Record one worker assignment.
3. Record one gladiator's PV-relevant persistent stats, fatigue/injury/training state and equipped slots.
4. Record Rival management state visible to the player where exposed.
5. Save/return to title and Continue.
6. Verify all recorded values match.
7. Advance the month once after reload.
8. Confirm economy, roster and rival management process once only.

Pass condition: load does not duplicate the current month's processing and does not lose monthly state.

## Phase E — GT I Month XIII

Reach Month XIII using normal advancement.

Before entering combat:

- Arena alert must show GT I pending.
- Torneos must show the Month XIII encounter.
- Select the required player gladiator according to the UI contract.

Run all three consecutive 1v1 bouts.

Verify:

- same selected player gladiator is used across the series;
- PV and Stamina carry over between consecutive bouts;
- a finished bout registers exactly once;
- player win adds exactly 3 points;
- double KO is not counted as a win;
- combat history gets one observer-only entry per completed bout;
- standings/progress do not change before a bout actually completes;
- GT I completion becomes 3/3 and Arena shows Completed.

Save/load during or immediately after the series if the UI permits it and verify the series cannot duplicate completed bouts.

Pass condition: Month XIII series is completable with correct carryover and scoring.

## Phase F — GT I Month XVI

Reach Month XVI.

Run the three independent 1v1 bouts.

Verify:

- each bout starts from a fresh combat state;
- previous bout PV/Stamina does not carry into the next independent bout;
- each completed bout registers once;
- scoring and history behave identically to Month XIII authority rules.

Pass condition: Month XVI differs from XIII exactly in the intended fresh-state rule.

## Phase G — GT I Month XX

Reach Month XX.

Select the required pair and run all three consecutive 2v2 bouts.

Verify:

- same pair continues by default;
- at most one unilateral player substitution is allowed by the series contract;
- continuing member carries PV/Stamina;
- substitute enters fresh;
- invalid extra substitutions are rejected by UI/runtime rather than silently accepted;
- Interception and other 2v2-only targeting behavior does not select invalid allies/enemies;
- all three bouts register exactly once;
- standings/placement/finale resolve after the intended completion point.

Pass condition: Month XX can reach the demo result screen without authority mismatch or soft lock.

## Phase H — Campaign completion

After Month XX:

1. Verify campaign completion state is read-only where intended.
2. Verify Advance Month is disabled.
3. Return to title/menu.
4. Verify Continue becomes the final-result action when the save is completed.
5. Load the completed save.
6. Confirm victory/defeat, wins/losses and final summary are stable.
7. Confirm no Month XXI gameplay can be entered from the demo UI.

Pass condition: demo terminates cleanly and cannot continue into undeclared full-game content.

## Phase I — Presentation sweep

During the entire playthrough log P2/P3 defects for:

- clipped or overlapping controls;
- text outside containers;
- untranslated keys;
- stale Week/Day terminology visible as active gameplay;
- inconsistent button labels;
- modal layering;
- inaccessible back navigation;
- hidden required buttons at 1600×900 and 1920×1080;
- bad focus/scroll behavior;
- duplicated history entries;
- stale HUD resources after actions;
- placeholder art that blocks readability or clicking.

Placeholder visual quality by itself is not a programming blocker.

## Point 3 completion criteria

Point 3 may be marked CLOSED only when:

- a human has completed the representative management loop;
- Save v14 continuity has been exercised from the UI;
- GT I XIII, XVI and XX have each been completed interactively;
- the completed demo save has been reloaded;
- no unresolved P0/P1 exists;
- any P2 affecting the required demo path has been fixed and revalidated;
- CI is green after any code fixes generated by this playtest.

Until those conditions are met, Point 3 remains IN PROGRESS.
