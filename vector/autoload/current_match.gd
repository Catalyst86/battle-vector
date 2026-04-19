extends Node
## Holds the selected GameMode across scene transitions. Home sets it before
## launching the match; Match reads it on _ready. If unset (e.g. scene run
## directly), returns a sensible default.

const DEFAULT_MODE_PATH := "res://data/game_modes/solo_1v1.tres"

var mode: GameMode = null

func set_mode(m: GameMode) -> void:
	mode = m

func get_mode() -> GameMode:
	if mode != null:
		return mode
	var m := load(DEFAULT_MODE_PATH) as GameMode
	mode = m
	return m
