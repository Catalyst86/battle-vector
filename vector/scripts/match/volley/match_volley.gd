extends Node2D
## VOLLEY mode match controller. Handles spawner, scoring, timer, overtime,
## and the game-over hand-off. Reuses the existing menu shell (header,
## match_confirm, game_over) — just the in-match phase is specific to this
## mode.

enum Phase { MATCH, OVERTIME, OVER }

const SQUARE_SCENE: PackedScene = preload("res://scenes/match/volley/square.tscn")
const GUN_SCENE: PackedScene = preload("res://scenes/match/volley/gun.tscn")
const UNIT_SCENE: PackedScene = preload("res://scenes/match/unit.tscn")
const SCOUT_CARD: CardData = preload("res://data/cards/_scout.tres")

@onready var field: Node2D = $Field
@onready var spawner: SquareSpawner = $Field/SquareSpawner
@onready var timer_label: Label = %TimerLabel
@onready var player_score_label: Label = %PlayerScore
@onready var enemy_score_label: Label = %EnemyScore
@onready var player_hp_label: Label = %PlayerGunHP
@onready var enemy_hp_label: Label = %EnemyGunHP
@onready var phase_label: Label = %PhaseLabel
@onready var back_btn: Button = %BackButton
@onready var hint_label: Label = %HintLabel
@onready var game_over: GameOverOverlay = %GameOver
@onready var midline: ColorRect = %Midline
@onready var hand: CardHand = %Hand
@onready var mana_bar: ManaBar = %ManaBar
@onready var mana_label: Label = %ManaLabel
@onready var enemy_mana_label: Label = %EnemyManaLabel

const MATCH_SECONDS: float = 120.0
const OVERTIME_SECONDS: float = 60.0
const OT_MARGIN: int = 10  # overtime ends when a side leads by this many
const FIELD_TOP: float = 80.0
const FIELD_BOTTOM: float = 680.0
const MIDLINE_Y: float = 380.0
## Mana economy — matches classic 1V1 defaults. Tuned later if needed.
const MANA_MAX: int = 10
const MANA_START: float = 6.0
const MANA_REGEN_PER_SEC: float = 1.0
## Delay before the same card can be deployed again, keeps one-card spam at bay.
const DEPLOY_COOLDOWN: float = 0.4
## Seconds between bot spawn attempts. Aggression multiplier shortens this
## per-bot so high-arena opponents flood the board faster.
const BOT_SPAWN_INTERVAL: float = 2.0

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

var phase: Phase = Phase.MATCH
var _time_left: float = MATCH_SECONDS
var _player_score: int = 0
var _enemy_score: int = 0
var _player_gun: Gun
var _enemy_gun: Gun
var _deck: Array[CardData] = []
var _selected: CardData = null
var _mana: float = MANA_START
var _bots: Array[BotState] = []

func _ready() -> void:
	add_to_group("match")
	get_tree().paused = false
	if UnitRegistry != null:
		UnitRegistry.clear()
	MusicPlayer.play(&"match", 0.8)
	back_btn.pressed.connect(func():
		SfxBank.play_ui(&"ui_back")
		get_tree().paused = false
		Router.goto("res://scenes/menus/main_menu.tscn"))
	game_over.rematch_requested.connect(func():
		get_tree().paused = false
		Router.goto("res://scenes/match/volley/match_volley.tscn"))
	_spawn_guns()
	_setup_hand()
	_setup_bots()
	_apply_hud_style()
	_refresh_hud()
	SfxBank.play(&"match_start")
	PlayerProfile.buzz(40)

var _player_guns: Array[Gun] = []
var _enemy_guns: Array[Gun] = []
var _team_size: int = 1

