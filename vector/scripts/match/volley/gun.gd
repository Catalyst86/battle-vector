class_name Gun
extends Node2D
## Player-owned auto-aiming gun for VOLLEY mode. Scans the descending-square
## pool each frame, picks a target (nearest square heading toward its side),
## and fires projectiles on a cooldown. Accumulates heat per shot and stops
## firing when heat maxes out until it cools below the reset threshold.
##
## MVP: fixed position, fixed stats. Module loadout + cosmetic swaps come
## later per the design doc.

signal kill_scored(amount: int)
signal hp_changed(hp: float, hp_max: float)
signal destroyed

@export var is_enemy: bool = false
@export var color: Color = Color("5be0ff")

# Stats (MVP — tuneable via modules later)
const FIRE_INTERVAL: float = 0.5
const SHOT_DAMAGE: float = 2.0
const SHOT_RANGE: float = 520.0
const HEAT_PER_SHOT: float = 5.0
const HEAT_MAX: float = 100.0
const HEAT_COOLDOWN_PER_SEC: float = 18.0
const HEAT_RESET_THRESHOLD: float = 60.0
const HP_MAX: float = 100.0
const REBOOT_DURATION: float = 2.0
const AIM_TURN_RATE: float = 6.0  # radians/sec

var heat: float = 0.0
var hp: float = HP_MAX
var _fire_cd: float = 0.0
var _overheated: bool = false
var _reboot_timer: float = 0.0
var _stun_timer: float = 0.0
var _aim_angle: float = 0.0  # visual barrel angle
var _target_ref: Square = null

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/match/volley/gun_projectile.tscn")

func _ready() -> void:
	add_to_group("volley_guns")
	add_to_group("volley_gun_enemy" if is_enemy else "volley_gun_player")
	_aim_angle = PI * 0.5 if not is_enemy else -PI * 0.5
	hp_changed.emit(hp, HP_MAX)

## Called by Square units colliding with us (siege arrival) and by opposing
## spells like SURGE. Gates on reboot so dead guns don't double-die.
func take_damage(amount: float) -> void:
	if _reboot_timer > 0.0 or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	hp_changed.emit(hp, HP_MAX)
	if hp <= 0.0:
		_reboot_timer = REBOOT_DURATION
		destroyed.emit()

func apply_stun(seconds: float) -> void:
	_stun_timer = maxf(_stun_timer, seconds)

func _process(delta: float) -> void:
	# Reboot + stun gate firing entirely.
	if _reboot_timer > 0.0:
		_reboot_timer -= delta
		if _reboot_timer <= 0.0:
			hp = HP_MAX * 0.5  # come back at half HP
			hp_changed.emit(hp, HP_MAX)
		queue_redraw()
		return
	if _stun_timer > 0.0:
		_stun_timer -= delta
		queue_redraw()
		return
	# Passive heat cooldown any frame we're not firing.
	heat = maxf(0.0, heat - HEAT_COOLDOWN_PER_SEC * delta)
	if _overheated and heat < HEAT_RESET_THRESHOLD:
		_overheated = false
	# Acquire target + aim
	_target_ref = _pick_target()
	if _target_ref != null:
		var dir: Vector2 = _target_ref.global_position - global_position
		if dir.length_squared() > 0.0:
			var desired: float = dir.angle()
			_aim_angle = _smooth_angle(_aim_angle, desired, AIM_TURN_RATE * delta)
	# Fire
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if _target_ref != null and not _overheated and _fire_cd <= 0.0:
		_fire(_target_ref)
		_fire_cd = FIRE_INTERVAL
		heat += HEAT_PER_SHOT
		if heat >= HEAT_MAX:
			heat = HEAT_MAX
			_overheated = true
	queue_redraw()

func _smooth_angle(current: float, target: float, step: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	if absf(diff) <= step:
		return target
	return current + signf(diff) * step

func _pick_target() -> Square:
	# Choose the square moving toward our side that's closest to us, with
	# lowest HP as tiebreak. Squares not heading our way are valid fallbacks
	# but deprioritised — we'd rather clean our own lane.
	var best: Square = null
	var best_score: float = INF
	for n in get_tree().get_nodes_in_group("volley_squares"):
		var sq := n as Square
		if sq == null or not is_instance_valid(sq) or sq.hp <= 0.0:
			continue
		var dist: float = global_position.distance_to(sq.global_position)
		if dist > SHOT_RANGE:
			continue
		var heading_us: bool = (sq.bound_for_enemy and is_enemy) or (not sq.bound_for_enemy and not is_enemy)
		var priority: float = dist + (0.0 if heading_us else SHOT_RANGE)  # penalise other-lane
		priority += sq.hp * 8.0  # prefer cleaner kills
		if priority < best_score:
			best_score = priority
			best = sq
	return best

func _fire(sq: Square) -> void:
	var p: GunProjectile = PROJECTILE_SCENE.instantiate() as GunProjectile
	p.origin_is_enemy = is_enemy
	p.color = color
	p.damage = SHOT_DAMAGE
	get_parent().add_child(p)
	p.global_position = global_position + Vector2.from_angle(_aim_angle) * 12.0
	p.velocity = Vector2.from_angle(_aim_angle) * 620.0

# ─── Rendering ─────────────────────────────────────────────────────────────

func _draw() -> void:
	var base := color
	if _reboot_timer > 0.0:
		base = Palette.UI_TEXT_3
	elif _stun_timer > 0.0:
		base = Palette.UI_AMBER
	# Body — hexagonal gun turret, cardinal-oriented
	var pts := PackedVector2Array([
		Vector2(-14, -6), Vector2(-6, -14), Vector2(6, -14),
		Vector2(14, -6), Vector2(14, 6), Vector2(6, 14),
		Vector2(-6, 14), Vector2(-14, 6),
	])
	var loop := pts.duplicate(); loop.append(pts[0])
	var fill := base
	fill.a = 0.12
	draw_colored_polygon(pts, fill)
	draw_polyline(loop, base, 1.4, true)
	# Inner core
	draw_circle(Vector2.ZERO, 4.0, base)
	# Barrel along aim angle
	var tip := Vector2.from_angle(_aim_angle) * 22.0
	draw_line(Vector2.ZERO, tip, base, 2.0, true)
	# Heat ring — outer arc that fills clockwise with heat level
	var heat_frac: float = heat / HEAT_MAX
	var heat_color: Color = Palette.UI_RED if _overheated else Palette.UI_AMBER
	heat_color.a = 0.6
	if heat_frac > 0.0:
		draw_arc(Vector2.ZERO, 18.0, -PI * 0.5, -PI * 0.5 + heat_frac * TAU, 24, heat_color, 1.5, true)
	# HP ring — full ring underneath, fades from green → red as HP drops
	var hp_frac: float = hp / HP_MAX
	var hp_color: Color = Palette.UI_GREEN.lerp(Palette.UI_RED, 1.0 - hp_frac)
	hp_color.a = 0.5
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU * hp_frac, 48, hp_color, 2.0, true)
