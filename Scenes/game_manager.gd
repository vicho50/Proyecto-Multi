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
var _manual_spawn_count := 0
const warrior_price: int = 5
const archer_price: int = 10
const heavy_price: int = 15

var SPAWN_DIRECTIONS = [
	Vector3.RIGHT,
	Vector3.LEFT,
]

func _ready():
	spawner.spawn_function = _custom_spawn
	if multiplayer.is_server():
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
	var id = data["id"]
	var scene = UNIT_SCENES.get(role, UNIT_SCENES[Statics.Role.ROLE_A])
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
func request_custom_spawn(role: Statics.Role, team_id: int, target_pos: Vector3):
	if not multiplayer.is_server():
		return
	_manual_spawn_count += 1
	var unique_id = 5000 + _manual_spawn_count
	
	var data = {
		"id": unique_id,
		"team_id": team_id,
		"role": role,
		"custom_position": target_pos,
		"use_custom_pos": true
	}
	if role==Statics.Role.ROLE_A:
		if GameManager.read_gold(0)>=heavy_price:
			GameManager.sub_gold(0,heavy_price)
			spawner.spawn(data)
	if role==Statics.Role.ROLE_C:
		if GameManager.read_gold(0)>=archer_price:
			GameManager.sub_gold(0,archer_price)
			spawner.spawn(data)
	if role==Statics.Role.ROLE_B:
		if GameManager.read_gold(0)>=warrior_price:
			GameManager.sub_gold(0,warrior_price)
			spawner.spawn(data)
	

func _unhandled_input(event):
	# Procesa clics del mouse no manejados por la UI
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ui_nodes = get_tree().get_nodes_in_group("UI_Nodes")
		if ui_nodes.is_empty(): return
		
		var ui_layer = ui_nodes[0]
		if ui_layer.selected_role != null:
			var clicked_position = _get_mouse_3d_position()
			if clicked_position != Vector3.INF:
				request_custom_spawn.rpc(ui_layer.selected_role, ui_layer.player_id, clicked_position)
				return

	if Input.is_key_pressed(KEY_1): manual_unit_spawn(Statics.Role.ROLE_A, 0)
	if Input.is_key_pressed(KEY_2): manual_unit_spawn(Statics.Role.ROLE_B, 0)
	if Input.is_key_pressed(KEY_3): manual_unit_spawn(Statics.Role.ROLE_C, 0)
	if Input.is_key_pressed(KEY_4): manual_unit_spawn(Statics.Role.ROLE_A, 1)
	if Input.is_key_pressed(KEY_5): manual_unit_spawn(Statics.Role.ROLE_B, 1)
	if Input.is_key_pressed(KEY_6): manual_unit_spawn(Statics.Role.ROLE_C, 1)

func manual_unit_spawn(role: Statics.Role, team_id: int):
	if not multiplayer.is_server():
		return
	_manual_spawn_count += 1
	var unique_id = 5000 + _manual_spawn_count
	var data = {
		"id": unique_id,
		"team_id": team_id,
		"role": role,
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