func _spawn_guns() -> void:
	var mode: GameMode = CurrentMatch.get_mode() if CurrentMatch else null
	_team_size = mode.team_size if mode != null else 1
	# Side positions — 1V1 uses centre gun; 2V2 splits left/right per side.
	var player_positions: Array = _gun_positions(_team_size, FIELD_BOTTOM - 30)
	var enemy_positions: Array = _gun_positions(_team_size, FIELD_TOP + 30)
	for i in _team_size:
		var p := GUN_SCENE.instantiate() as Gun
		p.is_enemy = false
		p.color = Palette.UI_CYAN if i == 0 else Palette.UI_GREEN  # ally bot = green
		field.add_child(p)
		p.position = player_positions[i]
		p.hp_changed.connect(_refresh_hud.unbind(2))
		_player_guns.append(p)
	for i in _team_size:
		var e := GUN_SCENE.instantiate() as Gun
		e.is_enemy = true
		e.color = Palette.UI_RED
		field.add_child(e)
		e.position = enemy_positions[i]
		e.hp_changed.connect(_refresh_hud.unbind(2))
		_enemy_guns.append(e)
	_player_gun = _player_guns[0]
	_enemy_gun = _enemy_guns[0]
	spawner.square_spawned.connect(_on_square_spawned)
	spawner.spawn_y = MIDLINE_Y
	# More targets for 2V2 — boost spawn rate.
	if _team_size >= 2:
		spawner.spawn_interval = 0.22

func _setup_hand() -> void:
	# Use the player's real deck. Tutorial mode doesn't apply in Volley (MVP).
	if PlayerDeck != null and not PlayerDeck.cards.is_empty():
		_deck = PlayerDeck.cards
	else:
		_deck = []
	hand.deck = _deck
	hand.build()
	hand.set_interactive(true)
	hand.card_selected.connect(_on_card_selected)
	hand.set_affordability(int(_mana))

## Arena-themed persona drives bot deck selection — matches classic so
## climbing the ladder feels consistent. 2V2 spawns one ally-side bot
## (is_enemy=false, green-coloured gun) + two enemy bots.
func _setup_bots() -> void:
	_bots.clear()
	var arena_idx: int = PlayerProfile.arena_index() if PlayerProfile != null else 0
	var enemy_persona: Dictionary = {}
	var ally_persona: Dictionary = {}
	if BotPersonas != null:
		enemy_persona = BotPersonas.for_arena(arena_idx)
		ally_persona = BotPersonas.for_arena(maxi(0, arena_idx - 1))
	if _team_size == 1:
		_bots.append(_make_bot_from_persona(true, enemy_persona))
	elif _team_size >= 2:
		_bots.append(_make_bot_from_persona(false, ally_persona))
		_bots.append(_make_bot_from_persona(true, enemy_persona))
		_bots.append(_make_bot_from_persona(true, enemy_persona))

## Persona → BotState. Falls back to the player's deck on an empty persona
## so low-arena matches don't brick. Mirrors match.gd's version.
func _make_bot_from_persona(enemy: bool, persona: Dictionary) -> BotState:
	var b := BotState.new()
	var cards: Array[CardData] = []
	if BotPersonas != null and not persona.is_empty():
		cards = BotPersonas.deck_for(persona)
	if cards.size() < 4:
		cards = _deck.duplicate() if not _deck.is_empty() else []
	b.deck_cards = cards
	b.is_enemy = enemy
	b.mana = MANA_START
	b.timer = 0.0
	b.aggression = float(persona.get("aggression", 0.75))
	b.favour_roles = persona.get("favour_roles", [])
	b.display_name = String(persona.get("name", "BOT"))
	return b

