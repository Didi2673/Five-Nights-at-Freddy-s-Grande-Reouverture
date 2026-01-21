extends Node3D



# --- UI & COMPOSANTS ---
@onready var label_heure = $UI/Label_Heure
@onready var video_victoire = $UI/VideoStreamPlayer
@onready var game_ui = $UI # Le groupe qui contient le reste de ton UI (boutons caméras etc)

# Booléen pour arrêter le jeu quand on gagne
var game_over : bool = false

# --- CONFIGURATION DU JEU ---
var night_index : int = 0
var current_night_data = {}
var current_hour : int = 0
var timer_seconds : float = 0.0
var hour_duration : float = 60.0

# --- BATTERIE ---
var batterie : float = 100.0
var est_coupure_courant : bool = false

# Configuration de la consommation (ajuste selon la difficulté voulue)
# Combien de % on perd par seconde selon le niveau d'usage (1 à 5)
var taux_drain = {
	1: 0.1,  # Usage 1 (Rien) : Très lent (tient toute la nuit)
	2: 0.25, # Usage 2 : Moyen
	3: 0.45, # Usage 3 : Rapide
	4: 0.7,  # Usage 4 : Très rapide
	5: 1.2   # Usage 5 : CATASTROPHE
}

# --- LIENS ---
@onready var label_batterie = $UI/Label_Batterie # <-- NOUVEAU
# @onready var label_usage = $CanvasLayer/Label_Usage # (Optionnel)

# LISTE DES APPAREILS CONSOMMATEURS
# Glisse tes noeuds Portes et Cameras_System ici dans l'inspecteur
@export var portes : Array[Node3D] 
@export var systeme_camera : Node3D

var animatronics_instances : Array[AnimatronicAI] = []
@onready var map_container = $Cameras_System

@export var porte_gauche : Node3D 
@export var porte_droite : Node3D
@export var ecran_jumpscare : VideoStreamPlayer # Pour la vidéo de mort

func _process(delta):
	if est_coupure_courant:
		return # Si plus de courant, on arrête tout calcul

	# 1. GESTION DU TEMPS (Ton code existant)
	timer_seconds += delta
	if timer_seconds >= hour_duration:
		timer_seconds = 0.0
		passer_heure_suivante()

	# 2. GESTION DE LA BATTERIE
	calculer_drain_batterie(delta)
	
	for i in range(animatronics_instances.size()):
		var bot = animatronics_instances[i]
		
		# On récupère la difficulté pour l'heure actuelle
		var current_ai = GameData.get_ai_level(i, night_index, current_hour)
		
		# On fait "vivre" l'animatronique
		bot.process_ai(delta, current_ai)

func calculer_drain_batterie(delta):
	# On commence au niveau 1 (Le ventilateur tourne toujours)
	var usage_level : int = 1
	
	# Vérification des portes
	for porte in portes:
		# On suppose que ton script de porte a la variable "est_fermee"
		if porte.est_fermee:
			usage_level += 1
	
	# Vérification des caméras
	# On suppose que ton script camera a la variable "est_ouvert"
	if systeme_camera and systeme_camera.est_ouvert:
		usage_level += 1
	
	# On retire de la batterie selon le niveau d'usage
	# (On clamp à 5 car si tu as 2 portes + caméra + lumière, ça ne doit pas dépasser le max prévu)
	usage_level = clampi(usage_level, 1, 5)
	
	var perte = taux_drain[usage_level] * delta
	batterie -= perte
	
	# Mise à jour de l'affichage
	label_batterie.text = "Power: " + str(int(batterie)) + "%"
	
	# Optionnel : Afficher l'usage (Barres vertes)
	# label_usage.text = "Usage: " + "|||".repeat(usage_level) 
	
	# 3. COUPURE DE COURANT
	if batterie <= 0:
		trigger_blackout()

