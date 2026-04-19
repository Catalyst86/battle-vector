class_name GameOverOverlay
extends Control
## Fullscreen VICTORY / DEFEAT / DRAW panel. Backdrop absorbs clicks so nothing
## below can be interacted with while this is visible. Emits a signal when the
## player taps Rematch; match.gd handles the actual scene reload.

signal rematch_requested

@onready var result_label: Label = %ResultLabel
@onready var score_label: Label = %ScoreLabel
@onready var reward_label: Label = %RewardLabel
@onready var rematch_btn: Button = %RematchButton
@onready var menu_btn: Button = %MenuButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_tactical_style()
	rematch_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_confirm")
		rematch_requested.emit())
	menu_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_back")
		get_tree().paused = false
		Router.goto("res://scenes/menus/main_menu.tscn"))

func _apply_tactical_style() -> void:
	# Result + body fonts
	result_label.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	result_label.add_theme_font_size_override("font_size", 42)
	score_label.add_theme_font_override("font", Palette.FONT_MONO)
	score_label.add_theme_font_size_override("font_size", 12)
	score_label.add_theme_color_override("font_color", Palette.UI_TEXT_2)
	reward_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	reward_label.add_theme_font_size_override("font_size", 11)
	reward_label.add_theme_color_override("font_color", Palette.UI_AMBER)
	# Caption
	var caption: Label = $Caption
	if caption:
		caption.add_theme_font_override("font", Palette.FONT_DISPLAY)
		caption.add_theme_font_size_override("font_size", 9)
		caption.add_theme_color_override("font_color", Palette.UI_TEXT_3)
	# Buttons
	_style_button(rematch_btn, true)
	_style_button(menu_btn, false)

func _style_button(b: Button, primary: bool) -> void:
	b.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	b.add_theme_font_size_override("font_size", 12)
	var color: Color = Palette.UI_CYAN if primary else Palette.UI_TEXT_1
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.15))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0e2533") if primary else Palette.UI_BG_1
	sb.border_color = Palette.UI_CYAN if primary else Palette.UI_LINE_3
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	if primary:
		sb.shadow_color = Palette.UI_CYAN_GLOW
		sb.shadow_size = 6
	for sn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(sn, sb)

func show_result(result: String, you_squares: int, enemy_squares: int, gold_delta: int = 0, trophy_delta: int = 0, xp_delta: int = 0, levels_gained: int = 0, subtitle_override: String = "") -> void:
	result_label.text = result
	var color: Color = Palette.BASE_YOU
	if result == "DEFEAT":
		color = Palette.BASE_ENEMY
	elif result == "DRAW":
		color = Palette.TEXT
	result_label.add_theme_color_override("font_color", color)
	# Shrink the hero font when the result string is longer than the
	# single-word VICTORY / DEFEAT / DRAW set — otherwise "TUTORIAL COMPLETE"
	# clips the frame.
	result_label.add_theme_font_size_override("font_size", 28 if result.length() > 8 else 42)
	# Explicit subtitle wins over the score-line default. Volley uses it to
	# render "X VS Y KILLS" since the SQUARES wording doesn't match the mode.
	if subtitle_override != "":
		score_label.text = subtitle_override
	# Tutorial runs vs a defenseless dummy; the "X VS Y SQUARES" line is
	# misleading there. Use a training-specific caption instead.
	elif result == "TUTORIAL COMPLETE":
		score_label.text = "TRAINING SECTOR CLEARED"
	else:
		score_label.text = "%d VS %d SQUARES" % [you_squares, enemy_squares]
	var gold_txt: String = "+%d" % gold_delta if gold_delta >= 0 else "%d" % gold_delta
	var trophy_txt: String = ("+%d" % trophy_delta) if trophy_delta >= 0 else ("%d" % trophy_delta)
	var xp_suffix: String = ""
	if levels_gained > 0:
		xp_suffix = "  //  LEVEL UP!"
	reward_label.text = "%s GOLD   //   %s ★   //   +%d XP%s" % [gold_txt, trophy_txt, xp_delta, xp_suffix]
	visible = true
	_animate_reveal()

## Reveal sequence — the backdrop fades in first, then the result label pops
## with a scale/back-ease, then score + reward + buttons cascade. Keeps the
## total window under 700ms so it doesn't delay player input unduly.
func _animate_reveal() -> void:
	var backdrop: ColorRect = $Backdrop
	if backdrop:
		backdrop.modulate = Color(1, 1, 1, 0)
	for n in [result_label, score_label, reward_label, rematch_btn, menu_btn]:
		if n == null: continue
		(n as CanvasItem).modulate = Color(1, 1, 1, 0)
	var caption: Control = $Caption
	if caption: caption.modulate = Color(1, 1, 1, 0)
	result_label.scale = Vector2(0.85, 0.85)
	result_label.pivot_offset = result_label.size * 0.5

	var tw := create_tween().set_parallel(false)
	if backdrop:
		tw.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	if caption:
		tw.tween_property(caption, "modulate:a", 1.0, 0.15)
	# Result pops with BACK ease for a gamey overshoot.
	tw.tween_property(result_label, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(result_label, "scale", Vector2.ONE, 0.32).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Cascade the rest.
	tw.tween_property(score_label, "modulate:a", 1.0, 0.18)
	tw.tween_property(reward_label, "modulate:a", 1.0, 0.18)
	tw.tween_property(rematch_btn, "modulate:a", 1.0, 0.14)
	tw.parallel().tween_property(menu_btn, "modulate:a", 1.0, 0.14)
