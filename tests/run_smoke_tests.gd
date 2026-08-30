extends SceneTree

const BASE_ENEMY_SCENE_PATH := "res://scenes/base_enemy.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const ITEM_CATALOG_PATH := "res://data/item_catalog.tres"
const TEST_SAVE_PATH := "user://architecture_cleanup_smoke_test.json"

const ItemCatalogScript = preload("res://scripts/item_catalog.gd")
const GoldPickupScript = preload("res://scripts/gold_pickup.gd")
const EquipmentPickupScript = preload("res://scripts/equipment_pickup.gd")
const FireballProjectileScript = preload("res://scripts/fireball_projectile.gd")
const EnemyProjectileScript = preload("res://scripts/enemy_projectile.gd")

const EXPECTED_ITEM_IDS: Array[StringName] = [
	&"training_sword",
	&"practice_blade",
	&"apprentice_hood",
	&"sturdy_vest",
]

const ENEMY_CASES := [
	{
		"label": "Basic",
		"path": "res://scenes/enemy.tscn",
		"health": 30,
		"move_speed": 120.0,
		"contact_damage": 10,
		"experience_reward": 10,
	},
	{
		"label": "Fast",
		"path": "res://scenes/fast_enemy.tscn",
		"health": 18,
		"move_speed": 210.0,
		"contact_damage": 7,
		"experience_reward": 8,
	},
	{
		"label": "Heavy",
		"path": "res://scenes/heavy_enemy.tscn",
		"health": 80,
		"move_speed": 70.0,
		"contact_damage": 8,
		"experience_reward": 20,
	},
	{
		"label": "Elite",
		"path": "res://scenes/elite_brute.tscn",
		"health": 150,
		"move_speed": 85.0,
		"contact_damage": 14,
		"experience_reward": 50,
	},
	{
		"label": "Ranged",
		"path": "res://scenes/ranged_enemy.tscn",
		"health": 40,
		"move_speed": 115.0,
		"contact_damage": 6,
		"experience_reward": 12,
	},
]

var checks_run: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	print("\n=== Project Shattered World smoke/regression suite ===")
	await _test_main_scene_loads()

	var sandbox := Node2D.new()
	sandbox.name = "SmokeTestSandbox"
	root.add_child(sandbox)
	current_scene = sandbox

	var player := await _test_player_and_ui(sandbox)
	var enemies := await _test_enemy_variants(sandbox)

	if player != null and not enemies.is_empty():
		await _test_combat_and_rewards(sandbox, player, enemies)
		_test_progression(player)
		_test_item_catalog_and_equipment(player, enemies)
		_test_save_compatibility(player)

	_cleanup_test_save()
	current_scene = null
	sandbox.queue_free()
	await process_frame

	if failures == 0:
		print("=== PASS: %d checks completed ===\n" % checks_run)
		quit(0)
	else:
		printerr("=== FAIL: %d of %d checks failed ===\n" % [failures, checks_run])
		quit(1)


func _test_main_scene_loads() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "Main scene resource loads")

	if main_scene == null:
		return

	var main := main_scene.instantiate()
	_check(main != null, "Main scene instantiates")

	if main == null:
		return

	root.add_child(main)
	current_scene = main
	await process_frame
	await physics_frame
	_check(main.get_node_or_null("Player") != null, "Main scene contains Player")
	_check(main.get_node_or_null("TestWorld") != null, "Main scene contains test world")
	_check(get_nodes_in_group("enemy").size() >= 5, "Main scene contains enemy variants")
	current_scene = null
	main.queue_free()
	await process_frame


