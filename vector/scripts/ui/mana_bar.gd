class_name ManaBar
extends Control
## 10-pip mana bar, matching the handoff's "mana pip bar (10 pips, filled in
## yellow, glowing)". Shows a fractional pip for smoother regen feedback.

@export var pip_count: int = 10
@export var pip_gap: float = 2.0
@export var pip_color: Color = Color("fbbf24")
@export var dim_color: Color = Color(1, 1, 1, 0.12)

var _mana: float = 0.0
var _max: int = 10

func _ready() -> void:
	custom_minimum_size = Vector2(120.0, 8.0)
	queue_redraw()

func set_value(mana: float, mana_max: int) -> void:
	_mana = mana
	_max = max(1, mana_max)
	queue_redraw()

func _draw() -> void:
	var n := pip_count
	var total_gap: float = float(n - 1) * pip_gap
	var pip_w: float = (size.x - total_gap) / float(n)
	var pip_h := size.y
	for i in n:
		var x := i * (pip_w + pip_gap)
		var rect := Rect2(x, 0, pip_w, pip_h)
		var pip_value_low: float = float(i)          # pip considered lit at mana >= i+1
		var pip_value_high: float = float(i + 1)
		var fill_frac: float = clampf(_mana - pip_value_low, 0.0, 1.0)
		# Background pip
		draw_rect(rect, dim_color, true)
		if fill_frac > 0.0:
			var lit_rect := Rect2(x, 0, pip_w * fill_frac, pip_h)
			draw_rect(lit_rect, pip_color, true)
