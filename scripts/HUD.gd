extends CanvasLayer
## HUD + overlays (start / game-over / level-up), built in code.
## Restyled to the "Neon Survivor System" Stitch design:
##   fonts  = Space Grotesk (headlines) + JetBrains Mono (readouts/labels)
##   look   = glassmorphism cyber-panels, neon borders, segmented bars,
##            chamfer-less sharp geometry, hex/parallelogram pips.

var main = null
const UIS = preload("res://scripts/UIDesignSystem.gd")

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
var boss_phase_lbl: Label
var boss_hp_lbl: Label
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
var pause_btn: Button

# overlays
var start_overlay: Control
var gameover_overlay: Control
var levelup_overlay: Control
var pause_overlay: Control
var codex_overlay: Control
var guide_overlay: Control
var settings_overlay: Control
var final_score_lbl: Label
var final_wave_lbl: Label
var final_combo_lbl: Label
var best_lbl: Label
var final_loadout_lbl: Label
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
var pause_loadout_lbl: Label
var pause_run_lbl: Label
var codex_title_lbl: Label
var _modal_return := "start"

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
	var boss_panel := PanelContainer.new()
	boss_panel.position = Vector2(52, 124)
	boss_panel.size = Vector2(vp.x - 104, 92)
	boss_panel.add_theme_stylebox_override("panel", UIS.panel_style(UIS.DANGER, 0.9, 16))
	boss_wrap.add_child(boss_panel)
	var boss_header := HBoxContainer.new()
	boss_header.position = Vector2(72, 138)
	boss_header.size = Vector2(vp.x - 144, 28)
	boss_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_wrap.add_child(boss_header)
	boss_name_lbl = _lbl("BOSS", fv_title, 20, UIS.TEXT_PRIMARY)
	boss_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_header.add_child(boss_name_lbl)
	boss_hp_lbl = _r(_lbl("100%", fv_num, 18, UIS.DANGER))
	boss_hp_lbl.custom_minimum_size = Vector2(88, 0)
	boss_header.add_child(boss_hp_lbl)
	boss_phase_lbl = _lbl("PHASE 1", fv_label, 12, UIS.TEXT_SECONDARY)
	boss_phase_lbl.position = Vector2(72, 168)
	boss_phase_lbl.size = Vector2(vp.x - 144, 18)
	boss_wrap.add_child(boss_phase_lbl)
	boss_fill = _seg_bar(boss_wrap, Vector2(72, 190), Vector2(vp.x - 144, 14), UIS.DANGER, UIS.DANGER)

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

	# Pause sits above the action controls: reachable, but away from steering.
	pause_btn = _premium_button("Ⅱ", TXT_DIM, 16, Vector2(48, 48))
	pause_btn.position = Vector2(vp.x - 68, 126)
	pause_btn.tooltip_text = "Pause"
	pause_btn.pressed.connect(func(): main.toggle_pause())
	gameplay_hud.add_child(pause_btn)

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
	_build_pause()
	_build_codex()
	_build_guide()
	_build_settings()
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
	b.custom_minimum_size = min_size
	UIS.apply_button(b, fv_label, accent, false)
	b.add_theme_font_size_override("font_size", maxi(fs, UIS.FONT_BODY))
	return b

func _premium_box(accent: Color, alpha := 0.72, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIS.panel_style(accent, alpha, radius))
	return p

func _premium_button(text: String, accent: Color, fs: int, min_size: Vector2, filled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	UIS.apply_button(b, fv_label, accent, filled)
	b.add_theme_font_size_override("font_size", maxi(fs, UIS.FONT_BUTTON))
	return b

# Menu action button: glyph icon · left-aligned label · right chevron, on the
# UIDesignSystem "rail" style. Primary actions are taller, brighter and pulse.
func _menu_action(icon_txt: String, label_txt: String, accent: Color, primary := false) -> Button:
	var w: float = _vp().x - UIS.SCREEN_MARGIN * 2
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2(w, (UIS.TOUCH_PRIMARY + 12) if primary else UIS.TOUCH_PRIMARY)
	UIS.apply_button(b, fv_label, accent, primary)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24; row.offset_right = -22
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var ic := _lbl(icon_txt, f_sym, 26 if primary else 20, accent)
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.custom_minimum_size = Vector2(32, 0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)

	var tx := _lbl(label_txt, fv_label, UIS.FONT_BUTTON_PRIMARY if primary else UIS.FONT_BUTTON, UIS.TEXT_PRIMARY)
	tx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tx)

	var ch := _lbl("›", f_sym, 30 if primary else 24, Color(accent.r, accent.g, accent.b, 0.85))
	ch.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ch)

	if primary:
		# gentle "alive" pulse on the hero action
		var tw := create_tween().set_loops()
		tw.tween_property(b, "modulate", Color(1.08, 1.08, 1.08), 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "modulate", Color(1, 1, 1), 0.9).set_trans(Tween.TRANS_SINE)
	return b

