extends Node2D

@export_group("Réglages Caméra")
@export var vitesse_scroll : float = 600.0
@export var zone_active_x : int = 150
@onready var camera = $Camera2D
@onready var background = $Background
@onready var audio_warning = $Audio_Warning
@onready var audio_fan = $Audio_Fan
@onready var audio_music_box = $Audio_MusicBox
@onready var audio_leurre = $Audio_Leurre
@onready var audio_flash_foxy = $Audio_Flash_Foxy
@onready var audio_honk = $Audio_Honk
@onready var audio_power_down = $Audio_PowerDown
@onready var audio_freddy = $Audio_Freddy_Laugh

var heat_timer_accumulated : float = 0.0

var puppet_timer_attaque : float = 5.0
var puppet_timer_reset : float = 5.0
var puppet_est_en_position : bool = false

@onready var audio_phone_call = $Audio_PhoneCall
@onready var btn_mute_call = $UI/Bouton_Mute_Call

@onready var sprite_gf = $GoldenFreddy_Sprite
@onready var audio_gf_appear = $Audio_GF_Appear

@onready var audio_ambiance = $Audio_Ambiance

var phone_calls = {
	1: "res://phone/night1.wav",
	2: "res://phone/night2.wav",
	3: "res://phone/night3.wav",
	4: "res://phone/night4.wav",
	5: "res://phone/night5.wav",
	6: "res://phone/night6.wav" 
}

var gf_active : bool = false          
var gf_reaction_timer : float = 0.0   
var gf_cooldown : float = 2.0         
var gf_interval_check : float = 1.0   
var gf_timer_check : float = 0.0

@export_group("Textures Bureau")
@export var tex_normal : Texture2D          
@export var tex_light_left : Texture2D      
@export var tex_light_left_bonnie : Texture2D 
@export var tex_light_right : Texture2D      
@export var tex_light_right_chica : Texture2D 

@export var son_monitor : AudioStreamPlayer 
@onready var audio_monitor = $Audio_Monitor 

var videos_jumpscares = {
	"Bonnie": "res://Bonnie.ogv",
	"Chica": "res://Chica.ogv",
	"Foxy": "res://Foxy.ogv",
	"Freddy": "res://Freddy.ogv",
	"Puppet": "res://Puppet.ogv",
	"Mangle": "res://Mangle.ogv",
	"Golden-Freddy": "res://Golden-Freddy.ogv",
	"Shadow-Bonnie": "res://Shadow-Bonnie.ogv",
	"Springtrap": "res://Springtrap.ogv",
	"Heat": "res://Heat.ogv"
}

@onready var container_barres = $UI/Barres_Container
@onready var ventilateur = $Ventilateur

var taux_drain = [0.16, 0.33, 0.66, 1.0, 1.33, 1.66]
var temperature : float = 60.0
var temperature_min : float = 60.0
var temperature_max : float = 120.0
var ventilateur_actif : bool = true 

var silent_ventilateur_active : bool = false
var silent_fan_timer : float = 0.0

@export var textures_barres : Array[Texture2D] 
@onready var indicateur_usage = $UI/Indicateur_Usage
var vitesse_chauffe : float = 4.5
var vitesse_refroidissement : float = 1.5 
@onready var label_temp = $UI/Label_Temperature 

# --- LUMIERES ---
var light_left_on : bool = false
var light_right_on : bool = false
var limite_gauche : float = 0.0
var limite_droite : float = 0.0
var ecran_largeur : float

# --- UI ---
@onready var label_heure = $UI/Label_Heure
@onready var label_nuit = $UI/Label_Nuit
@onready var label_batterie = $UI/Label_Batterie
@onready var video_victoire = $UI/VideoStreamPlayer
@onready var ecran_jumpscare = $Layer_Jumpscare/Jumpscare 
@onready var game_ui = $UI 
@onready var map_container = $UI/Moniteur_CCTV 

# --- REFERENCES ---
@export var portes : Array[Node] 
@export var systeme_camera : Node
@export var porte_gauche : Node 
@export var porte_droite : Node

