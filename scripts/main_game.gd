extends Node3D

# Example main game controller
# This demonstrates how to use the SpawnController

@onready var spawn_controller = $SpawnController

func _ready() -> void:
	# Example: Spawn units when pressing keys
	pass

func _unhandled_input(event: InputEvent) -> void:
	if not Game.is_online():
		return  # Only work in multiplayer

	# Example controls for testing
	# Press 1 to spawn team 0 warrior
	if event.is_action_pressed("ui_page_up"):
		spawn_controller.request_spawn_unit.rpc("roman_warrior", 0)

	# Press 2 to spawn team 1 warrior
	elif event.is_action_pressed("ui_page_down"):
		spawn_controller.request_spawn_unit.rpc("roman_warrior", 1)

	# Press 3 to spawn team 0 heavy
	elif event.is_action_pressed("ui_home"):
		spawn_controller.request_spawn_unit.rpc("roman_heavy", 0)

	# Press 4 to spawn team 1 heavy
	elif event.is_action_pressed("ui_end"):
		spawn_controller.request_spawn_unit.rpc("roman_heavy", 1)

func _process(delta: float) -> void:
	# Example: Show help text in debug mode
	if OS.is_debug_build() and Game.is_online():
		Debug.log("Press PageUp/PageDown to spawn warriors, Home/End for heavy units")
