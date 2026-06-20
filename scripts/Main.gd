extends Node2D
## AETHERWING — Godot 4.6 port of AETHERWING_prototype_v11.html
## Central controller: owns game state, the simulation loop, spawning,
## collisions and camera (mirrors the original single update()/render()).

# --- scene refs ---
var camera: Camera2D
var world: Node2D
var worldfx: Node2D
var starfield: Control
var hud: CanvasLayer
var weapon_system: WeaponSystem

# --- entities ---
var player: Player
var boss = null
var world_boss = null

# boss arena — confines the player to a visible ring during a boss fight
var arena_active := false
var arena_center: Vector2 = Vector2.ZERO
var arena_radius := 0.0
var enemies: Array = []
var bullets: Array = []
var enemy_bullets: Array = []
var xp_gems: Array = []
var health_pickups: Array = []
var enemy_grid := {}
const ENEMY_GRID_SIZE := 72.0
const MAX_PLAYER_BULLETS := 180
const MAX_ENEMY_BULLETS := 220
const MAX_XP_GEMS := 100
var particles: Array = []          # {pos, vel, life, max_life, color, size}
var decals: Array = []             # {pos, size, color, life, max_life}
var damage_numbers: Array = []     # {pos, vel, text, color, big, life, max_life}

# --- game state ---
var state := "start"               # start / playing / paused / levelup / dying / gameover
var time := 0.0
var time_scale := 1.0
var hit_pause := 0.0
var score := 0
var combo := 1
var max_combo := 1
var combo_timer := 0.0
var wave := 1
var wave_timer := 0.0
var wave_spawn_queue: Array = []   # {time, type, pos}
var wave_transition := -1.0
var boss_index := 0
var echo_phase := false
var echo_phase_timer := 0.0
var screen_shake := 0.0
var zoom_pulse := 1.0
var rewind_snapshots: Array = []
var rewind_active := false
var rewind_timer := 0.0
var snap_timer := 0.0
var kill_count := 0
var elite_timer := 0.0
var boss_timer := 0.0
var arena_health_timer := 0.0
var objective_toast_timer := 0.0
var revive_used := false
var launch_sequence_id := 0
var control_mode := "joystick"   # joystick (default) | follow | direct
var high_score := 0

var upgrades := {}
var upgrade_stacks := {}
var pending_level_ups := 0
var test_ability_timer := 0.0
var _pending := false   # true while a warning banner is playing before a spawn
var introduced_enemies := {}
var enemy_intro_queue: Array[String] = []
var enemy_intro_resume_scale := 1.0

const ENEMY_INTROS := {
	"drone": {"name": "DRONE", "icon": "⬡", "color": Data.CYAN,
		"desc": "A steady pursuer. Keep moving and cut through the swarm before it surrounds you."},
	"weaver": {"name": "WEAVER", "icon": "⌁", "color": Data.CYAN_SOFT,
		"desc": "A small zigzag attacker. Its lateral movement makes straight-line weapons less reliable."},
	"skimmer": {"name": "SKIMMER", "icon": "➤", "color": Data.PURPLE,
		"desc": "A ranged flanker. It circles at medium range and fires into your escape routes."},
	"diver": {"name": "DIVER", "icon": "▼", "color": Data.MAGENTA,
		"desc": "A red strike craft. It locks onto your position, commits to a fast charge, then turns for another pass."},
	"bulwark": {"name": "BULWARK", "icon": "■", "color": Data.AMBER,
		"desc": "An armored blocker. Attack while its forward shield retracts or hit it from behind."},
	"lancer": {"name": "LANCER", "icon": "◇", "color": Data.GOLD,
		"desc": "A precision sniper. Move away from its targeting line before the charged shot fires."},
}

const TEST_ABILITY_DURATION := 30.0

func _announce_then(text: String, color: Color, cb: Callable) -> void:
	_pending = true
	hud.announce(text, color)
	await get_tree().create_timer(1.3).timeout
	_pending = false
	if state == "playing":
		cb.call()

# --- landmarks / world mini-boss ---
var landmark_cache := {}          # "cx,cy" -> Landmark node or null
var nearby_landmarks: Array = []
var xp_mult := 1.0
var xp_mult_timer := 0.0
var beacon_timer := 0.0

# --- daily / weekly modifiers ---
var current_modifier := ""
var current_weekly := ""
var modifier_badge := ""
var weekly_badge := ""
var modifier_name := ""
var modifier_desc := ""
var modifier_color: Color = Data.AMBER
var weekly_name := ""
var weekly_desc := ""
var weekly_color: Color = Data.PURPLE

# --- camera / view ---
var cam: Vector2 = Vector2.ZERO
const CAM_FOLLOW := 0.12
var view_size: Vector2 = Vector2(720, 1280)

# --- input ---
var dragging := false
var drag_index := -1
var drag_start: Vector2 = Vector2.ZERO
var drag_cur: Vector2 = Vector2.ZERO
var ship_anchor: Vector2 = Vector2.ZERO
var last_finger: Vector2 = Vector2.ZERO
var tap_start_ms := 0
var swipe_start_y := 0.0
var swipe_start_ms := 0

# --- virtual joystick ---
const JOY_RADIUS := 72.0
const JOY_DEADZONE := 6.0
const JOY_MAX_SPEED := 520.0
const MOVE_ACCEL := 12.0
const MOVE_BRAKE := 18.0
const FOLLOW_MAX_SPEED := 620.0
var joy_active := false
var joy_origin: Vector2 = Vector2.ZERO
var joy_vec: Vector2 = Vector2.ZERO    # clamped knob offset (screen px)
var joy_dir: Vector2 = Vector2.ZERO    # normalized steer direction
var joy_mag := 0.0                      # 0..1 push amount

# preloads
const PlayerScript = preload("res://scripts/Player.gd")
const HealthPickupScript = preload("res://scripts/HealthPickup.gd")
const BossCatalogScript = preload("res://scripts/BossCatalog.gd")
const CodexBossScript = preload("res://scripts/CodexBoss.gd")

func _ready() -> void:
	randomize()
	view_size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): view_size = get_viewport_rect().size)

	# Optional bloom for extra neon punch
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.15
	env.glow_strength = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	world = Node2D.new()
	world.name = "World"
	add_child(world)

	worldfx = Node2D.new()
	worldfx.set_script(preload("res://scripts/WorldFX.gd"))
	worldfx.main = self
	world.add_child(worldfx)

	# Starfield behind everything
	var sf_layer := CanvasLayer.new()
	sf_layer.layer = -10
	add_child(sf_layer)
	starfield = Control.new()
	starfield.set_script(preload("res://scripts/Starfield.gd"))
	starfield.main = self
	sf_layer.add_child(starfield)

	# HUD on top
	hud = CanvasLayer.new()
	hud.layer = 10
	hud.set_script(preload("res://scripts/HUD.gd"))
	add_child(hud)
	hud.main = self
	hud.build()

	high_score = _load_high_score()
	_pick_modifiers()
	new_game()
	state = "start"
	hud.show_start()
	_show_splash()

