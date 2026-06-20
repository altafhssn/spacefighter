extends Node2D
## Draws particles, scorch decals and floating damage numbers held in Main's
## arrays (world space). Simulation lives in Main to match the original loop.

var main = null
var font: Font
var redraw_timer := 0.0

func _ready() -> void:
	z_index = 50
	font = ThemeDB.fallback_font

func _process(dt: float) -> void:
	redraw_timer -= dt
	if redraw_timer <= 0.0 and (main.arena_active or not main.particles.is_empty()
			or not main.decals.is_empty() or not main.damage_numbers.is_empty()):
		queue_redraw()
		redraw_timer = 1.0 / 30.0

func _draw() -> void:
	if main == null:
		return

	# Boss arena boundary — pulsing dashed ring the player can't cross
	if main.arena_active:
		var c: Vector2 = main.arena_center
		var r: float = main.arena_radius
		var pulse: float = 0.45 + sin(main.time * 2.5) * 0.18
		var col := Color(Data.MAGENTA.r, Data.MAGENTA.g, Data.MAGENTA.b, pulse)
		var segs := 40
		for i in segs:
			if i % 2 == 1:
				continue
			var a0: float = (float(i) / segs) * TAU + main.time * 0.15
			var a1: float = (float(i + 1) / segs) * TAU + main.time * 0.15
			draw_arc(c, r, a0, a1, 6, col, 3.0)
		# soft inner edge glow
		draw_arc(c, r - 4.0, 0, TAU, 48, Color(Data.MAGENTA.r, Data.MAGENTA.g, Data.MAGENTA.b, 0.08), 8.0)

	# Decals (under everything else fx)
	for d in main.decals:
		var a: float = d.life / d.max_life * 0.4
		draw_circle(d.pos, d.size, Color(d.color.r, d.color.g, d.color.b, a * 0.5))

	# Particles
	for p in main.particles:
		var a: float = clamp(p.life / p.max_life, 0.0, 1.0)
		draw_circle(p.pos, p.size, Color(p.color.r, p.color.g, p.color.b, a))

	# Damage numbers
	for d in main.damage_numbers:
		var a: float = clamp(d.life / d.max_life, 0.0, 1.0)
		var fs: int = 20 if d.big else 13
		var col := Color(d.color.r, d.color.g, d.color.b, a)
		var txt: String = str(d.text)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, d.pos + Vector2(-w / 2, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
