# Steam and crash-monitoring integration decision

Status: frozen pre-implementation decision for Ludus Gladiator Simulator.

Godot remains frozen at **4.5.2**. Save schema remains **v14**.

## GodotSteam — ADOPT LATER, ISOLATED PROBE REQUIRED

GodotSteam is the preferred Steamworks integration path for Ludus, but it should not be installed during the current design/data migration phase.

### Why adopt

Ludus plans a Steam demo and later full Steam release. We will need a maintained Steamworks bridge for initialization, overlay, achievements/statistics later, and other Steam platform functions if/when used.

The preferred integration form is **GodotSteam GDExtension**, not a custom Godot module build.

Reasons:

- preserves stock Godot 4.5.2 editor/export templates;
- keeps Steam integration separable from gameplay logic;
- easier to disable or isolate in non-Steam/dev builds;
- avoids maintaining a custom engine fork.

### Repository/source note

The historical GitHub GodotSteam repository was archived in 2026 because the project moved its active source/release workflow to Codeberg. Do not interpret GitHub archival as project abandonment.

### Version policy

Do not install `latest` blindly.

Before adoption:

1. identify the exact GodotSteam GDExtension release claimed to support the frozen Godot 4.5.x line;
2. pin the exact release/version and artifact checksum;
3. run an isolated compatibility probe against **Godot 4.5.2**;
4. validate editor import, headless startup, Windows export and Steam initialization;
5. confirm the normal non-Steam/headless test suite remains runnable without Steam client availability;
6. keep Steam state out of Save v14 unless a future explicit migration requires otherwise.

Existing 4.5-era releases are useful candidates, but compatibility with 4.5.1 must not be assumed identical to 4.5.2 without the probe.

### Demo build rule

The Steam demo should use its own Steam App ID and its own export preset/feature identity. Avoid a manually flippable global `IS_DEMO` switch where possible; derive demo/full behavior from the build/export configuration so a developer cannot accidentally ship the wrong mode.

Achievements remain disabled for the current demo design.

### Timing

Integrate GodotSteam only when:

- Steamworks partner configuration/App IDs are ready;
- the monthly design migration is stable;
- the demo export pipeline exists;
- CI can add a Steam-specific smoke/export job without destabilizing the normal headless suite.

Until then, Steam-specific calls stay behind a small platform adapter/interface and do not leak through core systems.

## Sentry for Godot — APPROVE FOR QA/DEMO, PRIVACY-MINIMAL CONFIGURATION

Sentry now has a first-party Godot SDK and is useful for discovering crashes and runtime errors that only occur on players' machines. That is valuable for a solo-developed Steam demo.

Do **not** integrate it during the current migration work. Add it shortly before external QA/demo distribution, after an isolated compatibility check against Godot 4.5.2.

### What Ludus should collect

Allowed by default:

- crash/error type and stack trace;
- Ludus build/release identifier;
- Godot version;
- OS/platform and coarse hardware/GPU information needed for debugging;
- current screen/system tag using a non-personal enum, e.g. `arena`, `market`, `campaign`;
- deterministic combat/campaign seed only when it contains no user information;
- safe internal subsystem/version tags.

### What Ludus should NOT collect by default

- player name or Steam display name;
- Steam ID or other account identifier;
- email/address/contact data;
- save-file contents;
- free-form player text;
- screenshots;
- scene-tree dumps;
- local variables;
- full logs if they may contain save data, filesystem usernames, tokens or personal paths;
- arbitrary attachments.

Screenshots, scene-tree context, source/local variables and attachments are powerful debugging features but are opt-in/high-risk for privacy. They remain disabled unless a specific debugging need is reviewed.

### Privacy and security rules

- never commit a private Sentry auth token;
- treat the DSN as configuration, not as a privileged server secret, but still keep environment/config separation clean;
- configure event filtering/redaction before public distribution;
- do not set a user identity unless an explicit product/privacy decision is made later;
- avoid `send_default_pii`/equivalent PII collection;
- sample/noise-control repetitive non-actionable errors to avoid exhausting quotas;
- document telemetry/crash reporting appropriately for the shipped product and applicable storefront/privacy requirements.

### Operational rule

Sentry is an error/crash monitor, not gameplay analytics. Ludus will not use it to profile player behavior, monetization or engagement.

A useful event should answer:

> What failed, in which Ludus build/system, on what technical environment, and can we reproduce it?

It should not answer:

> Who is this player and what have they been doing personally?

### Timing

Recommended sequence:

1. finish frozen-design migration;
2. restore intentional green baseline for updated tests;
3. create Steam/demo export pipeline;
4. run isolated GodotSteam probe/integration;
5. run isolated Sentry SDK probe;
6. enable privacy-minimal Sentry for external QA/demo;
7. validate one intentional test error/crash reaches the dashboard;
8. verify normal offline play continues if Sentry network access fails.

## Final decision

- **GodotSteam:** yes, required later for Steam; GDExtension; exact version/checksum pinned; isolated 4.5.2 probe first.
- **Sentry:** yes, shortly before public QA/demo; first-party SDK; privacy-minimal/error-only configuration; isolated 4.5.2 probe first.
- **Neither tool owns gameplay state, save schema, combat rules, economy or campaign logic.**
