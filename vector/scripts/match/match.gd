extends Node2D
## Match scene root. Phases: BUILD → MATCH → OVERTIME → OVER.
## Mode-aware: reads `CurrentMatch.mode` at boot. 1v1 spawns one enemy bot;
## 2v2 spawns an ally bot on your side + two enemy bots on theirs. When
## networking lands, the bots are replaced by remote peers.

enum Phase { BUILD, MATCH, OVERTIME, OVER }

@export var deck: Array[CardData] = []
## Seconds between bot spawn attempts during MATCH/OVERTIME.
@export_range(0.5, 10.0, 0.1) var bot_spawn_interval: float = 2.0
@export_range(0.0, 3.0, 0.05) var deploy_cooldown: float = 0.4

@onready var playfield: Node2D = $Playfield
@onready var enemy_base: Node2D = $Playfield/EnemyBase
@onready var player_base: Node2D = $Playfield/PlayerBase
@onready var units_layer: Node2D = $Playfield/UnitsLayer
@onready var preview: Node2D = $Playfield/DeployPreview
@onready var back_btn: Button = %BackButton
@onready var hand: CardHand = %Hand
@onready var mana_bar: ManaBar = %ManaBar
@onready var mana_label: Label = %ManaLabel
@onready var enemy_mana_label: Label = %EnemyManaLabel
@onready var phase_label: Label = %PhaseLabel
@onready var timer_label: Label = %TimerLabel
@onready var hint_label: Label = %HintLabel
@onready var wall_toggle: Button = %WallToggle
@onready var start_btn: Button = %StartMatchButton
@onready var game_over: GameOverOverlay = %GameOver
@onready var coach: TutorialCoach = %TutorialCoach

const UNIT_SCENE: PackedScene = preload("res://scenes/match/unit.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/match/wall.tscn")
const SCOUT_CARD: CardData = preload("res://data/cards/_scout.tres")
const DEFAULT_MODE: String = "res://data/game_modes/solo_1v1.tres"
const MATCH_SCENE_PATH := "res://scenes/match/match.tscn"
## Tutorial deck — a minimal 4-card hand that covers the main attack shapes
## (ranged, ranged-fast, melee AoE, sniper) without overwhelming a new player.
const TUTORIAL_DECK_IDS: Array[StringName] = [&"dart", &"orb", &"bomb", &"lance"]

class BotState:
	var deck_cards: Array[CardData] = []
	var is_enemy: bool = false
	var mana: float = 0.0
	var timer: float = 0.0
	## Last N roles this bot deployed. Used to avoid spamming the same role.
	var recent_roles: Array[int] = []
	## Aggression 0..1 — biases spawn frequency and role preference. Pulled
	## from the arena's bot persona; higher = faster, more offensive.
	var aggression: float = 0.75
	## Roles the persona leans toward — lightly weighted when picking cards.
	var favour_roles: Array = []
	var display_name: String = ""

var phase: Phase = Phase.BUILD
var _mode: GameMode
var _original_config: GameConfigData = null
var _time_left: float = 0.0
var _build_time_left: float = 0.0
var _mana: float = 0.0
var _selected: CardData
var _wall_mode: bool = false
var _player_wall_count: int = 0
var _bots: Array[BotState] = []
var _shake: float = 0.0
var _playfield_base_pos: Vector2 = Vector2.ZERO
# Per-match stat accumulators — flushed to DailyOps on _end_match. Only the
# player's actions count; bot deploys don't tick player quests.
var _stats_roles_played: Dictionary = {}
var _stats_squares_destroyed: int = 0
## True while the tutorial briefing overlay is up — the BUILD countdown
## freezes so the player can read without the match auto-starting under them.
var _briefing_active: bool = false

func _ready() -> void:
	add_to_group("match")
	# Defensive: clear stale state from a prior match. Pause persists across
	# scene loads, so a rematch after VICTORY would start frozen without this.
	get_tree().paused = false
	if UnitRegistry != null:
		UnitRegistry.clear()
	_mode = CurrentMatch.get_mode() if CurrentMatch != null else (load(DEFAULT_MODE) as GameMode)
	# Swap in mode-specific config if present. Restored on exit.
	if _mode != null and _mode.config != null:
		_original_config = GameConfig.data
		GameConfig.data = _mode.config
	# Tutorial overrides your saved deck with a fixed 4-card starter set so
	# the walkthrough always plays out the same way.
	if _mode != null and _mode.is_tutorial:
		deck = _build_tutorial_deck()
	elif PlayerDeck != null and not PlayerDeck.cards.is_empty():
		deck = PlayerDeck.cards
	var cfg := GameConfig.data
	playfield.position = Vector2(0.0, cfg.hud_top_height)
	_playfield_base_pos = playfield.position
	_time_left = float(cfg.match_seconds)
	_build_time_left = float(cfg.build_seconds)
	_mana = float(cfg.mana_start)
	hand.deck = deck
	hand.build()
	hand.set_interactive(false)
	hand.card_selected.connect(_on_card_selected)
	back_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_back")
		_return_to_home())
	game_over.rematch_requested.connect(func(): _return_to_match())
	enemy_base.squares_changed.connect(func(_n): _check_win())
	player_base.squares_changed.connect(func(_n): _check_win())
	wall_toggle.pressed.connect(_on_wall_toggle)
	# START MATCH button is deprecated — match auto-starts when the BUILD
	# countdown hits zero. The button is hidden in _apply_tactical_hud to
	# keep the UI honest; the _start_match callback stays connected as a
	# harmless no-op if something tries to fire it.
	start_btn.pressed.connect(_start_match)
	start_btn.visible = false
	phase_label.text = "SETUP"
	_setup_bots()
	_refresh_ui()
	_update_hint()
	_update_coach()
	_apply_tactical_hud()
	MusicPlayer.play(&"match", 0.8)
	if _mode != null and _mode.is_tutorial:
		_show_tutorial_briefing()

