extends CanvasLayer
## HUD + overlays (start / game-over / level-up), built in code.
## Restyled to the "Neon Survivor System" Stitch design:
##   fonts  = Space Grotesk (headlines) + JetBrains Mono (readouts/labels)
##   look   = glassmorphism cyber-panels, neon borders, segmented bars,
##            chamfer-less sharp geometry, hex/parallelogram pips.

var main = null

# ------------------------------------------------------------
# DESIGN TOKENS (from neon_survivor_system/DESIGN.md)
# ------------------------------------------------------------
const VOID      := Color("020617")   # panel base
const CY        := Color("00F3FF")   # Aether (primary)
const CY_SOFT   := Color("6FF6FF")
const MG        := Color("FE00FE")   # Wing (secondary)
const MG_SOFT   := Color("FFABF3")
const AM        := Color("FFBF00")   # Echo (tertiary)
const AM_SOFT   := Color("FBBC00")
const GREEN     := Color("10B981")   # Launch (success)
const GREEN_BR  := Color("4ADE80")
const ERR       := Color("FFB4AB")   # health red
const OUTLINE   := Color("849495")
const OUTLINE_V := Color("3A494B")
const TXT       := Color("DCE4E4")
const TXT_DIM   := Color("B9CACB")

# fonts
var f_head: FontFile      # Space Grotesk
var f_mono: FontFile      # JetBrains Mono
var fv_display: FontVariation
var fv_title: FontVariation
var fv_num: FontVariation
var fv_label: FontVariation
var fv_body: FontVariation
var f_sym: Font           # fallback (for ♥ ↺ ◆ and modifier icons)
var _notch: ImageTexture

# container holding all in-game widgets (hidden on menus)
var gameplay_hud: Control

# stat widgets
var score_lbl: Label
var combo_lbl: Label
var hp_lbl: Label
var wave_lbl: Label
var weapon_lbl: Label
var slots_box: HBoxContainer
var echo_fill: ColorRect
var echo_pct_lbl: Label
var xp_fill: ColorRect
var xp_lbl: Label
var rewind_lbl: Label

# boss
var boss_wrap: Control
var boss_name_lbl: Label
var boss_fill: ColorRect

# world mini-boss bar
var wboss_wrap: Control
var wboss_name_lbl: Label
var wboss_fill: ColorRect

# radar + world position
var minimap: Control
var world_pos_lbl: Label
var mod_badge: Label
var wk_badge: Label

# misc
var toast_lbl: Label
var wave_intro_lbl: Label
var announce_lbl: Label
var boost_btn: Button
var dash_btn: Button

# overlays
var start_overlay: Control
var gameover_overlay: Control
var levelup_overlay: Control
var final_score_lbl: Label
var final_wave_lbl: Label
var final_combo_lbl: Label
var best_lbl: Label
var start_best_lbl: Label
var logo_pulse: Label
var mod_icon_lbl: Label
var mod_name_lbl: Label
var mod_desc_lbl: Label
var wk_icon_lbl: Label
var wk_name_lbl: Label
var wk_desc_lbl: Label
var mode_joystick_btn: Button
var mode_follow_btn: Button
var mode_direct_btn: Button
var swap_btn: Button
var cards_box: VBoxContainer

# flashes
var damage_flash: ColorRect
var rewind_flash: ColorRect
var death_flash: ColorRect
var echo_overlay: ColorRect


# ============================================================
# FONTS
# ============================================================
func _load_fonts() -> void:
	f_sym = ThemeDB.fallback_font
	f_head = load("res://fonts/SpaceGrotesk.ttf")
	f_mono = load("res://fonts/JetBrainsMono.ttf")
	fv_display = _fv(f_head, 700)
	fv_title   = _fv(f_head, 700)
	fv_num     = _fv(f_mono, 700)
	fv_label   = _fv(f_mono, 600)
	fv_body    = _fv(f_mono, 400)

