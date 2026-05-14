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
	velocity = global_position.direction_to(next_pos) * move_speed
	move_and_slide()

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
