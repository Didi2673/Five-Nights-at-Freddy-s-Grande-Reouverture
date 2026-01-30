class_name AnimatronicAI extends Node

# --- DONNÉES ---
var nom : String
var data_json : Dictionary
var json_index : int = 0
var path_list : Array = []
var current_path_index : int = 0

# --- RÉFÉRENCES ---
var camera_system_ref : Node 
var porte_cible : Node2D 
var office_ref : Node2D 

# --- TIMER ---
var move_timer : float = 0.0
var base_interval : float = 5.0

var current_ai_level : int = 0

func setup(data, _camera_system_ref, _porte_cible, _office_ref, _real_index):
	json_index = _real_index
	data_json = data
	nom = data["name"]
	path_list = data["path"]
	base_interval = data["movement_interval"]
	
	reset_timer(0)
	
	camera_system_ref = _camera_system_ref
	porte_cible = _porte_cible
	office_ref = _office_ref
	
	# INITIALISATION SÉCURISÉE
	var salle_depart = path_list[0]
	if camera_system_ref.etat_salles.has(salle_depart):
		if not camera_system_ref.etat_salles[salle_depart].has(nom):
			camera_system_ref.etat_salles[salle_depart].append(nom)
			#camera_system_ref.mettre_a_jour_image()

func definir_visibilite_camera(est_visible : bool):
	var salle_actuelle = path_list[current_path_index]
	
	if est_visible:
		if camera_system_ref.etat_salles.has(salle_actuelle):
			if not camera_system_ref.etat_salles[salle_actuelle].has(nom):
				camera_system_ref.etat_salles[salle_actuelle].append(nom)
	else:
		if camera_system_ref.etat_salles.has(salle_actuelle):
			if camera_system_ref.etat_salles[salle_actuelle].has(nom):
				camera_system_ref.etat_salles[salle_actuelle].erase(nom)
				
	camera_system_ref.mettre_a_jour_image()

func tenter_jouer_son_vent():
	if office_ref.has_node("Audio_Vent_Move"):
		var audio = office_ref.get_node("Audio_Vent_Move")
		audio.pitch_scale = randf_range(0.9, 1.1)
		audio.play()

func reset_timer(ai_level : int):
	move_timer = base_interval

# --- RECEPTION AUDIO (CHICA) ---
func recevoir_audio(camera_source : String):
	if nom != "Chica": return
	
	if current_path_index == path_list.size() - 1:
		print("ECHEC : Chica est déjà à la porte.")
		return
	
	var index_son = path_list.find(camera_source)
	if index_son == -1: return
	if index_son == 0: return 

	if index_son == current_path_index - 1:
		print("SUCCÈS ! Chica recule vers ", camera_source)
		reculer_sur_chemin(index_son)
		move_timer = base_interval 
	else:
		print("ECHEC DE DISTANCE.")
		
func reculer_sur_chemin(index_cible):
	var ancienne_salle = path_list[current_path_index]
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)
	
	current_path_index = index_cible
	var nouvelle_salle = path_list[current_path_index]
	
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	camera_system_ref.mettre_a_jour_image()

func process_ai(delta, current_ai_level_arg):
	current_ai_level = current_ai_level_arg
	
	if office_ref.game_over: return
	
	
	if nom == "Chica":
		if current_path_index == path_list.size() - 1:
			verifier_porte_ouverte()
			return

	if nom == "Freddy":
		if not office_ref.ventilateur_actif:
			reset_timer(current_ai_level)
			return

	move_timer -= delta
	
	if move_timer <= 0:
		reset_timer(current_ai_level)
		attempt_logic(current_ai_level)
		
func verifier_porte_ouverte():
	if porte_cible and not porte_cible.est_fermee:
		if randf() < 0.05: 
			print("CHICA EST RENTRÉE !")
			office_ref.trigger_jumpscare("Chica")

