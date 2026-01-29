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

@onready var etoile_1 = $Ecran_Accueil/Container_Etoiles/Etoile_1
@onready var etoile_2 = $Ecran_Accueil/Container_Etoiles/Etoile_2
@onready var etoile_3 = $Ecran_Accueil/Container_Etoiles/Etoile_3

@onready var ecran_transition = $Ecran_Transition
@onready var label_trans_nuit = $Ecran_Transition/Label_Nuit_Transition
@onready var audio_transition = $Ecran_Transition/Audio_Transition

@onready var audio_hover = $Audio_Hover

@onready var ecran_succes = $Ecran_Succes
@onready var grid_succes = $Ecran_Succes/ScrollContainer/Grid_Succes
# Charge une icone par défaut si tu n'as pas encore créé les images
@onready var icon_defaut = preload("res://icon.svg")

@onready var container_custom = $Ecran_Selection/Panneau_Details/Grid_Custom_Night

var font_custom = load("res://vcr_osd_mono.ttf")

var nuit_selectionnee_temp : int = 1

func _ready():
	if ecran_transition:
		ecran_transition.visible = false
		
	if ecran_succes: 
		ecran_succes.visible = false
		
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
		
	var btn_succes_accueil = ecran_accueil.find_child("Bouton_Succes", true, false)
	if btn_succes_accueil:
		btn_succes_accueil.pressed.connect(_on_aller_vers_succes)
		btn_succes_accueil.mouse_entered.connect(_jouer_son_hover)

	# Connexion du bouton "Retour" (sur l'écran succès)
	var btn_retour_succes = ecran_succes.find_child("Bouton_Retour", true, false)
	if btn_retour_succes:
		btn_retour_succes.pressed.connect(_on_retour_accueil_depuis_succes)
		btn_retour_succes.mouse_entered.connect(_jouer_son_hover)
		
	btn_lancer.pressed.connect(_on_lancer_nuit)
	verifier_etoiles()
	update_details_panel(0) 
	
func _on_aller_vers_succes():
	ecran_accueil.visible = false
	ecran_selection.visible = false # Au cas où
	ecran_succes.visible = true
	
	generer_liste_succes() # On génère la liste à l'ouverture

func _on_retour_accueil_depuis_succes():
	ecran_succes.visible = false
	ecran_accueil.visible = true
	
func generer_liste_succes():
	# 1. Nettoyage de la liste précédente
	for child in grid_succes.get_children():
		child.queue_free()
	
	# 2. Configuration de la grille (Espacement)
	grid_succes.add_theme_constant_override("h_separation", 20)
	grid_succes.add_theme_constant_override("v_separation", 20)
	
	# 3. Boucle sur les données
	for ach in GameData.achievements_data:
		var est_debloque = GameData.unlocked_achievements.has(ach["id"])
		
		# --- LE CONTENEUR (Panel) ---
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(400, 100) # Taille fixe assez large
		
		# --- DISPOSITION (HBox : Icone à gauche | Texte à droite) ---
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 15)
		panel.add_child(hbox)
		
		# A. L'ICONE
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(80, 80)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		if est_debloque:
			# Si débloqué : On charge l'image (si elle existe) sinon défaut
			if ResourceLoader.exists(ach["icon"]):
				icon_rect.texture = load(ach["icon"])
			else:
				icon_rect.texture = icon_defaut
			icon_rect.modulate = Color.WHITE
		else:
			# Si verrouillé : Image sombre ou "?"
			icon_rect.texture = icon_defaut
			icon_rect.modulate = Color(0.1, 0.1, 0.1, 0.5) # Très sombre et transparent
			
		hbox.add_child(icon_rect)
		
		# B. LES TEXTES (VBox : Titre en haut, Description en bas)
		var vbox_text = VBoxContainer.new()
		vbox_text.alignment = BoxContainer.ALIGNMENT_CENTER # Centré verticalement
		vbox_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Prend toute la place restante
		
		var lbl_titre = Label.new()
		var lbl_desc = Label.new()
		
		# Police (si tu veux l'appliquer)
		if font_custom:
			lbl_titre.add_theme_font_override("font", font_custom)
			lbl_desc.add_theme_font_override("font", font_custom)
		
		if est_debloque:
			lbl_titre.text = ach["title"]
			lbl_desc.text = ach["description"]
			lbl_titre.modulate = Color.GREEN # Titre en vert
		else:
			if ach["hidden"]:
				lbl_titre.text = "???"
				lbl_desc.text = "Succès Secret"
			else:
				lbl_titre.text = ach["title"]
				lbl_desc.text = "Verrouillé"
			
			lbl_titre.modulate = Color.GRAY
			lbl_desc.modulate = Color(0.5, 0.5, 0.5)
		
		# Style des textes
		lbl_titre.add_theme_font_size_override("font_size", 22) # Titre gros
		lbl_desc.add_theme_font_size_override("font_size", 16)  # Desc plus petite
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # Retour à la ligne auto
		
		vbox_text.add_child(lbl_titre)
		vbox_text.add_child(lbl_desc)
		
		hbox.add_child(vbox_text)
		
		# Ajout final à la grille
		grid_succes.add_child(panel)

