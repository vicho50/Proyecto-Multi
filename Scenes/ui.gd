extends CanvasLayer

const game_manager = preload("res://Scenes/game_manager.gd")
@export var player_id: int = 0

@onready var resource_label = $HUD/HBoxContainer/ResourceLabel
@onready var health_bar = $HUD/MarginContainer/HealthBar
@onready var health_percentage_label = $HUD/MarginContainer/HealthBar/Label
@onready var Heavy_Cost = $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/HBoxContainer/Precio_Heavy
@onready var Warrior_Cost = $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/HBoxContainer/Precio_Warrior
@onready var Archer_Cost = $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/HBoxContainer/Precio_Archer
@onready var Miner_Cost = $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/HBoxContainer/Precio_Miner


@onready var game_over_screen: Control = $GameOverScreen
@onready var result_label: Label = $GameOverScreen/ResultLabel

@onready var Puller = $HUD/VBoxContainer/Control
@onready var Puller_Button = $HUD/VBoxContainer/Control/TextureButton
var is_collapsed := false

@onready var Puller_2 = $HUD/VBoxContainer_2/Control_2
@onready var Puller_Button_2 = $HUD/VBoxContainer_2/Control_2/TextureButton_2
var is_collapsed_2 := false

var _game_over := false

#Mouses
var Heavy_Mouse=load("res://Assets/UI/Mouses/Mouse_Heavy.png")
var Warrior_Mouse=load("res://Assets/UI/Mouses/Mouse_Warrior.png")
var Archer_Mouse=load("res://Assets/UI/Mouses/Mouse_Archer.png")
var Miner_Mouse=load("res://Assets/UI/Mouses/Mouse_Miner.png")
var Default_Mouse=load("res://Assets/UI/Mouses/Mouse_Default.png")
var Special_Mouse=load("res://Assets/UI/Mouses/Mouse_Special.png")

var player_data
# Tipo de unidad seleccionado para spawn al hacer click
var selected_unit_type = null

func _ready():
	await get_tree().process_frame

	# Team (side 0/1) is assigned by lobby join order; the faction (Romans/Celts)
	# only decides which unit scenes get spawned.
	var current = Game.get_current_player()
	if current:
		player_id = Statics.player_team_id(current)

	player_data = GameManager.get_player(player_id)

	if player_data:
		player_data.gold_changed.connect(update_gold)
		update_gold(player_data.gold)
		_setup_castle_link()
		# Registra la UI en un grupo para acceder facilmente desde el mundo 3D
		add_to_group("UI_Nodes")
	Set_Prices()
	_setup_game_over_watch()

# Escucha la destrucción de ambos castillos para mostrar victoria/derrota.
func _setup_game_over_watch():
	game_over_screen.visible = false
	for tid in [0, 1]:
		for castle in get_tree().get_nodes_in_group("castillo_jugador_" + str(tid)):
			if castle.has_signal("castle_destroyed"):
				castle.castle_destroyed.connect(_on_castle_destroyed.bind(tid))

# El primer parámetro es el player_id emitido por la señal (no se usa);
# el segundo es el team_id que enlazamos al conectar (equipo perdedor).
func _on_castle_destroyed(_emitted_id, losing_team_id: int) -> void:
	if _game_over:
		return
	_game_over = true
	if player_id == losing_team_id:
		result_label.text = "DEFEAT"
		result_label.modulate = Color(1.0, 0.35, 0.35)
	else:
		result_label.text = "VICTORY"
		result_label.modulate = Color(0.4, 1.0, 0.4)
	game_over_screen.visible = true

func _setup_castle_link():
	var castle_group = "castillo_jugador_" + str(player_id)
	var castles = get_tree().get_nodes_in_group(castle_group)
	
	if castles.size() > 0:
		var c = castles[0]
		c.health_changed.connect(_on_health_updated)
		health_bar.max_value = c.max_health
		health_bar.value = c.current_health

func _on_health_updated(curr, _max):
	var t = create_tween()
	t.tween_property(health_bar, "value", curr, 0.1)
	if _max > 0:
		var porcentaje: int = int((float(curr) / float(_max)) * 100)
		porcentaje = max(0, porcentaje) 
		health_percentage_label.text = str(porcentaje) + "%"
	else:
		health_percentage_label.text = "0%"

func update_gold(amount: int):
	resource_label.text = "Gold: " + str(amount)
	
func Set_Prices():
	Heavy_Cost.text = str(game_manager.heavy_price)
	Warrior_Cost.text = str(game_manager.warrior_price)
	Archer_Cost.text = str(game_manager.archer_price)
	Miner_Cost.text = str(game_manager.miner_price)

