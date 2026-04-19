extends Control
## Home screen. Top-level hub: player identity, economy, ladder arena, XP bar,
## tabs for Collection / Deck / Shop, and a mode-picker row.

const CARD_SLOT_SCENE: PackedScene = preload("res://scenes/ui/card_slot.tscn")
const CARD_BUTTON_SCENE: PackedScene = preload("res://scenes/ui/card_button.tscn")
const MATCH_SCENE: String = "res://scenes/match/match.tscn"

@onready var name_label: Label = %PlayerName
@onready var gold_label: Label = %GoldLabel
@onready var trophy_label: Label = %TrophyLabel
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XpBar
@onready var xp_text: Label = %XpText
@onready var collection_grid: GridContainer = %CollectionGrid
@onready var deck_row: HBoxContainer = %DeckRow
@onready var deck_caption: Label = %DeckCaption
@onready var edit_deck_btn: Button = %EditDeckButton
@onready var shop_gold_label: Label = %ShopGoldLabel
@onready var chest_button: Button = %ChestButton
@onready var chest_status: Label = %ChestStatus
@onready var chest_result: Label = %ChestResult
@onready var battle_1v1_btn: Button = %Battle1v1Button
@onready var battle_2v2_btn: Button = %Battle2v2Button
@onready var tutorial_btn: Button = %TutorialButton
@onready var ladder_trophy_label: Label = %LadderTrophyLabel
@onready var ladder_arena_label: Label = %LadderArenaLabel
@onready var ladder_progress_bar: ProgressBar = %LadderProgressBar
@onready var ladder_progress_label: Label = %LadderProgressLabel
@onready var ladder_record_label: Label = %LadderRecordLabel
@onready var ladder_stats_label: Label = %LadderStatsLabel
@onready var arena_list: VBoxContainer = %ArenaList

func _ready() -> void:
	edit_deck_btn.pressed.connect(func(): Router.goto("res://scenes/menus/deck_builder.tscn"))
	battle_1v1_btn.pressed.connect(_on_1v1_pressed)
	battle_2v2_btn.pressed.connect(_on_2v2_pressed)
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	chest_button.pressed.connect(_on_chest_pressed)
	PlayerProfile.changed.connect(_refresh_header)
	PlayerProfile.changed.connect(_refresh_ladder)
	PlayerProfile.changed.connect(_refresh_tutorial_button)
	PlayerProfile.changed.connect(_refresh_chest)
	_build_collection()
	_build_deck_preview()
	_build_arena_list()
	_refresh_header()
	_refresh_ladder()
	_refresh_tutorial_button()
	_refresh_chest()
	# Tick chest countdown once a second.
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_refresh_chest)
	add_child(t)

func _on_1v1_pressed() -> void:
	CurrentMatch.set_mode(load("res://data/game_modes/solo_1v1.tres") as GameMode)
	Router.goto(MATCH_SCENE)

func _on_2v2_pressed() -> void:
	CurrentMatch.set_mode(load("res://data/game_modes/solo_2v2.tres") as GameMode)
	Router.goto(MATCH_SCENE)

func _on_tutorial_pressed() -> void:
	CurrentMatch.set_mode(load("res://data/game_modes/tutorial.tres") as GameMode)
	Router.goto(MATCH_SCENE)

func _refresh_tutorial_button() -> void:
	# After completion the button stays visible as a replay option but dims.
	if PlayerProfile.data.tutorial_completed:
		tutorial_btn.text = "↻ TUTORIAL"
		tutorial_btn.modulate = Color(1, 1, 1, 0.65)
	else:
		tutorial_btn.text = "▸ TUTORIAL"
		tutorial_btn.modulate = Color(1, 1, 1, 1)

func _refresh_chest() -> void:
	if chest_button == null:
		return
	if PlayerProfile.can_claim_free_chest():
		chest_button.text = "▸ CLAIM DAILY CHEST"
		chest_button.disabled = false
		chest_status.text = "READY"
		chest_status.add_theme_color_override("font_color", Color(0.525, 0.937, 0.674, 1.0))
	else:
		var secs: int = PlayerProfile.seconds_until_free_chest()
		var h: int = secs / 3600
		var m: int = (secs % 3600) / 60
		var s: int = secs % 60
		chest_button.text = "NEXT IN %d:%02d:%02d" % [h, m, s]
		chest_button.disabled = true
		chest_status.text = "LOCKED"
		chest_status.add_theme_color_override("font_color", Color(0.898, 0.906, 0.922, 0.4))

func _on_chest_pressed() -> void:
	var rewards: Dictionary = PlayerProfile.claim_free_chest()
	if rewards.get("gold", 0) <= 0:
		return
	var lvl_hint: String = "  //  LEVEL UP!" if rewards.get("levels", 0) > 0 else ""
	chest_result.text = "+%d GOLD  //  +%d XP%s" % [rewards.gold, rewards.xp, lvl_hint]
	chest_result.visible = true
	_refresh_chest()