## Pre-tutorial briefing overlay — displayed on match entry for new players.
## Fades in with the callsign header, shows a 3-line ops brief, and dismisses
## on tap or after a short auto-hide. Keeps the player from being dropped into
## controls with no context. Pauses the BUILD countdown while visible so the
## match can't auto-start under the player while they're reading.
func _show_tutorial_briefing() -> void:
	_briefing_active = true
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 60
	var hud: Node = get_node_or_null("HUD")
	if hud:
		hud.add_child(overlay)
	else:
		add_child(overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.016, 0.027, 0.047, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	# Content column
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24; vb.offset_right = -24
	vb.add_theme_constant_override("separation", 14)
	overlay.add_child(vb)
	var kicker := Label.new()
	kicker.text = "▸ OPS BRIEFING"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_override("font", Palette.FONT_DISPLAY)
	kicker.add_theme_font_size_override("font_size", 10)
	kicker.add_theme_color_override("font_color", Palette.UI_TEXT_3)
	vb.add_child(kicker)
	var title := Label.new()
	title.text = "TRAINING\nSECTOR · 01"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Palette.UI_CYAN)
	vb.add_child(title)
	var body := Label.new()
	body.text = ("OBJECTIVE — DESTROY THE HOSTILE BASE (RED SQUARES).\n"
		+ "BUILD — PLACE WALLS TO SLOW INCOMING UNITS.\n"
		+ "MATCH — SPEND MANA TO DEPLOY CARDS ON YOUR SIDE.\n"
		+ "FOLLOW THE HIGHLIGHTED PROMPTS.")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", Palette.FONT_MONO)
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", Palette.UI_TEXT_1)
	vb.add_child(body)
	var hint := Label.new()
	hint.text = "▸ TAP TO CONTINUE"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", Palette.FONT_DISPLAY)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Palette.UI_AMBER)
	vb.add_child(hint)
	# Fade-in, then tap-to-dismiss (or auto-dismiss after 5s).
	overlay.modulate = Color(1, 1, 1, 0)
	var fade_in := create_tween()
	fade_in.tween_property(overlay, "modulate:a", 1.0, 0.3)
	var dismiss := func():
		if not is_instance_valid(overlay) or overlay.is_queued_for_deletion():
			return
		_briefing_active = false
		var fade_out := create_tween()
		fade_out.tween_property(overlay, "modulate:a", 0.0, 0.2)
		fade_out.finished.connect(func(): overlay.queue_free())
	overlay.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			SfxBank.play_ui(&"ui_click")
			dismiss.call())
	# Auto-dismiss fallback — don't strand the player on the briefing.
	var auto_timer := get_tree().create_timer(6.0)
	auto_timer.timeout.connect(dismiss)

## Re-skins the existing HUD nodes with the tactical theme — fonts, colors,
## and button styleboxes. Done in code rather than .tscn edits so we don't
## disturb the scene's anchors / unique-name wiring.
func _apply_tactical_hud() -> void:
	# Top HUD ── phase label becomes a bordered cyan pill.
	phase_label.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	phase_label.add_theme_font_size_override("font_size", 11)
	phase_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	timer_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", Palette.UI_AMBER)
	enemy_mana_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	enemy_mana_label.add_theme_color_override("font_color", Palette.UI_RED)
	var enemy_lbl: Label = $HUD/TopHUD/EnemyLabel
	if enemy_lbl:
		enemy_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY)
		enemy_lbl.add_theme_color_override("font_color", Palette.UI_RED)
		# Name after the enemy persona. Tutorial mode has no bots, so we
		# label the training dummy explicitly instead of leaving the tscn
		# default "K.VOID_07" hardcoded placeholder visible.
		if _mode != null and _mode.is_tutorial:
			enemy_lbl.text = "TARGET // TRAINING DUMMY"
		else:
			for b in _bots:
				if b.is_enemy and b.display_name != "":
					enemy_lbl.text = "ENEMY // %s" % b.display_name
					break
	# Bottom HUD ── identity / mana line
	var player_lbl: Label = $HUD/BottomHUD/PlayerRow/PlayerLabel
	if player_lbl:
		player_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY)
		player_lbl.add_theme_color_override("font_color", Palette.UI_CYAN)
	mana_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	mana_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	# Mana pips — swap gold for cyan to match the tactical "friendly" palette.
	if mana_bar is ManaBar:
		(mana_bar as ManaBar).pip_color = Palette.UI_CYAN
		(mana_bar as ManaBar).dim_color = Palette.UI_LINE_2
		mana_bar.queue_redraw()
	hint_label.add_theme_font_override("font", Palette.FONT_MONO)
	hint_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	# Buttons
	_style_hud_button(wall_toggle, Palette.UI_TEXT_0)
	_style_hud_button(back_btn, Palette.UI_TEXT_1)
	_style_hud_button(start_btn, Palette.UI_CYAN)

