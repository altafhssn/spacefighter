class_name Enemy
extends Node2D
## Enemy with behavior state machine — port of ENEMY_BASE + updateEnemy + drawEnemy.

var main = null

var type := "drone"
var hp := 18.0
var max_hp := 18.0
var size := 10.0
var color: Color = Data.CYAN
var speed := 65.0
var score_value := 50
var behavior := "drift"
var xp_value := 1
var age := 0.0
var telegraph := 0.0
var fire_timer := 0.0
var hit_flash := 0.0
var spawn_protect := 0.0
var vel: Vector2 = Vector2.ZERO
var remove := false
var is_elite := false
var slow_timer := 0.0
var slow_factor := 1.0
var burn_timer := 0.0
var burn_dps := 0.0

# behavior-specific
var drift_angle := 0.0
var state := ""
var aim_time := 0.9
var dive_speed := 400.0
var dive_target: Vector2 = Vector2.ZERO
var dive_timer := 0.0
var recover_timer := 0.0
var shield_hp := 0.0
var shield_angle := -PI / 2
var shield_open := false
var shield_cycle := 0.0
var beam_telegraph := 1.2
var fire_interval := 2.5
var spiral_ang := 0.0
var spiral_radius := 60.0
var spiral_center: Vector2 = Vector2.ZERO
var snipe_target: Vector2 = Vector2.ZERO
var snipe_target_ready := false
var snipe_side := 0.0
var weave_phase := 0.0
var orbit_dir := 1.0
var preferred_range := 210.0
var redraw_timer := 0.0

