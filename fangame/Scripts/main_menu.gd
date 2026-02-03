extends Control

# --- REFERENCES ---
@onready var ecran_accueil = $Ecran_Accueil
@onready var ecran_selection = $Ecran_Selection
@onready var ecran_options = $Ecran_Options
@onready var liste_nuits_container = $Ecran_Selection/Liste_Nuits

@onready var container_touches = $Ecran_Options/Panel/ScrollContainer/Container_Touches
@onready var btn_retour = $Ecran_Options/Panel/Bouton_Retour

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

@onready var ecran_intro_nuit_1 = $ColorRect/Ecran_Intro_Nuit1

@onready var audio_hover = $Audio_Hover

@onready var ecran_succes = $Ecran_Succes
@onready var grid_succes = $Ecran_Succes/ScrollContainer/Grid_Succes
# Charge une icone par défaut si tu n'as pas encore créé les images
@onready var icon_defaut = preload("res://icon.svg")

@onready var container_custom = $Ecran_Selection/Panneau_Details/Grid_Custom_Night

@onready var container_challenges = $Ecran_Selection/Panneau_Details/Liste_Challenges

var actions_a_mapper = {
	"input_light_left": "Lumière Gauche",
	"input_light_right": "Lumière Droite",
	"input_door_left": "Porte Gauche",
	"input_door_right": "Porte Droite",
	"input_seal_vent": "Sceller Ventilation",
	"toggle_monitor": "Moniteur (Ouvrir/Fermer)",
	"toggle_fan": "Ventilateur (On/Off)",
	"toggle_silent_fan": "Ventilo Silencieux",
	"toggle_fullscreen": "Plein Écran"
}
var action_en_cours_de_modif : String = ""
var bouton_en_cours_de_modif : Button = null

var font_custom = load("res://vcr_osd_mono.ttf")

var nuit_selectionnee_temp : int = 1

func _ready():
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if ecran_transition:
		ecran_transition.visible = false
		
	if ecran_succes: 
		ecran_succes.visible = false
		
	if ecran_intro_nuit_1: 
		ecran_intro_nuit_1.visible = false
		
	
	if container_custom:
		container_custom.visible = false
		preparer_interface_custom()
	
	if container_challenges:
		generer_liste_challenges()
		container_challenges.visible = false
		
	ecran_accueil.visible = true
	ecran_selection.visible = false
	ecran_options.visible = false
	
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
		
	var btn_options = ecran_accueil.find_child("Bouton_Options", true, false)
	if btn_options:
		btn_options.mouse_entered.connect(_jouer_son_hover)
		btn_options.pressed.connect(_on_bouton_options_pressed)
		
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
		
	if btn_retour:
		btn_retour.pressed.connect(_on_retour_pressed)
	
	creer_liste_boutons()
		
	btn_lancer.pressed.connect(_on_lancer_nuit)
	verifier_etoiles()
	update_details_panel(0) 
	
	
func creer_liste_boutons():
	# 1. On nettoie la liste existante
	for child in container_touches.get_children():
		child.queue_free()
	
	# 2. On crée une ligne pour chaque action
	for action_id in actions_a_mapper:
		var nom_lisible = actions_a_mapper[action_id]
		
		# Création d'un conteneur horizontal
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size.y = 50 # Un peu plus de hauteur pour aérer
		
		# A. Le Nom de l'action
		var lbl = Label.new()
		lbl.text = nom_lisible
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# --- AJOUT STYLE ---
		if font_custom:
			lbl.add_theme_font_override("font", font_custom)
			lbl.add_theme_font_size_override("font_size", 24)
		# -------------------
		
		hbox.add_child(lbl)
		
		# B. Le Bouton avec la touche actuelle
		var btn = Button.new()
		btn.custom_minimum_size.x = 200 # Bouton un peu plus large
		btn.toggle_mode = true
		btn.text = recuperer_nom_touche_actuelle(action_id)
		
		# --- AJOUT STYLE ---
		if font_custom:
			btn.add_theme_font_override("font", font_custom)
			btn.add_theme_font_size_override("font_size", 24)
		# -------------------
		
		btn.pressed.connect(_on_remap_button_pressed.bind(action_id, btn))
		
		hbox.add_child(btn)
		container_touches.add_child(hbox)

