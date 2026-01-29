extends Control

func _ready():
	await get_tree().create_timer(3.0).timeout
	charger_menu()

func _input(event):
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
		charger_menu()

func charger_menu():
	get_tree().change_scene_to_file("res://main_menu.tscn")