func _fv(base: Font, wght: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": wght}
	return v


# ============================================================
# LABEL HELPERS
# ============================================================
# in-game readout: dark outline for legibility over the action
func _lbl(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 5)
	return l

# menu/title: faint colored halo to fake neon bloom
func _glow(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.22))
	l.add_theme_constant_override("outline_size", 10)
	return l

func _ctr(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ============================================================
# BUILD
# ============================================================
func build() -> void:
	_load_fonts()
	_notch = _make_notch()
	var vp := _vp()

	# --- full-screen flashes / tints ---
	echo_overlay = _full_rect(Color(AM.r, AM.g, AM.b, 0.12)); echo_overlay.visible = false
	add_child(echo_overlay)
	damage_flash = _full_rect(Color(MG.r, MG.g, MG.b, 0.0)); add_child(damage_flash)
	rewind_flash = _full_rect(Color(CY.r, CY.g, CY.b, 0.0)); add_child(rewind_flash)
	death_flash = _full_rect(Color(1, 1, 1, 0.0)); add_child(death_flash)

	# --- gameplay HUD container ---
	gameplay_hud = Control.new()
	gameplay_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gameplay_hud)

	# ---- top-left: SCORE / COMBO panel + HP / rewind ----
	var tl_panel := _panel(CY, 0.5)
	tl_panel.position = Vector2(20, 16)
	gameplay_hud.add_child(tl_panel)
	var tl := VBoxContainer.new(); tl.add_theme_constant_override("separation", 2)
	tl_panel.add_child(tl)
	var sc_row := HBoxContainer.new(); sc_row.add_theme_constant_override("separation", 8)
	sc_row.add_child(_lbl("SCORE", fv_label, 12, OUTLINE))
	score_lbl = _lbl("0", fv_num, 22, AM_SOFT); sc_row.add_child(score_lbl)
	tl.add_child(sc_row)
	var cb_row := HBoxContainer.new(); cb_row.add_theme_constant_override("separation", 8)
	cb_row.add_child(_lbl("COMBO", fv_label, 12, OUTLINE))
	combo_lbl = _lbl("x1", fv_num, 22, MG_SOFT); cb_row.add_child(combo_lbl)
	tl.add_child(cb_row)

	# HP hearts + rewind token (symbols → fallback font)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	hp_row.position = Vector2(24, 86)
	gameplay_hud.add_child(hp_row)
	hp_lbl = _lbl("", f_sym, 22, ERR); hp_row.add_child(hp_lbl)
	rewind_lbl = _lbl("", f_sym, 18, CY_SOFT); hp_row.add_child(rewind_lbl)

	# ---- top-center: modifier badges + boss bar ----
	mod_badge = _ctr(_lbl("", fv_label, 11, AM_SOFT))
	mod_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mod_badge.offset_top = 12; mod_badge.offset_bottom = 28
	gameplay_hud.add_child(mod_badge)
	wk_badge = _ctr(_lbl("", fv_label, 11, MG_SOFT))
	wk_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wk_badge.offset_top = 30; wk_badge.offset_bottom = 46
	gameplay_hud.add_child(wk_badge)

	boss_wrap = _passthru(); boss_wrap.visible = false
	gameplay_hud.add_child(boss_wrap)
	boss_name_lbl = _ctr(_lbl("BOSS", fv_label, 13, ERR))
	boss_name_lbl.position = Vector2(vp.x / 2 - 160, 56); boss_name_lbl.size = Vector2(320, 18)
	boss_wrap.add_child(boss_name_lbl)
	boss_fill = _seg_bar(boss_wrap, Vector2(vp.x / 2 - 160, 80), Vector2(320, 12), ERR, ERR)

	# ---- top-right: WAVE / WEAPON panel + ECHO ----
	var tr_panel := _panel(CY, 0.5)
	tr_panel.position = Vector2(vp.x - 200, 16)
	gameplay_hud.add_child(tr_panel)
	var tr := VBoxContainer.new(); tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 2)
	tr_panel.add_child(tr)
	wave_lbl = _lbl("WAVE 1", fv_title, 24, TXT); wave_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(wave_lbl)
	tr.add_child(_r(_lbl("WEAPON", fv_label, 10, OUTLINE)))
	var wpn_row := HBoxContainer.new(); wpn_row.add_theme_constant_override("separation", 8)
	wpn_row.alignment = BoxContainer.ALIGNMENT_END
	weapon_lbl = _lbl("PULSE", fv_label, 14, CY_SOFT); wpn_row.add_child(weapon_lbl)
	slots_box = HBoxContainer.new(); slots_box.add_theme_constant_override("separation", 3)
	for i in 4:
		var s := ColorRect.new(); s.custom_minimum_size = Vector2(8, 14)
		s.color = Color(1, 1, 1, 0.2); slots_box.add_child(s)
	wpn_row.add_child(slots_box)
	tr.add_child(wpn_row)

	echo_pct_lbl = _r(_lbl("ECHO 0%", fv_label, 10, AM_SOFT))
	echo_pct_lbl.position = Vector2(vp.x - 160, 92); echo_pct_lbl.size = Vector2(140, 14)
	gameplay_hud.add_child(echo_pct_lbl)
	echo_fill = _seg_bar(gameplay_hud, Vector2(vp.x - 140, 108), Vector2(120, 8), AM, AM)

	# ---- world mini-boss bar (bottom-center) ----
	wboss_wrap = _passthru(); wboss_wrap.visible = false
	gameplay_hud.add_child(wboss_wrap)
	wboss_name_lbl = _ctr(_lbl("GUARDIAN", fv_label, 13, MG_SOFT))
	wboss_name_lbl.position = Vector2(vp.x / 2 - 160, vp.y - 92); wboss_name_lbl.size = Vector2(320, 18)
	wboss_wrap.add_child(wboss_name_lbl)
	wboss_fill = _seg_bar(wboss_wrap, Vector2(vp.x / 2 - 150, vp.y - 72), Vector2(300, 7), MG, MG)

	# ---- radar (bottom-left) ----
	var radar_panel := _round_panel(CY)
	radar_panel.position = Vector2(20, vp.y - 250)
	radar_panel.size = Vector2(118, 118)
	gameplay_hud.add_child(radar_panel)
	minimap = Control.new()
	minimap.set_script(load("res://scripts/Minimap.gd"))
	minimap.main = main
	minimap.size = Vector2(118, 118)
	minimap.position = Vector2(20, vp.y - 250)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(minimap)

	# coords + XP (bottom)
	world_pos_lbl = _lbl("X 0 · Y 0", fv_label, 11, OUTLINE)
	world_pos_lbl.position = Vector2(20, vp.y - 62)
	gameplay_hud.add_child(world_pos_lbl)
	xp_lbl = _lbl("LEVEL 1   0 / 10 XP", fv_label, 11, TXT_DIM)
	xp_lbl.position = Vector2(20, vp.y - 44)
	gameplay_hud.add_child(xp_lbl)
	xp_fill = _seg_bar(gameplay_hud, Vector2(20, vp.y - 24), Vector2(vp.x - 40, 6), GREEN_BR, GREEN)

	# ---- bottom-right controls ----
	boost_btn = _neon_button("BOOST »", CY, 18, Vector2(130, 64))
	boost_btn.position = Vector2(vp.x - 150, vp.y - 120)
	boost_btn.button_down.connect(func(): main.set_boost(true))
	boost_btn.button_up.connect(func(): main.set_boost(false))
	gameplay_hud.add_child(boost_btn)

	swap_btn = _neon_button("⟳", MG, 22, Vector2(56, 56))
	swap_btn.add_theme_font_override("font", f_sym)
	swap_btn.position = Vector2(vp.x - 150 - 64, vp.y - 112)
	swap_btn.pressed.connect(func(): main.cycle_weapon())
	gameplay_hud.add_child(swap_btn)

	# DASH button — above BOOST, so the steering finger never has to let go
	dash_btn = _neon_button("DASH", CY, 16, Vector2(130, 50))
	dash_btn.position = Vector2(vp.x - 150, vp.y - 190)
	dash_btn.pressed.connect(func(): main.trigger_dash())
	gameplay_hud.add_child(dash_btn)

	# floating joystick (under buttons)
	var joy_view := Control.new()
	joy_view.set_script(load("res://scripts/Joystick.gd"))
	joy_view.main = main
	joy_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(joy_view)
	gameplay_hud.move_child(joy_view, 0)

	# ---- toast + wave intro ----
	toast_lbl = _ctr(_glow("", fv_label, 18, CY))
	toast_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_lbl.offset_top = -170; toast_lbl.offset_bottom = -140
	toast_lbl.modulate.a = 0.0
	add_child(toast_lbl)
	wave_intro_lbl = _ctr(_glow("", fv_display, 64, TXT))
	wave_intro_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	wave_intro_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_intro_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_intro_lbl.modulate.a = 0.0
	add_child(wave_intro_lbl)

	# warning banner shown before bosses / elites / guardians spawn
	announce_lbl = _ctr(_glow("", fv_display, 34, MG_SOFT))
	announce_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	announce_lbl.offset_top = _vp().y * 0.28
	announce_lbl.offset_bottom = _vp().y * 0.28 + 96
	announce_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	announce_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	announce_lbl.modulate.a = 0.0
	add_child(announce_lbl)

	_build_start()
	_build_gameover()
	_build_levelup()
	gameplay_hud.visible = false