# --- Studio boot splash (LITTLE TAG ART STUDIOS) ---
# Shows the studio logo on launch, then fades into the menu.
# Skips silently if the logo file hasn't been added yet.
func _show_splash() -> void:
	var candidates := [
		"res://assets/LTAS.png",
		"res://assets/littletag_logo.png",
		"res://assets/logo.png",
		"res://assets/littletag.png",
	]
	var tex: Texture2D = null
	for c in candidates:
		if ResourceLoader.exists(c):
			tex = load(c)
			if tex != null:
				break
	if tex == null:
		return

	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color.BLACK
	root.add_child(bg)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.offset_left = 70; tr.offset_top = 70; tr.offset_right = -70; tr.offset_bottom = -70
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.pivot_offset = (view_size - Vector2(140, 140)) * 0.5
	root.add_child(tr)

	# Black covers instantly so the menu never shows through; only the logo
	# animates, then the whole splash crossfades into the menu once.
	root.modulate.a = 1.0
	tr.modulate.a = 0.0
	tr.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(tr, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(tr, "scale", Vector2.ONE, 0.6)
	tw.tween_interval(1.3)
	tw.tween_property(root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)

const SAVE_PATH := "user://aetherwing.save"
func _load_high_score() -> int:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f: return int(f.get_line())
	return 0

func _save_high_score() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_line(str(high_score))

func _pick_modifiers() -> void:
	var d := Time.get_datetime_dict_from_system()
	var day_seed: int = d.year * 10000 + d.month * 100 + d.day
	var rng := RandomNumberGenerator.new()
	rng.seed = day_seed
	var dk: Array = Data.DAILY_MODIFIERS.keys()
	current_modifier = dk[rng.randi() % dk.size()]
	var week: int = int(_day_of_year(d) / 7.0)
	var wk_seed: int = d.year * 100 + week
	rng.seed = wk_seed
	var wk: Array = Data.WEEKLY_MODIFIERS.keys()
	current_weekly = wk[rng.randi() % wk.size()]

	var m: Dictionary = Data.DAILY_MODIFIERS[current_modifier]
	modifier_name = m.name; modifier_desc = m.desc; modifier_color = m.color
	modifier_badge = "%s  %s" % [m.icon, m.name]
	var w: Dictionary = Data.WEEKLY_MODIFIERS[current_weekly]
	weekly_name = w.name; weekly_desc = w.desc; weekly_color = w.color
	weekly_badge = "%s  %s" % [w.icon, w.name]

func _day_of_year(d: Dictionary) -> int:
	var days_in := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if d.year % 4 == 0 and (d.year % 100 != 0 or d.year % 400 == 0):
		days_in[1] = 29
	var doy: int = d.day
	for i in (d.month - 1):
		doy += days_in[i]
	return doy

# --- weekly modifier multipliers ---
func wave_count_mult() -> float: return 1.5 if current_weekly == "swarm" else 1.0
func enemy_hp_mult() -> float: return 1.5 if current_weekly == "elite" else 1.0
func enemy_xp_mult() -> float: return 1.5 if current_weekly == "elite" else 1.0
func enemy_speed_mult() -> float: return 1.15 if current_weekly == "speed" else 1.0
func player_speed_mult() -> float: return 1.2 if current_weekly == "speed" else 1.0
func score_mult() -> float: return 2.0 if current_weekly == "greed" else 1.0
func greed_hp_penalty() -> int: return 1 if current_weekly == "greed" else 0
func landmark_spawn_mult() -> float: return 0.85 if current_weekly == "explorer" else 0.6

# ------------------------------------------------------------
# LANDMARKS
# ------------------------------------------------------------
func get_landmarks_near(p: Vector2) -> Array:
	var g := Data.LANDMARK_GRID
	var gx := int(floor(p.x / g))
	var gy := int(floor(p.y / g))
	var result: Array = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var cx := gx + dx
			var cy := gy + dy
			var key := "%d,%d" % [cx, cy]
			if not landmark_cache.has(key):
				landmark_cache[key] = _generate_landmark(cx, cy, key)
			if landmark_cache[key] != null:
				result.append(landmark_cache[key])
	return result

func _generate_landmark(cx: int, cy: int, key: String):
	if cx == 0 and cy == 0:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d_%d" % [cx, cy])
	if rng.randf() >= landmark_spawn_mult():
		return null
	var g := Data.LANDMARK_GRID
	var types: Array = Data.LANDMARK_TYPES.keys()
	var type: String = types[rng.randi() % types.size()]
	var ox := (rng.randf() - 0.5) * g * 0.5
	var oy := (rng.randf() - 0.5) * g * 0.5
	var guarded := rng.randf() < 0.25
	var guard_type := ""
	if guarded:
		var bk: Array = Data.MINI_BOSS_TYPES.keys()
		guard_type = bk[rng.randi() % bk.size()]
	var lm := Landmark.new()
	lm.main = self
	lm.type = type
	lm.key = key
	lm.guarded = guarded
	lm.guard_type = guard_type
	lm.position = Vector2(cx * g + g / 2.0 + ox, cy * g + g / 2.0 + oy)
	lm.z_index = 2
	world.add_child(lm)
	return lm

func update_landmarks(dt: float) -> void:
	if xp_mult_timer > 0:
		xp_mult_timer -= dt
		if xp_mult_timer <= 0:
			xp_mult = 1.0
			hud.toast("XP BOOST ENDED")
	if beacon_timer > 0:
		beacon_timer -= dt
		if beacon_timer <= 0:
			hud.toast("RADAR NORMAL")
	var p: Vector2 = player.position
	nearby_landmarks = get_landmarks_near(p)
	for lm in nearby_landmarks:
		if lm.visited: continue
		var d: float = lm.position.distance_to(p)
		var def: Dictionary = Data.LANDMARK_TYPES[lm.type]
		if lm.guarded and not lm.guard_triggered and world_boss == null and boss == null and not _pending:
			if d < 220.0:
				lm.guard_triggered = true
				var ang: float = (lm.position - p).angle()
				var bpos: Vector2 = lm.position - Vector2(cos(ang), sin(ang)) * 120.0
				var gtype: String = lm.guard_type
				var gkey: String = lm.key
				var gdef: Dictionary = Data.MINI_BOSS_TYPES[gtype]
				_announce_then("⚠ " + gdef.name + " AWAKENS", gdef.color, func(): spawn_world_boss(gtype, bpos, gkey))
		if d < def.radius + Data.PLAYER.size:
			# a guarded landmark stays locked until its guardian is defeated
			# (defeat clears `guarded`), so it can't be grabbed during the warning
			if lm.guarded:
				if lm.guard_triggered and objective_toast_timer <= 0.0:
					var guardian_name: String = Data.MINI_BOSS_TYPES.get(
						lm.guard_type, {"name": "GUARDIAN"}).name
					hud.toast("LOCKED — DEFEAT %s" % guardian_name, "warning")
					objective_toast_timer = 2.5
				continue
			lm.visited = true
			apply_landmark_effect(lm)
			spawn_particles(lm.position, def.color, 40, 6.0)
			spawn_particles(lm.position, Data.WHITE, 20, 4.0)
			screen_shake = 0.4

func apply_landmark_effect(lm) -> void:
	var def: Dictionary = Data.LANDMARK_TYPES[lm.type]
	match lm.type:
		"cache":
			var num := 2 if current_modifier == "cache" else 1
			var granted := 0
			for i in num:
				var available := Data.UPGRADES.filter(func(up): return _is_upgrade_available(up.id))
				if available.is_empty():
					break
				var up: Dictionary = available[randi() % available.size()]
				if _grant_upgrade(up.id):
					granted += 1
			hud.toast("%d UPGRADE(S) ACQUIRED" % granted, "gold")
		"station":
			heal_player(player.max_hp, "FULL REPAIR")
			player.echo_meter = Data.ECHO.meter_max
			if current_modifier == "station":
				player.shield_timer = 15.0
				hud.toast("FULL HEAL + ECHO + SHIELD", "green")
			else:
				hud.toast("FULL HEAL + ECHO REFILL", "green")
		"ruins":
			xp_mult = 3.0 if current_modifier == "ruins" else 2.0
			xp_mult_timer = 30.0
			hud.toast("%dx XP FOR 30s" % int(xp_mult), "green")
		"beacon":
			beacon_timer = 120.0 if current_modifier == "beacon" else 60.0
			hud.toast("RADAR RANGE +50%% FOR %ds" % int(beacon_timer), "green")
	hud.toast(def.name + " CLAIMED", "gold")

func get_active_landmarks() -> Array:
	var out: Array = []
	for lm in nearby_landmarks:
		if not lm.visited:
			out.append({"pos": lm.position, "color": lm.color})
	return out

# ------------------------------------------------------------
# WORLD MINI-BOSS
# ------------------------------------------------------------
func spawn_world_boss(type: String, pos: Vector2, landmark_key: String) -> void:
	boss_timer = 0.0
	var def: Dictionary = Data.MINI_BOSS_TYPES[type]
	var scaled: float = round(def.hp * (1.0 + wave * 0.2))
	var b := WorldBoss.new()
	b.main = self
	b.type = type
	b.boss_name = def.name
	b.hp = scaled; b.max_hp = scaled
	b.size = def.size; b.speed = def.speed; b.color = def.color
	b.score_value = def.score; b.xp_value = def.xp; b.behavior = def.behavior
	b.guarding_landmark = landmark_key
	b.position = pos
	b.z_index = 16
	world.add_child(b)
	world_boss = b
	var objective_name := "LANDMARK"
	if landmark_cache.has(landmark_key) and landmark_cache[landmark_key] != null:
		objective_name = Data.LANDMARK_TYPES[landmark_cache[landmark_key].type].name
	hud.show_world_boss_bar("%s — GUARDING %s" % [def.name, objective_name], def.color)
	hud.toast("LOCKED: DEFEAT %s TO CLAIM %s" % [def.name, objective_name], "warning")
	Audio.boss_warn()

func damage_world_boss(amount: float) -> void:
	if world_boss == null: return
	if world_boss.spawn_protect > 0: amount *= 0.3
	world_boss.hp -= amount
	world_boss.hit_flash = 0.1
	Audio.boss_hit()
	if world_boss.hp <= 0:
		defeat_world_boss()

func defeat_world_boss() -> void:
	var b = world_boss
	spawn_particles(b.position, b.color, 50, 8.0)
	spawn_particles(b.position, Data.AMBER, 30, 6.0)
	spawn_particles(b.position, Data.WHITE, 20, 4.0)
	spawn_decal(b.position, 30.0, b.color)
	var guardian_gain := int(round(b.score_value * active_score_mult()))
	score += guardian_gain
	var guardian_xp := int(round(b.xp_value * enemy_xp_mult()))
	spawn_xp_gem(b.position, guardian_xp)
	spawn_xp_gem(b.position + Vector2(20, 10), guardian_xp)
	spawn_xp_gem(b.position + Vector2(-20, -10), guardian_xp)
	hud.toast("%s DEFEATED — +%d" % [b.boss_name, guardian_gain], "gold")
	Audio.boss_kill()
	screen_shake = 1.0
	hit_pause = 0.15
	var key: String = b.guarding_landmark
	if key != "" and landmark_cache.has(key) and landmark_cache[key] != null:
		var lm = landmark_cache[key]
		lm.guarded = false
		lm.visited = true
		apply_landmark_effect(lm)
		spawn_particles(lm.position, lm.color, 30, 6.0)
	hud.hide_world_boss_bar()
	b.queue_free()
	world_boss = null
	boss_timer = 0.0   # full 90s breather before the next timed boss

# ------------------------------------------------------------
# GAME LIFECYCLE
# ------------------------------------------------------------
func new_game() -> void:
	# clear entities
	for arr in [enemies, bullets, enemy_bullets, xp_gems, health_pickups]:
		for e in arr:
			if is_instance_valid(e): e.queue_free()
	enemies.clear(); bullets.clear(); enemy_bullets.clear(); xp_gems.clear(); health_pickups.clear()
	particles.clear(); decals.clear(); damage_numbers.clear()
	if boss and is_instance_valid(boss): boss.queue_free()
	boss = null
	arena_active = false
	for k in landmark_cache:
		var lm = landmark_cache[k]
		if lm != null and is_instance_valid(lm): lm.queue_free()
	landmark_cache.clear()
	nearby_landmarks.clear()
	if world_boss and is_instance_valid(world_boss): world_boss.queue_free()
	world_boss = null
	if weapon_system and is_instance_valid(weapon_system): weapon_system.queue_free()
	weapon_system = null
	xp_mult = 1.0; xp_mult_timer = 0.0; beacon_timer = 0.0
	if player and is_instance_valid(player): player.queue_free()

	cam = Vector2.ZERO
	time = 0.0; time_scale = 1.0; hit_pause = 0.0
	score = 0; combo = 1; max_combo = 1; combo_timer = 0.0
	wave = 1; wave_timer = 0.0; wave_spawn_queue.clear(); wave_transition = -1.0
	echo_phase = false; echo_phase_timer = 0.0
	screen_shake = 0.0; zoom_pulse = 1.0
	rewind_snapshots.clear(); rewind_active = false; rewind_timer = 0.0; snap_timer = 0.0
	kill_count = 0; elite_timer = 0.0; boss_timer = 0.0; revive_used = false
	arena_health_timer = 0.0
	introduced_enemies.clear()
	enemy_intro_queue.clear()

	upgrades = {
		"damage": 0.0, "fireRate": 0.0, "multishot": 0, "pierce": 0, "bulletSpeed": 0.0,
		"echoGain": 0.0, "critChance": 0.0, "magnet": 0.0, "moveSpeed": 0.0,
		"echoDuration": 0.0, "lifesteal": 0.0,
	}
	upgrade_stacks = {}
	pending_level_ups = 0
	test_ability_timer = 0.0

	player = PlayerScript.new()
	player.position = Vector2.ZERO
	player.target = Vector2.ZERO
	player.max_hp = Data.PLAYER.max_hp - greed_hp_penalty()
	player.hp = player.max_hp
	player.rewind_charges = Data.ECHO.rewind_charges
	player.z_index = 20
	world.add_child(player)

	weapon_system = WeaponSystem.new()
	weapon_system.main = self
	weapon_system.z_index = 19
	world.add_child(weapon_system)
	weapon_system.reset_run()

	# XP
	xp_level = 1; xp_current = 0; xp_to_next = Data.xp_required(1)

	# reset any boss/echo HUD that may have been showing when the last run ended
	if hud:
		hud.hide_boss_bar()
		hud.hide_world_boss_bar()
		hud.hide_enemy_intro()
		hud.set_echo_overlay(false)

func start_game() -> void:
	new_game()
	launch_sequence_id += 1
	var sequence := launch_sequence_id
	state = "launching"
	hud.hide_overlays()
	hud.update_weapon()
	for count in [3, 2, 1]:
		hud.show_launch_countdown(str(count))
		await get_tree().create_timer(1.0).timeout
		if state != "launching" or sequence != launch_sequence_id:
			return
	hud.show_launch_countdown("LAUNCH")
	state = "playing"
	Audio.start_music(func(): return combo)
	start_wave(1)

func restart() -> void:
	start_game()

func return_to_base() -> void:
	launch_sequence_id += 1
	dragging = false
	joy_active = false
	joy_dir = Vector2.ZERO
	joy_mag = 0.0
	time_scale = 1.0
	state = "start"
	hud.show_start()

func toggle_pause() -> void:
	if state == "playing":
		state = "paused"
		dragging = false
		joy_active = false
		joy_dir = Vector2.ZERO
		joy_mag = 0.0
		hud.show_pause()
	elif state == "paused":
		state = "playing"
		hud.hide_pause()

# ------------------------------------------------------------
# XP / LEVELS
# ------------------------------------------------------------
var xp_level := 1
var xp_current := 0
var xp_to_next := 10

func gain_xp(amount: int) -> void:
	xp_current += int(round(amount * xp_mult))
	while xp_current >= xp_to_next:
		xp_current -= xp_to_next
		xp_level += 1
		xp_to_next = Data.xp_required(xp_level)
		pending_level_ups += 1
	if pending_level_ups > 0 and state != "levelup":
		trigger_level_up()
	hud.update_xp()

func trigger_level_up() -> void:
	if pending_level_ups <= 0:
		return
	pending_level_ups -= 1
	state = "levelup"
	time_scale = 0.0
	var pool: Array = weapon_system.get_cards()
	if pool.is_empty():
		# Keep utility upgrades as a fallback once the loadout is complete.
		pool = Data.UPGRADES.filter(func(up): return _is_upgrade_available(up.id))
		pool.shuffle()
		pool = pool.slice(0, mini(3, pool.size()))
	hud.show_levelup(pool)
	hud.toast("LEVEL %d!" % xp_level, "gold")

func choose_upgrade(up: Dictionary) -> void:
	if up.has("kind"):
		weapon_system.apply_card(up)
		upgrade_stacks[up.id] = upgrade_stacks.get(up.id, 0) + 1
	else:
		_grant_upgrade(up.id)
	hud.hide_levelup()
	hud.update_weapon()
	test_ability_timer = TEST_ABILITY_DURATION
	hud.toast("%s — TEST 30s" % up.name, "gold")
	if pending_level_ups > 0:
		trigger_level_up()
	else:
		state = "playing"
		time_scale = 1.0

func _is_upgrade_available(id: String) -> bool:
	return upgrade_stacks.get(id, 0) < Data.UPGRADE_MAX_STACKS.get(id, 1)

func _grant_upgrade(id: String) -> bool:
	if not _is_upgrade_available(id):
		return false
	_apply_upgrade(id)
	upgrade_stacks[id] = upgrade_stacks.get(id, 0) + 1
	return true

func _apply_upgrade(id: String) -> void:
	match id:
		"damage": upgrades.damage = min(2.0, upgrades.damage + 0.25)
		"firerate": upgrades.fireRate = min(1.0, upgrades.fireRate + 0.20)
		"multishot": upgrades.multishot = min(4, upgrades.multishot + 1)
		"pierce": upgrades.pierce = min(5, upgrades.pierce + 1)
		"bulletspeed": upgrades.bulletSpeed = min(1.2, upgrades.bulletSpeed + 0.30)
		"maxhp":
			player.max_hp += 1
			heal_player(player.max_hp, "HULL EXPANDED")
		"echogain": upgrades.echoGain = min(2.0, upgrades.echoGain + 0.50)
		"critchance": upgrades.critChance = min(0.60, upgrades.critChance + 0.15)
		"magnet": upgrades.magnet = min(1.6, upgrades.magnet + 0.40)
		"movespeed": upgrades.moveSpeed = min(0.60, upgrades.moveSpeed + 0.15)
		"rewind": player.rewind_charges += 1
		"echoduration": upgrades.echoDuration = min(4.5, upgrades.echoDuration + 1.5)
		"lifesteal": upgrades.lifesteal = min(0.20, upgrades.lifesteal + 0.05)

func _expire_test_abilities() -> void:
	test_ability_timer = 0.0
	upgrades = {
		"damage": 0.0, "fireRate": 0.0, "multishot": 0, "pierce": 0, "bulletSpeed": 0.0,
		"echoGain": 0.0, "critChance": 0.0, "magnet": 0.0, "moveSpeed": 0.0,
		"echoDuration": 0.0, "lifesteal": 0.0,
	}
	upgrade_stacks.clear()
	player.max_hp = Data.PLAYER.max_hp - greed_hp_penalty()
	player.hp = mini(player.hp, player.max_hp)
	player.rewind_charges = mini(player.rewind_charges, Data.ECHO.rewind_charges)
	if weapon_system:
		weapon_system.reset_run()
		hud.update_weapon()
	hud.toast("TEST ABILITIES EXPIRED", "warning")

# ------------------------------------------------------------
# MAIN LOOP
# ------------------------------------------------------------
func _process(delta: float) -> void:
	var raw_dt: float = min(0.05, delta)
	if state == "playing" or state == "dying":
		update(raw_dt)
	# camera always tracks (also during dying / levelup for nice framing)
	_update_camera(raw_dt)
	if player: player.queue_redraw()
	hud.refresh()

func _update_camera(raw_dt: float) -> void:
	if player:
		var f := 1.0 - pow(1.0 - CAM_FOLLOW, raw_dt * 60.0)
		cam += (player.position - cam) * f
	var shake := Vector2.ZERO
	if screen_shake > 0:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * screen_shake * 14.0
	camera.position = cam + shake
	camera.zoom = Vector2(zoom_pulse, zoom_pulse)

func update(raw_dt: float) -> void:
	if hit_pause > 0:
		hit_pause -= raw_dt
		return
	var dt := raw_dt * time_scale
	time += dt
	objective_toast_timer = maxf(0.0, objective_toast_timer - raw_dt)
	player.time = time
	zoom_pulse += (1.0 - zoom_pulse) * 0.15

	if rewind_active:
		rewind_timer -= raw_dt
		if rewind_timer <= 0: rewind_active = false
		return

	if echo_phase:
		echo_phase_timer -= raw_dt
		if echo_phase_timer <= 0: end_echo_phase()
	if not echo_phase and player.echo_meter >= Data.ECHO.meter_max:
		trigger_echo_phase()

	_update_movement(raw_dt, dt)
	weapon_system.update(dt)
	if test_ability_timer > 0.0:
		test_ability_timer -= raw_dt
		if test_ability_timer <= 0.0:
			_expire_test_abilities()

	if combo > 1:
		combo_timer -= raw_dt
		if combo_timer <= 0: combo = 1

	# wave spawn queue
	wave_timer += raw_dt
	while wave_spawn_queue.size() > 0 and wave_spawn_queue[0].time <= wave_timer:
		var s = wave_spawn_queue.pop_front()
		spawn_enemy(s.type, s.pos)

	# wave transition (paused while a warning banner is announcing a spawn)
	if wave_spawn_queue.is_empty() and enemies.is_empty() and boss == null and not _pending:
		if wave_transition < 0:
			wave_transition = 1.8
		else:
			wave_transition -= raw_dt
			if wave_transition <= 0:
				wave_transition = -1.0
				start_wave(wave + 1)
	else:
		wave_transition = -1.0

	# entities
	_rebuild_enemy_grid()
	for e in enemies: e.update(dt)
	if boss: boss.update(dt)
	if world_boss: world_boss.update(dt)
	update_landmarks(raw_dt)

	_update_bullets(dt)
	_update_enemy_bullets(dt)
	update_xp_gems(dt)
	update_health_pickups(dt)
	update_particles(raw_dt)
	check_collisions()

	# cull far entities
	var pp: Vector2 = player.position
	_cull(enemies, pp)

	# elites every 30s
	elite_timer += raw_dt
	var elite_interval: float = Data.ELITE_INTERVAL / 2.0 if current_modifier == "hunt" else Data.ELITE_INTERVAL
	if elite_timer >= elite_interval and boss == null and world_boss == null and not _pending:
		elite_timer = 0.0
		_announce_then("⚠ ELITE INCOMING", Data.AMBER, func(): spawn_elite())

	# Safety timer: advance the same Codex order used by wave bosses.
	boss_timer += raw_dt
	if boss_timer >= Data.BOSS_INTERVAL and boss == null and world_boss == null and wave_spawn_queue.is_empty() and not _pending:
		boss_timer = 0.0
		var encounter := wave / 5 + 1
		var boss_id: String = BossCatalogScript.id_for_encounter(encounter)
		var bname: String = BossCatalogScript.DEFINITIONS[boss_id].name
		_announce_then("⚠ WARNING\n" + bname, Data.MAGENTA, func(): _spawn_boss_id(boss_id))

	if screen_shake > 0:
		screen_shake = max(0.0, screen_shake - raw_dt * 2.0)

	# rewind snapshots
	snap_timer -= raw_dt
	if snap_timer <= 0:
		take_snapshot()
		snap_timer = 0.1

func _cull(arr: Array, _pp: Vector2) -> void:
	# Enemies are NOT removed by distance anymore (they re-engage from the spawn
	# ring instead of vanishing). Only sweep out ones flagged for removal.
	var keep: Array = []
	for e in arr:
		if e.remove:
			e.queue_free()
		else:
			keep.append(e)
	arr.assign(keep)

func _enemy_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / ENEMY_GRID_SIZE), floori(pos.y / ENEMY_GRID_SIZE))