func update(dt: float) -> void:
	age += dt
	if burn_timer > 0.0:
		burn_timer -= dt
		hp -= burn_dps * dt
	if slow_timer > 0.0:
		slow_timer -= dt
	else:
		slow_factor = 1.0
	if hit_flash > 0: hit_flash -= dt
	if spawn_protect > 0: spawn_protect -= dt
	var p: Vector2 = main.player.position

	match behavior:
		"drift":
			drift_angle += dt * 1.2
			var ang := (p - position).angle()
			var wobble := sin(drift_angle) * 0.6
			vel = Vector2(cos(ang + wobble), sin(ang + wobble)) * speed
		"weave":
			weave_phase += dt * 5.5
			var toward := (p - position).normalized()
			var lateral := toward.rotated(PI / 2.0) * sin(weave_phase) * speed * 0.9
			vel = toward * speed + lateral
		"strafe":
			var offset := position - p
			var distance := maxf(1.0, offset.length())
			var radial := offset / distance
			var tangent := radial.rotated(PI / 2.0) * orbit_dir
			var range_error := clampf((distance - preferred_range) / preferred_range, -1.0, 1.0)
			vel = tangent * speed - radial * range_error * speed * 0.9
			fire_timer -= dt
			if fire_timer <= 0.0 and distance < preferred_range * 1.45:
				var shot_angle := (p - position).angle()
				main.spawn_enemy_bullet(position, Vector2.from_angle(shot_angle) * 260.0, 3.5, color, 1, 3.0)
				fire_timer = randf_range(2.2, 3.0)
		"dive":
			if state == "aiming":
				aim_time -= dt
				telegraph = max(0.0, 0.9 - aim_time)
				var ang := (p - position).angle()
				vel = Vector2(cos(ang), sin(ang)) * 55.0
				if aim_time <= 0:
					state = "diving"
					dive_target = p + main.player.vel * 0.22
					vel = (dive_target - position).normalized() * dive_speed
					dive_timer = clampf(position.distance_to(dive_target) / dive_speed + 0.12, 0.35, 1.15)
					telegraph = 0.0
			elif state == "diving":
				dive_timer -= dt
				if dive_timer <= 0.0 or position.distance_to(dive_target) < 18.0:
					state = "recovering"
					recover_timer = 0.55
			elif state == "recovering":
				recover_timer -= dt
				var away := (position - p).normalized()
				var tangent := away.rotated(PI / 2.0)
				vel = vel.lerp((away * 0.45 + tangent * 0.55).normalized() * speed * 1.4,
					1.0 - exp(-5.0 * dt))
				if recover_timer <= 0.0:
					state = "aiming"
					aim_time = randf_range(0.75, 1.05)
					telegraph = 0.0
		"shield":
			var ang := (p - position).angle()
			shield_cycle += dt
			shield_open = fmod(shield_cycle, 4.0) >= 2.6
			shield_angle = ang
			vel = Vector2(cos(ang), sin(ang)) * speed
		"snipe":
			if state == "positioning":
				if not snipe_target_ready:
					_choose_snipe_target(p)
				# Keep one committed destination instead of choosing a random
				# point every frame. The old jitter made the Lancer's velocity
				# impossible for auto-aim to predict while the player strafed.
				var to_target: Vector2 = snipe_target - position
				vel = to_target.limit_length(180.0)
				if to_target.length() < 10.0:
					state = "charging"
					fire_timer = beam_telegraph
					snipe_target_ready = false
			elif state == "charging":
				vel = Vector2.ZERO
				telegraph = 1.0 - (fire_timer / beam_telegraph)
				fire_timer -= dt
				if fire_timer <= 0:
					_fire_beam()
					state = "cooldown"
					fire_timer = 1.5
					telegraph = 0.0
			elif state == "cooldown":
				vel = Vector2.ZERO
				fire_timer -= dt
				if fire_timer <= 0:
					state = "positioning"
					snipe_side *= -1.0
					snipe_target_ready = false
		"spiral_out":
			spiral_radius += speed * dt
			spiral_ang += dt * 1.5 * (1.0 if spiral_ang > 0 else -1.0)
			var center: Vector2 = main.boss.position if main.boss else spiral_center
			position = center + Vector2(cos(spiral_ang), sin(spiral_ang)) * spiral_radius
			vel = Vector2.ZERO
			var vp: Vector2 = main.view_size
			if spiral_radius > max(vp.x, vp.y) * 0.7:
				remove = true
			queue_redraw()
			return

	# separation — push apart from nearby pursuers so swarms don't stack
	if behavior in ["drift", "weave", "strafe", "shield"]:
		var sep := Vector2.ZERO
		for o in main.nearby_enemies(position):
			if o == self: continue
			var off: Vector2 = position - o.position
			var dsq := off.length_squared()
			var rad: float = (size + o.size) * 1.5
			if dsq > 0.01 and dsq < rad * rad:
				sep += off / sqrt(dsq)
		if sep != Vector2.ZERO:
			vel += sep.normalized() * speed * 0.85

	position += vel * dt * slow_factor

	# Pursuers never vanish from distance — if the player outruns them they
	# re-enter from the spawn ring so the wave stays a threat.
	var dp := position.distance_to(p)
	var leash: float = main.view_size.length() * 0.9
	match behavior:
		"drift", "weave", "strafe", "shield", "snipe":
			if dp > leash: _reengage(p)
		"dive":
			if state == "aiming" and dp > leash: _reengage(p)
			elif state in ["diving", "recovering"] and dp > Data.CULL_DISTANCE: _reengage(p)
	redraw_timer -= dt
	if redraw_timer <= 0.0 or hit_flash > 0.0 or telegraph > 0.0:
		queue_redraw()
		redraw_timer = 1.0 / 30.0

func _reengage(p: Vector2) -> void:
	var ang := randf() * TAU
	position = p + Vector2(cos(ang), sin(ang)) * main.view_size.length() * 0.62
	if behavior == "snipe":
		state = "positioning"; fire_timer = 0.0; telegraph = 0.0
		snipe_target_ready = false
	elif behavior == "strafe":
		fire_timer = randf_range(0.8, 1.8)
	elif behavior == "dive":
		state = "aiming"; aim_time = 0.9; telegraph = 0.0

func _choose_snipe_target(p: Vector2) -> void:
	if snipe_side == 0.0:
		snipe_side = -1.0 if position.x < p.x else 1.0
	var lateral := 230.0 + randf_range(0.0, 55.0)
	snipe_target = p + Vector2(snipe_side * lateral, randf_range(-145.0, -75.0))
	snipe_target_ready = true

func _fire_beam() -> void:
	var p: Vector2 = main.player.position
	var ang := (p - position).angle()
	main.spawn_enemy_bullet(position, Vector2(cos(ang), sin(ang)) * 750.0, 5.0, Data.AMBER, 1, 2.0)

