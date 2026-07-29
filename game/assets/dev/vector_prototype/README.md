# Vector gladiator prototype

This directory contains generated development-only assets for the Scalable Vector
Shapes 2D evaluation.

- `vector_gladiator_idle.png`: 13-frame idle spritesheet baked at 8 FPS with the
  plugin's `SVSSceneExporter` on Godot 4.5.2.
- Source scene: `res://scenes/dev/VectorGladiatorPrototype.tscn`.
- Playback scene: `res://scenes/dev/VectorGladiatorBaked.tscn`.

The committed spritesheet is reproducible with:

```text
godot45 --path game --script res://scripts/dev/bake_vector_gladiator.gd
```

The exporter requires a graphical rendering context. In headless mode it waits for
`RenderingServer.frame_post_draw` and does not complete.

## Evaluation record

- Plugin: Scalable Vector Shapes 2D 2.27.3, MIT, fixed upstream commit
  `c8b1ccf2b7ee2f77aa69a7dcfd38e716ebceb44e`.
- Godot: 4.5.2 stable, Compatibility renderer.
- Installation: the published add-on was copied to
  `res://addons/scalable_vector_shapes_2d/`; its original absolute add-on paths
  were mechanically updated to that required directory.
- Compatibility adjustment: recursive `ScalableVectorShape2D` type annotations
  were relaxed without changing geometry behavior. This removes an upstream
  script-resource leak at process exit on Godot 4.5.2.
- Vector scene: 43 nodes, including 11 independently pivoted vector shape nodes.
- Baked scene: 7 nodes; one `Sprite2D` plus one `AnimationPlayer` replaces the
  vector hierarchy for playback.
- Spritesheet: 13 frames, 10,530 × 543 px, 44,442 bytes at generation time.
- Import timing: the full editor startup plus first spritesheet import completed
  in about 8.4 seconds. Import time was not isolated, so no more precise figure
  is claimed.
- Visible comparison: the baked idle preserves silhouette and flat colors. It
  quantizes motion to 8 FPS and no longer permits per-part recoloring or equipment
  replacement without rebaking.
- Equipment reuse: vector sword and shield are independent subtrees and can be
  swapped or recolored directly. The baked version requires a new sheet for each
  equipment combination.

## Performance observation

One three-second graphical sample per count was captured on an AMD Radeon 760M
using Godot's built-in monitors:

| Animated instances | Average FPS | Average frame time | Draw calls |
| ---: | ---: | ---: | ---: |
| 1 | 57.00 | 17.545 ms | 22 |
| 10 | 59.94 | 16.684 ms | 220 |
| 25 | 59.38 | 16.841 ms | 550 |
| 50 | 58.21 | 17.179 ms | 1100 |

The run showed no render errors or visible degradation. CPU utilization was not
reported because the built-in sample did not provide a reliable per-process CPU
percentage. Draw calls scale linearly, so larger crowds should use baked sprites
or another batching strategy.
