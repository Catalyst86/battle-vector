class_name Unit
extends Node2D
## Deployed unit. Dispatches per-role AI each frame. Rendering projects flat
## `world_pos` through Pseudo3D. Damage stats account for player level AND
## nearby Buffer auras (refreshed each frame).

signal reached_base(side: int, world_pos: Vector2, damage: float)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/match/projectile.tscn")
const FX_SCENE: PackedScene = preload("res://scenes/match/fx.tscn")
const UNIT_SCENE: PackedScene = preload("res://scenes/match/unit.tscn")
const DEATH_BURST_SCENE: PackedScene = preload("res://scenes/match/death_burst.tscn")

@export var card: CardData
@export var is_enemy: bool = false

var world_pos: Vector2 = Vector2.ZERO
var hp: float = 0.0
var level_mult: float = 1.0
var base_damage: float = 0.0          # card.damage * level_mult
var effective_damage: float = 0.0     # base_damage * _buff_mult (per-frame)
var _buff_mult: float = 1.0
var _age: float = 0.0
var _spawn_t: float = 0.0
var _fire_cd: float = 0.0
var _arrived: bool = false
var _prev_world: Vector2 = Vector2.ZERO
## Hit-flash brightness (0..1). Bumped in take_damage, decays each _process,
## blended into modulate by _update_render. Separate from spawn-fade alpha.
var _flash: float = 0.0
## VOLLEY mode: when set, this unit walks toward the target gun instead of a
## BaseGrid strip, ignores walls (Volley has none), and renders flat (no
## Pseudo3D projection — the Volley field is 2D). On contact it deals its
## effective damage to the gun and self-destructs. Set by match_volley.gd
## immediately after spawn.
var _volley_gun_target: Node2D = null
## Multiplier on movement speed — defaulted to 1.0 (classic behaviour). The
## Volley controller drops this to ~0.85 so everyone walks a little less
## frantically, giving the player time to read the field and pick link
## targets. Not baked into card.speed so classic balance is untouched.
var speed_mult: float = 1.0
## When true, this unit is the first half of a pending Vector Link and a
## pulsing amber ring is drawn around it so the player can see which
## unit they picked. Cleared by match_volley on link completion / cancel.
var link_highlight: bool = false

func _ready() -> void:
	assert(card != null, "Unit.card not assigned")
	if PlayerProfile != null:
		if is_enemy:
			# Bot units scale with the player's arena so climbing the ladder
			# actually makes matches harder: +10% hp/damage per arena index.
			level_mult = 1.0 + float(PlayerProfile.arena_index()) * 0.1
		elif card.id != &"":
			level_mult = PlayerProfile.level_multiplier(card.id)
	hp = card.hp * level_mult
	base_damage = card.damage * level_mult * _synergy_multiplier()
	effective_damage = base_damage
	add_to_group("units")
	add_to_group("enemy_units" if is_enemy else "player_units")
	# Buffers go in a dedicated team group so _refresh_effective_damage can
	# fast-path: most units never iterate anything when no buffers exist.
	if card.role == CardData.Role.BUFFER:
		add_to_group("buffers_enemy" if is_enemy else "buffers_player")
	UnitRegistry.register(self)
	# Self-connect reached_base so units spawned by other units (on-death
	# Revenant → Scout etc.) still hit the match's base-damage handler.
	var match_node: Node = get_tree().get_first_node_in_group("match")
	if match_node != null and match_node.has_method("_on_unit_reached_base"):
		if not reached_base.is_connected(match_node._on_unit_reached_base):
			reached_base.connect(match_node._on_unit_reached_base)
	queue_redraw()

func _exit_tree() -> void:
	UnitRegistry.unregister(self)

## Compute damage multiplier from active deck synergies. Only the player's
## team benefits — bot decks don't participate (matches the Deck-tab UI,
## which only shows synergies for the player's loadout).
func _synergy_multiplier() -> float:
	if is_enemy or Synergies == null or PlayerDeck == null:
		return 1.0
	var deck_ids: Array = []
	for c in PlayerDeck.cards:
		deck_ids.append(c.id)
	var active: Array = Synergies.active_for(deck_ids)
	var mult: float = 1.0
	for pair in active:
		if card.id == pair.a or card.id == pair.b:
			mult += float(pair.bonus)
	return mult

func spawn_at(pos: Vector2) -> void:
	world_pos = pos
	_prev_world = pos
	_spawn_t = 0.0

func take_damage(amount: float) -> void:
	if _arrived:
		return
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		_die()
	elif card != null:
		# Non-lethal hit — play the size-weighted hit SFX. Lethal hits fall
		# through to _die() which emits the death SFX instead (no overlap).
		SfxBank.play_event(card, &"hit")

