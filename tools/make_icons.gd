extends SceneTree
## One-shot icon generator. Run headless:
##   godot --headless --path . --script res://tools/make_icons.gd
## Rasterizes the AETHERWING ship SVGs into the PNGs the Android export needs.

const SHIP := """
<g transform='translate(216,216)'>
  <path d='M0,-110 L88,77 L44,55 L0,33 L-44,55 L-88,77 Z' fill='#C8D2DC' stroke='#00F0FF' stroke-width='5' stroke-linejoin='round'/>
  <path d='M33,22 L83,72 L55,66 L22,44 Z' fill='#00F0FF'/>
  <path d='M-33,22 L-83,72 L-55,66 L-22,44 Z' fill='#00F0FF'/>
  <ellipse cx='0' cy='-22' rx='12' ry='16' fill='#00F0FF'/>
  <circle cx='-4' cy='-28' r='4' fill='#FFFFFF'/>
  <path d='M-15,44 L0,104 L15,44 Z' fill='#FFE600' opacity='0.9'/>
</g>
"""

const BG := """
<svg xmlns='http://www.w3.org/2000/svg' width='432' height='432' viewBox='0 0 432 432'>
 <defs><radialGradient id='bg' cx='50%' cy='42%' r='78%'>
  <stop offset='0%' stop-color='#143055'/>
  <stop offset='55%' stop-color='#0B1F3A'/>
  <stop offset='100%' stop-color='#050A14'/>
 </radialGradient></defs>
 <rect width='432' height='432' fill='url(#bg)'/>
 <circle cx='105' cy='95' r='150' fill='#FF2D7A' opacity='0.08'/>
 <circle cx='335' cy='350' r='160' fill='#00F0FF' opacity='0.08'/>
</svg>
"""

func _fg(transparent: bool) -> String:
	var bg := "" if transparent else "<rect width='432' height='432' fill='url(#bg)'/>"
	var defs := "<radialGradient id='glow'><stop offset='0%' stop-color='#00F0FF' stop-opacity='0.5'/><stop offset='100%' stop-color='#00F0FF' stop-opacity='0'/></radialGradient>"
	if not transparent:
		defs += "<radialGradient id='bg' cx='50%' cy='42%' r='78%'><stop offset='0%' stop-color='#143055'/><stop offset='55%' stop-color='#0B1F3A'/><stop offset='100%' stop-color='#050A14'/></radialGradient>"
	return "<svg xmlns='http://www.w3.org/2000/svg' width='432' height='432' viewBox='0 0 432 432'><defs>%s</defs>%s<circle cx='216' cy='216' r='150' fill='url(#glow)'/>%s</svg>" % [defs, bg, SHIP]

func _mono() -> String:
	var ship := SHIP.replace("#C8D2DC", "#FFFFFF").replace("#00F0FF", "#FFFFFF").replace("#FFE600", "#FFFFFF").replace("stroke-width='5'", "stroke-width='0'")
	return "<svg xmlns='http://www.w3.org/2000/svg' width='432' height='432' viewBox='0 0 432 432'>%s</svg>" % ship

func _initialize() -> void:
	var d := DirAccess.open("res://")
	if not d.dir_exists("icons"): d.make_dir("icons")
	_save(BG, 1.0, "res://icons/icon_bg.png")
	_save(_fg(true), 1.0, "res://icons/icon_fg.png")
	_save(_mono(), 1.0, "res://icons/icon_mono.png")
	_save(_fg(false), 192.0 / 432.0, "res://icons/icon_main.png")
	_save(_fg(false), 1.0, "res://icons/icon_512.png")
	print("ICONS DONE")
	quit()

func _save(svg: String, scale: float, path: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK:
		push_error("svg fail: " + path)
		return
	img.save_png(path)
	print("saved ", path, " ", img.get_width(), "x", img.get_height())
