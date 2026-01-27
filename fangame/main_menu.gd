extends Control

# --- REFERENCES ---
@onready var ecran_accueil = $Ecran_Accueil
@onready var ecran_selection = $Ecran_Selection
@onready var liste_nuits_container = $Ecran_Selection/Liste_Nuits

@onready var label_duree = $Ecran_Selection/Panneau_Details/Label_Duree 

# Panneau Détails
@onready var label_titre = $Ecran_Selection/Panneau_Details/Label_Titre_Nuit
@onready var label_desc = $Ecran_Selection/Panneau_Details/Label_Description
@onready var label_difficulte = $Ecran_Selection/Panneau_Details/Label_Difficulte
@onready var btn_lancer = $Ecran_Selection/Panneau_Details/Bouton_Lancer_Nuit

@onready var ecran_transition = $Ecran_Transition
@onready var label_trans_nuit = $Ecran_Transition/Label_Nuit_Transition
@onready var audio_transition = $Ecran_Transition/Audio_Transition

@onready var audio_hover = $Audio_Hover

@onready var container_custom = $Ecran_Selection/Panneau_Details/Grid_Custom_Night

var font_custom = load("res://vcr_osd_mono.ttf")

var nuit_selectionnee_temp : int = 1

func _ready():
	if ecran_transition:
		ecran_transition.visible = false
		
	if container_custom:
		container_custom.visible = false
		preparer_interface_custom()
		
	ecran_accueil.visible = true
	ecran_selection.visible = false
	
	if btn_lancer:
		btn_lancer.mouse_entered.connect(_jouer_son_hover)
	
	var btn_retour = $Ecran_Selection/Bouton_Retour
	if btn_retour:
		btn_retour.mouse_entered.connect(_jouer_son_hover)
		btn_retour.pressed.connect(_on_retour_accueil)

	var btn_quit = ecran_accueil.find_child("Bouton_Quitter", true, false)
	if btn_quit:
		btn_quit.mouse_entered.connect(_jouer_son_hover)
		btn_quit.pressed.connect(_on_bouton_quitter_pressed)
		
	var btn_play = ecran_accueil.find_child("Bouton_Play", true, false)
	if btn_play:
		btn_play.mouse_entered.connect(_jouer_son_hover)
		btn_play.pressed.connect(_on_aller_vers_selection)
		
	btn_lancer.pressed.connect(_on_lancer_nuit)
	
	update_details_panel(0) 

func preparer_interface_custom():
	# On nettoie d'abord
	for child in container_custom.get_children():
		child.queue_free()
	
	# --- 1. CONFIGURATION DE LA GRILLE ---
	container_custom.columns = 4 # <--- 4 ANIMATRONIQUES PAR LIGNE
	
	# On espacement les éléments (Horizontal et Vertical)
	container_custom.add_theme_constant_override("h_separation", 30)
	container_custom.add_theme_constant_override("v_separation", 30)
	
	# Pour chaque animatronique du jeu
	for data in GameData.animatronics_data:
		var nom_bot = data["name"]
		
		if nom_bot == "Springtrap": 
			continue
		# --- 2. LE CONTENEUR DU ROBOT (LA "CARTE") ---
		var boite_robot = VBoxContainer.new()
		# On force une taille minimale pour que ça prenne de la place
		boite_robot.custom_minimum_size = Vector2(180, 100) 
		# On centre le contenu
		boite_robot.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# --- A. NOM DU ROBOT ---
		var lbl_nom = Label.new()
		lbl_nom.text = nom_bot
		lbl_nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Style du nom (Gros et gras si possible)
		if font_custom: 
			lbl_nom.add_theme_font_override("font", font_custom)
			lbl_nom.add_theme_font_size_override("font_size", 25) # <--- NOM PLUS GRAND
		else:
			lbl_nom.add_theme_font_size_override("font_size", 20)
			
		boite_robot.add_child(lbl_nom)
		
		# --- B. SÉLECTEUR (HBox) ---
		var boite_selecteur = HBoxContainer.new()
		boite_selecteur.alignment = BoxContainer.ALIGNMENT_CENTER
		# Un peu d'espace entre les boutons et le nombre
		boite_selecteur.add_theme_constant_override("separation", 15) 
		
		# Bouton Moins
		var btn_minus = Button.new()
		btn_minus.text = "<"
		# GROS BOUTON CARRÉ
		btn_minus.custom_minimum_size = Vector2(40, 40) 
		btn_minus.pressed.connect(_on_change_ai.bind(nom_bot, -1, boite_selecteur))
		btn_minus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Label Valeur (0)
		var lbl_val = Label.new()
		lbl_val.text = "0"
		lbl_val.name = "Label_AI"
		# LARGEUR FIXE pour ne pas que ça bouge quand on passe de 9 à 10
		lbl_val.custom_minimum_size.x = 40 
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# GROS CHIFFRE
		if font_custom: 
			lbl_val.add_theme_font_override("font", font_custom)
			lbl_val.add_theme_font_size_override("font_size", 50) # <--- CHIFFRE ENORME
		else:
			lbl_val.add_theme_font_size_override("font_size", 28)
		
		# Bouton Plus
		var btn_plus = Button.new()
		btn_plus.text = ">"
		# GROS BOUTON CARRÉ
		btn_plus.custom_minimum_size = Vector2(40, 40)
		btn_plus.pressed.connect(_on_change_ai.bind(nom_bot, 1, boite_selecteur))
		btn_plus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		boite_selecteur.add_child(btn_minus)
		boite_selecteur.add_child(lbl_val)
		boite_selecteur.add_child(btn_plus)
		
		boite_robot.add_child(boite_selecteur)
		
		# Ajout à la grille
		container_custom.add_child(boite_robot)
		
		# Initialiser la valeur
		if not GameData.custom_night_levels.has(nom_bot):
			GameData.custom_night_levels[nom_bot] = 0

