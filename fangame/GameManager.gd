extends Node

func _process(delta):
	# "ui_cancel" est mappé sur ECHAP par défaut dans Godot
	if Input.is_action_just_pressed("ui_cancel"):
		quit_game()

func quit_game():
	print("Fermeture du jeu via Echap.")
	get_tree().quit()
	
func _input(event):
	if event.is_action_pressed("toggle_fullscreen"): # Crée cette action dans Input Map (F11)
		var mode_actuel = DisplayServer.window_get_mode()
		if mode_actuel == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