func _die() -> void:
	if card != null:
		_spawn_death_burst()
		SfxBank.play_event(card, &"death")
		if card.on_death_shockwave_radius > 0.0:
			_aoe_damage(card.on_death_shockwave_radius, card.on_death_shockwave_damage * level_mult)
			_spawn_fx(world_pos, card.on_death_shockwave_radius, card.color, 0.55)
			get_tree().call_group("match", "shake", 6.0)
			# Bigger units get a brief hit-pause on death — the shockwave
			# kill reads as a beat rather than a blur.
			get_tree().call_group("match", "hit_pause", 0.06)
		else:
			get_tree().call_group("match", "shake", 2.0)
		if card.on_death_spawn != null:
			_spawn_child_unit(card.on_death_spawn as CardData, world_pos)
	queue_free()

func _spawn_death_burst() -> void:
	var b: DeathBurst = SpawnPool.acquire_burst(get_parent()) as DeathBurst
	b.setup(world_pos, card.color)

func _spawn_child_unit(c: CardData, pos: Vector2) -> void:
	if c == null:
		return
	# Not pooled — child units are rare (Revenant deaths) and need a fresh
	# instance with full _ready lifecycle (group registration, signals).
	var u := UNIT_SCENE.instantiate()
	u.card = c
	u.is_enemy = is_enemy
	get_parent().add_child(u)
	u.spawn_at(pos)

func _process(delta: float) -> void:
	_age += delta
	_spawn_t += delta
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_flash = maxf(0.0, _flash - delta * 7.0)
	_refresh_effective_damage()

	match card.role:
		CardData.Role.SHOOTER: _do_shooter(delta)
		CardData.Role.MELEE: _do_melee(delta)
		CardData.Role.WALLBREAK: _do_wallbreak(delta)
		CardData.Role.INTERCEPTOR: _do_interceptor(delta)
		CardData.Role.SNIPER: _do_sniper(delta)
		CardData.Role.HEALER: _do_healer(delta)
		CardData.Role.BUFFER: _do_buffer(delta)
		# SWARM never arrives here — replaced on spawn.

	if _volley_gun_target != null:
		_check_volley_gun_arrival()
	else:
		_resolve_wall_collision(delta)
		_check_base_arrival()
	_update_render()
	queue_redraw()

# --- Role behaviors -----------------------------------------------------------

func _do_shooter(delta: float) -> void:
	var target: Node2D = _find_nearest_enemy(card.attack_range + 40.0)
	if target != null:
		var d: float = world_pos.distance_to(target.world_pos)
		if d > card.attack_range:
			_move_toward(target.world_pos, delta)
		_try_fire(target.world_pos)
		return
	_move_toward_base(delta)
	# No unit target → pick a specific alive enemy base square to aim at.
	var square_pos: Vector2 = _pick_base_square_target()
	if square_pos != Vector2.INF:
		_try_fire(square_pos)

func _do_melee(delta: float) -> void:
	var target: Node2D = _find_nearest_enemy(INF)
	if target != null:
		var d: float = world_pos.distance_to(target.world_pos)
		if d <= maxf(card.attack_range, card.size * 0.9):
			_deal_damage(target, effective_damage)
			var radius: float = card.melee_aoe_radius if card.melee_aoe_radius > 0.0 else 40.0
			_aoe_damage(radius, effective_damage * 0.6)
			_spawn_fx(world_pos, radius, card.color, 0.5)
			_spawn_death_burst()
			SfxBank.play_event(card, &"death")
			get_tree().call_group("match", "shake", 4.0)
			queue_free()
			return
		_move_toward(target.world_pos, delta)
		return
	_move_toward_base(delta)

func _do_wallbreak(delta: float) -> void:
	_move_toward_base(delta)
	var walls_group: String = "walls_enemy" if not is_enemy else "walls_player"
	for n in get_tree().get_nodes_in_group(walls_group):
		var w := n as Wall
		if w == null:
			continue
		if _overlaps_wall(w):
			w.take_damage(effective_damage * delta * 3.0)

func _do_interceptor(delta: float) -> void:
	var target: Node2D = _find_nearest_enemy(INF)
	if target == null:
		_move_toward_base(delta)
		return
	var d: float = world_pos.distance_to(target.world_pos)
	if d > card.attack_range:
		_move_toward(target.world_pos, delta)
		return
	var dmg: float = effective_damage * delta * 2.0
	_deal_damage(target, dmg)

