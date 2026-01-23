extends Control # <-- Important : on étend Control maintenant !

# --- RÉFÉRENCES ---
# Glisse ton TextureRect (l'écran noir/image) ici
@export var ecran_visuel : TextureRect 

var btn_audio : BaseButton

var vent_scelle : bool = false
var btn_vent : BaseButton

var chemin_chica_audio = ["Cam12", "Cam10", "Cam06", "Cam05", "Cam02"]

var ecran_brouillage : ColorRect

@onready var audio_switch = $Audio_Switch_Cam
@onready var audio_flash_foxy = $Audio_Flash_Foxy

# --- VARIABLES D'ÉTAT ---
var est_ouvert : bool = false
var a_du_courant : bool = true
var camera_actuelle : String = "Cam01"

# --- UI INTERNE ---
# Plus besoin de chercher ui_moniteur, car "self" EST le moniteur !
var ui_music_box : Control
var progress_bar : Range
var btn_wind : BaseButton
var ui_foxy : Control
var btn_flash : BaseButton

# --- VARIABLES JEU (PUPPET / FOXY) ---
var music_timer : float = 100.0
var music_max : float = 100.0
var drain_speed : float = 0.0 
var puppet_escaped : bool = false
var puppet_attack_delay : float = 5.0
var puppet_data_index : int = -1
var est_winding : bool = false

var peut_flasher : bool = true
var temps_recharge_flash : float = 3.0
var foxy_rage : int = 0
var foxy_max_rage : int = 5
var foxy_attacking : bool = false

# --- DONNÉES SALLES ---
var etat_salles = {
	"Cam01": [], "Cam02": [], "Cam03": [], "Cam04": ["Puppet"],
	"Cam05": [], "Cam06": [], "Cam07": [], "Cam08": [], 
	"Cam09": [], "Cam10": [], "Cam11": [], "Cam12": [], "Cam13": [],
	# --- AJOUTE CES DEUX LIGNES IMPÉRATIVEMENT ---
	"Left_Door_Pos": [],   # Position finale pour Bonnie
	"Right_Door_Pos": []   # Position finale pour Chica
}

func _ready():
	# 1. On se cache au démarrage
	visible = false 
	
	# 2. Récupération des composants UI (Enfants de ce noeud)
	ui_music_box = find_child("MusicBox_UI", true, false)
	if ui_music_box:
		progress_bar = ui_music_box.find_child("Barre_Musique", true, false)
		btn_wind = ui_music_box.find_child("Bouton_Wind", true, false)
		if btn_wind:
			if not btn_wind.button_down.is_connected(_on_wind_start):
				btn_wind.button_down.connect(_on_wind_start)
			if not btn_wind.button_up.is_connected(_on_wind_stop):
				btn_wind.button_up.connect(_on_wind_stop)
				
	ui_foxy = find_child("Foxy_UI", true, false)
	if ui_foxy:
		btn_flash = ui_foxy.find_child("Bouton_Flash", true, false)
		if btn_flash:
			btn_flash.pressed.connect(_on_flash_foxy)

	# 3. Trouver Puppet dans les données
	for i in range(GameData.animatronics_data.size()):
		if GameData.animatronics_data[i]["name"] == "Puppet":
			puppet_data_index = i
			break
			
	btn_audio = find_child("Bouton_Audio", true, false)
	if btn_audio:
		btn_audio.pressed.connect(_on_audio_pressed)
		btn_audio.visible = false
	
	# --- CONFIGURATION BOUTON VENT ---
	btn_vent = find_child("Bouton_Vent", true, false)
	if btn_vent:
		btn_vent.visible = false # Caché au départ
		if not btn_vent.pressed.is_connected(_on_toggle_vent):
			btn_vent.pressed.connect(_on_toggle_vent)
			
	ecran_brouillage = find_child("Ecran_Brouillage", true, false)
	if ecran_brouillage:
		ecran_brouillage.visible = false
	
	mettre_a_jour_image()
	
func declencher_brouillage():
	# Si le moniteur est éteint, pas de brouillage visible
	if not est_ouvert or not visible: return
	
	if ecran_brouillage:
		print(">>> BROUILLAGE ACTIVÉ !")
		ecran_brouillage.visible = true
		
		# On attend 2 secondes
		await get_tree().create_timer(1.0).timeout
		
		# On vérifie si l'écran existe toujours (au cas où on quitte le jeu entre temps)
		if ecran_brouillage:
			ecran_brouillage.visible = false
