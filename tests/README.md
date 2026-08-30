# Smoke/regression suite

Run the tracked suite from the repository root with Godot 4:

```powershell
godot --headless --path . --script res://tests/run_smoke_tests.gd
```

If `godot` is not on PATH, replace it with the full path to the Godot executable.
The command exits with code `0` when all checks pass and code `1` when any check
fails. It uses a dedicated temporary `user://architecture_cleanup_smoke_test.json`
save and removes that file after the run.

The suite is intentionally lightweight. It verifies scene loading, core component
contracts, enemy variants, combat paths, progression, the shared item catalog,
inventory/equipment replacement, save compatibility, Character menu flow and
mobile-control wiring. Manual gameplay testing is still required for feel, touch
accuracy and visual presentation.
