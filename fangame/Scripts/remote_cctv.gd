extends Control

# --- RÉFÉRENCES VISUELLES ---
@export var ecran_visuel : TextureRect 
@export var ecran_brouillage : ColorRect 

var flash_count_session : int = 0

# --- RÉFÉRENCES AUDIO ---
@onready var audio_switch = $Audio_Switch_Cam
@onready var audio_flash_foxy = $Audio_Flash_Foxy
@onready var audio_mangle_static = $Audio_Mangle_Static

# --- BOUTONS ---
var btn_audio : BaseButton
var btn_vent : BaseButton
var btn_flash : BaseButton

# --- ETAT DU JEU ---
var est_ouvert : bool = false
var a_du_courant : bool = true
var camera_actuelle : String = "Cam01"
var vent_scelle : bool = false

# --- ZONES SPÉCIALES ---
var chemin_chica_audio = ["Cam12", "Cam10", "Cam06", "Cam05", "Cam02"]

# --- FOXY ---
var ui_foxy : Control
var peut_flasher : bool = true
var foxy_max_rage : int = 5
var temps_recharge_flash : float = 3.0
var foxy_rage : int = 0
var foxy_attacking : bool = false

# --- DONNÉES SALLES ---
var etat_salles = {
	"Cam01": [], "Cam02": [], "Cam03": [], "Cam04": [],
	"Cam05": [], "Cam06": [], "Cam07": [], "Cam08": [], 
	"Cam09": [], "Cam10": [], "Cam11": [], "Cam12": [], "Cam13": [],
	"Left_Door_Pos": [],   
	"Right_Door_Pos": [],  
}

func _ready():
	visible = false 
	
	# --- 1. CONFIGURATION AUDIO (CHICA) ---
	btn_audio = find_child("Bouton_Audio", true, false)
	if btn_audio:
		if not btn_audio.pressed.is_connected(_on_input_audio_pressed):
			btn_audio.pressed.connect(_on_input_audio_pressed) # Modifié
		btn_audio.visible = false
	
	# --- 2. CONFIGURATION VENTILATION (SPRINGTRAP/MANGLE) ---
	btn_vent = find_child("Bouton_Vent", true, false)
	if btn_vent:
		btn_vent.visible = false 
		if not btn_vent.pressed.is_connected(_on_input_vent_pressed):
			btn_vent.pressed.connect(_on_input_vent_pressed) # Modifié
			
	# --- 3. CONFIGURATION FOXY (FLASH) ---
	ui_foxy = find_child("Foxy_UI", true, false)
	if ui_foxy:
		btn_flash = ui_foxy.find_child("Bouton_Flash", true, false)
		if btn_flash:
			if not btn_flash.pressed.is_connected(_on_input_flash_pressed):
				btn_flash.pressed.connect(_on_input_flash_pressed) # Modifié

	# --- 4. BROUILLAGE ---
	if ecran_brouillage:
		ecran_brouillage.visible = false
	
	mettre_a_jour_image()

func _process(_delta):
	if not visible:
		if audio_mangle_static and audio_mangle_static.playing:
			audio_mangle_static.stop()
		if audio_switch and audio_switch.playing:
			audio_switch.stop()

# ============================================================
# PARTIE 1 : INPUTS (CLICS SOURIS)
# Ces fonctions envoient l'ordre au serveur via RPC
# ============================================================

func _on_input_vent_pressed():
	if NetworkGlobal.players.size() > 0:
		rpc("sync_action_vent_cctv") # On envoie l'ordre
	else:
		_executer_toggle_vent() # Solo

func _on_input_audio_pressed():
	if not a_du_courant: return
	if NetworkGlobal.players.size() > 0:
		rpc("sync_action_audio_lure", camera_actuelle)
	else:
		_executer_audio_lure(camera_actuelle)

func _on_input_flash_pressed():
	if not peut_flasher or not a_du_courant: return
	if NetworkGlobal.players.size() > 0:
		rpc("sync_action_flash")
	else:
		_executer_flash_foxy()