func _scanlines() -> TextureRect:
	var img := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	img.set_pixel(0, 1, Color(0, 0, 0, 0))
	img.set_pixel(0, 2, Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.035))
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _vignette() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256; t.height = 256
	var tr := TextureRect.new()
	tr.texture = t
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

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
	var bg := _full_rect(Color(UIS.SURFACE_0.r, UIS.SURFACE_0.g, UIS.SURFACE_0.b, 0.74))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	start_overlay.add_child(bg)
	start_overlay.add_child(_scanlines())
	start_overlay.add_child(_vignette())
	add_child(start_overlay)

	# Best score remains isolated at top-right.
	var best_panel := _premium_box(UIS.CYAN, 0.82, 16)
	best_panel.position = Vector2(_vp().x - 210, 24)
	best_panel.custom_minimum_size = Vector2(178, 60)
	var best_row := HBoxContainer.new()
	best_row.alignment = BoxContainer.ALIGNMENT_CENTER
	best_row.add_theme_constant_override("separation", UIS.GAP_SMALL)
	best_row.add_child(_lbl("BEST", fv_label, UIS.FONT_BODY, UIS.TEXT_SECONDARY))
	start_best_lbl = _lbl("0", fv_num, UIS.FONT_SCORE, UIS.TEXT_PRIMARY)
	best_row.add_child(start_best_lbl)
	best_panel.add_child(best_row); start_overlay.add_child(best_panel)

	# Brand lockup.
	var logo := HBoxContainer.new()
	logo.position = Vector2(0, 106); logo.size = Vector2(_vp().x, 72)
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var l1 := _glow("AETHER", fv_display, UIS.FONT_TITLE, UIS.CYAN)
	var l2 := _glow("WING", fv_display, UIS.FONT_TITLE, UIS.MAGENTA)
	logo.add_child(l1); logo.add_child(l2)
	start_overlay.add_child(logo); logo_pulse = l1
	# Product hero.
	var hero := Control.new()
	hero.set_script(load("res://scripts/MenuHero.gd"))
	hero.position = Vector2(76, 180); hero.size = Vector2(_vp().x - 152, 330)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_overlay.add_child(hero)

	# Three equal-size actions with generous separation.
	var actions := VBoxContainer.new()
	actions.position = Vector2(UIS.SCREEN_MARGIN, 548)
	actions.size = Vector2(_vp().x - UIS.SCREEN_MARGIN * 2, 244)
	actions.add_theme_constant_override("separation", UIS.GAP_BUTTON)
	start_overlay.add_child(actions)
	var launch := _menu_action("▶", "PLAY", UIS.GREEN, true)
	launch.pressed.connect(func(): main.start_game())
	var tutorial := _menu_action("?", "TUTORIAL", UIS.CYAN)
	tutorial.pressed.connect(func(): show_guide("start"))
	var settings := _menu_action("⚙", "SETTINGS", UIS.MAGENTA)
	settings.pressed.connect(func(): show_settings("start"))
	actions.add_child(launch)
	actions.add_child(tutorial)
	actions.add_child(settings)

	# Studio signature at the bottom-center, light text only.
	var studio := _ctr(_lbl("LTAS", fv_label, UIS.FONT_BODY, UIS.TEXT_SECONDARY))
	studio.position = Vector2(0, _vp().y - 64)
	studio.size = Vector2(_vp().x, 24)
	start_overlay.add_child(studio)

	# decorative frame (corner brackets + accent rails) on top, mouse-ignored
	var frame := Control.new()
	frame.set_script(load("res://scripts/MenuFrame.gd"))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_overlay.add_child(frame)

