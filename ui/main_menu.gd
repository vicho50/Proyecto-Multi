class_name MainMenu
extends Control


@onready var host: Button = %Host
@onready var join: Button = %Join
@onready var how_to_play: Button = %HowToPlay
@onready var credits: Button = %Credits
@onready var quit: Button = %Quit


func _ready() -> void:
	if Game.multiplayer_test:
		get_tree().change_scene_to_file("res://lobby/lobby_test.tscn")
		return

	quit.pressed.connect(func(): get_tree().quit())
	host.pressed.connect(func(): get_tree().change_scene_to_file("res://lobby/host_screen.tscn"))
	join.pressed.connect(func(): get_tree().change_scene_to_file("res://lobby/join_screen.tscn"))
	how_to_play.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/how_to_play.tscn"))
	credits.pressed.connect(func(): get_tree().change_scene_to_file("res://ui/credits.tscn"))

	host.grab_focus()
