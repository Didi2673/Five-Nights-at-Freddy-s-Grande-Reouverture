extends Node2D

# --- 1. CONFIGURATION CAMERA 2D (NOUVEAU) ---
@export_group("Réglages Caméra")
@export var vitesse_scroll : float = 600.0
@export var zone_active_x : int = 150 # Largeur des bords pour scroller
@onready var camera = $Camera2D
@onready var background = $Background # Ton Sprite2D
@onready var audio_warning = $Audio_Warning
@onready var audio_fan = $Audio_Fan
@onready var audio_music_box = $Audio_MusicBox
@onready var audio_leurre = $Audio_Leurre
@onready var audio_flash_foxy = $Audio_Flash_Foxy
@export var nom_camera_puppet : String = "Cam04"

@onready var sprite_gf = $GoldenFreddy_Sprite # Vérifie le chemin !
@onready var audio_gf_appear = $Audio_GF_Appear

var gf_active : bool = false          # Est-il dans le bureau ?
var gf_reaction_timer : float = 0.0   # Compte à rebours avant la mort (1 seconde)
var gf_cooldown : float = 2.0         # Temps de pause après une apparition
var gf_interval_check : float = 1.0   # On teste s'il apparait toutes les secondes
var gf_timer_check : float = 0.0

# --- TEXTURES DU BUREAU (Assigner dans l'inspecteur !) ---
@export_group("Textures Bureau")
@export var tex_normal : Texture2D          # Tout éteint
@export var tex_light_left : Texture2D      # Lumière Gauche (Vide)
@export var tex_light_left_bonnie : Texture2D # Lumière Gauche (Bonnie)
@export var tex_light_right : Texture2D     # Lumière Droite (Vide)
@export var tex_light_right_chica : Texture2D # Lumière Droite (Chica)

@export var son_monitor : AudioStreamPlayer # Glisse ton son ici (monitor_flip.wav)
@onready var audio_monitor = $Audio_Monitor # Ou le chemin vers ton noeud

var videos_jumpscares = {
	"Bonnie": "res://Bonnie.ogv",
	"Chica": "res://Chica.ogv",
	"Foxy": "res://Foxy.ogv",
	"Freddy": "res://Freddy.ogv",
	"Puppet": "res://Puppet.ogv",
	"Mangle": "res://Mangle.ogv",
	"Golden-Freddy": "res://Golden-Freddy.ogv",
	"Springtrap": "res://Springtrap.ogv",
	"Heat": "res://Heat.ogv"
}

# ... tes autres onready var ...
@onready var container_barres = $UI/Barres_Container
@onready var ventilateur = $Ventilateur

# --- SYSTÈME DE TEMPÉRATURE -
var taux_drain = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
var temperature : float = 60.0
var temperature_min : float = 60.0
var temperature_max : float = 120.0
var ventilateur_actif : bool = true # Éteint par défaut pour économiser la batterie

@export var textures_barres : Array[Texture2D] 

# Référence vers le noeud TextureRect que tu viens de créer
@onready var indicateur_usage = $UI/Indicateur_Usage

# Vitesse (degrés par seconde)
var vitesse_chauffe : float = 1  # Ça monte doucement
var vitesse_refroidissement : float = 2.5 # Ça descend plus vite

@onready var label_temp = $UI/Label_Temperature # Adapte le chemin vers ton Label

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
@onready var ecran_jumpscare = $Layer_Jumpscare/Jumpscare # Renommé pour clarté
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
	print(night_index)
	
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
		
	if son_monitor: audio_monitor.stream = son_monitor
	
	audio_fan.play()
	
	if night_index == 6:
		print("--- NUIT 6 : SPRINGTRAP ACTIVE / PUPPET DESACTIVÉE ---")
		if systeme_camera:
			# On met le timer à l'infini ou on le bloque
			systeme_camera.music_timer = 99999.0 
			# Si tu as une variable pour dire "Puppet active", mets-la à false ici
	