func _chip(accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sbox(Color(accent.r, accent.g, accent.b, 0.08), Color(accent.r, accent.g, accent.b, 0.45), 1))
	panel.custom_minimum_size = Vector2(150, 54)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	var icon := _lbl("◆", f_sym, 25, accent); icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var nm := _lbl("NAME", fv_label, 13, accent)
	var ds := _lbl("desc", fv_body, 11, TXT_DIM)
	ds.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm); col.add_child(ds)
	return {"panel": panel, "icon": icon, "name": nm, "desc": ds}

func _set_mode(m: String) -> void:
	main.control_mode = m
	if mode_joystick_btn:
		mode_joystick_btn.button_pressed = (m == "joystick")
	if mode_follow_btn:
		mode_follow_btn.button_pressed = (m == "follow")
	if mode_direct_btn:
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
	final_loadout_lbl = _ctr(_lbl("", fv_body, 11, CY_SOFT))
	final_loadout_lbl.custom_minimum_size = Vector2(560, 44)
	final_loadout_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(final_loadout_lbl)
	v.add_child(_spacer(6))

	var b := _neon_button("RE-ENGAGE", CY, 22, Vector2(640, 56))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): main.restart())
	v.add_child(b)
	var base := _neon_button("RETURN TO BASE", OUTLINE, 14, Vector2(260, 46))
	base.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	base.pressed.connect(func(): main.return_to_base())
	v.add_child(base)

# ---------------- PAUSE ----------------
func _build_pause() -> void:
	pause_overlay = Control.new()
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	var bg := _full_rect(Color(VOID.r, VOID.g, VOID.b, 0.78))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(bg)
	add_child(pause_overlay)

	var card := _premium_box(CY, 0.92, 26)
	card.position = Vector2(32, 198)
	card.custom_minimum_size = Vector2(_vp().x - 64, 680)
	pause_overlay.add_child(card)
	var content := VBoxContainer.new(); content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	var status := HBoxContainer.new()
	var left := VBoxContainer.new(); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_lbl("PAUSE", fv_label, 11, OUTLINE))
	left.add_child(_glow("RUN PAUSED", fv_display, 38, CY))
	status.add_child(left)
	var live := _premium_box(GREEN_BR, 0.32, 10)
	var live_lbl := _lbl("●  SAFE", fv_label, 11, GREEN_BR)
	live.add_child(live_lbl); status.add_child(live)
	content.add_child(status)
	var rule := ColorRect.new(); rule.color = Color(CY, 0.22); rule.custom_minimum_size = Vector2(0, 1)
	content.add_child(rule)

	pause_run_lbl = _lbl("WAVE 1 · LEVEL 1 · SCORE 0", fv_num, 18, AM_SOFT)
	content.add_child(pause_run_lbl)
	var loadout_card := _premium_box(CY, 0.46, 16)
	loadout_card.custom_minimum_size = Vector2(0, 120)
	var loadout_col := VBoxContainer.new(); loadout_col.add_theme_constant_override("separation", 7)
	loadout_col.add_child(_lbl("LOADOUT", fv_label, 11, OUTLINE))
	pause_loadout_lbl = _lbl("PULSE LASER 1", fv_body, 14, CY_SOFT)
	pause_loadout_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loadout_col.add_child(pause_loadout_lbl)
	loadout_card.add_child(loadout_col); content.add_child(loadout_card)

	var resume := _premium_button("RESUME FLIGHT   ▶", GREEN_BR, 20, Vector2(0, 64), true)
	resume.pressed.connect(func(): main.toggle_pause())
	content.add_child(resume)
	var tutorial := _premium_button("TUTORIAL", UIS.CYAN, UIS.FONT_BUTTON, Vector2(0, UIS.TOUCH_MIN))
	var settings := _premium_button("SETTINGS", UIS.MAGENTA, UIS.FONT_BUTTON, Vector2(0, UIS.TOUCH_MIN))
	tutorial.pressed.connect(func(): show_guide("pause"))
	settings.pressed.connect(func(): show_settings("pause"))
	content.add_child(tutorial)
	content.add_child(settings)
	content.add_child(_spacer(8))
	var restart := _premium_button("RESTART CURRENT SORTIE", AM, 12, Vector2(0, 48))
	restart.pressed.connect(func(): main.restart())
	content.add_child(restart)
	var base := _premium_button("ABANDON TO BASE", ERR, 12, Vector2(0, 48))
	base.pressed.connect(func(): main.return_to_base())
	content.add_child(base)