func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size

func _commas(n: int) -> String:
	var s := str(abs(n)); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return ("-" if n < 0 else "") + out

func _r(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

func _full_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _passthru() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ============================================================
# STYLE PRIMITIVES — glassmorphism panels, neon, segmented bars
# ============================================================
func _sbox(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(0)   # sharp / angular per design
	s.content_margin_left = 12; s.content_margin_right = 12
	s.content_margin_top = 6; s.content_margin_bottom = 6
	return s

# glassmorphism "cyber-panel": dark void tint + thin neon edge
func _panel(accent: Color, a: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sbox(Color(VOID.r, VOID.g, VOID.b, a), Color(accent.r, accent.g, accent.b, 0.4), 1))
	return p

func _round_panel(accent: Color) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(VOID.r, VOID.g, VOID.b, 0.5)
	s.set_corner_radius_all(60)
	s.set_border_width_all(1); s.border_color = Color(accent.r, accent.g, accent.b, 0.3)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _neon_button(text: String, accent: Color, fs: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", fv_label)
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", TXT)
	b.add_theme_color_override("font_pressed_color", TXT)
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_stylebox_override("normal", _sbox(Color(accent.r, accent.g, accent.b, 0.10), accent, 1))
	b.add_theme_stylebox_override("hover", _sbox(Color(accent.r, accent.g, accent.b, 0.22), accent, 1))
	b.add_theme_stylebox_override("pressed", _sbox(Color(accent.r, accent.g, accent.b, 0.38), accent, 2))
	b.add_theme_stylebox_override("disabled", _sbox(Color(accent.r, accent.g, accent.b, 0.04), Color(accent.r, accent.g, accent.b, 0.25), 1))
	b.add_theme_color_override("font_disabled_color", Color(accent.r, accent.g, accent.b, 0.4))
	return b

# 4px tiling notch texture: 2px clear + 2px dark → segmented-bar look
func _make_notch() -> ImageTexture:
	var img := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	img.set_pixel(1, 0, Color(0, 0, 0, 0))
	img.set_pixel(2, 0, Color(0, 0, 0, 0.85))
	img.set_pixel(3, 0, Color(0, 0, 0, 0.85))
	return ImageTexture.create_from_image(img)

# builds a segmented progress bar; returns the fill ColorRect (set fill.size.x)
func _seg_bar(parent: Node, pos: Vector2, size: Vector2, fill_color: Color, border: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.10); bg.position = pos; bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = fill_color; fill.position = pos; fill.size = Vector2(0, size.y)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fill)
	var notch := TextureRect.new()
	notch.texture = _notch
	notch.stretch_mode = TextureRect.STRETCH_TILE
	notch.position = pos; notch.size = size
	notch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(notch)
	var bd := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_border_width_all(1); s.border_color = Color(border.r, border.g, border.b, 0.5)
	s.set_corner_radius_all(0)
	bd.add_theme_stylebox_override("panel", s)
	bd.position = pos; bd.size = size; bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bd)
	fill.set_meta("w", size.x)
	return fill


# ============================================================
# OVERLAYS
# ============================================================
func _overlay(dim: float) -> Array:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := _full_rect(Color(VOID.r, VOID.g, VOID.b, dim))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	o.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	o.add_child(v)
	add_child(o)
	return [o, v]

func _spacer(h: int) -> Control:
	var s := Control.new(); s.custom_minimum_size = Vector2(0, h)
	return s

# ---------------- START ----------------
func _build_start() -> void:
	start_overlay = Control.new()
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := _full_rect(Color(VOID.r, VOID.g, VOID.b, 0.55))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	start_overlay.add_child(bg)
	add_child(start_overlay)

	# BEST badge, top-right
	var best_panel := _panel(CY, 0.5)
	best_panel.position = Vector2(_vp().x - 200, 24)
	var best_row := HBoxContainer.new(); best_row.add_theme_constant_override("separation", 8)
	best_row.add_child(_lbl("BEST", fv_label, 12, OUTLINE))
	start_best_lbl = _lbl("0", fv_num, 20, TXT); best_row.add_child(start_best_lbl)
	best_panel.add_child(best_row)
	start_overlay.add_child(best_panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	start_overlay.add_child(v)

	# two-tone logo
	var logo := HBoxContainer.new(); logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var l1 := _glow("AETHER", fv_display, 56, CY)
	var l2 := _glow("WING", fv_display, 56, MG)
	logo.add_child(l1); logo.add_child(l2)
	v.add_child(logo); logo_pulse = l1

	var underline := ColorRect.new()
	underline.color = AM
	underline.custom_minimum_size = Vector2(280, 3)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(underline)
	v.add_child(_ctr(_lbl("RECURSIVE  ARCADE  SHOOTER", fv_label, 14, TXT_DIM)))

	v.add_child(_spacer(90))

	# daily + weekly chips, side by side
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 12)
	var daily := _chip(AM); mod_icon_lbl = daily.icon; mod_name_lbl = daily.name; mod_desc_lbl = daily.desc
	var weekly := _chip(MG_SOFT); wk_icon_lbl = weekly.icon; wk_name_lbl = weekly.name; wk_desc_lbl = weekly.desc
	chips.add_child(daily.panel); chips.add_child(weekly.panel)
	v.add_child(chips)

	v.add_child(_ctr(_lbl("STEER  ·  TAP DASH  ·  ⟳ SWAP  ·  HOLD » BOOST", fv_label, 11, OUTLINE)))

	v.add_child(_ctr(_lbl("CONTROL", fv_label, 10, OUTLINE)))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 8)
	mode_joystick_btn = _neon_button("JOYSTICK", CY, 14, Vector2(120, 44))
	mode_follow_btn = _neon_button("FOLLOW", CY, 14, Vector2(110, 44))
	mode_direct_btn = _neon_button("DIRECT", CY, 14, Vector2(110, 44))
	for b in [mode_joystick_btn, mode_follow_btn, mode_direct_btn]:
		b.toggle_mode = true
	mode_joystick_btn.pressed.connect(func(): _set_mode("joystick"))
	mode_follow_btn.pressed.connect(func(): _set_mode("follow"))
	mode_direct_btn.pressed.connect(func(): _set_mode("direct"))
	modes.add_child(mode_joystick_btn); modes.add_child(mode_follow_btn); modes.add_child(mode_direct_btn)
	v.add_child(modes)

	var launch := _neon_button("▶  LAUNCH", GREEN, 24, Vector2(640, 62))
	launch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	launch.add_theme_color_override("font_color", GREEN_BR)
	launch.pressed.connect(func(): main.start_game())
	v.add_child(launch)
	v.add_child(_ctr(_lbl("GODOT 4.6 PORT · V1.1", fv_label, 10, OUTLINE)))

