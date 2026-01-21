extends Node

# --- RÉFÉRENCES ---
# L'image qui change (Le TextureRect dans ton interface)
@export var ecran_visuel : TextureRect 
# Le noeud racine de ton interface (Moniteur_CCTV) pour le cacher/montrer
@export var ui_moniteur : Control 

# --- VARIABLES D'ÉTAT ---
var est_ouvert : bool = false # <--- La variable qui manquait !
var a_du_courant : bool = true
var camera_actuelle : String = "Cam01"

var ui_music_box : Control
var progress_bar : Range
var btn_wind : BaseButton

var ui_foxy : Control # <--- Nouveau
var btn_flash : BaseButton # <--- Nouveau

# --- VARIABLES PUPPET ---
var music_timer : float = 100.0
var music_max : float = 100.0
var drain_speed : float = 0.0 # Vitesse de descente (ajuste selon difficulté)
var puppet_escaped : bool = false
var puppet_attack_delay : float = 5.0
var puppet_data_index : int = -1

# --- VARIABLES FOXY ---
var peut_flasher : bool = true
var temps_recharge_flash : float = 3.0
var foxy_rage : int = 0
var foxy_max_rage : int = 5
var foxy_attacking : bool = false # Si vrai, il a quitté le rideau

# Dictionnaire : "Nom_Camera" -> Liste de Strings (Array)
var etat_salles = {
	"Cam01": [], # Départ
	"Cam02": [],
	"Cam03": [],
	"Cam04": ["Puppet"],
	"Cam05": [],
	"Cam06": [],
	"Cam07": [],
	"Cam08": [],
	"Cam09": [],
	"Cam10": [],
	"Cam11": [],
	"Cam12": []
	# Ajoute les autres caméras ici...
}

func _ready():
	# 1. Configuration UI (Comme avant)
	if ui_moniteur:
		ui_moniteur.visible = false
		ui_music_box = ui_moniteur.find_child("MusicBox_UI", true, false)
		if ui_music_box:
			progress_bar = ui_music_box.find_child("Barre_Musique", true, false)
			btn_wind = ui_music_box.find_child("Bouton_Wind", true, false)
			if btn_wind:
				if not btn_wind.button_down.is_connected(_on_wind_start):
					btn_wind.button_down.connect(_on_wind_start)
				if not btn_wind.button_up.is_connected(_on_wind_stop):
					btn_wind.button_up.connect(_on_wind_stop)
		ui_foxy = ui_moniteur.find_child("Foxy_UI", true, false)
		if ui_foxy:
			btn_flash = ui_foxy.find_child("Bouton_Flash", true, false)
			if btn_flash:
				btn_flash.pressed.connect(_on_flash_foxy)

	# 2. TROUVER LA PUPPET DANS LE JSON
	# On cherche l'index de la Puppet dans la liste chargée par GameData
	for i in range(GameData.animatronics_data.size()):
		if GameData.animatronics_data[i]["name"] == "Puppet":
			puppet_data_index = i
			break
	
	mettre_a_jour_image()
	
func _on_flash_foxy():
	if not peut_flasher: return
	
	if camera_actuelle == "Cam03" and not foxy_attacking:
		print("FLASH FOXY !")
		# On baisse la rage
		foxy_rage -= 1
		if foxy_rage < 0: foxy_rage = 0
		
		# Effet visuel (Optionnel : Flash blanc sur l'écran)
		flash_screen_effect() 
		
		# On met à jour l'image (pour voir s'il recule dans le rideau)
		mettre_a_jour_image()
		
		peut_flasher = false # On verrouille
		
		# On désactive le bouton visuellement (il deviendra grisé)
		if btn_flash: btn_flash.disabled = true 
		
		# 3. ATTENTE (3 Secondes)
		await get_tree().create_timer(temps_recharge_flash).timeout
		
		# 4. FIN DU COOLDOWN
		peut_flasher = true # On déverrouille
		
		# On réactive le bouton (s'il est encore affiché)
		if btn_flash: btn_flash.disabled = false

func flash_screen_effect():
	# Petit effet rapide pour feedback
	var original_modulate = ecran_visuel.modulate
	ecran_visuel.modulate = Color(10, 10, 10) # Très brillant
	await get_tree().create_timer(0.1).timeout
	ecran_visuel.modulate = original_modulate

func _process(delta):
	if puppet_escaped:
		puppet_attack_delay -= delta
		if puppet_attack_delay <= 0:
			lancer_attaque_puppet()
		return

	# GESTION DE LA BOITE À MUSIQUE
	if music_timer > 0:
		if est_winding and camera_actuelle == "Cam04" and est_ouvert:
			# Vitesse de remontage (Fixe, ex: 15% par seconde)
			music_timer += 15.0 * delta 
		else:
			# Vitesse de descente (DYNAMIQUE selon le JSON)
			music_timer -= drain_speed * delta 
		
		music_timer = clamp(music_timer, 0.0, music_max)
		
		if progress_bar:
			progress_bar.value = music_timer
		
		if music_timer <= 0:
			trigger_puppet_escape()

# --- NOUVELLE FONCTION : MISE À JOUR DIFFICULTÉ ---
# Cette fonction sera appelée par Office.gd à chaque changement d'heure
func update_puppet_difficulty(current_hour : int, night_index : int):
	if puppet_data_index != -1:
		# On utilise la fonction helper de GameData (si elle existe)
		# Sinon on lit le tableau manuellement
		var niveau = GameData.get_ai_level(puppet_data_index, night_index, current_hour)
		
		# On applique le niveau comme vitesse
		drain_speed = float(niveau)
		
		# Optionnel : Afficher pour déboguer
		# print("Heure : ", current_hour, " -> Vitesse Puppet : ", drain_speed)