func gestion_audio_music_box():
	# 1. On vérifie d'abord si la boite est vide
	# On suppose que la variable 'music_box_timer' est dans systeme_camera
	var est_vide = false
	
	if "music_timer" in systeme_camera:
		if systeme_camera.music_timer <= 0:
			est_vide = true
	
	# 2. Si la boite est vide : ON COUPE TOUT
	if est_vide:
		if audio_music_box.playing:
			audio_music_box.stop()
		return # On arrête la fonction ici
		
	# 3. Si la boite n'est pas vide, on s'assure que le son tourne
	if not audio_music_box.playing:
		audio_music_box.play()
	
	# 4. GESTION DU VOLUME (Le cœur de ta demande)
	# Condition : Moniteur OUVERT + Sur la BONNE CAMÉRA
	if systeme_camera.est_ouvert and systeme_camera.camera_actuelle == nom_camera_puppet:
		# On monte le volume (0 dB = volume normal)
		# On utilise lerp pour une transition douce (optionnel, mais plus agréable)
		audio_music_box.volume_db = lerp(audio_music_box.volume_db, 0.0, 0.1)
	else:
		# On coupe le volume (-80 dB = silence)
		audio_music_box.volume_db = lerp(audio_music_box.volume_db, -80.0, 0.1)

func toggle_ventilateur():	
	ventilateur_actif = !ventilateur_actif
	
	# Petit feedback sonore (optionnel)
	# if ventilateur_actif: $Son_Fan_On.play()
	# else: $Son_Fan_Off.play()
	if ventilateur_actif:
		# Si on allume, on joue le son
		if audio_fan and not audio_fan.playing:
			audio_fan.play()
	else:
		# Si on éteint, on coupe le son
		if audio_fan:
			audio_fan.stop()
	
	print("Ventilateur : ", ventilateur_actif)

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
			
			# --- AJOUT ICI ---
			if audio_monitor.stream:
				audio_monitor.play()
			
			# Petite astuce : Si on ouvre les caméras, on éteint les lumières des portes
			# pour économiser la batterie (comme dans le vrai jeu)
			if systeme_camera.est_ouvert:
				if porte_gauche.has_method("_on_light_stop"): porte_gauche._on_light_stop()
				if porte_droite.has_method("_on_light_stop"): porte_droite._on_light_stop()
				
	if Input.is_action_just_pressed("toggle_fan"):
		# On appelle la fonction qui est DANS ce script (ligne 89)
		toggle_ventilateur()
		
		# Si tu as AUSSI un script sur l'objet ventilateur pour l'animation/son :
		if ventilateur and ventilateur.has_method("toggle_ventilateur"):
			ventilateur.toggle_ventilateur()
	
	# --- GESTION CAMERA (SCROLL) ---
	# On ne bouge la caméra que si le moniteur est FERMÉ
	if systeme_camera and not systeme_camera.est_ouvert:
		gestion_camera_scroll(delta)
	
	if est_coupure_courant or game_over: return

	# --- TEST DE DIAGNOSTIC ---
	if systeme_camera == null:
		print("BLOQUÉ : La variable 'Systeme Camera' est vide dans l'inspecteur !")
	elif systeme_camera.est_ouvert:
		pass
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
	calculer_temperature(delta)
	
	for i in range(animatronics_instances.size()):
		var bot = animatronics_instances[i]
		
		# 1. On récupère le niveau d'IA actuel pour ce robot
		var current_ai = GameData.get_ai_level(bot.json_index, night_index, current_hour)
		
		# 2. On exécute son intelligence
		bot.process_ai(delta, current_ai)
		
	gestion_audio_music_box()
	process_golden_freddy(delta)

	# --- NOUVELLE FONCTION TEMPÉRATURE ---
func calculer_temperature(delta):
	if ventilateur_actif:
		# Si le ventilateur est ON, la température baisse
		if temperature > temperature_min:
			temperature -= vitesse_refroidissement * delta
	else:
		# Si le ventilateur est OFF, la température monte
		if temperature < temperature_max:
			temperature += vitesse_chauffe * delta
	
	# On borne la valeur entre 60 et 120
	temperature = clamp(temperature, temperature_min, temperature_max)
	
	# Mise à jour de l'affichage (sans décimales)
	if label_temp:
		label_temp.text = "Temp : " + str(int(temperature)) + "°"
		
		# Changement de couleur si ça devient critique (> 100°)
		if temperature > 100:
			label_temp.modulate = Color.RED
			# Optionnel : Faire clignoter l'écran ou ajouter un effet de flou de chaleur
		else:
			label_temp.modulate = Color.GREEN
			
	# --- MORT PAR CHALEUR ---
	if temperature >= 120.0:
		trigger_game_over_heat()

