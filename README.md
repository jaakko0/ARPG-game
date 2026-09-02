# Project Shattered World

A pixel-art mobile ARPG focused on build experimentation, exploration, meaningful progression and hidden secrets.

## Vision

Create the kind of game I would personally want to play for hundreds of hours.

The game combines:

- Zelda-style movement and combat
- Diablo-style loot and progression
- Pixel-art exploration inspired by classic RPGs
- A world full of secrets, mysteries and discoveries

## Core Pillars

### 1. Build Experimentation

Players should constantly discover new ways to play.

- Large skill trees
- Build-changing Legendary items
- Hybrid specializations
- Multiple progression systems

### 2. Exploration

The world should reward curiosity.

- Hidden dungeons
- Secret bosses
- Rare skills
- Hidden Legendary items
- Rumors and mysteries

### 3. Respect The Player's Time

Every session should provide progress.

Whether the player has:

- 5 minutes
- 30 minutes
- 6 hours

They should always feel they moved forward.

## Never Do These

- Daily quests
- Weekly quests
- Energy systems
- Mandatory login rewards
- Pay-to-win mechanics
- Full enemy immunities
- Excessive inventory management
- Forced waiting timers

## Current Status

Playable Godot 4 prototype for an Android-first portrait ARPG. The current test
arena supports:

- keyboard and virtual-joystick movement with a following camera
- shared Health and damage handling, enemy contact damage and player respawn
- automatic melee attacks and the manually activated Fireball skill
- gold and equipment drops, inventory, equipment and a Character menu
- XP, levels, attribute allocation and equipment-derived attribute bonuses
- versioned JSON save/load for current player progression
- player critical hits and combat feedback, including damage numbers and hit reactions
- Basic, Fast, Heavy, Elite Brute and Ranged Cultist enemies
- reusable AreaAttack and RangedAttack behaviours

The visuals and UI are still prototype placeholders. Future game-design concepts
in the GDD are not implemented unless they are listed above.

## Technology

- Godot 4
- GDScript
- GitHub
- ChatGPT
- Codex

## Repository Structure

/docs     - Design documents
/art      - Graphics and visual assets
/audio    - Music and sound effects
/scenes   - Godot scenes
/scripts  - Gameplay code
/data     - Items, skills and game data
/tests    - Lightweight tracked smoke/regression suite

## Current Architecture

- `HitData` carries each hit's amount, source, direction, damage type, tags and
  critical flag. `Health` is the single authoritative place that subtracts HP.
- The player's small `HitFactory` owns the configurable prototype critical chance
  and multiplier; enemy hits currently remain non-critical.
- Static equipment definitions are Godot Resources with stable item IDs.
- `data/item_catalog.tres` is the authoritative prototype item catalog and
  default equipment drop pool.
- `scenes/base_enemy.tscn` owns the common enemy nodes. Current enemy scenes
  inherit it and override only variant data or add a special attack.
- `AreaAttack` and `RangedAttack` remain separate reusable behaviours.
- Keyboard and mobile controls call the same player gameplay methods.
- `SaveCoordinator` gathers, validates and restores gameplay state from its owning
  components. `SaveSystem` handles JSON, versioning and safe file replacement.
- New systems should be kept in focused components instead of adding unrelated
  responsibilities to `player.gd`.

## Validation

Run the tracked smoke/regression suite from the repository root:

```powershell
godot --headless --path . --script res://tests/run_smoke_tests.gd
```

Manual testing in Godot is still required for gameplay feel and touch controls.
