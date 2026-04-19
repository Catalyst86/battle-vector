extends Node
## Loads the central GameConfig resource so every system can read it as
## `GameConfig.data.<field>`. Swap the resource in the inspector to hot-swap
## a whole set of tuning values (e.g. for a "hardcore" or "playtest" profile).

const DEFAULT_PATH := "res://data/config/game_config.tres"

var data: GameConfigData

func _ready() -> void:
	data = load(DEFAULT_PATH) as GameConfigData
	if data == null:
		push_error("GameConfig resource missing at %s — using defaults." % DEFAULT_PATH)
		data = GameConfigData.new()
