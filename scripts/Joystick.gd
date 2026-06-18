extends Control
## Faint floating virtual joystick — drawn in screen space when the player is
## steering in JOYSTICK mode. Kept low-opacity ("~10% visible") so it never
## obscures the action. State lives on Main.

var main = null

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main == null or not main.joy_active:
		return
	var c: Color = Data.CYAN
	var o: Vector2 = main.joy_origin
	var knob: Vector2 = main.joy_origin + main.joy_vec
	var r: float = main.JOY_RADIUS

	# base ring (very subtle)
	draw_circle(o, r, Color(c.r, c.g, c.b, 0.06))
	draw_arc(o, r, 0, TAU, 48, Color(c.r, c.g, c.b, 0.14), 2.0)
	draw_arc(o, r * 0.5, 0, TAU, 32, Color(c.r, c.g, c.b, 0.07), 1.0)

	# knob — brightens with push magnitude
	var a: float = 0.12 + main.joy_mag * 0.22
	draw_circle(knob, r * 0.42, Color(c.r, c.g, c.b, a * 0.5))
	draw_arc(knob, r * 0.42, 0, TAU, 28, Color(c.r, c.g, c.b, a + 0.1), 2.0)
	draw_circle(knob, 3.0, Color(c.r, c.g, c.b, a + 0.2))