func _rebuild_enemy_grid() -> void:
	enemy_grid.clear()
	for enemy in enemies:
		if enemy.remove:
			continue
		var cell := _enemy_cell(enemy.position)
		if not enemy_grid.has(cell):
			enemy_grid[cell] = []
		enemy_grid[cell].append(enemy)

func nearby_enemies(pos: Vector2, radius := ENEMY_GRID_SIZE) -> Array:
	var result: Array = []
	var center := _enemy_cell(pos)
	var safe_radius := clampf(radius, ENEMY_GRID_SIZE, ENEMY_GRID_SIZE * 8.0)
	var reach := clampi(ceili(safe_radius / ENEMY_GRID_SIZE), 1, 8)
	for x in range(center.x - reach, center.x + reach + 1):
		for y in range(center.y - reach, center.y + reach + 1):
			var cell := Vector2i(x, y)
			if enemy_grid.has(cell):
				result.append_array(enemy_grid[cell])
	return result

# ------------------------------------------------------------
# MOVEMENT
# ------------------------------------------------------------
func _update_movement(raw_dt: float, _dt: float) -> void:
	var p := player
	var move_mult: float = (1.0 + upgrades.moveSpeed) * player_speed_mult()
	if weapon_system:
		move_mult *= weapon_system.movement_multiplier()
	var desired_velocity := Vector2.ZERO

	if control_mode == "joystick":
		# Curved analog response gives precision near center without sacrificing
		# full-speed movement at the edge.
		var response := joy_mag * joy_mag * (3.0 - 2.0 * joy_mag)
		desired_velocity = joy_dir * JOY_MAX_SPEED * move_mult * response
		p.target = p.position
	else:
		var d := p.target - p.position
		if d.length() > 1.0:
			var chase_gain := 12.0 if control_mode == "direct" else 7.0
			desired_velocity = d.limit_length(FOLLOW_MAX_SPEED * move_mult) * chase_gain
			desired_velocity = desired_velocity.limit_length(FOLLOW_MAX_SPEED * move_mult)

	var response_rate := MOVE_BRAKE if desired_velocity.length_squared() < p.vel.length_squared() else MOVE_ACCEL
	var response_factor := 1.0 - exp(-response_rate * raw_dt)
	p.vel = p.vel.lerp(desired_velocity, response_factor)
	if desired_velocity == Vector2.ZERO and p.vel.length() < 4.0:
		p.vel = Vector2.ZERO
	p.position += p.vel * raw_dt

	# banking
	var target_bank: float = clamp(-p.vel.x * 0.0012, -Data.PLAYER.max_bank, Data.PLAYER.max_bank)
	p.bank += (target_bank - p.bank) * Data.PLAYER.bank_smoothing

	# aim toward nearest threat
	var nearest = _nearest_target(p.position)
	var target_angle := -PI / 2
	if nearest != null:
		target_angle = (nearest.position - p.position).angle()
	var diff := wrapf(target_angle - p.aim_angle, -PI, PI)
	p.aim_angle += diff * Data.PLAYER.angle_smoothing

	# engine trail
	if fmod(time, 0.05) < 0.02:
		p.engine_trail.append({"pos": p.position + Vector2(0, Data.PLAYER.size * 0.4), "life": 0.3, "max_life": 0.3})
		if p.engine_trail.size() > 8: p.engine_trail.pop_front()
	for t in p.engine_trail: t.life -= raw_dt
	p.engine_trail = p.engine_trail.filter(func(t): return t.life > 0)

	if p.invuln > 0: p.invuln -= raw_dt
	if p.shield_timer > 0: p.shield_timer -= raw_dt

	# confine the ship inside the boss arena (can't fly away from the fight)
	if arena_active:
		var off := p.position - arena_center
		if off.length() > arena_radius:
			p.position = arena_center + off.normalized() * arena_radius
			p.target = p.position
			p.vel = p.vel.slide(off.normalized()) * 0.35
			joy_mag = 0.0

