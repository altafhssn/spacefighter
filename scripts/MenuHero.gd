extends Control

## Animated menu centerpiece: the ship is framed as the product hero rather
## than leaving the home screen as a stack of controls.

var t := 0.0

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5 + Vector2(0, 8)
	var breathe := 1.0 + sin(t * 1.8) * 0.025
	for i in 3:
		var r := (62.0 + i * 34.0) * breathe
		var alpha := 0.18 - i * 0.045
		draw_arc(c, r, -PI * 0.82 + t * (0.08 + i * 0.02),
			PI * 0.28 + t * (0.08 + i * 0.02), 42, Color(Data.CYAN, alpha), 1.2)
		draw_arc(c, r, PI * 0.45 - t * (0.06 + i * 0.015),
			PI * 1.15 - t * (0.06 + i * 0.015), 30, Color(Data.MAGENTA, alpha * 0.8), 1.0)
	Neon.glow(self, c, 86.0, Data.CYAN, 0.12)
	var ship := PackedVector2Array([
		c + Vector2(0, -38),
		c + Vector2(26, 25),
		c + Vector2(8, 17),
		c + Vector2(0, 30),
		c + Vector2(-8, 17),
		c + Vector2(-26, 25),
	])
	Neon.poly(self, ship, Color(Data.CHROME, 0.9), Data.CYAN, 2.2)
	var wing_r := PackedVector2Array([
		c + Vector2(5, 2), c + Vector2(23, 24),
		c + Vector2(11, 18), c + Vector2(2, 10)])
	var wing_l := PackedVector2Array([
		c + Vector2(-5, 2), c + Vector2(-23, 24),
		c + Vector2(-11, 18), c + Vector2(-2, 10)])
	draw_colored_polygon(wing_r, Color(Data.CYAN, 0.75))
	draw_colored_polygon(wing_l, Color(Data.CYAN, 0.75))
	draw_circle(c + Vector2(0, -7), 5.0, Data.CYAN_SOFT)
	draw_circle(c + Vector2(-1.5, -9), 1.5, Data.WHITE)
	var flame := 13.0 + sin(t * 14.0) * 3.0
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-5, 22), c + Vector2(0, 22 + flame), c + Vector2(5, 22)]),
		Color(Data.AMBER, 0.9))
	for i in 10:
		var a := t * (0.12 + i * 0.006) + i * 2.17
		var p := c + Vector2.from_angle(a) * (95.0 + (i % 3) * 22.0)
		draw_circle(p, 1.2 + (i % 2), Color(Data.WHITE, 0.22 + (i % 3) * 0.08))