## Bot deploy tick. Picks an affordable card, biases toward recent-role
## freshness + persona-favoured roles, spawns on the bot's own half.
func _bot_try_spawn(b: BotState) -> void:
	if b.deck_cards.is_empty() or phase == Phase.OVER:
		return
	var affordable: Array[CardData] = []
	for c in b.deck_cards:
		if c != null and c.cost <= int(b.mana):
			affordable.append(c)
	if affordable.is_empty():
		return
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
	var x: float = randf_range(40.0, 320.0)
	var y: float
	if b.is_enemy:
		# Enemy spawns on the top half (their own side) so their units walk
		# down toward the player's gun.
		y = randf_range(FIELD_TOP + 30.0, MIDLINE_Y - 30.0)
	else:
		# Ally bot spawns on the player's half, walks up toward the enemy.
		y = randf_range(MIDLINE_Y + 30.0, FIELD_BOTTOM - 30.0)
	b.mana -= float(pick.cost)
	_spawn_unit(pick, Vector2(x, y), b.is_enemy)

func _gun_positions(count: int, y: float) -> Array:
	# Single gun sits centre; duo splits left/right of centre.
	if count <= 1:
		return [Vector2(180, y)]
	return [Vector2(100, y), Vector2(260, y)]

func _apply_hud_style() -> void:
	phase_label.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	phase_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	timer_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	timer_label.add_theme_color_override("font_color", Palette.UI_AMBER)
	player_score_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	player_score_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	enemy_score_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	enemy_score_label.add_theme_color_override("font_color", Palette.UI_RED)
	player_hp_label.add_theme_font_override("font", Palette.FONT_MONO)
	player_hp_label.add_theme_color_override("font_color", Palette.UI_TEXT_2)
	enemy_hp_label.add_theme_font_override("font", Palette.FONT_MONO)
	enemy_hp_label.add_theme_color_override("font_color", Palette.UI_TEXT_2)
	hint_label.add_theme_font_override("font", Palette.FONT_MONO)
	hint_label.add_theme_color_override("font_color", Palette.UI_TEXT_3)
	mana_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	mana_label.add_theme_color_override("font_color", Palette.UI_CYAN)
	enemy_mana_label.add_theme_font_override("font", Palette.FONT_MONO_BOLD)
	enemy_mana_label.add_theme_color_override("font_color", Palette.UI_RED)
	if mana_bar is ManaBar:
		(mana_bar as ManaBar).pip_color = Palette.UI_CYAN
		(mana_bar as ManaBar).dim_color = Palette.UI_LINE_2
		mana_bar.queue_redraw()
	var exit_sb := StyleBoxFlat.new()
	exit_sb.bg_color = Palette.UI_BG_1
	exit_sb.border_color = Palette.UI_LINE_2
	exit_sb.border_width_top = 1; exit_sb.border_width_bottom = 1
	exit_sb.border_width_left = 1; exit_sb.border_width_right = 1
	for sn in ["normal", "hover", "pressed", "focus"]:
		back_btn.add_theme_stylebox_override(sn, exit_sb)
	back_btn.add_theme_font_override("font", Palette.FONT_DISPLAY)
	back_btn.add_theme_color_override("font_color", Palette.UI_TEXT_1)

func _on_square_spawned(sq: Square) -> void:
	sq.destroyed.connect(_on_square_destroyed)
	# Wire an "off-screen" watcher via _process polling in this controller —
	# the square doesn't know where the field edges are, so we arbitrate.

func _on_square_destroyed(killer_is_enemy: bool, score: int) -> void:
	if killer_is_enemy:
		_enemy_score += score
	else:
		_player_score += score
	_refresh_hud()
	_check_early_win()

