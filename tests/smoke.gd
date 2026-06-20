extends SceneTree

const BossCatalogScript = preload("res://scripts/BossCatalog.gd")

func _initialize() -> void:
	var packed: PackedScene = load("res://Main.tscn")
	var game = packed.instantiate()
	root.add_child(game)
	await process_frame
	game.hud.show_codex("start")
	if not game.hud.codex_overlay.visible:
		push_error("Codex screen did not open")
		quit(1)
		return
	game.hud.close_modal()
	game.hud.show_settings("start")
	if not game.hud.settings_overlay.visible:
		push_error("Settings screen did not open")
		quit(1)
		return
	game.hud.close_modal()
	game.hud.show_guide("start")
	if not game.hud.guide_overlay.visible:
		push_error("Pilot guide did not open")
		quit(1)
		return
	game.hud.close_modal()
	game.start_game()
	await process_frame
	if game.state != "launching" or game.hud.wave_intro_lbl.text != "3":
		push_error("Launch did not begin with a three-second countdown")
		quit(1)
		return
	await create_timer(3.1).timeout
	await process_frame
	if game.state != "enemy_intro" or not game.hud.enemy_intro_overlay.visible:
		push_error("First enemy introduction did not pause the run")
		quit(1)
		return
	_dismiss_enemy_intros(game)
	game.toggle_pause()
	if game.state != "paused" or not game.hud.pause_overlay.visible:
		push_error("Pause screen did not freeze the run")
		quit(1)
		return
	game.hud.show_codex("pause")
	game.hud.close_modal()
	if not game.hud.pause_overlay.visible:
		push_error("Codex did not return to pause screen")
		quit(1)
		return
	game.toggle_pause()
	if game.state != "playing":
		push_error("Pause screen did not resume the run")
		quit(1)
		return

	# Joystick movement should accelerate into input, reverse responsively, and
	# brake to a clean stop instead of snapping or drifting.
	game.control_mode = "joystick"
	game.player.position = Vector2.ZERO
	game.player.target = Vector2.ZERO
	game.player.vel = Vector2.ZERO
	game.joy_dir = Vector2.RIGHT
	game.joy_mag = 1.0
	game._update_movement(0.1, 0.1)
	if game.player.vel.x <= 0.0 or game.player.vel.x >= game.JOY_MAX_SPEED:
		push_error("Joystick acceleration is not smooth")
		quit(1)
		return
	game.joy_dir = Vector2.LEFT
	game._update_movement(0.1, 0.1)
	if game.player.vel.x >= 0.0:
		push_error("Joystick direction changes are not responsive")
		quit(1)
		return
	game.joy_dir = Vector2.ZERO
	game.joy_mag = 0.0
	game._update_movement(0.5, 0.5)
	if game.player.vel.length() > 5.0:
		push_error("Joystick release left excessive drift")
		quit(1)
		return

	# Test-build abilities are temporary and reset to the base Pulse loadout.
	game._grant_upgrade("damage")
	game.weapon_system.weapons.append({"id": "gravity", "level": 1, "evolved": ""})
	game.test_ability_timer = 0.01
	game.update(0.02)
	if game.test_ability_timer > 0.0 or game.upgrades.damage != 0.0:
		push_error("Test ability timer did not expire utility upgrades")
		quit(1)
		return
	if game.weapon_system.weapons.size() != 1 or game.weapon_system.weapons[0].id != "pulse":
		push_error("Test ability timer did not restore the base loadout")
		quit(1)
		return

	# Green is reserved for points/XP, never an enemy or combat satellite.
	if Data.ENEMY_BASE.skimmer.color == Data.GREEN or Data.SURVIVOR_WEAPONS.shield.color == Data.GREEN:
		push_error("Combat entities still use the points-green color")
		quit(1)
		return

	# Purple hostile shots are converted to larger amber projectiles.
	var enemy_bullets_before: int = game.enemy_bullets.size()
	game.spawn_enemy_bullet(Vector2.ZERO, Vector2.RIGHT, 5.0, Data.PURPLE, 1, 1.0)
	var converted_bullet: Bullet = game.enemy_bullets.back()
	if game.enemy_bullets.size() <= enemy_bullets_before or converted_bullet.color == Data.PURPLE:
		push_error("Purple hostile projectile was not recolored")
		quit(1)
		return
	if converted_bullet.size < 8.0:
		push_error("Converted hostile projectile was not enlarged")
		quit(1)
		return
	game.spawn_enemy_bullet(Vector2.ZERO, Vector2.RIGHT, 5.0, Data.MAGENTA, 1, 1.0)
	var converted_magenta: Bullet = game.enemy_bullets.back()
	if converted_magenta.color == Data.MAGENTA or converted_magenta.size < 8.0:
		push_error("Magenta hostile projectile still reads as a small purple shot")
		quit(1)
		return

	# Exercise every base weapon through the shared runtime.
	for id in Data.SURVIVOR_WEAPONS:
		game.weapon_system.weapons = [{"id": id, "level": 5, "evolved": ""}]
		game.weapon_system.cooldowns.clear()
		game.weapon_system.update(2.0)
		await process_frame

	# Gravity mines must deploy away from the ship, visibly arm, and only then
	# become active singularity fields.
	var mines: Array = game.bullets.filter(func(b): return b.is_gravity_mine)
	if mines.is_empty():
		push_error("Gravity Mine did not create a mine projectile")
		quit(1)
		return
	var mine: Bullet = mines.back()
	if mine.position.distance_to(game.player.position) < 90.0 or mine.singularity_activated:
		push_error("Gravity Mine did not deploy into the combat space before arming")
		quit(1)
		return
	game._update_bullets(mine.mine_arm_total + 0.01)
	if not mine.singularity_activated:
		push_error("Gravity Mine did not activate after its arming window")
		quit(1)
		return

	# The two small-enemy roles should produce meaningfully different motion,
	# and the skimmer should pressure from range instead of becoming a recolor.
	var weaver: Enemy = game.spawn_enemy("weaver", game.player.position + Vector2(0, -260))
	var skimmer: Enemy = game.spawn_enemy("skimmer", game.player.position + Vector2(210, 0))
	_dismiss_enemy_intros(game)
	skimmer.fire_timer = 0.0
	var enemy_shots_before: int = game.enemy_bullets.size()
	weaver.update(0.1)
	skimmer.update(0.1)
	if absf(weaver.vel.x) < 1.0:
		push_error("Weaver did not generate lateral weaving motion")
		quit(1)
		return
	if game.enemy_bullets.size() <= enemy_shots_before:
		push_error("Skimmer did not fire from its orbit")
		quit(1)
		return
	weaver.queue_free()
	skimmer.queue_free()
	game.enemies.clear()

	# Divers should commit to repeated attack passes instead of flying away
	# after one charge.
	var diver: Enemy = game.spawn_enemy("diver", game.player.position + Vector2(0, -260))
	_dismiss_enemy_intros(game)
	var saw_dive := false
	var saw_recovery := false
	for step in 35:
		diver.update(0.1)
		saw_dive = saw_dive or diver.state == "diving"
		saw_recovery = saw_recovery or diver.state == "recovering"
	if not saw_dive or not saw_recovery or diver.remove:
		push_error("Diver did not complete a purposeful strike-and-recovery pass")
		quit(1)
		return
	diver.queue_free()
	game.enemies.clear()

	# Boss arenas are 1.5x larger than the previous radius and can generate
	# collectible repair signals.
	game._open_arena()
	var expected_radius: float = min(game.view_size.x, game.view_size.y) * 1.89
	if not is_equal_approx(game.arena_radius, expected_radius):
		push_error("Boss arena was not enlarged to 1.5x")
		quit(1)
		return
	game.player.hp = game.player.max_hp - 1
	game.spawn_health_pickup()
	if game.health_pickups.is_empty():
		push_error("Boss arena did not spawn a repair pickup")
		quit(1)
		return
	game.health_pickups[0].position = game.player.position
	game.update_health_pickups(0.01)
	if game.player.hp != game.player.max_hp:
		push_error("Repair pickup did not heal the player")
		quit(1)
		return
	game.arena_active = false

	# Exercise every hand-authored merge attack.
	game.weapon_system.weapons = []
	for recipe in Data.MERGE_RECIPES:
		game.weapon_system.merged = {recipe.id: true}
		game.weapon_system.merge_cooldowns.clear()
		game.weapon_system.update(10.0)
		await process_frame
	game.weapon_system.merged.clear()

	# Verify evolution and merge eligibility/card application.
	game.weapon_system.weapons = [
		{"id": "pulse", "level": 5, "evolved": ""},
		{"id": "plasma", "level": 5, "evolved": "supernova"},
	]
	game.weapon_system.passives = {"power_core": 5, "explosive_tip": 5}
	var cards: Array = game.weapon_system.get_cards()
	var pulse_evo = cards.filter(func(card): return card.kind == "evolve" and card.target_id == "pulse")
	if pulse_evo.is_empty():
		push_error("Evolution card was not generated")
		quit(1)
		return
	game.weapon_system.apply_card(pulse_evo[0])
	cards = game.weapon_system.get_cards()
	var merge_cards = cards.filter(func(card): return card.kind == "merge" and card.target_id == "genesis_ray")
	if merge_cards.is_empty():
		push_error("Merge card was not generated")
		quit(1)
		return
	if not game.weapon_system.apply_card(merge_cards[0]):
		push_error("Merge card could not be applied")
		quit(1)
		return

	# Moving-fire regression: a strafing ship must still lead and intersect a
	# laterally moving target, and fast shots must use swept collision.
	for old_bullet in game.bullets:
		if is_instance_valid(old_bullet):
			old_bullet.queue_free()
	game.bullets.clear()
	var moving_target := Enemy.new()
	moving_target.main = game
	moving_target.position = Vector2(0, -320)
	moving_target.vel = Vector2(110, 0)
	moving_target.speed = 0.0
	game.world.add_child(moving_target)
	game.enemies = [moving_target]
	game.player.position = Vector2.ZERO
	game.player.vel = Vector2(300, 0)
	game.weapon_system._fire_pulse({"id": "pulse", "level": 1, "evolved": ""})
	var moving_bullet: Bullet = game.bullets.back()
	var closest := INF
	for step in 30:
		moving_bullet.prev_position = moving_bullet.position
		moving_bullet.position += moving_bullet.vel * 0.025
		moving_target.position += moving_target.vel * 0.025
		closest = minf(closest, moving_bullet.position.distance_to(moving_target.position))
	if closest > 12.0:
		push_error("Predictive moving-fire aim missed by %.2f pixels" % closest)
		quit(1)
		return
	moving_bullet.prev_position = Vector2.ZERO
	moving_bullet.position = Vector2(100, 0)
	if not game._bullet_hits(moving_bullet, Vector2(50, 0), 5.0):
		push_error("Swept projectile collision failed")
		quit(1)
		return
	moving_target.queue_free()
	game.enemies.clear()
	game.player.vel = Vector2.ZERO

	# Elite Lancer regression: positioning must commit to one destination long
	# enough for auto-aim to predict it instead of randomizing every frame.
	var lancer := Enemy.new()
	lancer.main = game
	lancer.type = "lancer"
	lancer.behavior = "snipe"
	lancer.state = "positioning"
	lancer.position = Vector2(-650, -650)
	lancer.size = 22.0
	lancer.hp = 200.0
	lancer.max_hp = 200.0
	game.world.add_child(lancer)
	game.enemies = [lancer]
	lancer.update(0.016)
	var committed_target: Vector2 = lancer.snipe_target
	for step in 12:
		lancer.update(0.016)
		if lancer.state == "positioning" and lancer.snipe_target != committed_target:
			push_error("Lancer changed positioning target mid-move")
			quit(1)
			return
	lancer.queue_free()
	game.enemies.clear()

	# Exercise promoted Codex bosses without waiting for wave progression.
	for id in BossCatalogScript.SUPPORTED:
		if id in ["conductor", "spiral"]:
			continue
		game.spawn_codex_boss(id)
		game.boss.phase = 1
		game.boss.update(0.1)
		game.defeat_boss(false)
		await process_frame

	print("AETHERWING_SMOKE_OK")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0)

func _dismiss_enemy_intros(game) -> void:
	while game.state == "enemy_intro":
		game.dismiss_enemy_intro()