func _input(_event):
	if Input.is_key_pressed(KEY_KP_ADD):
		GameManager.add_gold(player_id, 50)
	
	if Input.is_key_pressed(KEY_KP_SUBTRACT):
		var castles = get_tree().get_nodes_in_group("castillo_jugador_" + str(player_id))
		if castles.size() > 0: castles[0].take_damage(10)
	if Input.is_key_pressed(KEY_1):
		select_unit_to_spawn(Statics.UnitType.WARRIOR)
		Input.set_custom_mouse_cursor(Warrior_Mouse)
	if Input.is_key_pressed(KEY_2):
		select_unit_to_spawn(Statics.UnitType.ARCHER)
		Input.set_custom_mouse_cursor(Archer_Mouse)
	if Input.is_key_pressed(KEY_3):
		select_unit_to_spawn(Statics.UnitType.HEAVY)
		Input.set_custom_mouse_cursor(Heavy_Mouse)
	if Input.is_key_pressed(KEY_4):
		select_unit_to_spawn(Statics.UnitType.MINER)
		Input.set_custom_mouse_cursor(Miner_Mouse)
	if Input.is_key_pressed(KEY_5):
		select_unit_to_spawn(Statics.UnitType.SPECIAL)
		Input.set_custom_mouse_cursor(Warrior_Mouse)

# Conecta la senal pressed los botones al tipo de unidad seleccionado
func select_unit_to_spawn(unit_type: Statics.UnitType):
	selected_unit_type = unit_type

#Heavy
func _on_roman_heavy_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.HEAVY)
	Input.set_custom_mouse_cursor(Heavy_Mouse)
	
func _on_roman_heavy_button_mouse_entered():
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.position -= $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.size * 0.025
	
func _on_roman_heavy_button_mouse_exited():
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.position += $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.size * 0.025
	
func _on_roman_heavy_button_button_down() -> void:
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/TextureRect.scale = Vector2(0.98, 0.98)
	
	
func _on_roman_heavy_button_button_up() -> void:
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Heavy_Button/TextureRect.scale = Vector2(1.0, 1.0)
	

#Warrior
# Roman Warrior
func _on_roman_warrior_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.WARRIOR)
	Input.set_custom_mouse_cursor(Warrior_Mouse)

func _on_roman_warrior_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.position -= $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.size * 0.025
func _on_roman_warrior_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.position += $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.size * 0.025

func _on_roman_warrior_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_roman_warrior_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Warrior_Button/TextureRect.scale = Vector2(1.0, 1.0)
# Roman Archer
func _on_roman_archer_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.ARCHER)
	Input.set_custom_mouse_cursor(Archer_Mouse)

func _on_roman_archer_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.position -= $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.size * 0.025
func _on_roman_archer_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.position += $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.size * 0.025

func _on_roman_archer_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_roman_archer_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Archer_Button/TextureRect.scale = Vector2(1.0, 1.0)

# Roman Miner
func _on_roman_miner_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.MINER)
	Input.set_custom_mouse_cursor(Miner_Mouse)

func _on_roman_miner_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.position -= $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.size * 0.025

func _on_roman_miner_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.position += $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.size * 0.025

func _on_roman_miner_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_roman_miner_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Miner_Button/TextureRect.scale = Vector2(1.0, 1.0)

func _on_roman_special_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.SPECIAL)
	Input.set_custom_mouse_cursor(Special_Mouse)

func _on_roman_special_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.position -= $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.size * 0.025

func _on_roman_special_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.position += $HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.size * 0.025

func _on_roman_special_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_roman_special_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer/Control/HBoxContainer2/Roman_Special_Button/TextureRect.scale = Vector2(1.0, 1.0)


######Germanos#######
#Heavy
func _on_german_heavy_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.HEAVY)
	Input.set_custom_mouse_cursor(Heavy_Mouse)
	
func _on_german_heavy_button_mouse_entered():
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.position -= $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.size * 0.025
	
func _on_german_heavy_button_mouse_exited():
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.position += $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.size * 0.025
	
func _on_german_heavy_button_button_down() -> void:
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button/TextureRect.scale = Vector2(0.98, 0.98)
	
	
func _on_german_heavy_button_button_up() -> void:
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Heavy_Button/TextureRect.scale = Vector2(1.0, 1.0)
	

#Warrior
# German Warrior
func _on_german_warrior_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.WARRIOR)
	Input.set_custom_mouse_cursor(Warrior_Mouse)

func _on_german_warrior_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.position -= $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.size * 0.025
func _on_german_warrior_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.position += $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.size * 0.025

func _on_german_warrior_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_german_warrior_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Warrior_Button/TextureRect.scale = Vector2(1.0, 1.0)
# German Archer
func _on_german_archer_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.ARCHER)
	Input.set_custom_mouse_cursor(Archer_Mouse)

func _on_german_archer_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.position -= $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.size * 0.025
func _on_german_archer_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.position += $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.size * 0.025

func _on_german_archer_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_german_archer_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Archer_Button/TextureRect.scale = Vector2(1.0, 1.0)

