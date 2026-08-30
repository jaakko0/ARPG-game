
# Scene map

- `main.tscn`: current gameplay entry point.
- `test_world.tscn`: portrait prototype arena and solid obstacles.
- `player.tscn`: player components, camera and prototype HUD.
- `base_enemy.tscn`: shared enemy root, collision, Health, LootDropper,
  CombatFeedback, HP label and type label.
- `enemy.tscn`, `fast_enemy.tscn`, `heavy_enemy.tscn`, `elite_brute.tscn` and
  `ranged_enemy.tscn`: inherited enemy variants.
- Heavy and Elite add AreaAttack nodes. Ranged Cultist adds RangedAttack and uses
  `ranged_enemy.gd`.
- pickup/projectile scenes: small reusable runtime objects.
- Character menu, inventory, equipment and attribute scenes: prototype UI panels.

When adding a normal enemy variant, inherit `base_enemy.tscn`, preserve the common
node names expected by `enemy.gd`, and override only variant-specific settings.