# --- VARIABLES JEU ---
var game_over : bool = false
var night_index : int = 1
var current_night_data = {}
var current_hour : int = 0
var timer_seconds : float = 0.0
var hour_duration : float = 60.0

var animatronics_instances : Array[AnimatronicAI] = []

# --- BATTERIE ---
var batterie : float = 100.0
var est_coupure_courant : bool = false


func _ready():
	ecran_largeur = get_viewport_rect().size.x
	if background and background.texture:
		var taille_image = background.texture.get_width() * background.scale.x 
		limite_droite = taille_image - ecran_largeur
	
	night_index = GameData.current_night_played 
	print("Lancement Nuit : ", night_index)
	
	if label_nuit:
		label_nuit.text = "Nuit " + str(night_index)
	
	var info = GameData.get_night_info(night_index)
	if info:
		current_night_data = info
		hour_duration = info["hour_duration_seconds"]
	else:
		print("ERREUR : Pas d'info pour la nuit ", night_index)
	
	update_clock_display()
	
	spawn_animatronics()
	
	if son_monitor: audio_monitor.stream = son_monitor
	audio_fan.play()
	
	if night_index == 6:
		print("--- NUIT 6 : SPRINGTRAP ACTIVE / PUPPET DESACTIVÉE ---")
		
			
	if btn_mute_call:
		btn_mute_call.visible = false
		btn_mute_call.pressed.connect(_on_mute_call_pressed)
	
	lancer_appel_telephonique()
	
	if night_index < 3:
		if label_temp: label_temp.visible = false
	else:
		if label_temp: label_temp.visible = true

func _on_nez_freddy_pressed():
	if audio_honk: audio_honk.play()
	GameData.unlock_achievement("honk")

func lancer_appel_telephonique():
	if phone_calls.has(night_index):
		var chemin = phone_calls[night_index]
		if ResourceLoader.exists(chemin):
			audio_phone_call.stream = load(chemin)
			audio_phone_call.play()
			if btn_mute_call: btn_mute_call.visible = true
			await audio_phone_call.finished
			if btn_mute_call: btn_mute_call.visible = false

func _on_mute_call_pressed():
	if audio_phone_call.playing:
		audio_phone_call.stop()
		if btn_mute_call: btn_mute_call.visible = false

func toggle_ventilateur():
	ventilateur_actif = !ventilateur_actif
	
	if ventilateur_actif:
		# Si on allume le normal, on éteint le silencieux
		silent_ventilateur_active = false
		if audio_fan and not audio_fan.playing: audio_fan.play()
	else:
		if audio_fan: audio_fan.stop()
		
	print("Ventilateur Normal : ", ventilateur_actif)
	
func toggle_silent_ventilateur():
	silent_ventilateur_active = !silent_ventilateur_active
	
	if silent_ventilateur_active:
		# Si on allume le silencieux, on éteint le normal
		ventilateur_actif = false
		if audio_fan: audio_fan.stop() # Le silencieux ne fait pas de bruit
		print("Ventilateur Silencieux : ACTIF")
	else:
		print("Ventilateur Silencieux : INACTIF")

