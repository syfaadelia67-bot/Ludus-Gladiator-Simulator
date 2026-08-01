# Headless tests

The project tests rely on autoloads from `project.godot`. Run each test through
the project's main scene, rather than with Godot's `--script` flag, so those
autoloads and the real UI scene context are available:

```powershell
godot --headless --path game -- --test=res://tests/demo_readiness_integration_test.gd
```

`TestRunner` runs tests as `Node` instances. Legacy `SceneTree` tests were
migrated mechanically to `Node` so they can execute with the project's real
autoloads. Node tests can expose a `run()` or `_ready()` method. Each test runs
in its own Godot process to keep global state
and `get_tree().quit()` calls isolated.
