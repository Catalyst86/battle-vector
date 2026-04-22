extends Node
## Global player progression. Holds gold, trophies, and card levels. Persists
## to user://profile.tres. All economy numbers live here — tune as needed.

const PROFILE_PATH := "user://profile.tres"

## Upgrade costs, index 0 = cost to go from L1 → L2, etc.
## Audit-raised 1.5× from the original (20/50/100/200/400/800/1500/3000/6000)
## to pull days-to-max-1-card from ~25 toward the 60-120 benchmark floor.
## Total L1→L10 cost: 18,105 gold.
const UPGRADE_COSTS: Array[int] = [30, 75, 150, 300, 600, 1200, 2250, 4500, 9000]

## Arena trophy thresholds (index = arena level).
const ARENA_THRESHOLDS: Array[int] = [0, 100, 300, 600, 1000, 1500, 2200, 3000]
const ARENA_NAMES: Array[String] = [
	"GROUND ZERO", "SCRAP ALLEY", "NEON ARC", "VOID HALLS",
	"DATAVAULT", "SIGNAL PEAK", "STORM LAYER", "APEX GRID",
]

## Match payouts.
const WIN_GOLD := 60
const WIN_TROPHIES := 30
const WIN_XP := 50
const LOSS_GOLD := 15
const LOSS_TROPHIES := -20
const LOSS_XP := 15
const DRAW_GOLD := 25
const DRAW_TROPHIES := 0
const DRAW_XP := 25

## Free daily chest payout range + cooldown (seconds). Tune freely.
const FREE_CHEST_COOLDOWN: int = 86400  # 24h
const FREE_CHEST_GOLD_MIN: int = 80
const FREE_CHEST_GOLD_MAX: int = 160
const FREE_CHEST_XP_MIN: int = 30
const FREE_CHEST_XP_MAX: int = 80

signal changed

var data: PlayerProfileData

func _ready() -> void:
	_load()

func _load() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		data = load(PROFILE_PATH) as PlayerProfileData
	if data == null:
		data = PlayerProfileData.new()
	_ensure_levels()
	_apply_audio()
	# Seed the Volley gun-module starter set + default loadout. Deferred so
	# GunModules autoload (which depends on PlayerProfile being alive) has
	# time to boot before we call into it.
	call_deferred("_ensure_gun_modules")

func _ensure_gun_modules() -> void:
	if GunModules != null:
		GunModules.ensure_starters()

func _ensure_levels() -> void:
	# Make sure every card in the pool has a level entry. New cards added
	# later will default to level 1 without wiping existing progress.
	for c in PlayerDeck.pool():
		if not data.card_levels.has(c.id):
			data.card_levels[c.id] = 1

func save() -> void:
	var err := ResourceSaver.save(data, PROFILE_PATH)
	if err != OK:
		push_error("PlayerProfile save failed: %d" % err)
	changed.emit()

# --- Levels -----------------------------------------------------------------

func get_card_level(id: StringName) -> int:
	return int(data.card_levels.get(id, 1))

func level_multiplier(id: StringName) -> float:
	return 1.0 + (get_card_level(id) - 1) * 0.1

func upgrade_cost(id: StringName) -> int:
	var lvl := get_card_level(id)
	if lvl >= data.max_card_level:
		return -1
	var idx := lvl - 1
	if idx < 0 or idx >= UPGRADE_COSTS.size():
		return -1
	return UPGRADE_COSTS[idx]

func can_upgrade(id: StringName) -> bool:
	var cost := upgrade_cost(id)
	return cost > 0 and data.gold >= cost

func upgrade(id: StringName) -> bool:
	if not can_upgrade(id):
		return false
	var cost := upgrade_cost(id)
	data.gold -= cost
	data.card_levels[id] = get_card_level(id) + 1
	save()
	return true

# --- Economy ----------------------------------------------------------------