func attempt_logic(ai_level):
	if nom == "Foxy":
		gerer_foxy(ai_level)
		return
	
	if nom == "Mangle":
		attempt_mangle_move(ai_level)
		return

	if nom == "Springtrap":
		process_springtrap_logic(ai_level)
		return

	
	if nom == "Freddy":
		if current_path_index == 0:
			# --- MODIFICATION ICI : GESTION DU CHALLENGE ---
			# Par défaut, Freddy respecte la règle.
			# MAIS si on est dans le challenge "bear_attack", il l'ignore.
			if GameData.active_challenge_id != "bear_attack":
				
				var occupants_scene = camera_system_ref.etat_salles["Cam01"]
				
				# Si Bonnie OU Chica sont sur la scène, Freddy attend.
				if occupants_scene.has("Bonnie") or occupants_scene.has("Chica"):
					return 
			# -----------------------------------------------

		# 2. CONDITION VENTILATEUR
		if not office_ref.ventilateur_actif:
			return 

		# 3. TENTATIVE DE MOUVEMENT
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			if current_path_index == path_list.size() - 1:
				tenter_attaque()
			else:
				avancer_sur_chemin()
		return

	# --- LOGIQUE CHICA ---
	if nom == "Chica":
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			avancer_sur_chemin()
		return
		
	# --- LOGIQUE PUPPET ---
	if nom == "Puppet":
		if current_path_index < path_list.size() - 1:
			var roll = randi_range(1, 20)
			if roll <= ai_level:
				avancer_sur_chemin()
		return
		
	# --- LOGIQUE STANDARD (BONNIE) ---
	if current_path_index == path_list.size() - 1:
		tenter_attaque()
	else:
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			avancer_sur_chemin()

# --- MANGLE ---
func attempt_mangle_move(ai_level):
	var roll = randi_range(1, 20)
	if roll > ai_level: return

	if current_path_index == path_list.size() - 1:
		if camera_system_ref.vent_scelle:
			print("BLOCKED! Mangle heurte la ventilation scellée.")
			tenter_jouer_son_vent()
			changer_position(0)
		else:
			print("MANGLE ENTRE DANS LE BUREAU !")
			office_ref.trigger_jumpscare("Mangle")
	else:
		avancer_sur_chemin()
		
func changer_position(nouvel_index):
	var ancienne_salle = path_list[current_path_index]
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)
	
	current_path_index = nouvel_index
	var nouvelle_salle = path_list[current_path_index]
	
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	print(nom, " a été déplacé vers ", nouvelle_salle)
	
	var cam_joueur = camera_system_ref.camera_actuelle
	if camera_system_ref.est_ouvert and (cam_joueur == ancienne_salle or cam_joueur == nouvelle_salle):
		if camera_system_ref.has_method("declencher_brouillage"):
			camera_system_ref.declencher_brouillage()
	
	camera_system_ref.mettre_a_jour_image()
	
func gerer_foxy(ai_level):
	if not "foxy_attacking" in camera_system_ref: return
	if camera_system_ref.foxy_attacking: return
	
	var roll = randi_range(1, 20)
	if roll <= ai_level:
		if "foxy_rage" in camera_system_ref:
			camera_system_ref.foxy_rage += 1
			var max_rage = 5
			if "foxy_max_rage" in camera_system_ref:
				max_rage = camera_system_ref.foxy_max_rage
			
			if camera_system_ref.foxy_rage >= max_rage:
				lancer_attaque_foxy()
			else:
				camera_system_ref.mettre_a_jour_image()

func avancer_sur_chemin():
	var ancienne_salle = path_list[current_path_index]
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)

	current_path_index += 1
	var nouvelle_salle = path_list[current_path_index]
	
	if "Cam09" in ancienne_salle or "Cam13" in nouvelle_salle:
		tenter_jouer_son_vent()
	
	# --- SON SPÉCIFIQUE FREDDY ---
	if nom == "Freddy": 
		jouer_rire_freddy()
	
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	print(nom, " a bougé vers ", nouvelle_salle)
	camera_system_ref.mettre_a_jour_image()

