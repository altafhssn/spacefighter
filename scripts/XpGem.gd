class_name XpGem
extends Node2D
## XP gem dropped by enemies, auto-collected via magnet. Movement handled by Main.

var vel: Vector2 = Vector2.ZERO
var value := 1
var life := 12.0
var gravity := 60.0
var size := 6.0
var collected := false
var t := 0.0

func _draw() -> void:
	var pulse := 1.0 + sin(t * 8.0) * 0.15
	Neon.glow(self, Vector2.ZERO, size * 3.0 * pulse, Data.GREEN, 0.3)
	var s := size * pulse
	var diamond := PackedVector2Array([
		Vector2(0, -s), Vector2(s * 0.7, 0), Vector2(0, s), Vector2(-s * 0.7, 0)])
	draw_colored_polygon(diamond, Data.GREEN)
	draw_circle(Vector2.ZERO, size * 0.35, Data.WHITE)
