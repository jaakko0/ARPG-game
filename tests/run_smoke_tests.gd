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
		await _test_lightning_arc(sandbox, player, enemies)
		await _test_flame_nova(sandbox, player, enemies)
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

	for component_path in ["Health", "Experience", "Attributes", "Equipment", "Inventory", "SaveSystem", "SaveCoordinator", "AutocastSkillSlots"]:
		if player.get_node_or_null(component_path) == null:
			player_components_exist = false

	_check(player_components_exist, "Player contains all core progression components")

	_check(player.has_method("try_autoattack"), "Player autoattack path exists")
	_check(player.has_method("activate_skill"), "Player generic skill-slot activation exists")
	_check(player.has_method("get_skill_in_slot"), "Player generic skill-slot lookup exists")
	_check(not player.has_method("try_fireball"), "Player has no duplicate Fireball-specific activation method")
	_check(not player.has_method("try_lightning_arc"), "Player has no Lightning-specific activation method")
	_check(not player.has_method("try_flame_nova"), "Player has no Flame-Nova-specific activation method")
	_check(player.has_method("get_movement_input"), "Player movement input path exists")
	_check(player.has_method("save_progression") and player.has_method("load_progression"), "Player save/load command entry points exist")
	_check(not player.has_method("get_progression_save_data"), "Player no longer builds the save payload")
	_check(not player.has_method("apply_progression_save_data"), "Player no longer restores the save payload")
	_check(InputMap.has_action("move_left") and InputMap.has_action("move_right"), "Movement input actions exist")
	_check(InputMap.has_action("skill_slot_1"), "Generic first skill-slot input action exists")
	_check(InputMap.has_action("skill_slot_2"), "Generic second skill-slot input action exists")
	_check(not InputMap.has_action("fireball"), "Legacy Fireball-specific input action is removed")
	_check(not InputMap.has_action("lightning_arc"), "No Lightning-specific input action exists")
	_check(not InputMap.has_action("flame_nova"), "Flame Nova has no manual input action")
	_check(not InputMap.has_action("skill_slot_3"), "No third manual skill-slot action exists")
	_check(InputMap.has_action("save_game") and InputMap.has_action("load_game"), "K/L save and load actions exist")

	var space_uses_first_slot := false

	for input_event in InputMap.action_get_events("skill_slot_1"):
		if input_event is InputEventKey and input_event.physical_keycode == KEY_SPACE:
			space_uses_first_slot = true
			break

	_check(space_uses_first_slot, "Space maps to the generic first skill slot")

	var q_uses_second_slot := false

	for input_event in InputMap.action_get_events("skill_slot_2"):
		if input_event is InputEventKey and input_event.physical_keycode == KEY_Q:
			q_uses_second_slot = true
			break

	_check(q_uses_second_slot, "Q maps to the generic second skill slot")

	var starting_position: Vector2 = player.global_position
	player.call("_on_mobile_movement_changed", Vector2.RIGHT)
	player.call("_physics_process", 0.1)
	_check(player.global_position.x > starting_position.x, "Mobile movement feeds CharacterBody2D movement")
	player.call("_on_mobile_movement_changed", Vector2.ZERO)

	var fireball_skill := player.get_node("FireballSkill")
	var lightning_arc_skill := player.get_node("LightningArcSkill")
	var autocast_skill_slots := player.get_node("AutocastSkillSlots")
	var flame_nova_skill := player.get_node("AutocastSkillSlots/FlameNovaSkill")
	autocast_skill_slots.set_physics_process(false)
	_check(
		player.call("get_skill_in_slot", 0) == fireball_skill,
		"Fireball runtime is assigned to skill slot 0"
	)
	_check(
		player.call("get_skill_in_slot", 1) == lightning_arc_skill,
		"Lightning Arc runtime is assigned to skill slot 1"
	)
	_check(player.call("get_skill_in_slot", 2) == null, "Unassigned skill slots fail safely")
	_check(fireball_skill.has_method("try_activate"), "Assigned Fireball runtime owns activation")
	_check(lightning_arc_skill.has_method("try_activate"), "Assigned Lightning Arc runtime owns activation")
	_check(
		autocast_skill_slots.has_method("update_autocast_skills"),
		"Player owns a reusable passive/autocast update boundary"
	)
	_check(
		autocast_skill_slots.call("get_skill_in_slot", 0) == flame_nova_skill,
		"Flame Nova occupies passive/autocast slot 0"
	)
	_check(
		autocast_skill_slots.call("get_skill_in_slot", 1) == null,
		"Unused passive/autocast slots are empty safely"
	)
	_check(flame_nova_skill.get("damage") == 22, "Flame Nova prototype base damage is configured")
	_check(
		is_equal_approx(flame_nova_skill.get("autocast_interval"), 5.0),
		"Flame Nova prototype autocast interval is configured"
	)

	var original_passive_skill := autocast_skill_slots.call("get_skill_in_slot", 0) as Node
	_check(
		autocast_skill_slots.call("set_skill_in_slot", 0, null)
		and autocast_skill_slots.call("get_skill_in_slot", 0) == null,
		"Passive/autocast slot can be empty safely"
	)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		autocast_skill_slots.call("set_skill_in_slot", 0, original_passive_skill),
		"Prototype passive skill can be equipped again"
	)
	flame_nova_skill.set("time_until_ready", 0.0)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		is_zero_approx(flame_nova_skill.get("time_until_ready")),
		"Ready Flame Nova waits without consuming its timer when no target exists"
	)
	lightning_arc_skill.set("cooldown_remaining", 0.0)
	_check(
		not player.call("activate_skill", 1, Vector2.RIGHT),
		"Lightning Arc safely declines activation with no target"
	)
	_check(
		is_zero_approx(lightning_arc_skill.get("cooldown_remaining")),
		"No-target Lightning Arc does not consume cooldown"
	)

	var fireballs_before := _count_nodes_with_script(sandbox, FireballProjectileScript)
	player.set("facing_direction", Vector2.RIGHT)
	fireball_skill.set("cooldown_remaining", 0.0)
	_check(player.call("activate_skill", 0, Vector2.RIGHT), "Generic slot activation succeeds")
	_check(
		_count_nodes_with_script(sandbox, FireballProjectileScript) == fireballs_before + 1,
		"Generic slot activation creates the Fireball projectile"
	)
	_check(
		not player.call("activate_skill", 0, Vector2.RIGHT),
		"Fireball cooldown still blocks immediate slot reactivation"
	)
	_check(
		_count_nodes_with_script(sandbox, FireballProjectileScript) == fireballs_before + 1,
		"Blocked cooldown activation does not create another projectile"
	)

	for child in sandbox.get_children():
		if child.get_script() == FireballProjectileScript:
			child.queue_free()

	await process_frame
	fireball_skill.set("cooldown_remaining", 0.0)
	fireballs_before = _count_nodes_with_script(sandbox, FireballProjectileScript)
	Input.action_press("skill_slot_1")
	player.call("_physics_process", 0.0)
	Input.action_release("skill_slot_1")
	_check(
		_count_nodes_with_script(sandbox, FireballProjectileScript) == fireballs_before + 1,
		"Space action activates Fireball through skill slot 0"
	)

	for child in sandbox.get_children():
		if child.get_script() == FireballProjectileScript:
			child.queue_free()

	await process_frame

	var hud := player.get_node_or_null("HUD")
	var mobile_controls := player.get_node_or_null("HUD/MobileControls")
	_check(hud is CanvasLayer, "Player HUD stays on a CanvasLayer")
	_check(mobile_controls != null, "Mobile controls are reachable")
	_check(mobile_controls.has_signal("movement_changed"), "Mobile joystick signal exists")
	_check(mobile_controls.has_signal("skill_slot_requested"), "Mobile generic skill-slot signal exists")
	_check(not mobile_controls.has_signal("fireball_requested"), "Mobile controls have no Fireball-specific signal")
	_check(not mobile_controls.has_signal("lightning_arc_requested"), "Mobile controls have no Lightning-specific signal")
	_check(mobile_controls.get_node_or_null("FlameNovaButton") == null, "Flame Nova adds no mobile button")
	_check(
		mobile_controls.is_connected(
			"skill_slot_requested",
			Callable(player, "_on_mobile_skill_slot_requested")
		),
		"Mobile skill request uses the player generic slot path"
	)

	var requested_skill_slots: Array[int] = []
	mobile_controls.connect(
		"skill_slot_requested",
		func(slot_index: int) -> void:
			requested_skill_slots.append(slot_index)
	)

	fireball_skill.set("cooldown_remaining", 0.0)
	fireballs_before = _count_nodes_with_script(sandbox, FireballProjectileScript)
	mobile_controls.get_node("FireballButton").emit_signal("pressed")
	_check(
		_count_nodes_with_script(sandbox, FireballProjectileScript) == fireballs_before + 1,
		"Mobile Fireball button activates Fireball through skill slot 0"
	)
	_check(requested_skill_slots.back() == 0, "Mobile Fireball button requests generic slot 0")

	var lightning_button := mobile_controls.get_node_or_null("LightningArcButton") as Button
	_check(lightning_button != null, "Mobile Lightning Arc button exists")

	if lightning_button != null:
		lightning_button.emit_signal("pressed")
		_check(requested_skill_slots.back() == 1, "Mobile Lightning Arc button requests generic slot 1")
		_check(
			not lightning_button.get_global_rect().intersects(
				mobile_controls.get_node("FireballButton").get_global_rect()
			),
			"Mobile skill buttons do not overlap"
		)
		_check(
			not lightning_button.get_global_rect().intersects(
				mobile_controls.get_node("VirtualJoystick").get_global_rect()
			),
			"Lightning Arc button does not overlap the joystick"
		)

	var manual_skill_button_count := 0

	for control in mobile_controls.get_children():
		if control is Button:
			manual_skill_button_count += 1

	_check(manual_skill_button_count == 2, "HUD still contains exactly two manual skill buttons")

	for child in sandbox.get_children():
		if child.get_script() == FireballProjectileScript:
			child.queue_free()

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


