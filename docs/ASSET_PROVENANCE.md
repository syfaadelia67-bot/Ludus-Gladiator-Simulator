# Asset provenance and licensing policy

This repository is public. Every asset committed here must be safe to redistribute from a public source repository, not merely safe to use inside a compiled commercial game.

## Core rule

Do not commit an external asset unless all of the following are known:

1. Source and author/provider.
2. License or commercial-use terms.
3. Whether modification is allowed.
4. Whether attribution is required.
5. Whether raw/source-file redistribution is allowed.
6. Whether the asset may be uploaded to or reused by generative-AI tools.

If any answer is unknown, the asset does not enter the repository until reviewed.

## Repository locations

- `game/assets/`: runtime-ready assets that are safe to redistribute from this public repository. Prefer compact formats such as PNG/WebP/OGG.
- `source_assets/`: editable masters that we own or are explicitly allowed to redistribute. This directory is tracked by Git LFS.
- `private_assets/`: local-only restricted or paid source material. Gitignored. Never referenced directly by game code.
- `licensed_assets_raw/`: local-only vendor packs/archives whose raw redistribution is not explicitly allowed. Gitignored. Never referenced directly by game code.

Do not commit vendor ZIP/RAR/7z archives to the public repository.

## License intake rules

### Approved by default after provenance is recorded

- Original assets created for Ludus.
- CC0/public-domain assets.
- Permissive assets that explicitly allow commercial use and public redistribution, with attribution supplied when required.

### Review required

- CC BY assets: attribution is mandatory.
- Share-alike/copyleft asset licenses: review the exact obligations before use.
- Marketplace/paid assets: most licenses allow use in a game but do not allow redistributing the raw files in a public source repository.
- AI-generated assets: record provider/model or product, generation date/batch, and the commercial-use terms that applied at that time.

### Reject unless requirements change

- Non-commercial-only licenses (for example CC BY-NC) for final commercial game content.
- Assets with unknown authorship or unclear license.
- Ripped/extracted assets from another game.
- Assets whose license forbids the intended commercial use.

## Public-repository rule for paid assets

A paid asset may be legally usable in the shipped game while still being illegal to expose as a raw file on GitHub. If Ludus begins relying on paid/restricted art or audio that cannot be publicly redistributed, choose one of these before committing it:

1. Keep the restricted sources outside this repository and use only outputs whose redistribution is expressly permitted; or
2. move the asset-bearing repository/pipeline to private storage before integration.

Do not assume that buying an asset grants source-redistribution rights.

## AI reuse rule

A license that permits use in the game does not automatically permit uploading the asset to an AI service for training, style transfer, generation, or variation. Record this separately. If the terms prohibit AI/ML reuse, the asset must never be sent to Scenario, Leonardo, another generator, or a training pipeline.

## Provenance ledger

Record third-party packs, sources, and AI-generation batches here before merge. One row may cover a coherent pack/batch when the same license and source apply to all contained files.

| Asset group / path | Source / provider | Author | License / terms | Commercial use | Raw public redistribution | Attribution | AI reuse allowed | Modified | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| _Example: placeholder UI pack_ | _source URL_ | _author_ | _CC0_ | Yes | Yes | No | Verify | Yes | _remove/replace before final if needed_ |

## Release gate

Before a public demo or release:

- every third-party asset shipped by the game must have provenance recorded;
- all required credits/attributions must appear in the final notices/credits;
- no file from `private_assets/` or `licensed_assets_raw/` may be tracked;
- no restricted vendor archive may be present in repository history for the release branch;
- generated assets must have a documented commercial-use basis;
- assets marked as not allowed for AI reuse must not have been used as generative inputs.

This document is a production-control policy, not legal advice. When license wording is ambiguous, do not use the asset until the rights are clear.