func _test_player_and_ui(sandbox: Node2D) -> CharacterBody2D:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	_check(player_scene != null, "Player scene loads")

	if player_scene == null:
		return null

	var player := player_scene.instantiate() as CharacterBody2D
	_check(player != null, "Player scene instantiates as CharacterBody2D")

	if player == null:
		return null

	sandbox.add_child(player)
	player.global_position = Vector2(200.0, 200.0)
	await process_frame
	player.set_physics_process(false)

	var player_components_exist := true

	for component_path in ["Health", "Experience", "Attributes", "Equipment", "Inventory", "SaveSystem"]:
		if player.get_node_or_null(component_path) == null:
			player_components_exist = false

	_check(player_components_exist, "Player contains all core progression components")

	_check(player.has_method("try_autoattack"), "Player autoattack path exists")
	_check(player.has_method("try_fireball"), "Player Fireball path exists")
	_check(player.has_method("get_movement_input"), "Player movement input path exists")
	_check(InputMap.has_action("move_left") and InputMap.has_action("move_right"), "Movement input actions exist")
	_check(InputMap.has_action("fireball"), "Fireball input action exists")

	var starting_position: Vector2 = player.global_position
	player.call("_on_mobile_movement_changed", Vector2.RIGHT)
	player.call("_physics_process", 0.1)
	_check(player.global_position.x > starting_position.x, "Mobile movement feeds CharacterBody2D movement")
	player.call("_on_mobile_movement_changed", Vector2.ZERO)

	var fireballs_before := _count_nodes_with_script(sandbox, FireballProjectileScript)
	player.set("facing_direction", Vector2.RIGHT)
	player.get_node("FireballSkill").set("cooldown_remaining", 0.0)
	_check(player.call("try_fireball"), "Fireball activation succeeds")
	_check(
		_count_nodes_with_script(sandbox, FireballProjectileScript) == fireballs_before + 1,
		"Fireball activation creates the projectile"
	)

	for child in sandbox.get_children():
		if child.get_script() == FireballProjectileScript:
			child.queue_free()

	var hud := player.get_node_or_null("HUD")
	var mobile_controls := player.get_node_or_null("HUD/MobileControls")
	_check(hud is CanvasLayer, "Player HUD stays on a CanvasLayer")
	_check(mobile_controls != null, "Mobile controls are reachable")
	_check(mobile_controls.has_signal("movement_changed"), "Mobile joystick signal exists")
	_check(mobile_controls.has_signal("fireball_requested"), "Mobile Fireball signal exists")
	_check(
		mobile_controls.is_connected(
			"fireball_requested",
			Callable(player, "_on_mobile_fireball_requested")
		),
		"Mobile Fireball button uses the player Fireball path"
	)

	var character_panels_exist := true

	for panel_path in [
		"HUD/CharacterMenu",
		"HUD/AttributePanel",
		"HUD/EquipmentPanel",
		"HUD/InventoryPanel",
	]:
		if player.get_node_or_null(panel_path) == null:
			character_panels_exist = false

	_check(character_panels_exist, "Character menu and all management panels are reachable")

	player.call("open_character_management")
	_check(paused, "Character menu pauses gameplay")
	_check(player.call("show_character_section", &"inventory"), "Inventory opens from Character menu flow")
	_check(player.get_node("HUD/InventoryPanel").visible, "Inventory panel becomes visible")
	player.call("close_character_management")
	_check(not paused, "Closing Character menu resumes gameplay")
	await process_frame

	return player


