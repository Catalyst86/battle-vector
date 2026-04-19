extends Control
## Settings menu. Music + SFX volume sliders and a mute toggle. All values
## route through PlayerProfile which persists them and re-applies on boot.

@onready var back_btn: Button = %BackButton
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var mute_btn: CheckButton = %MuteButton

func _ready() -> void:
	back_btn.pressed.connect(_on_back)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_btn.toggled.connect(_on_mute_toggled)
	_sync_from_profile()

func _sync_from_profile() -> void:
	var d := PlayerProfile.data
	music_slider.set_value_no_signal(d.music_volume)
	sfx_slider.set_value_no_signal(d.sfx_volume)
	mute_btn.set_pressed_no_signal(d.audio_muted)
	music_value.text = "%d%%" % int(round(d.music_volume * 100.0))
	sfx_value.text = "%d%%" % int(round(d.sfx_volume * 100.0))

func _on_music_changed(v: float) -> void:
	PlayerProfile.set_music_volume(v)
	music_value.text = "%d%%" % int(round(v * 100.0))

func _on_sfx_changed(v: float) -> void:
	PlayerProfile.set_sfx_volume(v)
	sfx_value.text = "%d%%" % int(round(v * 100.0))
	# Play a sample tick so the user hears the new level immediately.
	SfxBank.play(&"ui_click")

func _on_mute_toggled(b: bool) -> void:
	PlayerProfile.set_audio_muted(b)

func _on_back() -> void:
	SfxBank.play_ui(&"ui_back")
	Router.goto("res://scenes/menus/main_menu.tscn")