func recuperer_nom_touche_actuelle(action_id):
	var events = InputMap.action_get_events(action_id)
	if events.size() > 0:
		# On prend le premier événement (souvent une touche clavier)
		var event = events[0]
		if event is InputEventKey:
			return OS.get_keycode_string(event.keycode)
		elif event is InputEventMouseButton:
			return "Souris " + str(event.button_index)
	return "Aucune"

func _on_remap_button_pressed(action_id, bouton_ref):
	# Si on clique sur un bouton, on passe en mode "Écoute"
	action_en_cours_de_modif = action_id
	bouton_en_cours_de_modif = bouton_ref
	
	bouton_ref.text = "Appuyez..."
	
	# On désactive les autres boutons pour éviter les conflits
	set_process_input(true)
	
func _input(event):
	# Si on n'est pas en train de modifier, on ne fait rien
	if action_en_cours_de_modif == "": return
	
	# On cherche une pression de touche clavier
	if event is InputEventKey and event.pressed:
		
		# Annulation avec ECHAP
		if event.keycode == KEY_ESCAPE:
			cancel_remap()
			return
			
		# --- APPLICATION DE LA NOUVELLE TOUCHE ---
		
		# 1. On supprime l'ancienne touche
		InputMap.action_erase_events(action_en_cours_de_modif)
		
		# 2. On ajoute la nouvelle
		InputMap.action_add_event(action_en_cours_de_modif, event)
		
		# 3. Mise à jour visuelle
		bouton_en_cours_de_modif.text = OS.get_keycode_string(event.keycode)
		bouton_en_cours_de_modif.button_pressed = false # Relâche le bouton visuellement
		
		# 4. Sauvegarde
		GameData.save_keybinds() 
		
		# 5. Reset
		action_en_cours_de_modif = ""
		bouton_en_cours_de_modif = null
		
		# On "consomme" l'événement pour qu'il ne déclenche rien d'autre dans le jeu
		get_viewport().set_input_as_handled()

func cancel_remap():
	if bouton_en_cours_de_modif:
		bouton_en_cours_de_modif.text = recuperer_nom_touche_actuelle(action_en_cours_de_modif)
		bouton_en_cours_de_modif.button_pressed = false
	
	action_en_cours_de_modif = ""
	bouton_en_cours_de_modif = null

func _on_retour_pressed():
	# Masquer le menu options et réafficher le menu principal
	ecran_options.visible = false
	ecran_accueil.visible = true