func _nearest_target(from: Vector2):
	var best = null
	var best_d := INF
	for e in enemies:
		var dd: float = e.position.distance_to(from)
		if dd < best_d: best_d = dd; best = e
	if boss and boss.phase > 0:
		var dd: float = boss.position.distance_to(from)
		if dd < best_d: best_d = dd; best = boss
	if world_boss:
		var dd: float = world_boss.position.distance_to(from)
		if dd < best_d: best = world_boss
	return best

# ------------------------------------------------------------
# FIRE
# ------------------------------------------------------------
func _update_fire(dt: float) -> void:
	var p := player
	var w: Dictionary = Data.WEAPONS[p.weapon_idx]
	var eff_rate: float = w.fire_rate * (1.0 + upgrades.fireRate)
	var interval := 1.0 / eff_rate
	p.fire_accum += dt
	while p.fire_accum >= interval:
		p.fire_accum -= interval
		_fire_weapon(w)
		Audio.shoot(w.id)

func _fire_weapon(w: Dictionary) -> void:
	var p := player
	var target = _nearest_target(p.position)
	var base_ang := -PI / 2
	if target != null:
		base_ang = (target.position - p.position).angle()
	var extra: int = upgrades.multishot

	match w.behavior:
		"single":
			fire_bullet(base_ang, w)
			for i in range(1, extra + 1):
				var off: float = 0.18 * ceil(i / 2.0) * (1.0 if i % 2 == 1 else -1.0)
				fire_bullet(base_ang + off, w)
		"pierce":
			var b := fire_bullet(base_ang, w)
			b.pierce = w.pierce_max + upgrades.pierce
			for i in range(1, extra + 1):
				var off: float = 0.18 * ceil(i / 2.0) * (1.0 if i % 2 == 1 else -1.0)
				var b2 := fire_bullet(base_ang + off, w)
				b2.pierce = w.pierce_max + upgrades.pierce
		"spread":
			var total: int = w.spread_count + extra
			for i in total:
				var off: float = (i - (total - 1) / 2.0) * w.spread_angle
				fire_bullet(base_ang + off, w)
		"singularity":
			var b := fire_bullet(base_ang, w)
			b.is_singularity = true
			b.singularity_radius = w.singularity_radius
			b.singularity_duration = w.singularity_duration
			b.singularity_pull = w.singularity_pull

func fire_bullet(ang: float, w: Dictionary) -> Bullet:
	_trim_player_bullets()
	var dmg_mult: float = 1.0 + upgrades.damage
	var spd_mult: float = 1.0 + upgrades.bulletSpeed
	var b := Bullet.new()
	b.is_critical = randf() < clampf(upgrades.critChance, 0.0, 0.60)
	b.friendly = true
	b.position = player.position + Vector2(0, -Data.PLAYER.size)
	b.prev_position = b.position
	b.vel = Vector2(cos(ang), sin(ang)) * w.bullet_speed * spd_mult
	b.size = w.bullet_size
	b.damage = w.damage * dmg_mult * (3.0 if b.is_critical else 1.0)
	b.color = w.color
	b.life = 1.2 if w.behavior == "pierce" else 2.0
	b.is_beam = (w.behavior == "pierce")
	b.z_index = 15
	world.add_child(b)
	bullets.append(b)
	return b