func _chip(accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sbox(Color(accent.r, accent.g, accent.b, 0.08), Color(accent.r, accent.g, accent.b, 0.45), 1))
	panel.custom_minimum_size = Vector2(150, 0)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := _lbl("◆", f_sym, 22, accent); icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nm := _lbl("NAME", fv_label, 11, accent)
	var ds := _lbl("desc", fv_body, 10, TXT_DIM)
	col.add_child(nm); col.add_child(ds)
	return {"panel": panel, "icon": icon, "name": nm, "desc": ds}

func _set_mode(m: String) -> void:
	main.control_mode = m
	mode_joystick_btn.button_pressed = (m == "joystick")
	mode_follow_btn.button_pressed = (m == "follow")
	mode_direct_btn.button_pressed = (m == "direct")

# ---------------- GAME OVER ----------------
func _build_gameover() -> void:
	var pair := _overlay(0.9)
	gameover_overlay = pair[0]; gameover_overlay.visible = false
	var v: VBoxContainer = pair[1]
	v.add_child(_ctr(_glow("SYSTEM", fv_display, 56, MG)))
	v.add_child(_ctr(_glow("FAILURE", fv_display, 56, MG)))
	v.add_child(_spacer(10))

	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stats.add_theme_constant_override("separation", 10)
	final_score_lbl = _stat_row(stats, "FINAL SCORE", AM_SOFT)
	final_wave_lbl = _stat_row(stats, "WAVE REACHED", CY_SOFT)
	final_combo_lbl = _stat_row(stats, "MAX COMBO", MG_SOFT)
	best_lbl = _stat_row(stats, "★ BEST SCORE", AM)
	v.add_child(stats)
	v.add_child(_spacer(6))

	var b := _neon_button("RE-ENGAGE", CY, 22, Vector2(640, 56))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): main.restart())
	v.add_child(b)
	v.add_child(_ctr(_lbl("RETURN TO BASE", fv_label, 11, OUTLINE)))