# ---------------- CODEX / ARMORY ----------------
func _build_codex() -> void:
	var pair := _overlay(0.96)
	codex_overlay = pair[0]; codex_overlay.visible = false
	var v: VBoxContainer = pair[1]
	codex_title_lbl = _ctr(_glow("ARMORY / CODEX", fv_display, 38, CY))
	v.add_child(codex_title_lbl)
	v.add_child(_ctr(_lbl("WEAPONS EVOLVE AT LV5 WITH THEIR PAIRED PASSIVE", fv_label, 10, OUTLINE)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 830)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var list := VBoxContainer.new()
	list.custom_minimum_size = Vector2(610, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.add_child(_section_header("WEAPON SYSTEMS", CY))
	for id in Data.SURVIVOR_WEAPONS:
		var w: Dictionary = Data.SURVIVOR_WEAPONS[id]
		var passive: Dictionary = Data.PASSIVES[w.passive]
		var evo: Dictionary = Data.EVOLUTIONS[w.evolution]
		list.add_child(_codex_row(w.icon, w.name, "%s · EVO: %s" % [passive.name, evo.name], w.color))
	list.add_child(_section_header("BOSS SIGNALS", MG_SOFT))
	for id in BossCatalog.SUPPORTED:
		var b: Dictionary = BossCatalog.DEFINITIONS[id]
		list.add_child(_codex_row("◆", b.name, "%s · BASE HP %d" % [b.difficulty, int(b.hp)], MG_SOFT))
	v.add_child(scroll)
	var back := _neon_button("BACK", OUTLINE, 14, Vector2(220, 46))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): close_modal())
	v.add_child(back)

func _section_header(text: String, accent: Color) -> Control:
	var row := VBoxContainer.new()
	row.add_child(_lbl(text, fv_title, 17, accent))
	var line := ColorRect.new(); line.color = Color(accent, 0.45)
	line.custom_minimum_size = Vector2(0, 2)
	row.add_child(line)
	return row

func _codex_row(icon_text: String, title: String, desc: String, accent: Color) -> Control:
	var panel := _panel(accent, 0.46)
	panel.custom_minimum_size = Vector2(600, 62)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var icon := _ctr(_lbl(icon_text, f_sym, 24, accent))
	icon.custom_minimum_size = Vector2(40, 0); row.add_child(icon)
	var col := VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_lbl(title, fv_label, 13, TXT))
	var d := _lbl(desc, fv_body, 10, TXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(d); row.add_child(col)
	return panel

# ---------------- PILOT GUIDE ----------------
func _build_guide() -> void:
	var pair := _overlay(0.96)
	guide_overlay = pair[0]; guide_overlay.visible = false
	var v: VBoxContainer = pair[1]
	v.add_child(_ctr(_glow("PILOT GUIDE", fv_display, 40, MG_SOFT)))
	v.add_child(_ctr(_lbl("MOVE WELL. LET THE WEAPONS WORK.", fv_label, 11, OUTLINE)))
	var panel := _panel(MG_SOFT, 0.62)
	panel.custom_minimum_size = Vector2(600, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 12)
	panel.add_child(list)
	list.add_child(_guide_row("STEER", "Drag or use the floating joystick. Weapons auto-target nearby threats.", CY))
	list.add_child(_guide_row("DASH", "Tap or press DASH to cross bullets with brief invulnerability.", CY))
	list.add_child(_guide_row("BOOST", "Hold BOOST to trade Echo energy for escape speed.", AM))
	list.add_child(_guide_row("BUILD", "Collect XP, install up to 4 weapons and 4 passives, then evolve matched pairs.", GREEN_BR))
	list.add_child(_guide_row("FOCUS", "The swap button only changes the HUD focus. All installed weapons fire together.", MG_SOFT))
	list.add_child(_guide_row("LANDMARKS", "Caches, stations, ruins and beacons are world objectives—not enemies.", Data.PURPLE))
	v.add_child(panel)
	v.add_child(_ctr(_lbl("CONTROL MODE", fv_label, 10, OUTLINE)))
	var modes := HBoxContainer.new(); modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 8)
	for mode_data in [["JOYSTICK", "joystick"], ["FOLLOW", "follow"], ["DIRECT", "direct"]]:
		var btn := _neon_button(mode_data[0], CY, 12, Vector2(130, 42))
		var mode_id: String = mode_data[1]
		btn.pressed.connect(func(): _set_mode(mode_id))
		modes.add_child(btn)
	v.add_child(modes)
	var back := _neon_button("BACK", OUTLINE, 14, Vector2(220, 46))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): close_modal())
	v.add_child(back)

