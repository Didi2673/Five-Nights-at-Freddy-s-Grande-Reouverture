class_name AnimatronicAI extends Node

# --- DONNÉES ---
var nom : String
var data_json : Dictionary
var json_index : int = 0
var path_list : Array = []
var current_path_index : int = 0

var sb_active : bool = false        # Est-il apparu ?
var sb_kill_timer : float = 8.0    # Le joueur a 10s pour réagir
var sb_stare_timer : float = 0.0    # Le joueur doit le regarder 3s
var sb_room : String = ""


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
	
	if nom == "Shadow-Bonnie":
		return
	
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
	
	# --- AJOUT SYNCHRO ---
	var office = get_parent()
	if office.has_method("sync_move_client"):
		office.sync_move_client(ancienne_salle, nouvelle_salle)
	# ---------------------
	
	camera_system_ref.mettre_a_jour_image()

func process_ai(delta, current_ai_level_arg):
	if NetworkGlobal.game_mode == "VS":
		return
	
	if NetworkGlobal.players.size() > 0 and not multiplayer.is_server():
		return
	current_ai_level = current_ai_level_arg
	
	if office_ref.game_over or office_ref.est_coupure_courant: return
	
	
	if nom == "Chica":
		if current_path_index == path_list.size() - 1:
			verifier_porte_ouverte()
			return
			
	if nom == "Shadow-Bonnie" and sb_active:
		
		# 1. KILL TIMER (Le joueur a 30s pour réagir)
		sb_kill_timer -= delta
		if sb_kill_timer <= 0:
			office_ref.trigger_jumpscare(nom)
			return

		if camera_system_ref.est_ouvert and camera_system_ref.camera_actuelle == sb_room:
			sb_stare_timer += delta
			
			if sb_stare_timer >= 1.0: 
				desactiver_shadow_bonnie()
		else:
			pass

	
	move_timer -= delta
	
	if move_timer <= 0:
		reset_timer(current_ai_level)
		attempt_logic(current_ai_level)	


func versus_move():
	print("Ordre reçu pour : ", nom)
	
	# CAS 1 : FOXY (Phases)
	if nom == "Foxy":
		if not "foxy_rage" in camera_system_ref: camera_system_ref.foxy_rage = 0
		camera_system_ref.foxy_rage += 1
		if camera_system_ref.foxy_rage >= camera_system_ref.foxy_max_rage:
			lancer_attaque_foxy() # Votre fonction existante
		else:
			camera_system_ref.mettre_a_jour_image()
		return

	# CAS 2 : GOLDEN FREDDY (Spawn Office)
	if nom == "Golden-Freddy":
		office_ref.tenter_spawn_golden_freddy() # On force le spawn
		return

	# CAS 3 : SHADOW BONNIE (Besoin d'une caméra cible)
	# (Géré par un autre appel spécifique, voir plus bas)

	# CAS 4 : MOUVEMENT STANDARD (Bonnie, Chica, Freddy, Puppet...)
	
	# Est-ce qu'on est à la fin du chemin (Porte / Vent) ?
	if current_path_index == path_list.size() - 1:
		tenter_attaque_versus()
	else:
		# On avance
		avancer_sur_chemin()


func tenter_attaque_versus():
	if office_ref.est_coupure_courant: return
	
	var attaque_reussie = false
	
	# VERIFICATION DES DEFENSES
	if nom == "Freddy":
		# Freddy passe si la porte Droite est ouverte (Logique simplifiée pour VS)
		if porte_cible and not porte_cible.est_fermee: attaque_reussie = true
		
	elif nom == "Mangle" or nom == "Springtrap":
		# Eux passent par la vent
		if not camera_system_ref.vent_scelle: attaque_reussie = true
		
	elif porte_cible:
		# Bonnie / Chica
		if not porte_cible.est_fermee: attaque_reussie = true

	# RESULTAT
	if attaque_reussie:
		print("PURPLE GUY A GAGNÉ AVEC ", nom)
		office_ref.trigger_jumpscare(nom)
	else:
		print("ATTAQUE BLOQUÉE ! ", nom, " repart au début.")
		# Son de "Bang" sur la porte
		if office_ref.has_node("Audio_Door_Bang"): office_ref.get_node("Audio_Door_Bang").play()
		
		# Reset position
		var index_retour = 0
		if nom == "Bonnie": index_retour = path_list.find("Cam02")
		if index_retour == -1: index_retour = 0
		changer_position(index_retour)





func verifier_porte_ouverte():
	if office_ref.est_coupure_courant: return
	if porte_cible and not porte_cible.est_fermee:
		if randf() < 0.05: 
			print("CHICA EST RENTRÉE !")
			office_ref.trigger_jumpscare("Chica")