func trigger_game_over_heat():
	print("MORT DE CHALEUR !")
	trigger_jumpscare("Heat")
	
	# IA DES ROBOTS (Optionnel ici si on lance le jumpscare direct, mais je le laisse)
	for i in range(animatronics_instances.size()):
		var bot = animatronics_instances[i]
		var current_ai = GameData.get_ai_level(bot.json_index, night_index, current_hour)
		# Si tu as besoin de delta ici, tu devras le passer, 
		# mais pour un game over, on peut souvent ignorer l'IA.
		
	update_office_background()
	

func jouer_audio_leurre(nom_camera : String):
	if audio_leurre:
		# Petite variation de pitch pour le réalisme (optionnel)
		audio_leurre.pitch_scale = randf_range(0.95, 1.05)
		audio_leurre.play()
	print("📢 OFFICE : Diffusion audio en ", nom_camera, " à ", animatronics_instances.size(), " robots.")
	# On parcourt tous les robots
	for bot in animatronics_instances:
		# Si le robot a la fonction pour écouter
		if bot.has_method("recevoir_audio"):
			bot.recevoir_audio(nom_camera)


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
	var monstre_revele = false
	# 1. Si tout est éteint
	if not light_left_on and not light_right_on:
		background.texture = tex_normal
		return

	# 2. Lumière GAUCHE allumée
	if light_left_on:
		# On regarde si Bonnie est à la porte ("Left_Door_Pos")
		if systeme_camera.etat_salles.has("Left_Door_Pos") and systeme_camera.etat_salles["Left_Door_Pos"].has("Bonnie"):
			background.texture = tex_light_left_bonnie
			monstre_revele = true
		else:
			background.texture = tex_light_left

	# 3. Lumière DROITE allumée
	elif light_right_on:
		# On regarde si Chica est à la porte ("Right_Door_Pos")
		if systeme_camera.etat_salles.has("Right_Door_Pos") and systeme_camera.etat_salles["Right_Door_Pos"].has("Chica"):
			background.texture = tex_light_right_chica
			monstre_revele = true
		else:
			background.texture = tex_light_right
			
	if monstre_revele:
		# On joue le son SEULEMENT s'il n'est pas déjà en train de jouer
		# pour éviter que ça fasse "B-B-B-B-Bip" 60 fois par seconde
		if not audio_warning.playing:
			audio_warning.play()

# --- NOUVELLE FONCTION : DEPLACEMENT 2D ---
func gestion_camera_scroll(delta):
	var souris_x = get_viewport().get_mouse_position().x
	
	if souris_x < zone_active_x:
		camera.position.x -= vitesse_scroll * delta
	elif souris_x > ecran_largeur - zone_active_x:
		camera.position.x += vitesse_scroll * delta
	
	camera.position.x = clamp(camera.position.x, limite_gauche, limite_droite)


func calculer_drain_batterie(delta):
	# Par défaut, usage à 0 (comme tu as demandé)
	var usage_level : int = 0 
	
	# 1. Le Ventilateur consomme 1 barre
	if ventilateur_actif:
		usage_level += 1
	
	# 2. Les Portes consomment
	for porte in portes:
		if porte.est_fermee: usage_level += 1
	
	# 3. Les Caméras consomment
	if systeme_camera and systeme_camera.est_ouvert:
		usage_level += 1
		# Si on scelle la vent (Mangle), ça consomme encore plus
	if "vent_scelle" in systeme_camera and systeme_camera.vent_scelle:
		usage_level += 1
	
	# 4. La Lumière (si tu as des boutons light)
	if light_left_on: usage_level += 1
	if light_right_on: usage_level += 1
	# --- MISE A JOUR VISUELLE (NOUVEAU) ---
	if container_barres:
		# On récupère la liste de toutes les petites barres (les TextureRects)
		var barres = container_barres.get_children()
		
		# On parcourt chaque barre
		for i in range(barres.size()):
			# Si l'index de la barre (0, 1, 2...) est inférieur au niveau d'usage
			# On l'affiche. Sinon, on la cache.
			if i < usage_level:
				barres[i].visible = true  # Ou .modulate = Color.WHITE
			else:
				barres[i].visible = false # Ou .modulate = Color(0.2, 0.2, 0.2) pour faire "gris"
	# --- PROTECTION ---
	# Si usage_level est à 0, on ne draine RIEN !
	if usage_level == 0:
		
		return # On quitte la fonction, la batterie ne descend pas
	
	# Sinon, on applique le drain
	# Assure-toi que ton tableau taux_drain commence bien à l'index 1 ou gère l'index 0
	# Exemple : taux_drain = [0, 1.0, 2.0, 3.0, 4.0, 5.0]
	
	# On borne pour ne pas dépasser la taille du tableau
	usage_level = clampi(usage_level, 0, 5) 
	
	# 1. On récupère le drain de base (calibré pour 60s)
	var drain_de_base = taux_drain[usage_level] if usage_level < taux_drain.size() else 5.0
	
	# 2. On calcule le facteur d'ajustement
	# Si l'heure dure 60s, le ratio est 1.0 (inchangé).
	# Si l'heure dure 90s, le ratio devient 0.66 (ça descend moins vite).
	var ratio_duree = 60.0 / hour_duration
	
	# 3. On applique le ratio
	var drain_reel = drain_de_base * ratio_duree
	
	# 4. On retire à la batterie
	batterie -= drain_reel * delta
	
	# Mise à jour affichage batterie
	if batterie < 0: batterie = 0
	if label_batterie:
		label_batterie.text = "Power : " + str(int(batterie)) + "%"
		if batterie <= 20:
			label_batterie.modulate = Color.RED
		
	# Mise à jour visuelle de l'usage (Barres vertes)
	# Fais une petite fonction pour afficher des barres selon usage_level


