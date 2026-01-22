extends Node2D

# --- 1. CONFIGURATION CAMERA 2D (NOUVEAU) ---
@export_group("Réglages Caméra")
@export var vitesse_scroll : float = 600.0
@export var zone_active_x : int = 150 # Largeur des bords pour scroller
@onready var camera = $Camera2D
@onready var background = $Background # Ton Sprite2D

# --- TEXTURES DU BUREAU (Assigner dans l'inspecteur !) ---
@export_group("Textures Bureau")
@export var tex_normal : Texture2D          # Tout éteint
@export var tex_light_left : Texture2D      # Lumière Gauche (Vide)
@export var tex_light_left_bonnie : Texture2D # Lumière Gauche (Bonnie)
@export var tex_light_right : Texture2D     # Lumière Droite (Vide)
@export var tex_light_right_chica : Texture2D # Lumière Droite (Chica)

# --- ETAT DES LUMIERES ---
var light_left_on : bool = false
var light_right_on : bool = false

var limite_gauche : float = 0.0
var limite_droite : float = 0.0
var ecran_largeur : float

# --- 2. UI & COMPOSANTS ---
@onready var label_heure = $UI/Label_Heure
@onready var label_nuit = $UI/Label_Nuit
@onready var label_batterie = $UI/Label_Batterie
@onready var video_victoire = $UI/VideoStreamPlayer
@onready var ecran_jumpscare = $UI/Jumpscare # Renommé pour clarté
@onready var game_ui = $UI 
@onready var map_container = $UI/Moniteur_CCTV # Assure-toi que c'est dans le CanvasLayer UI

# --- 3. REFERENCES EXTERNES ---
# Glisse tes noeuds Portes 2D et le Système Caméra ici
@export var portes : Array[Node] 
@export var systeme_camera : Node
@export var porte_gauche : Node 
@export var porte_droite : Node

# --- 4. VARIABLES DE JEU ---
var game_over : bool = false
var night_index : int = 1
var current_night_data = {}
var current_hour : int = 0
var timer_seconds : float = 0.0
var hour_duration : float = 60.0

var animatronics_instances : Array[AnimatronicAI] = []

# --- 5. BATTERIE ---
var batterie : float = 100.0
var est_coupure_courant : bool = false
var taux_drain = { 1: 0.1, 2: 0.25, 3: 0.45, 4: 0.7, 5: 1.2 }


func _ready():
	# A. INITIALISATION CAMERA SCROLL
	ecran_largeur = get_viewport_rect().size.x
	if background and background.texture:
		var taille_image = background.texture.get_width() * background.scale.x # On prend en compte le scale !
		
		limite_droite = taille_image - ecran_largeur
		
		# --- LE MOUCHARD ---
		print("--- DIAGNOSTIC SCROLL ---")
		print("Largeur Écran : ", ecran_largeur)
		print("Largeur Image (réelle) : ", taille_image)
		print("La caméra peut aller de 0 à : ", limite_droite)
		
		if limite_droite <= 0:
			print("⚠️ PROBLÈME : L'image est trop petite pour scroller !")
	
	# B. CHARGEMENT DONNÉES DE JEU
	night_index = GameData.current_night_played # Utilise la variable du Menu
	
	if label_nuit:
		label_nuit.text = "Nuit " + str(night_index)
	
	# Récupération des infos depuis le JSON (via GameData)
	var info = GameData.get_night_info(night_index)
	if info:
		current_night_data = info
		hour_duration = info["hour_duration_seconds"]
		print("Démarrage : ", info["title"], " (Durée heure: ", hour_duration, "s)")
	else:
		print("ERREUR : Pas d'info pour la nuit ", night_index)
	
	update_clock_display()
	
	# C. SPAWN ROBOTS & VITESSE PUPPET
	spawn_animatronics()
	
	# Initialisation immédiate de la difficulté Puppet
	if systeme_camera.has_method("update_puppet_difficulty"):
		systeme_camera.update_puppet_difficulty(current_hour, night_index)


func _process(delta):
	# Si Game Over ou Coupure, on arrête tout
	if est_coupure_courant or game_over:
		return 
		
	# --- 1. GESTION DE L'INPUT (C'est ce qui manquait !) ---
	# "ui_accept" est la touche Espace par défaut dans Godot.
	# Tu peux aussi créer une action "toggle_monitor" dans les Paramètres du projet.
	if Input.is_action_just_pressed("ui_accept"): 
		if systeme_camera.has_method("toggle_monitor"):
			systeme_camera.toggle_monitor()
			
			# Petite astuce : Si on ouvre les caméras, on éteint les lumières des portes
			# pour économiser la batterie (comme dans le vrai jeu)
			if systeme_camera.est_ouvert:
				if porte_gauche.has_method("_on_light_stop"): porte_gauche._on_light_stop()
				if porte_droite.has_method("_on_light_stop"): porte_droite._on_light_stop()

	# --- GESTION CAMERA (SCROLL) ---
	# On ne bouge la caméra que si le moniteur est FERMÉ
	if systeme_camera and not systeme_camera.est_ouvert:
		gestion_camera_scroll(delta)
	
	if est_coupure_courant or game_over: return

	# --- TEST DE DIAGNOSTIC ---
	if systeme_camera == null:
		print("BLOQUÉ : La variable 'Systeme Camera' est vide dans l'inspecteur !")
	elif systeme_camera.est_ouvert:
		print("")
	else:
		# Si on arrive ici, le scroll DOIT marcher
		var souris_x = get_viewport().get_mouse_position().x
		# print("Souris X : ", souris_x) # Décommente pour voir la position
		gestion_camera_scroll(delta)

	# --- GESTION DU TEMPS ---
	timer_seconds += delta
	if timer_seconds >= hour_duration:
		timer_seconds = 0.0
		passer_heure_suivante()

	# --- GESTION BATTERIE ---
	calculer_drain_batterie(delta)
	
	
	# --- IA DES ROBOTS ---
	for i in range(animatronics_instances.size()):
		var bot = animatronics_instances[i]
		# On récupère la difficulté dynamique
		var current_ai = GameData.get_ai_level(i, night_index, current_hour)
		bot.process_ai(delta, current_ai)
		
	update_office_background()


