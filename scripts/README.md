
# Script map

- `player.gd`: movement/facing plus current player-level coordination.
- `health.gd`: shared max/current health, damage, healing and depletion signals.
- `enemy.gd`: shared chase, contact attack, death, loot and XP behaviour.
- `ranged_enemy.gd`: ranged distance management on top of `enemy.gd`.
- `area_attack.gd` / `ranged_attack.gd`: separate reusable special attacks.
- `fireball_skill.gd` / projectile scripts: current active skill/projectile paths.
- `experience.gd` / `attributes.gd`: progression and allocated attributes.
- `equipment_item_data.gd`: static Resource definition for equipment.
- `item_catalog.gd`: stable-ID lookup, duplicate validation and default drop pool.
- `inventory.gd` / `equipment.gd`: owned definition IDs and equipped definitions.
- `loot_dropper.gd`: gold plus catalog-backed equipment spawning.
- panel/menu/mobile scripts: prototype presentation and input adapters.
- `save_system.gd`: versioned JSON file access and schema validation.

Gameplay state belongs in components rather than UI scripts. Input adapters should
call existing gameplay methods rather than duplicate gameplay logic.