func _trim_player_bullets() -> void:
	while bullets.size() >= MAX_PLAYER_BULLETS:
		var oldest = bullets.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

# ------------------------------------------------------------
# BULLET SIM
# ------------------------------------------------------------
func _update_bullets(dt: float) -> void:
	var pp: Vector2 = player.position
	var keep: Array = []
	for b in bullets:
		b.set_time(time)
		b.prev_position = b.position
		if b.homing_turn_rate > 0.0:
			if b.target == null or not is_instance_valid(b.target):
				b.target = _nearest_target(b.position)
			if b.target != null:
				var desired: float = (b.target.position - b.position).angle()
				var current: float = b.vel.angle()
				var turn: float = clampf(wrapf(desired - current, -PI, PI),
					-b.homing_turn_rate * dt, b.homing_turn_rate * dt)
				b.vel = Vector2.from_angle(current + turn) * b.vel.length()
		if b.is_gravity_mine and not b.singularity_activated:
			b.mine_arm_time -= dt
			b.life -= dt
			if b.mine_arm_time <= 0.0:
				_activate_singularity(b, false)
				screen_shake = maxf(screen_shake, 0.12)
			b.queue_redraw()
			if b.life > 0.0:
				keep.append(b)
			else:
				b.queue_free()
			continue
		if b.is_ring:
			b.ring_radius = min(b.ring_max_radius, b.ring_radius + b.ring_speed * dt)
			b.life -= dt
			for e in enemies:
				if e.remove: continue
				var d: float = e.position.distance_to(b.position)
				if b.field_dps > 0.0:
					if d <= b.ring_radius + e.size:
						_damage_enemy(e, b.field_dps * dt, b)
				elif not b.ring_hits.has(e) and abs(d - b.ring_radius) <= e.size + max(8.0, b.ring_speed * dt):
					_damage_enemy(e, b.damage, b)
					b.ring_hits.append(e)
			if boss and boss.phase > 0 and not b.ring_hits.has(boss):
				var boss_dist: float = boss.position.distance_to(b.position)
				if b.field_dps > 0.0 and boss_dist <= b.ring_radius + boss.size:
					damage_boss(b.field_dps * dt * b.boss_damage_mult, b)
				elif abs(boss_dist - b.ring_radius) <= boss.size + 10.0:
					damage_boss(b.damage * b.boss_damage_mult, b)
					b.ring_hits.append(boss)
			b.queue_redraw()
			if b.life > 0: keep.append(b)
			else: b.queue_free()
			continue
		if b.is_singularity and b.singularity_activated:
			b.singularity_duration -= dt
			for e in enemies:
				if e.remove: continue
				var ed: float = e.position.distance_to(b.position)
				if ed < b.singularity_radius and ed > 5:
					var pull: Vector2 = (b.position - e.position).normalized()
					var force: float = (1.0 - ed / b.singularity_radius) * b.singularity_pull
					e.position += pull * force * dt
					_damage_enemy(e, b.damage * dt, b)
			if boss and boss.phase > 0:
				var bd: float = boss.position.distance_to(b.position)
				if bd < b.singularity_radius:
					damage_boss(b.damage * dt * 0.35, b)
			if world_boss:
				var wd: float = world_boss.position.distance_to(b.position)
				if wd < b.singularity_radius:
					damage_world_boss(b.damage * dt * 0.35)
			for eb in enemy_bullets:
				var ed: float = eb.position.distance_to(b.position)
				if ed < b.singularity_radius and ed > 5:
					eb.vel += (b.position - eb.position).normalized() * 300.0 * dt
					if b.destroys_enemy_bullets and ed < b.singularity_radius * 0.25:
						eb.hit = true
			if b.singularity_duration <= 0:
				if b.detonation_damage > 0.0:
					var old_damage: float = b.damage
					var old_radius: float = b.splash_radius
					b.damage = b.detonation_damage
					b.splash_radius = b.detonation_radius
					b.splash_factor = 1.0
					_splash_damage(b.position, b)
					b.damage = old_damage
					b.splash_radius = old_radius
				b.life = 0
		else:
			b.trail.append(b.position)
			if b.trail.size() > 3: b.trail.pop_front()
			b.position += b.vel * dt
			b.life -= dt
			if b.position.distance_to(pp) > Data.CULL_DISTANCE: b.life = 0
		b.queue_redraw()
		if b.life > 0 and not b.hit:
			keep.append(b)
		else:
			b.queue_free()
	bullets.assign(keep)

func _update_enemy_bullets(dt: float) -> void:
	var pp: Vector2 = player.position
	var keep: Array = []
	for b in enemy_bullets:
		b.set_time(time)
		b.position += b.vel * dt
		b.life -= dt
		if b.life > 0 and not b.hit and b.position.distance_to(pp) <= Data.CULL_DISTANCE:
			keep.append(b)
		else:
			b.queue_free()
	enemy_bullets.assign(keep)

# ------------------------------------------------------------
# COLLISIONS
# ------------------------------------------------------------
func check_collisions() -> void:
	var p := player
	for b in bullets:
		if b.hit or b.singularity_activated: continue
		if b.is_gravity_mine: continue
		# boss
		if boss and boss.phase > 0 and not b.pierce_hits.has(boss):
			if _bullet_hits(b, boss.position, boss.size + b.size):
				damage_boss(b.damage * b.boss_damage_mult, b)
				_splash_damage(b.position, b, boss)
				if b.is_singularity:
					_activate_singularity(b)
				elif b.pierce > 0:
					b.pierce -= 1
					b.pierce_hits.append(boss)
				else:
					b.hit = true
				spawn_particles(b.position, Data.AMBER, 5, 2.0)
				if b.hit or b.singularity_activated: continue
		# world mini-boss
		if world_boss and not b.pierce_hits.has(world_boss):
			if _bullet_hits(b, world_boss.position, world_boss.size + b.size):
				damage_world_boss(b.damage * b.boss_damage_mult)
				_splash_damage(b.position, b, world_boss)
				if b.is_singularity:
					_activate_singularity(b)
				elif b.pierce > 0:
					b.pierce -= 1
					b.pierce_hits.append(world_boss)
				else:
					b.hit = true
				spawn_particles(b.position, world_boss.color, 5, 2.0)
				if b.hit or b.singularity_activated: continue
		# enemies
		for e in enemies:
			if e.remove or b.pierce_hits.has(e): continue
			if _bullet_hits(b, e.position, e.size + b.size):
				if e.behavior == "shield" and e.shield_hp > 0 and not e.shield_open:
					var ang_to: float = (b.position - e.position).angle()
					var ad := wrapf(ang_to - e.shield_angle, -PI, PI)
					if abs(ad) < PI / 2:
						e.shield_hp -= b.damage
						if b.pierce > 0: b.pierce -= 1; b.pierce_hits.append(e)
						else: b.hit = true
						spawn_particles(b.position, Data.AMBER, 6, 2.0)
						if not b.hit: continue
						break
				var dmg_mult: float = Data.SPAWN_PROTECTION_MULT if e.spawn_protect > 0 else 1.0
				_damage_enemy(e, b.damage * dmg_mult, b)
				_splash_damage(b.position, b, e)
				if b.is_singularity and not b.singularity_activated:
					_activate_singularity(b)
				elif b.pierce > 0:
					b.pierce -= 1; b.pierce_hits.append(e)
				else:
					b.hit = true
				spawn_particles(b.position, e.color, 5, 2.0)
				var shown_damage := int(round(b.damage * dmg_mult))
				var damage_text := "CRIT %d" % shown_damage if b.is_critical else str(shown_damage)
				spawn_damage_number(b.position, damage_text, Data.AMBER, b.is_critical)
				Audio.hit()
				if b.hit or b.singularity_activated: break

	# player hit
	if p.invuln <= 0 and not rewind_active:
		for b in enemy_bullets:
			if b.hit: continue
			if b.position.distance_to(p.position) < Data.PLAYER.size + b.size:
				b.hit = true
				damage_player()
				break
		for e in enemies:
			if e.remove: continue
			if e.position.distance_to(p.position) < Data.PLAYER.size + e.size:
				damage_player()
				if e.behavior == "dive" and e.state == "diving":
					e.remove = true
					spawn_particles(e.position, e.color, 12, 4.0)
				break
		if boss and boss.phase > 0:
			if boss.position.distance_to(p.position) < Data.PLAYER.size + boss.size:
				damage_player()
		if world_boss:
			if world_boss.position.distance_to(p.position) < Data.PLAYER.size + world_boss.size:
				damage_player()

	# purge hit bullets immediately
	bullets = bullets.filter(func(b):
		if b.hit and is_instance_valid(b): b.queue_free()
		return not b.hit)
	enemy_bullets = enemy_bullets.filter(func(b):
		if b.hit and is_instance_valid(b): b.queue_free()
		return not b.hit)
	var kept: Array = []
	for e in enemies:
		if e.remove: e.queue_free()
		else: kept.append(e)
	enemies = kept

func _bullet_hits(b: Bullet, target_pos: Vector2, hit_radius: float) -> bool:
	# Swept segment collision prevents fast shots from skipping small targets on
	# low-FPS frames or while both ship and enemy are moving laterally.
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target_pos, b.prev_position, b.position)
	return closest.distance_squared_to(target_pos) <= hit_radius * hit_radius

