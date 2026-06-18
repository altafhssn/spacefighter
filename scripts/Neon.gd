class_name Neon
extends RefCounted
## Drawing helpers for the neon-vector aesthetic.
## Uses a smooth radial-gradient texture to reproduce the canvas
## radial-gradient glows from the original prototype (no banding).

static var _radial: GradientTexture2D

static func _tex() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.32), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_radial = t
	return _radial

static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color, intensity := 0.4) -> void:
	ci.draw_texture_rect(_tex(), Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)),
		false, Color(color.r, color.g, color.b, intensity))

static func glow_dot(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	glow(ci, pos, radius * 2.6, color, 0.5)
	ci.draw_circle(pos, radius, color)

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, stroke: Color, width := 1.5) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, stroke, width, true)
