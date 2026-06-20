class_name Landmark
extends Node2D
## A world landmark (cache / station / ruins / beacon). Interaction range is
## intentionally separate from visual scale so landmarks feel like objects in
## space instead of oversized HUD reticles.

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
var redraw_timer := 0.0

func _ready() -> void:
	font = ThemeDB.fallback_font
	var def: Dictionary = Data.LANDMARK_TYPES[type]
	radius = def.radius
	color = def.color
	icon = def.icon

func _process(dt: float) -> void:
	# Only animate/redraw landmarks near the player; cached far ones stay idle.
	var near: bool = main and main.player and position.distance_to(main.player.position) < 1600.0
	visible = near
	redraw_timer -= dt
	if near and redraw_timer <= 0.0:
		queue_redraw()
		redraw_timer = 1.0 / 20.0

func _draw() -> void:
	var t: float = main.time if main else 0.0
	var pulse: float = 1.0 + sin(t * 2.4 + position.x * 0.01) * 0.045
	var visual_radius: float = minf(radius * 0.62, 34.0)

	if visited:
		draw_arc(Vector2.ZERO, visual_radius * 0.75, 0, TAU, 24, Color(color, 0.22), 1.0)
		_icon(Color(color, 0.32), 20)
		return

	# Guarded landmarks always explain the lock and exact objective.
	if guarded:
		var dc := Color(Data.MAGENTA.r, Data.MAGENTA.g, Data.MAGENTA.b, 0.5 + sin(t * 3.0) * 0.2)
		_dashed_ring(visual_radius * 1.55 * pulse, dc)
		var lock_text := "🔒  LOCKED"
		var lock_w := font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2(-lock_w / 2, -visual_radius - 30), lock_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Data.MAGENTA_SOFT)
		var guardian_name: String = Data.MINI_BOSS_TYPES.get(guard_type, {"name": "GUARDIAN"}).name
		var objective := "DEFEAT %s TO UNLOCK" % guardian_name
		var objective_w := font.get_string_size(objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, Vector2(-objective_w / 2, -visual_radius - 14), objective,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Data.WHITE)

	match type:
		"ruins": _draw_ruins(t, visual_radius, pulse)
		"cache": _draw_cache(t, visual_radius, pulse)
		"station": _draw_station(t, visual_radius, pulse)
		"beacon": _draw_beacon(t, visual_radius, pulse)

	# label when close
	if main and main.player and position.distance_to(main.player.position) < 350:
		var def: Dictionary = Data.LANDMARK_TYPES[type]
		var nm: String = ("%s — LOCKED" % def.name) if guarded else def.name
		var w := font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(-w / 2, visual_radius + 24), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, 0.78))
		var effect: String
		if guarded:
			var guardian_name: String = Data.MINI_BOSS_TYPES.get(guard_type, {"name": "GUARDIAN"}).name
			effect = "DEFEAT %s TO CLAIM: %s" % [guardian_name, def.effect]
		else:
			effect = def.effect
		var ew := font.get_string_size(effect, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string(font, Vector2(-ew / 2, visual_radius + 39), effect,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Data.WHITE, 0.62))

