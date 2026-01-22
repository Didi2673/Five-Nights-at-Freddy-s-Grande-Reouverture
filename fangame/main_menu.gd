extends Control

# --- REFERENCES (Basées sur ta capture d'écran) ---
@onready var ecran_accueil = $Ecran_Accueil
@onready var ecran_selection = $Ecran_Selection
@onready var liste_nuits_container = $Ecran_Selection/Liste_Nuits

@onready var label_duree = $Ecran_Selection/Panneau_Details/Label_Duree # Assure-toi d'avoir ce label

# Panneau Détails
@onready var label_titre = $Ecran_Selection/Panneau_Details/Label_Titre_Nuit
@onready var label_desc = $Ecran_Selection/Panneau_Details/Label_Description
@onready var label_difficulte = $Ecran_Selection/Panneau_Details/Label_Difficulte
@onready var btn_lancer = $Ecran_Selection/Panneau_Details/Bouton_Lancer_Nuit

# Variable pour savoir quelle nuit est sélectionnée (mais pas encore lancée)
var nuit_selectionnee_temp : int = 1

func _ready():
	# Initialisation : On affiche l'accueil, on cache la sélection
	ecran_accueil.visible = true
	ecran_selection.visible = false
	
	# Connecter le bouton "Jouer" de l'accueil (s'il existe)
	# Supposons qu'il s'appelle "Bouton_Jouer" dans Ecran_Accueil
	var btn_play = ecran_accueil.find_child("Bouton_Jouer", true, false)
	if btn_play:
		btn_play.pressed.connect(_on_aller_vers_selection)
	
	# Connecter le bouton retour et lancer
	$Ecran_Selection/Bouton_Retour.pressed.connect(_on_retour_accueil)
	btn_lancer.pressed.connect(_on_lancer_nuit)
	
	# On vide le panneau de détails au début
	update_details_panel(0) 

# --- NAVIGATION ---
func _on_aller_vers_selection():
	ecran_accueil.visible = false
	ecran_selection.visible = true
	generer_liste_nuits()
	
	# Optionnel : Pré-sélectionner la dernière nuit débloquée
	update_details_panel(GameData.unlocked_night)

func _on_bouton_quitter_pressed():
	print("Fermeture du jeu...")
	get_tree().quit()

func _on_retour_accueil():
	ecran_selection.visible = false
	ecran_accueil.visible = true

# --- GÉNÉRATION DE LA LISTE ---
func generer_liste_nuits():
	var total_nuits_json = GameData.nights_data.size()
	
	# 1. On nettoie la liste précédente
	for child in liste_nuits_container.get_children():
		child.queue_free()
	
	# 2. On crée les boutons
	for i in range(1, total_nuits_json + 1):
		var btn = Button.new()
		
		# Esthétique : Taille min pour qu'on puisse cliquer
		btn.custom_minimum_size.y = 40 
		
		if i <= GameData.unlocked_night:
			# Nuit DÉBLOQUÉE
			btn.text = "Nuit " + str(i)
			# Quand on clique, ça AFFICHE les détails (ça ne lance pas le jeu)
			btn.pressed.connect(_on_nuit_bouton_clicked.bind(i))
		else:
			# Nuit BLOQUÉE
			btn.text = "???"
			btn.disabled = true
		
		liste_nuits_container.add_child(btn)

# --- LOGIQUE DE SÉLECTION ---
func _on_nuit_bouton_clicked(numero_nuit):
	nuit_selectionnee_temp = numero_nuit
	update_details_panel(numero_nuit)

func update_details_panel(numero_nuit):
	if numero_nuit == 0:
		label_titre.text = "Sélectionnez une nuit"
		label_desc.text = ""
		label_difficulte.text = ""
		label_duree.text = ""
		btn_lancer.disabled = true
		return

	# 1. On récupère les infos depuis GameData
	var info = GameData.get_night_info(numero_nuit)
	
	if info:
		# 2. On remplit les labels avec les clés du JSON
		label_titre.text = info["title"] # "Nuit X"
		label_desc.text = info["description"]
		label_difficulte.text = "Difficulté : " + info["difficulty_label"]
		
		# Si tu as un Label pour la durée ("6 minutes")
		if label_duree:
			label_duree.text = "Durée : " + info["display_duration_text"]
			
		btn_lancer.disabled = false
	else:
		print("Erreur : Pas d'info pour la nuit ", numero_nuit)

# --- LANCEMENT DU JEU ---
func _on_lancer_nuit():
	print("Lancement de la nuit ", nuit_selectionnee_temp)
	
	# 1. On enregistre la nuit choisie dans les données globales
	GameData.current_night_played = nuit_selectionnee_temp
	
	# 2. On change de scène
	get_tree().change_scene_to_file("res://office.tscn")