func _test_lightning_arc(
	sandbox: Node2D,
	player: CharacterBody2D,
	enemies: Array[CharacterBody2D]
) -> void:
	var basic := _find_enemy_by_name(enemies, "Enemy")
	var fast := _find_enemy_by_name(enemies, "FastEnemy")
	var heavy := _find_enemy_by_name(enemies, "HeavyEnemy")
	var fireball_skill := player.get_node("FireballSkill")
	var lightning_arc_skill := player.get_node("LightningArcSkill")

	if basic == null or fast == null or heavy == null:
		_check(false, "Lightning Arc test targets are available")
		return

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(1000.0, 1000.0)
		enemy.get_node("Health").call("restore_full")

	basic.global_position = player.global_position + Vector2(120.0, 0.0)
	fast.global_position = player.global_position + Vector2(200.0, 0.0)
	heavy.global_position = player.global_position + Vector2(290.0, 0.0)

	var basic_health := basic.get_node("Health")
	var fast_health := fast.get_node("Health")
	var heavy_health := heavy.get_node("Health")
	var basic_health_before: int = basic_health.get("current_health")
	var fast_health_before: int = fast_health.get("current_health")
	var heavy_health_before: int = heavy_health.get("current_health")
	var first_damage: int = lightning_arc_skill.get("damage")
	var chain_damage: int = lightning_arc_skill.call("get_chain_damage")
	var visuals_before := get_nodes_in_group("lightning_arc_visual").size()

	lightning_arc_skill.set("cooldown_remaining", 0.0)
	fireball_skill.set("cooldown_remaining", 0.0)
	_check(
		player.call("activate_skill", 1, Vector2.LEFT),
		"Lightning Arc activates through generic skill slot 1"
	)
	_check(
		basic_health.get("current_health") == basic_health_before - first_damage,
		"Lightning Arc selects and damages the nearest first target exactly once"
	)
	_check(
		fast_health.get("current_health") == fast_health_before - chain_damage,
		"Lightning Arc chains to the nearest different enemy"
	)
	_check(
		heavy_health.get("current_health") == heavy_health_before,
		"Lightning Arc stops after one additional chain target"
	)
	_check(
		get_nodes_in_group("lightning_arc_visual").size() == visuals_before + 1,
		"Lightning Arc creates one lightweight visual per cast"
	)

	var chain_visual := get_nodes_in_group("lightning_arc_visual").back() as Line2D
	_check(chain_visual != null and chain_visual.points.size() == 9, "Lightning visual shows both hit segments")
	_check(lightning_arc_skill.get("cooldown_remaining") > 0.0, "Lightning Arc starts its own cooldown")
	_check(is_zero_approx(fireball_skill.get("cooldown_remaining")), "Lightning Arc does not start Fireball cooldown")
	_check(
		not player.call("activate_skill", 1, Vector2.RIGHT),
		"Lightning Arc cooldown blocks immediate reactivation"
	)

	for enemy in [basic, fast, heavy]:
		enemy.get_node("Health").call("restore_full")

	lightning_arc_skill.set("cooldown_remaining", 0.0)
	var q_target_health_before: int = basic_health.get("current_health")
	Input.action_press("skill_slot_2")
	player.call("_physics_process", 0.0)
	Input.action_release("skill_slot_2")
	_check(
		basic_health.get("current_health") == q_target_health_before - first_damage,
		"Q activates Lightning Arc through generic skill slot 1"
	)

	for enemy in [basic, fast, heavy]:
		enemy.get_node("Health").call("restore_full")

	lightning_arc_skill.set("cooldown_remaining", 0.0)
	var mobile_target_health_before: int = basic_health.get("current_health")
	player.get_node("HUD/MobileControls/LightningArcButton").emit_signal("pressed")
	_check(
		basic_health.get("current_health") == mobile_target_health_before - first_damage,
		"Mobile Lightning Arc button activates generic skill slot 1"
	)

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(1000.0, 1000.0)
		enemy.get_node("Health").call("restore_full")

	lightning_arc_skill.set("cooldown_remaining", 0.0)
	fireball_skill.set("cooldown_remaining", 0.0)
	var fireballs_before := _count_nodes_with_script(sandbox, FireballProjectileScript)
	_check(player.call("activate_skill", 0, Vector2.RIGHT), "Fireball still activates through skill slot 0")
	_check(
		_count_nodes_with_script(sandbox, FireballProjectileScript) == fireballs_before + 1,
		"Fireball regression still creates its projectile"
	)
	_check(fireball_skill.get("cooldown_remaining") > 0.0, "Fireball starts its own cooldown")
	_check(is_zero_approx(lightning_arc_skill.get("cooldown_remaining")), "Fireball does not start Lightning Arc cooldown")

	for child in sandbox.get_children():
		if child.get_script() == FireballProjectileScript:
			child.queue_free()

	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	var lethal_target := enemy_scene.instantiate() as CharacterBody2D
	sandbox.add_child(lethal_target)
	lethal_target.global_position = player.global_position + Vector2(120.0, 0.0)
	lethal_target.set_physics_process(false)
	lethal_target.get_node("LootDropper").set("equipment_drop_chance", 0.0)
	var lethal_health := lethal_target.get_node("Health")
	lethal_health.call("take_damage", lethal_health.get("current_health") - 1)
	var experience := player.get_node("Experience")
	var experience_before: int = experience.get("current_experience")
	var gold_pickups_before := _count_nodes_with_script(sandbox, GoldPickupScript)
	lightning_arc_skill.set("cooldown_remaining", 0.0)
	_check(player.call("activate_skill", 1, Vector2.RIGHT), "Lightning Arc can kill its first target")
	_check(lethal_target.get("death_processed"), "Lightning Arc death uses the shared enemy death path")
	_check(
		experience.get("current_experience") == experience_before + lethal_target.get("experience_reward"),
		"Lightning Arc kill awards XP exactly once"
	)
	_check(
		_count_nodes_with_script(sandbox, GoldPickupScript) == gold_pickups_before + 1,
		"Lightning Arc kill creates loot through the shared drop path"
	)

	var experience_after_death: int = experience.get("current_experience")
	var gold_pickups_after_death := _count_nodes_with_script(sandbox, GoldPickupScript)
	lethal_target.call("_on_health_depleted")
	_check(
		experience.get("current_experience") == experience_after_death
		and _count_nodes_with_script(sandbox, GoldPickupScript) == gold_pickups_after_death,
		"Repeated depletion cannot duplicate Lightning Arc kill rewards"
	)

	for visual in get_nodes_in_group("lightning_arc_visual"):
		visual.queue_free()

	await process_frame


