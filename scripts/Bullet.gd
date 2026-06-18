class_name Bullet
extends Node2D
## Player and enemy projectiles. Movement / collision handled by Main so the
## singularity gravity-well interactions match the original exactly.

var friendly := true
var vel: Vector2 = Vector2.ZERO
var size := 4.0
var color: Color = Data.CYAN
var damage := 6.0
var life := 2.0
var hit := false
var is_beam := false
var is_critical := false
var trail: Array = []   # world-space Vector2

# pierce
var pierce := 0
var pierce_hits: Array = []

# singularity
var is_singularity := false
var singularity_activated := false
var singularity_radius := 120.0
var singularity_duration := 1.5
var singularity_pull := 200.0

func _draw() -> void:
	if is_singularity and singularity_activated:
		var pulse := 1.0 + sin(main_time() * 8.0) * 0.15
		Neon.glow(self, Vector2.ZERO, singularity_radius * pulse, Data.PURPLE, 0.25)
		draw_arc(Vector2.ZERO, singularity_radius, 0, TAU, 48, Color(Data.PURPLE.r, Data.PURPLE.g, Data.PURPLE.b, 0.5), 2.0)
		draw_circle(Vector2.ZERO, 6.0 * pulse, Data.WHITE)
		return

	# Trail (world coords → local)
	for i in trail.size():
		var a: float = (float(i) / max(1, trail.size())) * 0.5
		var lp: Vector2 = trail[i] - position
		draw_circle(lp, size * 0.6, Color(color.r, color.g, color.b, a))

	Neon.glow_dot(self, Vector2.ZERO, size, color)
	if is_beam:
		# stretch a small streak along velocity
		var dir := vel.normalized() * size * 2.0
		draw_line(-dir, dir, Color(color, 0.8), size * 0.8)

var _mt := 0.0
func main_time() -> float:
	return _mt
func set_time(t: float) -> void:
	_mt = t