func _style_hud_button(b: Button, text_color: Color) -> void:
	if b == null:
		return
	b.add_theme_font_override("font", Palette.FONT_DISPLAY)
	b.add_theme_font_size_override("font_size", 10)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color.lightened(0.2))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.UI_BG_1
	sb.border_color = Palette.UI_LINE_3 if text_color != Palette.UI_CYAN else Palette.UI_CYAN
	sb.border_width_top = 1; sb.border_width_bottom = 1
	sb.border_width_left = 1; sb.border_width_right = 1
	if text_color == Palette.UI_CYAN:
		sb.shadow_color = Palette.UI_CYAN_GLOW
		sb.shadow_size = 4
	for sn in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(sn, sb)

func _exit_tree() -> void:
	if _original_config != null:
		GameConfig.data = _original_config

func _return_to_home() -> void:
	if _original_config != null:
		GameConfig.data = _original_config
		_original_config = null
	get_tree().paused = false
	Router.goto("res://scenes/menus/main_menu.tscn")

func _return_to_match() -> void:
	if _original_config != null:
		GameConfig.data = _original_config
		_original_config = null
	get_tree().paused = false
	Router.goto(MATCH_SCENE_PATH)

func _setup_bots() -> void:
	_bots.clear()
	if _mode == null:
		return
	# Tutorial has no bots — just the player vs a defenseless enemy base.
	if _mode.is_tutorial:
		return
	# Arena-themed personas drive bot decks. The player's current arena picks
	# the enemy flavour; ally bots in 2v2 share the same persona for cohesion.
	var arena_idx: int = PlayerProfile.arena_index() if PlayerProfile != null else 0
	var enemy_persona: Dictionary = {}
	var ally_persona: Dictionary = {}
	if BotPersonas != null:
		enemy_persona = BotPersonas.for_arena(arena_idx)
		# Ally bots pull from the player's arena too — same flavour, distinct
		# persona slot. A second personality table per side could land later.
		ally_persona = BotPersonas.for_arena(maxi(0, arena_idx - 1))
	if _mode.team_size == 1:
		_bots.append(_make_bot_from_persona(true, enemy_persona))
	elif _mode.team_size >= 2:
		_bots.append(_make_bot_from_persona(false, ally_persona))
		_bots.append(_make_bot_from_persona(true, enemy_persona))
		_bots.append(_make_bot_from_persona(true, enemy_persona))

func _build_tutorial_deck() -> Array[CardData]:
	var result: Array[CardData] = []
	for id in TUTORIAL_DECK_IDS:
		var c := load("res://data/cards/%s.tres" % id) as CardData
		if c != null:
			result.append(c)
	return result

func _random_subset(source: Array[CardData], n: int) -> Array[CardData]:
	if source.size() <= n:
		return source.duplicate()
	var shuffled: Array[CardData] = source.duplicate()
	shuffled.shuffle()
	return shuffled.slice(0, n)

func _make_bot(enemy: bool, bot_deck: Array[CardData]) -> BotState:
	var b := BotState.new()
	b.deck_cards = bot_deck.duplicate()
	b.is_enemy = enemy
	b.mana = float(GameConfig.data.mana_start)
	b.timer = 0.0
	return b

## Builds a bot from a persona dictionary. Defensive against missing fields
## so a partial persona (or empty dict on low arenas) still spawns a valid
## bot — falls back to the player's current deck in that case.
func _make_bot_from_persona(enemy: bool, persona: Dictionary) -> BotState:
	var b := BotState.new()
	var cards: Array[CardData] = []
	if BotPersonas != null and not persona.is_empty():
		cards = BotPersonas.deck_for(persona)
	if cards.size() < 4:
		# Fallback — use the player's deck so matches can't brick at low arenas.
		cards = deck if not deck.is_empty() else _random_subset(
			PlayerProfile.unlocked_cards() if PlayerProfile != null else deck, 8)
	b.deck_cards = cards
	b.is_enemy = enemy
	b.mana = float(GameConfig.data.mana_start)
	b.timer = 0.0
	b.aggression = float(persona.get("aggression", 0.75))
	b.favour_roles = persona.get("favour_roles", [])
	b.display_name = String(persona.get("name", "BOT"))
	return b

