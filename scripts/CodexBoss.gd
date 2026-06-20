class_name CodexBoss
extends Node2D

## Shared implementation for the first promoted Codex encounters. Every boss
## keeps its own state branch but uses the same lifecycle and damage contract.

var main = null
var type := "warden"
var boss_name := "THE WARDEN"
var hp := 1200.0
var max_hp := 1200.0
var size := 40.0
var speed := 50.0
var phase := 0
var age := 0.0
var intro_timer := 2.0
var attack_timer := 1.5
var state_timer := 0.0
var warp_timer := 3.0
var summon_timer := 3.0
var shielded := false
var vulnerable_timer := 0.0
var exploding := false
var detonation_timer := 0.0
var color: Color = Data.MAGENTA
var rotation_v := 0.0
var hit_flash := 0.0
var target_pos := Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
const BossCatalogScript = preload("res://scripts/BossCatalog.gd")

func setup(id: String, wave: int) -> void:
	type = id
	var def: Dictionary = BossCatalogScript.DEFINITIONS[id]
	boss_name = def.name
	hp = BossCatalogScript.scaled_hp(id, wave)
	max_hp = hp
	size = def.size
	speed = def.speed
	match id:
		"warden": color = Data.MAGENTA_SOFT; shielded = true; state_timer = 8.0
		"stalker": color = Data.MAGENTA; warp_timer = 3.0
		"sentry": color = Data.GOLD; attack_timer = 1.2
		"summoner": color = Data.PURPLE; summon_timer = 3.0
		"bomber": color = Data.AMBER; state_timer = 4.0

func update(dt: float) -> void:
	var old_position := position
	age += dt
	if hit_flash > 0.0: hit_flash -= dt
	if phase == 0:
		var anchor: Vector2 = main.player.position + Vector2(0, -main.view_size.y * 0.27)
		position = position.lerp(anchor, 1.0 - exp(-3.0 * dt))
		intro_timer -= dt
		if intro_timer <= 0.0:
			phase = 1
			main.show_toast(_phase_label())
		vel = (position - old_position) / maxf(dt, 0.001)
		queue_redraw()
		return
	match type:
		"warden": _update_warden(dt)
		"stalker": _update_stalker(dt)
		"sentry": _update_sentry(dt)
		"summoner": _update_summoner(dt)
		"bomber": _update_bomber(dt)
	vel = (position - old_position) / maxf(dt, 0.001)
	queue_redraw()

func damage_multiplier(source = null) -> float:
	if type == "warden" and shielded:
		if source != null and source.shield_break:
			shielded = false
			state_timer = 5.0
			main.show_toast("WARDEN SHIELD BROKEN")
			return 1.0
		return 0.0
	return 1.0

func _phase_label() -> String:
	match type:
		"warden": return "SHIELD CYCLE ENGAGED"
		"stalker": return "PREDATOR LOCK"
		"sentry": return "TARGETING ARRAY ACTIVE"
		"summoner": return "SUMMON GATES OPEN"
		"bomber": return "DETONATION COUNTDOWN"
	return boss_name

func _move_toward_player(dt: float, mult := 1.0) -> void:
	var d: Vector2 = main.player.position - position
	if d.length_squared() > 1.0:
		position += d.normalized() * speed * mult * dt

func _update_warden(dt: float) -> void:
	var ratio: float = hp / max_hp
	phase = 1 if ratio > 0.66 else (2 if ratio > 0.33 else 3)
	if phase == 1:
		shielded = true
	elif phase == 2:
		state_timer -= dt
		if state_timer <= 0.0:
			shielded = not shielded
			state_timer = 8.0 if shielded else 5.0
			main.show_toast("SHIELD ACTIVE" if shielded else "CORE EXPOSED")
	else:
		shielded = false
	_move_toward_player(dt, 2.0 if phase == 3 else 0.65)
	attack_timer -= dt
	if attack_timer <= 0.0:
		attack_timer = 1.0 if not shielded else 2.0
		_aimed_fan(1, 360.0, 0.0)

func _update_stalker(dt: float) -> void:
	phase = 2 if hp <= max_hp * 0.5 else 1
	var d: Vector2 = main.player.position - position
	var zig := sin(age * 5.0) * 0.45
	if d.length_squared() > 1.0:
		position += Vector2.from_angle(d.angle() + zig) * speed * dt
	warp_timer -= dt
	if d.length() > 400.0 or (phase == 2 and warp_timer <= 0.0):
		warp_timer = 3.0
		var a := randf() * TAU
		position = main.player.position + Vector2.from_angle(a) * 100.0
		main.spawn_particles(position, Data.WHITE, 18, 4.0)
		target_pos = main.player.position
		state_timer = 0.4
	if state_timer > 0.0:
		state_timer -= dt
		if state_timer <= 0.0:
			var lunge: Vector2 = target_pos - position
			if lunge.length_squared() > 1.0:
				position += lunge.normalized() * 70.0