func trigger_blackout():
	print("PLUS DE COURANT !")
	est_coupure_courant = true
	batterie = 0
	label_batterie.text = "0%"
	ventilateur_actif = false
	if audio_fan: audio_fan.stop()
	
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
	for i in range(GameData.animatronics_data.size()):
		var data = GameData.animatronics_data[i]
		var nom_bot = data["name"]
		
		if night_index == 6:
			# Nuit 6 : On ne veut QUE Springtrap
			if nom_bot != "Springtrap": continue
		else:
			# Autres nuits : On ne veut PAS Springtrap
			if nom_bot == "Springtrap": continue
		
		# --- LE FIX EST ICI ---
		# Si c'est Puppet OU Golden-Freddy, on saute le tour !
		# On ne veut pas qu'ils aient le script d'IA classique.
		if data["name"] == "Puppet" or data["name"] == "Golden-Freddy": 
			continue 
		# ----------------------
		
		var bot = AnimatronicAI.new()
		var porte_a_attaquer = null
		
		if nom_bot == "Springtrap":
			# Astuce : on lui passe un tableau ou on gérera ça dans l'IA
			# Pour l'instant on laisse null, on ira chercher les portes via office_ref dans l'IA
			pass 
		elif data.has("door_side"):
			if data["door_side"] == "left": porte_a_attaquer = porte_gauche
			elif data["door_side"] == "right": porte_a_attaquer = porte_droite
		
		bot.setup(data, systeme_camera, porte_a_attaquer, self, i)
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
	print("JUMPSCARE PAR : ", nom_tueur)
	
	# 1. Cacher l'interface
	if map_container: map_container.visible = false
	if game_ui: game_ui.visible = false 
	
	# 2. Configurer la vidéo
	if ecran_jumpscare:
		# 1. On active le Layer et la Vidéo
		$Layer_Jumpscare.visible = true
		ecran_jumpscare.visible = true
		
		# 2. CHARGEMENT DU FICHIER
		if videos_jumpscares.has(nom_tueur):
			ecran_jumpscare.stream = load(videos_jumpscares[nom_tueur])
		
		# --- LE FIX EST ICI : ON FORCE LA GEOMETRIE ---
		
		# A. On s'assure que la vidéo a le droit de s'agrandir
		ecran_jumpscare.expand = true 
		
		# B. On annule les ancrages automatiques qui pourraient bugger
		ecran_jumpscare.set_anchors_preset(Control.PRESET_TOP_LEFT)
		
		# C. On remet la position à 0,0 (coin haut gauche)
		ecran_jumpscare.position = Vector2.ZERO
		
		# D. On force la taille à être celle de la fenêtre du jeu
		ecran_jumpscare.size = get_viewport_rect().size
		
		# ----------------------------------------------
		
		print("Lancement vidéo... Taille forcée : ", ecran_jumpscare.size)
		ecran_jumpscare.play()
		
		await ecran_jumpscare.finished
		
		# Nettoyage
		ecran_jumpscare.stop()
		$Layer_Jumpscare.visible = false
	
	get_tree().change_scene_to_file("res://main_menu.tscn")


