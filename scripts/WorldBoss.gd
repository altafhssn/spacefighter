class_name WorldBoss
extends Node2D
## A world mini-boss guarding a landmark (warden / stalker / sentry).
## Port of spawnWorldBoss + updateWorldBossV9 + drawWorldBossV9 (chase /
## chase_fast / ranged behaviors). Driven by Main.

var main = null
var type := "warden"
var boss_name := "WARDEN"
var hp := 400.0
var max_hp := 400.0
var size := 32.0
var speed := 50.0
var color: Color = Data.MAGENTA_SOFT
var score_value := 2000
var xp_value := 15
var behavior := "chase"
var age := 0.0
var fire_timer := 0.0
var hit_flash := 0.0
var spawn_protect := 0.5
var vel: Vector2 = Vector2.ZERO
var guarding_landmark := ""

func update(dt: float) -> void:
	age += dt
	if hit_flash > 0: hit_flash -= dt
	if spawn_protect > 0: spawn_protect -= dt
	var p: Vector2 = main.player.position
	var d: Vector2 = p - position
	var dist := d.length()

	match behavior:
		"chase":
			if dist > 0: vel = (d / dist) * speed
		"chase_fast":
			var zig := sin(age * 4.0) * 0.4
			var ang := d.angle() + zig
			vel = Vector2(cos(ang), sin(ang)) * speed
		"ranged":
			var ideal := 250.0
			if dist > ideal + 30: vel = (d / dist) * speed
			elif dist < ideal - 30: vel = -(d / dist) * speed
			else: vel = Vector2(-d.y, d.x) / dist * speed * 0.7
			fire_timer -= dt
			if fire_timer <= 0:
				fire_timer = 1.2
				var fang := d.angle()
				for i in range(-1, 2):
					main.spawn_enemy_bullet(position, Vector2(cos(fang + i * 0.15), sin(fang + i * 0.15)) * 320.0, 5.0, color, 1, 3.0)
				Audio.shoot("pulse")

	position += vel * dt
	queue_redraw()

func _draw() -> void:
	Neon.glow(self, Vector2.ZERO, size * 2.5, color, 0.35)
	var body_color: Color = Data.WHITE if hit_flash > 0 else color
	if spawn_protect > 0:
		draw_arc(Vector2.ZERO, size + 6.0, 0, TAU, 32, Color(Data.WHITE.r, Data.WHITE.g, Data.WHITE.b, 0.6), 1.5)

	match behavior:
		"chase":
			# heavy hexagon
			var pts := PackedVector2Array()
			for i in 6:
				var a := (float(i) / 6.0) * TAU + age * 0.5
				pts.append(Vector2(cos(a), sin(a)) * size)
			Neon.poly(self, pts, Color(body_color, 0.9), color, 2.5)
		"chase_fast":
			# spiky diamond
			var pts := PackedVector2Array()
			for i in 8:
				var a := (float(i) / 8.0) * TAU + age * 2.0
				var r: float = size if i % 2 == 0 else size * 0.55
				pts.append(Vector2(cos(a), sin(a)) * r)
			Neon.poly(self, pts, Color(body_color, 0.9), color, 2.0)
		"ranged":
			# armored octagon with aperture
			var pts := PackedVector2Array()
			for i in 8:
				var a := (float(i) / 8.0) * TAU + PI / 8
				pts.append(Vector2(cos(a), sin(a)) * size)
			Neon.poly(self, pts, Color(body_color, 0.9), color, 2.5)
			draw_arc(Vector2.ZERO, size * 0.5, 0, TAU, 24, Color(color, 0.7), 1.5)

	var cp := 1.0 + sin(age * 5.0) * 0.2
	Neon.glow_dot(self, Vector2.ZERO, size * 0.3 * cp, Data.WHITE)
