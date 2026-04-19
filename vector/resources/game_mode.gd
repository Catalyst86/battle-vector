@tool
class_name GameMode
extends Resource
## Describes a match type. Mode picker on the home screen selects one of these
## and stores it on CurrentMatch; Match.gd reads it at boot to configure the
## scene (team size, how many bot stand-ins, which config resource).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(1, 4) var team_size: int = 1
## If true, the mode expects a networked peer to fill the other seats.
## Until networking lands, the match falls back to bot stand-ins.
@export var networked: bool = false
## Optional mode-specific config override. If null, the global game_config.tres
## is used. Lets 2v2 ship a larger map without touching 1v1 balance.
@export var config: GameConfigData = null
## Tutorial mode — match uses a preset deck, no enemy bot spawns, and scripted
## hint text guides the player through deploy → damage → win. First victory
## flips PlayerProfile.tutorial_completed and grants a small one-time reward.
@export var is_tutorial: bool = false
