class_name TacticalHeader
extends Control
## Player-identity header for the menu shell. Call sign + trophy + arena on
## the left, settings chip + gold on the right, level diamond + XP bar across
## the bottom. Auto-syncs to PlayerProfile via its `changed` signal.

signal settings_pressed

const LINE_H: float = 1.0

@onready var _callsign: Label = %CallSign
@onready var _id_trophy: Label = %TrophyCount
@onready var _arena_label: Label = %ArenaLabel
@onready var _settings_btn: Button = %SettingsChip
@onready var _gold: Label = %GoldLabel
@onready var _diamond: DiamondLevel = %LevelDiamond
@onready var _xp_label: Label = %XpLabel
@onready var _xp_max_label: Label = %XpMaxLabel
@onready var _xp_bar: PBar = %XpBar

var _displayed_gold: int = -1
var _gold_tween: Tween

func _ready() -> void:
	_settings_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_click")
		settings_pressed.emit())
	if PlayerProfile != null:
		PlayerProfile.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if PlayerProfile == null or PlayerProfile.data == null:
		return
	var d := PlayerProfile.data
	_callsign.text = d.player_name.to_upper().replace(".", "·")
	_id_trophy.text = str(d.trophies)
	_arena_label.text = "ARENA %d — %s" % [PlayerProfile.arena_index() + 1, PlayerProfile.arena_name()]
	_diamond.level = d.player_level
	var needed: int = PlayerProfile.xp_to_next(d.player_level)
	if needed < 0:
		_xp_label.text = str(d.xp)
		_xp_max_label.text = "/MAX"
		_xp_bar.progress = 1.0
	else:
		_xp_label.text = str(d.xp)
		_xp_max_label.text = "/%d XP" % needed
		_xp_bar.progress = clampf(float(d.xp) / float(needed), 0.0, 1.0)
	_animate_gold(d.gold)

func _animate_gold(target: int) -> void:
	if _displayed_gold < 0:
		_displayed_gold = target
		_gold.text = _format_gold(target)
		return
	if _displayed_gold == target:
		return
	var start: int = _displayed_gold
	_displayed_gold = target
	if _gold_tween and _gold_tween.is_valid():
		_gold_tween.kill()
	_gold_tween = create_tween()
	_gold_tween.tween_method(func(v: float):
		_gold.text = _format_gold(int(round(v))),
		float(start), float(target), 0.6)

func _format_gold(n: int) -> String:
	# Tabular-style formatting — no comma separators (mono font keeps it aligned).
	return str(n)