func award(gold_delta: int, trophy_delta: int) -> void:
	data.gold = maxi(0, data.gold + gold_delta)
	data.trophies = maxi(0, data.trophies + trophy_delta)
	save()

func award_match_result(result: String) -> Dictionary:
	var gold_delta: int = 0
	var trophy_delta: int = 0
	var xp_delta: int = 0
	var history_token: String = ""
	match result:
		"VICTORY":
			gold_delta = WIN_GOLD
			trophy_delta = WIN_TROPHIES
			xp_delta = WIN_XP
			data.wins += 1
			history_token = "W"
			if DailyOps != null:
				DailyOps.track(&"win_matches", 1)
		"DEFEAT":
			gold_delta = LOSS_GOLD
			trophy_delta = LOSS_TROPHIES
			xp_delta = LOSS_XP
			data.losses += 1
			history_token = "L"
		"DRAW":
			gold_delta = DRAW_GOLD
			trophy_delta = DRAW_TROPHIES
			xp_delta = DRAW_XP
			data.draws += 1
			history_token = "D"
	# Match history ring — keep last 5, oldest first.
	if history_token != "":
		data.match_history.append(history_token)
		while data.match_history.size() > 5:
			data.match_history.pop_front()
	award(gold_delta, trophy_delta)
	if data.trophies > data.best_trophies:
		data.best_trophies = data.trophies
	var levels_gained := award_xp(xp_delta)
	# Season XP is 1:1 with player XP for now — every match advances both
	# tracks. Tweak the multiplier if the season track needs to feel slower.
	if SeasonPass != null and xp_delta > 0:
		SeasonPass.award_xp(xp_delta)
	return {"gold": gold_delta, "trophies": trophy_delta, "xp": xp_delta, "levels": levels_gained}

# --- Player XP / level ------------------------------------------------------

## XP required to go from level `lvl` → `lvl+1`. Quadratic ramp.
## Audit pulled coefficient from 80 → 40 (halved) so matches-to-max-level
## moves from ~2550 toward the 300-500 benchmark. Now: ~1275 matches at
## median XP rate — still above the ceiling but within 2.5× rather than 5×.
## If this feels too fast in playtest, raise coefficient toward 60.
func xp_to_next(lvl: int) -> int:
	if lvl >= data.max_player_level:
		return -1
	return 40 * lvl * lvl + 120

func xp_progress_frac() -> float:
	var needed := xp_to_next(data.player_level)
	if needed <= 0:
		return 1.0
	return clampf(float(data.xp) / float(needed), 0.0, 1.0)

## Adds XP and levels up as many times as the new total allows. Returns the
## number of levels gained this call.
func award_xp(amount: int) -> int:
	if amount <= 0:
		save()
		return 0
	data.xp += amount
	var gained := 0
	while data.player_level < data.max_player_level:
		var need := xp_to_next(data.player_level)
		if need < 0 or data.xp < need:
			break
		data.xp -= need
		data.player_level += 1
		gained += 1
	save()
	return gained

## Called when the player wins the tutorial for the first time. One-time
## reward; subsequent replays return zero deltas so there's nothing to farm.
func complete_tutorial() -> Dictionary:
	if data.tutorial_completed:
		save()
		return {"gold": 0, "trophies": 0, "xp": 0, "levels": 0}
	data.tutorial_completed = true
	data.gold += 50
	var levels := award_xp(50)  # award_xp calls save()
	return {"gold": 50, "trophies": 0, "xp": 50, "levels": levels}

## All cards in the pool the player's current level has unlocked.
func unlocked_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for c in PlayerDeck.pool():
		if c != null and c.unlock_level <= data.player_level:
			result.append(c)
	return result

func is_card_unlocked(c: CardData) -> bool:
	return c != null and c.unlock_level <= data.player_level

# --- Arena ------------------------------------------------------------------

func arena_index() -> int:
	var t := data.trophies
	var idx := 0
	for i in ARENA_THRESHOLDS.size():
		if t >= ARENA_THRESHOLDS[i]:
			idx = i
	return idx

