class_name Landmark
extends Node2D
## A world landmark (cache / station / ruins / beacon). Discovery + effects are
## handled by Main; this node renders the ring/spokes/icon/aura. Port of drawLandmarks.

var main = null
var type := "cache"
var key := ""
var visited := false
var guarded := false
var guard_type := ""
var guard_triggered := false
var radius := 50.0
var color: Color = Data.AMBER
var icon := "⬡"
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	var def: Dictionary = Data.LANDMARK_TYPES[type]
	radius = def.radius
	color = def.color
	icon = def.icon

func _process(_dt: float) -> void:
	# Only animate/redraw landmarks near the player; cached far ones stay idle.
	var near: bool = main and main.player and position.distance_to(main.player.position) < 1600.0
	visible = near
	if near:
		queue_redraw()

func _draw() -> void:
	var t: float = main.time if main else 0.0
	var pulse := 1.0 + sin(t * 2.0 + position.x * 0.01) * 0.1

	# aura
	Neon.glow(self, Vector2.ZERO, radius * 2.5 * pulse, color, 0.05 if visited else 0.22)

	if visited:
		draw_arc(Vector2.ZERO, radius * 0.7, 0, TAU, 32, Color(color, 0.3), 1.5)
		_icon(Color(color, 0.4), 26)
		return

	# guarded warning ring + skull
	if guarded and not guard_triggered:
		var dc := Color(Data.MAGENTA.r, Data.MAGENTA.g, Data.MAGENTA.b, 0.5 + sin(t * 3.0) * 0.2)
		_dashed_ring(radius * 1.4 * pulse, dc)
		var fs := 18
		var skull := "☠"
		var w := font.get_string_size(skull, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(-w / 2, -radius - 18), skull, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Data.MAGENTA)

	draw_arc(Vector2.ZERO, radius * pulse, 0, TAU, 40, color, 2.5)
	draw_arc(Vector2.ZERO, radius * 0.65 * pulse, 0, TAU, 32, Color(color, 0.5), 1.0)

	# rotating spokes
	var sa := t * 0.8
	for i in 4:
		var a := sa + (float(i) / 4.0) * TAU
		var p1 := Vector2(cos(a), sin(a)) * radius * 0.7
		var p2 := Vector2(cos(a), sin(a)) * radius * 1.1
		draw_line(p1, p2, Color(color, 0.6), 1.5)

	_icon(color, 32)

	# label when close
	if main and main.player and position.distance_to(main.player.position) < 350:
		var def: Dictionary = Data.LANDMARK_TYPES[type]
		var nm: String = def.name
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(-w / 2, radius + 22), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, 0.8))

func _icon(col: Color, fs: int) -> void:
	var w := font.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, Vector2(-w.x / 2, fs * 0.35), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _dashed_ring(r: float, c: Color) -> void:
	var segs := 24
	for i in segs:
		if i % 2 == 1: continue
		var a0 := (float(i) / segs) * TAU
		var a1 := (float(i + 1) / segs) * TAU
		draw_arc(Vector2.ZERO, r, a0, a1, 4, c, 2.0)