func _draw_ruins(t: float, r: float, pulse: float) -> void:
	# Broken orbital relic: asymmetry and missing sections keep it grounded in
	# world space instead of reading as a targeting reticle.
	Neon.glow(self, Vector2.ZERO, r * 1.35, color, 0.13)
	var rot: float = t * 0.12
	var arcs: Array = [
		[-0.10, 0.92],
		[1.32, 2.18],
		[2.62, 3.74],
		[4.14, 5.38],
	]
	for arc in arcs:
		draw_arc(Vector2.ZERO, r * pulse, float(arc[0]) + rot, float(arc[1]) + rot,
			12, Color(color, 0.8), 2.0, true)
	# Three relic pylons point toward a small crystal core.
	for i in 3:
		var a: float = rot * -0.6 + float(i) / 3.0 * TAU
		var center: Vector2 = Vector2.from_angle(a) * r * 0.68
		var tangent: Vector2 = Vector2.from_angle(a + PI / 2.0)
		var inward: Vector2 = -Vector2.from_angle(a)
		var shard := PackedVector2Array([
			center + inward * 8.0,
			center + tangent * 4.0,
			center - tangent * 4.0,
		])
		Neon.poly(self, shard, Color(color, 0.14), Color(color, 0.65), 1.2)
	var core_r: float = 7.0 + sin(t * 3.5) * 0.8
	var core := PackedVector2Array([
		Vector2(0, -core_r),
		Vector2(core_r * 0.85, core_r * 0.7),
		Vector2(-core_r * 0.85, core_r * 0.7),
	])
	Neon.poly(self, core, Color(color, 0.22), Color(color, 0.95), 1.5)
	draw_circle(Vector2.ZERO, 2.0, Data.WHITE)
	for i in 4:
		var a: float = t * (0.35 + i * 0.03) + float(i) * 1.7
		var p: Vector2 = Vector2.from_angle(a) * (r * (0.45 + i * 0.11))
		draw_circle(p, 1.2, Color(color, 0.45))

func _draw_cache(t: float, r: float, pulse: float) -> void:
	Neon.glow(self, Vector2.ZERO, r * 1.25, color, 0.12)
	var rot: float = t * 0.18
	var outer := _regular_polygon(6, r * pulse, rot)
	var inner := _regular_polygon(6, r * 0.62, -rot * 0.7)
	Neon.poly(self, outer, Color(color, 0.055), Color(color, 0.85), 2.0)
	Neon.poly(self, inner, Color(color, 0.09), Color(color, 0.45), 1.0)
	for i in 3:
		var a: float = rot + float(i) / 3.0 * TAU
		draw_line(Vector2.from_angle(a) * r * 0.68, Vector2.from_angle(a) * r * 0.92,
			Color(color, 0.65), 2.0)
	_icon(color, 22)

func _draw_station(t: float, r: float, pulse: float) -> void:
	Neon.glow(self, Vector2.ZERO, r * 1.3, color, 0.11)
	var rot: float = t * 0.22
	for i in 4:
		var a: float = rot + float(i) / 4.0 * TAU
		var p: Vector2 = Vector2.from_angle(a) * r * 0.72
		draw_circle(p, 5.0 * pulse, Color(color, 0.14))
		draw_arc(p, 5.0 * pulse, 0, TAU, 16, Color(color, 0.75), 1.4)
	draw_rect(Rect2(-3, -r * 0.45, 6, r * 0.9), Color(color, 0.85))
	draw_rect(Rect2(-r * 0.45, -3, r * 0.9, 6), Color(color, 0.85))
	draw_circle(Vector2.ZERO, 3.0, Data.WHITE)

func _draw_beacon(t: float, r: float, pulse: float) -> void:
	Neon.glow(self, Vector2.ZERO, r * 1.25, color, 0.11)
	var sweep: float = fmod(t * 0.55, 1.0)
	draw_line(Vector2(0, r * 0.7), Vector2(0, -r * 0.7), Color(color, 0.75), 2.0)
	var top := Vector2(0, -r * 0.72)
	var tri := PackedVector2Array([top, Vector2(-8, -r * 0.36), Vector2(8, -r * 0.36)])
	Neon.poly(self, tri, Color(color, 0.16), Color(color, 0.8), 1.5)
	draw_arc(Vector2.ZERO, r * (0.35 + sweep * 0.65) * pulse, -PI * 0.82, -PI * 0.18,
		18, Color(color, (1.0 - sweep) * 0.7), 1.5)
	draw_circle(Vector2.ZERO, 3.0, Data.WHITE)

func _regular_polygon(sides: int, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		pts.append(Vector2.from_angle(rot + float(i) / sides * TAU) * r)
	return pts

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