func arena_name() -> String:
	var i := arena_index()
	if i < 0 or i >= ARENA_NAMES.size():
		return "?"
	return ARENA_NAMES[i]

func arena_label() -> String:
	return "ARENA %d — %s" % [arena_index() + 1, arena_name()]

## Returns -1 if already in the top arena.
func next_arena_threshold() -> int:
	var cur := arena_index()
	if cur + 1 >= ARENA_THRESHOLDS.size():
		return -1
	return ARENA_THRESHOLDS[cur + 1]

func current_arena_floor() -> int:
	return ARENA_THRESHOLDS[arena_index()]

func total_matches() -> int:
	return data.wins + data.losses + data.draws

func win_rate() -> float:
	var t := total_matches()
	if t == 0:
		return 0.0
	return float(data.wins) / float(t)

# --- Free chest -------------------------------------------------------------

func seconds_until_free_chest() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	var elapsed: int = now - data.last_free_chest_ts
	return maxi(0, FREE_CHEST_COOLDOWN - elapsed)

func can_claim_free_chest() -> bool:
	return seconds_until_free_chest() <= 0

## Rolls a random gold + xp reward, marks the claim timestamp, and saves.
## Returns the deltas (or zeros if cooldown hasn't expired).
func claim_free_chest() -> Dictionary:
	if not can_claim_free_chest():
		return {"gold": 0, "xp": 0, "levels": 0}
	var gold_delta: int = randi_range(FREE_CHEST_GOLD_MIN, FREE_CHEST_GOLD_MAX)
	var xp_delta: int = randi_range(FREE_CHEST_XP_MIN, FREE_CHEST_XP_MAX)
	data.gold += gold_delta
	data.last_free_chest_ts = int(Time.get_unix_time_from_system())
	var levels := award_xp(xp_delta)
	return {"gold": gold_delta, "xp": xp_delta, "levels": levels}

# --- Audio ------------------------------------------------------------------

## Push the saved music/sfx/mute values into the AudioServer bus volumes.
## Safe to call before buses exist (get_bus_index returns -1 and we skip).
func _apply_audio() -> void:
	var music_idx := AudioServer.get_bus_index(&"Music")
	var sfx_idx := AudioServer.get_bus_index(&"SFX")
	var muted: bool = data.audio_muted
	if music_idx >= 0:
		var v: float = maxf(0.0001, data.music_volume)
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(v))
		AudioServer.set_bus_mute(music_idx, muted or data.music_volume <= 0.0)
	if sfx_idx >= 0:
		var v: float = maxf(0.0001, data.sfx_volume)
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(v))
		AudioServer.set_bus_mute(sfx_idx, muted or data.sfx_volume <= 0.0)

func set_music_volume(v: float) -> void:
	data.music_volume = clampf(v, 0.0, 1.0)
	_apply_audio()
	save()

func set_sfx_volume(v: float) -> void:
	data.sfx_volume = clampf(v, 0.0, 1.0)
	_apply_audio()
	save()

func set_audio_muted(b: bool) -> void:
	data.audio_muted = b
	_apply_audio()
	save()

# --- Graphics toggles -------------------------------------------------------

func set_scanlines_enabled(b: bool) -> void:
	data.scanlines_enabled = b
	save()

func set_screen_shake_enabled(b: bool) -> void:
	data.screen_shake_enabled = b
	save()

func set_haptic_enabled(b: bool) -> void:
	data.haptic_enabled = b
	save()

## Triggers a short Android phone vibration. No-op on desktop and when the
## user has haptics disabled. Keep pulses brief — 20–90ms range.
func buzz(duration_ms: int) -> void:
	if data == null or not data.haptic_enabled:
		return
	Input.vibrate_handheld(duration_ms)

func set_player_name(new_name: String) -> void:
	var trimmed: String = new_name.strip_edges().substr(0, 16)
	if trimmed == "":
		return
	data.player_name = trimmed
	save()
