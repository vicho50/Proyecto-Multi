extends Node3D

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

# Cada facción tiene su propio set de escenas. El team_id 0 (Romanos) usa las
# escenas roman_*, el team_id 1 (Germanos) usa las german_*. El minero es común.
var ROMAN_UNIT_SCENES = {
	Statics.UnitType.HEAVY: preload("res://Scenes/roman_heavy.tscn"),
	Statics.UnitType.WARRIOR: preload("res://Scenes/roman_warrior.tscn"),
	Statics.UnitType.ARCHER: preload("res://Scenes/roman_archer.tscn"),
	Statics.UnitType.MINER: preload("res://Scenes/miner_unit.tscn"),
}

var GERMAN_UNIT_SCENES = {
	Statics.UnitType.HEAVY: preload("res://Scenes/german_heavy.tscn"),
	Statics.UnitType.WARRIOR: preload("res://Scenes/german_warrior.tscn"),
	Statics.UnitType.ARCHER: preload("res://Scenes/german_archer.tscn"),
	Statics.UnitType.MINER: preload("res://Scenes/miner_unit.tscn"),
}

# Unidades de combate elegibles para la oleada inicial aleatoria (el minero se excluye).
var COMBAT_UNIT_TYPES = [
	Statics.UnitType.HEAVY,
	Statics.UnitType.WARRIOR,
	Statics.UnitType.ARCHER,
]

@export var spawn_initial_wave: bool = false # Si es false, la partida empieza sin unidades.
@export var min_initial_units_per_team: int = 3
@export var max_initial_units_per_team: int = 6
@export var unit_spacing_z: float = 1.4
@export var team_0_spawn_position: Vector3 = Vector3(-9.0, 0.0, 0.3)
@export var team_1_spawn_position: Vector3 = Vector3(8.3, 0.0, 0.3)

var _initial_spawn_done := false
var _manual_spawn_count := 0
const warrior_price: int = 5
const archer_price: int = 10
const heavy_price: int = 15
const miner_price: int = 20

var SPAWN_DIRECTIONS = [
	Vector3.RIGHT,
	Vector3.LEFT,
]

func _ready():
	spawner.spawn_function = _custom_spawn
	# Reinicia la economía al comenzar el combate (10 de oro por equipo + ingreso pasivo).
	GameManager.start_match()
	if multiplayer.is_server() and spawn_initial_wave:
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
		var random_unit := _get_random_spawn_unit_type()
		for team_id in SPAWN_DIRECTIONS.size():
			var data = {
				"id": (team_id * 1000) + slot,
				"team_id": team_id,
				"slot": slot,
				"units_per_team": units_per_team,
				"unit_type": random_unit,
			}
			spawner.spawn(data)

func _get_random_spawn_unit_type() -> Statics.UnitType:
	if COMBAT_UNIT_TYPES.is_empty():
		return Statics.UnitType.HEAVY
	return COMBAT_UNIT_TYPES[randi_range(0, COMBAT_UNIT_TYPES.size() - 1)]


# Devuelve la escena de la unidad para la facción correspondiente al team_id.
func _get_unit_scene_for_team(unit_type: Statics.UnitType, team_id: int) -> PackedScene:
	var scenes = ROMAN_UNIT_SCENES if team_id == 0 else GERMAN_UNIT_SCENES
	return scenes.get(unit_type, scenes[Statics.UnitType.HEAVY])

func _custom_spawn(data: Variant) -> Node:
	var unit_type = data["unit_type"]
	var team_id = int(data.get("team_id", 0))
	var id = data["id"]
	var scene = _get_unit_scene_for_team(unit_type, team_id)
	var unit = scene.instantiate()
	unit.name = "Unit_%d" % id
	unit.team_id = team_id
	
	# Verifica si se envio una posicion personalizada en el click
	if data.get("use_custom_pos", false):
		unit.position = data["custom_position"]
	else:
		var slot = int(data.get("slot", 0))
		var units_per_team = int(data.get("units_per_team", 1))
		var lane_index := float(slot) - (float(units_per_team - 1) * 0.5)
		var formation_offset := Vector3(0.0, 0.0, lane_index * unit_spacing_z)
		unit.position = _get_team_spawn_position(team_id) + formation_offset
		
	unit.advance_direction = SPAWN_DIRECTIONS[team_id]
	return unit