func _process(delta: float) -> void:
	_update_shake(delta)
	if phase == Phase.OVER:
		return
	if phase == Phase.BUILD:
		# Freeze the BUILD countdown while the tutorial briefing overlay is
		# visible so the player can read without the match starting under
		# them. Plain matches never set _briefing_active so this is a no-op.
		if not _briefing_active:
			_build_time_left -= delta
			if _build_time_left <= 0.0:
				_start_match()
		_refresh_ui()
		return
	var cfg := GameConfig.data
	_mana = minf(_mana + cfg.mana_regen_per_sec * delta, float(cfg.mana_max))
	for b in _bots:
		# Aggressive personas regenerate + act faster. Multiplier range 0.7–1.3.
		var aggro_mult: float = 0.7 + 0.6 * clampf(b.aggression, 0.0, 1.0)
		b.mana = minf(b.mana + cfg.mana_regen_per_sec * delta * aggro_mult, float(cfg.mana_max))
		b.timer += delta
		if b.timer >= bot_spawn_interval / aggro_mult:
			b.timer = 0.0
			_bot_try_spawn(b)
	_time_left -= delta
	if _time_left <= 0.0:
		_advance_phase()
	_refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.OVER:
		return
	if event is InputEventMouseMotion:
		_update_preview((event as InputEventMouseMotion).position)
		return
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if not (m.pressed and m.button_index == MOUSE_BUTTON_LEFT):
		return
	if phase == Phase.BUILD:
		if _wall_mode:
			_try_place_wall(m.position)
		return
	if _selected != null:
		_try_deploy(m.position)

# --- BUILD phase ------------------------------------------------------------

func _on_wall_toggle() -> void:
	if phase != Phase.BUILD:
		return
	if _player_wall_count >= GameConfig.data.max_walls_per_player and not _wall_mode:
		return
	_wall_mode = not _wall_mode
	if _wall_mode:
		hand.deselect()
		_selected = null
		preview.hide_preview()
	_refresh_build_ui()
	_update_hint()
	_update_coach()

func _try_place_wall(screen: Vector2) -> void:
	var cfg := GameConfig.data
	if _player_wall_count >= cfg.max_walls_per_player:
		return
	var local := screen - playfield.global_position
	if local.y < 0.0 or local.y > cfg.map_height + cfg.far_y_lift:
		return
	var world := Pseudo3D.unproject(local)
	var min_y: float = cfg.midline_y + cfg.wall_height * 0.5 + 4.0
	var max_y: float = cfg.map_height - cfg.base_strip_height - cfg.wall_height * 0.5 - 4.0
	if world.y < min_y or world.y > max_y:
		return
	var clamp_x: float = clampf(world.x, cfg.wall_width * 0.5, cfg.map_width - cfg.wall_width * 0.5)
	_spawn_wall(Vector2(clamp_x, world.y), 0)
	SfxBank.play(&"wall_place")
	_player_wall_count += 1
	if _player_wall_count >= cfg.max_walls_per_player:
		_wall_mode = false
	_refresh_build_ui()
	_update_hint()
	_update_coach()

func _start_match() -> void:
	if phase != Phase.BUILD:
		return
	SfxBank.play(&"match_start")
	PlayerProfile.buzz(45)
	phase = Phase.MATCH
	_wall_mode = false
	# Every bot gets its own 3-wall allotment auto-placed on the correct side.
	for b in _bots:
		_auto_place_walls(1 if b.is_enemy else 0, 3)
	wall_toggle.visible = false
	start_btn.visible = false
	hand.set_interactive(true)
	phase_label.text = "MATCH"
	_refresh_ui()
	_update_hint()
	_update_coach()
	_show_match_start_countdown()