func trigger_blackout():
	print("PLUS DE COURANT !")
	est_coupure_courant = true
	batterie = 0
	label_batterie.text = "0%"
	
	# 1. On ouvre toutes les portes et on casse les boutons
	for porte in portes:
		if porte.has_method("couper_courant"):
			porte.couper_courant()
	
	# 2. On ferme les caméras
	if systeme_camera.has_method("couper_courant_camera"):
		systeme_camera.couper_courant_camera()
	
	# 3. AMBIANCE
	# Ici tu pourras lancer le son de coupure, éteindre la lumière principale (Light3D),
	# et lancer la séquence de Freddy qui arrive dans le noir.
	

func _ready():
	# 1. On charge la configuration de la nuit 1 depuis notre Singleton
	# On vérifie qu'on a bien des données chargées
	var night_index = GameData.index_nuit_selectionnee
	if GameData.nights_data.size() > night_index:
		current_night_data = GameData.nights_data[night_index]
		hour_duration = current_night_data["hour_duration_seconds"]
		
		# On initialise l'affichage
		update_clock_display()
		print("Démarrage de : ", current_night_data["title"])
	else:
		print("ERREUR CRITIQUE : Pas de données de nuit trouvées !")
		
	spawn_animatronics()
	if systeme_camera.has_method("update_puppet_difficulty"):
		systeme_camera.update_puppet_difficulty(current_hour, night_index)
	
func spawn_animatronics():
	for data in GameData.animatronics_data:
		
		# --- LE CORRECTIF EST ICI ---
		# Si c'est la Puppet, on saute ce tour de boucle.
		# On ne veut pas qu'elle ait une IA de déplacement classique.
		if data["name"] == "Puppet":
			continue 
		# ----------------------------
		
		var bot = AnimatronicAI.new()
		
		var porte_a_attaquer = null
		if data.has("door_side"):
			if data["door_side"] == "left":
				porte_a_attaquer = porte_gauche
			elif data["door_side"] == "right":
				porte_a_attaquer = porte_droite
		
		bot.setup(data, systeme_camera, porte_a_attaquer, self)
		animatronics_instances.append(bot)
		
func trigger_jumpscare(nom_tueur : String):
	if game_over: return # On ne meurt pas deux fois
	
	game_over = true
	print("MORT PAR : ", nom_tueur)
	
	# 1. On coupe tout
	# Désactive les boutons, cache le moniteur...
	$CanvasLayer/Moniteur_CCTV.visible = false
	$UI/Label_Heure.visible = false
	
	# 2. On lance la vidéo de Jumpscare
	# Tu peux charger une vidéo différente selon le tueur si tu veux
	if ecran_jumpscare:
		# Exemple : ecran_jumpscare.stream = load("res://videos/jumpscare_" + nom_tueur + ".ogv")
		ecran_jumpscare.visible = true
		ecran_jumpscare.play()
		
		await ecran_jumpscare.finished
		# Retour menu principal
		get_tree().change_scene_to_file("res://main_menu.tscn")

func passer_heure_suivante():
	current_hour += 1
	update_clock_display()
	
	# Mise à jour de l'IA des animatroniques (on le fera à l'étape suivante)
	print("Il est maintenant ", current_hour, "h du matin (in-game)")
	if systeme_camera.has_method("update_puppet_difficulty"):
		systeme_camera.update_puppet_difficulty(current_hour, night_index)

	# Condition de VICTOIRE (6 AM)
	if current_hour == 6:
		trigger_victory()

func update_clock_display():
	# Conversion simple : 0 = 12 AM, autres = X AM
	var text_heure = ""
	if current_hour == 0:
		text_heure = "12 AM"
	else:
		text_heure = str(current_hour) + " AM"
	
	label_heure.text = text_heure

func trigger_victory():
	game_over = true
	print("VICTOIRE ! 6 AM !")
	
	# 1. On cache l'interface du jeu (caméras, boutons, etc.)
	# Assure-toi que tout ton UI de jeu est enfant d'un noeud Control ou CanvasLayer que tu peux cacher
	# $CanvasLayer/Moniteur_CCTV.visible = false 
	
	# 2. On lance la vidéo
	video_victoire.visible = true
	video_victoire.play()
	
	# Optionnel : Quitter ou revenir au menu à la fin de la vidéo
	await video_victoire.finished
	print("Vidéo terminée")
	# get_tree().quit() ou changer de scène
