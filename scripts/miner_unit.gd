extends Node3D

enum State {IDLE, GO_TO_MINE, MINING, RETURN_TO_BASE}

@export var team_id: int = 0
@export var advance_direction: Vector3 = Vector3.RIGHT
@export var carry_capacity: int = 20
@export var mining_speed: float = 1.5
@export var move_speed: float = 4.0
@export var obstacle_avoidance_distance: float = 2.0
@export var obstacle_avoidance_probe_radius: float = 0.8
@export var obstacle_avoidance_angles: PackedFloat32Array = PackedFloat32Array([0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0])

# Sincronizadas por MultiplayerSynchronizer
var current_state: int = State.IDLE
var current_health: int = 30
var is_dead: bool = false

var current_gold: int = 0
var target_mine: Node3D = null
var home_castle: Node3D = null

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visuals: Node3D = $Visuals
@onready var pickaxe: Node3D = $Visuals/Pickaxe
@onready var body_mesh: MeshInstance3D = $Visuals/Body

# Timer creado en _ready para no depender de nodo en escena
var mining_timer: Timer

# Variables de animación
var visual_base_y: float = 0.0
var bounce_time: float = 0.0
var pickaxe_base_pos: Vector3 = Vector3.ZERO
var pickaxe_base_rot: Vector3 = Vector3.ZERO

var mining_animating: bool = false
var mining_anim_time: float = 0.0
const MINING_ANIM_DURATION: float = 0.35

func _ready() -> void:
	# Crear MiningTimer programáticamente
	mining_timer = Timer.new()
	mining_timer.wait_time = mining_speed
	mining_timer.one_shot = false
	mining_timer.timeout.connect(_on_mining_tick)
	add_child(mining_timer)

	visual_base_y = visuals.position.y
	pickaxe_base_pos = pickaxe.position
	pickaxe_base_rot = pickaxe.rotation

	_apply_team_color()

	if multiplayer.is_server():
		_find_base()
		# Defer para que el mapa de navegación y los nodos estén listos
		call_deferred("_deferred_start")