func _stat_row(parent: VBoxContainer, label: String, value_color: Color) -> Label:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(320, 0)
	row.add_theme_constant_override("separation", 16)
	var l := _lbl(label, fv_label, 13, OUTLINE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := _r(_lbl("0", fv_num, 22, value_color))
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l); row.add_child(val)
	parent.add_child(row)
	return val

# ---------------- LEVEL UP ----------------
func _build_levelup() -> void:
	var pair := _overlay(0.85)
	levelup_overlay = pair[0]; levelup_overlay.visible = false
	var v: VBoxContainer = pair[1]
	v.add_child(_ctr(_glow("LEVEL UP", fv_title, 30, CY)))
	v.add_child(_ctr(_lbl("CHOOSE AN UPGRADE", fv_label, 14, TXT_DIM)))
	v.add_child(_spacer(8))
	cards_box = VBoxContainer.new()
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_box.add_theme_constant_override("separation", 14)
	v.add_child(cards_box)

func show_levelup(choices: Array) -> void:
	for c in cards_box.get_children(): c.queue_free()
	for up in choices:
		var rare: bool = up.rarity == "rare"
		var accent: Color = AM if rare else CY
		var card := Button.new()
		card.custom_minimum_size = Vector2(360, 84)
		card.focus_mode = Control.FOCUS_NONE
		card.add_theme_stylebox_override("normal", _card_sbox(accent, 0.06))
		card.add_theme_stylebox_override("hover", _card_sbox(accent, 0.16))
		card.add_theme_stylebox_override("pressed", _card_sbox(accent, 0.24))
		card.pressed.connect(func(): main.choose_upgrade(up))
		cards_box.add_child(card)

		var row := HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.offset_left = 14; row.offset_right = -14; row.offset_top = 10; row.offset_bottom = -10
		card.add_child(row)
		var icon := _glow(up.icon, f_sym, 30, accent)
		icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon.custom_minimum_size = Vector2(44, 0)
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		row.add_child(col)
		var name_row := HBoxContainer.new(); name_row.add_theme_constant_override("separation", 8)
		name_row.add_child(_lbl(up.name, fv_label, 14, accent))
		var stack: int = main.upgrade_stacks.get(up.id, 0)
		var tag := _lbl("NEW" if stack == 0 else "STACK %d" % (stack + 1), fv_label, 9, VOID)
		var tagp := PanelContainer.new()
		tagp.add_theme_stylebox_override("panel", _sbox(GREEN_BR if stack == 0 else accent, GREEN_BR if stack == 0 else accent, 0))
		tagp.add_child(tag)
		name_row.add_child(tagp)
		col.add_child(name_row)
		col.add_child(_lbl(up.desc, fv_body, 11, TXT_DIM))
	levelup_overlay.visible = true

