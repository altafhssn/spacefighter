extends Control
## Decorative menu frame: animated corner brackets + thin accent rails.
## Pure cosmetic overlay (mouse-ignored) for the start screen.

var t := 0.0

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var m := 18.0          # margin from edge
	var L := 50.0          # bracket arm length
	var lw := 2.0
	var a: float = 0.45 + sin(t * 1.6) * 0.14
	var cy := Color(Data.CYAN, a)

	# four L-shaped corner brackets
	var corners := [
		[Vector2(m, m), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(w - m, m), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(m, h - m), Vector2(1, 0), Vector2(0, -1)],
		[Vector2(w - m, h - m), Vector2(-1, 0), Vector2(0, -1)],
	]
	for c in corners:
		var p: Vector2 = c[0]
		draw_line(p, p + c[1] * L, cy, lw)
		draw_line(p, p + c[2] * L, cy, lw)
		draw_circle(p, 2.5, Color(Data.CYAN, a + 0.2))

	# faint accent rails along top/bottom between the brackets
	draw_line(Vector2(m + L + 12, m), Vector2(w - m - L - 12, m), Color(Data.CYAN, 0.12), 1.0)
	draw_line(Vector2(m + L + 12, h - m), Vector2(w - m - L - 12, h - m), Color(Data.MAGENTA, 0.12), 1.0)

	# a slow scan sweep down the left rail for life
	var sy: float = m + fmod(t * 90.0, max(1.0, h - m * 2))
	draw_line(Vector2(m, sy), Vector2(m, sy + 40.0), Color(Data.CYAN, 0.5), lw)
