class_name AnimatronicAI extends Node

# --- DONNÉES ---
var nom : String
var data_json : Dictionary
var path_list : Array = []
var current_path_index : int = 0

# --- RÉFÉRENCES ---
var camera_system_ref : Node 
var porte_cible : Node2D 
var office_ref : Node2D 

# --- TIMER ---
var move_timer : float = 0.0
var base_interval : float = 5.0 # Intervalle de base (ex: 5 secondes)

func setup(data, _camera_system_ref, _porte_cible, _office_ref):
	data_json = data
	nom = data["name"]
	path_list = data["path"]
	base_interval = data["movement_interval"] # On garde la valeur de base
	
	# On lance le timer
	reset_timer(0) # 0 pour l'IA initiale (sera maj au premier process)
	
	camera_system_ref = _camera_system_ref
	porte_cible = _porte_cible
	office_ref = _office_ref
	
	# INITIALISATION SÉCURISÉE
	var salle_depart = path_list[0]
	if camera_system_ref.etat_salles.has(salle_depart):
		if not camera_system_ref.etat_salles[salle_depart].has(nom):
			camera_system_ref.etat_salles[salle_depart].append(nom)
			camera_system_ref.mettre_a_jour_image()

func reset_timer(ai_level : int):
	# --- CALCUL DE LA VITESSE SELON L'IA ---
	# Plus l'IA est haute, plus le temps diminue.
	# Exemple : Base 5s. À niveau 20 -> 5 - (20 * 0.15) = 2 secondes.
	var reduction = float(ai_level) * 0.15
	var final_time = base_interval - reduction
	
	# On garde une limite minimum (par ex 2.0 secondes) pour pas que ce soit injouable
	if final_time < 2.0: final_time = 2.0
	
	move_timer = final_time

func process_ai(delta, current_ai_level):
	
	if Engine.get_frames_drawn() % 60 == 0:
		print(nom, " est au niveau IA : ", current_ai_level)
		
	if office_ref.game_over: return

	# --- LOGIQUE FREDDY (Ne bouge pas si on le regarde) ---
	if nom == "Freddy":
		var salle_actuelle = path_list[current_path_index]
		if camera_system_ref.est_ouvert and camera_system_ref.camera_actuelle == salle_actuelle:
			# On le bloque tant qu'on le regarde
			reset_timer(current_ai_level)
			return 

	# --- TIMER ---
	move_timer -= delta
	
	if move_timer <= 0:
		# Le timer est fini, on tente quelque chose !
		reset_timer(current_ai_level) # On relance le timer pour la prochaine fois
		attempt_logic(current_ai_level)

func attempt_logic(ai_level):
	# --- CAS FOXY ---
	if nom == "Foxy":
		gerer_foxy(ai_level)
		return

	# --- CAS NORMAUX (Bonnie, Chica, Freddy) ---
	
	# 1. Sommes-nous DÉJÀ à la porte (dernière étape) ?
	if current_path_index == path_list.size() - 1:
		# On est à la porte, on tente d'attaquer !
		# (Note: Dans FNaF, ils attaquent souvent immédiatement s'ils sont là, 
		# mais on peut ajouter un jet de dé si on veut les rendre hésitants)
		tenter_attaque()
	
	else:
		# 2. Nous sommes sur le chemin, on essaie d'avancer
		# Jet de dé standard (1 à 20)
		var roll = randi_range(1, 20)
		
		# Condition spéciale Freddy : Attend que Cam01 soit vide
		if nom == "Freddy" and current_path_index == 0:
			var occupants_scene = camera_system_ref.etat_salles["Cam01"]
			if occupants_scene.has("Bonnie") or occupants_scene.has("Chica"):
				return # Il attend son tour
		
		# Si le jet réussit, on avance
		if roll <= ai_level:
			avancer_sur_chemin()

func gerer_foxy(ai_level):
	if camera_system_ref.foxy_attacking: return
	
	var roll = randi_range(1, 20)
	if roll <= ai_level:
		camera_system_ref.foxy_rage += 1
		print("Foxy Rage : ", camera_system_ref.foxy_rage)
		
		if camera_system_ref.foxy_rage >= camera_system_ref.foxy_max_rage:
			lancer_attaque_foxy()
		else:
			camera_system_ref.mettre_a_jour_image()

func avancer_sur_chemin():
	# 1. ON SE RETIRE DE LA SALLE ACTUELLE
	var ancienne_salle = path_list[current_path_index]
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)

	# 2. ON AVANCE L'INDEX
	current_path_index += 1
	var nouvelle_salle = path_list[current_path_index]
	
	# 3. ON S'AJOUTE DANS LA NOUVELLE SALLE (CORRECTION VISUELLE ICI !)
	# Avant, tu avais un "return" ici qui empêchait l'ajout. Maintenant on l'ajoute.
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	print(nom, " a bougé vers ", nouvelle_salle)
	
	# 4. MISE A JOUR DES CAMERAS
	camera_system_ref.mettre_a_jour_image()

func tenter_attaque():
	print(nom, " VERIFIE LA PORTE...")
	
	# Cas Freddy
	if nom == "Freddy":
		office_ref.trigger_jumpscare("Freddy")
		return
	
	# Cas Bonnie / Chica
	if porte_cible and porte_cible.est_fermee:
		# --- ECHEC : RETOUR AU DEBUT ---
		print("BLOCKED! ", nom, " repart.")
		
		# On le retire visuellement de la porte
		var salle_porte = path_list[current_path_index]
		if camera_system_ref.etat_salles.has(salle_porte):
			camera_system_ref.etat_salles[salle_porte].erase(nom)
		
		# On cherche où retourner (Cam01 par défaut ou autre)
		current_path_index = 0 
		if nom == "Bonnie": current_path_index = path_list.find("Cam05") # Exemple de repli
		if current_path_index == -1: current_path_index = 0
		
		# On le remet dans la salle de repli
		var salle_repli = path_list[current_path_index]
		if camera_system_ref.etat_salles.has(salle_repli):
			camera_system_ref.etat_salles[salle_repli].append(nom)
			
		camera_system_ref.mettre_a_jour_image()
		
	else:
		# --- REUSSITE : MORT ---
		office_ref.trigger_jumpscare(nom)

# ... (Garde tes fonctions lancer_attaque_foxy et knock_door_foxy inchangées) ...
func lancer_attaque_foxy():
	print("FOXY COURT !")
	camera_system_ref.foxy_attacking = true
	camera_system_ref.mettre_a_jour_image()
	await office_ref.get_tree().create_timer(randf_range(6.0, 10.0)).timeout
	knock_door_foxy()

func knock_door_foxy():
	if office_ref.game_over: return
	if porte_cible and porte_cible.est_fermee:
		print("FOXY BLOQUÉ")
		office_ref.batterie -= 5.0
		if office_ref.batterie < 0: office_ref.batterie = 0
		office_ref.label_batterie.text = "Power: " + str(int(office_ref.batterie)) + "%"
		camera_system_ref.foxy_rage = 0
		camera_system_ref.foxy_attacking = false
		camera_system_ref.mettre_a_jour_image()
	else:
		office_ref.trigger_jumpscare("Foxy")