func generer_liste_challenges():
	# Nettoyage
	for child in container_challenges.get_children():
		child.queue_free()
	
	for challenge in GameData.challenges_list:
		var btn = Button.new()
		
		# --- MODIFICATIONS ICI ---
		# 1. Application de la police importée (.ttf)
		if font_custom:
			btn.add_theme_font_override("font", font_custom)
		
		# 2. Augmentation de la taille de la police (Changez 24 par ce que vous voulez)
		btn.add_theme_font_size_override("font_size", 35) 
		
		# Optionnel : Augmenter un peu la hauteur du bouton pour que le gros texte rentre bien
		btn.custom_minimum_size.y = 40 
		# -------------------------
		
		btn.text = challenge["name"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Si le challenge est réussi
		if challenge["id"] in GameData.completed_challenges:
			#btn.text += " [★]"
			btn.modulate = Color.GREEN
		
		# Connexion du signal
		btn.pressed.connect(_on_challenge_clicked.bind(challenge))
		
		# Curseur main au survol (plus joli)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		
		container_challenges.add_child(btn)

func _on_challenge_clicked(challenge_data):
	print("Challenge sélectionné : ", challenge_data["name"])
	GameData.active_challenge_id = challenge_data["id"]
	
	# 1. Mise à jour des données (Logique)
	if challenge_data["id"] == "custom":
		# Reset à 0
		for key in GameData.custom_night_levels:
			GameData.custom_night_levels[key] = 0
	else:
		# Applique les niveaux du challenge
		# D'abord reset à 0 pour ceux qui ne sont pas dans le challenge
		for key in GameData.custom_night_levels:
			GameData.custom_night_levels[key] = 0
			
		var niveaux_impose = challenge_data["levels"]
		for robot_nom in niveaux_impose:
			GameData.custom_night_levels[robot_nom] = niveaux_impose[robot_nom]
	
	# 2. Reconstruire l'interface visuelle
	# Cela va appeler preparer_interface_custom qui va lire les nouvelles données
	# et appliquer les bons chiffres et l'état désactivé/activé des boutons.
	rafraichir_valeurs_visuelles()

func rafraichir_valeurs_visuelles():
	# Cette fonction parcourt ton interface pour mettre à jour les textes "0", "10", "20"
	# en lisant GameData.custom_night_levels.
	# Tu devras peut-être adapter ton code existant pour retrouver les Labels.
	# Une astuce est de nommer les labels "Label_NomDuRobot" ou de les mettre dans un dictionnaire lors de la création.
	
	# Exemple simple si tu refais la boucle de création :
	preparer_interface_custom()
	
func _on_aller_vers_succes():
	ecran_accueil.visible = false
	ecran_selection.visible = false # Au cas où
	ecran_succes.visible = true
	ecran_options.visible = false
	
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
	
	container_custom.columns = 4 
	container_custom.add_theme_constant_override("h_separation", 30)
	container_custom.add_theme_constant_override("v_separation", 50)
	
	# Est-ce qu'on est dans un challenge ? (Si oui, on désactive les boutons)
	var est_en_challenge = (GameData.active_challenge_id != "custom")
	
	for data in GameData.animatronics_data:
		var nom_bot = data["name"]
		
		if nom_bot == "Springtrap": continue
			
		var boite_robot = VBoxContainer.new()
		boite_robot.custom_minimum_size = Vector2(180, 150)
		boite_robot.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# --- IMAGE ---
		var icon_robot = TextureRect.new()
		icon_robot.custom_minimum_size = Vector2(200, 200) 
		icon_robot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_robot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var chemin_image = "res://IconesAnimatroniques/" + nom_bot + ".webp"
		if ResourceLoader.exists(chemin_image):
			icon_robot.texture = load(chemin_image)
		else:
			icon_robot.texture = icon_defaut 
			
		boite_robot.add_child(icon_robot)
		
		# --- SÉLECTEUR ---
		var boite_selecteur = HBoxContainer.new()
		boite_selecteur.alignment = BoxContainer.ALIGNMENT_CENTER
		boite_selecteur.add_theme_constant_override("separation", 15) 
		
		# Bouton Moins
		var btn_minus = Button.new()
		btn_minus.text = "<"
		btn_minus.custom_minimum_size = Vector2(40, 40) 
		btn_minus.pressed.connect(_on_change_ai.bind(nom_bot, -1, boite_selecteur))
		btn_minus.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn_minus.add_to_group("boutons_ai")
		
		# --- CORRECTION 1 : Désactiver si challenge ---
		btn_minus.disabled = est_en_challenge 
		
		# Label Valeur
		var lbl_val = Label.new()
		lbl_val.name = "Label_AI"
		
		# --- CORRECTION 2 : Lire la valeur actuelle au lieu de mettre "0" ---
		var niveau_actuel = 0
		if GameData.custom_night_levels.has(nom_bot):
			niveau_actuel = GameData.custom_night_levels[nom_bot]
		else:
			GameData.custom_night_levels[nom_bot] = 0 # Init si inexistant
			
		lbl_val.text = str(niveau_actuel)
		
		# Couleur du texte selon la difficulté
		update_label_color(lbl_val, niveau_actuel)
		# -------------------------------------------------------------------

		lbl_val.custom_minimum_size.x = 40 
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
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
		btn_plus.add_to_group("boutons_ai")
		
		# --- CORRECTION 1 : Désactiver si challenge ---
		btn_plus.disabled = est_en_challenge
		
		boite_selecteur.add_child(btn_minus)
		boite_selecteur.add_child(lbl_val)
		boite_selecteur.add_child(btn_plus)
		
		boite_robot.add_child(boite_selecteur)
		container_custom.add_child(boite_robot)

# Petite fonction utilitaire pour ne pas dupliquer le code des couleurs
func update_label_color(label, valeur):
	if valeur == 0: label.modulate = Color.WHITE
	elif valeur <= 10: label.modulate = Color.YELLOW
	elif valeur < 20: label.modulate = Color.ORANGE
	else: label.modulate = Color.RED

# --- 2. GESTION DU CLIC (+ / -) ---
func _on_change_ai(nom_bot, changement, conteneur_ref):
	var valeur_actuelle = GameData.custom_night_levels[nom_bot]
	var nouvelle_valeur = clamp(valeur_actuelle + changement, 0, 20)
	
	GameData.custom_night_levels[nom_bot] = nouvelle_valeur
	
	var label = conteneur_ref.get_node("Label_AI")
	label.text = str(nouvelle_valeur)
	
	# Utilisation de la fonction utilitaire créée plus haut
	update_label_color(label, nouvelle_valeur)


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
	if GameData.completed_challenges.size() > 0:
		etoile_3.visible = true

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
			if container_challenges: container_challenges.visible = true
			
			# On reset les valeurs à 0 ou on garde les précédentes
			# Pour l'instant on garde les valeurs précédentes
		else:
			# MODE CLASSIQUE : On montre la desc, on cache la grille
			label_desc.visible = true
			label_difficulte.visible = true
			label_duree.visible = true
			label_desc.text = info["description"]
			if container_custom: container_custom.visible = false
			if container_challenges: container_challenges.visible = false
		
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
	
	if nuit_selectionnee_temp == 1:
		if ecran_intro_nuit_1:
			# 1. On prépare l'image : Visible mais totalement transparente
			$ColorRect.visible = true
			ecran_intro_nuit_1.modulate.a = 0.0 
			ecran_intro_nuit_1.visible = true
			
			# 2. On crée le Tween (l'animateur)
			var tween = create_tween()
			
			# ÉTAPE A : Fondu d'entrée (passe de 0 à 1 en 1.0 seconde)
			tween.tween_property(ecran_intro_nuit_1, "modulate:a", 1.0, 1.0)
			
			# ÉTAPE B : On attend 3 secondes (temps de lecture)
			tween.tween_interval(3.0)
			
			# ÉTAPE C : Fondu de sortie (passe de 1 à 0 en 1.0 seconde)
			tween.tween_property(ecran_intro_nuit_1, "modulate:a", 0.0, 1.0)
			
			# 3. On attend que TOUTE l'animation soit finie
			await tween.finished
			
			# 4. On cache l'écran pour la propreté
			ecran_intro_nuit_1.visible = false
			$ColorRect.visible = false
	
	if label_trans_nuit:
		label_trans_nuit.text = "Nuit " + str(nuit_selectionnee_temp)
	
	if ecran_transition:
		ecran_transition.visible = true
		ecran_transition.z_index = 4096 
	
	if audio_transition:
		audio_transition.play()
	
	await get_tree().create_timer(2.5).timeout
	
	get_tree().change_scene_to_file("res://Scenes/office.tscn")


func _on_bouton_options_pressed() -> void:
	ecran_accueil.visible = false
	ecran_selection.visible = false # Au cas où
	ecran_succes.visible = false
	ecran_options.visible = true
	creer_liste_boutons()


func _on_bouton_retour_pressed() -> void:
	ecran_accueil.visible = true	
	ecran_selection.visible = false # Au cas où
	ecran_succes.visible = false
	ecran_options.visible = false
