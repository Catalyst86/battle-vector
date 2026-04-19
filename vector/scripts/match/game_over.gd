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
	rematch_btn.pressed.connect(func(): rematch_requested.emit())
	menu_btn.pressed.connect(func(): Router.goto("res://scenes/menus/main_menu.tscn"))

func show_result(result: String, you_squares: int, enemy_squares: int, gold_delta: int = 0, trophy_delta: int = 0, xp_delta: int = 0, levels_gained: int = 0) -> void:
	result_label.text = result
	var color: Color = Palette.BASE_YOU
	if result == "DEFEAT":
		color = Palette.BASE_ENEMY
	elif result == "DRAW":
		color = Palette.TEXT
	result_label.add_theme_color_override("font_color", color)
	score_label.text = "%d VS %d SQUARES" % [you_squares, enemy_squares]
	var gold_txt: String = "+%d" % gold_delta if gold_delta >= 0 else "%d" % gold_delta
	var trophy_txt: String = ("+%d" % trophy_delta) if trophy_delta >= 0 else ("%d" % trophy_delta)
	var xp_suffix: String = ""
	if levels_gained > 0:
		xp_suffix = "  //  LEVEL UP!"
	reward_label.text = "%s GOLD   //   %s 🏆   //   +%d XP%s" % [gold_txt, trophy_txt, xp_delta, xp_suffix]
	visible = true