func gestion_inputs_clavier():
	# --- 1. GESTION DES LUMIÈRES (Toggle : On appuie pour allumer/éteindre) ---
	if Input.is_action_just_pressed("input_light_left"):
		porte_gauche._on_light_start()
	elif Input.is_action_just_released("input_light_left"):
		porte_gauche._on_light_stop()
		
	# LUMIÈRE DROITE
	if Input.is_action_just_pressed("input_light_right"):
		porte_droite._on_light_start()
	elif Input.is_action_just_released("input_light_right"):
		porte_droite._on_light_stop()

	# --- 2. GESTION DES PORTES ---
	# Note : Assurez-vous que vos scripts de portes ont une fonction "toggle" ou "interagir"
	if Input.is_action_just_pressed("input_door_left"):
		if porte_gauche.has_method("_on_door_toggle"): 
			porte_gauche._on_door_toggle()
		
			
	if Input.is_action_just_pressed("input_door_right"):
		if porte_droite.has_method("_on_door_toggle"): 
			porte_droite._on_door_toggle()
		
	# --- 3. GESTION DU VENTILATION SEAL ---
	if Input.is_action_just_pressed("input_seal_vent"):
		# On appelle la fonction dans le système caméra
		if systeme_camera.has_method("_on_toggle_vent"):
			systeme_camera._on_toggle_vent()
			
	if Input.is_action_just_pressed("toggle_monitor"): # <--- On utilise le nouveau nom
		if systeme_camera.has_method("toggle_monitor"):
			systeme_camera.toggle_monitor()
			if audio_monitor.stream: audio_monitor.play()
			
			# Si on ouvre, on éteint les lumières des portes pour économiser/logique
			if systeme_camera.est_ouvert:
				if porte_gauche.has_method("_on_light_stop"): porte_gauche._on_light_stop()
				if porte_droite.has_method("_on_light_stop"): porte_droite._on_light_stop()






func _process(delta):
	# Si Game Over, on arrête tout
	if game_over: return 
	
	# --- 1. INPUTS (Bloqués si coupure de courant) ---
	if not est_coupure_courant:
		gestion_inputs_clavier()
					
		if night_index >= 3:
			if Input.is_action_just_pressed("toggle_fan"): toggle_ventilateur()
			if Input.is_action_just_pressed("toggle_silent_fan"): toggle_silent_ventilateur()
		else:
			# Logique auto pour nuits 1-2
			if not ventilateur_actif:
				ventilateur_actif = true
				if audio_fan and not audio_fan.playing: audio_fan.play()
			if silent_ventilateur_active:
				silent_ventilateur_active = false
	
	# --- 2. CAMERA SCROLL (Autorisé même sans courant !) ---
	# On peut regarder autour de soi dans le noir
	if systeme_camera and not systeme_camera.est_ouvert:
		gestion_camera_scroll(delta)
	
	# --- 3. GESTION DU TEMPS (Autorisé sans courant pour pouvoir gagner à 6AM) ---
	timer_seconds += delta
	if timer_seconds >= hour_duration:
		timer_seconds = 0.0
		passer_heure_suivante()

	# --- 4. SYSTEMES (Batterie, Temp, IA) ---
	# On ne calcule le drain et la temp que s'il y a du courant
	if not est_coupure_courant:
		calculer_drain_batterie(delta)
		calculer_temperature(delta)
	
	# L'IA continue de tourner (pour que Freddy s'approche pendant le blackout)
	# Mais on peut limiter les autres si on veut. Ici on laisse tourner.
	for i in range(animatronics_instances.size()):
		var bot = animatronics_instances[i]
		var ai_level_to_use = 0
		if night_index == 7:
			ai_level_to_use = bot.current_ai_level
		else:
			ai_level_to_use = GameData.get_ai_level(bot.json_index, night_index, current_hour)
		bot.process_ai(delta, ai_level_to_use)
		
	process_golden_freddy(delta)
	gestion_puppet(delta)
	
	
func gestion_puppet(delta):
	if game_over or est_coupure_courant: return

	var puppet_bot = null
	for bot in animatronics_instances:
		if bot.nom == "Puppet":
			puppet_bot = bot
			break
	
	if puppet_bot == null: return 

	var salle_puppet = ""
	if puppet_bot.path_list.size() > 0:
		salle_puppet = puppet_bot.path_list[puppet_bot.current_path_index]

	var volume_cible = -80.0
	puppet_est_en_position = (salle_puppet == "Right_Door_Pos") # Position d'attaque (invisible)

	if puppet_est_en_position:
		volume_cible = 0.0
	elif systeme_camera.est_ouvert and systeme_camera.camera_actuelle == salle_puppet:
		volume_cible = 0.0
	else:
		volume_cible = -80.0

	if audio_music_box:
		if not audio_music_box.playing: audio_music_box.play()
		audio_music_box.volume_db = lerp(audio_music_box.volume_db, volume_cible, 5 * delta)

	if puppet_est_en_position:
		if porte_droite.est_fermee:
			puppet_timer_reset -= delta
			if puppet_timer_reset <= 0:
				renvoyer_puppet(puppet_bot)
		else:
			puppet_timer_attaque -= delta
			puppet_timer_reset = 5.0 
			if puppet_timer_attaque <= 0:
				trigger_jumpscare("Puppet")
	else:
		puppet_timer_attaque = 5.0
		puppet_timer_reset = 5.0

