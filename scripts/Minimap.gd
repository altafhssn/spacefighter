extends Control
## Circular radar (top-right) — port of drawMinimap. Shows enemies, boss and
## landmarks relative to the player.

var main = null
const RANGE := 900.0

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main == null or main.player == null: return
	var sz := size.x
	var c := Vector2(sz / 2, sz / 2)
	var radius := sz / 2 - 3.0

	# background + border
	draw_circle(c, radius, Color(Data.NAVY2.r, Data.NAVY2.g, Data.NAVY2.b, 0.55))
	draw_arc(c, radius, 0, TAU, 48, Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.5), 1.5)
	# sweep spokes
	draw_line(c, c + Vector2(radius, 0), Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.08), 1.0)
	draw_line(c, c + Vector2(0, radius), Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.08), 1.0)

	var p: Vector2 = main.player.position
	var rng_units: float = RANGE * (1.5 if main.beacon_timer > 0 else 1.0)
	var scale := radius / rng_units

	# landmarks
	if main.has_method("get_active_landmarks"):
		for lm in main.get_active_landmarks():
			var d: Vector2 = lm.pos - p
			if d.length() < rng_units:
				draw_circle(c + d * scale, 3.0, lm.color)

	# enemies
	for e in main.enemies:
		var d: Vector2 = e.position - p
		if d.length() >= rng_units: continue
		var col: Color = Data.AMBER if e.is_elite else Color(Data.MAGENTA.r, Data.MAGENTA.g, Data.MAGENTA.b, 0.9)
		draw_circle(c + d * scale, 4.0 if e.is_elite else 2.5, col)

	# boss
	if main.boss:
		var d: Vector2 = main.boss.position - p
		if d.length() < rng_units:
			draw_circle(c + d * scale, 5.0, Data.MAGENTA)
	if main.world_boss:
		var d: Vector2 = main.world_boss.position - p
		if d.length() < rng_units:
			draw_circle(c + d * scale, 5.0, main.world_boss.color)

	# player at center
	draw_circle(c, 3.0, Data.CYAN)
