extends Node
## Lightweight scene router. Menus and the match never load each other
## directly — they call `Router.goto("res://scenes/...")` and this handles
## the fade + swap. Add new menus without touching existing ones.

signal scene_changed(path: String)

@export var fade_color: Color = Color(0, 0, 0)
@export var fade_duration: float = 0.22

var _fade: ColorRect
var _canvas: CanvasLayer
var _busy: bool = false

func _ready() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 128
	add_child(_canvas)
	_fade = ColorRect.new()
	_fade.color = fade_color
	_fade.color.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_canvas.add_child(_fade)

func goto(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Router.goto failed: %s (err %d)" % [path, err])
	scene_changed.emit(path)
	await _fade_to(0.0)
	_busy = false

func _fade_to(target_alpha: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_alpha, fade_duration)
	await tw.finished
