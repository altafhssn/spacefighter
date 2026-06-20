class_name HealthPickup
extends Node2D

var life := 18.0
var value := 1
var t := 0.0
var size := 13.0

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(t * 5.0) * 0.12
	Neon.glow(self, Vector2.ZERO, size * 2.8 * pulse, Data.GREEN, 0.32)
	draw_arc(Vector2.ZERO, size * 1.35 * pulse, 0.0, TAU, 28, Color(Data.GREEN, 0.7), 2.0)
	draw_rect(Rect2(-3.0, -size * 0.7, 6.0, size * 1.4), Data.WHITE)
	draw_rect(Rect2(-size * 0.7, -3.0, size * 1.4, 6.0), Data.WHITE)