func _apply_team_color() -> void:
	var team_color := Color(0.2, 0.4, 1.0) if team_id == 0 else Color(1.0, 0.2, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = team_color
	body_mesh.material_override = mat

func _deferred_start() -> void:
	_update_state(State.GO_TO_MINE)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Al declararse un vencedor los mineros también dejan de trabajar.
	if Game.game_over:
		_update_visuals(delta)
		return

	if multiplayer.is_server():
		_run_logic(delta)

	_update_visuals(delta)

func _run_logic(delta: float) -> void:
	match current_state:
		State.GO_TO_MINE:
			if target_mine and is_instance_valid(target_mine):
				_move_towards(target_mine.global_position, delta, true)
				if global_position.distance_to(target_mine.global_position) < 1.5:
					_update_state(State.MINING)
			else:
				_find_closest_mine()
				if target_mine:
					nav_agent.target_position = target_mine.global_position

		State.RETURN_TO_BASE:
			if home_castle and is_instance_valid(home_castle):
				_move_towards(home_castle.global_position, delta, false)
				if global_position.distance_to(home_castle.global_position) < 1.5:
					_deposit_gold()

func _update_state(new_state: int) -> void:
	current_state = new_state
	match new_state:
		State.GO_TO_MINE:
			_find_closest_mine()
			if target_mine:
				nav_agent.target_position = target_mine.global_position
		State.MINING:
			mining_timer.start()
		State.RETURN_TO_BASE:
			mining_timer.stop()
			mining_animating = false
			if home_castle:
				nav_agent.target_position = home_castle.global_position

func _move_towards(dest: Vector3, delta: float, avoid_obstacles: bool) -> void:
	var next_pos = nav_agent.get_next_path_position()

	# Si el agente no tiene camino aún, moverse directamente al destino
	if global_position.distance_to(next_pos) < 0.05:
		next_pos = dest

	var desired_direction = global_position.direction_to(next_pos)
	var direction = _find_clear_direction(desired_direction) if avoid_obstacles else desired_direction
	global_position = global_position.move_toward(global_position + direction * move_speed * delta, move_speed * delta)

	# Rotar hacia la dirección de movimiento
	var flat_dir = Vector3(direction.x, 0.0, direction.z)
	if flat_dir.length() > 0.01:
		var target_angle = atan2(flat_dir.x, flat_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


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
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [self]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var collider: Node = hit.get("collider") as Node
		if collider == null:
			continue
		if collider.is_in_group("minas"):
			continue
			if collider.is_in_group("castillo_jugador_" + str(team_id)):
				continue
		return true

	return false

func _on_mining_tick() -> void:
	if not multiplayer.is_server():
		return
	if not (target_mine and is_instance_valid(target_mine)):
		_update_state(State.GO_TO_MINE)
		return

	var extracted: int = target_mine.extract_gold(5)
	current_gold += extracted

	# Disparar animación (se ejecutará en todos los clientes vía sync de current_state)
	_trigger_mining_anim.rpc()

	if current_gold >= carry_capacity:
		_update_state(State.RETURN_TO_BASE)

func _deposit_gold() -> void:
	GameManager.add_gold(team_id, current_gold)
	current_gold = 0
	_update_state(State.GO_TO_MINE)

# -----------------------------------------------------------------------
# Animaciones visuales
# -----------------------------------------------------------------------

@rpc("authority", "call_local", "unreliable")
func _trigger_mining_anim() -> void:
	mining_animating = true
	mining_anim_time = 0.0

func _update_visuals(delta: float) -> void:
	match current_state:
		State.GO_TO_MINE, State.RETURN_TO_BASE:
			# Bounce de caminar
			bounce_time += delta * 8.0
			visuals.position.y = lerp(
				visuals.position.y,
				visual_base_y + abs(sin(bounce_time)) * 0.12,
				12.0 * delta
			)
			# Pico vuelve a posición base
			pickaxe.position = pickaxe.position.lerp(pickaxe_base_pos, 10.0 * delta)
			pickaxe.rotation = pickaxe.rotation.lerp(pickaxe_base_rot, 10.0 * delta)

		State.IDLE, State.MINING:
			# Flotación idle suave
			bounce_time += delta * 2.0
			visuals.position.y = lerp(
				visuals.position.y,
				visual_base_y + sin(bounce_time) * 0.025,
				8.0 * delta
			)

			# Swing del pico
			if mining_animating:
				mining_anim_time += delta
				var half := MINING_ANIM_DURATION * 0.5
				var t: float
				if mining_anim_time < half:
					t = mining_anim_time / half
				elif mining_anim_time < MINING_ANIM_DURATION:
					t = 1.0 - (mining_anim_time - half) / half
				else:
					mining_animating = false
					mining_anim_time = 0.0
					t = 0.0

				pickaxe.rotation.x = lerp(pickaxe_base_rot.x, pickaxe_base_rot.x - deg_to_rad(85.0), t)
				pickaxe.position.y  = lerp(pickaxe_base_pos.y, pickaxe_base_pos.y - 0.18, t)
			else:
				pickaxe.position = pickaxe.position.lerp(pickaxe_base_pos, 10.0 * delta)
				pickaxe.rotation = pickaxe.rotation.lerp(pickaxe_base_rot, 10.0 * delta)

# -----------------------------------------------------------------------
# Búsqueda de nodos
# -----------------------------------------------------------------------

func _find_closest_mine() -> void:
	var minas = get_tree().get_nodes_in_group("minas")
	var closest: Node3D = null
	var min_dist := INF
	for mina in minas:
		if not is_instance_valid(mina):
			continue
		if mina.is_infinite or mina.gold_remaining > 0:
			var dist = global_position.distance_to(mina.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = mina
	target_mine = closest

func _find_base() -> void:
	var bases = get_tree().get_nodes_in_group("castillo_jugador_" + str(team_id))
	if bases.size() > 0:
		home_castle = bases[0]