func attempt_logic(ai_level):
	if office_ref.est_coupure_courant: return
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
		
		# ====================================================================
		# AJOUT : RÈGLE DE PRIORITÉ (ATTENDRE BONNIE ET CHICA)
		# ====================================================================
		if current_path_index == 0: # Si Freddy est toujours sur la Scène (Cam01)
			
			# 1. Est-ce que le challenge "Bear Attack" est actif ?
			var est_bear_attack = false
			if NetworkGlobal.players.size() > 0:
				# En Multi, on regarde la variable du réseau
				if NetworkGlobal.active_challenge_multi_id == "bear_attack": est_bear_attack = true
			else:
				# En Solo, on regarde GameData
				if GameData.active_challenge_id == "bear_attack": est_bear_attack = true
			
			# 2. Si ce N'EST PAS Bear Attack, on applique la restriction
			if not est_bear_attack:
				var salle_scene = path_list[0] # Normalement "Cam01"
				if camera_system_ref.etat_salles.has(salle_scene):
					var occupants = camera_system_ref.etat_salles[salle_scene]
					
					# Si Bonnie OU Chica est encore sur la scène, Freddy attend.
					if occupants.has("Bonnie") or occupants.has("Chica"):
						# On annule tout mouvement pour ce tour
						return 
		# ====================================================================

		# --- SUITE DE LA LOGIQUE FREDDY (INCHANGÉE) ---
		
		if current_path_index == path_list.size() - 1:
			
			# CONDITION DE DÉFENSE : Ventilateur éteint
			if not office_ref.ventilateur_actif:
				print("Ventilateur éteint : Freddy repart forcement.")
				var index_retour = 1 # Caméra de repli (Dining Area souvent)
				changer_position(index_retour)
				office_ref.jouer_rire_freddy()
				return
				
		# 1. On lance le dé (RNG)
		var roll = randi_range(1, 20)
		
		# Si le jet échoue, Freddy ne fait rien
		if roll > ai_level:
			return

		# 2. EST-IL À LA DERNIÈRE CAMÉRA ? (La Ventilation)
		if current_path_index == path_list.size() - 1:
			
			if office_ref.ventilateur_actif:
				# A. Le ventilateur fait du bruit -> Freddy entend et ATTAQUE
				print("Freddy attaque car le ventilateur est allumé !")
				tenter_attaque()
				
			else:
				# B. Le ventilateur est coupé -> Freddy repart
				print("Ventilateur éteint : Freddy repart.")
				var index_retour = 1 
				changer_position(index_retour)
				office_ref.jouer_rire_freddy() 
				
		else:
			# 3. MOUVEMENT NORMAL (Il avance vers l'office)
			avancer_sur_chemin()
			office_ref.jouer_rire_freddy()
			
		return # Fin de la logique Freddy pour ce tour

	# --- LOGIQUE CHICA ---
	if nom == "Chica":
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			avancer_sur_chemin()
		return
		
	if nom == "Shadow-Bonnie":
		# Si il est déjà là, on ne fait rien (on attend que le joueur gère la situation)
		if sb_active:
			return

		# Jet de dés classique pour voir s'il décide d'attaquer
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			faire_apparaitre_shadow_bonnie()
		
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
	if office_ref.est_coupure_courant: return
	# 1. EST-ELLE À LA POSITION D'ATTAQUE ?
	if current_path_index == path_list.size() - 1:
		
		# CONDITION DE DÉFENSE : Vent scellé
		if camera_system_ref.vent_scelle:
			print("BLOCKED! Mangle heurte la ventilation scellée (Départ Forcé).")
			tenter_jouer_son_vent()
			changer_position(0) # Retour départ
			return # On s'arrête là, pas besoin de dés
			
		# Si vent non scellé, on continue (risque de jumpscare)
	
	# 2. LOGIQUE NORMALE (Déplacement ou Attaque si vent ouvert)
	var roll = randi_range(1, 20)
	if roll > ai_level: return # Echec du dé

	# Mouvement ou Attaque standard
	if current_path_index == path_list.size() - 1:
		# Si on arrive ici, c'est que le vent n'était PAS scellé
		print("MANGLE ENTRE DANS LE BUREAU !")
		office_ref.trigger_jumpscare("Mangle")
	else:
		avancer_sur_chemin()