func _card_sbox(accent: Color, a: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent.r, accent.g, accent.b, a)
	s.set_border_width_all(1); s.border_color = accent
	s.border_width_left = 4
	s.set_corner_radius_all(0)
	return s

func hide_levelup() -> void:
	levelup_overlay.visible = false


# ============================================================
# SHOW / HIDE
# ============================================================
func show_start() -> void:
	start_overlay.visible = true
	gameover_overlay.visible = false
	levelup_overlay.visible = false
	gameplay_hud.visible = false
	start_best_lbl.text = _commas(main.high_score)
	_set_mode(main.control_mode)
	mod_icon_lbl.text = Data.DAILY_MODIFIERS[main.current_modifier].icon
	mod_icon_lbl.add_theme_color_override("font_color", main.modifier_color)
	mod_name_lbl.text = main.modifier_name
	mod_name_lbl.add_theme_color_override("font_color", main.modifier_color)
	mod_desc_lbl.text = main.modifier_desc
	wk_icon_lbl.text = Data.WEEKLY_MODIFIERS[main.current_weekly].icon
	wk_icon_lbl.add_theme_color_override("font_color", main.weekly_color)
	wk_name_lbl.text = main.weekly_name
	wk_name_lbl.add_theme_color_override("font_color", main.weekly_color)
	wk_desc_lbl.text = main.weekly_desc

