extends CanvasLayer
## HUD + overlays (start / game-over / level-up), built in code.
## Port of the DOM HUD from the prototype.

var main = null

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
var xp_bg: ColorRect
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
var boost_btn: Button

# overlays
var start_overlay: Control
var gameover_overlay: Control
var levelup_overlay: Control
var final_score_lbl: Label
var final_wave_lbl: Label
var final_combo_lbl: Label
var best_lbl: Label
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
var cards_box: HBoxContainer

# flashes
var damage_flash: ColorRect
var rewind_flash: ColorRect
var death_flash: ColorRect
var echo_overlay: ColorRect

func _mk_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 5)
	return l

func _ctr_label(text: String, size: int, color: Color) -> Label:
	var l := _mk_label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func build() -> void:
	var vp := _vp()

	# --- full-screen flashes / tints (always present) ---
	echo_overlay = _full_rect(Color(Data.AMBER.r, Data.AMBER.g, Data.AMBER.b, 0.12))
	echo_overlay.visible = false
	add_child(echo_overlay)
	damage_flash = _full_rect(Color(Data.MAGENTA.r, Data.MAGENTA.g, Data.MAGENTA.b, 0.0))
	add_child(damage_flash)
	rewind_flash = _full_rect(Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.0))
	add_child(rewind_flash)
	death_flash = _full_rect(Color(1, 1, 1, 0.0))
	add_child(death_flash)

	# --- gameplay HUD container ---
	gameplay_hud = Control.new()
	gameplay_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gameplay_hud)

	# top-left: score / combo / hp
	var score_cap := _mk_label("SCORE", 11, Data.CHROME)
	score_cap.position = Vector2(22, 10)
	gameplay_hud.add_child(score_cap)
	score_lbl = _mk_label("0", 34, Data.AMBER)
	score_lbl.position = Vector2(20, 24)
	gameplay_hud.add_child(score_lbl)
	combo_lbl = _mk_label("x1", 22, Data.MAGENTA)
	combo_lbl.position = Vector2(20, 70)
	gameplay_hud.add_child(combo_lbl)
	hp_lbl = _mk_label("", 22, Data.MAGENTA)
	hp_lbl.position = Vector2(20, 104)
	gameplay_hud.add_child(hp_lbl)
	rewind_lbl = _mk_label("", 12, Data.CYAN)
	rewind_lbl.position = Vector2(20, 138)
	gameplay_hud.add_child(rewind_lbl)

	# top-right: wave / weapon / echo
	wave_lbl = _mk_label("WAVE 1", 16, Data.CYAN)
	wave_lbl.position = Vector2(vp.x - 140, 16)
	gameplay_hud.add_child(wave_lbl)
	weapon_lbl = _mk_label("PULSE", 18, Data.CYAN)
	weapon_lbl.position = Vector2(vp.x - 140, 40)
	gameplay_hud.add_child(weapon_lbl)
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 4)
	slots_box.position = Vector2(vp.x - 140, 68)
	gameplay_hud.add_child(slots_box)
	for i in 4:
		var s := ColorRect.new()
		s.custom_minimum_size = Vector2(20, 5)
		s.color = Color(1, 1, 1, 0.2)
		slots_box.add_child(s)
	echo_pct_lbl = _mk_label("ECHO 0%", 11, Data.AMBER)
	echo_pct_lbl.position = Vector2(vp.x - 140, 86)
	gameplay_hud.add_child(echo_pct_lbl)
	var echo_bg := ColorRect.new()
	echo_bg.color = Color(1, 1, 1, 0.12)
	echo_bg.position = Vector2(vp.x - 140, 104)
	echo_bg.size = Vector2(120, 8)
	gameplay_hud.add_child(echo_bg)
	echo_fill = ColorRect.new()
	echo_fill.color = Data.AMBER
	echo_fill.position = Vector2(vp.x - 140, 104)
	echo_fill.size = Vector2(0, 8)
	gameplay_hud.add_child(echo_fill)

	# world mini-boss bar (bottom-center, above XP)
	wboss_wrap = Control.new()
	wboss_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wboss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wboss_wrap.visible = false
	gameplay_hud.add_child(wboss_wrap)
	wboss_name_lbl = _ctr_label("GUARDIAN", 14, Data.MAGENTA)
	wboss_name_lbl.position = Vector2(vp.x / 2 - 160, vp.y - 90)
	wboss_name_lbl.size = Vector2(320, 18)
	wboss_wrap.add_child(wboss_name_lbl)
	var wbg := ColorRect.new()
	wbg.color = Color(1, 1, 1, 0.12)
	wbg.position = Vector2(vp.x / 2 - 150, vp.y - 70)
	wbg.size = Vector2(300, 7)
	wboss_wrap.add_child(wbg)
	wboss_fill = ColorRect.new()
	wboss_fill.color = Data.MAGENTA
	wboss_fill.position = Vector2(vp.x / 2 - 150, vp.y - 70)
	wboss_fill.size = Vector2(300, 7)
	wboss_wrap.add_child(wboss_fill)

	# radar (top-right, below echo)
	var radar_cap := _mk_label("RADAR", 9, Data.CHROME)
	radar_cap.position = Vector2(vp.x - 140, 122)
	gameplay_hud.add_child(radar_cap)
	minimap = Control.new()
	minimap.set_script(load("res://scripts/Minimap.gd"))
	minimap.main = main
	minimap.size = Vector2(118, 118)
	minimap.position = Vector2(vp.x - 140, 136)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(minimap)

	# daily / weekly modifier badges (top-center)
	mod_badge = _ctr_label("", 12, Data.AMBER)
	mod_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mod_badge.offset_top = 12
	mod_badge.offset_bottom = 30
	gameplay_hud.add_child(mod_badge)
	wk_badge = _ctr_label("", 12, Data.PURPLE)
	wk_badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wk_badge.offset_top = 30
	wk_badge.offset_bottom = 48
	gameplay_hud.add_child(wk_badge)

	# world position (bottom-left)
	world_pos_lbl = _mk_label("X 0 · Y 0", 11, Data.CHROME)
	world_pos_lbl.position = Vector2(20, vp.y - 60)
	gameplay_hud.add_child(world_pos_lbl)

	# XP bar (bottom, anchored to bottom edge)
	xp_lbl = _mk_label("LEVEL 1   0 / 10 XP", 11, Data.CHROME)
	xp_lbl.position = Vector2(20, vp.y - 40)
	gameplay_hud.add_child(xp_lbl)
	xp_bg = ColorRect.new()
	xp_bg.color = Color(1, 1, 1, 0.1)
	xp_bg.position = Vector2(20, vp.y - 22)
	xp_bg.size = Vector2(vp.x - 40, 6)
	gameplay_hud.add_child(xp_bg)
	xp_fill = ColorRect.new()
	xp_fill.color = Data.GREEN
	xp_fill.position = Vector2(20, vp.y - 22)
	xp_fill.size = Vector2(0, 6)
	gameplay_hud.add_child(xp_fill)

	# boost button (interactive → on the layer, not the ignore-container)
	boost_btn = Button.new()
	boost_btn.text = "» BOOST"
	boost_btn.add_theme_font_size_override("font_size", 16)
	boost_btn.size = Vector2(120, 60)
	boost_btn.position = Vector2(vp.x - 140, vp.y - 110)
	boost_btn.focus_mode = Control.FOCUS_NONE
	boost_btn.button_down.connect(func(): main.set_boost(true))
	boost_btn.button_up.connect(func(): main.set_boost(false))
	gameplay_hud.add_child(boost_btn)

	# weapon swap button (bottom-left) — needed in joystick mode where swipe-up steers
	swap_btn = _neon_button("⟳ SWAP", Data.MAGENTA, 14, Vector2(96, 46))
	swap_btn.size_flags_horizontal = Control.SIZE_FILL
	swap_btn.position = Vector2(20, vp.y - 118)
	swap_btn.pressed.connect(func(): main.cycle_weapon())
	gameplay_hud.add_child(swap_btn)

	# floating virtual joystick (drawn under the buttons)
	var joy_view := Control.new()
	joy_view.set_script(load("res://scripts/Joystick.gd"))
	joy_view.main = main
	joy_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(joy_view)
	gameplay_hud.move_child(joy_view, 0)

	# boss bar
	boss_wrap = Control.new()
	boss_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_wrap.visible = false
	gameplay_hud.add_child(boss_wrap)
	boss_name_lbl = _ctr_label("BOSS", 16, Data.MAGENTA)
	boss_name_lbl.position = Vector2(vp.x / 2 - 160, 60)
	boss_name_lbl.size = Vector2(320, 20)
	boss_wrap.add_child(boss_name_lbl)
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(1, 1, 1, 0.12)
	boss_bg.position = Vector2(vp.x / 2 - 160, 86)
	boss_bg.size = Vector2(320, 8)
	boss_wrap.add_child(boss_bg)
	boss_fill = ColorRect.new()
	boss_fill.color = Data.MAGENTA
	boss_fill.position = Vector2(vp.x / 2 - 160, 86)
	boss_fill.size = Vector2(320, 8)
	boss_wrap.add_child(boss_fill)

	# toast + wave intro (on layer, centered, span full width)
	toast_lbl = _ctr_label("", 18, Data.CYAN)
	toast_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_lbl.offset_top = -150
	toast_lbl.offset_bottom = -120
	toast_lbl.modulate.a = 0.0
	add_child(toast_lbl)
	wave_intro_lbl = _ctr_label("", 64, Data.CYAN)
	wave_intro_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	wave_intro_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_intro_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_intro_lbl.modulate.a = 0.0
	add_child(wave_intro_lbl)

	_build_start()
	_build_gameover()
	_build_levelup()

	gameplay_hud.visible = false