func _process(delta: float) -> void:
	if phase == Phase.OVER:
		return
	# Mana regen — matches classic rate so deck-builders transfer feel.
	_mana = minf(_mana + MANA_REGEN_PER_SEC * delta, float(MANA_MAX))
	# Bot economies + deploy ticks. Aggression shortens the spawn interval
	# and boosts regen, matching classic 1V1 pacing.
	for b in _bots:
		var aggro_mult: float = 0.7 + 0.6 * clampf(b.aggression, 0.0, 1.0)
		b.mana = minf(b.mana + MANA_REGEN_PER_SEC * delta * aggro_mult, float(MANA_MAX))
		b.timer += delta
		if b.timer >= BOT_SPAWN_INTERVAL / aggro_mult:
			b.timer = 0.0
			_bot_try_spawn(b)
	_time_left -= delta
	# Escape check — a square that exits the opposing team's side without
	# being killed credits THIS team. ("Your defenders slipped one past
	# the enemy.") Symmetric for opposite case.
	for n in get_tree().get_nodes_in_group("volley_squares"):
		var sq := n as Square
		if sq == null or not is_instance_valid(sq):
			continue
		if sq.bound_for_enemy and sq.position.y < FIELD_TOP:
			_player_score += _award_from_escape(sq)
			sq.trigger_escape()
		elif not sq.bound_for_enemy and sq.position.y > FIELD_BOTTOM:
			_enemy_score += _award_from_escape(sq)
			sq.trigger_escape()
	_refresh_hud()
	if _time_left <= 0.0:
		_advance_phase()

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.OVER:
		return
	if not (event is InputEventMouseButton):
		return
	var m := event as InputEventMouseButton
	if not (m.pressed and m.button_index == MOUSE_BUTTON_LEFT):
		return
	if _selected != null:
		_try_deploy(m.position)

func _on_card_selected(card: CardData) -> void:
	_selected = card
	_update_hint()

## Pay mana + spawn a unit on the player's half. Rejects clicks on the
## enemy's half (past midline) and silently no-ops if the player can't
## afford the selected card — classic mode behaves the same.
func _try_deploy(screen: Vector2) -> void:
	if _selected == null:
		return
	if _selected.cost > int(_mana):
		return
	# Deploy bounds: player half only (below midline). Small margin at top/
	# bottom so units don't spawn inside the gun or off-screen.
	if screen.y < MIDLINE_Y + 10.0:
		return
	if screen.y > FIELD_BOTTOM - 10.0:
		return
	if screen.x < 20.0 or screen.x > 340.0:
		return
	_mana -= float(_selected.cost)
	var deployed := _selected
	SfxBank.play_event(deployed, &"deploy")
	PlayerProfile.buzz(25)
	_spawn_unit(deployed, screen, false)
	_refresh_hud()
	hand.deselect()
	hand.trigger_cooldown(deployed, DEPLOY_COOLDOWN)
	_selected = null
	_update_hint()

func _spawn_unit(c: CardData, at_world: Vector2, enemy: bool) -> void:
	if c == null:
		return
	if c.role == CardData.Role.SWARM:
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
	field.add_child(u)
	u.spawn_at(at_world)
	# VOLLEY-specific wiring: units walk toward the closest enemy gun,
	# ignoring walls and BaseGrid arrival. Picked closest so 2V2 deploys
	# near one gun prefer it over the diagonally-opposite one.
	u._volley_gun_target = _pick_target_gun(at_world, enemy)

## Closest living gun on the opposite side. Returns null only if every
## gun on that side has already been destroyed — rare, guarded downstream.
func _pick_target_gun(from: Vector2, attacker_is_enemy: bool) -> Gun:
	var pool: Array[Gun] = _player_guns if attacker_is_enemy else _enemy_guns
	var best: Gun = null
	var best_d: float = INF
	for g in pool:
		if g == null or not is_instance_valid(g):
			continue
		var d: float = from.distance_to(g.position)
		if d < best_d:
			best_d = d
			best = g
	return best

func _update_hint() -> void:
	if phase == Phase.OVER:
		hint_label.text = ""
		return
	if _selected == null:
		hint_label.text = "▸ TAP A CARD"
	elif _selected.cost > int(_mana):
		hint_label.text = "NEED %d MANA — TAP CARD TO CANCEL" % _selected.cost
	else:
		hint_label.text = "▼ TAP YOUR SIDE TO DEPLOY ▼"

