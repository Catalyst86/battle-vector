@tool
class_name PlayerProfileData
extends Resource
## Persistent player identity + economy. Stored at user://profile.tres.
## Swap the whole Resource to reset a save, or edit a field in-editor to
## gift yourself gold for playtesting.

@export var player_name: String = "VEC.BLUE"
@export var gold: int = 250
@export var trophies: int = 0
@export var best_trophies: int = 0
@export var xp: int = 0
@export var player_level: int = 1
@export var max_card_level: int = 10
@export var max_player_level: int = 15
@export var wins: int = 0
@export var losses: int = 0
@export var draws: int = 0
@export var tutorial_completed: bool = false
## Unix timestamp of the last free-chest claim. 0 = never claimed.
@export var last_free_chest_ts: int = 0
## Map of card_id (StringName) → level (int, starts at 1).
@export var card_levels: Dictionary = {}