func renvoyer_puppet(bot):
	print("PUPPET REPART AU DÉBUT !")
	bot.changer_position(0)
	puppet_timer_attaque = 5.0
	puppet_timer_reset = 5.0

func calculer_temperature(delta):
	if ventilateur_actif:
		if temperature > temperature_min:
			temperature -= vitesse_refroidissement * delta
			
	elif silent_ventilateur_active:
		if temperature < temperature_max:
			temperature += vitesse_chauffe * delta
			
		silent_fan_timer += delta
		if silent_fan_timer >= 0.2:
			silent_fan_timer = 0.0
			if randf() < 0.7:
				temperature -= 1.0
				
	else:
		if temperature < temperature_max:
			temperature += vitesse_chauffe * delta
	
	temperature = clamp(temperature, temperature_min, temperature_max)
	
	if label_temp:
		label_temp.text = "Temp : " + str(int(temperature)) + "°"
		if temperature > 100:
			label_temp.modulate = Color.RED
		else:
			label_temp.modulate = Color.GREEN
			
	if temperature >= 120.0:
		trigger_game_over_heat()
		
	if temperature >= 110.0 and not game_over:
		heat_timer_accumulated += delta
		if heat_timer_accumulated >= 10.0:
			GameData.unlock_achievement("heat_survivor")
	else:
		heat_timer_accumulated = 0.0

func trigger_game_over_heat():
	trigger_jumpscare("Heat")
	update_office_background()

func jouer_audio_leurre(nom_camera : String):
	if audio_leurre:
		audio_leurre.pitch_scale = randf_range(0.95, 1.05)
		audio_leurre.play()
	for bot in animatronics_instances:
		if bot.has_method("recevoir_audio"):
			bot.recevoir_audio(nom_camera)


func set_light_state(cote : String, est_allume : bool):
	if cote == "left":
		light_left_on = est_allume
		if est_allume: light_right_on = false 
	elif cote == "right":
		light_right_on = est_allume
		if est_allume: light_left_on = false
	update_office_background()

func update_office_background():
	var monstre_revele = false
	if not light_left_on and not light_right_on:
		background.texture = tex_normal
		return

	if light_left_on:
		if systeme_camera.etat_salles.has("Left_Door_Pos") and systeme_camera.etat_salles["Left_Door_Pos"].has("Bonnie"):
			background.texture = tex_light_left_bonnie
			monstre_revele = true
		else:
			background.texture = tex_light_left

	elif light_right_on:
		if systeme_camera.etat_salles.has("Right_Door_Pos") and systeme_camera.etat_salles["Right_Door_Pos"].has("Chica"):
			background.texture = tex_light_right_chica
			monstre_revele = true
		else:
			background.texture = tex_light_right
			
	if monstre_revele:
		if not audio_warning.playing:
			audio_warning.play()

func gestion_camera_scroll(delta):
	var souris_x = get_viewport().get_mouse_position().x
	
	if souris_x < zone_active_x:
		camera.position.x -= vitesse_scroll * delta
	elif souris_x > ecran_largeur - zone_active_x:
		camera.position.x += vitesse_scroll * delta
	
	camera.position.x = clamp(camera.position.x, limite_gauche, limite_droite)