func _test_flame_nova(
	sandbox: Node2D,
	player: CharacterBody2D,
	enemies: Array[CharacterBody2D]
) -> void:
	var basic := _find_enemy_by_name(enemies, "Enemy")
	var fast := _find_enemy_by_name(enemies, "FastEnemy")
	var heavy := _find_enemy_by_name(enemies, "HeavyEnemy")
	var autocast_skill_slots := player.get_node("AutocastSkillSlots")
	var flame_nova_skill := autocast_skill_slots.get_node("FlameNovaSkill")
	var fireball_skill := player.get_node("FireballSkill")
	var lightning_arc_skill := player.get_node("LightningArcSkill")

	if basic == null or fast == null or heavy == null:
		_check(false, "Flame Nova test targets are available")
		return

	autocast_skill_slots.set_physics_process(false)

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(1000.0, 1000.0)
		enemy.get_node("Health").call("restore_full")

	flame_nova_skill.set("time_until_ready", 0.0)
	var visuals_before := get_nodes_in_group("flame_nova_visual").size()
	autocast_skill_slots.call("update_autocast_skills", 1.0)
	_check(
		is_zero_approx(flame_nova_skill.get("time_until_ready")),
		"Ready Flame Nova remains ready while no enemy is nearby"
	)
	_check(
		get_nodes_in_group("flame_nova_visual").size() == visuals_before,
		"No-target Flame Nova creates no visual"
	)

	basic.global_position = player.global_position + Vector2(100.0, 0.0)
	var basic_health := basic.get_node("Health")
	var basic_health_before: int = basic_health.get("current_health")
	var nova_damage: int = flame_nova_skill.get("damage")
	fireball_skill.set("cooldown_remaining", 0.0)
	lightning_arc_skill.set("cooldown_remaining", 0.0)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		basic_health.get("current_health") == basic_health_before - nova_damage,
		"Ready Flame Nova activates when an enemy enters its radius"
	)
	_check(
		is_equal_approx(
			flame_nova_skill.get("time_until_ready"),
			flame_nova_skill.get("autocast_interval")
		),
		"Successful Flame Nova restarts its autocast interval"
	)
	_check(
		is_zero_approx(fireball_skill.get("cooldown_remaining"))
		and is_zero_approx(lightning_arc_skill.get("cooldown_remaining")),
		"Flame Nova does not affect either active-skill cooldown"
	)
	_check(
		get_nodes_in_group("flame_nova_visual").size() == visuals_before + 1,
		"Flame Nova creates one main visual per activation"
	)

	var nova_visual := get_nodes_in_group("flame_nova_visual").back() as Line2D
	_check(
		nova_visual != null
		and nova_visual.points.size() == 48
		and nova_visual.global_position.is_equal_approx(player.global_position),
		"Flame Nova visual is one player-centered ring"
	)
	await create_timer(0.4).timeout
	_check(
		get_nodes_in_group("flame_nova_visual").size() == visuals_before,
		"Flame Nova visual cleans itself up after its short lifetime"
	)

	basic_health.call("restore_full")
	basic_health_before = basic_health.get("current_health")
	var interval: float = flame_nova_skill.get("autocast_interval")
	flame_nova_skill.set("time_until_ready", interval)
	autocast_skill_slots.call("update_autocast_skills", interval - 0.1)
	_check(
		basic_health.get("current_health") == basic_health_before,
		"Flame Nova does not activate before its interval completes"
	)
	autocast_skill_slots.call("update_autocast_skills", 0.2)
	_check(
		basic_health.get("current_health") == basic_health_before - nova_damage,
		"Flame Nova activates once when its interval completes"
	)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		basic_health.get("current_health") == basic_health_before - nova_damage,
		"One Flame Nova activation cannot tick the same target repeatedly"
	)

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(1000.0, 1000.0)
		enemy.get_node("Health").call("restore_full")

	basic.global_position = player.global_position + Vector2(100.0, 0.0)
	heavy.global_position = player.global_position + Vector2(-100.0, 0.0)
	fast.global_position = player.global_position + Vector2(171.0, 0.0)
	var fast_health := fast.get_node("Health")
	var heavy_health := heavy.get_node("Health")
	basic_health_before = basic_health.get("current_health")
	var fast_health_before: int = fast_health.get("current_health")
	var heavy_health_before: int = heavy_health.get("current_health")
	visuals_before = get_nodes_in_group("flame_nova_visual").size()
	flame_nova_skill.set("time_until_ready", 0.0)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		basic_health.get("current_health") == basic_health_before - nova_damage
		and heavy_health.get("current_health") == heavy_health_before - nova_damage,
		"Flame Nova damages every valid enemy inside its radius exactly once"
	)
	_check(
		fast_health.get("current_health") == fast_health_before,
		"Flame Nova does not damage enemies outside its configured radius"
	)
	_check(
		get_nodes_in_group("flame_nova_visual").size() == visuals_before + 1,
		"Multi-target Flame Nova still creates only one main visual"
	)

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(1000.0, 1000.0)
		enemy.get_node("Health").call("restore_full")

	basic.global_position = player.global_position + Vector2(100.0, 0.0)
	basic_health_before = basic_health.get("current_health")
	flame_nova_skill.set("time_until_ready", 0.0)
	autocast_skill_slots.set_physics_process(true)
	player.call("open_character_management")
	await create_timer(0.1, true, true).timeout
	_check(
		basic_health.get("current_health") == basic_health_before
		and is_zero_approx(flame_nova_skill.get("time_until_ready")),
		"Character menu pause stops Flame Nova processing and damage"
	)
	player.call("close_character_management")

	for step in 3:
		await physics_frame

	_check(
		basic_health.get("current_health") == basic_health_before - nova_damage,
		"Flame Nova resumes safely after the Character menu closes"
	)
	autocast_skill_slots.set_physics_process(false)

	basic_health.call("restore_full")
	basic_health_before = basic_health.get("current_health")
	flame_nova_skill.set("time_until_ready", 0.0)
	player.set("starting_position", player.global_position)
	var player_health := player.get_node("Health")
	player_health.call("take_damage", player_health.get("current_health"))
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		basic_health.get("current_health") == basic_health_before
		and is_zero_approx(flame_nova_skill.get("time_until_ready")),
		"Flame Nova cannot attack while player health is depleted"
	)
	player.call("respawn")
	_check(
		player_health.get("current_health") == player_health.get("max_health")
		and player.global_position == player.get("starting_position"),
		"Player reset still restores health and starting position"
	)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		basic_health.get("current_health") == basic_health_before - nova_damage,
		"Ready Flame Nova continues safely after player reset"
	)

	for enemy in enemies:
		enemy.global_position = player.global_position + Vector2(1000.0, 1000.0)
		enemy.get_node("Health").call("restore_full")

	var enemy_scene := load("res://scenes/enemy.tscn") as PackedScene
	var lethal_targets: Array[CharacterBody2D] = []

	for offset in [Vector2(80.0, 0.0), Vector2(-80.0, 0.0)]:
		var lethal_target := enemy_scene.instantiate() as CharacterBody2D
		sandbox.add_child(lethal_target)
		lethal_target.global_position = player.global_position + offset
		lethal_target.set_physics_process(false)
		lethal_target.set("experience_reward", 1)
		lethal_target.get_node("LootDropper").set("equipment_drop_chance", 0.0)
		var lethal_health := lethal_target.get_node("Health")
		lethal_health.call("take_damage", lethal_health.get("current_health") - 1)
		lethal_targets.append(lethal_target)

	var experience := player.get_node("Experience")
	experience.call("restore_progress", 1, 0)
	var experience_before: int = experience.get("current_experience")
	var total_experience_reward := 0

	for lethal_target in lethal_targets:
		total_experience_reward += lethal_target.get("experience_reward")

	var gold_pickups_before := _count_nodes_with_script(sandbox, GoldPickupScript)
	flame_nova_skill.set("time_until_ready", 0.0)
	autocast_skill_slots.call("update_autocast_skills", 0.0)
	_check(
		lethal_targets[0].get("death_processed")
		and lethal_targets[1].get("death_processed"),
		"One Flame Nova can safely kill multiple enemies"
	)
	_check(
		experience.get("current_experience") == experience_before + total_experience_reward,
		"Multiple Flame Nova kills award the expected XP exactly once"
	)
	_check(
		_count_nodes_with_script(sandbox, GoldPickupScript) == gold_pickups_before + 2,
		"Multiple Flame Nova kills each use the shared loot path"
	)

	var experience_after_deaths: int = experience.get("current_experience")
	var gold_pickups_after_deaths := _count_nodes_with_script(sandbox, GoldPickupScript)

	for lethal_target in lethal_targets:
		lethal_target.call("_on_health_depleted")

	_check(
		experience.get("current_experience") == experience_after_deaths
		and _count_nodes_with_script(sandbox, GoldPickupScript) == gold_pickups_after_deaths,
		"Repeated depletion cannot duplicate Flame Nova rewards"
	)

	for visual in get_nodes_in_group("flame_nova_visual"):
		visual.queue_free()

	await process_frame


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
	_check(
		player.call("activate_skill", 0, Vector2.RIGHT),
		"Fireball can be activated through its slot for hit regression"
	)
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
	var save_coordinator := player.get_node("SaveCoordinator")
	var inventory := player.get_node("Inventory")
	var equipment := player.get_node("Equipment")
	var experience := player.get_node("Experience")
	var attributes := player.get_node("Attributes")
	save_system.set("save_path", TEST_SAVE_PATH)
	_check(save_coordinator != null, "SaveCoordinator exists")
	_check(save_coordinator.has_method("build_current_player_data"), "SaveCoordinator owns payload gathering")
	_check(save_coordinator.has_method("apply_player_data"), "SaveCoordinator owns payload restoration")

	var state_before_failure: Dictionary = save_coordinator.call("build_current_player_data")
	_check(
		not state_before_failure.has("passive_skills")
		and not state_before_failure.has("autocast_timer"),
		"Prototype passive slot and internal timer do not change the save schema"
	)
	var missing_result: Dictionary = save_coordinator.call("load_progression")
	_check(not missing_result.get("success", false), "Missing save is rejected safely")
	_check(missing_result.get("message", "") == "No Save Found", "Missing save feedback is preserved")
	_check(save_coordinator.call("build_current_player_data") == state_before_failure, "Missing save does not alter active state")

	_write_test_save_text("{not valid json")
	var malformed_result: Dictionary = save_coordinator.call("load_progression")
	_check(not malformed_result.get("success", false), "Malformed JSON is rejected safely")
	_check(save_coordinator.call("build_current_player_data") == state_before_failure, "Malformed JSON does not alter active state")

	_write_test_save_text(JSON.stringify({
		"save_version": 1,
		"player": {"gold": "invalid"},
	}))
	var invalid_structure_result: Dictionary = save_coordinator.call("load_progression")
	_check(not invalid_structure_result.get("success", false), "Invalid player structure is rejected safely")
	_check(save_coordinator.call("build_current_player_data") == state_before_failure, "Invalid structure does not partially apply")

	_write_test_save_text(JSON.stringify({
		"save_version": 2,
		"player": {},
	}))
	var unsupported_result: Dictionary = save_coordinator.call("load_progression")
	_check(unsupported_result.get("message", "") == "Load Failed: Unsupported Save", "Unsupported future save version is explicit")
	_check(save_coordinator.call("build_current_player_data") == state_before_failure, "Unsupported version does not alter active state")

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
	var old_load_result: Dictionary = save_coordinator.call("load_progression")
	_check(old_save_result.get("success", false), "Version 1 data without newer optional item fields saves")
	_check(old_load_result.get("success", false), "Version 1 compatibility data loads")
	_check(player.get("gold") == 7, "Version 1 compatibility restores gold")
	_check(inventory.call("get_item_count") == 0, "Missing optional inventory restores safely as empty")
	_check(equipment.call("get_equipped_item", &"weapon") == null, "Missing optional equipment restores safely as empty")

	var full_data := {
		"level": 3,
		"current_xp": 17,
		"gold": 23,
		"attributes": {
			"strength": 6,
			"dexterity": 8,
			"intelligence": 7,
			"vitality": 6,
			"unspent_points": 4,
		},
		"inventory": ["practice_blade"],
		"equipment": {
			"weapon": "training_sword",
			"head": "apprentice_hood",
			"chest": "sturdy_vest",
		},
	}
	_check(save_coordinator.call("apply_player_data", full_data), "SaveCoordinator applies complete current data")
	_check(player.call("save_progression"), "Player K-save command path succeeds through SaveCoordinator")
	_check(player.get_node("HUD/SaveStatusLabel").text == "Game Saved", "Save feedback is preserved")
	_check(not FileAccess.file_exists(TEST_SAVE_PATH + ".tmp"), "Successful save leaves no temporary file")
	_check(FileAccess.file_exists(TEST_SAVE_PATH + ".bak"), "Successful replacement retains one backup")

	_check(save_coordinator.call("apply_player_data", old_compatible_data), "State can change before round-trip load")
	_check(player.call("load_progression"), "Player L-load command path succeeds through SaveCoordinator")
	_check(player.get_node("HUD/SaveStatusLabel").text == "Game Loaded", "Load feedback is preserved")
	_check(experience.get("current_level") == 3 and experience.get("current_experience") == 17, "Level and XP round-trip")
	_check(player.get("gold") == 23, "Gold round-trips")
	_check(
		attributes.get("strength") == 6
		and attributes.get("dexterity") == 8
		and attributes.get("intelligence") == 7
		and attributes.get("vitality") == 6
		and attributes.get("unspent_points") == 4,
		"Attributes and unspent points round-trip"
	)
	_check(inventory.call("get_item_count") == 1, "Inventory round-trips")
	_check(equipment.call("get_equipped_item", &"weapon").item_id == &"training_sword", "Equipment round-trips")
	var derived_stats: Dictionary = player.call("get_derived_stats_debug_data")
	_check(derived_stats.get("autoattack_damage") == 13, "Strength and equipment recalculate autoattack damage after load")
	_check(derived_stats.get("fireball_damage") == 28, "Intelligence and equipment recalculate Fireball damage after load")
	_check(derived_stats.get("lightning_arc_damage") == 24, "Intelligence recalculates Lightning Arc damage after load")
	_check(
		player.get_node("AutocastSkillSlots/FlameNovaSkill").get("damage") == 30,
		"Intelligence recalculates Flame Nova damage after load"
	)
	_check(derived_stats.get("max_health") == 115, "Vitality and equipment recalculate max HP after load")

	var unknown_item_data: Dictionary = full_data.duplicate(true)
	unknown_item_data["inventory"] = ["unknown_item"]
	unknown_item_data["equipment"] = {"weapon": "unknown_item"}
	_check(save_coordinator.call("apply_player_data", unknown_item_data), "Save data with unknown item IDs remains safe")
	_check(inventory.call("get_item_count") == 0, "Unknown inventory IDs are filtered")
	_check(equipment.call("get_equipped_item", &"weapon") == null, "Unknown equipment IDs are ignored")

	var valid_state_before_bad_load: Dictionary = save_coordinator.call("build_current_player_data")
	_write_test_save_text("broken")
	var final_bad_result: Dictionary = save_coordinator.call("load_progression")
	_check(not final_bad_result.get("success", false), "Later malformed load still fails")
	_check(save_coordinator.call("build_current_player_data") == valid_state_before_bad_load, "Failed load never corrupts restored state")


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
	for path in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".tmp", TEST_SAVE_PATH + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _write_test_save_text(text: String) -> void:
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)

	if file == null:
		_check(false, "Regression suite can write its isolated save fixture")
		return

	file.store_string(text)
	file.close()


func _check(condition: bool, description: String) -> void:
	checks_run += 1

	if condition:
		return
	else:
		failures += 1
		printerr("[FAIL] %s" % description)
