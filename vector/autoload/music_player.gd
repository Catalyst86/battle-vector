extends Node
## Music playback with crossfade. Expects tracks at res://audio/music/<id>.ogg
## (or .mp3). If a track file is missing it silently no-ops — drop the files in
## later and they'll start working without any code changes.
##
## Usage:
##   MusicPlayer.play(&"menu")
##   MusicPlayer.play(&"match", 0.8)
##   MusicPlayer.stop(0.6)
##
## Track ids are conventional, not enforced: "menu", "match", "victory".

const MUSIC_DIR: String = "res://audio/music/"
const SUPPORTED_EXTS: Array[String] = ["ogg", "mp3"]

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer = null
var _current_track: StringName = &""
var _tween: Tween = null
var _warned_missing: Dictionary = {}   # id -> true, to avoid log spam

func _ready() -> void:
	_a = _make_player()
	_b = _make_player()

func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.volume_db = linear_to_db(0.0001)
	add_child(p)
	return p

## Switch to `track_id` with a `fade` crossfade (seconds). Calling with the
## currently-playing track is a no-op so repeat-calls from menu _ready hooks
## don't restart the loop.
func play(track_id: StringName, fade: float = 0.6) -> void:
	if track_id == _current_track and _active != null and _active.playing:
		return
	var stream: AudioStream = _load_stream(track_id)
	if stream == null:
		return
	var from_player: AudioStreamPlayer = _active
	var to_player: AudioStreamPlayer = _b if _active == _a else _a
	to_player.stream = stream
	to_player.volume_db = linear_to_db(0.0001)
	to_player.play()
	_current_track = track_id
	_active = to_player
	_crossfade(from_player, to_player, fade)

## Fade to silence and stop. Clears the current-track memo so the next `play`
## restarts cleanly.
func stop(fade: float = 0.4) -> void:
	if _active == null:
		return
	var p := _active
	_active = null
	_current_track = &""
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(p, "volume_db", linear_to_db(0.0001), fade)
	_tween.tween_callback(p.stop)

func _crossfade(from_p: AudioStreamPlayer, to_p: AudioStreamPlayer, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	# Bus volume already handles user's music-volume slider, so here we fade
	# the player's own volume between silent and 0 dB.
	_tween.tween_property(to_p, "volume_db", 0.0, duration)
	if from_p != null and from_p.playing:
		_tween.tween_property(from_p, "volume_db", linear_to_db(0.0001), duration)
		_tween.chain().tween_callback(from_p.stop)

func _load_stream(track_id: StringName) -> AudioStream:
	for ext in SUPPORTED_EXTS:
		var path: String = "%s%s.%s" % [MUSIC_DIR, track_id, ext]
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			# Enable looping on formats that support it. Keeps menu/match
			# themes flowing without us needing to wire a finished signal.
			if s is AudioStreamOggVorbis:
				(s as AudioStreamOggVorbis).loop = true
			elif s is AudioStreamMP3:
				(s as AudioStreamMP3).loop = true
			return s
	if not _warned_missing.has(track_id):
		_warned_missing[track_id] = true
		print("[MusicPlayer] no file for track '%s' in %s (expected .ogg or .mp3)" % [track_id, MUSIC_DIR])
	return null
