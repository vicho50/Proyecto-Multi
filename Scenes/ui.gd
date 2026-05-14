extends CanvasLayer

@export var player_id: int = 0

@onready var resource_label = $HUD/MarginContainer/VBoxContainer/HBoxContainer/ResourceLabel
@onready var health_bar = $HUD/MarginContainer/VBoxContainer/HealthBar

var player_data

func _ready():
	await get_tree().process_frame
	player_data = GameManager.get_player(player_id)
	
	if player_data:
		player_data.gold_changed.connect(update_gold)
		update_gold(player_data.gold)
		_setup_castle_link()

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
	t.tween_property(health_bar, "value", curr, 0.2)

func update_gold(amount: int):
	resource_label.text = "Oro: " + str(amount)

func _input(_event):
	if Input.is_key_pressed(KEY_KP_ADD):
		GameManager.add_gold(player_id, 50)
	
	if Input.is_key_pressed(KEY_KP_SUBTRACT):
		var castles = get_tree().get_nodes_in_group("castillo_jugador_" + str(player_id))
		if castles.size() > 0: castles[0].take_damage(10)