# ------------------------------------------------------------
# KILL / DAMAGE
# ------------------------------------------------------------
func _activate_singularity(b: Bullet, announce := true) -> void:
	b.singularity_activated = true
	b.vel = Vector2.ZERO
	b.life = b.singularity_duration + 0.1
	spawn_particles(b.position, Data.PURPLE, 30, 6.0)
	if announce:
		hud.toast("SINGULARITY ACTIVE", "green")

func _damage_enemy(e: Enemy, amount: float, source: Bullet = null) -> void:
	if e.remove:
		return
	e.hp -= amount
	e.hit_flash = 0.1
	if source:
		if source.knockback > 0.0:
			var away := (e.position - source.position).normalized()
			e.position += away * source.knockback
		if source.burn_duration > 0.0:
			e.burn_timer = max(e.burn_timer, source.burn_duration)
			e.burn_dps = max(e.burn_dps, source.burn_dps)
		if source.weapon_id == "gravity":
			e.slow_timer = max(e.slow_timer, 0.3)
			e.slow_factor = min(e.slow_factor, 0.5)
	if e.hp <= 0:
		kill_enemy(e, source.is_critical if source else false)

func _splash_damage(center: Vector2, source: Bullet, primary = null) -> void:
	if source.splash_radius <= 0.0:
		return
	for e in enemies:
		if e.remove or e == primary:
			continue
		if e.position.distance_to(center) <= source.splash_radius + e.size:
			_damage_enemy(e, source.damage * source.splash_factor, source)
	if boss and boss != primary and boss.phase > 0 and boss.position.distance_to(center) <= source.splash_radius + boss.size:
		damage_boss(source.damage * source.splash_factor * source.boss_damage_mult, source)
	if world_boss and world_boss != primary and world_boss.position.distance_to(center) <= source.splash_radius + world_boss.size:
		damage_world_boss(source.damage * source.splash_factor * source.boss_damage_mult)

func active_score_mult() -> float:
	return score_mult() * (2.0 if echo_phase else 1.0)

func kill_enemy(e: Enemy, is_crit := false) -> void:
	if e.remove: return
	e.remove = true
	kill_count += 1
	spawn_particles(e.position, e.color, 18, 3.0)
	spawn_particles(e.position, Data.WHITE, 8, 2.0)
	if is_crit:
		spawn_particles(e.position, Data.AMBER, 20, 4.0)
		spawn_damage_number(e.position + Vector2(0, -10), "CRIT!", Data.AMBER, true)
	if e.is_elite:
		spawn_particles(e.position, Data.AMBER, 30, 6.0)
		spawn_particles(e.position, Data.MAGENTA, 20, 8.0)
	spawn_decal(e.position, 12.0, e.color)
	var gain := int(round(e.score_value * combo * active_score_mult()))
	score += gain
	combo += 1
	if combo > max_combo: max_combo = combo
	combo_timer = 3.5
	spawn_damage_number(e.position, str(gain), Data.AMBER, true)
	var echo_gain: float = Data.ECHO.meter_per_kill * (1.0 + upgrades.echoGain) + (3.0 if is_crit else 0.0)
	player.echo_meter = min(Data.ECHO.meter_max, player.echo_meter + echo_gain)
	Audio.kill()
	hit_pause = max(hit_pause, 0.08 if is_crit else 0.04)
	zoom_pulse = max(zoom_pulse, 1.04 if is_crit else 1.025)
	var elite_xp_mult := 2.0 if current_modifier == "hunt" and e.is_elite else 1.0
	spawn_xp_gem(e.position, int(round(e.xp_value * enemy_xp_mult() * elite_xp_mult)))
	if upgrades.lifesteal > 0 and randf() < upgrades.lifesteal:
		heal_player(1, "LIFESTEAL")

func heal_player(amount: int, source := "HEALED") -> int:
	var before := player.hp
	player.hp = mini(player.max_hp, player.hp + amount)
	var restored := player.hp - before
	hud.flash_heal()
	spawn_particles(player.position, Data.GREEN, 22, 4.0)
	spawn_particles(player.position, Data.WHITE, 8, 2.0)
	if restored > 0:
		spawn_damage_number(player.position + Vector2(0, -24), "+%d HP" % restored, Data.GREEN, true)
		hud.toast("%s  +%d HP" % [source, restored])
	return restored

func damage_player(amount: int = 1) -> void:
	var p := player
	if p.invuln > 0: return
	if p.shield_timer > 0:
		p.shield_timer = 0.0
		p.invuln = 1.2
		spawn_particles(p.position, Data.CYAN_SOFT, 16, 4.0)
		hud.toast("SHIELD ABSORBED")
		return
	p.hp -= amount
	p.invuln = 1.2
	combo = 1; combo_timer = 0.0
	screen_shake = 0.6
	hit_pause = 0.08
	zoom_pulse = 0.97
	p.echo_meter = max(0.0, p.echo_meter - Data.ECHO.meter_per_hit)
	spawn_particles(p.position, Data.MAGENTA, 20, 4.0)
	Audio.damage()
	hud.flash_damage()
	if p.hp <= 0:
		if p.rewind_charges > 0 and rewind_snapshots.size() >= 5:
			trigger_rewind()
		else:
			play_death()

# ------------------------------------------------------------
# ECHO PHASE / REWIND
# ------------------------------------------------------------
func trigger_echo_phase() -> void:
	if echo_phase: return
	echo_phase = true
	echo_phase_timer = Data.ECHO.phase_duration + upgrades.echoDuration
	time_scale = Data.ECHO.phase_time_scale
	player.echo_meter = 0.0
	zoom_pulse = 1.06
	hud.toast("ECHO PHASE — 2x SCORE", "gold")
	hud.set_echo_overlay(true)
	Audio.echo_phase()

func end_echo_phase() -> void:
	echo_phase = false
	time_scale = 1.0
	hud.set_echo_overlay(false)

func take_snapshot() -> void:
	rewind_snapshots.push_front({"pos": player.position})
	if rewind_snapshots.size() > 30: rewind_snapshots.pop_back()

func trigger_rewind() -> void:
	if player.rewind_charges <= 0 or rewind_snapshots.size() < 5: return
	player.rewind_charges -= 1
	rewind_active = true
	rewind_timer = 1.2
	player.hp = 1
	player.invuln = 1.8
	hit_pause = 0.0
	var snap = rewind_snapshots[rewind_snapshots.size() - 1]
	player.position = snap.pos
	player.target = snap.pos
	enemy_bullets = enemy_bullets.filter(func(b):
		var rm: bool = b.position.distance_to(snap.pos) < 140
		if rm: b.queue_free()
		return not rm)
	var kept: Array = []
	for e in enemies:
		if e.position.distance_to(snap.pos) < 100:
			spawn_particles(e.position, e.color, 14, 2.0)
			e.queue_free()
		else: kept.append(e)
	enemies = kept
	hud.flash_rewind()
	hud.toast("ECHO REWIND", "gold")
	Audio.rewind()

# ------------------------------------------------------------
# DEATH
# ------------------------------------------------------------
func play_death() -> void:
	if state == "dying": return
	state = "dying"
	time_scale = 0.3
	screen_shake = 1.2
	spawn_particles(player.position, Data.AMBER, 60, 8.0)
	spawn_particles(player.position, Data.MAGENTA, 40, 10.0)
	spawn_particles(player.position, Data.WHITE, 30, 6.0)
	hud.flash_death()
	await get_tree().create_timer(1.4).timeout
	time_scale = 1.0
	finalize_game_over()

func finalize_game_over() -> void:
	state = "gameover"
	if score > high_score:
		high_score = score
		_save_high_score()
	hud.show_gameover()

# ------------------------------------------------------------
# WAVES / SPAWNING
# ------------------------------------------------------------
func start_wave(n: int) -> void:
	wave = n
	wave_timer = 0.0
	wave_spawn_queue.clear()
	hud.show_wave_intro(n)
	if n > 1: Audio.wave_start()
	if n % 5 == 0:
		var encounter := n / 5
		var boss_id: String = BossCatalogScript.id_for_encounter(encounter)
		var bname: String = BossCatalogScript.DEFINITIONS[boss_id].name
		_announce_then("⚠ WARNING\n" + bname, Data.MAGENTA, _spawn_boss_id.bind(boss_id))
		return
	var patterns := generate_wave_pattern(n)
	var t := 0.0
	for pat in patterns:
		t = spawn_wave_pattern(pat, t)

func generate_wave_pattern(w: int) -> Array:
	var patterns: Array = []
	var count: int = min(80, int(round((15 + w * 4) * wave_count_mult())))
	if w % 5 == 0:
		patterns.append({"type": "line", "count": 10, "enemy": "drone"})
	elif w == 1:
		patterns.append({"type": "random", "count": count, "enemy": "drone"})
	elif w == 2:
		patterns.append({"type": "random", "count": int(count * 0.65), "enemy": "drone"})
		patterns.append({"type": "vortex", "count": int(count * 0.35), "enemy": "weaver"})
	elif w < 6:
		patterns.append({"type": "random", "count": int(count * 0.4), "enemy": "drone"})
		patterns.append({"type": "vortex", "count": int(count * 0.25), "enemy": "weaver"})
		patterns.append({"type": "circle", "count": int(count * 0.2), "enemy": "skimmer"})
		patterns.append({"type": "line", "count": int(count * 0.15), "enemy": "diver"})
	elif w < 10:
		patterns.append({"type": "vortex", "count": int(count * 0.3), "enemy": "weaver"})
		patterns.append({"type": "circle", "count": int(count * 0.25), "enemy": "skimmer"})
		patterns.append({"type": "random", "count": int(count * 0.2), "enemy": "drone"})
		patterns.append({"type": "line", "count": int(count * 0.15), "enemy": "lancer"})
		patterns.append({"type": "random", "count": int(count * 0.1), "enemy": "diver"})
	else:
		patterns.append({"type": "vortex", "count": int(count * 0.25), "enemy": "weaver"})
		patterns.append({"type": "circle", "count": int(count * 0.2), "enemy": "skimmer"})
		patterns.append({"type": "random", "count": int(count * 0.15), "enemy": "drone"})
		patterns.append({"type": "cross", "count": int(count * 0.2), "enemy": "diver"})
		patterns.append({"type": "circle", "count": int(count * 0.2), "enemy": "bulwark"})
	return patterns