## Drops a full-screen "3 · 2 · 1 · GO" overlay after BUILD ends — gives the
## player a beat to orient before bot units start pouring in.
func _show_match_start_countdown() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 50
	# Find a CanvasLayer to parent into so the overlay sits above the playfield.
	var hud: Node = get_node_or_null("HUD")
	if hud:
		hud.add_child(overlay)
	else:
		add_child(overlay)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_left = -120; lbl.offset_right = 120
	lbl.offset_top = -80; lbl.offset_bottom = 80
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	lbl.add_theme_font_size_override("font_size", 72)
	lbl.add_theme_color_override("font_color", Palette.UI_CYAN)
	overlay.add_child(lbl)
	# Sequence: 3 → 2 → 1 → GO. Each beat scales up + fades through.
	var beats: Array = ["3", "2", "1", "GO"]
	var tween := create_tween()
	for i in beats.size():
		var text: String = beats[i]
		var color: Color = Palette.UI_AMBER if i == beats.size() - 1 else Palette.UI_CYAN
		tween.tween_callback(func():
			lbl.text = text
			lbl.add_theme_color_override("font_color", color)
			lbl.modulate = Color(1, 1, 1, 1)
			lbl.scale = Vector2.ONE * 0.7)
		tween.tween_property(lbl, "scale", Vector2.ONE, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(lbl, "modulate:a", 0.0, 0.35).set_delay(0.2)
	tween.tween_callback(func(): overlay.queue_free())

func _auto_place_walls(side: int, count: int) -> void:
	var cfg := GameConfig.data
	var min_y: float
	var max_y: float
	if side == 1:
		min_y = cfg.base_strip_height + cfg.wall_height * 0.5 + 4.0
		max_y = cfg.midline_y - cfg.wall_height * 0.5 - 4.0
	else:
		min_y = cfg.midline_y + cfg.wall_height * 0.5 + 4.0
		max_y = cfg.map_height - cfg.base_strip_height - cfg.wall_height * 0.5 - 4.0
	var slot_h: float = (max_y - min_y) / maxf(float(count), 1.0)
	for i in range(count):
		var y: float = min_y + slot_h * (i + 0.5) + randf_range(-slot_h * 0.25, slot_h * 0.25)
		var x: float = randf_range(cfg.wall_width * 0.5, cfg.map_width - cfg.wall_width * 0.5)
		_spawn_wall(Vector2(x, y), side)

func _spawn_wall(at: Vector2, wall_side: int) -> void:
	var w := WALL_SCENE.instantiate() as Wall
	w.side = wall_side
	playfield.add_child(w)
	w.world_pos = at

# --- MATCH phase ------------------------------------------------------------

func _try_deploy(screen: Vector2) -> void:
	var cfg := GameConfig.data
	var local := screen - playfield.global_position
	if local.y < 0.0 or local.y > cfg.map_height + cfg.far_y_lift:
		return
	var world := Pseudo3D.unproject(local)
	if world.y < cfg.midline_y:
		return
	if _selected == null:
		return
	if _selected.cost > int(_mana):
		return
	_mana -= float(_selected.cost)
	var deployed := _selected
	SfxBank.play_event(deployed, &"deploy")
	PlayerProfile.buzz(25)
	_spawn_unit(deployed, world, false)
	# Daily-ops tracking — player deploys only.
	if DailyOps != null:
		DailyOps.track(&"deploy_units", 1)
		if deployed.role == CardData.Role.SWARM:
			DailyOps.track(&"deploy_swarm", 1)
		elif deployed.role == CardData.Role.SNIPER:
			DailyOps.track(&"deploy_snipe", 1)
	_stats_roles_played[deployed.role] = true
	_refresh_ui()
	hand.deselect()
	hand.trigger_cooldown(deployed, deploy_cooldown)
	_selected = null
	preview.hide_preview()
	_update_hint()
	_update_coach()

func _spawn_unit(c: CardData, at_world: Vector2, enemy: bool) -> void:
	if c.role == CardData.Role.SWARM:
		if c.swarm_count <= 0:
			push_warning("Card '%s' is SWARM but swarm_count=%d — spawning 1 scout as a fallback." % [c.id, c.swarm_count])
		var n: int = maxi(1, c.swarm_count)
		for i in range(n):
			var offset := Vector2(randf_range(-18.0, 18.0), randf_range(-8.0, 8.0))
			_spawn_single(SCOUT_CARD, at_world + offset, enemy)
		return
	_spawn_single(c, at_world, enemy)

func _spawn_single(c: CardData, at_world: Vector2, enemy: bool) -> void:
	var u := UNIT_SCENE.instantiate()
	u.card = c
	u.is_enemy = enemy
	units_layer.add_child(u)
	u.spawn_at(at_world)

func _on_unit_reached_base(side: int, world_pos: Vector2, damage: float) -> void:
	var hits: int = maxi(1, roundi(damage / 18.0))
	var target: Node2D = enemy_base if side == 1 else player_base
	target.damage_at(world_pos, hits)
	shake(3.0 + float(hits) * 0.5)
	SfxBank.play(&"base_damage")
	# side == 1 means the enemy base took damage (player unit scored).
	if side == 1:
		_stats_squares_destroyed += hits
		if DailyOps != null:
			DailyOps.track(&"destroy_squares", hits)
	else:
		# side == 0 = our own base — nudge the player's phone so they feel
		# the hit even if they're looking elsewhere on screen. Vignette
		# pulse + small hit-pause sell the "taking fire" beat.
		PlayerProfile.buzz(55)
		pulse_vignette(0.45 + 0.05 * float(hits))
		hit_pause(0.04)
	_check_win()
	_update_coach()

## Public: trigger a screen shake. Called by units on death / melee detonation
## via `get_tree().call_group("match", "shake", amount)`. No-ops when the
## player has disabled screen shake in settings.
func shake(amount: float) -> void:
	if PlayerProfile != null and PlayerProfile.data != null and not PlayerProfile.data.screen_shake_enabled:
		return
	_shake = maxf(_shake, amount)

## Public: brief engine-wide hit-pause on significant events (kills with
## shockwave, base hits, game-over beats). Scales time down to near-zero for
## `seconds`, then restores — reads as a freeze-frame punctuating the hit.
## Uses the ignore_time_scale timer param so the restore fires on wall-clock
## time rather than stalling forever inside the pause itself.
var _hit_pause_active: bool = false
func hit_pause(seconds: float) -> void:
	if seconds <= 0.0 or _hit_pause_active:
		return
	if PlayerProfile != null and PlayerProfile.data != null and not PlayerProfile.data.screen_shake_enabled:
		return  # same toggle as shake — players who disable motion get no freeze either
	_hit_pause_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_pause_active = false

## Public: pulse the vignette briefly when the player's base takes damage.
## Ramps intensity up + tints red, then decays back. Gated to player-side
## hits only so the enemy base taking damage (a win moment) doesn't punish
## the player's screen.
func pulse_vignette(strength: float = 0.55) -> void:
	var vig: ColorRect = $Vignette/VignetteRect if has_node("Vignette/VignetteRect") else null
	if vig == null or vig.material == null:
		return
	var mat: ShaderMaterial = vig.material as ShaderMaterial
	if mat == null:
		return
	var base_intensity: float = 0.42
	var base_tint: Color = Color(0, 0, 0, 1)
	mat.set_shader_parameter("intensity", base_intensity + strength)
	mat.set_shader_parameter("tint", Color(0.85, 0.2, 0.25, 1))
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float):
		mat.set_shader_parameter("intensity", v),
		base_intensity + strength, base_intensity, 0.45).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(c: Color):
		mat.set_shader_parameter("tint", c),
		Color(0.85, 0.2, 0.25, 1), base_tint, 0.45).set_trans(Tween.TRANS_QUAD)