# --- ACTION DU BOUTON VENT ---
func _on_toggle_vent():
	# On inverse l'état (Ouvert <-> Fermé)
	vent_scelle = !vent_scelle
	
	# Mise à jour du texte et de la couleur
	if btn_vent:
		if vent_scelle:
			btn_vent.text = "OUVRIR VENT"
			btn_vent.modulate = Color.RED # Feedback visuel (Consomme batterie !)
		else:
			btn_vent.text = "SCELLER VENT"
			btn_vent.modulate = Color.GREEN
			
	print("Ventilation scellée : ", vent_scelle)
	
# --- NOUVELLE FONCTION ---
func _on_audio_pressed():
	# 1. IMPORTANT : On "capture" le nom de la caméra MAINTENANT !
	# On le stocke dans une variable locale temporaire.
	var camera_cible = camera_actuelle
	
	print("[ID: ", get_instance_id(), "] Audio lancé sur -> ", camera_cible)
	
	# 2. On envoie l'ordre IMMEDIATEMENT à l'Office
	# On utilise la variable 'camera_cible' et non 'camera_actuelle' pour être sûr.
	var office = get_owner()
	if not office:
		var parent = get_parent()
		while parent:
			if parent.name == "office" or parent.has_method("jouer_audio_leurre"):
				office = parent
				break
			parent = parent.get_parent()
			
	if office and office.has_method("jouer_audio_leurre"):
		office.jouer_audio_leurre(camera_cible) # <--- L'IA reçoit l'info tout de suite !
	else:
		print("ERREUR : Office introuvable.")

	# 3. ENSUITE, on gère le visuel et le temps d'attente (Cooldown)
	if btn_audio:
		btn_audio.disabled = true
		
		# On attend 3 secondes (le script se met en pause ICI, mais l'audio est déjà parti !)
		await get_tree().create_timer(3.0).timeout 
		
		if btn_audio: btn_audio.disabled = false

func _process(delta):
	# ... (Ta logique Puppet inchangée) ...
	if puppet_escaped:
		puppet_attack_delay -= delta
		if puppet_attack_delay <= 0:
			lancer_attaque_puppet()
		return

	if music_timer > 0:
		if est_winding and camera_actuelle == "Cam04" and visible: # Ajout de "visible" par sécurité
			music_timer += 15.0 * delta
		else:
			music_timer -= (1.6 + (drain_speed * 0.22)) * delta
		
		music_timer = clamp(music_timer, 0.0, music_max)
		
		if progress_bar:
			var parts_restantes = ceil((music_timer / music_max) * 20)
			progress_bar.value = parts_restantes
			if parts_restantes <= 5: progress_bar.tint_progress = Color.RED
			elif parts_restantes <= 10: progress_bar.tint_progress = Color.ORANGE
			else: progress_bar.tint_progress = Color.WHITE
		
		if music_timer <= 0:
			trigger_puppet_escape()

# --- GESTION INPUT ESPACE (Déplacé ici) ---
# Plus besoin de le gérer dans Office.gd si tu le gères ici !
# Mais gardons-le ici au cas où le focus UI bloque l'input Office.


# --- ACTIONS ---
func toggle_monitor():
	est_ouvert = !est_ouvert
	visible = est_ouvert
	
	if est_ouvert:
		print("--- DIAGNOSTIC MONITEUR ---")
		print("Visible : ", visible)
		print("Modulate (Transparence) : ", modulate)
		print("Position : ", position)
		print("Taille (Size) : ", size)
		print("Mon parent est : ", get_parent().name)
		
		if ecran_visuel:
			print("Texture assignée : ", ecran_visuel.texture)
		else:
			print("ERREUR : ecran_visuel n'est pas lié dans l'inspecteur !")
			
		mettre_a_jour_image()

func fermer_moniteur():
	est_ouvert = false
	visible = false
	est_winding = false

func couper_courant_camera():
	a_du_courant = false
	vent_scelle = false 
	if btn_vent: 
		btn_vent.text = "SCELLER VENT"
		btn_vent.modulate = Color.GREEN
	fermer_moniteur()

# --- FONCTIONS BOUTONS (Intégrées directement !) ---
# Reconnecte tes boutons à ces fonctions dans l'éditeur
func _on_cam_01_pressed(): changer_camera("Cam01")
func _on_cam_02_pressed(): changer_camera("Cam02")
func _on_cam_03_pressed(): changer_camera("Cam03")
func _on_cam_04_pressed(): changer_camera("Cam04")
func _on_cam_05_pressed(): changer_camera("Cam05")
func _on_cam_06_pressed(): changer_camera("Cam06")
func _on_cam_07_pressed(): changer_camera("Cam07")
func _on_cam_08_pressed(): changer_camera("Cam08")
func _on_cam_09_pressed(): changer_camera("Cam09")
func _on_cam_10_pressed(): changer_camera("Cam10")
func _on_cam_11_pressed(): changer_camera("Cam11")
func _on_cam_12_pressed(): changer_camera("Cam12")
func _on_cam_13_pressed(): changer_camera("Cam13")
# ... Ajoute les autres ...