func _refresh_header() -> void:
	name_label.text = "YOU // %s" % PlayerProfile.data.player_name
	gold_label.text = "⚡ %d GOLD" % PlayerProfile.data.gold
	trophy_label.text = "🏆 %d  //  %s" % [PlayerProfile.data.trophies, PlayerProfile.arena_label()]
	level_label.text = "LEVEL %d" % PlayerProfile.data.player_level
	var needed: int = PlayerProfile.xp_to_next(PlayerProfile.data.player_level)
	if needed < 0:
		xp_bar.max_value = 1.0
		xp_bar.value = 1.0
		xp_text.text = "MAX"
	else:
		xp_bar.max_value = float(needed)
		xp_bar.value = float(PlayerProfile.data.xp)
		xp_text.text = "%d / %d XP" % [PlayerProfile.data.xp, needed]
	shop_gold_label.text = "GOLD: %d" % PlayerProfile.data.gold

func _build_collection() -> void:
	for c in collection_grid.get_children():
		c.queue_free()
	# Show ALL pool cards — locked ones render in their locked state so the
	# player can see what's coming up.
	for card in PlayerDeck.pool():
		var slot := CARD_SLOT_SCENE.instantiate() as CardSlot
		slot.card = card
		collection_grid.add_child(slot)

func _build_deck_preview() -> void:
	for c in deck_row.get_children():
		c.queue_free()
	for card in PlayerDeck.cards:
		var btn := CARD_BUTTON_SCENE.instantiate() as CardButton
		btn.custom_minimum_size = Vector2(40, 58)
		btn.card = card
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_row.add_child(btn)
	deck_caption.text = "CURRENT DECK (%d/8)" % PlayerDeck.cards.size()

func _build_arena_list() -> void:
	for c in arena_list.get_children():
		c.queue_free()
	for i in PlayerProfile.ARENA_THRESHOLDS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := Label.new()
		icon.custom_minimum_size = Vector2(18, 0)
		icon.add_theme_font_size_override("font_size", 11)
		icon.name = "Icon%d" % i
		row.add_child(icon)
		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.text = "%d. %s" % [i + 1, PlayerProfile.ARENA_NAMES[i]]
		name_lbl.name = "Name%d" % i
		row.add_child(name_lbl)
		var thresh := Label.new()
		thresh.add_theme_font_size_override("font_size", 10)
		thresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		thresh.custom_minimum_size = Vector2(56, 0)
		thresh.text = "🏆 %d" % PlayerProfile.ARENA_THRESHOLDS[i]
		thresh.name = "Thresh%d" % i
		row.add_child(thresh)
		arena_list.add_child(row)

func _refresh_ladder() -> void:
	var d := PlayerProfile.data
	ladder_trophy_label.text = "🏆 %d" % d.trophies
	ladder_arena_label.text = PlayerProfile.arena_label()
	var next_t := PlayerProfile.next_arena_threshold()
	if next_t < 0:
		ladder_progress_bar.max_value = 1.0
		ladder_progress_bar.value = 1.0
		ladder_progress_label.text = "TOP ARENA REACHED"
	else:
		var floor_t := PlayerProfile.current_arena_floor()
		var span: float = maxf(1.0, float(next_t - floor_t))
		var progress: float = float(d.trophies - floor_t)
		ladder_progress_bar.max_value = span
		ladder_progress_bar.value = clampf(progress, 0.0, span)
		ladder_progress_label.text = "%d / %d → ARENA %d" % [d.trophies, next_t, PlayerProfile.arena_index() + 2]
	ladder_record_label.text = "RECORD: %d 🏆" % d.best_trophies
	var total: int = PlayerProfile.total_matches()
	if total == 0:
		ladder_stats_label.text = "NO MATCHES PLAYED YET"
	else:
		var pct: int = int(round(PlayerProfile.win_rate() * 100.0))
		ladder_stats_label.text = "W %d  /  L %d  /  D %d  ·  %d%% WIN" % [d.wins, d.losses, d.draws, pct]
	_refresh_arena_list_highlight()

func _refresh_arena_list_highlight() -> void:
	var cur := PlayerProfile.arena_index()
	for i in PlayerProfile.ARENA_THRESHOLDS.size():
		if i >= arena_list.get_child_count():
			break
		var row := arena_list.get_child(i) as HBoxContainer
		if row == null:
			continue
		var icon := row.get_node_or_null("Icon%d" % i) as Label
		var name_lbl := row.get_node_or_null("Name%d" % i) as Label
		var thresh := row.get_node_or_null("Thresh%d" % i) as Label
		if icon == null or name_lbl == null or thresh == null:
			continue
		var state_color: Color
		if i < cur:
			icon.text = "✓"
			state_color = Color(0.525, 0.937, 0.674, 0.9)
		elif i == cur:
			icon.text = "●"
			state_color = Color(0.404, 0.910, 0.976, 1.0)
		else:
			icon.text = "○"
			state_color = Color(0.898, 0.906, 0.922, 0.4)
		icon.add_theme_color_override("font_color", state_color)
		name_lbl.add_theme_color_override("font_color", state_color)
		thresh.add_theme_color_override("font_color", state_color)