func _guide_row(title: String, body: String, accent: Color) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
	var tag := _lbl(title, fv_label, 12, accent); tag.custom_minimum_size = Vector2(105, 0)
	var text := _lbl(body, fv_body, 11, TXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tag); row.add_child(text)
	return row

# ---------------- SETTINGS ----------------
func _build_settings() -> void:
	var pair := _overlay(0.96)
	settings_overlay = pair[0]; settings_overlay.visible = false
	var v: VBoxContainer = pair[1]
	v.add_child(_ctr(_glow("SETTINGS", fv_display, 40, UIS.CYAN)))
	v.add_child(_spacer(12))
	var panel := _premium_box(UIS.CYAN, 0.88, UIS.CORNER_PANEL)
	panel.custom_minimum_size = Vector2(600, 330)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", UIS.GAP_BUTTON)
	panel.add_child(content)
	content.add_child(_lbl("CONTROL MODE", fv_label, UIS.FONT_SECTION, UIS.TEXT_PRIMARY))
	mode_joystick_btn = _premium_button("JOYSTICK", UIS.CYAN, UIS.FONT_BUTTON, Vector2(0, UIS.TOUCH_MIN))
	mode_follow_btn = _premium_button("FOLLOW", UIS.CYAN, UIS.FONT_BUTTON, Vector2(0, UIS.TOUCH_MIN))
	mode_direct_btn = _premium_button("DIRECT", UIS.CYAN, UIS.FONT_BUTTON, Vector2(0, UIS.TOUCH_MIN))
	for button in [mode_joystick_btn, mode_follow_btn, mode_direct_btn]:
		button.toggle_mode = true
	mode_joystick_btn.pressed.connect(func(): _set_mode("joystick"))
	mode_follow_btn.pressed.connect(func(): _set_mode("follow"))
	mode_direct_btn.pressed.connect(func(): _set_mode("direct"))
	content.add_child(mode_joystick_btn)
	content.add_child(mode_follow_btn)
	content.add_child(mode_direct_btn)
	v.add_child(panel)
	v.add_child(_spacer(12))
	var back := _premium_button("BACK", UIS.TEXT_SECONDARY, UIS.FONT_BUTTON, Vector2(600, UIS.TOUCH_MIN))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): close_modal())
	v.add_child(back)

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
		var tag_text := "NEW" if stack == 0 else "STACK %d" % (stack + 1)
		if up.has("kind"):
			match up.kind:
				"weapon_new", "passive_new": tag_text = "INSTALL"
				"weapon_up", "passive_up": tag_text = "UPGRADE"
				"evolve": tag_text = "EVOLUTION"
				"merge": tag_text = "MERGE"
		var tag := _lbl(tag_text, fv_label, 9, VOID)
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
	pause_overlay.visible = false
	codex_overlay.visible = false
	guide_overlay.visible = false
	settings_overlay.visible = false
	gameplay_hud.visible = false
	toast_lbl.visible = true
	wave_intro_lbl.visible = true
	announce_lbl.visible = true
	start_best_lbl.text = _commas(main.high_score)
	_set_mode(main.control_mode)

func _daily_short(id: String) -> String:
	match id:
		"cache": return "DOUBLE CACHE"
		"beacon": return "RADAR 120s"
		"ruins": return "XP x3"
		"station": return "BONUS SHIELD"
		"hunt": return "MORE ELITES"
	return ""

func _weekly_short(id: String) -> String:
	match id:
		"swarm": return "ENEMIES +50%"
		"elite": return "HP +50%  ·  XP +50%"
		"speed": return "ALL SPEED UP"
		"greed": return "SCORE x2  ·  HP -1"
		"explorer": return "MORE LANDMARKS"
	return ""

