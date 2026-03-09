extends Control

# --- RÉFÉRENCES VISUELLES ---
@export var ecran_visuel : TextureRect 
@export var ecran_brouillage : ColorRect # Assigne-le dans l'inspecteur si possible
var est_en_brouillage : bool = false

var flash_count_session : int = 0

# --- RÉFÉRENCES AUDIO ---
@onready var audio_switch = $Audio_Switch_Cam
@onready var audio_flash_foxy = $Audio_Flash_Foxy
@onready var audio_mangle_static = $Audio_Mangle_Static # <-- AJOUTE ÇA

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

# --- FOXY (Gardé pour le flash) ---
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
	"Left_Door_Pos": [],   # Position finale (invisible)
	"Right_Door_Pos": [],  # Position finale (invisible)
}

func _ready():
	visible = false 
	"""
	# --- 1. CONFIGURATION AUDIO (CHICA) ---
	btn_audio = find_child("Bouton_Audio", true, false)
	if btn_audio:
		if not btn_audio.pressed.is_connected(_on_audio_pressed):
			btn_audio.pressed.connect(_on_audio_pressed)
		btn_audio.visible = false
	"""
	# --- 2. CONFIGURATION VENTILATION (SPRINGTRAP/MANGLE) ---
	btn_vent = find_child("Bouton_Vent", true, false)
	if btn_vent:
		btn_vent.visible = false 
		if not btn_vent.pressed.is_connected(_on_toggle_vent):
			btn_vent.pressed.connect(_on_toggle_vent)
			
	# --- 3. CONFIGURATION FOXY (FLASH) ---
	ui_foxy = find_child("Foxy_UI", true, false)
	if ui_foxy:
		btn_flash = ui_foxy.find_child("Bouton_Flash", true, false)
		if btn_flash:
			if not btn_flash.pressed.is_connected(_on_flash_foxy):
				btn_flash.pressed.connect(_on_flash_foxy)

	# --- 4. BROUILLAGE ---
	if ecran_brouillage:
		ecran_brouillage.visible = false
	
	mettre_a_jour_image()

# --- AJOUT PRINCIPAL : LA SÉCURITÉ AUDIO CONTINUE ---
func _process(_delta):
	# Si le moniteur n'est pas visible (fermé par le joueur ou par le jeu)
	if not visible:
		# On force l'arrêt du static de Mangle s'il joue encore
		if audio_mangle_static and audio_mangle_static.playing:
			audio_mangle_static.stop()
			
		# Optionnel : On coupe aussi le bruit de switch caméra pour être propre
		if audio_switch and audio_switch.playing:
			audio_switch.stop()

# --- INPUT UTILISATEUR ---
func afficher_danger(nom_camera : String, est_visible : bool):
	# On cherche le bouton qui correspond à la caméra (ex: "Bouton_Cam04")
	# Adaptez le nom "Bouton_" selon comment vous avez nommé vos nœuds !
	# Si vos boutons s'appellent juste "Cam01", retirez le "Bouton_" dans le code ci-dessous.
	var nom_bouton = "Bouton_" + nom_camera.to_upper()
	
	# On cherche le nœud dans l'arbre
	var bouton = find_child(nom_bouton, true, false)
	
	if bouton:
		# On cherche l'icone qu'on a créée à l'étape 1
		var icon = bouton.get_node_or_null("Icone_Danger")
		if icon:
			icon.visible = est_visible
	else:
		print("ERREUR : Impossible de trouver le bouton pour ", nom_camera)


func _on_toggle_vent():
	# On inverse l'état
	vent_scelle = !vent_scelle
	
	if btn_vent:
		if vent_scelle:
			btn_vent.text = "OUVRIR VENT"
		else:
			btn_vent.text = "SCELLER VENT"
			
	print("Système Vent scellé : ", vent_scelle)