func calculer_drain_batterie(delta):
	var usage_level : int = 0 
	
	if silent_ventilateur_active: usage_level += 1
	for porte in portes:
		if porte.est_fermee: usage_level += 1
	if systeme_camera and systeme_camera.est_ouvert: usage_level += 1
	if "vent_scelle" in systeme_camera and systeme_camera.vent_scelle: usage_level += 1
	if light_left_on: usage_level += 1
	if light_right_on: usage_level += 1
	
	if container_barres:
		var barres = container_barres.get_children()
		for i in range(barres.size()):
			if i < usage_level: barres[i].visible = true 
			else: barres[i].visible = false
			
	#if usage_level == 0: return 
	
	usage_level = clampi(usage_level, 0, 5) 
	var drain_de_base = taux_drain[usage_level] if usage_level < taux_drain.size() else 5.0
	var ratio_duree = 60.0 / hour_duration
	var drain_reel = drain_de_base * ratio_duree
	batterie -= drain_reel * delta
	
	if batterie < 0: batterie = 0
	if label_batterie:
		label_batterie.text = "Power : " + str(int(batterie)) + "%"
		if batterie <= 20: label_batterie.modulate = Color.RED
		
	if batterie <= 0: trigger_blackout()

func trigger_blackout():
	if est_coupure_courant or game_over: return
	print("PLUS DE COURANT !")
	
	est_coupure_courant = true
	batterie = 0.0
	
	# 1. Couper les systèmes
	ventilateur_actif = false
	silent_ventilateur_active = false
	light_left_on = false
	light_right_on = false
	
	if audio_fan: audio_fan.stop()
	if audio_ambiance: audio_ambiance.stop()
	
	# Fermer le moniteur de force
	if systeme_camera.est_ouvert:
		systeme_camera.toggle_monitor()
	
	# Couper les portes
	for porte in portes:
		if porte.has_method("couper_courant"): porte.couper_courant()
	if systeme_camera.has_method("couper_courant_camera"): systeme_camera.couper_courant_camera()
	
	# 2. Mise à jour visuelle (Tout noir)
	label_batterie.text = "0%"
	game_ui.visible = false # Cache l'interface
	
	# On met l'image normale mais très sombre
	background.texture = tex_normal
	background.modulate = Color(0.1, 0.1, 0.1, 1) # Assombri presque totalement
	
	# 3. Lancer la séquence audio/jumpscare
	sequence_blackout_freddy()

func sequence_blackout_freddy():
	# A. Son de coupure ("Bzzzt")
	if audio_power_down:
		audio_power_down.play()
		await audio_power_down.finished
	
	# B. Petit délai d'attente dans le noir (Tension)
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	if game_over: return # Si 6AM a sonné entre temps, on arrête
	
	# D. Silence final (Avant la mort)
	await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
	
	# E. JUMPSCARE
	if not game_over: # Vérification finale si on a gagné
		trigger_jumpscare("Freddy")

func spawn_animatronics():
	for i in range(GameData.animatronics_data.size()):
		var data = GameData.animatronics_data[i]
		var nom_bot = data["name"]
		
		# FILTRES (Tes règles existantes)
		if night_index == 6 and nom_bot != "Springtrap": continue
		elif night_index != 6 and nom_bot == "Springtrap": continue
		if nom_bot == "Golden-Freddy": continue 
		
		# CREATION
		var bot = AnimatronicAI.new()
		var porte_a_attaquer = null
		
		if nom_bot != "Springtrap" and data.has("door_side"):
			if data["door_side"] == "left": porte_a_attaquer = porte_gauche
			elif data["door_side"] == "right": porte_a_attaquer = porte_droite
			
		var ai_level_final = 0
		
		if night_index == 7:
			if GameData.custom_night_levels.has(nom_bot):
				ai_level_final = GameData.custom_night_levels[nom_bot]
		else:
			ai_level_final = GameData.get_ai_level(i, night_index, current_hour)
		
		bot.setup(data, systeme_camera, porte_a_attaquer, self, i)
		bot.current_ai_level = ai_level_final
		animatronics_instances.append(bot)
		
	if systeme_camera:
		systeme_camera.mettre_a_jour_image()
	