func _draw() -> void:
	if is_elite:
		var ep := 1.0 + sin(main.time * 5.0) * 0.2
		Neon.glow(self, Vector2.ZERO, size * 3.0 * ep, Data.AMBER, 0.4)
	if telegraph > 0:
		Neon.glow(self, Vector2.ZERO, size + 10.0 + telegraph * 8.0, Data.AMBER, 0.4 + telegraph * 0.3)
	if spawn_protect > 0:
		draw_arc(Vector2.ZERO, size + 4.0, 0, TAU, 24,
			Color(Data.WHITE.r, Data.WHITE.g, Data.WHITE.b, spawn_protect / Data.SPAWN_PROTECTION * 0.6), 1.5)

	Neon.glow(self, Vector2.ZERO, size * 2.0, color, 0.3)
	var body_color: Color = Data.WHITE if hit_flash > 0 else color

	match type:
		"drone":
			var pts := PackedVector2Array()
			for i in 6:
				var a := (float(i) / 6.0) * TAU + age
				pts.append(Vector2(cos(a), sin(a)) * size)
			Neon.poly(self, pts, body_color, color, 1.5)
			draw_circle(Vector2.ZERO, 2.5, Data.WHITE)
		"weaver":
			var ang: float = vel.angle()
			draw_set_transform(Vector2.ZERO, ang + PI / 2.0, Vector2.ONE)
			var pts := PackedVector2Array([
				Vector2(0, -size), Vector2(size * 0.7, size * 0.65),
				Vector2(0, size * 0.25), Vector2(-size * 0.7, size * 0.65)])
			Neon.poly(self, pts, body_color, color, 1.3)
			draw_circle(Vector2(0, -size * 0.25), 1.5, Data.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"skimmer":
			var ang: float = vel.angle()
			draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
			var pts := PackedVector2Array([
				Vector2(size, 0), Vector2(-size * 0.65, -size * 0.7),
				Vector2(-size * 0.25, 0), Vector2(-size * 0.65, size * 0.7)])
			Neon.poly(self, pts, body_color, color, 1.4)
			draw_line(Vector2(-size * 0.2, 0), Vector2(size * 0.55, 0), Data.WHITE, 1.2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"diver":
			var ang: float = (main.player.position - position).angle()
			draw_set_transform(Vector2.ZERO, ang + PI / 2, Vector2.ONE)
			var pts := PackedVector2Array([
				Vector2(0, -size), Vector2(size * 0.85, size * 0.7),
				Vector2(0, size * 0.4), Vector2(-size * 0.85, size * 0.7)])
			Neon.poly(self, pts, body_color, color, 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if state == "aiming":
				var target_local: Vector2 = main.player.position - position
				draw_line(Vector2.ZERO, target_local, Color(color, 0.18 + telegraph * 0.42), 1.5)
				draw_circle(target_local, 5.0 + telegraph * 4.0, Color(color, 0.28), false, 1.5)
		"bulwark":
			draw_rect(Rect2(-size, -size, size * 2, size * 2), body_color)
			draw_rect(Rect2(-size, -size, size * 2, size * 2), color, false, 1.5)
			draw_rect(Rect2(-2, -size + 3, 4, size * 2 - 6), Data.NAVY)
			draw_rect(Rect2(-size + 3, -2, size * 2 - 6, 4), Data.NAVY)
			if shield_hp > 0 and not shield_open:
				draw_arc(Vector2.ZERO, size + 8.0, shield_angle - PI / 2, shield_angle + PI / 2, 20, Data.AMBER, 3.0)
			elif shield_hp > 0 and shield_open:
				# retracted — faint hint showing the body is exposed
				draw_arc(Vector2.ZERO, size + 8.0, shield_angle - PI / 2, shield_angle + PI / 2, 20, Color(Data.AMBER.r, Data.AMBER.g, Data.AMBER.b, 0.18), 1.0)
		"lancer":
			var pts := PackedVector2Array([
				Vector2(0, -size), Vector2(size * 0.55, 0),
				Vector2(0, size), Vector2(-size * 0.55, 0)])
			Neon.poly(self, pts, body_color, color, 1.5)
			if state == "charging":
				var ang: float = (main.player.position - position).angle()
				var endp := Vector2(cos(ang), sin(ang)) * 800.0
				draw_line(Vector2.ZERO, endp, Color(Data.AMBER.r, Data.AMBER.g, Data.AMBER.b, 0.5 + telegraph * 0.4), 1.5)

	# HP bar
	if hp < max_hp and max_hp > 15:
		var w := size * 2.0
		var by := size + 5.0
		draw_rect(Rect2(-w / 2, by, w, 3), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-w / 2, by, w * (hp / max_hp), 3), color)