func _do_sniper(_delta: float) -> void:
	# Stationary ranged attacker. Each shot picks a specific alive enemy
	# square so snipers spread fire rather than all hammering the centre.
	var square_pos: Vector2 = _pick_base_square_target()
	if square_pos != Vector2.INF:
		_try_fire(square_pos)

func _do_healer(delta: float) -> void:
	# AoE healer (Chorus): drift and heal everyone in radius.
	if card.aura_radius > 0.0:
		_move_toward_base(delta)
		if card.aura_heal_per_sec > 0.0:
			_apply_aura_heal(delta)
		return
	# Targeted healer (Mender): seek nearest wounded ally, heal when in range.
	var target: Unit = _find_nearest_wounded_ally()
	if target == null:
		_move_toward_base(delta)
		return
	var d: float = world_pos.distance_to(target.world_pos)
	if d > card.attack_range:
		_move_toward(target.world_pos, delta)
		return
	if card.aura_heal_per_sec > 0.0:
		var max_hp: float = target.card.hp * target.level_mult
		target.hp = minf(target.hp + card.aura_heal_per_sec * delta, max_hp)

func _do_buffer(delta: float) -> void:
	# Stationary aura emitter. Damage buff is picked up passively by allies in
	# _refresh_effective_damage. If also configured with a heal-aura, apply it.
	if card.aura_heal_per_sec > 0.0 and card.aura_radius > 0.0:
		_apply_aura_heal(delta)

# --- Helpers ------------------------------------------------------------------

func _deal_damage(target: Node2D, amount: float) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	# call_deferred avoids a stack overflow when an on-death shockwave kills
	# another unit with an on-death shockwave: each hit is processed on the
	# next idle frame instead of inline-recursing through take_damage → _die.
	target.call_deferred("take_damage", amount)
	if card.lifesteal_frac > 0.0:
		var max_hp: float = card.hp * level_mult
		hp = minf(hp + amount * card.lifesteal_frac, max_hp)

func _apply_aura_heal(delta: float) -> void:
	for n in UnitRegistry.allies_of(is_enemy):
		if n == self or n.is_queued_for_deletion():
			continue
		var u := n as Unit
		if u == null or u.card == null:
			continue
		if (u.world_pos - world_pos).length() <= card.aura_radius:
			var max_hp: float = u.card.hp * u.level_mult
			u.hp = minf(u.hp + card.aura_heal_per_sec * delta, max_hp)

func _refresh_effective_damage() -> void:
	_buff_mult = 1.0
	# Registry keeps a per-team buffer list so this loop only iterates BUFFER
	# units — typically 0, occasionally 1–2. O(1) array read per frame.
	for n in UnitRegistry.buffers_for(is_enemy):
		if n == self or n.is_queued_for_deletion():
			continue
		var u := n as Unit
		if u == null or u.card == null:
			continue
		if u.card.aura_damage_mult <= 0.0 or u.card.aura_radius <= 0.0:
			continue
		if (u.world_pos - world_pos).length() <= u.card.aura_radius:
			_buff_mult += u.card.aura_damage_mult
	effective_damage = base_damage * _buff_mult

func _move_toward(target: Vector2, delta: float) -> void:
	if card.speed <= 0.0:
		return
	var dir: Vector2 = target - world_pos
	if dir.length() < 0.001:
		return
	world_pos += dir.normalized() * card.speed * speed_mult * delta

func _move_toward_base(delta: float) -> void:
	if card.speed <= 0.0:
		return
	var dir_y: float = -1.0 if not is_enemy else 1.0
	world_pos.y += card.speed * speed_mult * dir_y * delta

func _try_fire(target_world: Vector2) -> void:
	if card.fire_rate <= 0.0:
		return
	if _fire_cd > 0.0:
		return
	_fire_cd = card.fire_rate
	SfxBank.play_event(card, &"shoot")
	_spawn_projectiles(target_world)

func _spawn_projectiles(target: Vector2) -> void:
	var cfg := GameConfig.data
	var count: int = maxi(1, card.projectile_count)
	var base_dir: Vector2 = (target - world_pos).normalized()
	if base_dir.length_squared() < 0.0001:
		base_dir = Vector2(0.0, -1.0 if not is_enemy else 1.0)
	var spread_rad: float = deg_to_rad(card.projectile_spread_deg)
	var start_angle: float = -spread_rad * float(count - 1) * 0.5
	# Volley projectiles travel slightly slower than classic's — same
	# "slower playfield" pass that drops unit speed_mult, so bolts don't
	# snap across the field in one frame.
	var proj_speed: float = cfg.projectile_speed
	if _volley_gun_target != null:
		proj_speed *= 0.8
	for i in count:
		var dir: Vector2 = base_dir.rotated(start_angle + spread_rad * i)
		var p: Projectile = SpawnPool.acquire_projectile(get_parent()) as Projectile
		p.world_pos = world_pos
		p.velocity = dir * proj_speed
		p.damage = effective_damage
		p.color = card.color
		p.owner_enemy = is_enemy
		p.pierces = card.pierces

