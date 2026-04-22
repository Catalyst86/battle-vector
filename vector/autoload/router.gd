extends Node
## Lightweight scene router. Menus and the match never load each other
## directly — they call `Router.goto("res://scenes/...")` and this swaps
## the scene. Instant by design; the previous fade-in/out was removed
## because it made every menu hop feel slower than it was.

signal scene_changed(path: String)

var _busy: bool = false

## Swap to the scene at `path`. Yields one frame before firing so the
## caller's _ready / signal handler can unwind — change_scene_to_file
## refuses if a parent node is still adding children, and Router.goto is
## commonly invoked from exactly those callsites (main boot, back-button
## handlers). The `_busy` guard swallows rapid double-taps.
func goto(path: String) -> void:
	if _busy:
		return
	_busy = true
	await get_tree().process_frame
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Router.goto failed: %s (err %d)" % [path, err])
	scene_changed.emit(path)
	_busy = false
