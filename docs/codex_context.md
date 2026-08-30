
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
