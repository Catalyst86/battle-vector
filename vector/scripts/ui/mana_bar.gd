class_name ManaBar
extends Control
## 10-pip mana bar. Shows a fractional pip for smoother regen feedback.
## Pulses every pip gently when mana is full so the player notices and
## spends it — subtle "use it or lose it" hint without nagging audio.

@export var pip_count: int = 10
@export var pip_gap: float = 2.0
@export var pip_color: Color = Color("fbbf24")
@export var dim_color: Color = Color(1, 1, 1, 0.12)

## Displayed mana value — lerps toward `_target_mana` each frame so deploys
## read as a smooth drain rather than a snap. Callers still push the real
## value via `set_value`.
var _mana: float = 0.0
var _target_mana: float = 0.0
var _max: int = 10
var _pulse_t: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(120.0, 8.0)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	# Smooth the displayed value toward the target. Fast enough (8/sec) that
	# a 2-cost deploy reads as a ~0.25s drain, slow enough to feel animated.
	if absf(_mana - _target_mana) > 0.01:
		_mana = move_toward(_mana, _target_mana, delta * 8.0)
		queue_redraw()
	if _mana >= float(_max) - 0.01:
		_pulse_t += delta
		queue_redraw()
	elif _pulse_t != 0.0:
		_pulse_t = 0.0
		queue_redraw()

func set_value(mana: float, mana_max: int) -> void:
	_target_mana = mana
	_max = max(1, mana_max)

func _draw() -> void:
	var n := pip_count
	var total_gap: float = float(n - 1) * pip_gap
	var pip_w: float = (size.x - total_gap) / float(n)
	var pip_h := size.y
	# When full, every pip brightens in sync via a sine pulse. Amplitude is
	# subtle — 30% alpha shift — so it's noticeable without being annoying.
	var full: bool = _mana >= float(_max) - 0.01
	var pulse_amp: float = 0.0
	if full:
		pulse_amp = 0.5 + 0.5 * sin(_pulse_t * TAU / 1.1)
	for i in n:
		var x := i * (pip_w + pip_gap)
		var rect := Rect2(x, 0, pip_w, pip_h)
		var pip_value_low: float = float(i)
		var fill_frac: float = clampf(_mana - pip_value_low, 0.0, 1.0)
		draw_rect(rect, dim_color, true)
		if fill_frac > 0.0:
			var lit := pip_color
			if full:
				# Brighten + add a thin halo.
				lit = lit.lightened(0.15 * pulse_amp)
				var halo := pip_color
				halo.a = 0.35 * pulse_amp
				draw_rect(Rect2(x - 1, -1, pip_w + 2, pip_h + 2), halo, false, 1.0)
			draw_rect(Rect2(x, 0, pip_w * fill_frac, pip_h), lit, true)
