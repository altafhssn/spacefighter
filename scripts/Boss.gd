class_name Boss
extends Node2D
## The Conductor and The Spiral — port of spawnConductor/spawnSpiral +
## updateConductor/updateSpiral + drawConductor/drawSpiral.

var main = null

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
var fire_timer := 0.0
var fire_interval := 0.7
var spawn_timer := 0.0
var spawn_interval := 1.5
var intro_timer := 2.5
var boss_name := "THE CONDUCTOR"
var home: Vector2 = Vector2.ZERO
var batons: Array = []   # {angle, distance, fire_timer, attached, pos:Vector2}

func setup_conductor() -> void:
	type = "conductor"; hp = 700; max_hp = 700; size = 38
	next_phase_hp = 350; rotation_speed = 0.7; boss_name = "THE CONDUCTOR"
	batons.clear()
	for i in 4:
		batons.append({"angle": (float(i) / 4.0) * TAU, "distance": 75.0,
			"fire_timer": i * 0.6, "attached": true, "pos": Vector2.ZERO})

func setup_spiral() -> void:
	type = "spiral"; hp = 850; max_hp = 850; size = 32
	next_phase_hp = 425; next_phase_hp2 = 200
	rotation_speed = 1.2; spawn_interval = 1.5; boss_name = "THE SPIRAL"
	phase = 0

func update(dt: float) -> void:
	age += dt
	if type == "conductor": _update_conductor(dt)
	else: _update_spiral(dt)
	queue_redraw()

func _update_conductor(dt: float) -> void:
	var p: Vector2 = main.player.position
	var H: float = main.view_size.y
	var W: float = main.view_size.x
	home = Vector2(p.x, p.y - H * 0.18)
	if phase == 0:
		position += (home - position) * 2.0 * dt
		intro_timer -= dt
		if intro_timer <= 0:
			phase = 1
			main.show_toast("PHASE 1 — RADIAL ASSAULT")
		return
	rotation_v += rotation_speed * dt
	position = Vector2(home.x + sin(age * 0.5) * (W * 0.22), home.y + cos(age * 0.3) * 20.0)

	if phase == 1 and hp <= next_phase_hp:
		phase = 2; rotation_speed = 0
		for b in batons:
			if b.attached:
				b.attached = false
				main.spawn_enemy_at("diver", b.pos)
		batons.clear()
		main.show_toast("PHASE 2 — DIRECT FIRE")
		fire_timer = 0; fire_interval = 0.7; main.screen_shake = 0.6

	if phase == 1:
		for b in batons:
			if b.attached:
				var a: float = b.angle + rotation_v
				b.pos = position + Vector2(cos(a), sin(a)) * b.distance
				b.fire_timer -= dt
				if b.fire_timer <= 0:
					b.fire_timer = 1.6
					for i in 8:
						var ang := (float(i) / 8.0) * TAU + rotation_v
						main.spawn_enemy_bullet(b.pos, Vector2(cos(ang), sin(ang)) * 200.0, 5.0, Data.MAGENTA, 1, 4.0)
	elif phase == 2:
		fire_timer -= dt
		if fire_timer <= 0:
			fire_timer = fire_interval
			var base := (p - position).angle()
			for i in range(-1, 2):
				var ang := base + i * 0.2
				main.spawn_enemy_bullet(position, Vector2(cos(ang), sin(ang)) * 320.0, 6.0, Data.MAGENTA, 1, 4.0)

func _update_spiral(dt: float) -> void:
	var p: Vector2 = main.player.position
	var H: float = main.view_size.y
	var W: float = main.view_size.x
	home = Vector2(p.x, p.y - H * 0.18)
	if phase == 0:
		position += (home - position) * 2.0 * dt
		intro_timer -= dt
		if intro_timer <= 0:
			phase = 1
			main.show_toast("PHASE 1 — SPIRAL SPAWN")
		return
	rotation_v += rotation_speed * dt
	position.x = home.x + sin(age * 0.4) * (W * 0.18)
	position.y = home.y

	if phase == 1 and hp <= next_phase_hp:
		phase = 2; rotation_speed = -1.5; spawn_interval = 1.0
		main.show_toast("PHASE 2 — REVERSE SPIN"); main.screen_shake = 0.6
	if phase == 2 and hp <= next_phase_hp2:
		phase = 3; rotation_speed = 2.5; spawn_interval = 0.5; fire_timer = 0
		main.show_toast("PHASE 3 — COLLAPSE"); main.screen_shake = 0.8

	spawn_timer -= dt
	if spawn_timer <= 0:
		spawn_timer = spawn_interval
		var arm_count := 2 if phase == 3 else 1
		for arm in arm_count:
			var base_ang: float = rotation_v + (float(arm) / arm_count) * TAU
			var spawn_pos := position + Vector2(cos(base_ang), sin(base_ang)) * 60.0
			main.spawn_spiral_drone(spawn_pos, base_ang)

	if phase == 3:
		fire_timer -= dt
		if fire_timer <= 0:
			fire_timer = 0.6
			for i in 6:
				var ang := (float(i) / 6.0) * TAU + rotation_v
				main.spawn_enemy_bullet(position, Vector2(cos(ang), sin(ang)) * 250.0, 5.0, Data.AMBER, 1, 4.0)

func _draw() -> void:
	if type == "conductor": _draw_conductor()
	else: _draw_spiral()

func _draw_conductor() -> void:
	Neon.glow(self, Vector2.ZERO, size * 2.5, Data.MAGENTA, 0.35)
	# outer ring of nodes
	for i in 12:
		var a := (float(i) / 12.0) * TAU + rotation_v * 0.5
		var pp := Vector2(cos(a), sin(a)) * (size + 14.0)
		draw_circle(pp, 3.0, Data.MAGENTA)
	# body ring
	var pts := PackedVector2Array()
	for i in 8:
		var a := (float(i) / 8.0) * TAU + rotation_v
		pts.append(Vector2(cos(a), sin(a)) * size)
	Neon.poly(self, pts, Color(Data.MAGENTA, 0.85), Data.MAGENTA_SOFT, 2.0)
	# core
	var cp := 1.0 + sin(age * 4.0) * 0.25
	Neon.glow_dot(self, Vector2.ZERO, size * 0.4 * cp, Data.WHITE)
	# batons
	for b in batons:
		if b.attached:
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
