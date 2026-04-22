extends Node
## Match-level event logging. Appends a CSV row to user://matches.csv on
## every match end so post-launch balance iteration has real data instead
## of intuition. Columns match `HEADERS` below — add new fields by bumping
## schema_version and extending both arrays; old rows remain readable.
##
## Sized small on purpose: no unit-by-unit damage log, no per-second
## frames. This is the bare minimum "what did the player do" row.
## Unit-level telemetry is a later add if needed.

const LOG_PATH: String = "user://matches.csv"
const SCHEMA_VERSION: int = 1

## Column order — update `log_match` callers if you reorder.
const HEADERS: Array[String] = [
	"schema_version",
	"timestamp_unix",
	"mode",              # "classic_1v1" | "classic_2v2" | "volley_1v1" | "volley_2v2" | "tutorial"
	"team_size",
	"result",            # "VICTORY" | "DEFEAT" | "DRAW" | "TUTORIAL COMPLETE"
	"duration_s",        # wall-clock seconds
	"phase_at_end",      # "MATCH" | "OVERTIME" | "SURGE"
	"player_score",      # kills (volley) or surviving-base-squares (classic)
	"enemy_score",
	"cards_played",      # count of player deploys this match
	"cards_linked",      # Vector Link fusions (volley)
	"rift_captured_by",  # "player" | "enemy" | "none"
	"player_arena_index",
	"player_level",
	"trophies_after",
	"deck_ids",          # semicolon-separated
]

func _ready() -> void:
	_ensure_headers()

func _ensure_headers() -> void:
	if FileAccess.file_exists(LOG_PATH):
		return
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Telemetry: failed to create %s" % LOG_PATH)
		return
	f.store_line(",".join(HEADERS))
	f.close()

## Caller supplies a Dictionary; missing keys default to "". Values are
## shallow-stringified. Commas in string fields are replaced with ";" to
## keep the CSV single-field-per-column (good enough for MVP telemetry;
## proper quoting comes later if any field starts carrying commas).
func log_match(data: Dictionary) -> void:
	_ensure_headers()
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		push_warning("Telemetry: failed to open %s for append" % LOG_PATH)
		return
	f.seek_end()
	var fields: Array[String] = []
	for h in HEADERS:
		var v = data.get(h, "")
		if h == "schema_version":
			v = SCHEMA_VERSION
		elif h == "timestamp_unix" and v == "":
			v = Time.get_unix_time_from_system()
		fields.append(_sanitize(str(v)))
	f.store_line(",".join(fields))
	f.close()

func _sanitize(s: String) -> String:
	# Keep CSV one-column-per-field. No quoting yet; just swap separators.
	return s.replace(",", ";").replace("\n", " ").replace("\r", "")

## Convenience — called once from dev console to get a snapshot of the
## raw log file content without opening the user:// directory manually.
func snapshot() -> String:
	if not FileAccess.file_exists(LOG_PATH):
		return ""
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	var txt := f.get_as_text()
	f.close()
	return txt
