class_name Player
extends Node2D
## The player ship. Movement / combat is driven by Main (mirrors the original
## single update loop); this node holds state and renders itself.

var target: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var bank := 0.0
var hp := 3
var max_hp := 3
var invuln := 0.0
var dash_timer := 0.0
var dash_cooldown := 0.0
var dash_dir: Vector2 = Vector2.ZERO
var echo_meter := 0.0
var rewind_charges := 1
var shield_timer := 0.0
var aim_angle := -PI / 2
var weapon_idx := 0
var fire_accum := 0.0
var engine_trail: Array = []   # {pos:Vector2, life, max_life}

var time := 0.0

func _draw() -> void:
	var P: Dictionary = Data.PLAYER
	var size: float = P.size

	# Engine trail (drawn in world space → convert to local)
	for t in engine_trail:
		var a: float = (t.life / t.max_life) * 0.5
		var lp: Vector2 = t.pos - position
		Neon.glow(self, lp, 10.0, Color(Data.AMBER.r, Data.AMBER.g, Data.AMBER.b, a), a * 0.7)

	var alpha := 1.0
	if invuln > 0 and int(invuln * 20) % 2 == 0:
		alpha = 0.4

	# Dash flash
	if dash_timer > 0:
		draw_circle(Vector2.ZERO, size + 10, Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.3))

	# Station shield bubble
	if shield_timer > 0:
		var sp := 0.6 + sin(time * 6.0) * 0.2
		Neon.glow(self, Vector2.ZERO, size * 2.2, Data.GREEN, 0.18)
		draw_arc(Vector2.ZERO, size + 8.0, 0, TAU, 40, Color(Data.GREEN.r, Data.GREEN.g, Data.GREEN.b, sp), 2.0)

	draw_set_transform(Vector2.ZERO, aim_angle + PI / 2 + bank, Vector2.ONE)

	# Outer glow
	Neon.glow(self, Vector2.ZERO, size * 2.5, Color(Data.CYAN, alpha), 0.4 * alpha)

	# Ship body
	var body := PackedVector2Array([
		Vector2(0, -size),
		Vector2(size * 0.8, size * 0.7),
		Vector2(size * 0.4, size * 0.5),
		Vector2(0, size * 0.3),
		Vector2(-size * 0.4, size * 0.5),
		Vector2(-size * 0.8, size * 0.7),
	])
	Neon.poly(self, body, Color(Data.CHROME, alpha), Color(Data.CYAN, alpha), 1.5)

	# Wing accents
	var wingR := PackedVector2Array([
		Vector2(size * 0.3, size * 0.2), Vector2(size * 0.75, size * 0.65),
		Vector2(size * 0.5, size * 0.6), Vector2(size * 0.2, size * 0.4)])
	var wingL := PackedVector2Array([
		Vector2(-size * 0.3, size * 0.2), Vector2(-size * 0.75, size * 0.65),
		Vector2(-size * 0.5, size * 0.6), Vector2(-size * 0.2, size * 0.4)])
	draw_colored_polygon(wingR, Color(Data.CYAN, alpha))
	draw_colored_polygon(wingL, Color(Data.CYAN, alpha))

	# Cockpit
	draw_circle(Vector2(0, -2), 3.5, Color(Data.CYAN, alpha))
	draw_circle(Vector2(-1, -3), 1.0, Color(Data.WHITE, alpha))

	# Engine flame
	var flame_len := 8.0 + sin(time * 30.0) * 3.0
	var flame := PackedVector2Array([
		Vector2(-4, size * 0.4),
		Vector2(0, size * 0.4 + flame_len),
		Vector2(4, size * 0.4)])
	draw_colored_polygon(flame, Color(Data.AMBER, alpha * 0.9))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