func spawn_wave_pattern(pat: Dictionary, base_time: float) -> float:
	var c: Vector2 = player.position
	var t := base_time
	var interval := 0.08
	var diag := view_size.length()
	var ring_min := diag * Data.SPAWN_RING_MIN
	var ring_max := diag * Data.SPAWN_RING_MAX
	var et: String = pat.enemy
	match pat.type:
		"random":
			for i in pat.count:
				var ang := randf() * TAU
				var r := ring_min + randf() * (ring_max - ring_min)
				wave_spawn_queue.append({"time": t, "type": et, "pos": c + Vector2(cos(ang), sin(ang)) * r})
				t += interval + randf() * 0.15
		"circle":
			var radius := (ring_min + ring_max) / 2.0
			for i in pat.count:
				var ang: float = (float(i) / pat.count) * TAU
				wave_spawn_queue.append({"time": t, "type": et, "pos": c + Vector2(cos(ang), sin(ang)) * radius})
				t += interval
		"line":
			var line_x := c.x + (randf() - 0.5) * 200.0
			var start_y := c.y - ring_max
			for i in pat.count:
				wave_spawn_queue.append({"time": t, "type": et, "pos": Vector2(line_x, start_y - i * 35.0)})
				t += interval * 1.5
		"vortex":
			for i in pat.count:
				var ang: float = (float(i) / pat.count) * PI * 6.0
				var r: float = ring_min + (float(i) / pat.count) * (ring_max - ring_min)
				wave_spawn_queue.append({"time": t, "type": et, "pos": c + Vector2(cos(ang), sin(ang)) * r})
				t += interval
		"cross":
			var per_line: int = int(pat.count / 4)
			var arm_len := per_line * 40.0
			for dir in 4:
				for i in per_line:
					var off := ring_min + i * 40.0
					var pos: Vector2
					if dir == 0: pos = Vector2(c.x - off, c.y - arm_len / 2 + i * 40.0)
					elif dir == 1: pos = Vector2(c.x + off, c.y - arm_len / 2 + i * 40.0)
					elif dir == 2: pos = Vector2(c.x - arm_len / 2 + i * 40.0, c.y - off)
					else: pos = Vector2(c.x - arm_len / 2 + i * 40.0, c.y + off)
					wave_spawn_queue.append({"time": t, "type": et, "pos": pos})
					t += interval
	return t

func spawn_enemy(type: String, pos: Vector2) -> Enemy:
	var def: Dictionary = Data.ENEMY_BASE[type]
	var scaled: float = round(Data.scale_enemy_hp(def.hp, wave) * enemy_hp_mult())
	var e := Enemy.new()
	e.main = self
	e.position = pos
	e.type = type
	e.hp = scaled; e.max_hp = scaled
	e.size = def.size; e.color = def.color
	e.speed = def.speed * enemy_speed_mult(); e.score_value = def.score
	e.xp_value = def.xp
	e.spawn_protect = Data.SPAWN_PROTECTION
	match type:
		"drone":
			e.behavior = "drift"; e.drift_angle = randf() * TAU
		"weaver":
			e.behavior = "weave"; e.weave_phase = randf() * TAU
		"skimmer":
			e.behavior = "strafe"; e.orbit_dir = -1.0 if randf() < 0.5 else 1.0
			e.preferred_range = randf_range(175.0, 245.0)
			e.fire_timer = randf_range(0.8, 1.8)
		"diver":
			e.behavior = "dive"; e.state = "aiming"; e.aim_time = 0.9; e.dive_speed = 400.0
		"bulwark":
			e.behavior = "shield"; e.shield_hp = Data.scale_enemy_hp(def.shield_hp, wave); e.shield_angle = -PI / 2
		"lancer":
			e.behavior = "snipe"; e.state = "positioning"; e.beam_telegraph = 1.2
	e.z_index = 10
	world.add_child(e)
	enemies.append(e)
	request_enemy_intro(type)
	return e

func request_enemy_intro(type: String) -> void:
	if not ENEMY_INTROS.has(type) or introduced_enemies.has(type):
		return
	introduced_enemies[type] = true
	enemy_intro_queue.append(type)
	if state == "playing":
		_show_next_enemy_intro()

func _show_next_enemy_intro() -> void:
	if enemy_intro_queue.is_empty():
		return
	var type: String = enemy_intro_queue.pop_front()
	var info: Dictionary = ENEMY_INTROS[type]
	if state != "enemy_intro":
		enemy_intro_resume_scale = time_scale
	state = "enemy_intro"
	time_scale = 0.0
	dragging = false
	joy_active = false
	joy_mag = 0.0
	hud.show_enemy_intro(info.name, info.icon, info.desc, info.color)

func dismiss_enemy_intro() -> void:
	hud.hide_enemy_intro()
	if not enemy_intro_queue.is_empty():
		_show_next_enemy_intro()
		return
	state = "playing"
	time_scale = enemy_intro_resume_scale

func spawn_enemy_at(type: String, pos: Vector2) -> void:
	spawn_enemy(type, pos)

func spawn_spiral_drone(pos: Vector2, ang: float) -> void:
	var e := Enemy.new()
	e.main = self
	e.position = pos
	e.type = "drone"
	e.hp = 8; e.max_hp = 8; e.size = 10; e.color = Data.CYAN
	e.speed = 180; e.score_value = 50; e.behavior = "spiral_out"
	e.spiral_ang = ang; e.spiral_radius = 60.0
	e.spiral_center = boss.position if boss else pos
	e.z_index = 10
	world.add_child(e)
	enemies.append(e)

func spawn_elite() -> void:
	var types := ["drone", "weaver", "skimmer", "diver", "bulwark", "lancer"]
	var type: String = types[randi() % types.size()]
	var diag := view_size.length()
	var ang := randf() * TAU
	var pos: Vector2 = player.position + Vector2(cos(ang), sin(ang)) * diag * 0.65
	var e := spawn_enemy(type, pos)
	e.hp *= 5; e.max_hp *= 5
	e.size *= 1.6
	e.score_value *= 5
	e.is_elite = true
	hud.toast("ELITE INBOUND", "warning")

func spawn_enemy_bullet(pos: Vector2, vel: Vector2, size: float, color: Color, damage: int, life: float) -> void:
	while enemy_bullets.size() >= MAX_ENEMY_BULLETS:
		var oldest = enemy_bullets.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var b := Bullet.new()
	b.friendly = false
	b.position = pos
	b.vel = vel
	var hostile_color := color
	var hostile_size := size
	if color.is_equal_approx(Data.PURPLE) or color.is_equal_approx(Data.MAGENTA) \
			or color.is_equal_approx(Data.MAGENTA_SOFT):
		hostile_color = Data.AMBER_SOFT
		hostile_size = maxf(8.0, size * 1.6)
	b.size = hostile_size
	b.color = hostile_color
	b.damage = damage
	b.life = life
	b.z_index = 12
	world.add_child(b)
	enemy_bullets.append(b)

func _spawn_timed_boss() -> void:
	var encounter := wave / 5 + 1
	_spawn_boss_id(BossCatalogScript.id_for_encounter(encounter))

func _spawn_boss_idx(idx: int) -> void:
	if idx == 0: spawn_conductor()
	else: spawn_spiral()

func _spawn_boss_id(id: String) -> void:
	match id:
		"conductor": spawn_conductor()
		"spiral": spawn_spiral()
		_: spawn_codex_boss(id)

func spawn_codex_boss(id: String) -> void:
	if not BossCatalogScript.DEFINITIONS.has(id):
		return
	boss_timer = 0.0
	var b = CodexBossScript.new()
	b.main = self
	b.setup(id, wave)
	var diag := view_size.length()
	b.position = Vector2(player.position.x, player.position.y - diag * 0.5)
	b.z_index = 18
	world.add_child(b)
	boss = b
	_open_arena()
	hud.show_boss_bar(b.boss_name)
	hud.toast("WARNING: %s INBOUND" % b.boss_name, "warning")
	Audio.boss_warn()

func spawn_conductor() -> void:
	boss_timer = 0.0
	boss = Boss.new()
	boss.main = self
	boss.setup_conductor()
	var diag := view_size.length()
	boss.position = Vector2(player.position.x, player.position.y - diag * 0.5)
	boss.z_index = 18
	world.add_child(boss)
	_open_arena()
	hud.show_boss_bar("THE CONDUCTOR")
	hud.toast("WARNING: CONDUCTOR INBOUND", "warning")
	Audio.boss_warn()

func spawn_spiral() -> void:
	boss_timer = 0.0
	boss = Boss.new()
	boss.main = self
	boss.setup_spiral()
	var diag := view_size.length()
	boss.position = Vector2(player.position.x, player.position.y - diag * 0.5)
	boss.z_index = 18
	world.add_child(boss)
	_open_arena()
	hud.show_boss_bar("THE SPIRAL")
	hud.toast("WARNING: SPIRAL INBOUND", "warning")
	Audio.boss_warn()