func passer_heure_suivante():
	current_hour += 1
	update_clock_display()

	if current_hour == 6: 
		trigger_victory()
	
	if systeme_camera:
		systeme_camera.mettre_a_jour_image()
	
	update_office_background()

func forcer_depart_autres_robots():
	for bot in animatronics_instances:
		if bot.nom != "Springtrap":
			# 1. On coupe son IA
			bot.reset_timer(0) 
			
			# 2. On le renvoie à sa position de départ (souvent index 0 : La Scène)
			bot.changer_position(0)
			
			# 3. Si c'était Foxy et qu'il attaquait, on annule
			if bot.nom == "Foxy" and systeme_camera.foxy_attacking:
				systeme_camera.foxy_attacking = false
				systeme_camera.foxy_rage = 0
				
	# Mise à jour visuelle forcée des caméras
	systeme_camera.mettre_a_jour_image()
	# Mise à jour du bureau (au cas où Bonnie était à la fenêtre)
	update_office_background()


func update_clock_display():
	var text_heure = "12 AM" if current_hour == 0 else str(current_hour) + " AM"
	label_heure.text = text_heure

func trigger_jumpscare(nom_tueur : String):
	if game_over: return
	game_over = true
	
	if current_hour == 0:
		GameData.unlock_achievement("early_death")
	
	if map_container: map_container.visible = false
	if game_ui: game_ui.visible = false 
	if audio_ambiance: audio_ambiance.stop()
	
	if ecran_jumpscare:
		$Layer_Jumpscare.visible = true
		ecran_jumpscare.visible = true
		if videos_jumpscares.has(nom_tueur):
			ecran_jumpscare.stream = load(videos_jumpscares[nom_tueur])
		
		ecran_jumpscare.expand = true 
		ecran_jumpscare.set_anchors_preset(Control.PRESET_TOP_LEFT)
		ecran_jumpscare.position = Vector2.ZERO
		ecran_jumpscare.size = get_viewport_rect().size
		
		ecran_jumpscare.play()
		await ecran_jumpscare.finished
		ecran_jumpscare.stop()
		$Layer_Jumpscare.visible = false
	
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func trigger_victory():
	game_over = true
	
	if game_ui: game_ui.visible = true
	
	# Par contre, on cache les textes pour ne pas les voir par dessus la vidéo
	if label_heure: label_heure.visible = false
	if label_batterie: label_batterie.visible = false
	if map_container: map_container.visible = false
	
	# On remet la lumière normale (au cas où le modulate du blackout affecte la vidéo)
	if background: background.modulate = Color(1, 1, 1, 1)
	
	if batterie >= 20.0:
		GameData.unlock_achievement("battery_master")
		
	# --- SUCCÈS : NUITS ---
	if night_index >= 1 and night_index <= 6:
		GameData.unlock_achievement("night_" + str(night_index))
		
	# --- SUCCÈS : 7/20 MODE ---
	if night_index == 7:
		if GameData.active_challenge_id != "custom":
			var id_chal = GameData.active_challenge_id
			
			# Si pas déjà validé, on l'ajoute
			if not id_chal in GameData.completed_challenges:
				GameData.completed_challenges.append(id_chal)
				GameData.save_game() # On sauvegarde immédiatemen
				
		var tous_a_20 = true
		# On vérifie si un seul robot est en dessous de 20
		# Attention : On vérifie TOUS les robots disponibles
		for key in GameData.custom_night_levels:
			if GameData.custom_night_levels[key] < 20:
				tous_a_20 = false
				break
		
		# Vérification supplémentaire : est-ce que les robots sont bien activés ?
		# (Pour éviter le cheat où on met 0 partout)
		if GameData.custom_night_levels.size() < 4: # Sécurité
			tous_a_20 = false
			 
		if tous_a_20:
			GameData.unlock_achievement("20_20_mode")
	
	GameData.win_night(night_index)
	audio_fan.stop()
	audio_power_down.stop()
	audio_music_box.volume_db = -80.0
	audio_music_box.stop()
	audio_ambiance.stop()
	
	if map_container: map_container.visible = false
	if label_heure: label_heure.visible = false
	if label_batterie: label_batterie.visible = false
	
	if video_victoire:
		video_victoire.z_index = 4000 
		video_victoire.visible = true
		video_victoire.play()
		await video_victoire.finished
		
	var chemin_image_fin = ""
	
	# DÉFINITION DES IMAGES SELON LA NUIT
	if night_index == 5:
		chemin_image_fin = "res://night5.png" # Ton image "Chèque"
	elif night_index == 6:
		chemin_image_fin = "res://night6.png" # Ton image "Heures Supp"
	elif night_index == 7:
		chemin_image_fin = "res://night7.png"     # Ton image "Licenciement"
	
	# 1. SI C'EST UNE NUIT AVEC IMAGE DE FIN
	if chemin_image_fin != "" and ResourceLoader.exists(chemin_image_fin):
		print("Affichage écran de fin pour la nuit ", night_index)
		
		# On passe l'info au GameData
		GameData.image_fin_a_afficher = chemin_image_fin
		
		# On charge la scène de fin
		get_tree().change_scene_to_file("res://Scenes/ending_screen.tscn")
		return # On arrête la fonction ici, on ne lance pas de mini-jeu
		
	var nom_scene_minijeu = "res://minigames/Minigame_" + str(night_index) + ".tscn"
	
	# On vérifie si ce fichier existe réellement
	if ResourceLoader.exists(nom_scene_minijeu):
		print("Lancement du Mini-Jeu pour la nuit ", night_index)
		get_tree().change_scene_to_file(nom_scene_minijeu)
	else:
		# Si pas de mini-jeu pour cette nuit (ex: Nuit 7), retour au menu
		print("Pas de mini-jeu trouvé, retour menu.")
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func process_golden_freddy(delta):
	if game_over or est_coupure_courant: return
	if gf_cooldown > 0:
		gf_cooldown -= delta
		return 

	if gf_active:
		if systeme_camera.est_ouvert:
			desactiver_golden_freddy()
			return
		gf_reaction_timer -= delta
		if gf_reaction_timer <= 0:
			trigger_jumpscare("Golden-Freddy")
	else:
		if systeme_camera.est_ouvert: return
		gf_timer_check -= delta
		if gf_timer_check <= 0:
			gf_timer_check = 1.0 
			tenter_spawn_golden_freddy()