## Picks a specific alive square from the opposing base for ranged aim.
## Returns Vector2.INF if no alive squares remain.
func _pick_base_square_target() -> Vector2:
	# Volley mode has no BaseGrid — SHOOTERs / SNIPERs aim at the enemy gun
	# directly so they contribute DPS to the siege effort even while walking.
	if _volley_gun_target != null and is_instance_valid(_volley_gun_target):
		return _volley_gun_target.position
	var group_name: String = "enemy_base" if not is_enemy else "player_base"
	var base := get_tree().get_first_node_in_group(group_name) as BaseGrid
	if base == null:
		return Vector2.INF
	return base.random_alive_position()

func _find_nearest_enemy(within: float) -> Node2D:
	var best: Node2D = null
	var best_d2: float = within * within
	for n in UnitRegistry.enemies_of(is_enemy):
		if n.is_queued_for_deletion():
			continue
		var u := n as Node2D
		if u == null:
			continue
		var d2: float = (u.world_pos - world_pos).length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best = u
	return best

func _find_nearest_wounded_ally() -> Unit:
	var best: Unit = null
	var best_d2: float = INF
	for n in UnitRegistry.allies_of(is_enemy):
		if n == self or n.is_queued_for_deletion():
			continue
		var u := n as Unit
		if u == null or u.card == null:
			continue
		var max_hp: float = u.card.hp * u.level_mult
		if u.hp >= max_hp - 0.1:
			continue
		var d2: float = (u.world_pos - world_pos).length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best = u
	return best

func _aoe_damage(radius: float, dmg: float) -> void:
	for n in UnitRegistry.enemies_of(is_enemy):
		if n == self or n.is_queued_for_deletion():
			continue
		var u := n as Node2D
		if u == null:
			continue
		if (u.world_pos - world_pos).length() <= radius:
			_deal_damage(u, dmg)

func _spawn_fx(at: Vector2, radius: float, c: Color, duration: float) -> void:
	var fx := FX_SCENE.instantiate() as FX
	get_parent().add_child(fx)
	fx.setup(at, radius, c, duration)

func _resolve_wall_collision(delta: float) -> void:
	# Wallbreak units and phases_walls units drill through.
	if card.role == CardData.Role.WALLBREAK or card.phases_walls:
		_prev_world = world_pos
		return
	var walls_group: String = "walls_enemy" if not is_enemy else "walls_player"
	for n in get_tree().get_nodes_in_group(walls_group):
		var w := n as Wall
		if w == null:
			continue
		var exp := _expanded_bounds(w)
		var hit: bool = exp.has_point(world_pos) or exp.has_point(_prev_world)
		if not hit:
			var wall_y := w.world_pos.y
			if (_prev_world.y - wall_y) * (world_pos.y - wall_y) < 0.0:
				var lx: float = exp.position.x
				var rx: float = exp.position.x + exp.size.x
				var cross_x: float = world_pos.x
				if _prev_world.y != world_pos.y:
					var t: float = (wall_y - _prev_world.y) / (world_pos.y - _prev_world.y)
					cross_x = _prev_world.x + t * (world_pos.x - _prev_world.x)
				if cross_x >= lx and cross_x <= rx:
					hit = true
		if hit:
			if not is_enemy:
				world_pos.y = exp.position.y + exp.size.y
			else:
				world_pos.y = exp.position.y
			w.take_damage(effective_damage * delta * 2.0)
			_prev_world = world_pos
			return
	_prev_world = world_pos

func _overlaps_wall(w: Wall) -> bool:
	return _expanded_bounds(w).has_point(world_pos)

func _expanded_bounds(w: Wall) -> Rect2:
	var b := w.bounds()
	var pad := card.size * 0.5
	return Rect2(b.position - Vector2(pad, pad), b.size + Vector2(pad * 2.0, pad * 2.0))

func _check_base_arrival() -> void:
	if _arrived:
		return
	var cfg := GameConfig.data
	var reached: int = -1
	# Trigger arrival as soon as the unit enters the base strip, so the
	# impact lands on the first row it actually touches — not the far edge.
	if not is_enemy and world_pos.y <= cfg.base_strip_height:
		reached = 1
	elif is_enemy and world_pos.y >= cfg.map_height - cfg.base_strip_height:
		reached = 0
	if reached != -1:
		_arrived = true
		reached_base.emit(reached, world_pos, effective_damage)
		queue_free()

