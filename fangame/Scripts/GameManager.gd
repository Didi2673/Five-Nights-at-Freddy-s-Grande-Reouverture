extends Node

func _process(delta):
	# "ui_cancel" est mappé sur ECHAP par défaut dans Godot
	if Input.is_action_just_pressed("ui_cancel"):
		quit_game()
		
	if Input.is_physical_key_pressed(KEY_F2):
		soft_reset()

func quit_game():
	print("Fermeture du jeu via Echap.")
	get_tree().quit()
	
func soft_reset():
	print(">>> RESET F2 : Retour au menu principal <<<")
	
	# Optionnel : Si tu as des variables globales temporaires dans GameData à nettoyer, fais-le ici.
	# Par exemple, si tu veux reset le niveau de batterie global ou autre.
	# Mais généralement, recharger la scène suffit.
	
	# On recharge la scène du menu principal
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	
func _input(event):
	if event.is_action_pressed("toggle_fullscreen"): # Crée cette action dans Input Map (F11)
		var mode_actuel = DisplayServer.window_get_mode()
		if mode_actuel == DisplayServer.WINDOW_MODE_MAXIMIZED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
