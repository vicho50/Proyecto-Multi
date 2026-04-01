extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

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
		var unit = scene.instantiate()
		unit.name = "Unit_%d" % player.id
		unit.team_id = player.index
		unit.set_multiplayer_authority(player.id)
		add_child(unit, true)
		