func hide_overlays() -> void:
	start_overlay.visible = false
	gameover_overlay.visible = false
	levelup_overlay.visible = false
	gameplay_hud.visible = true

func show_gameover() -> void:
	final_score_lbl.text = _commas(main.score)
	final_wave_lbl.text = "%d" % main.wave
	final_combo_lbl.text = "x%d" % main.max_combo
	best_lbl.text = _commas(main.high_score)
	gameover_overlay.visible = true
	gameplay_hud.visible = false


# ============================================================
# DYNAMIC UPDATES
# ============================================================
func refresh() -> void:
	if main == null or main.player == null: return
	if not gameplay_hud.visible: return
	score_lbl.text = _commas(main.score)
	combo_lbl.text = "x%d" % main.combo
	var hp_str := ""
	for i in main.player.max_hp:
		hp_str += "♥" if i < main.player.hp else "♡"
	hp_lbl.text = hp_str
	var rw := ""
	for i in main.player.rewind_charges: rw += "↺"
	rewind_lbl.text = rw
	var ep: float = main.player.echo_meter / Data.ECHO.meter_max
	echo_fill.size.x = echo_fill.get_meta("w") * clamp(ep, 0.0, 1.0)
	echo_pct_lbl.text = "ECHO %d%%" % int(ep * 100)
	if main.boss and boss_wrap.visible:
		boss_fill.size.x = boss_fill.get_meta("w") * clamp(main.boss.hp / main.boss.max_hp, 0.0, 1.0)
	if main.world_boss and wboss_wrap.visible:
		wboss_fill.size.x = wboss_fill.get_meta("w") * clamp(main.world_boss.hp / main.world_boss.max_hp, 0.0, 1.0)
	boost_btn.disabled = main.player.echo_meter < Data.BOOST.min_echo_to_start
	dash_btn.disabled = main.player.dash_cooldown > 0.0
	world_pos_lbl.text = "X %d · Y %d" % [round(main.player.position.x), round(main.player.position.y)]
	mod_badge.text = main.modifier_badge
	wk_badge.text = main.weekly_badge
	update_xp()