func _get_team_spawn_position(team_id: int) -> Vector3:
	if team_id == 0:
		return team_0_spawn_position
	return team_1_spawn_position

# RPC para que los clientes soliciten spawnear en una coordenada
@rpc("any_peer", "call_local")
func request_custom_spawn(unit_type: Statics.UnitType, team_id: int, target_pos: Vector3):
	if not multiplayer.is_server():
		return
	_manual_spawn_count += 1
	var unique_id = 5000 + _manual_spawn_count

	var data = {
		"id": unique_id,
		"team_id": team_id,
		"unit_type": unit_type,
		"custom_position": target_pos,
		"use_custom_pos": true
	}
	if unit_type == Statics.UnitType.HEAVY:
		if GameManager.read_gold(team_id) >= heavy_price:
			GameManager.sub_gold(team_id, heavy_price)
			spawner.spawn(data)
	if unit_type == Statics.UnitType.ARCHER:
		if GameManager.read_gold(team_id) >= archer_price:
			GameManager.sub_gold(team_id, archer_price)
			spawner.spawn(data)
	if unit_type == Statics.UnitType.WARRIOR:
		if GameManager.read_gold(team_id) >= warrior_price:
			GameManager.sub_gold(team_id, warrior_price)
			spawner.spawn(data)
	if unit_type == Statics.UnitType.MINER:
		if GameManager.read_gold(team_id) >= miner_price:
			GameManager.sub_gold(team_id, miner_price)
			spawner.spawn(data)


func _unhandled_input(event):
	# Procesa clics del mouse no manejados por la UI
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ui_nodes = get_tree().get_nodes_in_group("UI_Nodes")
		if ui_nodes.is_empty(): return

		var ui_layer = ui_nodes[0]
		if ui_layer.selected_unit_type != null:
			var clicked_position = _get_mouse_3d_position()
			if clicked_position != Vector3.INF:
				request_custom_spawn.rpc(ui_layer.selected_unit_type, ui_layer.player_id, clicked_position)
				return

	if Input.is_key_pressed(KEY_1): manual_unit_spawn(Statics.UnitType.HEAVY, 0)
	if Input.is_key_pressed(KEY_2): manual_unit_spawn(Statics.UnitType.WARRIOR, 0)
	if Input.is_key_pressed(KEY_3): manual_unit_spawn(Statics.UnitType.ARCHER, 0)
	if Input.is_key_pressed(KEY_4): manual_unit_spawn(Statics.UnitType.HEAVY, 1)
	if Input.is_key_pressed(KEY_5): manual_unit_spawn(Statics.UnitType.WARRIOR, 1)
	if Input.is_key_pressed(KEY_6): manual_unit_spawn(Statics.UnitType.ARCHER, 1)

func manual_unit_spawn(unit_type: Statics.UnitType, team_id: int):
	if not multiplayer.is_server():
		return
	_manual_spawn_count += 1
	var unique_id = 5000 + _manual_spawn_count
	var data = {
		"id": unique_id,
		"team_id": team_id,
		"unit_type": unit_type,
		"slot": randi() % 5,
		"units_per_team": 5
	}
	spawner.spawn(data)

# Proyecta un rayo desde la camara hacia el espacio 3D, Intersecta con el suelo
func _get_mouse_3d_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector3.INF
	
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_normal = camera.project_ray_normal(mouse_pos)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * 1000)
	 
	var result = space_state.intersect_ray(query)
	if result:
		return result.position # Retorna el impacto con el suelo
	return Vector3.INF
