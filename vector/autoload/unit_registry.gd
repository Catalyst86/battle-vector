extends Node
## Fast per-team unit lookup. Units register on _ready, unregister on _exit_tree.
## Consumers read the arrays directly instead of calling get_nodes_in_group()
## each frame, which would allocate a new Array on every call.
##
## Arrays are intentionally untyped to avoid a hard Unit/UnitRegistry circular
## type dependency. Callers duck-type on .card / .world_pos / .is_enemy.

var player_team: Array = []
var enemy_team: Array = []
var player_buffers: Array = []
var enemy_buffers: Array = []

func register(u: Node) -> void:
	var team: Array = enemy_team if u.is_enemy else player_team
	if not team.has(u):
		team.append(u)
	if u.card != null and u.card.role == CardData.Role.BUFFER:
		var buffers: Array = enemy_buffers if u.is_enemy else player_buffers
		if not buffers.has(u):
			buffers.append(u)

func unregister(u: Node) -> void:
	player_team.erase(u)
	enemy_team.erase(u)
	player_buffers.erase(u)
	enemy_buffers.erase(u)

## Opposing team from `u`'s perspective.
func enemies_of(u: Node) -> Array:
	return player_team if u.is_enemy else enemy_team

## Same team as `u`. Includes `u` — callers skip self themselves.
func allies_of(u: Node) -> Array:
	return enemy_team if u.is_enemy else player_team

## Friendly BUFFER-role units, used by _refresh_effective_damage.
func buffers_for(u: Node) -> Array:
	return enemy_buffers if u.is_enemy else player_buffers

## Nuke all four lists. Called by match.gd on _ready as a safety net in case
## a previous match left stale references (normally _exit_tree handles this).
func clear() -> void:
	player_team.clear()
	enemy_team.clear()
	player_buffers.clear()
	enemy_buffers.clear()