func _test_enemy_variants(sandbox: Node2D) -> Array[CharacterBody2D]:
	var enemies: Array[CharacterBody2D] = []
	var item_catalog := load(ITEM_CATALOG_PATH)

	for case in ENEMY_CASES:
		var scene_path: String = case["path"]
		var scene := load(scene_path) as PackedScene
		_check(scene != null, "%s enemy scene loads" % case["label"])

		if scene == null:
			continue

		var uses_base_scene := false

		for dependency in ResourceLoader.get_dependencies(scene_path):
			if String(dependency).begins_with(BASE_ENEMY_SCENE_PATH):
				uses_base_scene = true
				break

		_check(uses_base_scene, "%s enemy reuses base_enemy.tscn" % case["label"])

		var enemy := scene.instantiate() as CharacterBody2D
		_check(enemy != null, "%s enemy instantiates" % case["label"])

		if enemy == null:
			continue

		sandbox.add_child(enemy)
		enemy.global_position = Vector2(1200.0 + enemies.size() * 180.0, 1200.0)
		enemy.set_physics_process(false)
		enemies.append(enemy)

		var common_nodes_exist := true

		for node_path in ["CollisionShape2D", "Health", "LootDropper", "CombatFeedback", "HealthLabel", "TypeLabel"]:
			if enemy.get_node_or_null(node_path) == null:
				common_nodes_exist = false

		_check(common_nodes_exist, "%s enemy inherits all shared nodes" % case["label"])

		var health := enemy.get_node("Health")
		var feedback := enemy.get_node("CombatFeedback")
		var loot_dropper := enemy.get_node("LootDropper")
		_check(enemy.is_in_group("enemy"), "%s remains in enemy group" % case["label"])
		_check(
			health.get("max_health") == case["health"]
			and is_equal_approx(enemy.get("move_speed"), case["move_speed"])
			and enemy.get("contact_damage") == case["contact_damage"]
			and enemy.get("experience_reward") == case["experience_reward"],
			"%s core balance values are preserved" % case["label"]
		)
		_check(
			health.is_connected("damage_taken", Callable(feedback, "show_damage")),
			"%s damage feedback connection is preserved" % case["label"]
		)
		_check(loot_dropper.get("item_catalog") == item_catalog, "%s uses the shared ItemCatalog" % case["label"])

	var heavy := _find_enemy_by_name(enemies, "HeavyEnemy")
	var elite := _find_enemy_by_name(enemies, "EliteBrute")
	var ranged := _find_enemy_by_name(enemies, "RangedCultist")
	_check(heavy != null and heavy.get_node_or_null("AreaAttack") != null, "Heavy retains AreaAttack")
	_check(elite != null and elite.get_node_or_null("AreaAttack") != null, "Elite retains Ground Slam AreaAttack")
	_check(elite != null and elite.is_in_group("elite"), "Elite rank group is preserved")
	_check(ranged != null and ranged.get_node_or_null("RangedAttack") != null, "Ranged enemy retains RangedAttack")
	_check(ranged != null and ranged.is_in_group("ranged_enemy"), "Ranged enemy group is preserved")

	if heavy != null:
		_check(heavy.get_node("AreaAttack").has_method("update_attack"), "Heavy attack behaviour is callable")

	if elite != null:
		_check(elite.get_node("AreaAttack").get("ability_name") == "Ground Slam", "Elite Ground Slam settings are preserved")

	if ranged != null:
		var ranged_attack := ranged.get_node("RangedAttack")
		_check(ranged_attack.get("projectile_scene") != null, "Ranged projectile scene is configured")
		var projectile := ranged_attack.call("fire_projectile", get_first_node_in_group("player")) as CharacterBody2D
		_check(projectile != null, "RangedAttack creates an enemy projectile")

		if projectile != null:
			_check(projectile.get_script() == EnemyProjectileScript, "RangedAttack uses the enemy projectile path")
			projectile.queue_free()

	return enemies


func _test_combat_and_rewards(
	sandbox: Node2D,
	player: CharacterBody2D,
	enemies: Array[CharacterBody2D]
) -> void:
	var basic := _find_enemy_by_name(enemies, "Enemy")
	var heavy := _find_enemy_by_name(enemies, "HeavyEnemy")

	if basic == null or heavy == null:
		_check(false, "Basic and Heavy enemies are available for combat regression")
		return

	basic.global_position = player.global_position + Vector2(100.0, 0.0)
	var basic_health := basic.get_node("Health")
	var health_before: int = basic_health.get("current_health")
	player.set("attack_cooldown_remaining", 0.0)
	player.call("try_autoattack")
	_check(
		basic_health.get("current_health") == health_before - player.get("attack_damage"),
		"Autoattack damages the nearest enemy through Health"
	)

	# Move the melee target away so it cannot intercept the Fireball collision check.
	basic.global_position = player.global_position + Vector2(500.0, 500.0)
	heavy.global_position = player.global_position + Vector2(130.0, 0.0)
	await physics_frame
	var heavy_health := heavy.get_node("Health")
	var heavy_health_before: int = heavy_health.get("current_health")
	player.get_node("FireballSkill").set("cooldown_remaining", 0.0)
	player.set("facing_direction", Vector2.RIGHT)
	_check(player.call("try_fireball"), "Fireball can be activated for hit regression")
	var fireball := _find_last_node_with_script(sandbox, FireballProjectileScript) as CharacterBody2D
	_check(fireball != null, "Fireball projectile is available for collision regression")

	if fireball != null:
		for step in 8:
			await physics_frame

			if heavy_health.get("current_health") < heavy_health_before:
				break

			if not is_instance_valid(fireball) or fireball.is_queued_for_deletion():
				break

		_check(heavy_health.get("current_health") < heavy_health_before, "Fireball collision damages an enemy")

	var loot_dropper := basic.get_node("LootDropper")
	loot_dropper.set("equipment_drop_chance", 1.0)
	var experience := player.get_node("Experience")
	var experience_before: int = experience.get("current_experience")
	var gold_pickups_before := _count_nodes_with_script(sandbox, GoldPickupScript)
	var equipment_pickups_before := _count_nodes_with_script(sandbox, EquipmentPickupScript)
	basic.call("take_damage", basic_health.get("current_health"))
	basic.call("_on_health_depleted")
	_check(basic.get("death_processed"), "Enemy death is processed")
	_check(
		experience.get("current_experience") == experience_before + basic.get("experience_reward"),
		"Enemy death awards XP exactly once"
	)
	_check(
		_count_nodes_with_script(sandbox, GoldPickupScript) == gold_pickups_before + 1,
		"Enemy death creates one gold pickup"
	)
	_check(
		_count_nodes_with_script(sandbox, EquipmentPickupScript) == equipment_pickups_before + 1,
		"Enemy equipment drop uses the configured drop path"
	)

	var gold_pickup := _find_last_node_with_script(sandbox, GoldPickupScript)
	var gold_before: int = player.get("gold")

	if gold_pickup != null:
		var gold_amount: int = gold_pickup.get("amount")
		gold_pickup.call("_on_body_entered", player)
		_check(player.get("gold") == gold_before + gold_amount, "Gold pickup increases player gold")
	else:
		_check(false, "Gold pickup is available for collection")

	var equipment_pickup := _find_last_node_with_script(sandbox, EquipmentPickupScript)
	var inventory := player.get_node("Inventory")
	var inventory_before: int = inventory.call("get_item_count")

	if equipment_pickup != null:
		equipment_pickup.call("_on_body_entered", player)
		_check(inventory.call("get_item_count") == inventory_before + 1, "Equipment pickup enters inventory")
	else:
		_check(false, "Equipment pickup is available for collection")

	await process_frame