func _open_arena() -> void:
	arena_active = true
	arena_center = player.position
	# 1.5x the previous arena size.
	arena_radius = min(view_size.x, view_size.y) * 1.89
	arena_health_timer = randf_range(7.0, 12.0)

func damage_boss(amount: float, source: Bullet = null) -> void:
	if boss == null or boss.phase == 0: return
	if boss.has_method("damage_multiplier"):
		amount *= boss.damage_multiplier(source)
		if amount <= 0.0:
			return
	boss.hp -= amount
	if "hit_flash" in boss:
		boss.hit_flash = 0.1
	Audio.boss_hit()
	if boss.hp <= 0:
		defeat_boss(true)

func defeat_boss(grant_reward := true) -> void:
	if boss == null:
		return
	var defeated = boss
	spawn_particles(defeated.position, Data.AMBER, 80, 8.0)
	spawn_particles(defeated.position, Data.MAGENTA, 50, 10.0)
	spawn_particles(defeated.position, Data.WHITE, 30, 6.0)
	spawn_decal(defeated.position, 40.0, Data.AMBER)
	var boss_gain := int(round(6000 * active_score_mult())) if grant_reward else 0
	score += boss_gain
	screen_shake = 1.5
	hit_pause = 0.2
	zoom_pulse = 1.08
	hud.toast("BOSS DEFEATED — +%d" % boss_gain, "gold")
	Audio.boss_kill()
	hud.hide_boss_bar()
	# loot: a generous scattered burst of XP gems so the kill pays off
	if grant_reward:
		var loot := 12 + wave
		for i in loot:
			var ang := randf() * TAU
			var r := 16.0 + randf() * 110.0
			spawn_xp_gem(defeated.position + Vector2(cos(ang), sin(ang)) * r, 4)
		# top off the player as a reward
		heal_player(1, "LOOT RECOVERED")
	defeated.queue_free()
	boss = null
	boss_timer = 0.0
	arena_active = false
	for pickup in health_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	health_pickups.clear()

# ------------------------------------------------------------
# XP GEMS / PICKUPS
# ------------------------------------------------------------
func spawn_xp_gem(pos: Vector2, value: int) -> void:
	if xp_gems.size() >= MAX_XP_GEMS:
		var oldest = xp_gems[0]
		if is_instance_valid(oldest):
			oldest.value += value
			oldest.size = minf(12.0, 5.0 + sqrt(float(oldest.value)))
			oldest.life = 12.0
		return
	var g := XpGem.new()
	g.position = pos
	g.vel = Vector2((randf() - 0.5) * 40.0, -30.0 - randf() * 30.0)
	g.value = value
	g.size = 5.0 + value
	g.z_index = 8
	world.add_child(g)
	xp_gems.append(g)

func update_xp_gems(dt: float) -> void:
	var p := player
	var magnet_r: float = 110.0 + upgrades.magnet * 80.0
	var keep: Array = []
	for g in xp_gems:
		g.t += dt
		g.life -= dt
		var d: float = g.position.distance_to(p.position)
		if d < magnet_r:
			var dir: Vector2 = (p.position - g.position).normalized()
			var force: float = (magnet_r - d) * 8.0
			g.vel += dir * force * dt
		else:
			g.vel.y += g.gravity * dt
			g.vel *= 0.96
		g.position += g.vel * dt
		g.queue_redraw()
		if d < Data.PLAYER.size + 6.0:
			gain_xp(g.value)
			spawn_particles(g.position, Data.GREEN, 4, 2.0)
			Audio.pickup()
			g.queue_free()
		elif g.life <= 0:
			g.queue_free()
		else:
			keep.append(g)
	xp_gems = keep

func spawn_health_pickup() -> void:
	if not arena_active or health_pickups.size() >= 2:
		return
	var angle := randf() * TAU
	var max_spawn_radius := minf(arena_radius * 0.7, view_size.y * 0.34)
	var radius := randf_range(120.0, max_spawn_radius)
	var pickup = HealthPickupScript.new()
	pickup.position = arena_center + Vector2.from_angle(angle) * radius
	pickup.z_index = 11
	world.add_child(pickup)
	health_pickups.append(pickup)
	spawn_particles(pickup.position, Data.GREEN, 18, 3.0)
	hud.toast("REPAIR SIGNAL DETECTED")

func update_health_pickups(dt: float) -> void:
	if arena_active and boss:
		arena_health_timer -= dt
		if arena_health_timer <= 0.0:
			spawn_health_pickup()
			arena_health_timer = randf_range(12.0, 20.0)
	var keep: Array = []
	for pickup in health_pickups:
		pickup.life -= dt
		if pickup.position.distance_to(player.position) < Data.PLAYER.size + pickup.size:
			if player.hp < player.max_hp:
				heal_player(pickup.value, "REPAIR PICKUP")
				spawn_particles(pickup.position, Data.GREEN, 30, 5.0)
				pickup.queue_free()
				continue
		if pickup.life > 0.0 and arena_active:
			keep.append(pickup)
		else:
			pickup.queue_free()
	health_pickups.assign(keep)

# ------------------------------------------------------------
# PARTICLES / FX
# ------------------------------------------------------------
func spawn_particles(pos: Vector2, color: Color, count: int, size_base := 2.0) -> void:
	var available := 150 - particles.size()
	var actual_count := mini(count, maxi(0, available))
	if actual_count <= 0:
		return
	for i in actual_count:
		var ang := randf() * TAU
		var spd := 40.0 + randf() * 160.0
		particles.append({
			"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": 0.5 + randf() * 0.3, "max_life": 0.8,
			"color": color, "size": size_base * (0.6 + randf() * 0.8),
		})

func spawn_decal(pos: Vector2, size: float, color: Color) -> void:
	if decals.size() > 30: decals.pop_front()
	decals.append({"pos": pos, "size": size, "color": color, "life": 6.0, "max_life": 6.0})

func spawn_damage_number(pos: Vector2, text: String, color: Color, big: bool) -> void:
	if damage_numbers.size() > 30: damage_numbers.pop_front()
	damage_numbers.append({
		"pos": pos, "vel": Vector2((randf() - 0.5) * 20.0, -40.0),
		"text": text, "color": color, "big": big, "life": 0.9, "max_life": 0.9})

func update_particles(dt: float) -> void:
	var keep: Array = []
	for p in particles:
		p.life -= dt
		p.pos += p.vel * dt
		p.vel *= 0.92
		if p.life > 0: keep.append(p)
	particles = keep
	var dk: Array = []
	for d in decals:
		d.life -= dt
		if d.life > 0: dk.append(d)
	decals = dk
	var nk: Array = []
	for d in damage_numbers:
		d.life -= dt
		d.pos += d.vel * dt
		if d.life > 0: nk.append(d)
	damage_numbers = nk

# ------------------------------------------------------------
# WEAPONS
# ------------------------------------------------------------
func cycle_weapon() -> void:
	player.weapon_idx = (player.weapon_idx + 1) % max(1, weapon_system.weapons.size())
	hud.update_weapon()
	Audio.weapon_swap()
	var entry: Dictionary = weapon_system.weapons[player.weapon_idx]
	hud.toast(Data.SURVIVOR_WEAPONS[entry.id].name + " FOCUSED", "green")

# ------------------------------------------------------------
# INPUT
# ------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state == "playing" or state == "paused":
			toggle_pause()
		return
	if state != "playing":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			# Claim the first free finger for steering.
			if not dragging:
				drag_index = event.index
				_pointer_down(event.position)
		elif event.index == drag_index:
			_pointer_up(event.position)
	elif event is InputEventScreenDrag and event.index == drag_index:
		_pointer_move(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q, KEY_TAB: cycle_weapon()

func _pointer_down(pos: Vector2) -> void:
	dragging = true
	drag_start = pos; drag_cur = pos
	ship_anchor = player.position
	last_finger = pos
	tap_start_ms = Time.get_ticks_msec()
	swipe_start_y = pos.y
	swipe_start_ms = Time.get_ticks_msec()
	if control_mode == "joystick":
		joy_active = true
		joy_origin = pos
		joy_vec = Vector2.ZERO
		joy_dir = Vector2.ZERO
		joy_mag = 0.0

func _pointer_move(pos: Vector2) -> void:
	if not dragging: return
	drag_cur = pos
	if control_mode == "joystick":
		var off := pos - joy_origin
		joy_vec = off.limit_length(JOY_RADIUS)
		if off.length() > JOY_DEADZONE:
			joy_dir = off.normalized()
			joy_mag = clampf(off.length() / JOY_RADIUS, 0.0, 1.0)
		else:
			joy_dir = Vector2.ZERO
			joy_mag = 0.0
		return
	# Per-frame finger delta — accumulated so the ship never runs out of "reach"
	# (the old anchor+total-delta scheme capped travel to the drag length and
	# made the ship stick mid-screen when you ran out of finger room).
	var fd := pos - last_finger
	last_finger = pos
	var total := pos - drag_start
	# swipe-up weapon swap (only once per drag)
	if swipe_start_y != INF:
		var swipe_dy := pos.y - swipe_start_y
		var elapsed := Time.get_ticks_msec() - swipe_start_ms
		if swipe_dy < -100 and elapsed < 350 and total.length() > 100:
			cycle_weapon()
			swipe_start_y = INF
			return
	if total.length() < Data.PLAYER.deadzone: return
	if control_mode == "direct":
		player.target += fd
	else:
		player.target += fd

func _pointer_up(_pos: Vector2) -> void:
	if not dragging: return
	dragging = false
	drag_index = -1
	joy_active = false
	joy_dir = Vector2.ZERO
	joy_mag = 0.0
	joy_vec = Vector2.ZERO

func show_toast(text: String, variant := "") -> void:
	hud.toast(text, variant)