func trigger_victory():
	game_over = true
	GameData.win_night(night_index)
	print("VICTOIRE ! Lancement vidéo...") # Debug
	
	# 1. On cache TOUT le reste pour être sûr
	if map_container: map_container.visible = false
	if label_heure: label_heure.visible = false
	if label_batterie: label_batterie.visible = false
	# Si tu as un noeud racine pour l'UI du jeu, cache-le :
	# game_ui.visible = false 
	
	# 2. On configure la vidéo
	if video_victoire:
		# On s'assure qu'elle est au premier plan (Z-Index max)
		video_victoire.z_index = 100 
		
		# On l'affiche et on lance
		video_victoire.visible = true
		video_victoire.play()
		
		# On attend la fin
		await video_victoire.finished
		print("Vidéo finie.")
		
	# 3. Retour au menu
	get_tree().change_scene_to_file("res://main_menu.tscn")
	


func process_golden_freddy(delta):
	if game_over or est_coupure_courant: return

	# 1. GESTION DU COOLDOWN (Temps de pause)
	if gf_cooldown > 0:
		gf_cooldown -= delta
		return # On ne fait rien tant qu'il est en pause

	# 2. SI GOLDEN FREDDY EST DÉJÀ LA (ACTIF)
	if gf_active:
		# A. Le joueur a remonté le moniteur ? -> IL DISPARAIT
		if systeme_camera.est_ouvert:
			print("Golden Freddy esquivé !")
			desactiver_golden_freddy()
			return

		# B. Compte à rebours vers la mort
		gf_reaction_timer -= delta
		
		# Effet visuel optionnel (hallucination qui clignote ?)
		# sprite_gf.modulate.a = randf_range(0.5, 1.0) 

		# C. Temps écoulé -> JUMPSCARE
		if gf_reaction_timer <= 0:
			print("MORT PAR GOLDEN FREDDY")
			trigger_jumpscare("Golden-Freddy") # Assure-toi d'avoir la vidéo dans ton dictionnaire !

	# 3. S'IL N'EST PAS LA (TENTATIVE D'APPARITION)
	else:
		# On ne tente pas de spawn si on regarde déjà les caméras
		if systeme_camera.est_ouvert: return

		# On vérifie chaque seconde (pas à chaque frame, sinon c'est trop violent)
		gf_timer_check -= delta
		if gf_timer_check <= 0:
			gf_timer_check = 1.0 # Reset pour la prochaine seconde
			tenter_spawn_golden_freddy()

func tenter_spawn_golden_freddy():
	# 1. On récupère son IA (On suppose qu'il est index 6 ou qu'on le cherche par nom)
	# Astuce : Tu peux coder l'index en dur ou faire une recherche propre
	var ai_level = 0
	
	# Cherchons l'IA de Golden Freddy dans les données chargées
	# (Il faut que tu saches quel index il a dans ton JSON, disons que c'est le dernier)
	# Une méthode plus propre est de chercher par nom :
	for i in range(GameData.animatronics_data.size()):
		if GameData.animatronics_data[i]["name"] == "Golden-Freddy":
			ai_level = GameData.get_ai_level(i, night_index, current_hour)
			break
	
	if ai_level == 0: return # Il est désactivé

	# 2. Formule de probabilité (Style FNAF 1/2)
	# Plus l'IA est haute, plus le chiffre à battre est bas.
	# Exemple : Sur un dé de 1000, si IA est 20, on a plus de chances.
	
	# Chance de base : 1 sur 1000, augmenté par l'IA
	var chance = randi_range(1, 1000)
	var seuil = ai_level * 10 # Si IA=20 -> Seuil 200 (20% de chance chaque seconde ! C'est beaucoup)
	
	# Tu peux ajuster l'équilibrage ici :
	# Pour le rendre très rare : 'var seuil = ai_level * 2'
	
	if chance <= seuil:
		activer_golden_freddy()

func activer_golden_freddy():
	print("GOLDEN FREDDY EST DANS LE BUREAU !")
	sprite_gf.visible = true
	gf_active = true
	gf_reaction_timer = 2.0 # 1 seconde pour réagir !
	# Jouer un son (rire d'enfant ou bruit bizarre)
	if has_node("Audio_GF_Appear"): $Audio_GF_Appear.play()

func desactiver_golden_freddy():
	gf_active = false
	sprite_gf.visible = false
	
	# On lance le cooldown pour ne pas qu'il revienne tout de suite
	# Exemple : Entre 10 et 20 secondes de répit
	gf_cooldown = randf_range(10.0, 20.0) 
	print("GF Cooldown : ", gf_cooldown)
