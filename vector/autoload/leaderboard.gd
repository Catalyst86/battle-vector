extends Node
## Season leaderboard — local, fake data until a real backend is in place.
## Top 3 are fixed personalities so the screen has character; the player's
## row is derived live from PlayerProfile.

const TOP: Array[Dictionary] = [
	{ "rank": 1, "name": "VEC.HEX",    "trophies": 3842 },
	{ "rank": 2, "name": "NULL.KEY",   "trophies": 3611 },
	{ "rank": 3, "name": "RAY.CAST",   "trophies": 3502 },
	{ "rank": 4, "name": "OVERCAST",   "trophies": 3388 },
	{ "rank": 5, "name": "GRAV.9",     "trophies": 3201 },
]

## Returns top N + player row with a blank-separator marker. Consumer draws
## a divider before any row whose `me` flag is true.
func rows(top_n: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r in TOP.slice(0, top_n):
		var row: Dictionary = r.duplicate()
		row["me"] = false
		result.append(row)
	if PlayerProfile != null and PlayerProfile.data != null:
		# Fake rank — player sits below the visible top. Scales with trophies
		# so it feels responsive to progression.
		var trophies: int = PlayerProfile.data.trophies
		var fake_rank: int = maxi(top_n + 1, 2100 - trophies)
		result.append({
			"rank": fake_rank,
			"name": PlayerProfile.data.player_name,
			"trophies": trophies,
			"me": true,
		})
	return result