func _test_progression(player: CharacterBody2D) -> void:
	var experience := player.get_node("Experience")
	var attributes := player.get_node("Attributes")
	var level_before: int = experience.get("current_level")
	var points_before: int = attributes.get("unspent_points")
	var experience_needed: int = experience.get("experience_required") - experience.get("current_experience")
	player.call("add_experience", experience_needed)
	_check(experience.get("current_level") == level_before + 1, "XP path increases player level")
	_check(attributes.get("unspent_points") == points_before + 1, "Level-up grants one attribute point")


func _test_item_catalog_and_equipment(
	player: CharacterBody2D,
	enemies: Array[CharacterBody2D]
) -> void:
	var catalog := load(ITEM_CATALOG_PATH)
	_check(catalog != null, "Shared ItemCatalog resource loads")

	if catalog == null:
		return

	_check(catalog.call("is_valid_catalog"), "Shared ItemCatalog validates without errors")
	_check(catalog.call("get_validation_errors").is_empty(), "Shared ItemCatalog has no duplicate IDs")

	var all_item_ids_resolve := true

	for item_id in EXPECTED_ITEM_IDS:
		if catalog.call("get_item_by_id", item_id) == null:
			all_item_ids_resolve = false

	_check(all_item_ids_resolve, "All prototype item IDs resolve")

	_check(catalog.call("get_item_by_id", &"unknown_item") == null, "Unknown item ID returns null safely")
	_check(catalog.call("get_default_equipment_drop_pool").size() == 4, "Default equipment drop pool resolves all prototype items")

	var duplicate_catalog := ItemCatalogScript.new()
	var first_item = catalog.call("get_item_by_id", &"training_sword")
	duplicate_catalog.items.append(first_item)
	duplicate_catalog.items.append(first_item)
	duplicate_catalog.default_equipment_drop_pool.append(first_item)
	_check(not duplicate_catalog.call("get_validation_errors").is_empty(), "Duplicate item IDs are detected safely")
	_check(duplicate_catalog.call("get_item_by_id", &"training_sword") == first_item, "Duplicate handling keeps the first definition")

	var equipment := player.get_node("Equipment")
	var inventory := player.get_node("Inventory")
	var empty_item_ids: Array[StringName] = []
	_check(equipment.get("item_catalog") == catalog, "Equipment uses the shared ItemCatalog")
	inventory.call("restore_item_ids", empty_item_ids)
	equipment.call("restore_equipment", {})
	_check(player.call("collect_equipment_item", catalog.call("get_item_by_id", &"training_sword")), "Training Sword enters inventory")
	_check(player.call("collect_equipment_item", catalog.call("get_item_by_id", &"practice_blade")), "Practice Blade enters inventory")
	_check(player.call("equip_inventory_item", 0), "Inventory item equips")
	_check(equipment.call("get_equipped_item", &"weapon").item_id == &"training_sword", "First weapon is equipped")
	_check(player.call("equip_inventory_item", 0), "Second weapon replaces first")
	_check(equipment.call("get_equipped_item", &"weapon").item_id == &"practice_blade", "Replacement weapon is equipped")
	_check(inventory.call("get_item_count") == 1, "Replaced weapon returns to inventory")
	equipment.call("restore_equipment", {"weapon": "unknown_item"})
	_check(equipment.call("get_equipped_item", &"weapon") == null, "Unknown saved equipment ID is ignored safely")

	var all_enemy_drop_pools_resolve := true

	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			var drop_pool: Array = enemy.get_node("LootDropper").call("get_equipment_drop_pool")

			if drop_pool.size() != 4:
				all_enemy_drop_pools_resolve = false

	_check(all_enemy_drop_pools_resolve, "All living enemy variants resolve the shared default drop pool")


