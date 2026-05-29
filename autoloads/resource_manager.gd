extends Node

signal gold_changed(team_id, new_amount)

@export var starting_gold: int = 100

var gold := {}

func _ready() -> void:
	# Initialize common team ids if running as server. You can call init_team manually as needed.
	if multiplayer.is_server():
		gold[0] = starting_gold
		gold[1] = starting_gold

# Initialize or overwrite a team's gold amount (server-only)
func init_team(team_id: int, amount: int = -1) -> void:
	if amount == -1:
		amount = starting_gold
	gold[team_id] = amount
	emit_signal("gold_changed", team_id, amount)
	# sync to clients
	if multiplayer.is_server():
		rpc("client_sync_gold", team_id, amount)

# Return current gold for a team (local view)
func get_gold(team_id: int) -> int:
	if gold.has(team_id):
		return gold[team_id]
	return 0

# Server authoritative: add gold to a team and sync
func add_gold(team_id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	if not gold.has(team_id):
		gold[team_id] = 0
	gold[team_id] += amount
	emit_signal("gold_changed", team_id, gold[team_id])
	rpc("client_sync_gold", team_id, gold[team_id])

# Server authoritative: attempt to spend gold, returns true if successful
func spend_gold(team_id: int, amount: int) -> bool:
	if not multiplayer.is_server():
		return false
	if not gold.has(team_id):
		gold[team_id] = 0
	if gold[team_id] >= amount:
		gold[team_id] -= amount
		emit_signal("gold_changed", team_id, gold[team_id])
		rpc("client_sync_gold", team_id, gold[team_id])
		return true
	return false

# Convenience check
func can_afford(team_id: int, amount: int) -> bool:
	return get_gold(team_id) >= amount

# Client RPC called from server to keep local state in sync
@rpc("any_peer", "call_local", "reliable")
func client_sync_gold(team_id: int, new_amount: int) -> void:
	gold[team_id] = new_amount
	emit_signal("gold_changed", team_id, new_amount)
