extends Node
## Procedural SFX bank. All effects are synthesized at boot into in-memory
## AudioStreamWAV resources — no audio files on disk. Keeps the binary small,
## matches the vector aesthetic, and survives mobile export with zero
## asset-pipeline work.
##
## Usage:
##   SfxBank.play(&"ui_click")                # fire-and-forget by id
##   SfxBank.play_event(card, &"shoot")       # card-aware, falls back to
##                                            # a role-appropriate default
##
## Cards can override any event by setting the matching StringName field on
## their CardData resource (sfx_deploy / sfx_shoot / sfx_death / sfx_hit). An
## empty override routes back through the role defaults below.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 16

enum Wave { SINE, SQUARE, SAW, TRIANGLE, NOISE }

var _bank: Dictionary = {}                # StringName -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _next_idx: int = 0
var _next_ui_idx: int = 0

func _ready() -> void:
	_build_players()
	_build_bank()

func _build_players() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	# Smaller UI pool — UI clicks rarely overlap more than 2-deep.
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = &"UI"
		add_child(p)
		_ui_players.append(p)

## Fire a named SFX. `pitch_variation` randomises pitch ±v around 1.0 so
## repeated plays don't sound like a single tone being looped.
func play(id: StringName, pitch_variation: float = 0.04, volume_db: float = 0.0) -> void:
	if id == &"":
		return
	var stream: AudioStreamWAV = _bank.get(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pick_player(false)
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = volume_db
	p.play()

## UI-bus variant — routed through the UI send so its volume can be tuned
## independently of gameplay SFX in the future.
func play_ui(id: StringName, pitch_variation: float = 0.02) -> void:
	if id == &"":
		return
	var stream: AudioStreamWAV = _bank.get(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _pick_player(true)
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.volume_db = 0.0
	p.play()

## Resolves a card's per-event SFX override, falling back to a role default,
## then plays it. `event` must be one of: &"deploy", &"shoot", &"death", &"hit".
func play_event(card: CardData, event: StringName) -> void:
	if card == null:
		return
	var id: StringName = _card_override(card, event)
	if id == &"":
		id = _default_for(card, event)
	if id != &"":
		play(id)

func _card_override(card: CardData, event: StringName) -> StringName:
	match event:
		&"deploy": return card.sfx_deploy
		&"shoot": return card.sfx_shoot
		&"death": return card.sfx_death
		&"hit": return card.sfx_hit
	return &""

func _default_for(card: CardData, event: StringName) -> StringName:
	match event:
		&"deploy":
			return &"deploy"
		&"shoot":
			match card.role:
				CardData.Role.SHOOTER, CardData.Role.INTERCEPTOR: return &"shoot_small"
				CardData.Role.WALLBREAK: return &"shoot_heavy"
				CardData.Role.SNIPER: return &"shoot_beam"
			return &""
		&"death":
			if card.size >= 20.0 or card.role == CardData.Role.WALLBREAK or card.role == CardData.Role.SNIPER:
				return &"death_heavy"
			return &"death_small"
		&"hit":
			if card.size >= 20.0:
				return &"hit_heavy"
			return &"hit_light"
	return &""

func _pick_player(ui: bool) -> AudioStreamPlayer:
	var pool: Array[AudioStreamPlayer] = _ui_players if ui else _players
	# Prefer a free player; if all busy, round-robin overwrite.
	for p in pool:
		if not p.playing:
			return p
	if ui:
		_next_ui_idx = (_next_ui_idx + 1) % pool.size()
		return pool[_next_ui_idx]
	_next_idx = (_next_idx + 1) % pool.size()
	return pool[_next_idx]

# --- Synthesis --------------------------------------------------------------

func _build_bank() -> void:
	# UI — short, bright, minimal envelope.
	_bank[&"ui_click"] = _synth(Wave.SQUARE, 900.0, 1100.0, 0.045, 0.22)
	_bank[&"ui_back"] = _synth(Wave.SQUARE, 620.0, 420.0, 0.06, 0.22)
	_bank[&"ui_confirm"] = _synth_multi([
		[Wave.TRIANGLE, 520.0, 520.0, 0.05, 0.28, 0.0],
		[Wave.TRIANGLE, 780.0, 780.0, 0.08, 0.3, 0.0],
	])

	# Deploy — short rising chirp; reads as "something arrived."
	_bank[&"deploy"] = _synth(Wave.SAW, 180.0, 540.0, 0.10, 0.28)

	# Shoot variants — tone scales with projectile heft.
	_bank[&"shoot_small"] = _synth(Wave.SQUARE, 1250.0, 720.0, 0.055, 0.18)
	_bank[&"shoot_heavy"] = _synth(Wave.SINE, 200.0, 95.0, 0.14, 0.42, 0.18)
	_bank[&"shoot_beam"] = _synth(Wave.SAW, 650.0, 660.0, 0.18, 0.22)

	# Hits.
	_bank[&"hit_light"] = _synth(Wave.NOISE, 0.0, 0.0, 0.035, 0.22)
	_bank[&"hit_heavy"] = _synth_multi([
		[Wave.NOISE, 0.0, 0.0, 0.09, 0.38, 1.0],
		[Wave.SINE, 90.0, 60.0, 0.09, 0.35, 0.0],
	], true)  # mixed = overlay instead of concat

	# Deaths.
	_bank[&"death_small"] = _synth(Wave.SQUARE, 320.0, 85.0, 0.16, 0.3)
	_bank[&"death_heavy"] = _synth_multi([
		[Wave.NOISE, 0.0, 0.0, 0.24, 0.5, 1.0],
		[Wave.SINE, 65.0, 40.0, 0.24, 0.42, 0.0],
	], true)

	# Walls.
	_bank[&"wall_place"] = _synth(Wave.TRIANGLE, 220.0, 160.0, 0.09, 0.35, 0.25)
	_bank[&"wall_break"] = _synth_multi([
		[Wave.NOISE, 0.0, 0.0, 0.18, 0.48, 1.0],
		[Wave.SINE, 130.0, 70.0, 0.18, 0.35, 0.0],
	], true)

	# Base + match events.
	_bank[&"base_damage"] = _synth_multi([
		[Wave.NOISE, 0.0, 0.0, 0.2, 0.35, 1.0],
		[Wave.SINE, 150.0, 60.0, 0.2, 0.5, 0.0],
	], true)
	_bank[&"match_start"] = _synth_multi([
		[Wave.TRIANGLE, 420.0, 420.0, 0.1, 0.3, 0.0],
		[Wave.TRIANGLE, 560.0, 560.0, 0.1, 0.3, 0.0],
		[Wave.TRIANGLE, 840.0, 840.0, 0.14, 0.34, 0.0],
	])
	_bank[&"victory"] = _synth_multi([
		[Wave.TRIANGLE, 523.0, 523.0, 0.11, 0.36, 0.0],
		[Wave.TRIANGLE, 659.0, 659.0, 0.11, 0.36, 0.0],
		[Wave.TRIANGLE, 784.0, 784.0, 0.11, 0.36, 0.0],
		[Wave.TRIANGLE, 1047.0, 1047.0, 0.22, 0.42, 0.0],
	])
	_bank[&"defeat"] = _synth_multi([
		[Wave.SINE, 440.0, 440.0, 0.14, 0.35, 0.0],
		[Wave.SINE, 330.0, 330.0, 0.14, 0.35, 0.0],
		[Wave.SINE, 220.0, 180.0, 0.32, 0.38, 0.1],
	])
	_bank[&"draw"] = _synth_multi([
		[Wave.TRIANGLE, 500.0, 500.0, 0.14, 0.3, 0.0],
		[Wave.TRIANGLE, 460.0, 420.0, 0.22, 0.32, 0.0],
	])

## Render a single tone / noise burst with a short attack + linear decay
## envelope. `noise_mix` in [0,1] blends white noise over the waveform.
func _synth(shape: int, freq_start: float, freq_end: float, duration: float, amp: float, noise_mix: float = 0.0) -> AudioStreamWAV:
	var n: int = maxi(1, int(SAMPLE_RATE * duration))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(n)
	var phase: float = 0.0
	var attack_n: int = mini(int(SAMPLE_RATE * 0.004), n / 6)
	for i in n:
		var t_frac: float = float(i) / float(maxi(1, n - 1))
		var freq: float = lerpf(freq_start, freq_end, t_frac)
		phase += TAU * freq / float(SAMPLE_RATE)
		if phase > TAU:
			phase -= TAU
		var sample: float = _wave(shape, phase)
		if noise_mix > 0.0:
			sample = lerpf(sample, randf() * 2.0 - 1.0, noise_mix)
		var env: float
		if i < attack_n:
			env = float(i) / float(maxi(1, attack_n))
		else:
			env = 1.0 - float(i - attack_n) / float(maxi(1, n - attack_n))
		samples[i] = sample * amp * env
	return _pack(samples)

## `segments` is either concatenated (default) or overlaid (mixed=true).
## Each segment: [shape, freq_start, freq_end, duration, amp, noise_mix].
func _synth_multi(segments: Array, mixed: bool = false) -> AudioStreamWAV:
	if mixed:
		return _synth_mixed(segments)
	return _synth_concat(segments)

func _synth_concat(segments: Array) -> AudioStreamWAV:
	var total: PackedFloat32Array = PackedFloat32Array()
	for seg in segments:
		var stream: AudioStreamWAV = _synth(seg[0], seg[1], seg[2], seg[3], seg[4], seg[5])
		var floats: PackedFloat32Array = _unpack(stream)
		total.append_array(floats)
	return _pack(total)

func _synth_mixed(segments: Array) -> AudioStreamWAV:
	var max_n: int = 0
	var parts: Array[PackedFloat32Array] = []
	for seg in segments:
		var stream: AudioStreamWAV = _synth(seg[0], seg[1], seg[2], seg[3], seg[4], seg[5])
		var floats: PackedFloat32Array = _unpack(stream)
		parts.append(floats)
		max_n = maxi(max_n, floats.size())
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(max_n)
	for part in parts:
		for i in part.size():
			out[i] += part[i]
	# Soft-clip in case mixed amplitude exceeds ±1.
	for i in out.size():
		out[i] = clampf(out[i], -1.0, 1.0)
	return _pack(out)

func _wave(shape: int, phase: float) -> float:
	match shape:
		Wave.SINE:
			return sin(phase)
		Wave.SQUARE:
			return 1.0 if phase < PI else -1.0
		Wave.SAW:
			return 2.0 * (phase / TAU) - 1.0
		Wave.TRIANGLE:
			var f: float = phase / TAU
			return 4.0 * abs(f - 0.5) - 1.0
		Wave.NOISE:
			return randf() * 2.0 - 1.0
	return 0.0

func _pack(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: float = clampf(samples[i], -1.0, 1.0)
		var s16: int = int(s * 32760.0)
		var u16: int = s16 & 0xffff
		bytes[i * 2] = u16 & 0xff
		bytes[i * 2 + 1] = (u16 >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream

func _unpack(stream: AudioStreamWAV) -> PackedFloat32Array:
	var bytes: PackedByteArray = stream.data
	var n: int = bytes.size() / 2
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	for i in n:
		var lo: int = bytes[i * 2]
		var hi: int = bytes[i * 2 + 1]
		var u16: int = (hi << 8) | lo
		if u16 >= 0x8000:
			u16 -= 0x10000
		out[i] = float(u16) / 32760.0
	return out