func _update_shake(delta: float) -> void:
	if _shake > 0.05:
		_shake = maxf(0.0, _shake - delta * 30.0)
		var off := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		playfield.position = _playfield_base_pos + off
	elif playfield.position != _playfield_base_pos:
		playfield.position = _playfield_base_pos

# --- Win / phase transition -------------------------------------------------

func _check_win() -> void:
	if phase == Phase.OVER or phase == Phase.BUILD:
		return
	if enemy_base.count_alive() <= 0:
		_end_match("VICTORY")
	elif player_base.count_alive() <= 0:
		_end_match("DEFEAT")

func _advance_phase() -> void:
	var cfg := GameConfig.data
	if phase == Phase.MATCH:
		phase = Phase.OVERTIME
		_time_left = float(cfg.overtime_seconds)
		phase_label.text = "OVERTIME"
		timer_label.add_theme_color_override("font_color", Palette.WALL_ENEMY)
	elif phase == Phase.OVERTIME:
		var you: int = player_base.count_alive()
		var them: int = enemy_base.count_alive()
		if you > them:
			_end_match("VICTORY")
		elif you < them:
			_end_match("DEFEAT")
		else:
			_end_match("DRAW")

func _end_match(result: String) -> void:
	if phase == Phase.OVER:
		return
	# Capture the phase we were in BEFORE flipping to OVER so the
	# overtime-win quest can see it.
	var ending_phase: Phase = phase
	phase = Phase.OVER
	preview.hide_preview()
	_selected = null
	# Victory-only quest flushes.
	if result == "VICTORY" and DailyOps != null:
		if _stats_roles_played.size() >= 5:
			DailyOps.track(&"play_roles", _stats_roles_played.size())
		if _player_wall_count == 0:
			DailyOps.track(&"no_walls", 1)
		if ending_phase == Phase.OVERTIME:
			DailyOps.track(&"overtime_win", 1)
		if _mode != null and _mode.is_tutorial:
			DailyOps.track(&"tutorial_replay", 1)
	var rewards: Dictionary = {"gold": 0, "trophies": 0, "xp": 0, "levels": 0}
	if _mode != null and _mode.is_tutorial:
		# Tutorial grants a one-time completion reward and doesn't touch the
		# ladder/W-L-D counters. Losses/draws give nothing.
		if result == "VICTORY" and PlayerProfile != null:
			rewards = PlayerProfile.complete_tutorial()
	elif PlayerProfile != null:
		rewards = PlayerProfile.award_match_result(result)
	match result:
		"VICTORY": SfxBank.play(&"victory")
		"DEFEAT": SfxBank.play(&"defeat")
		"DRAW": SfxBank.play(&"draw")
	# Longer buzz on the definitive moment. Defeat gets a slightly harsher
	# double-pulse via a second buzz shortly after.
	PlayerProfile.buzz(90)
	if result == "DEFEAT":
		get_tree().create_timer(0.18).timeout.connect(func(): PlayerProfile.buzz(60))
	# Tutorial wins are guaranteed — calling them "VICTORY" feels cheap.
	# Swap the display string to something honest; reward logic above
	# already uses the original "VICTORY" so nothing else changes.
	var display_result: String = result
	if _mode != null and _mode.is_tutorial and result == "VICTORY":
		display_result = "TUTORIAL COMPLETE"
	game_over.show_result(
		display_result,
		player_base.count_alive(),
		enemy_base.count_alive(),
		rewards.get("gold", 0),
		rewards.get("trophies", 0),
		rewards.get("xp", 0),
		rewards.get("levels", 0),
	)
	# Freeze the playfield behind the overlay. Units, projectiles, walls and
	# bots all inherit the default pausable process mode; the overlay itself
	# is PROCESS_MODE_ALWAYS (see GameOverOverlay._ready) so its buttons work.
	get_tree().paused = true

