extends CharacterBody3D

enum State {IDLE, GO_TO_MINE, MINING, RETURN_TO_BASE}

@export var team_id: int = 0
@export var carry_capacity: int = 20
@export var mining_speed: float = 1.5
@export var move_speed: float = 4.0

var current_state = State.IDLE
var current_gold: int = 0
var target_mine: Node3D = null
var home_castle: Node3D = null

@onready var nav_agent = $NavigationAgent3D
@onready var mining_timer = $MiningTimer

@export var obstacle_avoidance_distance: float = 2.0
@export var obstacle_avoidance_probe_radius: float = 0.8
@export var obstacle_avoidance_angles: PackedFloat32Array = PackedFloat32Array([0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0])

func _ready():
	mining_timer.wait_time = mining_speed
	mining_timer.timeout.connect(_on_mining_tick)
	_find_base()
	update_state(State.GO_TO_MINE)

func _physics_process(_delta):
	match current_state:
		State.GO_TO_MINE:
			_move_logic(target_mine.global_position if target_mine else Vector3.ZERO)
			if nav_agent.is_navigation_finished():
				update_state(State.MINING)
				
		State.RETURN_TO_BASE:
			_move_logic(home_castle.global_position if home_castle else Vector3.ZERO)
			if nav_agent.is_navigation_finished():
				_deposit_gold()

func update_state(new_state):
	current_state = new_state
	match new_state:
		State.GO_TO_MINE:
			_find_closest_mine()
			if target_mine: nav_agent.target_position = target_mine.global_position
		State.MINING:
			velocity = Vector3.ZERO
			mining_timer.start()
		State.RETURN_TO_BASE:
			mining_timer.stop()
			if home_castle: nav_agent.target_position = home_castle.global_position

func _move_logic(dest):
	if dest == Vector3.ZERO: return
	var next_pos = nav_agent.get_next_path_position()
	var desired_dir = global_position.direction_to(next_pos)
	velocity = _find_clear_direction(desired_dir) * move_speed
	move_and_slide()


func _find_clear_direction(desired_dir: Vector3) -> Vector3:
	var flat := desired_dir
	flat.y = 0.0
	if flat.length() <= 0.001:
		return Vector3.ZERO

	var desired := flat.normalized()
	if not _is_direction_blocked(desired):
		return desired

	for angle_degrees in obstacle_avoidance_angles:
		var rotated := desired.rotated(Vector3.UP, deg_to_rad(angle_degrees))
		if rotated.length() <= 0.001:
			continue
		if not _is_direction_blocked(rotated):
			return rotated.normalized()

	return desired


func _is_direction_blocked(direction: Vector3) -> bool:
	var flat := direction.normalized()
	var side := Vector3.UP.cross(flat)
	if side.length() <= 0.001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()

	var space_state = get_world_3d().direct_space_state
	for lateral in [0.0, obstacle_avoidance_probe_radius, -obstacle_avoidance_probe_radius]:
		var from: Vector3 = global_position + Vector3.UP * 0.3 + side * lateral
		var to: Vector3 = from + flat * obstacle_avoidance_distance
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not space_state.intersect_ray(query).is_empty():
			return true

	return false

func _on_mining_tick():
	if target_mine and target_mine.has_method("extract_gold"):
		var extracted = target_mine.extract_gold(5)
		current_gold += extracted
		
		if current_gold >= carry_capacity:
			update_state(State.RETURN_TO_BASE)

func _deposit_gold():
	GameManager.add_gold(team_id, current_gold)
	current_gold = 0
	update_state(State.GO_TO_MINE)

func _find_closest_mine():
	var minas = get_tree().get_nodes_in_group("minas")
	if minas.size() > 0:
		target_mine = minas[0] # Simplificado: toma la primera disponible

func _find_base():
	var bases = get_tree().get_nodes_in_group("castillo_jugador_" + str(team_id))
	if bases.size() > 0:
		home_castle = bases[0]
