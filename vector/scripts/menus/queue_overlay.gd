extends Control
## Matchmaking queue overlay. Radar animation + status log + abort button.
## After a short fake-matchmaking wait (2.5s) it routes into the actual match
## scene. Mode is set via the `mode` property on instantiation.

var mode: StringName = &"1v1"

var _timer_sec: float = 0.0
var _scanning_dots: int = 0
var _elapsed_lbl: Label
var _dots_lbl: Label
var _radar: Control
var _canceled: bool = false

const MATCH_DELAY: float = 2.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var grid := GridBg.new()
	grid.color = Color(0.47, 0.588, 0.706, 0.08)
	add_child(grid)
	var scan := Scanlines.new()
	add_child(scan)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_theme_constant_override("separation", 20)
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 24; outer.offset_right = -24; outer.offset_top = 24; outer.offset_bottom = -24
	add_child(outer)

	outer.add_child(_centered(TabHelpers.label("▸ MATCHMAKING %s" % String(mode).to_upper(), 10, Palette.UI_TEXT_3)))
	# Radar
	_radar = Control.new()
	_radar.custom_minimum_size = Vector2(220, 220)
	_radar.draw.connect(_draw_radar)
	_radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(_centered(_radar))
	# Scanning label
	_dots_lbl = TabHelpers.label("SCANNING", 24, Palette.UI_CYAN)
	_dots_lbl.add_theme_font_override("font", Palette.FONT_DISPLAY_BOLD)
	outer.add_child(_centered(_dots_lbl))
	# Elapsed
	_elapsed_lbl = TabHelpers.mono("ELAPSED ▸ 00:00", 11, Palette.UI_TEXT_2)
	outer.add_child(_centered(_elapsed_lbl))
	# Status log
	var log := VBoxContainer.new()
	log.add_theme_constant_override("separation", 2)
	log.custom_minimum_size = Vector2(260, 0)
	outer.add_child(_centered(log))
	log.add_child(TabHelpers.mono("> handshake.sec  OK", 10, Palette.UI_GREEN))
	log.add_child(TabHelpers.mono("> region NA-WEST  200ms", 10, Palette.UI_GREEN))
	log.add_child(TabHelpers.mono("> pool.size  12 ops", 10, Palette.UI_AMBER))
	log.add_child(TabHelpers.mono("> seeking.match_", 10, Palette.UI_CYAN))
	# Abort
	var abort: Button = TabHelpers.ghost_button("ABORT", func(): _cancel(), Palette.UI_RED)
	abort.add_theme_color_override("font_color", Palette.UI_RED)
	abort.custom_minimum_size = Vector2(200, 44)
	outer.add_child(_centered(abort))

	set_process(true)

func _cancel() -> void:
	if _canceled:
		return
	_canceled = true
	SfxBank.play_ui(&"ui_back")
	queue_free()

func _process(delta: float) -> void:
	if _canceled:
		return
	_timer_sec += delta
	var secs: int = int(_timer_sec)
	_elapsed_lbl.text = "ELAPSED ▸ %02d:%02d" % [secs / 60, secs % 60]
	_scanning_dots = int(_timer_sec * 2.5) % 4
	_dots_lbl.text = "SCANNING" + ".".repeat(_scanning_dots)
	_radar.queue_redraw()
	if _timer_sec >= MATCH_DELAY:
		_launch_match()

func _launch_match() -> void:
	_canceled = true
	var mode_path: String = "res://data/game_modes/solo_%s.tres" % String(mode)
	var gm: GameMode = load(mode_path) as GameMode
	if gm != null:
		CurrentMatch.set_mode(gm)
	Router.goto("res://scenes/match/match.tscn")

func _draw_radar() -> void:
	var center := Vector2(110, 110)
	# Three concentric rings
	for i in 3:
		var r: float = 30.0 + float(i) * 40.0
		var c: Color = Palette.UI_CYAN
		c.a = 0.35 - float(i) * 0.08
		_radar.draw_arc(center, r, 0.0, TAU, 64, c, 1.0, true)
	# Sweep line
	var sweep_angle: float = _timer_sec * 2.0
	var tip := center + Vector2(cos(sweep_angle), sin(sweep_angle)) * 100.0
	_radar.draw_line(center, tip, Palette.UI_CYAN, 1.5, true)
	# Cone sweep — approximate gradient via stacked semi-transparent lines
	for i in 20:
		var a: float = sweep_angle - float(i) * 0.04
		var alpha: float = 0.25 - float(i) * 0.012
		if alpha <= 0.0:
			break
		var t: Vector2 = center + Vector2(cos(a), sin(a)) * 100.0
		var c := Palette.UI_CYAN
		c.a = alpha
		_radar.draw_line(center, t, c, 1.0, true)
	# Center glyph — simple dart
	ShapeRenderer.draw_with_glow(_radar, CardData.Shape.TRIANGLE, Palette.UI_CYAN, 18.0, sweep_angle * 0.4)

func _centered(c: Control) -> Control:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(c)
	return hb