# --- Bot --------------------------------------------------------------------

func _bot_try_spawn(b: BotState) -> void:
	if b.deck_cards.is_empty() or phase == Phase.OVER or phase == Phase.BUILD:
		return
	var cfg := GameConfig.data
	var affordable: Array[CardData] = []
	for c in b.deck_cards:
		if c != null and c.cost <= int(b.mana):
			affordable.append(c)
	if affordable.is_empty():
		return
	# Prefer cards whose role isn't in recent history, AND lean toward the
	# persona's favoured roles. Fresh-role set filters by "haven't used in
	# the last 3"; favoured set further prefers cards the persona leans
	# toward. Falls back to the lower-priority sets when they come up empty.
	var fresh: Array[CardData] = []
	for c in affordable:
		if not b.recent_roles.has(c.role):
			fresh.append(c)
	var candidates: Array[CardData] = fresh if not fresh.is_empty() else affordable
	if not b.favour_roles.is_empty():
		var favoured: Array[CardData] = []
		for c in candidates:
			if b.favour_roles.has(c.role):
				favoured.append(c)
		if not favoured.is_empty():
			candidates = favoured
	var pick: CardData = candidates.pick_random()
	b.recent_roles.append(pick.role)
	while b.recent_roles.size() > 3:
		b.recent_roles.pop_front()
	var x: float = randf_range(40.0, cfg.map_width - 40.0)
	var y: float
	if b.is_enemy:
		y = randf_range(80.0, cfg.midline_y - 30.0)
	else:
		# Ally bot spawns anywhere on the player team's half.
		y = randf_range(cfg.midline_y + 30.0, cfg.map_height - 80.0)
	b.mana -= float(pick.cost)
	_spawn_unit(pick, Vector2(x, y), b.is_enemy)

# --- Card / preview UX -------------------------------------------------------

func _on_card_selected(card: CardData) -> void:
	if phase == Phase.BUILD:
		return
	_selected = card
	if card == null:
		preview.hide_preview()
	else:
		_wall_mode = false
		_refresh_build_ui()
		_update_preview(get_viewport().get_mouse_position())
	_update_hint()
	_update_coach()

func _update_preview(screen: Vector2) -> void:
	if phase != Phase.MATCH and phase != Phase.OVERTIME:
		preview.hide_preview()
		return
	if _selected == null:
		preview.hide_preview()
		return
	var cfg := GameConfig.data
	var local := screen - playfield.global_position
	if local.y < 0.0 or local.y > cfg.map_height + cfg.far_y_lift:
		preview.hide_preview()
		return
	var world := Pseudo3D.unproject(local)
	if world.y < cfg.midline_y:
		preview.hide_preview()
		return
	world.x = clampf(world.x, 0.0, cfg.map_width)
	var can_afford: bool = _selected.cost <= int(_mana)
	preview.show_card(_selected, can_afford)
	preview.set_world_pos(world)

# --- HUD --------------------------------------------------------------------

func _refresh_build_ui() -> void:
	var cfg := GameConfig.data
	wall_toggle.text = "▭ WALL %d/%d" % [_player_wall_count, cfg.max_walls_per_player]
	wall_toggle.disabled = _player_wall_count >= cfg.max_walls_per_player and not _wall_mode
	wall_toggle.modulate = Palette.WALL_ACCENT if _wall_mode else Color(1, 1, 1, 1)

func _refresh_ui() -> void:
	var cfg := GameConfig.data
	mana_bar.set_value(_mana, cfg.mana_max)
	mana_label.text = "%d / %d" % [int(_mana), cfg.mana_max]
	var enemy_mana_val: float = 0.0
	for b in _bots:
		if b.is_enemy:
			enemy_mana_val = b.mana
			break
	enemy_mana_label.text = "%d / %d" % [int(enemy_mana_val), cfg.mana_max]
	hand.set_affordability(int(_mana))
	if phase == Phase.BUILD:
		phase_label.text = "SETUP"
		var build_secs: int = maxi(0, int(ceil(_build_time_left)))
		timer_label.text = "0:%02d" % build_secs
		# Flash the timer red in the final 5 seconds so the player feels
		# the clock — the match is about to auto-start and they'd better
		# have walls down.
		if _build_time_left <= 5.0:
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
			timer_label.add_theme_color_override("font_color",
				Palette.UI_AMBER.lerp(Palette.UI_RED, pulse))
		else:
			timer_label.add_theme_color_override("font_color", Palette.UI_AMBER)
	else:
		var total_secs: int = maxi(0, int(ceil(_time_left)))
		timer_label.text = "%d:%02d" % [total_secs / 60, total_secs % 60]
	_refresh_build_ui()

