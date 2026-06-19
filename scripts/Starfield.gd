extends Control
## Parallax starfield drawn in screen space and offset by the camera position
## (port of initStarfield/drawStarfield).

var main = null
var nebulae: Array = []
var layers: Array = []          # 3 parallax layers of stars
const DEPTHS := [0.3, 0.5, 0.8]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_generate()
	get_viewport().size_changed.connect(_generate)

func _generate() -> void:
	var vp := get_viewport_rect().size
	var w: float = max(vp.x, 1.0)
	var h: float = max(vp.y, 1.0)
	nebulae.clear()
	for i in 6:
		nebulae.append({
			"pos": Vector2(randf() * w, randf() * h),
			"r": 120.0 + randf() * 220.0,
			"color": [Data.MAGENTA, Data.CYAN, Data.PURPLE][i % 3],
		})
	layers.clear()
	for d in DEPTHS.size():
		var stars: Array = []
		var n := int(70 / (d + 1)) + 30
		for i in n:
			stars.append({
				"pos": Vector2(randf() * w, randf() * h),
				"r": 0.6 + randf() * 1.6,
				"tw": randf() * TAU,
			})
		layers.append(stars)

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var w := vp.x
	var h := vp.y
	var cam: Vector2 = main.cam if main else Vector2.ZERO
	var time: float = main.time if main else 0.0

	# Nebula blobs (slow parallax)
	for n in nebulae:
		var np: Vector2 = n.pos - cam * 0.08
		np.x = fposmod(np.x, w + n.r * 2) - n.r
		np.y = fposmod(np.y, h + n.r * 2) - n.r
		Neon.glow(self, np, n.r, n.color, 0.035)

	# Star layers
	for li in layers.size():
		var depth: float = DEPTHS[li]
		for s in layers[li]:
			var sp: Vector2 = s.pos - cam * depth
			sp.x = fposmod(sp.x, w)
			sp.y = fposmod(sp.y, h)
			var tw: float = 0.7 + sin(time * 2.0 + s.tw) * 0.3
			draw_circle(sp, s.r, Color(Data.WHITE.r, Data.WHITE.g, Data.WHITE.b, 0.5 * tw))
