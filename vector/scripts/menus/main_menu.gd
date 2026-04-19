extends Control
## Tactical main menu shell. Hosts the header (identity / gold / XP), the 5-tab
## bar, the swappable tab content, and the persistent bottom dock. Modals
## (settings sheet, matchmaking queue) are parented to a dedicated ModalLayer
## so they always sit above tab content.

const SETTINGS_MODAL := preload("res://scenes/menus/settings_modal.tscn")
const QUEUE_OVERLAY := preload("res://scenes/menus/queue_overlay.tscn")
const MATCH_CONFIRM := preload("res://scenes/menus/match_confirm.tscn")
const LOADOUT_MODAL := preload("res://scenes/menus/loadout_modal.tscn")

## Per-tab scene/script map. Each value is a script; we instantiate it as a
## Control and add it to the Content panel when its tab becomes active.
const TAB_SCRIPTS := {
	&"home": preload("res://scripts/menus/tabs/home_tab.gd"),
	&"collection": preload("res://scripts/menus/tabs/collection_tab.gd"),
	&"deck": preload("res://scripts/menus/tabs/deck_tab.gd"),
	&"ladder": preload("res://scripts/menus/tabs/ladder_tab.gd"),
	&"shop": preload("res://scripts/menus/tabs/shop_tab.gd"),
}

@onready var header: TacticalHeader = %Header
@onready var tabbar_host: Control = %TabBarHost
@onready var content: PanelContainer = %Content
@onready var dock_host: Control = %BottomDockHost
@onready var modal_layer: Control = %ModalLayer

var _tabbar: TacticalTabBar
var _dock: TacticalBottomDock
var _current_tab: Control = null
var _active_id: StringName = &"home"

## Ordered list used by swipe cycling + _tabbar both. Keep in sync.
const TAB_ORDER: Array[StringName] = [&"home", &"collection", &"deck", &"ladder", &"shop"]

## Horizontal-swipe detection — swipes inside the content area cycle tabs.
var _swipe_start: Vector2 = Vector2.ZERO
var _swipe_tracking: bool = false
const SWIPE_THRESHOLD_PX: float = 80.0
const SWIPE_RATIO: float = 1.5  # |dx| must beat |dy| × ratio to count as horizontal

func _ready() -> void:
	MusicPlayer.play(&"menu")
	header.settings_pressed.connect(_open_settings)
	# Tab bar
	_tabbar = TacticalTabBar.new()
	_tabbar.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabbar_host.add_child(_tabbar)
	_tabbar.tab_selected.connect(_switch_tab)
	# Bottom dock
	_dock = TacticalBottomDock.new()
	_dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock_host.add_child(_dock)
	_dock.mode_selected.connect(_on_queue_requested)
	_dock.tutorial_pressed.connect(_on_tutorial)
	# Content panel styling — hard-edged surface, no radius.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Palette.UI_BG_0
	panel_style.border_width_top = 0
	panel_style.border_width_bottom = 0
	panel_style.border_width_left = 0
	panel_style.border_width_right = 0
	content.add_theme_stylebox_override("panel", panel_style)
	_switch_tab(_active_id)

## Global input hook for swipe gestures. Runs before _unhandled_input and
## doesn't consume events — taps still reach buttons normally, but we get to
## observe every touch/mouse press + release to measure swipe delta.
func _input(event: InputEvent) -> void:
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		pressed = mb.pressed
		pos = mb.position
	else:
		return
	# Only care about gestures that start inside the tab content area.
	if pressed:
		if content != null and content.get_global_rect().has_point(pos):
			_swipe_start = pos
			_swipe_tracking = true
		return
	if not _swipe_tracking:
		return
	_swipe_tracking = false
	var dx: float = pos.x - _swipe_start.x
	var dy: float = pos.y - _swipe_start.y
	if absf(dx) < SWIPE_THRESHOLD_PX:
		return
	if absf(dx) < absf(dy) * SWIPE_RATIO:
		return
	# Swipe right (dx > 0) → previous tab. Swipe left → next tab.
	_cycle_tab(-1 if dx > 0.0 else 1)

func _cycle_tab(direction: int) -> void:
	var idx: int = TAB_ORDER.find(_active_id)
	if idx < 0:
		return
	idx = wrapi(idx + direction, 0, TAB_ORDER.size())
	SfxBank.play_ui(&"ui_click")
	_switch_tab(TAB_ORDER[idx])

func _switch_tab(id: StringName) -> void:
	if _current_tab != null and _active_id == id:
		return
	_active_id = id
	# Fade the old tab out briefly, then drop it and fade the new tab in.
	# 120ms total — just enough to feel intentional, not enough to feel slow.
	var old: Control = _current_tab
	var script: Script = TAB_SCRIPTS.get(id)
	if script == null:
		return
	var tab: Control = script.new()
	tab.modulate = Color(1, 1, 1, 0)
	content.add_child(tab)
	_current_tab = tab
	_tabbar.select(id)
	var tw := create_tween()
	tw.tween_property(tab, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if old != null:
		old.modulate = Color(1, 1, 1, 1)
		var tw2 := create_tween()
		tw2.tween_property(old, "modulate:a", 0.0, 0.08)
		tw2.finished.connect(func(): old.queue_free())

func _open_settings() -> void:
	_spawn_modal(SETTINGS_MODAL.instantiate())

func _on_queue_requested(mode: StringName) -> void:
	# Insert the briefing confirmation between the bottom-dock tap and the
	# matchmaking radar. Player can CANCEL to back out or DEPLOY to queue up.
	var confirm: Control = MATCH_CONFIRM.instantiate()
	confirm.set("mode", mode)
	confirm.connect("confirmed", func(confirmed_mode: StringName):
		# Volley modes go through the Loadout modal first so the player can
		# swap gun modules. Classic modes skip straight to the queue radar.
		if confirmed_mode == &"volley" or confirmed_mode == &"volley_2v2":
			var resource_path: String = ("res://data/game_modes/solo_volley_2v2.tres"
				if confirmed_mode == &"volley_2v2"
				else "res://data/game_modes/solo_volley.tres")
			CurrentMatch.set_mode(load(resource_path) as GameMode)
			var loadout: Control = LOADOUT_MODAL.instantiate()
			loadout.set("target_scene", "res://scenes/match/volley/match_volley.tscn")
			loadout.connect("confirmed", func(scene: String):
				Router.goto(scene))
			_spawn_modal(loadout)
			return
		var q: Control = QUEUE_OVERLAY.instantiate()
		q.set("mode", confirmed_mode)
		_spawn_modal(q))
	_spawn_modal(confirm)

func _on_tutorial() -> void:
	CurrentMatch.set_mode(load("res://data/game_modes/tutorial.tres") as GameMode)
	Router.goto("res://scenes/match/match.tscn")

func _spawn_modal(m: Control) -> void:
	modal_layer.add_child(m)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