func faire_apparaitre_shadow_bonnie():
	if path_list.size() == 0: return
	
	# 1. Choisir une salle au hasard
	sb_room = path_list.pick_random()
	
	# 2. Activer les stats (avec les valeurs corrigées précédemment)
	sb_active = true
	sb_kill_timer = 8.0 
	sb_stare_timer = 0.0
	
	# 3. L'ajouter visuellement à la caméra
	if camera_system_ref.etat_salles.has(sb_room):
		
		# --- CORRECTION ICI : ON VÉRIFIE AVANT D'AJOUTER ---
		# On n'ajoute le nom QUE s'il n'est pas déjà dans la liste
		if not camera_system_ref.etat_salles[sb_room].has(nom):
			camera_system_ref.etat_salles[sb_room].append(nom)
			
		camera_system_ref.mettre_a_jour_image()
		
		if camera_system_ref.has_method("afficher_danger"):
			camera_system_ref.afficher_danger(sb_room, true)
		
	print("SHADOW BONNIE EST APPARU EN ", sb_room)

func desactiver_shadow_bonnie():
	print("SHADOW BONNIE REPOUSSÉ !")
	
	if camera_system_ref.has_method("afficher_danger"):
		camera_system_ref.afficher_danger(sb_room, false)
	
	# 1. Retirer visuellement
	if camera_system_ref.etat_salles.has(sb_room):
		camera_system_ref.etat_salles[sb_room].erase(nom)
		camera_system_ref.mettre_a_jour_image()
	
	# 2. Reset des variables
	sb_active = false
	sb_room = ""
	sb_kill_timer = 8.0
	sb_stare_timer = 0.0
	
	# 3. Reset du timer principal pour lui donner un temps de pause avant de pouvoir revenir
	reset_timer(0)

	
func changer_position(nouvel_index):
	var ancienne_salle = path_list[current_path_index]
	
	# Mise à jour locale
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)
	
	current_path_index = nouvel_index
	var nouvelle_salle = path_list[current_path_index]
	
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
		
	# --- AJOUT CRUCIAL DE LA SYNCHRO ICI ---
	var office = get_parent()
	if office.has_method("sync_move_client"):
		office.sync_move_client(ancienne_salle, nouvelle_salle)
	# ---------------------------------------
	
	print(nom, " a été déplacé vers ", nouvelle_salle)
	
	# Gestion du brouillage
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
	
	# Mise à jour locale (Serveur)
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)

	current_path_index += 1
	var nouvelle_salle = path_list[current_path_index]
	
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	# --- SYNCHRONISATION (CORRIGÉE) ---
	var office = get_parent() 
	if office.has_method("sync_move_client"):
		# On envoie les deux salles pour nettoyer l'ancienne et afficher la nouvelle
		office.sync_move_client(ancienne_salle, nouvelle_salle)
	# ----------------------------------
	
	if "Cam09" in ancienne_salle or "Cam13" in nouvelle_salle:
		tenter_jouer_son_vent()
	
	if nom == "Freddy": 
		jouer_rire_freddy()
	
	print(nom, " a bougé vers ", nouvelle_salle)
	camera_system_ref.mettre_a_jour_image()

func jouer_rire_freddy():
	if office_ref.has_node("Audio_Freddy_Laugh"):
		office_ref.get_node("Audio_Freddy_Laugh").play()

func tenter_attaque():
	if office_ref.est_coupure_courant: return
	
	# Freddy tue s'il arrive à la fin de son chemin (Office_Vent_Pos)
	if nom == "Freddy":
		office_ref.trigger_jumpscare("Freddy")
		return
	
	# --- LOGIQUE BONNIE / CHICA ---
	if porte_cible and porte_cible.est_fermee:
		print("BLOCKED! ", nom, " repart.")
		
		# On détermine l'index de repli (où le robot doit repartir)
		var index_repli = 0 # Par défaut : Retour au début (Cam 01)
		
		if nom == "Bonnie": 
			# Bonnie repart souvent en Cam 02 (Dining Area) au lieu de tout recommencer
			var idx = path_list.find("Cam02") 
			if idx != -1:
				index_repli = idx
			
		# --- CORRECTION MAJEURE ICI ---
		# Au lieu de modifier les listes à la main, on appelle la fonction
		# qui gère déjà le déplacement ET le réseau (RPC).
		changer_position(index_repli)
		
	else:
		# La porte est ouverte -> Jumpscare
		office_ref.trigger_jumpscare(nom)

func lancer_attaque_foxy():
	print("FOXY COURT !")
	camera_system_ref.foxy_attacking = true
	camera_system_ref.mettre_a_jour_image()
	await office_ref.get_tree().create_timer(randf_range(6.0, 10.0)).timeout
	knock_door_foxy()

func knock_door_foxy():
	if office_ref.game_over or office_ref.est_coupure_courant: return
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
	if office_ref.est_coupure_courant: return
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
