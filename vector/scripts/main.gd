extends Node
## Boot scene. Kept minimal so you can hang future startup work here
## (loading splash, audio init, save-file load, etc.) without touching menus.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"

func _ready() -> void:
	Router.goto(MAIN_MENU)
