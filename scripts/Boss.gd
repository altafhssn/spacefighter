class_name Boss
extends Node2D
## The Conductor and The Spiral.
## Rewritten AI: eased orbit/chase movement (the boss has weight and lags
## behind the player instead of teleport-tracking) + a telegraph→fire→recover
## attack state machine with several aimed and bullet-hell patterns per phase.

var main = null
var vel: Vector2 = Vector2.ZERO

var type := "conductor"
var hp := 700.0
var max_hp := 700.0
var size := 38.0
var age := 0.0
var phase := 0
var rotation_v := 0.0
var rotation_speed := 0.7
var next_phase_hp := 350.0
var next_phase_hp2 := 200.0
var spawn_timer := 0.0
var spawn_interval := 1.5
var intro_timer := 2.5
var boss_name := "THE CONDUCTOR"
var batons: Array = []   # {angle, distance, pos:Vector2}

# --- movement ---
var orbit_ang := 0.0
var orbit_center := Vector2.ZERO
var orbit_center_ready := false

# --- attack state machine ---
var atk_state := "cd"     # cd → tele → fire → cd
var atk_timer := 1.6
var atk_name := ""
var tele := 0.0
var tele_max := 0.0
var sweep_left := 0
var sweep_t := 0.0
var sweep_int := 0.06
var sweep_ang := 0.0
var spin_dir := 1.0


func setup_conductor() -> void:
	type = "conductor"; hp = 700; max_hp = 700; size = 38
	next_phase_hp = 350; rotation_speed = 0.7; boss_name = "THE CONDUCTOR"
	batons.clear()
	for i in 4:
		batons.append({"angle": (float(i) / 4.0) * TAU, "distance": 78.0, "pos": Vector2.ZERO})
	atk_timer = 1.8

func setup_spiral() -> void:
	type = "spiral"; hp = 850; max_hp = 850; size = 32
	next_phase_hp = 510; next_phase_hp2 = 220
	rotation_speed = 1.2; spawn_interval = 1.6; boss_name = "THE SPIRAL"
	phase = 0; spin_dir = 1.0; atk_timer = 1.8


func update(dt: float) -> void:
	var old_position := position
	age += dt
	if type == "conductor": _update_conductor(dt)
	else: _update_spiral(dt)
	vel = (position - old_position) / maxf(dt, 0.001)
	queue_redraw()


# ============================================================
# MOVEMENT — eased orbit around the player (lag = weight)
# ============================================================
func _orbit(dt: float, orbit_speed: float, rx: float, ry: float, resp: float) -> void:
	var p: Vector2 = main.player.position
	orbit_ang += orbit_speed * dt
	# Track a slow-moving combat center instead of orbiting the player's exact
	# position. This gives the player time to aim and prevents endless pursuit.
	var desired_center := p + Vector2(0, -main.view_size.y * 0.12)
	if not orbit_center_ready:
		orbit_center = desired_center
		orbit_center_ready = true
	orbit_center = orbit_center.lerp(desired_center, 1.0 - exp(-0.38 * dt))
	var anchor := orbit_center + Vector2(cos(orbit_ang) * rx, sin(orbit_ang) * ry)
	# Framerate-independent smoothing keeps movement weighty and predictable.
	position = position.lerp(anchor, 1.0 - exp(-resp * dt))

func _aim() -> float:
	return (main.player.position - position).angle()

# partial target-leading so a player strafing at full speed isn't a free dodge
func _aim_lead(bspeed: float) -> float:
	var pp: Vector2 = main.player.position
	var pv: Vector2 = main.player.vel
	var t: float = (pp - position).length() / max(bspeed, 1.0)
	var future: Vector2 = pp + pv * t * 0.6
	return (future - position).angle()


# ============================================================
# CONDUCTOR
# ============================================================
func _update_conductor(dt: float) -> void:
	var p: Vector2 = main.player.position
	if phase == 0:
		var intro_anchor := p + Vector2(0, -main.view_size.y * 0.28)
		position = position.lerp(intro_anchor, 1.0 - exp(-3.0 * dt))
		intro_timer -= dt
		if intro_timer <= 0:
			phase = 1
			orbit_ang = (position - p).angle()
			main.show_toast("PHASE 1 — RADIAL ASSAULT")
		return

	rotation_v += rotation_speed * dt

	# phase 2 transition: scatter batons into divers
	if phase == 1 and hp <= next_phase_hp:
		phase = 2
		for b in batons:
			main.spawn_enemy_at("diver", b.pos)
		batons.clear()
		main.show_toast("PHASE 2 — DIRECT FIRE")
		main.screen_shake = 0.6
		atk_state = "cd"; atk_timer = 0.8

	if phase == 1:
		_orbit(dt, 0.28, main.view_size.x * 0.24, main.view_size.y * 0.14, 1.15)
		for b in batons:
			var a: float = b.angle + rotation_v
			b.pos = position + Vector2(cos(a), sin(a)) * b.distance
		_run_attacks(dt, ["baton_fan", "core_ring", "baton_fan"], 1.5, 0.75)
	else:
		_orbit(dt, 0.40, main.view_size.x * 0.27, main.view_size.y * 0.17, 1.35)
		_run_attacks(dt, ["aimed_burst", "spiral_sweep", "cross_rain", "aimed_burst"], 1.0, 0.6)


