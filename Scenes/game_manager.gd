extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var UNIT_SCENES = {
	Statics.Role.ROLE_A: preload("res://Scenes/roman_heavy.tscn"),
	Statics.Role.ROLE_B: preload("res://Scenes/roman_warrior.tscn"),
	Statics.Role.ROLE_C: preload("res://Scenes/roman_archer.tscn")
}

@export var min_initial_units_per_team: int = 3
@export var max_initial_units_per_team: int = 6
@export var unit_spacing_z: float = 1.4
@export var team_0_spawn_position: Vector3 = Vector3(-9.0, 0.0, 0.3)
@export var team_1_spawn_position: Vector3 = Vector3(8.3, 0.0, 0.3)

var _initial_spawn_done := false

var SPAWN_DIRECTIONS = [
	Vector3.RIGHT,              # Team 0 advances right
	Vector3.LEFT,               # Team 1 advances left
]

func _ready():
	spawner.spawn_function = _custom_spawn
	if multiplayer.is_server():
		# Wait for all peers to be ready
		await get_tree().create_timer(0.5).timeout
		_spawn_initial_symmetric_wave()

func _spawn_initial_symmetric_wave() -> void:
	if _initial_spawn_done:
		return
	_initial_spawn_done = true

	var min_units := mini(min_initial_units_per_team, max_initial_units_per_team)
	var max_units := maxi(min_initial_units_per_team, max_initial_units_per_team)
	var units_per_team := randi_range(min_units, max_units)

	for slot in units_per_team:
		var random_role := _get_random_spawn_role()
		for team_id in SPAWN_DIRECTIONS.size():
			var data = {
				"id": (team_id * 1000) + slot,
				"team_id": team_id,
				"slot": slot,
				"units_per_team": units_per_team,
				"role": random_role,
			}
			spawner.spawn(data)

func _get_random_spawn_role() -> Statics.Role:
	var available_roles: Array = UNIT_SCENES.keys()
	if available_roles.is_empty():
		return Statics.Role.ROLE_A
	return available_roles[randi_range(0, available_roles.size() - 1)]

func _custom_spawn(data: Variant) -> Node:
	var role = data["role"]
	var team_id = int(data.get("team_id", 0))
	var slot = int(data.get("slot", 0))
	var units_per_team = int(data.get("units_per_team", 1))
	var id = data["id"]
	var scene = UNIT_SCENES.get(role, UNIT_SCENES[Statics.Role.ROLE_A])
	var unit = scene.instantiate()
	unit.name = "Unit_%d" % id
	unit.team_id = team_id
	if team_id < SPAWN_DIRECTIONS.size():
		var lane_index := float(slot) - (float(units_per_team - 1) * 0.5)
		var formation_offset := Vector3(0.0, 0.0, lane_index * unit_spacing_z)
		unit.position = _get_team_spawn_position(team_id) + formation_offset
		unit.advance_direction = SPAWN_DIRECTIONS[team_id]
	return unit

func _get_team_spawn_position(team_id: int) -> Vector3:
	if team_id == 0:
		return team_0_spawn_position
	return team_1_spawn_position
		
#Codigo para spawnear manualmente las unidades
var _manual_spawn_count := 0

func manual_unit_spawn(role: Statics.Role, team_id: int):
	# Solo el servidor puede ejecutar el spawner.spawn
	if not multiplayer.is_server():
		return

	_manual_spawn_count += 1
	
	var unique_id = 5000 + _manual_spawn_count
	
	var data = {
	"id": unique_id,
	"team_id": team_id,
	"role": role,
	"slot": randi() % 5, # Slot aleatorio para que no salgan todas en la misma linea
	"units_per_team": 5   # Valor base para el calculo de formacion
	}
	spawner.spawn(data)
	
#Inputs para spawn manual
func _input(_event):
	#Equipo Azul
	if Input.is_key_pressed(KEY_1):
		manual_unit_spawn(Statics.Role.ROLE_A, 0)
	if Input.is_key_pressed(KEY_2):
		manual_unit_spawn(Statics.Role.ROLE_B, 0)
	if Input.is_key_pressed(KEY_3):
		manual_unit_spawn(Statics.Role.ROLE_C, 0)
	#Equipo Rojo
	if Input.is_key_pressed(KEY_4):
		manual_unit_spawn(Statics.Role.ROLE_A, 1)
	if Input.is_key_pressed(KEY_5):
		manual_unit_spawn(Statics.Role.ROLE_B, 1)
	if Input.is_key_pressed(KEY_6):
		manual_unit_spawn(Statics.Role.ROLE_C, 1)
	return
