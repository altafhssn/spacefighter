extends Node2D
## Draws particles, scorch decals and floating damage numbers held in Main's
## arrays (world space). Simulation lives in Main to match the original loop.

var main = null
var font: Font

func _ready() -> void:
	z_index = 50
	font = ThemeDB.fallback_font

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main == null:
		return
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
