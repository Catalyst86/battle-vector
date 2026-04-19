extends Node
## Gun module registry for VOLLEY mode. Static data — a list of 8 modules
## the player can unlock and level up, and a helper that resolves a loadout
## (list of module ids) into effective stat multipliers applied on gun spawn.
##
## Progression model mirrors card levels:
##   - Each module has a per-player level stored in
##     PlayerProfileData.gun_modules[id] (default 1 once unlocked).
##   - Upgrade cost and level multiplier reuse PlayerProfile's card-upgrade
##     curve — no new economy constants.
##   - Player picks up to 3 modules for their loadout pre-match (stored in
##     PlayerProfileData.gun_loadout: Array[StringName]).
##
## See design/volley_mode.md §3d for full spec.

const MODULES: Array[Dictionary] = [
	{ "id": &"barrel",  "name": "BARREL",  "desc": "+15% damage per tier",                "max_tier": 5, "starter": true  },
	{ "id": &"cooling", "name": "COOLING", "desc": "-10% heat per shot per tier",         "max_tier": 5, "starter": true  },
	{ "id": &"trigger", "name": "TRIGGER", "desc": "+12% fire rate per tier",             "max_tier": 5, "starter": true  },
	{ "id": &"ammo",    "name": "AMMO",    "desc": "Splash radius +4px per tier",         "max_tier": 5, "starter": false },
	{ "id": &"scope",   "name": "SCOPE",   "desc": "+20% range per tier",                 "max_tier": 5, "starter": false },
	{ "id": &"plating", "name": "PLATING", "desc": "+20 gun HP per tier",                 "max_tier": 5, "starter": false },
	{ "id": &"damper",  "name": "DAMPER",  "desc": "-15% stun duration per tier",         "max_tier": 5, "starter": false },
	{ "id": &"repair",  "name": "REPAIR",  "desc": "+0.5 HP/sec auto-regen per tier",     "max_tier": 5, "starter": false },
]

## Returns the module definition dict, or empty dict if the id is unknown.
func info(id: StringName) -> Dictionary:
	for m in MODULES:
		if m.id == id:
			return m
	return {}

## True when the player has this module unlocked. Starter modules are
## always unlocked; non-starters land when we wire in a real unlock source
## (season reward, shop purchase — TODO). For MVP, all modules start
## unlocked at tier 1 so the player can experiment.
func is_unlocked(id: StringName) -> bool:
	if PlayerProfile == null or PlayerProfile.data == null:
		return false
	return PlayerProfile.data.gun_modules.has(id)

func tier(id: StringName) -> int:
	if PlayerProfile == null or PlayerProfile.data == null:
		return 0
	return int(PlayerProfile.data.gun_modules.get(id, 0))

func upgrade_cost(id: StringName) -> int:
	var t: int = tier(id)
	if t >= info(id).get("max_tier", 5):
		return -1
	# Reuse PlayerProfile.UPGRADE_COSTS for parity with the card economy.
	var idx: int = t - 1
	if PlayerProfile == null:
		return -1
	if idx < 0 or idx >= PlayerProfile.UPGRADE_COSTS.size():
		return -1
	return PlayerProfile.UPGRADE_COSTS[idx]

func can_upgrade(id: StringName) -> bool:
	if not is_unlocked(id):
		return false
	var cost: int = upgrade_cost(id)
	return cost > 0 and PlayerProfile.data.gold >= cost

func upgrade(id: StringName) -> bool:
	if not can_upgrade(id):
		return false
	var cost: int = upgrade_cost(id)
	PlayerProfile.data.gold -= cost
	PlayerProfile.data.gun_modules[id] = tier(id) + 1
	PlayerProfile.save()
	return true

## Seeds first-run module unlocks. Called by PlayerProfile on load — new
## players get the three starter modules at tier 1 so they can play Volley
## immediately without grinding.
func ensure_starters() -> void:
	if PlayerProfile == null or PlayerProfile.data == null:
		return
	var dirty := false
	for m in MODULES:
		if not m.get("starter", false):
			continue
		if not PlayerProfile.data.gun_modules.has(m.id):
			PlayerProfile.data.gun_modules[m.id] = 1
			dirty = true
	# Seed loadout with the three starters if empty.
	if PlayerProfile.data.gun_loadout.is_empty():
		for m in MODULES:
			if m.get("starter", false) and PlayerProfile.data.gun_loadout.size() < 3:
				PlayerProfile.data.gun_loadout.append(m.id)
		dirty = true
	if dirty:
		PlayerProfile.save()

## Loadout → stat modifiers. Returns a Dictionary of multipliers + additives
## that Gun applies on _ready. Missing modules contribute 0 — loadout may
## have fewer than 3 slots filled.
func compute_stats(loadout: Array) -> Dictionary:
	var stats := {
		"damage_mult":   1.0,
		"heat_mult":     1.0,
		"fire_rate_mult": 1.0,
		"splash_add":    0.0,
		"range_mult":    1.0,
		"hp_add":        0.0,
		"stun_mult":     1.0,
		"regen_add":     0.0,
	}
	for id in loadout:
		var t: int = tier(id)
		if t <= 0:
			continue
		match id:
			&"barrel":  stats.damage_mult    += 0.15 * t
			&"cooling": stats.heat_mult      *= pow(0.90, t)   # -10% compounding
			&"trigger": stats.fire_rate_mult += 0.12 * t
			&"ammo":    stats.splash_add     += 4.0 * t
			&"scope":   stats.range_mult     += 0.20 * t
			&"plating": stats.hp_add         += 20.0 * t
			&"damper":  stats.stun_mult      *= pow(0.85, t)
			&"repair":  stats.regen_add      += 0.5 * t
	return stats