# ============================================================
# SPIRAL
# ============================================================
func _update_spiral(dt: float) -> void:
	var p: Vector2 = main.player.position
	if phase == 0:
		var intro_anchor := p + Vector2(0, -main.view_size.y * 0.26)
		position = position.lerp(intro_anchor, 1.0 - exp(-3.0 * dt))
		intro_timer -= dt
		if intro_timer <= 0:
			phase = 1
			orbit_ang = (position - p).angle()
			main.show_toast("PHASE 1 — SPIRAL SPAWN")
		return

	rotation_v += rotation_speed * spin_dir * dt

	if phase == 1 and hp <= next_phase_hp:
		phase = 2; spin_dir = -1.0; spawn_interval = 1.1
		main.show_toast("PHASE 2 — REVERSE SPIN"); main.screen_shake = 0.6
		atk_state = "cd"; atk_timer = 0.6
	if phase == 2 and hp <= next_phase_hp2:
		phase = 3; spin_dir = 1.0; rotation_speed = 2.2; spawn_interval = 0.8
		main.show_toast("PHASE 3 — COLLAPSE"); main.screen_shake = 0.8
		atk_state = "cd"; atk_timer = 0.4

	# orbit, tightening as phases escalate
	var rx: float = main.view_size.x * (0.22 if phase == 1 else 0.25)
	var ry: float = main.view_size.y * (0.14 if phase == 1 else 0.17)
	_orbit(dt, 0.24 + 0.10 * phase, rx, ry, 1.05 + 0.12 * phase)

	# keep spawning drones along the arms (its signature)
	spawn_timer -= dt
	if spawn_timer <= 0 and atk_state != "fire":
		spawn_timer = spawn_interval
		var arm_count := 2 if phase == 3 else 1
		for arm in arm_count:
			var base_ang: float = rotation_v + (float(arm) / arm_count) * TAU
			main.spawn_spiral_drone(position + Vector2(cos(base_ang), sin(base_ang)) * 60.0, base_ang)

	match phase:
		1: _run_attacks(dt, ["arm_stream", "aimed_burst"], 1.8, 0.85)
		2: _run_attacks(dt, ["arm_stream", "aimed_burst", "arm_stream"], 1.3, 0.7)
		_: _run_attacks(dt, ["collapse_rings", "arm_stream", "aimed_burst"], 0.9, 0.55)


# ============================================================
# ATTACK STATE MACHINE
# ============================================================
func _run_attacks(dt: float, pool: Array, cd: float, tele_time: float) -> void:
	match atk_state:
		"cd":
			atk_timer -= dt
			if atk_timer <= 0:
				atk_name = pool[randi() % pool.size()]
				atk_state = "tele"
				tele_max = tele_time
				tele = tele_time
				atk_timer = tele_time
		"tele":
			atk_timer -= dt
			tele = max(0.0, atk_timer)
			if atk_timer <= 0:
				_begin_attack(atk_name)
				if sweep_left > 0:
					atk_state = "fire"
				else:
					atk_state = "cd"; atk_timer = cd
		"fire":
			sweep_t -= dt
			while sweep_t <= 0.0 and sweep_left > 0:
				sweep_t += sweep_int
				_sweep_volley(atk_name)
				sweep_left -= 1
			if sweep_left <= 0:
				atk_state = "cd"; atk_timer = cd

func _begin_attack(name: String) -> void:
	sweep_left = 0
	match name:
		# ---- instant attacks ----
		"baton_fan":
			Audio.boss_shoot()
			for b in batons:
				var base: float = (main.player.position - b.pos).angle()
				for k in range(-2, 3):
					_emit_from(b.pos, base + k * 0.16, 230.0, Data.MAGENTA, 5.0)
		"aimed_burst":
			Audio.boss_shoot()
			var a := _aim_lead(340.0)
			for k in range(-2, 3):
				_emit(a + k * 0.13, 340.0, Data.MAGENTA, 6.0)
		# ---- sweep attacks (fired over time during "fire") ----
		"core_ring":
			sweep_left = 6; sweep_int = 0.12; sweep_ang = rotation_v
		"spiral_sweep":
			sweep_left = 22; sweep_int = 0.05; sweep_ang = _aim()
		"cross_rain":
			sweep_left = 10; sweep_int = 0.10; sweep_ang = 0.0
		"arm_stream":
			sweep_left = 18; sweep_int = 0.06; sweep_ang = rotation_v
		"collapse_rings":
			sweep_left = 5; sweep_int = 0.18; sweep_ang = 0.0