func _update_sentry(dt: float) -> void:
	phase = 2 if hp <= max_hp * 0.5 else 1
	var d: Vector2 = main.player.position - position
	var ideal := 300.0 if phase == 2 else 250.0
	if d.length() > ideal + 25.0:
		position += d.normalized() * speed * dt
	elif d.length() < ideal - 25.0:
		position -= d.normalized() * speed * dt
	elif d.length_squared() > 1.0:
		position += Vector2(-d.y, d.x).normalized() * speed * 0.7 * dt
	attack_timer -= dt
	if attack_timer <= 0.0:
		attack_timer = 0.8 if phase == 2 else 1.2
		_aimed_fan(5 if phase == 2 else 3, 430.0, 0.15)

func _update_summoner(dt: float) -> void:
	phase = 2 if hp <= max_hp * 0.5 else 1
	var d: Vector2 = main.player.position - position
	var ideal := 150.0 if phase == 2 else 200.0
	if d.length() > ideal:
		position += d.normalized() * speed * dt
	else:
		position += Vector2(-d.y, d.x).normalized() * speed * 0.5 * dt
	summon_timer -= dt
	if summon_timer <= 0.0:
		summon_timer = 1.5 if phase == 2 else 3.0
		var count := 5 if phase == 2 else 3
		for i in count:
			var a := float(i) / count * TAU
			main.spawn_enemy_at("drone", position + Vector2.from_angle(a) * 70.0)
		if phase == 2:
			for i in 8:
				_emit(float(i) / 8.0 * TAU, 240.0)

func _update_bomber(dt: float) -> void:
	if exploding:
		detonation_timer -= dt
		if detonation_timer <= 0.0:
			if position.distance_to(main.player.position) <= 150.0:
				main.damage_player(2)
			main.spawn_particles(position, Data.AMBER, 80, 10.0)
			main.screen_shake = 1.3
			main.defeat_boss(false)
		return
	_move_toward_player(dt, 1.5)
	state_timer -= dt
	if position.distance_to(main.player.position) <= 60.0 or state_timer <= 0.0:
		exploding = true
		detonation_timer = 0.5
		main.show_toast("DETONATION — CLEAR THE BLAST!")

func _aimed_fan(count: int, bullet_speed: float, spread: float) -> void:
	var a: float = (main.player.position - position).angle()
	for i in count:
		var off := (i - (count - 1) / 2.0) * spread
		_emit(a + off, bullet_speed)

func _emit(angle: float, bullet_speed: float) -> void:
	main.spawn_enemy_bullet(position, Vector2.from_angle(angle) * bullet_speed, 5.0, color, 1, 4.0)

func _draw() -> void:
	var body: Color = Data.WHITE if hit_flash > 0.0 else color
	Neon.glow(self, Vector2.ZERO, size * 2.4, color, 0.35)
	match type:
		"warden":
			draw_rect(Rect2(-size, -size, size * 2.0, size * 2.0), Color(body, 0.8))
			draw_rect(Rect2(-size, -size, size * 2.0, size * 2.0), color, false, 3.0)
			if shielded:
				draw_arc(Vector2.ZERO, size + 12.0, 0, TAU, 48, Data.MAGENTA_SOFT, 4.0)
		"stalker":
			var pts := PackedVector2Array([Vector2(0, -size), Vector2(size * 0.65, 0),
				Vector2(0, size), Vector2(-size * 0.65, 0)])
			Neon.poly(self, pts, Color(body, 0.85), color, 2.0)
			Neon.glow_dot(self, Vector2(0, -4), 3.0, Data.WHITE)
		"sentry":
			_polygon(8, body)
			draw_line(Vector2.ZERO, (main.player.position - position).normalized() * 80.0, Color(Data.AMBER, 0.55), 1.5)
		"summoner":
			Neon.glow_dot(self, Vector2.ZERO, size, Data.PURPLE)
			for i in 5:
				var a := age * 2.0 + float(i) / 5.0 * TAU
				draw_circle(Vector2.from_angle(a) * (size + 10.0), 3.0, Data.AMBER)
		"bomber":
			draw_circle(Vector2.ZERO, size, Color(body, 0.9))
			draw_arc(Vector2.ZERO, size, 0, TAU, 32, Data.AMBER_SOFT, 3.0)
			if exploding:
				var f := 1.0 - detonation_timer / 0.5
				draw_arc(Vector2.ZERO, 150.0 * f, 0, TAU, 48, Color(Data.AMBER, 0.8), 3.0)
	Neon.glow_dot(self, Vector2.ZERO, size * 0.25, Data.WHITE)

func _polygon(sides: int, body: Color) -> void:
	var pts := PackedVector2Array()
	for i in sides:
		var a := float(i) / sides * TAU + rotation_v
		pts.append(Vector2.from_angle(a) * size)
	Neon.poly(self, pts, Color(body, 0.85), color, 2.0)