## VOLLEY arrival — on contact with the target gun, deal the unit's current
## effective damage and self-destruct. Uses a generous hit radius so fast
## units that overshoot in one frame still register. Dying here spawns a
## death burst exactly like _die() does for unit-vs-unit kills.
func _check_volley_gun_arrival() -> void:
	if _arrived or _volley_gun_target == null or not is_instance_valid(_volley_gun_target):
		return
	var gun_pos: Vector2 = _volley_gun_target.position
	var d: float = world_pos.distance_to(gun_pos)
	if d <= 24.0:
		_arrived = true
		if _volley_gun_target.has_method("take_damage"):
			_volley_gun_target.take_damage(effective_damage)
		get_tree().call_group("match", "shake", 3.0)
		_spawn_death_burst()
		SfxBank.play_event(card, &"death")
		queue_free()

# --- Rendering ---------------------------------------------------------------

func _update_render() -> void:
	var cfg := GameConfig.data
	var pop_t: float = clampf(_spawn_t / cfg.deploy_pop_duration, 0.0, 1.0)
	var pop_ease: float = 1.0 - pow(1.0 - pop_t, 3.0)
	var pop_scale: float = lerpf(1.35, 1.0, pop_ease)
	if _volley_gun_target != null:
		# VOLLEY: flat 2D field — no perspective pinch or depth scaling.
		var screen := world_pos
		screen.y += (1.0 - pop_ease) * -cfg.deploy_pop_distance
		position = screen
		scale = Vector2.ONE * pop_scale * cfg.unit_display_scale
	else:
		var screen: Vector2 = Pseudo3D.project(world_pos)
		screen.y += (1.0 - pop_ease) * -cfg.deploy_pop_distance
		position = screen
		var s: float = Pseudo3D.scale_at(world_pos.y)
		scale = Vector2.ONE * s * pop_scale * cfg.unit_display_scale
	# Hit-flash adds white brightness that decays. Spawn fade uses alpha.
	var base_alpha: float = lerpf(0.15, 1.0, pop_ease)
	var f: float = _flash
	modulate = Color(1.0 + f, 1.0 + f, 1.0 + f, base_alpha)

func _draw() -> void:
	if card == null:
		return
	var ring := card.color
	ring.a = 0.15
	draw_arc(Vector2.ZERO, card.size * 1.15, 0.0, TAU, 48, ring, 1.0, true)
	# Secondary ring showing aura radius (buffer / healer), faint.
	if card.aura_radius > 0.0:
		var aura := card.color
		aura.a = 0.06
		draw_arc(Vector2.ZERO, card.aura_radius, 0.0, TAU, 48, aura, 1.0, true)
	# Silhouette dispatch — if the card has a registered silhouette, draw
	# the procedural vector art (jet, rocket, ship squadron, etc.) with
	# direction-aware facing. Empty id falls back to the primitive Shape so
	# unrolled cards keep rendering until they get their own silhouette.
	if card.silhouette_id != &"" and Silhouettes.has(card.silhouette_id):
		var facing: float = PI if is_enemy else 0.0
		Silhouettes.draw(self, card.silhouette_id, card.color, card.size, _age, facing)
	else:
		var rot: float = 0.0
		match card.shape:
			CardData.Shape.TRIANGLE, CardData.Shape.DIAMOND, CardData.Shape.STAR, CardData.Shape.CHEVRON:
				rot = _age * 0.6
		ShapeRenderer.draw_with_glow(self, card.shape, card.color, card.size, rot)
	var max_hp: float = card.hp * level_mult
	if hp < max_hp and max_hp > 0.0:
		var w: float = 20.0
		var h: float = 2.2
		var pct: float = clampf(hp / max_hp, 0.0, 1.0)
		var y_off: float = card.size + 6.0
		draw_rect(Rect2(-w * 0.5, y_off, w, h), Color(0, 0, 0, 0.5), true)
		draw_rect(Rect2(-w * 0.5, y_off, w * pct, h), card.color, true)
	# Vector Link selection halo — pulsing amber ring confirms the first
	# unit picked during link mode. Same amber as the LINK button so the
	# visual language matches.
	if link_highlight:
		var pulse: float = 0.5 + 0.5 * sin(_age * 8.0)
		var ring := Palette.UI_AMBER
		ring.a = 0.35 + 0.45 * pulse
		draw_arc(Vector2.ZERO, card.size * 1.55, 0.0, TAU, 48, ring, 1.8 + 1.2 * pulse, true)