func tenter_spawn_golden_freddy():
	var ai_level = 0
	
	# --- 1. RECUPERATION DU NIVEAU ---
	if night_index == 7:
		# CAS CUSTOM NIGHT : On lit le menu
		if GameData.custom_night_levels.has("Golden-Freddy"):
			ai_level = GameData.custom_night_levels["Golden-Freddy"]
	else:
		# CAS HISTOIRE : On lit le JSON
		for i in range(GameData.animatronics_data.size()):
			if GameData.animatronics_data[i]["name"] == "Golden-Freddy":
				ai_level = GameData.get_ai_level(i, night_index, current_hour)
				break
	
	# Si IA est à 0, il n'apparaît jamais
	if ai_level == 0: return 
	
	# --- 2. CALCUL PROBABILITÉ ---
	var chance = randi_range(1, 1000)
	var seuil = ai_level * 10 
	
	if chance <= seuil:
		activer_golden_freddy()

func activer_golden_freddy():
	sprite_gf.visible = true
	gf_active = true
	GameData.unlock_achievement("golden_sighting")
	gf_reaction_timer = 2.0 
	if has_node("Audio_GF_Appear"): $Audio_GF_Appear.play()

func desactiver_golden_freddy():
	gf_active = false
	sprite_gf.visible = false
	gf_cooldown = randf_range(10.0, 20.0)

func jouer_rire_freddy():
	audio_freddy.play()