func _on_bouton_exit_pressed():
	fermer_moniteur()

# --- LOGIQUE INTERNE ---
func changer_camera(nom_cam : String):
	print("[ID: ", get_instance_id(), "] Changement Caméra -> ", nom_cam)
	camera_actuelle = nom_cam
	audio_switch.play()
	
	if btn_audio:
		# On l'affiche SI la caméra est dans le chemin de Chica
		# ET que ce n'est pas la scène (Cam01)
		if nom_cam in chemin_chica_audio:
			btn_audio.visible = true
		else:
			btn_audio.visible = false
			
	# 2. GESTION VENTILATION (Mangle - Cam13)
	if btn_vent:
		if nom_cam == "Cam13":
			btn_vent.visible = true
		else:
			btn_vent.visible = false
	
	# Gestion UI Music Box
	if ui_music_box:
		ui_music_box.visible = (nom_cam == "Cam04" and not puppet_escaped)
	
	# Gestion UI Foxy
	if ui_foxy:
		ui_foxy.visible = (nom_cam == "Cam03" and not foxy_attacking)
		if btn_flash: btn_flash.disabled = not peut_flasher
			
	mettre_a_jour_image()

func mettre_a_jour_image():
	if ecran_visuel == null: return
	
	var occupants : Array = []
	if etat_salles.has(camera_actuelle):
		occupants = etat_salles[camera_actuelle]
	
	var suffixe = ""
	if occupants.is_empty():
		suffixe = "_Vide"
	else:
		occupants.sort()
		for nom_monstre in occupants:
			suffixe += "_" + nom_monstre
			
	# Logique Foxy Cam03
	if camera_actuelle == "Cam03":
		if foxy_attacking:
			ecran_visuel.texture = load("res://Cameras/Cam03_Vide.png")
			return
		else:
			var phase = clampi(foxy_rage, 0, 4)
			var nom_img = "res://Cameras/Cam03_Foxy_" + str(phase) + ".png"
			if FileAccess.file_exists(nom_img):
				ecran_visuel.texture = load(nom_img)
			else:
				ecran_visuel.texture = load("res://Cameras/Cam03_Foxy_0.png")
			return
	
	# Chargement standard
	var chemin_image = "res://Cameras/" + camera_actuelle + suffixe + ".png"
	if FileAccess.file_exists(chemin_image):
		ecran_visuel.texture = load(chemin_image)
	else:
		ecran_visuel.texture = load("res://Cameras/" + camera_actuelle + "_Vide.png")

# --- PUPPET & FOXY ---
func update_puppet_difficulty(current_hour, night_index):
	if puppet_data_index != -1:
		var niveau = GameData.get_ai_level(puppet_data_index, night_index, current_hour)
		drain_speed = float(niveau)

func _on_wind_start(): est_winding = true
func _on_wind_stop(): est_winding = false

func trigger_puppet_escape():
	puppet_escaped = true
	if etat_salles["Cam04"].has("Puppet"): etat_salles["Cam04"].erase("Puppet")
	if camera_actuelle == "Cam04": mettre_a_jour_image()
	if ui_music_box: ui_music_box.visible = false

func lancer_attaque_puppet():
	# get_owner() est souvent plus fiable que get_parent() pour remonter à la racine Office
	if get_owner().has_method("trigger_jumpscare"):
		get_owner().trigger_jumpscare("Puppet")

func _on_flash_foxy():
	if not peut_flasher: return
	if camera_actuelle == "Cam03" and not foxy_attacking:
		audio_flash_foxy.play()
		foxy_rage -= 1
		if foxy_rage < 0: foxy_rage = 0
		flash_screen_effect()
		mettre_a_jour_image()
		peut_flasher = false
		if btn_flash: btn_flash.disabled = true
		await get_tree().create_timer(temps_recharge_flash).timeout
		peut_flasher = true
		if btn_flash: btn_flash.disabled = false

func flash_screen_effect():
	var original_modulate = ecran_visuel.modulate
	ecran_visuel.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	ecran_visuel.modulate = original_modulate
