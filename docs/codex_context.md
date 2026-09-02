
# Codex architecture context

Read the repository before editing and implement only the requested milestone.
This is a solo-developed, beginner-friendly Godot project: prefer readable scripts,
small Resources/components and explicit scene composition over large frameworks.

## Current boundaries

- `scripts/health.gd` is the reusable health and raw damage endpoint.
- `scripts/player.gd` owns CharacterBody movement/facing and currently coordinates
  combat, progression and menus. Avoid adding unrelated new systems to it; extract
  a focused component only when a concrete feature requires one.
- `scripts/equipment_item_data.gd` defines static equipment using stable IDs.
- `scripts/item_catalog.gd` validates and resolves those IDs. The shared resource
  is `data/item_catalog.tres`.
- `scenes/base_enemy.tscn` is the common enemy structure. New ordinary variants
  should inherit it and override only changed values/nodes.
- `scripts/area_attack.gd` and `scripts/ranged_attack.gd` are intentionally separate
  behaviours. Do not merge them without proven shared requirements.
- Keyboard and mobile UI must call the same gameplay methods. Autoattack remains
  automatic and has no attack button.
- Save format version is currently 1. Inventory/equipment saves use item IDs;
  unknown IDs must remain safe.
- `scripts/save_coordinator.gd` owns current payload gathering, validation and
  section application. Add future saved subsystems there instead of rebuilding a
  large save dictionary in `player.gd`.
- `scripts/save_system.gd` owns persistence, JSON and top-level version dispatch.
  It writes through a `.tmp` file and keeps one `.bak`; it must not control gameplay.

## Save version changes

Do not increment the save version unless the schema actually becomes incompatible.
For a future v1 -> v2 change:

1. increment `CURRENT_SAVE_VERSION` in `save_system.gd`
2. add a real version-1 migration case in `_dispatch_save_version`
3. migrate a duplicated dictionary rather than active gameplay state
4. validate the migrated current data in SaveCoordinator before applying it
5. add old-version fixtures to the tracked regression suite

Version 1 currently requires no migration and remains unchanged.

## Validation

Run:

```powershell
godot --headless --path . --script res://tests/run_smoke_tests.gd
```

Also launch `scenes/main.tscn` and manually test movement, combat, drops,
inventory/equipment, Character menu, save/load and mobile controls. Run
`git diff --check` before reporting completion.

## Not implemented

HitData/DamageContext, ItemInstance, rarity/affixes, generic skill slots, damage
types, crits, status effects, boss framework, AI state machines and object pooling
are future work. Do not describe them as current systems.