func _on_audio_pressed():
	if not a_du_courant: return
	
	var cam_cible = camera_actuelle
	print("Audio leurre envoyé sur : ", cam_cible)
	
	# On envoie l'info à l'Office (qui transmettra aux robots)
	var office = get_owner() # Cherche la racine de la scène (Office)
	if office and office.has_method("jouer_audio_leurre"):
		office.jouer_audio_leurre(cam_cible)
	
	# Cooldown du bouton
	if btn_audio:
		btn_audio.disabled = true
		await get_tree().create_timer(3.0).timeout 
		if btn_audio: btn_audio.disabled = false

func _on_flash_foxy():
	if not peut_flasher or not a_du_courant: return
	
	# Le flash ne marche que sur la Cam03
	if camera_actuelle == "Cam03" and not foxy_attacking:
		if audio_flash_foxy: audio_flash_foxy.play()
		
		# On calme Foxy (mécanique visuelle et logique)
		foxy_rage -= 1
		if foxy_rage < 0: foxy_rage = 0
		
		flash_count_session += 1
		if flash_count_session >= 10:
			GameData.unlock_achievement("foxy_flasher")
		
		# Feedback visuel
		flash_screen_effect()
		mettre_a_jour_image()
		
		# Cooldown
		peut_flasher = false
		if btn_flash: btn_flash.disabled = true
		await get_tree().create_timer(temps_recharge_flash).timeout
		peut_flasher = true
		if btn_flash: btn_flash.disabled = false
		
		# Note : C'est office.gd qui gère le "Vrai" reset de Foxy via une fonction aussi

# --- GESTION DU MONITEUR ---

func toggle_monitor():
	if not a_du_courant: return
	
	if est_ouvert:
		# Si le moniteur était ouvert, on appelle la vraie fonction de fermeture
		fermer_moniteur()
	else:
		# Sinon, on l'ouvre
		est_ouvert = true
		visible = true
		mettre_a_jour_image()

func fermer_moniteur():
	est_ouvert = false
	visible = false
	
	# Au lieu de baisser le volume, on stop proprement
	# (Le _process est une double sécurité, mais on le fait ici aussi)
	if audio_mangle_static: audio_mangle_static.stop()
	$Audio_Static.stop()

func declencher_brouillage():
	# Si le moniteur est fermé ou qu'un brouillage est DÉJÀ en cours, on annule
	if not est_ouvert or est_en_brouillage: return
	
	est_en_brouillage = true
	
	# 1. On lance le son de static
	if has_node("Audio_Static"):
		$Audio_Static.play()
	
	# 2. On met à jour l'image (ça va forcer le "Signal_Perdu.png" grâce à notre ajout précédent)
	mettre_a_jour_image()
	
	if ecran_brouillage:
		ecran_brouillage.visible = true
		
	# 3. On attend 2 secondes
	await get_tree().create_timer(2.0).timeout
	
	# 4. On remet tout à la normale
	est_en_brouillage = false
	
	if ecran_brouillage:
		ecran_brouillage.visible = false
		
	if has_node("Audio_Static"):
		$Audio_Static.stop()
		
	# On recharge l'image normale de la caméra (seulement si le moniteur est toujours ouvert)
	if est_ouvert:
		mettre_a_jour_image()

# --- NAVIGATION CAMÉRAS ---

# Relie tes boutons UI à ces fonctions :
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
	"""
	# 1. Gestion Bouton AUDIO (Chica)
	if btn_audio:
		# Visible seulement si utile pour Chica
		btn_audio.visible = (nom_cam in chemin_chica_audio)
"""
	# 2. Gestion Bouton VENT (Springtrap / Mangle)
	if btn_vent:
		# Visible seulement sur la caméra de ventilation
		btn_vent.visible = (nom_cam == "Cam13")
	
	# 3. Gestion UI Foxy
	if ui_foxy:
		ui_foxy.visible = (nom_cam == "Cam03" and not foxy_attacking)
		
	mettre_a_jour_image()

# --- SYSTÈME D'IMAGES (LE COEUR DU CODE) ---

