extends Node

# UnitManager - Autoload for managing network IDs and unit references
# This is the central registry for all units in multiplayer games

var _next_unit_id := 0
var _units_by_id: Dictionary = {}  # {network_id: unit_node}

# Register a unit and assign it a unique network ID
# Only the server should call this
func register_unit(unit: Node) -> int:
	if not multiplayer.is_server():
		push_error("Only server can register units")
		return -1

	var id = _next_unit_id
	_next_unit_id += 1
	_units_by_id[id] = unit

	return id

# Get a unit by its network ID
func get_unit_by_id(id: int) -> Node:
	return _units_by_id.get(id)

# Remove a unit from the registry
func unregister_unit(id: int) -> void:
	_units_by_id.erase(id)

# Get the next available ID (for server)
func get_next_id() -> int:
	if not multiplayer.is_server():
		push_error("Only server can get next ID")
		return -1

	var id = _next_unit_id
	_next_unit_id += 1
	return id

# Register a unit with a specific ID (called by clients when receiving spawn RPC)
func register_unit_with_id(unit: Node, id: int) -> void:
	_units_by_id[id] = unit

# Clear all units (useful for cleanup on scene change)
func clear_units() -> void:
	_units_by_id.clear()
	_next_unit_id = 0

# Get all registered units
func get_all_units() -> Array:
	return _units_by_id.values()

# Debug: Print all registered units
func print_units() -> void:
	print("=== Unit Manager Debug ===")
	print("Next ID: %d" % _next_unit_id)
	print("Registered units: %d" % _units_by_id.size())
	for id in _units_by_id:
		var unit = _units_by_id[id]
		if is_instance_valid(unit):
			print("  ID %d: %s" % [id, unit.name])
		else:
			print("  ID %d: [INVALID]" % id)
