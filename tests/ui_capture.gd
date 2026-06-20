extends SceneTree

func _initialize() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(2.6).timeout
	_capture("C:/tmp/aetherwing_ui_home.png")
	game.hud.show_settings("start")
	await process_frame
	_capture("C:/tmp/aetherwing_ui_settings.png")
	game.hud.close_modal()
	game.hud.show_codex("start")
	await process_frame
	_capture("C:/tmp/aetherwing_ui_codex.png")
	game.hud.close_modal()
	game.start_game()
	await create_timer(3.1).timeout
	game.toggle_pause()
	await process_frame
	_capture("C:/tmp/aetherwing_ui_pause.png")
	game.toggle_pause()
	game.spawn_codex_boss("warden")
	game.boss.phase = 2
	game.boss.hp = game.boss.max_hp * 0.64
	await process_frame
	_capture("C:/tmp/aetherwing_ui_boss.png")
	game.queue_free()
	await process_frame
	quit(0)

func _capture(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
