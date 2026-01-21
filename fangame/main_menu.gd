extends Control

# --- RÉFÉRENCES ---
# Glisse les noeuds depuis l'arbre vers le script pour remplir ces variables
@onready var ecran_accueil = $Ecran_Accueil
@onready var ecran_selection = $Ecran_Selection
@onready var liste_container = $Ecran_Selection/Liste_Nuits

# Les labels d'infos
@onready var label_titre = $Ecran_Selection/Panneau_Details/Label_Titre_Nuit
@onready var label_desc = $Ecran_Selection/Panneau_Details/Label_Description
@onready var label_duree = $Ecran_Selection/Panneau_Details/Label_Duree
@onready var label_diff = $Ecran_Selection/Panneau_Details/Label_Difficulte
@onready var btn_lancer = $Ecran_Selection/Panneau_Details/Bouton_Lancer_Nuit

# Variable temporaire pour savoir sur quoi on a cliqué
var index_selection_temp : int = -1

func _ready():
	# On s'assure que l'accueil est visible et la sélection cachée
	ecran_accueil.visible = true
	ecran_selection.visible = false
	btn_lancer.disabled = true # On ne peut pas lancer tant qu'on n'a pas choisi une nuit

# --- BOUTONS ACCUEIL ---

func _on_bouton_play_pressed():
	ecran_accueil.visible = false
	ecran_selection.visible = true
	generer_liste_nuits()

func _on_bouton_quitter_pressed():
	get_tree().quit()

# --- LOGIQUE DE SÉLECTION ---

func generer_liste_nuits():
	# 1. On nettoie la liste (au cas où on ouvre le menu 2 fois)
	for enfant in liste_container.get_children():
		enfant.queue_free()
	
	# 2. On boucle sur les données chargées dans GameData
	var nuits = GameData.nights_data
	
	for i in range(nuits.size()):
		var info_nuit = nuits[i]
		
		# Création dynamique d'un bouton
		var nouveau_bouton = Button.new()
		nouveau_bouton.text = info_nuit["title"] # Ex: "Nuit 1"
		nouveau_bouton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# MAGIE : On connecte le signal "pressed" en lui passant l'index 'i'
		# Cela veut dire : "Quand on clique, appelle _on_nuit_choisie avec le numéro i"
		nouveau_bouton.pressed.connect(_on_nuit_choisie.bind(i))
		
		liste_container.add_child(nouveau_bouton)

func _on_nuit_choisie(index : int):
	index_selection_temp = index
	
	# On récupère les infos
	var data = GameData.nights_data[index]
	
	# On met à jour l'affichage
	label_titre.text = data["title"]
	label_desc.text = "Description : " + data["description"]
	label_duree.text = "Durée : " + data["display_duration_text"]
	label_diff.text = "Difficulté : " + data["difficulty_label"]
	
	# On débloque le bouton jouer
	btn_lancer.disabled = false

# --- LANCEMENT DU JEU ---

func _on_bouton_lancer_nuit_pressed():
	if index_selection_temp != -1:
		# 1. On enregistre le choix dans le Singleton
		GameData.index_nuit_selectionnee = index_selection_temp
		
		# 2. On change de scène vers le bureau
		# CHANGE LE CHEMIN SI TA SCÈNE S'APPELLE AUTREMENT
		get_tree().change_scene_to_file("res://office.tscn") 

func _on_bouton_retour_pressed():
	ecran_selection.visible = false
	ecran_accueil.visible = true