func jouer_rire_freddy():
	if office_ref.has_node("Audio_Freddy_Laugh"):
		office_ref.get_node("Audio_Freddy_Laugh").play()

func tenter_attaque():
	# Freddy tue s'il arrive à la fin de son chemin (Office_Vent_Pos)
	if nom == "Freddy":
		office_ref.trigger_jumpscare("Freddy")
		return
	
	if porte_cible and porte_cible.est_fermee:
		print("BLOCKED! ", nom, " repart.")
		var salle_porte = path_list[current_path_index]
		if camera_system_ref.etat_salles.has(salle_porte):
			camera_system_ref.etat_salles[salle_porte].erase(nom)
		
		current_path_index = 0 
		if nom == "Bonnie": current_path_index = path_list.find("Cam02") 
		if current_path_index == -1: current_path_index = 0
		
		var salle_repli = path_list[current_path_index]
		if camera_system_ref.etat_salles.has(salle_repli):
			camera_system_ref.etat_salles[salle_repli].append(nom)
			
		camera_system_ref.mettre_a_jour_image()
	else:
		office_ref.trigger_jumpscare(nom)

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
		office_ref.label_batterie.text = "Power : " + str(int(office_ref.batterie)) + "%"
		camera_system_ref.foxy_rage = 0
		camera_system_ref.foxy_attacking = false
		camera_system_ref.mettre_a_jour_image()
	else:
		office_ref.trigger_jumpscare("Foxy")

# --- SPRINGTRAP ---
func process_springtrap_logic(ai_level):
	var roll = randi_range(1, 20)
	if roll > ai_level: return 
	
	var salle_actuelle = path_list[current_path_index]
	
	match salle_actuelle:
		"Cam02":
			if randf() < 0.5: deplacer_springtrap("Cam07")
			else: deplacer_springtrap("Cam10")
		"Cam07":
			if randf() < 0.5:
				print("Springtrap entre dans la ventilation (Cam13)...")
				deplacer_springtrap("Cam13") 
				tenter_jouer_son_vent()
			else:
				deplacer_springtrap("Cam11")
		"Cam10":
			if randf() < 0.5:
				print("Springtrap entre dans la ventilation (Cam13)...")
				deplacer_springtrap("Cam13")
				tenter_jouer_son_vent()
			else:
				deplacer_springtrap("Cam12")
		"Cam13":
			verifier_attaque_ventilation()
		"Cam11":
			attaquer_porte("left")
		"Cam12":
			attaquer_porte("right")

func verifier_attaque_ventilation():
	if camera_system_ref.vent_scelle:
		print("BLOCKED! Springtrap heurte la grille.")
		if office_ref.has_node("Audio_Vent_Bang"):
			office_ref.get_node("Audio_Vent_Bang").play()
		else:
			tenter_jouer_son_vent()
		var index_start = path_list.find("Cam02")
		changer_position(index_start)
	else:
		print("SPRINGTRAP SORT DE LA VENT -> MORT !")
		office_ref.trigger_jumpscare("Springtrap")

func deplacer_springtrap(nom_cible : String):
	var nouvel_index = path_list.find(nom_cible)
	if nouvel_index != -1:
		changer_position(nouvel_index) 

func attaquer_porte(cote : String):
	print("SPRINGTRAP TENTE D'ENTRER PAR : ", cote)
	var porte_bloquee = false
	if cote == "left":
		if office_ref.porte_gauche.est_fermee: porte_bloquee = true
	elif cote == "right":
		if office_ref.porte_droite.est_fermee: porte_bloquee = true
		
	if porte_bloquee:
		print("BLOCKED! Springtrap repart.")
		var index_start = path_list.find("Cam02")
		changer_position(index_start)
	else:
		office_ref.trigger_jumpscare("Springtrap")
