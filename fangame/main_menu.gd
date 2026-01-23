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

@onready var ecran_transition = $Ecran_Transition
@onready var label_trans_nuit = $Ecran_Transition/Label_Nuit_Transition
@onready var audio_transition = $Ecran_Transition/Audio_Transition

@onready var audio_hover = $Audio_Hover

# Variable pour savoir quelle nuit est sélectionnée (mais pas encore lancée)
var nuit_selectionnee_temp : int = 1

func _ready():
	# Initialisation : On affiche l'accueil, on cache la sélection
	if ecran_transition:
		ecran_transition.visible = false
		
	ecran_accueil.visible = true
	ecran_selection.visible = false
	if btn_lancer:
		btn_lancer.mouse_entered.connect(_jouer_son_hover)
	
	# 2. Le bouton "Retour"
	var btn_retour = $Ecran_Selection/Bouton_Retour
	if btn_retour:
		btn_retour.mouse_entered.connect(_jouer_son_hover)
		
	# 3. Le bouton "Jouer" (celui qu'on cherche dynamiquement)

	# 4. Le bouton "Quitter" (si tu en as un)
	var btn_quit = ecran_accueil.find_child("Bouton_Quitter", true, false)
	if btn_quit:
		btn_quit.mouse_entered.connect(_jouer_son_hover)
		
	# Connecter le bouton "Jouer" de l'accueil (s'il existe)
	# Supposons qu'il s'appelle "Bouton_Jouer" dans Ecran_Accueil
	var btn_play = ecran_accueil.find_child("Bouton_Play", true, false)
	if btn_play:
		btn_play.mouse_entered.connect(_jouer_son_hover)
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

func _jouer_son_hover():
	if audio_hover:
		# Petite variation de pitch pour que ce soit moins robotique
		
		audio_hover.play()
		
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
		btn.mouse_entered.connect(_jouer_son_hover)
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
	print("Lancement de la transition pour la nuit ", nuit_selectionnee_temp)
	
	# 1. On enregistre la donnée
	GameData.current_night_played = nuit_selectionnee_temp
	
	# 2. On configure l'écran de transition
	if label_trans_nuit:
		label_trans_nuit.text = "Nuit " + str(nuit_selectionnee_temp)
	
	# 3. On affiche l'écran noir (qui couvre tout le menu)
	if ecran_transition:
		ecran_transition.visible = true
		# Optionnel : S'assurer qu'il est devant tout (Z-Index)
		ecran_transition.z_index = 999 
	
	# 4. On joue le son
	if audio_transition:
		audio_transition.play()
	
	# 5. ON ATTEND (Le délai style FNAF)
	# "await" met le script en pause pendant 2.5 secondes (ajuste selon la longueur de ton son)
	await get_tree().create_timer(2.5).timeout
	
	# 6. Une fois le temps écoulé, on lance vraiment le jeu
	get_tree().change_scene_to_file("res://office.tscn")
