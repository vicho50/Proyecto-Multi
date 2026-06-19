class_name Statics
extends Node


const MAX_CLIENTS = 3
const PORT = 5409 # Number between 1024 and 65535.


enum Role {
	NONE,
	ROMANS,
	GERMANS,
}


# Tipos de unidad disponibles en la partida (independiente del equipo del jugador)
enum UnitType {
	HEAVY,
	WARRIOR,
	ARCHER,
	MINER,
}


static func get_role_name(role: Role) -> String:
	match role:
		Role.NONE:
			return "Sin facción"
		Role.ROMANS:
			return "Romanos"
		Role.GERMANS:
			return "Germanos"
	return "Unknown"


# Convierte la facción elegida en el lobby al team_id (0 azul / Romanos, 1 rojo / Germanos).
static func role_to_team_id(role: Role) -> int:
	match role:
		Role.ROMANS:
			return 0
		Role.GERMANS:
			return 1
	return 0


class PlayerData:
	var id: int
	var name: String
	# Position relative to other players
	var index: int = -1
	var role: Role
	var vote: bool = false
	
	func _init(new_id: int, new_name: String, new_index: int = -1, new_role: Role = Role.NONE) -> void:
		id = new_id
		name = new_name
		index = new_index
		role = new_role
	
	func _to_string() -> String:
		return "Player: {id: %d, name: %s, index: %d, role: %d}" % [id, name, index, Statics.get_role_name(role)]
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"index": index,
			"role": role,
			"vote": vote
		}
	
	static func from_dict(data: Dictionary) -> PlayerData:
		var player = PlayerData.new(data.id, data.name, data.index, data.role)
		player.vote = data.vote
		return player
	
	func update(player_data: PlayerData) -> void:
		if id != player_data.id:
			return
		name = player_data.name
		index = player_data.index
		role = player_data.role
		vote = player_data.vote
