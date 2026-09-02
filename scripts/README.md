
# Script map

- `player.gd`: movement/facing plus current player-level coordination.
- `health.gd`: shared max/current health, damage, healing and depletion signals.
- `enemy.gd`: shared chase, contact attack, death, loot and XP behaviour.
- `ranged_enemy.gd`: ranged distance management on top of `enemy.gd`.
- `area_attack.gd` / `ranged_attack.gd`: separate reusable special attacks.
- `fireball_skill.gd` / projectile scripts: Fireball runtime and projectile path.
- `lightning_arc_skill.gd`: immediate nearest-target hit, one chain target and
  lightweight line feedback for the second active skill.
- `experience.gd` / `attributes.gd`: progression and allocated attributes.
- `equipment_item_data.gd`: static Resource definition for equipment.
- `item_catalog.gd`: stable-ID lookup, duplicate validation and default drop pool.
- `inventory.gd` / `equipment.gd`: owned definition IDs and equipped definitions.
- `loot_dropper.gd`: gold plus catalog-backed equipment spawning.
- panel/menu/mobile scripts: prototype presentation and input adapters.
- `save_coordinator.gd`: current save payload gathering, validation and component
  restoration without storing duplicate gameplay state.
- `save_system.gd`: JSON/file persistence, top-level version dispatch and safe
  temporary-file replacement with one backup.

Gameplay state belongs in components rather than UI scripts. Keyboard and mobile
input request generic player skill slots; each assigned skill runtime owns its
activation rules, cooldown and effect spawning.
