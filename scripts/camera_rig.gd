extends Node3D

@export var move_speed: float = 8.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 4.0
@export var max_zoom: float = 18.0

# Posiciones de referencia de las bases para colocar la cámara detrás.
# Coinciden con BlueCastle (team 0) y RedCastle (team 1) en main.tscn.
@export var team_0_base_position: Vector3 = Vector3(-10.82, 0.0, 1.5)
@export var team_1_base_position: Vector3 = Vector3(9.94, 0.0, 1.5)

@onready var camera: Camera3D = $CameraPivot/Camera3D


func _ready() -> void:
	# Esperar a que el resto de la escena (jugador en Game, castillos) esté lista.
	await get_tree().process_frame
	_apply_team_view(_resolve_team_id())


func _resolve_team_id() -> int:
	var player = Game.get_current_player()
	if player:
		return Statics.player_team_id(player)
	return 0


func _apply_team_view(team_id: int) -> void:
	var base_position := team_0_base_position if team_id == 0 else team_1_base_position
	# Intentar usar la posición real del castillo si ya está en escena.
	var castles = get_tree().get_nodes_in_group("castillo_jugador_" + str(team_id))
	if not castles.is_empty():
		base_position = castles[0].global_position

	global_position = base_position
	# Cada equipo mira hacia el otro: team 0 (izquierda) mira a +X; team 1 (derecha) mira a -X.
	rotation = Vector3.ZERO
	rotate_y(deg_to_rad(-90.0) if team_id == 0 else deg_to_rad(90.0))


func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
		# Movimiento relativo al rig: W siempre avanza hacia el frente del jugador.
		translate(input_dir * move_speed * delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.position.z = max(min_zoom, camera.position.z - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.position.z = min(max_zoom, camera.position.z + zoom_speed)
