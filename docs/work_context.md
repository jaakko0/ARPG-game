
# Current work context

Project Shattered World is a playable Godot 4, GDScript, 2D top-down ARPG
prototype. Android portrait is the primary target; keyboard/mouse remain supported
for desktop testing.

## Implemented

- player movement, collision and camera
- Health/damage, enemy contact attacks and player death/reset
- nearest-target automatic melee attack
- Fireball input, cooldown, projectile collision and damage
- gold/equipment loot pickups
- XP, levels, STR/DEX/INT/VIT and attribute allocation
- inventory, equipment replacement and derived attribute effects
- JSON save/load for level, XP, gold, attributes, inventory and equipment
- debug combat feedback and a Character menu
- virtual joystick and mobile Fireball button
- Basic, Fast, Heavy, Elite Brute and Ranged Cultist enemies

## Architecture checkpoint A

- `scenes/base_enemy.tscn` contains shared enemy collision, Health, LootDropper,
  CombatFeedback and labels.
- Every current enemy scene inherits the base and preserves its previous stats.
- Heavy and Elite add `AreaAttack`; Ranged Cultist adds `RangedAttack` and keeps
  its ranged movement script.
- `data/item_catalog.tres` is the one current equipment catalog and default drop
  source. Owned items remain stable definition IDs; there is no ItemInstance yet.
- `tests/run_smoke_tests.gd` is the tracked regression entry point.

## Working rules

Keep milestones small, preserve accepted gameplay, validate headlessly and then
perform manual Godot testing. Do not commit or push unless the creator explicitly
requests it. GitHub/canonical repository files are the source of truth.
