extends Node3D

@export var move_speed: float = 8.0
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 4.0
@export var max_zoom: float = 18.0

@onready var camera: Camera3D = $CameraPivot/Camera3D

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
		global_position += input_dir * move_speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.position.z = max(min_zoom, camera.position.z - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.position.z = min(max_zoom, camera.position.z + zoom_speed)
