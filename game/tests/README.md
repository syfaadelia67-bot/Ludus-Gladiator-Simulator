# Headless tests

The project tests rely on autoloads from `project.godot`. Run them through the
project's main scene, rather than with Godot's `--script` flag, so the real
autoload and UI context is available.

## Single test

```powershell
godot --headless --path game -- --test=res://tests/demo_readiness_integration_test.gd
```

## Complete suite

```powershell
godot --headless --path game -- --test=res://tests/...
```

Suite mode discovers every `*_test.gd` file directly inside `res://tests`, sorts
the paths, and launches one isolated Godot process for each test. This prevents
global autoload state, saved temporary data, signals, or `get_tree().quit()` calls
from leaking between tests.

`TestRunner` stays inactive during normal startup when no `--test=` argument is
present. Test scripts must extend `Node` and may expose either a `run()` method or
perform their assertions from `_ready()`.
