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

	# Exercise every base weapon through the shared runtime.
	for id in Data.SURVIVOR_WEAPONS:
		game.weapon_system.weapons = [{"id": id, "level": 5, "evolved": ""}]
		game.weapon_system.cooldowns.clear()
		game.weapon_system.update(2.0)
		await process_frame

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