func mettre_a_jour_image():
	if ecran_visuel == null: return
	if est_en_brouillage:
		ecran_visuel.texture = load("res://Cameras/Signal_Perdu.png")
		return # On bloque tout le reste du code
		
	if GameData.current_night_played == 7 and camera_actuelle == "Cam01":
		# L'écran n'aura pas de texture (il sera transparent/noir selon ton fond d'écran)
		#ecran_visuel.texture = null 
		
		# OPTIONNEL : Si tu as dessiné une image spéciale "Signal Perdu", 
		# tu peux retirer le "null" au-dessus et décommenter la ligne ci-dessous :
		ecran_visuel.texture = load("res://Cameras/Signal_Perdu.png")
		
		return # On arrête la fonction ici pour ne pas charger les monstres
		
	# 1. On récupère qui est dans la salle
	var occupants_reels = []
	if etat_salles.has(camera_actuelle):
		occupants_reels = etat_salles[camera_actuelle].duplicate() # Important : duplicate pour ne pas modifier la vraie liste
	
	# --- GESTION AUDIO MANGLE ---
	gestion_audio_mangle(occupants_reels)
	
	if GameData.no_cameras_mode_active:
		ecran_visuel.texture = load("res://Cameras/Signal_Perdu.png") # Ou texture = null
		return # On bloque le reste de l'affichage
		
	# 3. Construction du nom de l'image
	var suffixe = ""
	
	if occupants_reels.is_empty():
		suffixe = "_Vide"
	else:
		occupants_reels.sort() # Trie par ordre alphabétique (ex: Bonnie_Chica)
		for nom_monstre in occupants_reels:
			suffixe += "_" + nom_monstre
			
	# --- CAS SPÉCIAL : FOXY (Cam03) ---
	if camera_actuelle == "Cam03":
		if foxy_attacking:
			# Foxy est parti attaquer, la salle est vide (ou avec d'autres robots)
			ecran_visuel.texture = load("res://Cameras/Cam03_Vide.png")
			return
		elif occupants_reels.has("Foxy") or occupants_reels.is_empty(): 
			# Si Foxy est là (il est seul dans sa rideau), on affiche selon sa rage
			var phase = clampi(foxy_rage, 0, 4)
			var nom_img = "res://Cameras/Cam03_Foxy_" + str(phase) + ".png"
			if ResourceLoader.exists(nom_img):
				ecran_visuel.texture = load(nom_img)
			else:
				ecran_visuel.texture = load("res://Cameras/Cam03_Foxy_0.png")
			return

	# --- CHARGEMENT STANDARD ---
	var chemin_final = "res://Cameras/" + camera_actuelle + suffixe + ".png"
	
	if ResourceLoader.exists(chemin_final):
		ecran_visuel.texture = load(chemin_final)
	else:
		# Si l'image combinée n'existe pas (ex: Chica + Freddy ensemble), on met l'image vide ou statique
		print("Image manquante : ", chemin_final)
		ecran_visuel.texture = load("res://Cameras/" + camera_actuelle + "_Vide.png")

func flash_screen_effect():
	# Petit effet blanc rapide pour simuler le flash
	var original = ecran_visuel.modulate
	ecran_visuel.modulate = Color(3, 3, 3) # Très brillant
	await get_tree().create_timer(0.05).timeout
	ecran_visuel.modulate = original

# --- FONCTION COUPURE COURANT ---
func couper_courant_camera():
	a_du_courant = false
	fermer_moniteur()
	if btn_vent: btn_vent.visible = false
	if btn_audio: btn_audio.visible = false
	
func gestion_audio_mangle(liste_occupants : Array):
	# Note : Cette fonction sert pour l'activation quand on change de caméra.
	# La désactivation d'urgence (fermeture moniteur) est gérée par _process.
	
	if not est_ouvert or not visible or audio_mangle_static == null:
		audio_mangle_static.stop()
		return

	# Si Mangle est dans la liste des occupants de la caméra actuelle
	if liste_occupants.has("Mangle"):
		# On lance le son s'il ne joue pas déjà
		if not audio_mangle_static.playing:
			audio_mangle_static.play()
	else:
		# Mangle n'est pas là, on coupe
		if audio_mangle_static.playing:
			audio_mangle_static.stop()