func preparer_interface_custom():
	# On nettoie d'abord
	for child in container_custom.get_children():
		child.queue_free()
	
	# --- 1. CONFIGURATION DE LA GRILLE ---
	container_custom.columns = 4
	container_custom.add_theme_constant_override("h_separation", 30)
	container_custom.add_theme_constant_override("v_separation", 50)
	
	for data in GameData.animatronics_data:
		var nom_bot = data["name"]
		
		# On ignore Springtrap (comme prévu) [cite: 29]
		if nom_bot == "Springtrap": 
			continue
			
		# --- 2. LE CONTENEUR DU ROBOT ---
		var boite_robot = VBoxContainer.new()
		boite_robot.custom_minimum_size = Vector2(180, 150) # J'ai augmenté un peu la hauteur
		boite_robot.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# --- A. IMAGE DE L'ANIMATRONIQUE (Remplacement du Label) ---
		var icon_robot = TextureRect.new()
		
		# Taille de l'image (ajuste selon tes besoins, ex: 100x100)
		icon_robot.custom_minimum_size = Vector2(200, 200) 
		icon_robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_robot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Construction du chemin : "res://ui/custom_icons/Bonnie.png"
		# Assure-toi que ce chemin correspond à ton dossier !
		var chemin_image = "res://IconesAnimatroniques/" + nom_bot + ".webp"
		
		if ResourceLoader.exists(chemin_image):
			icon_robot.texture = load(chemin_image)
		else:
			# Si l'image n'existe pas, on met l'icône par défaut [cite: 24]
			print("Image manquante pour : ", nom_bot)
			icon_robot.texture = icon_defaut 
			
		boite_robot.add_child(icon_robot)
		
		# --- B. SÉLECTEUR (HBox) ---
		var boite_selecteur = HBoxContainer.new()
		boite_selecteur.alignment = BoxContainer.ALIGNMENT_CENTER
		boite_selecteur.add_theme_constant_override("separation", 15) 
		
		# Bouton Moins
		var btn_minus = Button.new()
		btn_minus.text = "<"
		btn_minus.custom_minimum_size = Vector2(40, 40) 
		btn_minus.pressed.connect(_on_change_ai.bind(nom_bot, -1, boite_selecteur))
		btn_minus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		# Label Valeur (0)
		var lbl_val = Label.new()
		lbl_val.text = "0"
		lbl_val.name = "Label_AI"
		lbl_val.custom_minimum_size.x = 40 
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Police du chiffre
		if font_custom: 
			lbl_val.add_theme_font_override("font", font_custom)
			lbl_val.add_theme_font_size_override("font_size", 40) 
		else:
			lbl_val.add_theme_font_size_override("font_size", 28)
		
		# Bouton Plus
		var btn_plus = Button.new()
		btn_plus.text = ">"
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
	
	# --- 1. CALCUL DE LA HAUTEUR DYNAMIQUE ---
	# On récupère la hauteur totale du conteneur (définie dans l'éditeur avec les Ancres/Anchors)
	var hauteur_totale = liste_nuits_container.size.y
	
	# On récupère l'espace entre les boutons (défini dans Theme Overrides > Constants > Separation)
	# Si ce n'est pas défini, Godot utilise 4px par défaut.
	var separation = liste_nuits_container.get_theme_constant("separation")
	
	# Calcul de l'espace total "perdu" par les écarts (Il y a N-1 écarts pour N boutons)
	var total_separation = separation * (total_nuits_json - 1)
	if total_separation < 0: total_separation = 0
	
	# Hauteur restante divisée par le nombre de boutons
	var hauteur_bouton = (hauteur_totale - total_separation) / total_nuits_json
	
	# Petite sécurité pour éviter des boutons minuscules ou négatifs
	if hauteur_bouton < 30: hauteur_bouton = 30 
	
	# --- 2. CHARGEMENT POLICE ---
	var ma_police = load("res://vcr_osd_mono.ttf") 
	
	# Nettoyage
	for child in liste_nuits_container.get_children():
		child.queue_free()
	
	for i in range(1, total_nuits_json + 1):
		var btn = Button.new()
		
		# --- STYLE ---
		if ma_police:
			btn.add_theme_font_override("font", ma_police)
			# On adapte aussi la taille du texte : plus le bouton est petit, plus le texte est petit
			# (C'est optionnel, tu peux garder une taille fixe comme 24)
			var taille_texte = 50
			btn.add_theme_font_size_override("font_size", int(taille_texte))
		
		# --- HAUTEUR DYNAMIQUE ICI ---
		btn.custom_minimum_size.y = hauteur_bouton
		
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
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

func verifier_etoiles():
	# Par sécurité, on cache tout d'abord
	if etoile_1: etoile_1.visible = false
	if etoile_2: etoile_2.visible = false
	if etoile_3: etoile_3.visible = false
	
	# --- ETOILE 1 : Avoir fini la Nuit 5 ---
	# Si on a débloqué la nuit 6 (ou plus), c'est qu'on a fini la 5.
	if GameData.unlocked_night >= 6:
		if etoile_1: etoile_1.visible = true
		
	# --- ETOILE 2 : Avoir fini la Nuit 6 ---
	# Si on a débloqué la nuit 7 (ou plus), c'est qu'on a fini la 6.
	if GameData.unlocked_night >= 7:
		if etoile_2: etoile_2.visible = true
		
	# --- ETOILE 3 : Le défi 20/20/20/20 ---
	# On vérifie si le succès spécifique a été débloqué
	if GameData.unlocked_achievements.has("20_20_mode"):
		if etoile_3: etoile_3.visible = true

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
