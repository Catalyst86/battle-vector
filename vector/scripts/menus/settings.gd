extends Control
## Settings — placeholder. Live tweakers (sound, particle density, aesthetic)
## will land here. They read/write GameConfig.data fields via the inspector-
## editable resource, so every knob already exists in data/config/game_config.tres.

@onready var back_btn: Button = %BackButton

func _ready() -> void:
	back_btn.pressed.connect(func(): Router.goto("res://scenes/menus/main_menu.tscn"))
