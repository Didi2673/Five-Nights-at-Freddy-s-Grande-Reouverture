extends Control

@onready var image_rect = $ImageFin

func _ready():
	# 1. On charge l'image demandée par GameData
	if GameData.image_fin_a_afficher != "" and ResourceLoader.exists(GameData.image_fin_a_afficher):
		image_rect.texture = load(GameData.image_fin_a_afficher)
	else:
		print("Erreur : Pas d'image de fin définie !")
	
	# 2. On attend 5 à 8 secondes (le temps de lire le chèque)
	await get_tree().create_timer(8.0).timeout
	
	# 3. Retour au menu
	retour_menu()

func _input(event):
	# Permet de passer si on clique ou appuie sur Espace
	if event.is_action_pressed("ui_accept") or event is InputEventMouseButton:
		retour_menu()

func retour_menu():
	# On remet la variable à vide pour la propreté
	GameData.image_fin_a_afficher = ""
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