func hide_overlays() -> void:
	start_overlay.visible = false
	gameover_overlay.visible = false
	levelup_overlay.visible = false
	pause_overlay.visible = false
	codex_overlay.visible = false
	guide_overlay.visible = false
	settings_overlay.visible = false
	gameplay_hud.visible = true
	toast_lbl.visible = true
	wave_intro_lbl.visible = true
	announce_lbl.visible = true

func show_gameover() -> void:
	final_score_lbl.text = _commas(main.score)
	final_wave_lbl.text = "%d" % main.wave
	final_combo_lbl.text = "x%d" % main.max_combo
	best_lbl.text = _commas(main.high_score)
	final_loadout_lbl.text = main.weapon_system.summary() if main.weapon_system else ""
	gameover_overlay.visible = true
	gameplay_hud.visible = false

func show_pause() -> void:
	if main.weapon_system:
		pause_loadout_lbl.text = main.weapon_system.summary()
	pause_run_lbl.text = "WAVE %d  ·  LEVEL %d  ·  SCORE %s" % [main.wave, main.xp_level, _commas(main.score)]
	pause_overlay.visible = true
	gameplay_hud.visible = false
	toast_lbl.visible = false
	wave_intro_lbl.visible = false
	announce_lbl.visible = false

func hide_pause() -> void:
	pause_overlay.visible = false
	gameplay_hud.visible = true
	toast_lbl.visible = true
	wave_intro_lbl.visible = true
	announce_lbl.visible = true

func show_codex(return_to := "start") -> void:
	_modal_return = return_to
	start_overlay.visible = false
	pause_overlay.visible = false
	codex_overlay.visible = true
	guide_overlay.visible = false
	settings_overlay.visible = false
	gameplay_hud.visible = false

func show_guide(return_to := "start") -> void:
	_modal_return = return_to
	start_overlay.visible = false
	pause_overlay.visible = false
	codex_overlay.visible = false
	guide_overlay.visible = true
	settings_overlay.visible = false
	gameplay_hud.visible = false

func show_settings(return_to := "start") -> void:
	_modal_return = return_to
	start_overlay.visible = false
	pause_overlay.visible = false
	codex_overlay.visible = false
	guide_overlay.visible = false
	settings_overlay.visible = true
	gameplay_hud.visible = false
	_set_mode(main.control_mode)

func close_modal() -> void:
	codex_overlay.visible = false
	guide_overlay.visible = false
	settings_overlay.visible = false
	if _modal_return == "pause":
		show_pause()
	else:
		show_start()


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
		var boss_ratio: float = clamp(main.boss.hp / main.boss.max_hp, 0.0, 1.0)
		boss_fill.size.x = boss_fill.get_meta("w") * boss_ratio
		boss_hp_lbl.text = "%d%%" % ceili(boss_ratio * 100.0)
		boss_phase_lbl.text = "PHASE %d" % maxi(1, int(main.boss.phase))
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
	if main.weapon_system == null or main.weapon_system.weapons.is_empty():
		return
	main.player.weapon_idx = clampi(main.player.weapon_idx, 0, main.weapon_system.weapons.size() - 1)
	var entry: Dictionary = main.weapon_system.weapons[main.player.weapon_idx]
	var w: Dictionary = Data.SURVIVOR_WEAPONS[entry.id]
	weapon_lbl.text = main.weapon_system.summary()
	weapon_lbl.add_theme_color_override("font_color", w.color)
	weapon_lbl.add_theme_font_size_override("font_size", 10)
	var slots := slots_box.get_children()
	for i in slots.size():
		if i < main.weapon_system.weapons.size():
			var slot_entry: Dictionary = main.weapon_system.weapons[i]
			var col: Color = Data.SURVIVOR_WEAPONS[slot_entry.id].color
			slots[i].color = col if i == main.player.weapon_idx else Color(col, 0.4)
		else:
			slots[i].color = Color(1, 1, 1, 0.12)

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
	boss_phase_lbl.text = "INCOMING"
	boss_hp_lbl.text = "100%"
	boss_fill.size.x = boss_fill.get_meta("w")
	boss_wrap.visible = true
	pause_btn.position.y = 224

func hide_boss_bar() -> void:
	boss_wrap.visible = false
	pause_btn.position.y = 126

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