# ============================================================
# PARTIE 2 : ACTIONS RÉELLES (RPC)
# Exécutées chez TOUT LE MONDE (Serveur + Clients)
# ============================================================

# --- A. VENTILATION ---
@rpc("any_peer", "call_local", "reliable")
func sync_action_vent_cctv():
	# Si ça vient de la caméra, on exécute
	_executer_toggle_vent()
	
	# IMPORTANT : Si le bureau a aussi un bouton physique ou une variable d'état,
	# il faut s'assurer qu'Office.gd soit au courant.
	# Normalement Office.gd gère la logique "vent_scelle" principale.
	var office = get_owner()
	if office and office.has_method("commander_ventilation"):
		# On informe l'office sans recréer une boucle infinie RPC
		# (Ici on suppose que c'est juste visuel/bouton CCTV)
		if office.has_method("_on_toggle_vent"): # Si office a une méthode interne
			pass 

func _on_toggle_vent():
	_executer_toggle_vent()

# La vraie logique qui change la variable et le texte
func _executer_toggle_vent():
	vent_scelle = !vent_scelle
	if btn_vent:
		if vent_scelle: btn_vent.text = "OUVRIR VENT"
		else: btn_vent.text = "SCELLER VENT"
	
	# On informe l'Office pour qu'il mette à jour ses variables de jeu
	var office = get_owner()
	if office and "vent_scelle" in office.systeme_camera:
		office.systeme_camera.vent_scelle = vent_scelle
		
	print("Système Vent scellé : ", vent_scelle)


# --- B. AUDIO LEURRE ---
@rpc("any_peer", "call_local", "reliable")
func sync_action_audio_lure(cam_cible):
	_executer_audio_lure(cam_cible)

func _executer_audio_lure(cam_cible):
	print("Audio leurre reçu sur : ", cam_cible)
	
	var office = get_owner()
	if office and office.has_method("jouer_audio_leurre"):
		office.jouer_audio_leurre(cam_cible)
	
	# Cooldown visuel du bouton
	if btn_audio:
		btn_audio.disabled = true
		await get_tree().create_timer(3.0).timeout 
		if btn_audio: btn_audio.disabled = false


# --- C. FLASH FOXY ---
@rpc("any_peer", "call_local", "reliable")
func sync_action_flash():
	_executer_flash_foxy()

func _executer_flash_foxy():
	if camera_actuelle == "Cam03" and not foxy_attacking:
		if audio_flash_foxy: audio_flash_foxy.play()
		
		foxy_rage -= 1
		if foxy_rage < 0: foxy_rage = 0
		
		# On prévient aussi Office.gd qui gère la "vraie" rage de l'IA
		var office = get_owner()
		if office and office.has_method("update_foxy_rage"): 
			office.update_foxy_rage(foxy_rage) # Fonction hypothétique dans office
		
		flash_count_session += 1
		
		flash_screen_effect()
		mettre_a_jour_image()
		
		# Cooldown
		peut_flasher = false
		if btn_flash: btn_flash.disabled = true
		await get_tree().create_timer(temps_recharge_flash).timeout
		peut_flasher = true
		if btn_flash: btn_flash.disabled = false


# ============================================================
# PARTIE 3 : SYNCHRONISATION VISUELLE (LES ROBOTS)
# Cette fonction doit être appelée par Office.gd quand un robot bouge
# ============================================================

@rpc("authority", "call_remote", "reliable")
func sync_etat_salle(nom_salle : String, liste_occupants : Array):
	# 1. Mise à jour des données
	etat_salles[nom_salle] = liste_occupants
	
	# 2. Si on regarde cette salle sur la tablette, on met à jour l'image
	if camera_actuelle == nom_salle:
		mettre_a_jour_image()

	# 3. AJOUT IMPORTANT : On prévient le bureau de vérifier ses lumières/portes
	# C'est ce qui permet d'effacer Bonnie de la fenêtre immédiatement
	var office = get_owner()
	if office and office.has_method("update_office_background"):
		office.update_office_background()