func _vp() -> Vector2:
	return get_viewport().get_visible_rect().size

func _commas(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return ("-" if n < 0 else "") + out

func _full_rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = c
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# ------------------------------------------------------------
# OVERLAYS — full-rect, vertically-centered VBox
# ------------------------------------------------------------
func _make_overlay(dim: float) -> Array:
	var o := Control.new()
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(Data.NAVY.r, Data.NAVY.g, Data.NAVY.b, dim)
	o.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	o.add_child(v)
	add_child(o)
	return [o, v]

func _big_button(text: String) -> Button:
	return _neon_button(text, Data.CYAN, 22, Vector2(280, 56))

# --- neon UI styling helpers ---
func _sbox(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _neon_button(text: String, accent: Color, fs: int, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", Data.WHITE)
	b.add_theme_color_override("font_pressed_color", Data.WHITE)
	b.add_theme_color_override("font_focus_color", accent)
	b.add_theme_stylebox_override("normal", _sbox(Color(accent.r, accent.g, accent.b, 0.10), Color(accent.r, accent.g, accent.b, 0.55), 2, 10))
	b.add_theme_stylebox_override("hover", _sbox(Color(accent.r, accent.g, accent.b, 0.22), accent, 2, 10))
	b.add_theme_stylebox_override("pressed", _sbox(Color(accent.r, accent.g, accent.b, 0.38), accent, 2, 10))
	b.add_theme_stylebox_override("focus", _sbox(Color(0, 0, 0, 0), Color(accent.r, accent.g, accent.b, 0.0), 0, 10))
	return b

func _make_chip(accent: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _sbox(Color(accent.r, accent.g, accent.b, 0.08), Color(accent.r, accent.g, accent.b, 0.45), 1, 10))
	panel.custom_minimum_size = Vector2(360, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var icon := _mk_label("◆", 26, accent)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	row.add_child(col)
	var nm := _mk_label("NAME", 14, accent)
	var ds := _mk_label("desc", 11, Data.CHROME)
	col.add_child(nm)
	col.add_child(ds)
	return {"panel": panel, "icon": icon, "name": nm, "desc": ds}

func _build_start() -> void:
	start_overlay = Control.new()
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# light dim so the live starfield shows behind the menu
	var bg := _full_rect(Color(Data.NAVY.r, Data.NAVY.g, Data.NAVY.b, 0.55))
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	start_overlay.add_child(bg)
	add_child(start_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)

	# framed neon card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _sbox(Color(0.03, 0.07, 0.13, 0.92), Color(Data.CYAN.r, Data.CYAN.g, Data.CYAN.b, 0.45), 2, 18))
	center.add_child(card)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 34)
	card.add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)

	# two-tone logo
	var logo := HBoxContainer.new()
	logo.alignment = BoxContainer.ALIGNMENT_CENTER
	var l1 := _mk_label("AETHER", 54, Data.CYAN)
	var l2 := _mk_label("WING", 54, Data.MAGENTA)
	logo.add_child(l1); logo.add_child(l2)
	v.add_child(logo)
	logo_pulse = l1

	# amber underline accent
	var underline := ColorRect.new()
	underline.color = Data.AMBER
	underline.custom_minimum_size = Vector2(0, 3)
	underline.size_flags_horizontal = Control.SIZE_FILL
	v.add_child(underline)

	v.add_child(_ctr_label("RECURSIVE ARCADE SHOOTER", 14, Data.CHROME))

	# best score badge
	var best_panel := PanelContainer.new()
	best_panel.add_theme_stylebox_override("panel", _sbox(Color(Data.AMBER.r, Data.AMBER.g, Data.AMBER.b, 0.10), Color(Data.AMBER.r, Data.AMBER.g, Data.AMBER.b, 0.5), 1, 8))
	best_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	best_lbl = _mk_label("BEST  0", 18, Data.AMBER)
	best_panel.add_child(best_lbl)
	v.add_child(best_panel)

	# daily + weekly modifier chips
	var daily_chip := _make_chip(Data.AMBER)
	mod_icon_lbl = daily_chip.icon; mod_name_lbl = daily_chip.name; mod_desc_lbl = daily_chip.desc
	v.add_child(daily_chip.panel)
	var weekly_chip := _make_chip(Data.PURPLE)
	wk_icon_lbl = weekly_chip.icon; wk_name_lbl = weekly_chip.name; wk_desc_lbl = weekly_chip.desc
	v.add_child(weekly_chip.panel)

	v.add_child(_ctr_label("STEER to move   ·   TAP dash   ·   ⟳ swap   ·   HOLD » boost", 11, Data.CHROME))

	v.add_child(_ctr_label("CONTROL", 10, Data.CHROME))
	# control-mode segmented toggle (3 modes)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	modes.add_theme_constant_override("separation", 8)
	mode_joystick_btn = _neon_button("JOYSTICK", Data.CYAN, 14, Vector2(112, 42))
	mode_follow_btn = _neon_button("FOLLOW", Data.CYAN, 14, Vector2(106, 42))
	mode_direct_btn = _neon_button("DIRECT", Data.CYAN, 14, Vector2(106, 42))
	for b in [mode_joystick_btn, mode_follow_btn, mode_direct_btn]:
		b.toggle_mode = true
	mode_joystick_btn.button_pressed = true
	mode_joystick_btn.pressed.connect(func(): _set_mode("joystick"))
	mode_follow_btn.pressed.connect(func(): _set_mode("follow"))
	mode_direct_btn.pressed.connect(func(): _set_mode("direct"))
	modes.add_child(mode_joystick_btn); modes.add_child(mode_follow_btn); modes.add_child(mode_direct_btn)
	v.add_child(modes)

	# launch
	var launch := _neon_button("▶  LAUNCH", Data.GREEN, 24, Vector2(300, 60))
	launch.pressed.connect(func(): main.start_game())
	v.add_child(launch)

	v.add_child(_ctr_label("Godot 4.6 port · v1.1", 10, Data.CHROME))

func _set_mode(m: String) -> void:
	main.control_mode = m
	mode_joystick_btn.button_pressed = (m == "joystick")
	mode_follow_btn.button_pressed = (m == "follow")
	mode_direct_btn.button_pressed = (m == "direct")

func _build_gameover() -> void:
	var pair := _make_overlay(0.88)
	gameover_overlay = pair[0]
	gameover_overlay.visible = false
	var v: VBoxContainer = pair[1]
	v.add_child(_ctr_label("SYSTEM FAILURE", 48, Data.MAGENTA))
	final_score_lbl = _ctr_label("Final Score: 0", 22, Data.AMBER)
	v.add_child(final_score_lbl)
	final_wave_lbl = _ctr_label("Wave Reached: 1", 16, Data.CYAN)
	v.add_child(final_wave_lbl)
	final_combo_lbl = _ctr_label("Max Combo: x1", 16, Data.MAGENTA)
	v.add_child(final_combo_lbl)
	var b := _big_button("RE-ENGAGE")
	b.pressed.connect(func(): main.restart())
	v.add_child(b)

func _build_levelup() -> void:
	var pair := _make_overlay(0.8)
	levelup_overlay = pair[0]
	levelup_overlay.visible = false
	var v: VBoxContainer = pair[1]
	v.add_child(_ctr_label("LEVEL UP — CHOOSE AN UPGRADE", 22, Data.AMBER))
	cards_box = HBoxContainer.new()
	cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_box.add_theme_constant_override("separation", 16)
	v.add_child(cards_box)

func show_levelup(choices: Array) -> void:
	for c in cards_box.get_children(): c.queue_free()
	for up in choices:
		var card := Button.new()
		card.custom_minimum_size = Vector2(170, 210)
		card.focus_mode = Control.FOCUS_NONE
		card.autowrap_mode = TextServer.AUTOWRAP_WORD
		var stack: int = main.upgrade_stacks.get(up.id, 0)
		var stack_txt := ("STACK %d" % (stack + 1)) if stack > 0 else "NEW"
		card.text = "%s\n\n%s\n\n%s\n\n[%s]" % [up.icon, up.name, up.desc, stack_txt]
		card.add_theme_font_size_override("font_size", 14)
		var rare: bool = up.rarity == "rare"
		card.add_theme_color_override("font_color", Data.AMBER if rare else Data.CYAN)
		card.pressed.connect(func(): main.choose_upgrade(up))
		cards_box.add_child(card)
	levelup_overlay.visible = true

func hide_levelup() -> void:
	levelup_overlay.visible = false

func show_start() -> void:
	start_overlay.visible = true
	gameover_overlay.visible = false
	levelup_overlay.visible = false
	gameplay_hud.visible = false
	best_lbl.text = "BEST  %s" % _commas(main.high_score)
	_set_mode(main.control_mode)
	# daily chip
	mod_icon_lbl.text = Data.DAILY_MODIFIERS[main.current_modifier].icon
	mod_icon_lbl.add_theme_color_override("font_color", main.modifier_color)
	mod_name_lbl.text = main.modifier_name
	mod_name_lbl.add_theme_color_override("font_color", main.modifier_color)
	mod_desc_lbl.text = main.modifier_desc
	# weekly chip
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
	final_score_lbl.text = "Final Score: %s" % _commas(main.score)
	final_wave_lbl.text = "Wave Reached: %d" % main.wave
	final_combo_lbl.text = "Max Combo: x%d" % main.max_combo
	best_lbl.text = "BEST  %s" % _commas(main.high_score)
	gameover_overlay.visible = true
	gameplay_hud.visible = false

# ------------------------------------------------------------
# DYNAMIC UPDATES
# ------------------------------------------------------------
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
	rewind_lbl.text = ("REWIND " + rw) if rw != "" else ""
	var ep: float = main.player.echo_meter / Data.ECHO.meter_max
	echo_fill.size.x = 120.0 * clamp(ep, 0.0, 1.0)
	echo_pct_lbl.text = "ECHO %d%%" % int(ep * 100)
	if main.boss and boss_wrap.visible:
		boss_fill.size.x = 320.0 * clamp(main.boss.hp / main.boss.max_hp, 0.0, 1.0)
	if main.world_boss and wboss_wrap.visible:
		wboss_fill.size.x = 300.0 * clamp(main.world_boss.hp / main.world_boss.max_hp, 0.0, 1.0)
	boost_btn.disabled = main.player.echo_meter < Data.BOOST.min_echo_to_start
	world_pos_lbl.text = "X %d · Y %d" % [round(main.player.position.x), round(main.player.position.y)]
	mod_badge.text = main.modifier_badge
	wk_badge.text = main.weekly_badge
	update_xp()

func update_xp() -> void:
	var pct: float = float(main.xp_current) / max(1, main.xp_to_next)
	xp_fill.size.x = (_vp().x - 40.0) * clamp(pct, 0.0, 1.0)
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
	boss_fill.size.x = 320.0
	boss_wrap.visible = true

func hide_boss_bar() -> void:
	boss_wrap.visible = false

func show_world_boss_bar(n: String, col: Color) -> void:
	wboss_name_lbl.text = n
	wboss_name_lbl.add_theme_color_override("font_color", col)
	wboss_fill.color = col
	wboss_fill.size.x = 300.0
	wboss_wrap.visible = true

func hide_world_boss_bar() -> void:
	wboss_wrap.visible = false

func toast(text: String, _variant := "") -> void:
	toast_lbl.text = text
	var col := Data.CYAN
	match _variant:
		"gold": col = Data.GOLD
		"green": col = Data.GREEN
		"warning": col = Data.MAGENTA
	toast_lbl.add_theme_color_override("font_color", col)
	var tw := create_tween()
	toast_lbl.modulate.a = 1.0
	tw.tween_interval(1.2)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.6)

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