func _award_from_escape(sq: Square) -> int:
	# Grab the square's intended score directly from its tier stats table.
	# Keep parity with destruction points.
	var s: Dictionary = sq.STATS.get(sq.tier, {"score": 1})
	return int(s.score)

func _check_early_win() -> void:
	const TARGET_KILLS: int = 300
	if _player_score >= TARGET_KILLS or _enemy_score >= TARGET_KILLS:
		_end_match()
	elif phase == Phase.OVERTIME:
		var diff: int = absi(_player_score - _enemy_score)
		if diff >= OT_MARGIN:
			_end_match()

func _advance_phase() -> void:
	if phase == Phase.MATCH:
		if _player_score == _enemy_score:
			phase = Phase.OVERTIME
			_time_left = OVERTIME_SECONDS
			phase_label.text = "OVERTIME"
			phase_label.add_theme_color_override("font_color", Palette.UI_RED)
		else:
			_end_match()
	elif phase == Phase.OVERTIME:
		_end_match()

func _end_match() -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	spawner.active = false
	get_tree().paused = true
	var result: String
	if _player_score > _enemy_score:
		result = "VICTORY"
		SfxBank.play(&"victory")
	elif _player_score < _enemy_score:
		result = "DEFEAT"
		SfxBank.play(&"defeat")
	else:
		result = "DRAW"
		SfxBank.play(&"draw")
	PlayerProfile.buzz(100)
	var rewards: Dictionary = PlayerProfile.award_match_result(result) if PlayerProfile != null else {}
	game_over.show_result(
		result,
		_player_score,
		_enemy_score,
		rewards.get("gold", 0),
		rewards.get("trophies", 0),
		rewards.get("xp", 0),
		rewards.get("levels", 0),
	)

func _refresh_hud() -> void:
	var total_secs: int = maxi(0, int(ceil(_time_left)))
	timer_label.text = "%d:%02d" % [total_secs / 60, total_secs % 60]
	player_score_label.text = "%d" % _player_score
	enemy_score_label.text = "%d" % _enemy_score
	# Sum HP across all guns on a side — 2V2 shows the team's combined HP.
	var p_hp: int = 0
	for g in _player_guns:
		if is_instance_valid(g): p_hp += int(g.hp)
	var e_hp: int = 0
	for g in _enemy_guns:
		if is_instance_valid(g): e_hp += int(g.hp)
	player_hp_label.text = "HP %d" % p_hp
	enemy_hp_label.text = "HP %d" % e_hp
	mana_bar.set_value(_mana, MANA_MAX)
	mana_label.text = "⚡ %d/%d" % [int(_mana), MANA_MAX]
	# Enemy mana reads the first live enemy bot — gives the player a feel for
	# when the opponent is about to deploy without exposing all bots in 2V2.
	var enemy_bot_mana: float = 0.0
	for b in _bots:
		if b.is_enemy:
			enemy_bot_mana = b.mana
			break
	enemy_mana_label.text = "⚡ %d/%d" % [int(enemy_bot_mana), MANA_MAX]
	hand.set_affordability(int(_mana))
	if phase == Phase.OVERTIME:
		hint_label.text = "▸ OVERTIME — LEAD BY %d TO WIN" % OT_MARGIN
	elif _time_left <= 10.0 and _selected == null:
		hint_label.text = "▸ FINAL SECONDS"
	elif _selected == null:
		if _player_score > _enemy_score + 20:
			hint_label.text = "▸ HOLD THE LINE"
		elif _player_score < _enemy_score - 20:
			hint_label.text = "▸ PRESS HARDER — YOU'RE BEHIND"
		else:
			hint_label.text = "▸ TAP A CARD"
	elif _selected != null and _selected.cost > int(_mana):
		hint_label.text = "NEED %d MANA — TAP CARD TO CANCEL" % _selected.cost
	else:
		hint_label.text = "▼ TAP YOUR SIDE TO DEPLOY ▼"
