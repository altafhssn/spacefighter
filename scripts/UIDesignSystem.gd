class_name UIDesignSystem
extends RefCounted

## Central UI design system for every AETHERWING screen.
## Keep colors, typography, spacing, touch targets and component styling here.

# Palette — high contrast on the near-black game background.
const SURFACE_0 := Color("050816")
const SURFACE_1 := Color("0A1224")
const SURFACE_2 := Color("101D35")
const TEXT_PRIMARY := Color("F4FBFF")
const TEXT_SECONDARY := Color("B8C9D8")
const TEXT_MUTED := Color("8293A6")
const CYAN := Color("20E6FF")
const CYAN_BRIGHT := Color("7AF4FF")
const MAGENTA := Color("FF63D8")
const GREEN := Color("45F0A5")
const AMBER := Color("FFD166")
const DANGER := Color("FF8F9C")

# Typography. At the 720x1280 reference viewport, body copy never drops below
# 14 px and primary controls use 18–24 px.
const FONT_CAPTION := 12
const FONT_BODY := 14
const FONT_BUTTON := 18
const FONT_BUTTON_PRIMARY := 22
const FONT_SECTION := 18
const FONT_TITLE := 46
const FONT_SCORE := 22

# Layout / touch. 56 px is the minimum mobile touch target; main actions use 64.
const TOUCH_MIN := 56
const TOUCH_PRIMARY := 68
const GAP_SMALL := 12
const GAP_BUTTON := 18
const GAP_SECTION := 28
const SCREEN_MARGIN := 32
const CORNER_BUTTON := 14
const CORNER_PANEL := 22

static func panel_style(accent: Color = CYAN, alpha := 0.92, radius := CORNER_PANEL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(SURFACE_1.r, SURFACE_1.g, SURFACE_1.b, alpha)
	style.set_border_width_all(1)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func button_styles(accent: Color, primary := false) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.24 if primary else 0.095)
	normal.set_border_width_all(2 if primary else 1)
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.88 if primary else 0.62)
	normal.set_corner_radius_all(CORNER_BUTTON)
	normal.content_margin_left = 20
	normal.content_margin_right = 20

	# Sci-fi rail: the thicker left edge gives every action a recognizable,
	# consistent silhouette without reducing readability.
	normal.border_width_left = 5

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.34 if primary else 0.18)
	hover.border_color = accent

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.46)
	pressed.set_border_width_all(2)
	pressed.border_width_left = 7

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(SURFACE_2, 0.5)
	disabled.border_color = Color(TEXT_MUTED, 0.35)

	return {"normal": normal, "hover": hover, "pressed": pressed, "disabled": disabled}

static func apply_button(button: Button, font: Font, accent: Color, primary := false) -> void:
	var styles := button_styles(accent, primary)
	button.custom_minimum_size.y = TOUCH_PRIMARY if primary else TOUCH_MIN
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", FONT_BUTTON_PRIMARY if primary else FONT_BUTTON)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	button.add_theme_stylebox_override("normal", styles.normal)
	button.add_theme_stylebox_override("hover", styles.hover)
	button.add_theme_stylebox_override("pressed", styles.pressed)
	button.add_theme_stylebox_override("disabled", styles.disabled)
	button.focus_mode = Control.FOCUS_NONE
