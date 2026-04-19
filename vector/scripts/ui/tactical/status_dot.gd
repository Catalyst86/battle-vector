@tool
class_name StatusDot
extends Control
## 6×6 circular LED with a glowing halo. Used for online status, active-tab
## pulses, reward hints, row flags. Colors pulled from Palette tokens.

enum Mode { STATIC, BLINK, PULSE }

@export var color: Color = Color("4dffa8"):
	set(v): color = v; queue_redraw()
@export_range(3.0, 12.0, 0.5) var radius: float = 3.0:
	set(v): radius = v; queue_redraw()
@export var mode: Mode = Mode.STATIC
@export_range(0.2, 3.0, 0.05) var period: float = 1.0

var _t: float = 0.0
var _visible: bool = true

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0 + 4.0, radius * 2.0 + 4.0)
	set_process(mode != Mode.STATIC)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var alpha: float = 1.0
	var glow_intensity: float = 1.0
	match mode:
		Mode.BLINK:
			_visible = fposmod(_t, period) < period * 0.5
			alpha = 1.0 if _visible else 0.0
		Mode.PULSE:
			glow_intensity = 0.5 + 0.5 * (0.5 + 0.5 * sin(_t * TAU / period))
	if alpha <= 0.0:
		return
	var c := color
	c.a *= alpha
	var center := size * 0.5
	# Halo
	var halo := c
	halo.a *= 0.35 * glow_intensity
	draw_circle(center, radius * 2.0, halo)
	# Core
	draw_circle(center, radius, c)
