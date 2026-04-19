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

## Last 5 match results as single-char strings ("W" / "L" / "D"), oldest first.
## Drives the Last-5-Ops strip on the Home tab.
@export var match_history: Array[String] = []

## Daily-ops progress. Map of quest_id (StringName) → int progress.
## Reset once per local day — DailyOps autoload is source of truth for the
## quest list itself; this just stores how far the player has gotten.
@export var daily_ops_progress: Dictionary = {}
## Local-day index (days since epoch) of the last daily reset. Used by
## DailyOps to detect a new day and roll a fresh quest list.
@export var daily_ops_day: int = 0
## IDs of completed daily ops for the current day — don't award rewards twice.
@export var daily_ops_claimed: Array[StringName] = []

## Season pass — current tier 0..SeasonPass.MAX_TIER; season XP accrued toward
## the next tier. Claim state lives in `season_pass_claimed` as a set of tier
## ints (int keys since StringName tiers would be overkill).
@export var season_tier: int = 0
@export var season_xp: int = 0
@export var season_pass_claimed: Array[int] = []

## Gun module progression for VOLLEY mode. Map of module_id (StringName) →
## tier (int, starts at 1 when unlocked). Starter modules are seeded on
## first load via GunModules.ensure_starters.
@export var gun_modules: Dictionary = {}
## Three-slot loadout of module ids. Seeded to the starter trio on first
## load; player can edit in the Loadout modal before each Volley match.
@export var gun_loadout: Array[StringName] = []

## Audio settings — linear 0..1 values that map onto the Music and SFX bus
## volumes. Applied by PlayerProfile on load and whenever the user adjusts a
## slider in the settings menu.
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.7
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 0.9
@export var audio_muted: bool = false

## Graphics settings — honoured by the menu scanline overlay and match-shake
## code. Defaults on; players can disable via the settings sheet.
@export var scanlines_enabled: bool = true
@export var screen_shake_enabled: bool = true
## Haptic feedback toggle. When on, PlayerProfile.buzz(ms) drives the phone
## vibrator on deploy / base-damage / match-end / phase-start events. On
## desktop this is a no-op — Input.vibrate_handheld only fires on Android.
@export var haptic_enabled: bool = true
