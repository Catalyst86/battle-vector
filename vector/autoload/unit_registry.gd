extends Node
## Fast per-team unit lookup. Units register on _ready, unregister on _exit_tree.
## Consumers read the arrays directly instead of calling get_nodes_in_group()
## each frame, which would allocate a new Array on every call.
##
## Queries take a `bool is_enemy` rather than a node so non-Unit callers
## (projectiles — which use `owner_enemy` — and future team-scoped tools)
## don't need a matching `is_enemy` property. Arrays stay untyped so the
## autoload doesn't pull in the Unit class_name.

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

## Opposing team from the caller's perspective. Pass the caller's own
## enemy-flag (Unit.is_enemy or Projectile.owner_enemy).
func enemies_of(is_enemy: bool) -> Array:
	return player_team if is_enemy else enemy_team

## Same team as the caller. Includes the caller itself — skip self at the
## caller site.
func allies_of(is_enemy: bool) -> Array:
	return enemy_team if is_enemy else player_team

## Friendly BUFFER-role units, used by _refresh_effective_damage.
func buffers_for(is_enemy: bool) -> Array:
	return enemy_buffers if is_enemy else player_buffers

## Nuke all four lists. Called by match.gd on _ready as a safety net in case
## a previous match left stale references (normally _exit_tree handles this).
func clear() -> void:
	player_team.clear()
	enemy_team.clear()
	player_buffers.clear()
	enemy_buffers.clear()
