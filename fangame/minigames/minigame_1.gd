extends Node2D

func _on_zone_fin_body_entered(body):
	if body.name == "Player": # Assure-toi que ton perso s'appelle Player
		# Petit délai ou son de glitch avant de quitter
		# $Audio_Glitch.play()
		# await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://main_menu.tscn")
