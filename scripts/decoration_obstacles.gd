extends Node3D

@export var collision_layer: int = 1
@export var collision_mask: int = 0
@export var collision_margin: float = 0.15
@export var minimum_size: Vector3 = Vector3(0.35, 0.35, 0.35)
@export var randomize_layout: bool = true
@export var map_min_x: float = -11.0
@export var map_max_x: float = 11.0
@export var map_min_z: float = -11.0
@export var map_max_z: float = 11.0
@export var min_distance_between_decorations: float = 0.8
@export var mine_clearance_radius: float = 2.1
@export var castle_clearance_radius: float = 3.5

var _built := false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if randomize_layout:
		_randomize_layout()
	call_deferred("_build_obstacles")


func _randomize_layout() -> void:
	var decorations: Array[Node3D] = []
	for child in get_children():
		if child is MeshInstance3D:
			decorations.append(child)

	decorations.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return _get_decor_radius(a) > _get_decor_radius(b)
	)

	var occupied_positions: Array[Vector2] = []
	var occupied_radii: Array[float] = []
	var forbidden_points: Array[Dictionary] = _get_forbidden_points()

	for decoration in decorations:
		var radius := _get_decor_radius(decoration)
		var placed := false
		for _attempt in range(80):
			var candidate := Vector2(
				_rng.randf_range(map_min_x, map_max_x),
				_rng.randf_range(map_min_z, map_max_z)
			)
			if not _is_position_free(candidate, radius, occupied_positions, occupied_radii, forbidden_points):
				continue
			var current_position := decoration.position
			decoration.position = Vector3(candidate.x, current_position.y, candidate.y)
			occupied_positions.append(candidate)
			occupied_radii.append(radius)
			placed = true
			break

		if not placed:
			occupied_positions.append(Vector2(decoration.position.x, decoration.position.z))
			occupied_radii.append(radius)


func _get_forbidden_points() -> Array[Dictionary]:
	var forbidden: Array[Dictionary] = []

	for mine in get_tree().get_nodes_in_group("minas"):
		if mine is Node3D:
			forbidden.append({"position": Vector2(mine.global_position.x, mine.global_position.z), "radius": mine_clearance_radius})

	for team_id in [0, 1]:
		var castle_group := "castillo_jugador_" + str(team_id)
		for castle in get_tree().get_nodes_in_group(castle_group):
			if castle is Node3D and not castle.is_dead:
				forbidden.append({"position": Vector2(castle.global_position.x, castle.global_position.z), "radius": castle_clearance_radius})

	return forbidden


func _get_decor_radius(decoration: Node3D) -> float:
	if decoration is MeshInstance3D:
		var mesh_instance := decoration as MeshInstance3D
		if mesh_instance.mesh != null:
			var aabb := mesh_instance.mesh.get_aabb()
			return max(aabb.size.x, aabb.size.z) * 0.5 + collision_margin
	return minimum_size.x


func _is_position_free(candidate: Vector2, radius: float, occupied_positions: Array[Vector2], occupied_radii: Array[float], forbidden_points: Array[Dictionary]) -> bool:
	for i in occupied_positions.size():
		var other_position := occupied_positions[i]
		var other_radius := occupied_radii[i]
		if candidate.distance_to(other_position) < radius + other_radius + min_distance_between_decorations:
			return false

	for point in forbidden_points:
		var point_position: Vector2 = point["position"]
		var point_radius: float = point["radius"]
		if candidate.distance_to(point_position) < radius + point_radius + min_distance_between_decorations:
			return false

	return true

func _build_obstacles() -> void:
	if _built:
		return
	_built = true

	for child in get_children():
		if not (child is MeshInstance3D):
			continue

		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue

		var aabb := mesh_instance.mesh.get_aabb()
		if aabb.size == Vector3.ZERO:
			continue

		var obstacle := StaticBody3D.new()
		obstacle.name = "%s_Obstacle" % mesh_instance.name
		obstacle.collision_layer = collision_layer
		obstacle.collision_mask = collision_mask
		obstacle.add_to_group("map_obstacle")
		obstacle.transform = mesh_instance.transform
		add_child(obstacle)

		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(
			max(aabb.size.x + collision_margin * 2.0, minimum_size.x),
			max(aabb.size.y + collision_margin * 2.0, minimum_size.y),
			max(aabb.size.z + collision_margin * 2.0, minimum_size.z)
		)
		shape_node.shape = box
		shape_node.position = aabb.position + aabb.size * 0.5
		obstacle.add_child(shape_node)