func _test_save_compatibility(player: CharacterBody2D) -> void:
	_cleanup_test_save()
	var save_system := player.get_node("SaveSystem")
	save_system.set("save_path", TEST_SAVE_PATH)
	var old_compatible_data := {
		"level": 1,
		"current_xp": 0,
		"gold": 7,
		"attributes": {
			"strength": 5,
			"dexterity": 5,
			"intelligence": 5,
			"vitality": 5,
			"unspent_points": 0,
		},
	}
	var old_save_result: Dictionary = save_system.call("save_game", old_compatible_data)
	var old_load_result: Dictionary = save_system.call("load_game")
	_check(old_save_result.get("success", false), "Version 1 data without newer optional item fields saves")
	_check(old_load_result.get("success", false), "Version 1 compatibility data loads")

	var inventory := player.get_node("Inventory")
	var equipment := player.get_node("Equipment")
	var full_data: Dictionary = player.call("get_progression_save_data")
	full_data["gold"] = 23
	full_data["inventory"] = ["training_sword"]
	full_data["equipment"] = {"weapon": "practice_blade"}
	var save_result: Dictionary = save_system.call("save_game", full_data)
	var load_result: Dictionary = save_system.call("load_game")
	_check(save_result.get("success", false), "Current progression save succeeds")
	_check(load_result.get("success", false), "Current progression load succeeds")
	_check(player.call("apply_progression_save_data", load_result.get("player_data", {})), "Loaded progression applies")
	_check(player.get("gold") == 23, "Loaded gold is restored")
	_check(inventory.call("get_item_count") == 1, "Loaded inventory is restored")
	_check(equipment.call("get_equipped_item", &"weapon") != null, "Loaded equipment is restored")

	full_data["inventory"] = ["unknown_item"]
	full_data["equipment"] = {"weapon": "unknown_item"}
	_check(player.call("apply_progression_save_data", full_data), "Save data with unknown item IDs remains safe")
	_check(inventory.call("get_item_count") == 0, "Unknown inventory IDs are filtered")
	_check(equipment.call("get_equipped_item", &"weapon") == null, "Unknown equipment IDs are ignored")


func _find_enemy_by_name(enemies: Array[CharacterBody2D], enemy_name: String) -> CharacterBody2D:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.name == enemy_name:
			return enemy

	return null


func _count_nodes_with_script(parent: Node, script: Script) -> int:
	var count := 0

	for child in parent.get_children():
		if child.get_script() == script and not child.is_queued_for_deletion():
			count += 1

	return count


func _find_last_node_with_script(parent: Node, script: Script) -> Node:
	var children := parent.get_children()

	for index in range(children.size() - 1, -1, -1):
		var child := children[index] as Node

		if child.get_script() == script and not child.is_queued_for_deletion():
			return child

	return null


func _cleanup_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEST_SAVE_PATH)

	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, description: String) -> void:
	checks_run += 1

	if condition:
		return
	else:
		failures += 1
		printerr("[FAIL] %s" % description)
