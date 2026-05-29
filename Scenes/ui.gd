extends CanvasLayer

const game_manager = preload("res://Scenes/game_manager.gd")
@export var player_id: int = 0

@onready var resource_label = $HUD/VBoxContainer/HBoxContainer/ResourceLabel
@onready var health_bar = $HUD/MarginContainer/HealthBar
@onready var health_percentage_label = $HUD/MarginContainer/HealthBar/Label
@onready var Heavy_Cost = $HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button/HBoxContainer/Precio_Heavy
@onready var Warrior_Cost = $HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button/HBoxContainer/Precio_Warrior
@onready var Archer_Cost = $HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button/HBoxContainer/Precio_Archer
@onready var Miner_Cost = $HUD/VBoxContainer/HBoxContainer2/Roman_Miner_Button/HBoxContainer/Precio_Miner

#Mouses
var Heavy_Mouse=load("res://Assets/UI/Mouses/Mouse_Heavy.png")
var Warrior_Mouse=load("res://Assets/UI/Mouses/Mouse_Warrior.png")
var Archer_Mouse=load("res://Assets/UI/Mouses/Mouse_Archer.png")
var Default_Mouse=load("res://Assets/UI/Mouses/Mouse_Default.png")

var player_data
# Tipo de unidad seleccionado para spawn al hacer click
var selected_unit_type = null

func _ready():
	await get_tree().process_frame

	# Tomar el equipo del jugador local elegido en el lobby.
	var current = Game.get_current_player()
	if current:
		player_id = Statics.role_to_team_id(current.role)

	player_data = GameManager.get_player(player_id)

	if player_data:
		player_data.gold_changed.connect(update_gold)
		update_gold(player_data.gold)
		_setup_castle_link()
		# Registra la UI en un grupo para acceder facilmente desde el mundo 3D
		add_to_group("UI_Nodes")
	Set_Prices()

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
	resource_label.text = "Oro: " + str(amount)
	
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

# Conecta la senal pressed los botones al tipo de unidad seleccionado
func select_unit_to_spawn(unit_type: Statics.UnitType):
	selected_unit_type = unit_type

#Heavy
func _on_roman_heavy_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.HEAVY)
	Input.set_custom_mouse_cursor(Heavy_Mouse)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(0.7, 0.7, 0.7)

func _on_roman_heavy_button_mouse_entered():
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(0.8, 0.8, 0.8)
	
func _on_roman_heavy_button_mouse_exited():
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)
	
func _on_roman_heavy_button_button_down() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(0.7, 0.7, 0.7)
	
func _on_roman_heavy_button_button_up() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Heavy_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	

#Warrior
func _on_roman_warrior_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.WARRIOR)
	Input.set_custom_mouse_cursor(Warrior_Mouse)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.7, 0.7, 0.7)
	
func _on_roman_warrior_button_mouse_entered() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)
	
func _on_roman_warrior_button_mouse_exited() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)

func _on_roman_warrior_button_button_down() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.7, 0.7, 0.7)


func _on_roman_warrior_button_button_up() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Warrior_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)
	
#Archer
func _on_roman_archer_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.ARCHER)
	Input.set_custom_mouse_cursor(Archer_Mouse)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.7, 0.7, 0.7)

func _on_roman_archer_button_mouse_entered() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.9, 0.9, 0.9)


func _on_roman_archer_button_mouse_exited() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(1.0, 1.0, 1.0)


func _on_roman_archer_button_button_down() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(0.8, 0.8, 0.8)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.7, 0.7, 0.7)

func _on_roman_archer_button_button_up() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button.self_modulate = Color(1.353, 1.353, 1.353)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Archer_Button/TextureRect.self_modulate = Color(0.8, 0.8, 0.8)

#Minero
func _on_roman_miner_button_pressed() -> void:
	select_unit_to_spawn(Statics.UnitType.MINER)
	# No hay cursor propio para el minero; se usa el cursor por defecto.
	Input.set_custom_mouse_cursor(Default_Mouse)
	$HUD/VBoxContainer/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(0.8, 0.8, 0.8)

func _on_roman_miner_button_mouse_entered() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(0.8, 0.8, 0.8)

func _on_roman_miner_button_mouse_exited() -> void:
	$HUD/VBoxContainer/HBoxContainer2/Roman_Miner_Button.self_modulate = Color(1.353, 1.353, 1.353)