func update_xp() -> void:
	var pct: float = float(main.xp_current) / max(1, main.xp_to_next)
	xp_fill.size.x = xp_fill.get_meta("w") * clamp(pct, 0.0, 1.0)
	xp_lbl.text = "LEVEL %d   %d / %d XP" % [main.xp_level, main.xp_current, main.xp_to_next]

func update_weapon() -> void:
	var w: Dictionary = Data.WEAPONS[main.player.weapon_idx]
	weapon_lbl.text = w.name
	weapon_lbl.add_theme_color_override("font_color", w.color)
	var slots := slots_box.get_children()
	for i in slots.size():
		slots[i].color = w.color if i == main.player.weapon_idx else Color(1, 1, 1, 0.2)

func show_wave_intro(n: int) -> void:
	wave_lbl.text = "WAVE %d" % n
	wave_intro_lbl.text = "WAVE %d" % n
	var tw := create_tween()
	wave_intro_lbl.modulate.a = 0.0
	tw.tween_property(wave_intro_lbl, "modulate:a", 1.0, 0.3)
	tw.tween_interval(0.8)
	tw.tween_property(wave_intro_lbl, "modulate:a", 0.0, 0.5)

func show_boss_bar(n: String) -> void:
	boss_name_lbl.text = n
	boss_fill.size.x = boss_fill.get_meta("w")
	boss_wrap.visible = true

func hide_boss_bar() -> void:
	boss_wrap.visible = false

func show_world_boss_bar(n: String, col: Color) -> void:
	wboss_name_lbl.text = n
	wboss_name_lbl.add_theme_color_override("font_color", col)
	wboss_fill.color = col
	wboss_fill.size.x = wboss_fill.get_meta("w")
	wboss_wrap.visible = true

func hide_world_boss_bar() -> void:
	wboss_wrap.visible = false

func toast(text: String, _variant := "") -> void:
	toast_lbl.text = text
	var col := CY
	match _variant:
		"gold": col = AM
		"green": col = GREEN_BR
		"warning": col = MG_SOFT
	toast_lbl.add_theme_color_override("font_color", col)
	toast_lbl.add_theme_color_override("font_outline_color", Color(col.r, col.g, col.b, 0.22))
	var tw := create_tween()
	toast_lbl.modulate.a = 1.0
	tw.tween_interval(1.2)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.6)

# Big centered warning banner shown ~1.3s before something new spawns.
func announce(text: String, col: Color) -> void:
	announce_lbl.text = text
	announce_lbl.add_theme_color_override("font_color", col)
	announce_lbl.add_theme_color_override("font_outline_color", Color(col.r, col.g, col.b, 0.25))
	var tw := create_tween()
	announce_lbl.modulate.a = 0.0
	tw.tween_property(announce_lbl, "modulate:a", 1.0, 0.2)
	# two quick pulses to read as an alert
	tw.tween_property(announce_lbl, "modulate:a", 0.55, 0.25)
	tw.tween_property(announce_lbl, "modulate:a", 1.0, 0.25)
	tw.tween_interval(0.35)
	tw.tween_property(announce_lbl, "modulate:a", 0.0, 0.45)

func set_echo_overlay(on: bool) -> void:
	echo_overlay.visible = on

func _flash(rect: ColorRect, peak: float, dur: float) -> void:
	var tw := create_tween()
	rect.color.a = 0.0
	tw.tween_property(rect, "color:a", peak, dur * 0.3)
	tw.tween_property(rect, "color:a", 0.0, dur * 0.7)

func flash_damage() -> void: _flash(damage_flash, 0.4, 0.3)
func flash_rewind() -> void: _flash(rewind_flash, 0.6, 0.7)
func flash_death() -> void: _flash(death_flash, 0.9, 0.6)
