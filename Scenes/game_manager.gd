extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

const UNITS_PER_PLAYER := 3
const UNIT_SPAWN_Z_SPACING := 1.5

# X positions for each team's spawn zone (team 0 on left, team 1 on right)
const TEAM_SPAWN_X := {0: -8.0, 1: 8.0}
const TEAM_ADVANCE_DIR := {0: Vector3.RIGHT, 1: Vector3.LEFT}

var UNIT_SCENES = {
	Statics.Role.ROLE_A: preload("res://Scenes/roman_heavy.tscn"),
	Statics.Role.ROLE_B: preload("res://Scenes/roman_warrior.tscn")
}

func _ready():
	if multiplayer.is_server():
		_spawns_units_for_all_players()

func _spawns_units_for_all_players():
	for player in Game.players:
		var scene = UNIT_SCENES.get(player.role, UNIT_SCENES[Statics.Role.ROLE_A])
		var spawn_x: float = TEAM_SPAWN_X.get(player.index, 0.0)
		var advance_dir: Vector3 = TEAM_ADVANCE_DIR.get(player.index, Vector3.RIGHT)

		for i in range(UNITS_PER_PLAYER):
			var unit = scene.instantiate()
			unit.name = "Unit_%d_%d" % [player.id, i]
			unit.team_id = player.index
			unit.advance_direction = advance_dir
			unit.set_multiplayer_authority(player.id)
			# Spread units along the z-axis centered around 0
			var z_offset: float = (i - (UNITS_PER_PLAYER - 1) / 2.0) * UNIT_SPAWN_Z_SPACING
			unit.position = Vector3(spawn_x, 0.0, z_offset)
			add_child(unit, true)

