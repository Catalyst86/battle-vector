extends Node
## Daily operations system. 3 rotating quests refresh at local midnight.
## Progress + claim state lives on PlayerProfile; the pool of possible quests
## and active selection logic lives here.
##
## Emits `changed` whenever progress ticks forward or a new day rolls.

signal changed

## Pool of quest templates. `target` is the count needed to complete;
## `reward_gold` and `reward_xp` go to PlayerProfile on claim.
const POOL: Array[Dictionary] = [
	{ "id": &"win_matches",     "label": "WIN 3 MATCHES",             "target": 3, "reward_gold": 80, "reward_xp": 0 },
	{ "id": &"deploy_units",    "label": "DEPLOY 20 UNITS",           "target": 20, "reward_gold": 50, "reward_xp": 30 },
	{ "id": &"destroy_squares", "label": "DESTROY 30 ENEMY SQUARES",  "target": 30, "reward_gold": 60, "reward_xp": 20 },
	{ "id": &"play_roles",      "label": "PLAY 5 DIFFERENT ROLES",    "target": 5, "reward_gold": 40, "reward_xp": 40 },
	{ "id": &"no_walls",        "label": "WIN A MATCH WITHOUT WALLS", "target": 1, "reward_gold": 100, "reward_xp": 0 },
	{ "id": &"overtime_win",    "label": "WIN IN OVERTIME",           "target": 1, "reward_gold": 60, "reward_xp": 50 },
	{ "id": &"tutorial_replay", "label": "REPLAY THE TUTORIAL",       "target": 1, "reward_gold": 30, "reward_xp": 30 },
	{ "id": &"deploy_swarm",    "label": "DEPLOY 3 SWARM CARDS",      "target": 3, "reward_gold": 40, "reward_xp": 20 },
	{ "id": &"deploy_snipe",    "label": "DEPLOY 2 SNIPERS",          "target": 2, "reward_gold": 40, "reward_xp": 30 },
]

## Active quests for the day. Cached after `ensure_today()`.
var _active: Array[Dictionary] = []

func _ready() -> void:
	# Defer ensure_today so PlayerProfile has a chance to _load first.
	call_deferred("ensure_today")

## Returns the 3 active quests, rolling a new set if the day has changed.
func active() -> Array[Dictionary]:
	ensure_today()
	return _active

## Checks the local day against PlayerProfile's stored day. On mismatch picks
## a new random triple, clears progress, emits `changed`.
func ensure_today() -> void:
	if PlayerProfile == null or PlayerProfile.data == null:
		return
	var today: int = _local_day_index()
	if PlayerProfile.data.daily_ops_day == today and not _active.is_empty():
		return
	PlayerProfile.data.daily_ops_day = today
	PlayerProfile.data.daily_ops_progress.clear()
	PlayerProfile.data.daily_ops_claimed.clear()
	_active = _roll_triple()
	PlayerProfile.save()
	changed.emit()

func _local_day_index() -> int:
	var unix: int = int(Time.get_unix_time_from_system())
	# Naive local-day = unix-day; timezone skew is acceptable for a reset clock.
	return unix / 86400

func _roll_triple() -> Array[Dictionary]:
	var pool := POOL.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)

func progress_of(quest_id: StringName) -> int:
	if PlayerProfile == null or PlayerProfile.data == null:
		return 0
	return int(PlayerProfile.data.daily_ops_progress.get(quest_id, 0))

func target_of(quest_id: StringName) -> int:
	for q in active():
		if q.id == quest_id:
			return int(q.target)
	return 1

func is_done(quest_id: StringName) -> bool:
	return progress_of(quest_id) >= target_of(quest_id)

func is_claimed(quest_id: StringName) -> bool:
	if PlayerProfile == null or PlayerProfile.data == null:
		return false
	return PlayerProfile.data.daily_ops_claimed.has(quest_id)

## Advance a quest's progress by `amount`. If it crosses the target, the
## reward is auto-claimed (no manual step — keeps the UI simple).
func track(quest_id: StringName, amount: int = 1) -> void:
	if PlayerProfile == null or PlayerProfile.data == null:
		return
	ensure_today()
	var was_done: bool = is_done(quest_id)
	var cur: int = progress_of(quest_id)
	var target: int = target_of(quest_id)
	PlayerProfile.data.daily_ops_progress[quest_id] = mini(cur + amount, target)
	if not was_done and is_done(quest_id) and not is_claimed(quest_id):
		_award(quest_id)
	changed.emit()

func _award(quest_id: StringName) -> void:
	for q in _active:
		if q.id != quest_id:
			continue
		PlayerProfile.data.daily_ops_claimed.append(quest_id)
		PlayerProfile.data.gold += int(q.reward_gold)
		if int(q.reward_xp) > 0:
			PlayerProfile.award_xp(int(q.reward_xp))   # award_xp saves internally
		else:
			PlayerProfile.save()
		return

## Seconds until the next local-day rollover. Drives the "RESETS hh:mm:ss"
## countdown on the Home tab.
func seconds_until_reset() -> int:
	var unix: int = int(Time.get_unix_time_from_system())
	var next: int = ((unix / 86400) + 1) * 86400
	return next - unix
