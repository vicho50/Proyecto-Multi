extends Node

# SpawnController - Manages unit spawning with RPC synchronization
# This script should be added to the main game scene

const UNIT_SCENES = {
	"roman_warrior": preload("res://Scenes/roman_warrior.tscn"),
	"roman_heavy": preload("res://Scenes/roman_heavy.tscn")
}

# Spawn positions for each team
@export var team_0_spawn_position: Vector3 = Vector3(-10, 0, 0)
@export var team_1_spawn_position: Vector3 = Vector3(10, 0, 0)

# RPC: Client requests to spawn a unit
# Server validates and broadcasts spawn to all clients
@rpc("any_peer", "reliable")
func request_spawn_unit(unit_type: String, team_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id = multiplayer.get_remote_sender_id()

	# Validate unit type exists
	if not unit_type in UNIT_SCENES:
		push_error("Invalid unit type: %s" % unit_type)
		return

	# TODO: Add resource/economy validation here when Phase 3 is implemented
	# if not can_afford_unit(sender_id, unit_type):
	#     notify_spawn_failed.rpc_id(sender_id, "Not enough resources")
	#     return

	# Generate network ID for the unit
	var network_id = UnitManager.get_next_id()

	# Get spawn position based on team
	var spawn_pos = get_spawn_position(team_id)

	# Broadcast spawn to all clients (including caller)
	spawn_unit_at.rpc(unit_type, spawn_pos, team_id, network_id)

# RPC: Server tells all clients to spawn a unit at a specific location
@rpc("authority", "call_local", "reliable")
func spawn_unit_at(unit_type: String, position: Vector3, team_id: int, network_id: int) -> void:
	if not unit_type in UNIT_SCENES:
		push_error("Invalid unit type: %s" % unit_type)
		return

	# Instantiate the unit
	var unit_scene = UNIT_SCENES[unit_type]
	var unit = unit_scene.instantiate()

	# Set network properties
	unit.network_id = network_id
	unit.team_id = team_id
	unit.global_position = position

	# Add to scene
	add_child(unit)

	# Debug output
	if OS.is_debug_build():
		print("[SpawnController] Spawned %s (ID: %d) for team %d at %v" % [unit_type, network_id, team_id, position])

# Helper: Get spawn position for a team
func get_spawn_position(team_id: int) -> Vector3:
	if team_id == 0:
		return team_0_spawn_position
	else:
		return team_1_spawn_position

# Helper: Add some randomization to spawn position to avoid overlap
func get_spawn_position_with_offset(team_id: int, offset_range: float = 1.0) -> Vector3:
	var base_pos = get_spawn_position(team_id)
	var random_offset = Vector3(
		randf_range(-offset_range, offset_range),
		0,
		randf_range(-offset_range, offset_range)
	)
	return base_pos + random_offset

# Example usage: Call this from UI button or input handler
# spawn_controller.request_spawn_unit.rpc("roman_warrior", my_team_id)