# --- INPUT UTILISATEUR LOCAL (Boutons Caméras) ---
# Ces boutons restent locaux car chaque joueur regarde la caméra qu'il veut

func afficher_danger(nom_camera : String, est_visible : bool):
	var nom_bouton = "Bouton_" + nom_camera.to_upper()
	var bouton = find_child(nom_bouton, true, false)
	if bouton:
		var icon = bouton.get_node_or_null("Icone_Danger")
		if icon: icon.visible = est_visible

# --- GESTION DU MONITEUR ---

func toggle_monitor():
	if not a_du_courant: return
	est_ouvert = !est_ouvert
	visible = est_ouvert
	
	if est_ouvert:
		mettre_a_jour_image()

func fermer_moniteur():
	est_ouvert = false
	visible = false
	if audio_mangle_static: audio_mangle_static.stop()

func declencher_brouillage():
	if not est_ouvert: return
	if ecran_brouillage:
		ecran_brouillage.visible = true
		await get_tree().create_timer(1.0).timeout
		if ecran_brouillage: ecran_brouillage.visible = false

# --- NAVIGATION CAMÉRAS ---

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

func changer_camera(nom_cam : String):
	camera_actuelle = nom_cam
	if audio_switch: audio_switch.play()
	
	if btn_audio: btn_audio.visible = (nom_cam in chemin_chica_audio)
	if btn_vent: btn_vent.visible = (nom_cam == "Cam13")
	if ui_foxy: ui_foxy.visible = (nom_cam == "Cam03" and not foxy_attacking)
		
	mettre_a_jour_image()

# --- SYSTÈME D'IMAGES ---

func mettre_a_jour_image():
	if ecran_visuel == null: return
	
	var occupants_reels = []
	if etat_salles.has(camera_actuelle):
		occupants_reels = etat_salles[camera_actuelle].duplicate()
	
	gestion_audio_mangle(occupants_reels)
	
	var suffixe = ""
	
	if occupants_reels.is_empty():
		suffixe = "_Vide"
	else:
		occupants_reels.sort()
		for nom_monstre in occupants_reels:
			suffixe += "_" + nom_monstre
			
	if camera_actuelle == "Cam03":
		if foxy_attacking:
			ecran_visuel.texture = load("res://Cameras/Cam03_Vide.png")
			return
		elif occupants_reels.has("Foxy") or occupants_reels.is_empty(): 
			var phase = clampi(foxy_rage, 0, 4)
			var nom_img = "res://Cameras/Cam03_Foxy_" + str(phase) + ".png"
			if ResourceLoader.exists(nom_img):
				ecran_visuel.texture = load(nom_img)
			else:
				ecran_visuel.texture = load("res://Cameras/Cam03_Foxy_0.png")
			return

	var chemin_final = "res://Cameras/" + camera_actuelle + suffixe + ".png"
	
	if ResourceLoader.exists(chemin_final):
		ecran_visuel.texture = load(chemin_final)
	else:
		ecran_visuel.texture = load("res://Cameras/" + camera_actuelle + "_Vide.png")

func flash_screen_effect():
	var original = ecran_visuel.modulate
	ecran_visuel.modulate = Color(3, 3, 3)
	await get_tree().create_timer(0.05).timeout
	ecran_visuel.modulate = original

func couper_courant_camera():
	a_du_courant = false
	fermer_moniteur()
	if btn_vent: btn_vent.visible = false
	if btn_audio: btn_audio.visible = false
	
func gestion_audio_mangle(liste_occupants : Array):
	if not est_ouvert or not visible or audio_mangle_static == null:
		audio_mangle_static.stop()
		return

	if liste_occupants.has("Mangle"):
		if not audio_mangle_static.playing:
			audio_mangle_static.play()
	else:
		if audio_mangle_static.playing:
			audio_mangle_static.stop()