func _sweep_volley(name: String) -> void:
	match name:
		"core_ring":
			Audio.boss_shoot()
			var n := 14
			for i in n:
				_emit((float(i) / n) * TAU + sweep_ang, 215.0, Data.MAGENTA, 5.0)
			sweep_ang += 0.22
		"spiral_sweep":
			# two counter-rotating arms aimed off the player's bearing
			_emit(sweep_ang, 300.0, Data.MAGENTA_SOFT, 5.0)
			_emit(sweep_ang + PI, 300.0, Data.MAGENTA_SOFT, 5.0)
			sweep_ang += 0.42
		"cross_rain":
			for k in 4:
				_emit(sweep_ang + k * (TAU / 4.0), 260.0, Data.MAGENTA, 5.0)
			sweep_ang += 0.26
		"arm_stream":
			for k in 3:
				_emit(sweep_ang + k * (TAU / 3.0), 240.0, Data.AMBER, 5.0)
			sweep_ang += spin_dir * 0.34
		"collapse_rings":
			Audio.boss_shoot()
			var n := 18
			for i in n:
				_emit((float(i) / n) * TAU + sweep_ang, 230.0, Data.AMBER, 5.0)
			sweep_ang += 0.16
			# occasional aimed dagger to punish camping
			if sweep_left % 2 == 0:
				_emit(_aim_lead(360.0), 360.0, Data.MAGENTA, 6.0)

func _emit(angle: float, speed: float, color: Color, bsize: float) -> void:
	main.spawn_enemy_bullet(position, Vector2(cos(angle), sin(angle)) * speed, bsize, color, 1, 4.0)

func _emit_from(pos: Vector2, angle: float, speed: float, color: Color, bsize: float) -> void:
	main.spawn_enemy_bullet(pos, Vector2(cos(angle), sin(angle)) * speed, bsize, color, 1, 4.0)


# ============================================================
# DRAW
# ============================================================
func _draw() -> void:
	_draw_telegraph()
	if type == "conductor": _draw_conductor()
	else: _draw_spiral()

# charge-up tell: a ring collapsing toward the core as the attack readies
func _draw_telegraph() -> void:
	if tele <= 0.0 or tele_max <= 0.0:
		return
	var f: float = 1.0 - tele / tele_max          # 0 → 1 as it charges
	var col: Color = Data.AMBER if type == "spiral" else Data.MAGENTA_SOFT
	var ring_r: float = size + 4.0 + (1.0 - f) * size * 2.2
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 40, Color(col, 0.25 + f * 0.5), 2.0, true)
	Neon.glow(self, Vector2.ZERO, size * (1.2 + f), col, 0.15 + f * 0.35)

func _draw_conductor() -> void:
	Neon.glow(self, Vector2.ZERO, size * 2.5, Data.MAGENTA, 0.35)
	for i in 12:
		var a := (float(i) / 12.0) * TAU + rotation_v * 0.5
		var pp := Vector2(cos(a), sin(a)) * (size + 14.0)
		draw_circle(pp, 3.0, Data.MAGENTA)
	var pts := PackedVector2Array()
	for i in 8:
		var a := (float(i) / 8.0) * TAU + rotation_v
		pts.append(Vector2(cos(a), sin(a)) * size)
	Neon.poly(self, pts, Color(Data.MAGENTA, 0.85), Data.MAGENTA_SOFT, 2.0)
	var cp := 1.0 + sin(age * 4.0) * 0.25
	Neon.glow_dot(self, Vector2.ZERO, size * 0.4 * cp, Data.WHITE)
	for b in batons:
		var lp: Vector2 = b.pos - position
		Neon.glow_dot(self, lp, 8.0, Data.MAGENTA)

func _draw_spiral() -> void:
	Neon.glow(self, Vector2.ZERO, size * 3.0, Data.PURPLE, 0.35)
	for arm in 3:
		var arm_off := (float(arm) / 3.0) * TAU
		var last := Vector2.ZERO
		for j in 12:
			var t := float(j) / 12.0
			var r := t * 18.0 * 3.0
			var a := arm_off + rotation_v + t * 1.2
			var pp := Vector2(cos(a), sin(a)) * r
			if j > 0:
				draw_line(last, pp, Color(Data.CYAN, 0.8), 2.0)
			last = pp
	var cp := 1.0 + sin(age * 5.0) * 0.3
	Neon.glow_dot(self, Vector2.ZERO, size * 0.4 * cp, Data.WHITE)