# German Miner
func _on_german_miner_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.MINER)
	Input.set_custom_mouse_cursor(Miner_Mouse)

func _on_german_miner_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.position -= $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.size * 0.025

func _on_german_miner_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.position += $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.size * 0.025

func _on_german_miner_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_german_miner_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Miner_Button/TextureRect.scale = Vector2(1.0, 1.0)

func _on_german_special_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.SPECIAL)
	Input.set_custom_mouse_cursor(Special_Mouse)

func _on_german_special_button_mouse_entered() -> void:
	# Set hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.scale = Vector2(1.05, 1.05)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.position -= $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.size * 0.025

func _on_german_special_button_mouse_exited() -> void:
	# Reset colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.scale = Vector2(1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.position += $HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.size * 0.025

func _on_german_special_button_button_down() -> void:
	# Set pressed colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button/TextureRect.scale = Vector2(0.98, 0.98)

func _on_german_special_button_button_up() -> void:
	# Revert to hover colors
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button.self_modulate = Color(1.1, 1.1, 1.1)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	$HUD/VBoxContainer_2/Control_2/HBoxContainer2/German_Special_Button/TextureRect.scale = Vector2(1.0, 1.0)


# Recogedor
func _on_toggle_units_button_pressed():
	var tween = create_tween()
	# Get current width
	var target_offset = -Puller.size.x
	
	if is_collapsed:
		# Move back to origin
		tween.tween_property(Puller, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC)
		Puller_Button.rotation_degrees = 0
		
	else:
		# Move to edge based on width
		tween.tween_property(Puller, "position:x", target_offset, 0.5).set_trans(Tween.TRANS_CUBIC)
		Puller_Button.rotation_degrees = 180
		
	is_collapsed = !is_collapsed
	
func _on_texture_button_mouse_entered() -> void:
	$HUD/VBoxContainer/Control/TextureButton.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/TextureButton.scale = Vector2(0.25, 0.25)
	$HUD/VBoxContainer/Control/TextureButton.position -= $HUD/VBoxContainer/Control/TextureButton.size * 0.002


func _on_texture_button_mouse_exited() -> void:
	$HUD/VBoxContainer/Control/TextureButton.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer/Control/TextureButton.scale = Vector2(0.24, 0.24)
	$HUD/VBoxContainer/Control/TextureButton.position += $HUD/VBoxContainer/Control/TextureButton.size * 0.002

func _on_texture_button_button_down() -> void:
	$HUD/VBoxContainer/Control/TextureButton.self_modulate = Color(0.7, 0.7, 0.7)
	$HUD/VBoxContainer/Control/TextureButton.scale = Vector2(0.23, 0.23)
	$HUD/VBoxContainer/Control/TextureButton.position += $HUD/VBoxContainer/Control/TextureButton.size * 0.003


func _on_texture_button_button_up() -> void:
	_on_toggle_units_button_pressed()
	$HUD/VBoxContainer/Control/TextureButton.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/Control/TextureButton.scale = Vector2(0.25, 0.25)
	$HUD/VBoxContainer/Control/TextureButton.position -= $HUD/VBoxContainer/Control/TextureButton.size * 0.003
	
	# Recogedor_Germanos
func _on_toggle_units_button_2_pressed():
	var tween = create_tween()
	# Get current width
	var target_offset = -1044
	
	if is_collapsed:
		# Move back to origin
		tween.tween_property(Puller_2, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC)
		Puller_Button_2.rotation_degrees = 0
		
	else:
		# Move to edge based on width
		tween.tween_property(Puller_2, "position:x", target_offset, 0.5).set_trans(Tween.TRANS_CUBIC)
		Puller_Button_2.rotation_degrees = 180
		
	is_collapsed = !is_collapsed
	
func _on_texture_button_2_mouse_entered() -> void:
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.scale = Vector2(0.25, 0.25)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.position -= $HUD/VBoxContainer_2/Control_2/TextureButton_2.size * 0.002


func _on_texture_button_2_mouse_exited() -> void:
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.self_modulate = Color(1.0, 1.0, 1.0)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.scale = Vector2(0.24, 0.24)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.position += $HUD/VBoxContainer_2/Control_2/TextureButton_2.size * 0.002

func _on_texture_button_2_button_down() -> void:
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.self_modulate = Color(0.7, 0.7, 0.7)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.scale = Vector2(0.23, 0.23)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.position += $HUD/VBoxContainer_2/Control_2/TextureButton_2.size * 0.003


func _on_texture_button_2_button_up() -> void:
	_on_toggle_units_button_2_pressed()
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.scale = Vector2(0.25, 0.25)
	$HUD/VBoxContainer_2/Control_2/TextureButton_2.position -= $HUD/VBoxContainer_2/Control_2/TextureButton_2.size * 0.003