# --- LOGIQUE DE REMONTAGE ---
var est_winding : bool = false

func _on_wind_start():
	est_winding = true

func _on_wind_stop():
	est_winding = false

# --- LOGIQUE DE FUITE ---
func trigger_puppet_escape():
	print("LA MUSIQUE S'EST ARRÊTÉE...")
	puppet_escaped = true
	
	# 1. On retire la Puppet de la liste (pour afficher l'image Vide)
	if etat_salles["Cam04"].has("Puppet"):
		etat_salles["Cam04"].erase("Puppet")
	
	# 2. On rafraichit l'écran si on regarde la Cam 4
	if camera_actuelle == "Cam04":
		mettre_a_jour_image()
		# On cache l'UI car c'est trop tard
		if ui_music_box: ui_music_box.visible = false

func lancer_attaque_puppet():
	# On appelle le Game Over directement dans Office
	var office = get_parent() # On suppose que Cameras_System est enfant de Office
	if office.has_method("trigger_jumpscare"):
		office.trigger_jumpscare("Puppet")

# --- NAVIGATION ---
func changer_camera(nom_cam : String):
	camera_actuelle = nom_cam
	
	# GESTION VISIBILITÉ UI MUSIC BOX
	if ui_music_box:
		# Visible SEULEMENT si c'est Cam04 ET que la Puppet est encore là
		if nom_cam == "Cam04" and not puppet_escaped:
			ui_music_box.visible = true
		else:
			ui_music_box.visible = false
			est_winding = false # Sécurité si on change de cam en restant appuyé
	
	if ui_foxy:
		# Visible si Cam03 ET Foxy n'attaque pas
		ui_foxy.visible = (nom_cam == "Cam03" and not foxy_attacking)
		
		# --- CORRECTION DU BOUTON ---
		# Si le bouton est visible, on vérifie s'il doit être grisé ou non
		if btn_flash:
			# Il est désactivé si "peut_flasher" est faux
			btn_flash.disabled = not peut_flasher
			
	mettre_a_jour_image()

# --- GESTION DES ENTRÉES (OUVERTURE/FERMETURE) ---
func _input(event):
	# Si on a du courant et qu'on appuie sur ESPACE
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("Touche Espace détectée ! Courant : ", a_du_courant)
		
		if a_du_courant:
			toggle_moniteur()

func toggle_moniteur():
	est_ouvert = !est_ouvert
	
	if ui_moniteur:
		ui_moniteur.visible = est_ouvert
	
	# Si on ouvre, on rafraîchit l'image tout de suite
	if est_ouvert:
		mettre_a_jour_image()

func fermer_moniteur():
	est_ouvert = false
	if ui_moniteur:
		ui_moniteur.visible = false

# Appelée par Office.gd quand la batterie est à 0%
func couper_courant_camera():
	a_du_courant = false
	fermer_moniteur()

func mettre_a_jour_image():
	if ecran_visuel == null: return
	
	# 1. Récupérer la liste
	var occupants : Array = []
	if etat_salles.has(camera_actuelle):
		occupants = etat_salles[camera_actuelle]
	
	# 2. Construire le suffixe
	var suffixe = ""
	if occupants.is_empty():
		suffixe = "_Vide"
	else:
		occupants.sort() # Tri alphabétique CRUCIAL
		for nom_monstre in occupants:
			suffixe += "_" + nom_monstre
			
	# LOGIQUE VISUELLE SPÉCIALE FOXY (CAM 03)
	if camera_actuelle == "Cam03":
		if foxy_attacking:
			# Si Foxy est parti attaquer -> Rideau grand ouvert (Vide)
			ecran_visuel.texture = load("res://Cameras/Cam03_Vide.png")
			return # On arrête là, on ne charge pas autre chose
		else:
			# Foxy est là, son image dépend de sa rage (Phases)
			# Cam03_Foxy_0.png (Fermé)
			# Cam03_Foxy_1.png (Un peu ouvert) ...
			# Cam03_Foxy_4.png (Prêt à courir)
			var phase = clampi(foxy_rage, 0, 4) # On clamp à 4 max pour les images
			var nom_img = "Cam03_Foxy_" + str(phase) + ".png"
			
			if FileAccess.file_exists("res://Cameras/" + nom_img):
				ecran_visuel.texture = load("res://Cameras/" + nom_img)
			else:
				ecran_visuel.texture = load("res://Cameras/Cam03_Foxy_0.png")
			return
	
	# 3. Vérifier le fichier
	var nom_fichier = camera_actuelle + suffixe + ".png"
	var chemin_image = "res://Cameras/" + nom_fichier
	
	if FileAccess.file_exists(chemin_image):
		ecran_visuel.texture = load(chemin_image)
	else:
		# --- LE DIAGNOSTIC ---
		print("⚠️ ALERTE FICHIER MANQUANT ⚠️")
		print("Le jeu cherche : ", nom_fichier)
		print("Les occupants sont : ", occupants)
		print("Je charge l'image VIDE par sécurité.")
		print("--------------------------------")
		
		# Fallback sur l'image vide pour ne pas crasher
		ecran_visuel.texture = load("res://Cameras/" + camera_actuelle + "_Vide.png")