# --- 2. GESTION DU CLIC (+ / -) ---
func _on_change_ai(nom_bot, changement, conteneur_ref):
	# 1. Calcul de la nouvelle valeur
	var valeur_actuelle = GameData.custom_night_levels[nom_bot]
	var nouvelle_valeur = clamp(valeur_actuelle + changement, 0, 20)
	
	# 2. Sauvegarde
	GameData.custom_night_levels[nom_bot] = nouvelle_valeur
	
	# 3. Mise à jour visuelle
	var label = conteneur_ref.get_node("Label_AI")
	label.text = str(nouvelle_valeur)
	
	# Couleur selon difficulté
	if nouvelle_valeur == 0: label.modulate = Color.WHITE
	elif nouvelle_valeur <= 10: label.modulate = Color.YELLOW
	elif nouvelle_valeur < 20: label.modulate = Color.ORANGE
	else: label.modulate = Color.RED # 20 = Rouge


# --- NAVIGATION ---
func _on_aller_vers_selection():
	ecran_accueil.visible = false
	ecran_selection.visible = true
	generer_liste_nuits()
	nuit_selectionnee_temp = GameData.unlocked_night
	update_details_panel(GameData.unlocked_night)

func _on_bouton_quitter_pressed():
	print("Fermeture du jeu...")
	get_tree().quit()

func _jouer_son_hover():
	if audio_hover:
		audio_hover.pitch_scale = randf_range(0.9, 1.1)
		audio_hover.play()
		
func _on_retour_accueil():
	ecran_selection.visible = false
	ecran_accueil.visible = true

# --- GÉNÉRATION DE LA LISTE (STYLISTIQUE AMÉLIORÉE) ---
func generer_liste_nuits():
	var total_nuits_json = GameData.nights_data.size()
	
	# 1. CHARGEMENT DE LA POLICE (Une seule fois pour optimiser)
	# Remplace le chemin ci-dessous par le tien !
	var ma_police = load("res://vcr_osd_mono.ttf") 
	
	# Nettoyage
	for child in liste_nuits_container.get_children():
		child.queue_free()
	
	for i in range(1, total_nuits_json + 1):
		var btn = Button.new()
		
		# --- APPLICATION DE LA POLICE ---
		if ma_police:
			# "font" est le nom de la propriété de thème pour la police du texte
			btn.add_theme_font_override("font", ma_police)
			
			# Optionnel : Ajuster la taille si la police est petite/grande
			btn.add_theme_font_size_override("font_size", 24) 
		else:
			print("ERREUR : Police introuvable. Vérifie le chemin !")
		
		# --- RESTE DU STYLE (Comme avant) ---
		btn.custom_minimum_size.y = 55 
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.mouse_entered.connect(_jouer_son_hover)
		
		if i <= GameData.unlocked_night:
			btn.text = "  Nuit " + str(i)
			btn.pressed.connect(_on_nuit_bouton_clicked.bind(i))
		else:
			btn.text = "  ???"
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.5)
		
		liste_nuits_container.add_child(btn)

# --- LOGIQUE DE SÉLECTION & COULEURS ---
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

	var info = GameData.get_night_info(numero_nuit)
	
	if info:
		label_titre.text = info["title"]
		
		# EST-CE UNE NUIT CUSTOM ?
		if info.has("type") and info["type"] == "custom":
			# MODE CUSTOM : On cache la desc, on montre la grille
			label_desc.visible = false
			label_difficulte.visible = false
			label_duree.visible = false
			if container_custom: container_custom.visible = true
			
			# On reset les valeurs à 0 ou on garde les précédentes
			# Pour l'instant on garde les valeurs précédentes
		else:
			# MODE CLASSIQUE : On montre la desc, on cache la grille
			label_desc.visible = true
			label_difficulte.visible = true
			label_duree.visible = true
			label_desc.text = info["description"]
			if container_custom: container_custom.visible = false
		
		# Récupération du texte de difficulté
		var diff_text = info["difficulty_label"]
		label_difficulte.text = "Difficulté : " + diff_text
		
		# --- CHANGEMENT DE COULEUR SELON LA DIFFICULTÉ ---
		# On convertit en minuscule pour éviter les erreurs de majuscules (Facile vs facile)
		match diff_text.to_lower():
			"facile", "easy":
				label_difficulte.modulate = Color.GREEN # Vert
			"normal", "moyen":
				label_difficulte.modulate = Color.YELLOW # Jaune
			"difficile", "hard":
				label_difficulte.modulate = Color(1, 0.2, 0.2) # Rouge
			"extrême", "extreme", "cauchemar":
				label_difficulte.modulate = Color(0.6, 0, 0) # Rouge Sang / Foncé
			_:
				label_difficulte.modulate = Color.WHITE # Blanc par défaut
		
		if label_duree:
			label_duree.text = "Durée : " + info["display_duration_text"]
			
		btn_lancer.disabled = false
	else:
		print("Erreur : Pas d'info pour la nuit ", numero_nuit)

# --- LANCEMENT DU JEU ---
func _on_lancer_nuit():
	print("Lancement de la transition pour la nuit ", nuit_selectionnee_temp)
	
	GameData.current_night_played = nuit_selectionnee_temp
	
	if label_trans_nuit:
		label_trans_nuit.text = "Nuit " + str(nuit_selectionnee_temp)
	
	if ecran_transition:
		ecran_transition.visible = true
		ecran_transition.z_index = 4096 
	
	if audio_transition:
		audio_transition.play()
	
	await get_tree().create_timer(2.5).timeout
	
	get_tree().change_scene_to_file("res://office.tscn")
