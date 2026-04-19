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

func _ready() -> void:
	add_to_group("match")
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
	back_btn.pressed.connect(func(): _return_to_home())
	game_over.rematch_requested.connect(func(): _return_to_match())
	enemy_base.squares_changed.connect(func(_n): _check_win())
	player_base.squares_changed.connect(func(_n): _check_win())
	wall_toggle.pressed.connect(_on_wall_toggle)
	start_btn.pressed.connect(_start_match)
	phase_label.text = "SETUP"
	_setup_bots()
	_refresh_ui()
	_update_hint()
	_update_coach()

func _exit_tree() -> void:
	if _original_config != null:
		GameConfig.data = _original_config

func _return_to_home() -> void:
	if _original_config != null:
		GameConfig.data = _original_config
		_original_config = null
	Router.goto("res://scenes/menus/main_menu.tscn")

func _return_to_match() -> void:
	if _original_config != null:
		GameConfig.data = _original_config
		_original_config = null
	Router.goto(MATCH_SCENE_PATH)

func _setup_bots() -> void:
	_bots.clear()
	if _mode == null:
		return
	# Tutorial has no bots — just the player vs a defenseless enemy base.
	if _mode.is_tutorial:
		return
	# Bot decks are random 8-subsets of the unlocked pool so the player doesn't
	# always face a mirror match. Fallback to the player's deck if nothing else
	# is available yet (e.g. very low level with <8 unlocked).
	var pool: Array[CardData] = deck
	if PlayerProfile != null:
		var unlocked := PlayerProfile.unlocked_cards()
		if unlocked.size() >= 4:
			pool = unlocked
	if _mode.team_size == 1:
		_bots.append(_make_bot(true, _random_subset(pool, 8)))
	elif _mode.team_size >= 2:
		_bots.append(_make_bot(false, _random_subset(pool, 8)))
		_bots.append(_make_bot(true, _random_subset(pool, 8)))
		_bots.append(_make_bot(true, _random_subset(pool, 8)))

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

func _process(delta: float) -> void:
	_update_shake(delta)
	if phase == Phase.OVER:
		return
	if phase == Phase.BUILD:
		_build_time_left -= delta
		if _build_time_left <= 0.0:
			_start_match()
		_refresh_ui()
		return
	var cfg := GameConfig.data
	_mana = minf(_mana + cfg.mana_regen_per_sec * delta, float(cfg.mana_max))
	for b in _bots:
		b.mana = minf(b.mana + cfg.mana_regen_per_sec * delta, float(cfg.mana_max))
		b.timer += delta
		if b.timer >= bot_spawn_interval:
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
	_player_wall_count += 1
	if _player_wall_count >= cfg.max_walls_per_player:
		_wall_mode = false
	_refresh_build_ui()
	_update_hint()
	_update_coach()

func _start_match() -> void:
	if phase != Phase.BUILD:
		return
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
	_spawn_unit(deployed, world, false)
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
	_check_win()
	_update_coach()

## Public: trigger a screen shake. Called by units on death / melee detonation
## via `get_tree().call_group("match", "shake", amount)`.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

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
	phase = Phase.OVER
	preview.hide_preview()
	_selected = null
	var rewards: Dictionary = {"gold": 0, "trophies": 0, "xp": 0, "levels": 0}
	if _mode != null and _mode.is_tutorial:
		# Tutorial grants a one-time completion reward and doesn't touch the
		# ladder/W-L-D counters. Losses/draws give nothing.
		if result == "VICTORY" and PlayerProfile != null:
			rewards = PlayerProfile.complete_tutorial()
	elif PlayerProfile != null:
		rewards = PlayerProfile.award_match_result(result)
	game_over.show_result(
		result,
		player_base.count_alive(),
		enemy_base.count_alive(),
		rewards.get("gold", 0),
		rewards.get("trophies", 0),
		rewards.get("xp", 0),
		rewards.get("levels", 0),
	)

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
	# Prefer cards whose role isn't in recent history — stops the bot
	# from firing off three Darts in a row. Falls back to any affordable
	# if every role was used recently.
	var fresh: Array[CardData] = []
	for c in affordable:
		if not b.recent_roles.has(c.role):
			fresh.append(c)
	var pick: CardData = fresh.pick_random() if not fresh.is_empty() else affordable.pick_random()
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
	mana_label.text = "⚡ %d/%d" % [int(_mana), cfg.mana_max]
	var enemy_mana_val: float = 0.0
	for b in _bots:
		if b.is_enemy:
			enemy_mana_val = b.mana
			break
	enemy_mana_label.text = "⚡ %d/%d" % [int(enemy_mana_val), cfg.mana_max]
	hand.set_affordability(int(_mana))
	if phase == Phase.BUILD:
		phase_label.text = "SETUP"
		var build_secs: int = maxi(0, int(ceil(_build_time_left)))
		timer_label.text = "0:%02d" % build_secs
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

## Tutorial visual coach. Highlights the next thing the player should tap.
## State-derived so it always reflects the current situation — no step counter.
func _update_coach() -> void:
	if _mode == null or not _mode.is_tutorial:
		coach.hide_coach()
		return
	if phase == Phase.OVER:
		coach.hide_coach()
		return
	if phase == Phase.BUILD:
		if _wall_mode:
			coach.point_at_rect(_player_deploy_screen_rect())
		elif _player_wall_count == 0:
			coach.point_at(wall_toggle)
		else:
			coach.point_at(start_btn)
		return
	# MATCH / OVERTIME. Once the player lands a hit on the enemy base, stop
	# coaching — they've got it.
	if enemy_base != null and enemy_base.count_alive() < 54:
		coach.hide_coach()
		return
	if _selected == null:
		var btn: Control = hand.first_button()
		coach.point_at(btn if btn != null else hand)
	else:
		coach.point_at_rect(_player_deploy_screen_rect())

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