# --- GESTION DES LUMIERES (Appelé par les portes) ---
func set_light_state(cote : String, est_allume : bool):
	if cote == "left":
		light_left_on = est_allume
		# Sécurité : on ne peut pas allumer les deux en même temps (souvent le cas dans FNAF)
		if est_allume: light_right_on = false 
	elif cote == "right":
		light_right_on = est_allume
		if est_allume: light_left_on = false
	
	update_office_background()

# --- LOGIQUE D'AFFICHAGE ---
func update_office_background():
	# 1. Si tout est éteint
	if not light_left_on and not light_right_on:
		background.texture = tex_normal
		return

	# 2. Lumière GAUCHE allumée
	if light_left_on:
		# On regarde si Bonnie est à la porte ("Left_Door_Pos")
		if systeme_camera.etat_salles.has("Left_Door_Pos") and systeme_camera.etat_salles["Left_Door_Pos"].has("Bonnie"):
			background.texture = tex_light_left_bonnie
		else:
			background.texture = tex_light_left

	# 3. Lumière DROITE allumée
	elif light_right_on:
		# On regarde si Chica est à la porte ("Right_Door_Pos")
		if systeme_camera.etat_salles.has("Right_Door_Pos") and systeme_camera.etat_salles["Right_Door_Pos"].has("Chica"):
			background.texture = tex_light_right_chica
		else:
			background.texture = tex_light_right

# --- NOUVELLE FONCTION : DEPLACEMENT 2D ---
func gestion_camera_scroll(delta):
	var souris_x = get_viewport().get_mouse_position().x
	
	if souris_x < zone_active_x:
		camera.position.x -= vitesse_scroll * delta
	elif souris_x > ecran_largeur - zone_active_x:
		camera.position.x += vitesse_scroll * delta
	
	camera.position.x = clamp(camera.position.x, limite_gauche, limite_droite)


func calculer_drain_batterie(delta):
	var usage_level : int = 1 # Fan de base
	
	for porte in portes:
		if porte.est_fermee: usage_level += 1
	
	if systeme_camera and systeme_camera.est_ouvert:
		usage_level += 1
	
	usage_level = clampi(usage_level, 1, 5)
	
	batterie -= taux_drain[usage_level] * delta
	label_batterie.text = "Power: " + str(int(batterie)) + "%"
	
	if batterie <= 0:
		trigger_blackout()


func trigger_blackout():
	print("PLUS DE COURANT !")
	est_coupure_courant = true
	batterie = 0
	label_batterie.text = "0%"
	
	# 1. On ouvre les portes
	for porte in portes:
		if porte.has_method("couper_courant"):
			porte.couper_courant()
	
	# 2. On coupe la caméra
	if systeme_camera.has_method("couper_courant_camera"):
		systeme_camera.couper_courant_camera()
	
	# 3. AMBIANCE 2D
	# Astuce : Ajoute un CanvasModulate dans ta scène et change sa couleur ici
	# var ambiance = get_node_or_null("CanvasModulate")
	# if ambiance: ambiance.color = Color(0.1, 0.1, 0.1) # Presque noir total


func spawn_animatronics():
	# On utilise GameData.nights_data si c'est la config globale, 
	# ou GameData.animatronics_data pour la liste des robots.
	# Attention à bien utiliser la liste des robots chargée dans GameData
	
	for data in GameData.animatronics_data:
		if data["name"] == "Puppet": continue 
		
		var bot = AnimatronicAI.new()
		var porte_a_attaquer = null
		
		if data.has("door_side"):
			if data["door_side"] == "left": porte_a_attaquer = porte_gauche
			elif data["door_side"] == "right": porte_a_attaquer = porte_droite
		
		bot.setup(data, systeme_camera, porte_a_attaquer, self)
		animatronics_instances.append(bot)


func passer_heure_suivante():
	current_hour += 1
	update_clock_display()
	print("Il est ", current_hour, " AM")
	
	# Mise à jour difficulté Puppet
	if systeme_camera.has_method("update_puppet_difficulty"):
		systeme_camera.update_puppet_difficulty(current_hour, night_index)

	if current_hour == 6: # Ou info["end_hour"] si tu veux lire le JSON
		trigger_victory()


func update_clock_display():
	var text_heure = "12 AM" if current_hour == 0 else str(current_hour) + " AM"
	label_heure.text = text_heure


func trigger_jumpscare(nom_tueur : String):
	if game_over: return
	game_over = true
	
	# Cacher l'interface
	if map_container: map_container.visible = false
	game_ui.visible = false 
	
	# Lancer vidéo
	if ecran_jumpscare:
		ecran_jumpscare.visible = true
		ecran_jumpscare.play()
		await ecran_jumpscare.finished
		
	get_tree().change_scene_to_file("res://main_menu.tscn") # Adapte le chemin


func trigger_victory():
	game_over = true
	
	# Sauvegarder la victoire
	GameData.win_night(night_index)
	
	# UI
	game_ui.visible = false 
	if video_victoire:
		video_victoire.visible = true
		video_victoire.play()
		await video_victoire.finished
		
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
