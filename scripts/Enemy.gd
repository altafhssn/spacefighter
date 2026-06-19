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

# behavior-specific
var drift_angle := 0.0
var state := ""
var aim_time := 0.9
var dive_speed := 400.0
var shield_hp := 0.0
var shield_angle := -PI / 2
var shield_open := false
var shield_cycle := 0.0
var beam_telegraph := 1.2
var fire_interval := 2.5
var spiral_ang := 0.0
var spiral_radius := 60.0
var spiral_center: Vector2 = Vector2.ZERO

func update(dt: float) -> void:
	age += dt
	if hit_flash > 0: hit_flash -= dt
	if spawn_protect > 0: spawn_protect -= dt
	var p: Vector2 = main.player.position

	match behavior:
		"drift":
			drift_angle += dt * 1.2
			var ang := (p - position).angle()
			var wobble := sin(drift_angle) * 0.6
			vel = Vector2(cos(ang + wobble), sin(ang + wobble)) * speed
		"dive":
			if state == "aiming":
				aim_time -= dt
				telegraph = max(0.0, 0.9 - aim_time)
				var ang := (p - position).angle()
				vel = Vector2(cos(ang), sin(ang)) * 30.0
				if aim_time <= 0:
					state = "diving"
					var da := (p - position).angle()
					vel = Vector2(cos(da), sin(da)) * dive_speed
					telegraph = 0.0
			elif state == "diving":
				if position.distance_to(p) > Data.CULL_DISTANCE:
					remove = true
		"shield":
			var ang := (p - position).angle()
			shield_cycle += dt
			shield_open = fmod(shield_cycle, 4.0) >= 2.6
			shield_angle = ang
			vel = Vector2(cos(ang), sin(ang)) * speed
		"snipe":
			if state == "positioning":
				var off: float = (-1.0 if position.x < p.x else 1.0) * (220.0 + randf() * 80.0)
				var target := Vector2(p.x + off, p.y - 120.0 + randf() * 60.0)
				vel = (target - position) * 1.5
				if abs(target.x - position.x) < 5 and abs(target.y - position.y) < 5:
					state = "charging"
					fire_timer = beam_telegraph
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
				fire_timer -= dt
				if fire_timer <= 0:
					state = "charging"
					fire_timer = beam_telegraph
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
	if behavior == "drift" or behavior == "shield":
		var sep := Vector2.ZERO
		for o in main.enemies:
			if o == self: continue
			var off: Vector2 = position - o.position
			var dsq := off.length_squared()
			var rad: float = (size + o.size) * 1.5
			if dsq > 0.01 and dsq < rad * rad:
				sep += off / sqrt(dsq)
		if sep != Vector2.ZERO:
			vel += sep.normalized() * speed * 0.85

	position += vel * dt

	# Pursuers never vanish from distance — if the player outruns them they
	# re-enter from the spawn ring so the wave stays a threat.
	var dp := position.distance_to(p)
	var leash: float = main.view_size.length() * 0.9
	match behavior:
		"drift", "shield", "snipe":
			if dp > leash: _reengage(p)
		"dive":
			if state == "aiming" and dp > leash: _reengage(p)
			elif state == "diving" and dp > Data.CULL_DISTANCE: remove = true
	queue_redraw()

func _reengage(p: Vector2) -> void:
	var ang := randf() * TAU
	position = p + Vector2(cos(ang), sin(ang)) * main.view_size.length() * 0.62
	if behavior == "snipe":
		state = "positioning"; fire_timer = 0.0; telegraph = 0.0
	elif behavior == "dive":
		state = "aiming"; aim_time = 0.9; telegraph = 0.0

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
		"diver":
			var ang: float = (main.player.position - position).angle()
			draw_set_transform(Vector2.ZERO, ang + PI / 2, Vector2.ONE)
			var pts := PackedVector2Array([
				Vector2(0, -size), Vector2(size * 0.85, size * 0.7),
				Vector2(0, size * 0.4), Vector2(-size * 0.85, size * 0.7)])
			Neon.poly(self, pts, body_color, color, 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
