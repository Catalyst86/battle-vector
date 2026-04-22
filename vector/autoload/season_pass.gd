extends Node
## Season pass. Linear tier ladder — earn season XP from matches, unlock tier
## rewards. A single hard-coded season for now ("VECTOR.INIT"); swap the
## constants to rotate. Saves to PlayerProfile.

signal changed

const SEASON_NAME: String = "VECTOR.INIT"
const SEASON_NUMBER: int = 1
const MAX_TIER: int = 30
## Audit raised from 200 → 400 to compensate for the halved player-XP
## curve (player_profile.xp_to_next coefficient 80 → 40). Without this
## adjustment the season pass would fill in half the intended time.
const XP_PER_TIER: int = 400
## Unix timestamp the season ends — hard-coded 30 days from the project's
## reference date. Replace when you roll a real season schedule.
const SEASON_END_UNIX: int = 1776614400   # 2026-04-19 + 30d at 00:00 UTC (approx)

## Rewards per tier. `gold` and `xp` are the player-facing deliverables; a
## symbolic `label` is displayed in the Next-Up strip.
const REWARDS: Array[Dictionary] = [
	{ "gold": 40,  "label": "40 GOLD" },
	{ "gold": 60,  "label": "60 GOLD" },
	{ "gold": 80,  "label": "80 GOLD" },
	{ "gold": 0,   "label": "CHEVRON SKIN", "cosmetic": &"chevron_skin" },
	{ "gold": 100, "label": "100 GOLD" },
	{ "gold": 120, "label": "120 GOLD" },
	{ "gold": 150, "label": "150 GOLD" },
	{ "gold": 0,   "label": "DART SKIN", "cosmetic": &"dart_skin" },
	{ "gold": 180, "label": "180 GOLD" },
	{ "gold": 200, "label": "200 GOLD" },
]

func reward_at(tier: int) -> Dictionary:
	if tier < 0 or tier >= REWARDS.size():
		return { "gold": 200 + tier * 10, "label": "%d GOLD" % (200 + tier * 10) }
	return REWARDS[tier]

## Award season XP. Rolls the tier forward as needed. Returns tiers gained.
func award_xp(amount: int) -> int:
	if PlayerProfile == null or PlayerProfile.data == null or amount <= 0:
		return 0
	PlayerProfile.data.season_xp += amount
	var gained: int = 0
	while PlayerProfile.data.season_tier < MAX_TIER and PlayerProfile.data.season_xp >= XP_PER_TIER:
		PlayerProfile.data.season_xp -= XP_PER_TIER
		PlayerProfile.data.season_tier += 1
		gained += 1
	PlayerProfile.save()
	changed.emit()
	return gained

func claim(tier: int) -> Dictionary:
	if PlayerProfile == null or PlayerProfile.data == null:
		return {}
	if tier >= PlayerProfile.data.season_tier:
		return {}
	if PlayerProfile.data.season_pass_claimed.has(tier):
		return {}
	PlayerProfile.data.season_pass_claimed.append(tier)
	var reward: Dictionary = reward_at(tier)
	PlayerProfile.data.gold += int(reward.get("gold", 0))
	PlayerProfile.save()
	changed.emit()
	return reward

func xp_progress_frac() -> float:
	if PlayerProfile == null or PlayerProfile.data == null:
		return 0.0
	return clampf(float(PlayerProfile.data.season_xp) / float(XP_PER_TIER), 0.0, 1.0)

func seconds_remaining() -> int:
	return maxi(0, SEASON_END_UNIX - int(Time.get_unix_time_from_system()))