func _update_hint() -> void:
	if phase == Phase.OVER:
		hint_label.text = ""
		return
	# Tutorial uses its own progress-aware hints, independent of selection state.
	if _mode != null and _mode.is_tutorial:
		_tutorial_hint()
		return
	if phase == Phase.BUILD:
		if _wall_mode:
			hint_label.text = "▭ TAP YOUR SIDE TO PLACE WALL (%d/%d)" % [_player_wall_count, GameConfig.data.max_walls_per_player]
		else:
			hint_label.text = "▭ PLACE UP TO %d WALLS — MATCH AUTO-STARTS" % GameConfig.data.max_walls_per_player
		return
	if _selected == null:
		hint_label.text = "TAP A CARD"
	elif _selected.cost > int(_mana):
		hint_label.text = "NEED %d MANA — TAP CARD TO CANCEL" % _selected.cost
	else:
		hint_label.text = "▼ TAP YOUR SIDE TO DEPLOY ▼"

func _tutorial_hint() -> void:
	if phase == Phase.BUILD:
		if _wall_mode:
			hint_label.text = "▭ TAP YOUR (BLUE) SIDE TO PLACE A WALL"
		elif _player_wall_count == 0:
			hint_label.text = "▭ TAP THE WALL BUTTON TO START PLACING"
		else:
			hint_label.text = "▸ TAP START MATCH — OR WAIT FOR AUTO-START"
		return
	var enemy_cells: int = enemy_base.count_alive() if enemy_base != null else 54
	if enemy_cells <= 0:
		hint_label.text = "GREAT — YOU WON!"
	elif enemy_cells < 54:
		hint_label.text = "KEEP GOING — DESTROY EVERY RED SQUARE TO WIN"
	elif _selected != null:
		hint_label.text = "▼ TAP YOUR SIDE (BLUE) TO DEPLOY ▼"
	else:
		hint_label.text = "TAP A CARD TO DEPLOY YOUR FIRST UNIT"

## Tutorial visual coach. Highlights the next thing the player should tap and
## displays a one-line message bubble next to it. State-derived so every frame
## the coach is showing the right hint for the current moment — no step
## counter to keep in sync.
func _update_coach() -> void:
	if _mode == null or not _mode.is_tutorial:
		coach.hide_coach()
		return
	if phase == Phase.OVER:
		coach.hide_coach()
		return
	if phase == Phase.BUILD:
		if _wall_mode:
			coach.point_at_rect(_player_deploy_screen_rect(),
				"TAP YOUR (BLUE) SIDE TO DROP A WALL — BLOCK THE LANES")
		elif _player_wall_count == 0:
			coach.point_at(wall_toggle,
				"TAP THE WALL BUTTON — WALLS SLOW ENEMY UNITS")
		else:
			# Match auto-starts at the end of the BUILD countdown — point
			# the player at the timer instead of the (hidden) START button.
			coach.point_at(timer_label,
				"WALLS SET — MATCH AUTO-STARTS WHEN THE TIMER HITS ZERO")
		return
	# MATCH / OVERTIME. Once the player lands a hit on the enemy base, stop
	# coaching — they've got it.
	if enemy_base != null and enemy_base.count_alive() < 54:
		coach.hide_coach()
		return
	if _selected == null:
		var btn: Control = hand.first_button()
		coach.point_at(btn if btn != null else hand,
			"PICK A CARD — EACH ONE COSTS MANA TO DEPLOY")
	else:
		coach.point_at_rect(_player_deploy_screen_rect(),
			"TAP YOUR SIDE TO DEPLOY — DESTROY EVERY RED SQUARE TO WIN")

## Screen-space rect covering the player's half of the projected trapezoid.
## Used by the coach to circle the deploy zone.
func _player_deploy_screen_rect() -> Rect2:
	var cfg := GameConfig.data
	var top_left: Vector2 = Pseudo3D.project(Vector2(0.0, cfg.midline_y)) + playfield.global_position
	var top_right: Vector2 = Pseudo3D.project(Vector2(cfg.map_width, cfg.midline_y)) + playfield.global_position
	var bottom_left: Vector2 = Pseudo3D.project(Vector2(0.0, cfg.map_height)) + playfield.global_position
	var bottom_right: Vector2 = Pseudo3D.project(Vector2(cfg.map_width, cfg.map_height)) + playfield.global_position
	var min_x: float = minf(minf(top_left.x, top_right.x), minf(bottom_left.x, bottom_right.x))
	var max_x: float = maxf(maxf(top_left.x, top_right.x), maxf(bottom_left.x, bottom_right.x))
	var min_y: float = minf(top_left.y, top_right.y)
	var max_y: float = maxf(bottom_left.y, bottom_right.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
