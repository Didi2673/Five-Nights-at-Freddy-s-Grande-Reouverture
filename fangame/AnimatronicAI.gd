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
var base_interval : float = 5.0 # Intervalle de base (ex: 5 secondes)

func setup(data, _camera_system_ref, _porte_cible, _office_ref, _real_index):
	json_index = _real_index
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
			
func tenter_jouer_son_vent():
	# On vérifie si l'office a le lecteur audio
	if office_ref.has_node("Audio_Vent_Move"):
		var audio = office_ref.get_node("Audio_Vent_Move")
		
		# On ajoute une petite variation de pitch pour le réalisme
		audio.pitch_scale = randf_range(0.9, 1.1)
		audio.play()

func reset_timer(ai_level : int):
	
	move_timer = base_interval
	
# --- NOUVELLE FONCTION : RECEPTION AUDIO ---
func recevoir_audio(camera_source : String):
	# Seule Chica écoute
	if nom != "Chica": return
	
	print("--- AUDIO TEST CHICA ---")
	print("Position actuelle de Chica : ", path_list[current_path_index], " (Index ", current_path_index, ")")
	print("Son joué en : ", camera_source)
	
	# 1. EST-CE TROP TARD ?
	if current_path_index == path_list.size() - 1:
		print("ECHEC : Chica est déjà à la porte (trop tard).")
		return
	
	# 2. EST-CE QUE LA CAMERA EST SUR SON CHEMIN ?
	var index_son = path_list.find(camera_source)
	
	if index_son == -1: 
		print("ECHEC : La caméra ", camera_source, " n'est pas dans le chemin de Chica.")
		return
	
	print("Index de la source audio : ", index_son)
	
	# 3. REGLE DE LA SCENE (Interdit de revenir en 0)
	if index_son == 0:
		print("ECHEC : Le son est sur la Scène (Cam01), on ne peut pas l'attirer ici.")
		return

	# 4. VERIFICATION STRICTE (On veut Index Actuel - 1)
	if index_son == current_path_index - 1:
		print("SUCCÈS ! Chica recule vers ", camera_source)
		reculer_sur_chemin(index_son)
		
		# --- LE FIX EST ICI ---
		# On lui remet son timer à fond (ex: 5 secondes) pour qu'elle ne revienne pas tout de suite !
		move_timer = base_interval 
		print("Chica est distraite par le son, timer remis à : ", move_timer)
		# ----------------------
	else:
		print("ECHEC DE DISTANCE.")
		print("Il faut jouer le son à l'index : ", current_path_index - 1)
		print("Vous avez joué le son à l'index : ", index_son)
		
func reculer_sur_chemin(index_cible):
	# Nettoyage ancienne position
	var ancienne_salle = path_list[current_path_index]
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)
	
	# Nouvelle position (en arrière)
	current_path_index = index_cible
	var nouvelle_salle = path_list[current_path_index]
	
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	camera_system_ref.mettre_a_jour_image()

func process_ai(delta, current_ai_level):
	
	if Engine.get_frames_drawn() % 60 == 0:
		print(nom, " est au niveau IA : ", current_ai_level)
		
	if office_ref.game_over: return
	
	# --- LOGIQUE CHICA (CAMPING) ---
	if nom == "Chica":
		# Si Chica est à la porte (dernier point du chemin), elle ne bouge plus !
		# Le timer ne tourne même plus, elle attend juste que tu ouvres la porte pour te tuer.
		if current_path_index == path_list.size() - 1:
			verifier_porte_ouverte() # Vérifie en continu si tu ouvres
			return

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
		
func verifier_porte_ouverte():
	# Si Chica est plantée devant la porte et que la porte est OUVERTE -> Mort
	if porte_cible and not porte_cible.est_fermee:
		# On ajoute un petit délai ou une probabilité pour pas mourir à la milliseconde
		if randf() < 0.05: # Petite chance chaque frame (très dangereux)
			print("CHICA EST RENTRÉE !")
			office_ref.trigger_jumpscare("Chica")
	
	# Ici on ne gère PAS le fait qu'elle parte. Elle reste là pour toujours.
	# La seule défense est de fermer la porte pour bloquer le Jumpscare,
	# mais ça draine la batterie.

func attempt_logic(ai_level):
	if nom == "Foxy":
		gerer_foxy(ai_level)
		return
		
	# --- LOGIQUE MANGLE ---
	if nom == "Mangle":
		attempt_mangle_move(ai_level)
		return

	# --- LOGIQUE CHICA (AVANCE SEULEMENT) ---
	if nom == "Chica":
		# Elle avance vers la porte, mais ne recule jamais seule.
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			avancer_sur_chemin()
		return
		
	if nom == "Springtrap":
		process_springtrap_logic(ai_level)
		return

	# --- LOGIQUE STANDARD (BONNIE / FREDDY) ---
	if current_path_index == path_list.size() - 1:
		tenter_attaque()
	else:
		var roll = randi_range(1, 20)
		if nom == "Freddy" and current_path_index == 0:
			var occupants_scene = camera_system_ref.etat_salles["Cam01"]
			if occupants_scene.has("Bonnie") or occupants_scene.has("Chica"): return
		
		if roll <= ai_level:
			avancer_sur_chemin()
			
func attempt_mangle_move(ai_level):
	# 1. Jet de dés
	var roll = randi_range(1, 20)
	if roll > ai_level: return # Elle ne fait rien cette fois-ci

	# 2. Si Mangle est à la fin de son chemin (Cam13)
	if current_path_index == path_list.size() - 1:
		
		# VERIFICATION : La vent est-elle scellée ?
		if camera_system_ref.vent_scelle:
			print("BLOCKED! Mangle heurte la ventilation scellée.")
			# BRUIT DE METAL (Optionnel : jouer un son ici)
			tenter_jouer_son_vent()
			# RETOUR AU DÉPART (Reset)
			changer_position(0) # Elle repart au début de son chemin
			
		else:
			# VENT OUVERTE -> MORT
			print("MANGLE ENTRE DANS LE BUREAU !")
			office_ref.trigger_jumpscare("Mangle")
			
	else:
		# Sinon, elle avance normalement vers la salle suivante
		avancer_sur_chemin()
		
func changer_position(nouvel_index):
	# 1. On mémorise l'ancienne salle AVANT de changer
	var ancienne_salle = path_list[current_path_index]
	
	# --- Nettoyage ancienne position ---
	if camera_system_ref.etat_salles.has(ancienne_salle):
		camera_system_ref.etat_salles[ancienne_salle].erase(nom)

	# 2. On change l'index
	current_path_index = nouvel_index
	var nouvelle_salle = path_list[current_path_index]
	
	# --- Ajout nouvelle position ---
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	print(nom, " a été déplacé vers ", nouvelle_salle)
	
	# 3. --- LOGIQUE DE BROUILLAGE ---
	# On regarde quelle caméra le joueur regarde en ce moment
	var cam_joueur = camera_system_ref.camera_actuelle
	
	# Condition 1 : Le joueur regarde la salle que je viens de QUITTER
	# Condition 2 : Le joueur regarde la salle où je viens d'ARRIVER
	if camera_system_ref.est_ouvert and (cam_joueur == ancienne_salle or cam_joueur == nouvelle_salle):
		# On déclenche l'effet sur le moniteur
		if camera_system_ref.has_method("declencher_brouillage"):
			camera_system_ref.declencher_brouillage()
	
	# 4. On met à jour l'image (si pas de brouillage, ou après)
	camera_system_ref.mettre_a_jour_image()
	
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
	
	# --- NOUVEAU : DETECTION DE VENTILATION ---
	# Si l'ancienne salle OU la nouvelle salle contient "Vent" dans son nom
	# (Assure-toi que tes caméras de vent s'appellent "Vent01", "Vent02", etc.)
	if "Cam09" in ancienne_salle or "Cam13" in nouvelle_salle:
		tenter_jouer_son_vent()
	# ------------------------------------------
	
	if nom == "Freddy":
		jouer_rire_freddy()
	
	# 3. ON S'AJOUTE DANS LA NOUVELLE SALLE (CORRECTION VISUELLE ICI !)
	# Avant, tu avais un "return" ici qui empêchait l'ajout. Maintenant on l'ajoute.
	if camera_system_ref.etat_salles.has(nouvelle_salle):
		camera_system_ref.etat_salles[nouvelle_salle].append(nom)
	
	print(nom, " a bougé vers ", nouvelle_salle)
	
	# 4. MISE A JOUR DES CAMERAS
	camera_system_ref.mettre_a_jour_image()

func jouer_rire_freddy():
	# On vérifie que le noeud audio existe bien dans la scène Office
	if office_ref.has_node("Audio_Freddy_Laugh"):
		var audio = office_ref.get_node("Audio_Freddy_Laugh")
		
		
		audio.play()

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
		if nom == "Bonnie": current_path_index = path_list.find("Cam02") # Exemple de repli
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
		office_ref.label_batterie.text = "Power : " + str(int(office_ref.batterie)) + "%"
		camera_system_ref.foxy_rage = 0
		camera_system_ref.foxy_attacking = false
		camera_system_ref.mettre_a_jour_image()
	else:
		office_ref.trigger_jumpscare("Foxy")
		

# --- CERVEAU DE SPRINGTRAP (CORRIGÉ) ---
func process_springtrap_logic(ai_level):
	var roll = randi_range(1, 20)
	if roll > ai_level: return # Il ne bouge pas
	
	var salle_actuelle = path_list[current_path_index]
	
	match salle_actuelle:
		"Cam02":
			# Départ : Choix Gauche (07) ou Droite (10)
			if randf() < 0.5: deplacer_springtrap("Cam07")
			else: deplacer_springtrap("Cam10")
				
		"Cam07":
			# Coté Gauche
			if randf() < 0.5:
				# CHANGE ICI : On le déplace juste dans la vent. 
				# Il ne tuera qu'au PROCHAIN mouvement (après le timer).
				print("Springtrap entre dans la ventilation (Cam13)...")
				deplacer_springtrap("Cam13") 
				# On joue le son de mouvement maintenant pour prévenir
				tenter_jouer_son_vent()
			else:
				deplacer_springtrap("Cam11")
				
		"Cam10":
			# Coté Droit
			if randf() < 0.5:
				print("Springtrap entre dans la ventilation (Cam13)...")
				deplacer_springtrap("Cam13")
				tenter_jouer_son_vent()
			else:
				deplacer_springtrap("Cam12")
		
		"Cam13":
			# --- C'EST ICI QUE LE DÉLAI A LIEU ---
			# Il est déjà dans la ventilation depuis le dernier tour.
			# Le timer vient de finir, donc on résout l'attaque maintenant.
			verifier_attaque_ventilation()
		
		"Cam11":
			attaquer_porte("left")
			
		"Cam12":
			attaquer_porte("right")

# --- NOUVELLE FONCTION DE RÉSOLUTION ---
func verifier_attaque_ventilation():
	print("Springtrap tente de sortir de la ventilation...")
	
	if camera_system_ref.vent_scelle:
		print("BLOCKED! Springtrap heurte la grille.")
		# Son de métal "BANG"
		if office_ref.has_node("Audio_Vent_Bang"):
			office_ref.get_node("Audio_Vent_Bang").play()
		else:
			tenter_jouer_son_vent()
		
		# RETOUR A LA CASE DEPART (Cam02)
		var index_start = path_list.find("Cam02")
		changer_position(index_start)
	else:
		print("SPRINGTRAP SORT DE LA VENT -> MORT !")
		office_ref.trigger_jumpscare("Springtrap")

# --- FONCTIONS UTILITAIRES SPRINGTRAP ---

func deplacer_springtrap(nom_cible : String):
	# Trouver l'index de la salle cible dans la liste
	var nouvel_index = path_list.find(nom_cible)
	if nouvel_index != -1:
		changer_position(nouvel_index) # Utilise ta fonction existante
		
		# Petit son de rire ou de pas effrayant
		if office_ref.has_method("jouer_audio_leurre"): 
			# On peut réutiliser un son existant ou en jouer un nouveau
			pass

func check_ventilation_attack():
	# Il entre dans la ventilation (Cam13)
	# D'abord on le déplace visuellement pour que le joueur le voie dans la vent
	var index_vent = path_list.find("Cam13")
	changer_position(index_vent)
	
	print("SPRINGTRAP EST DANS LA VENTILATION !")
	
	# On attend un tick de timer (prochain mouvement) pour l'attaque
	# Ou on résout immédiatement selon tes préférences. 
	# Ici, on résout immédiatement :
	
	if camera_system_ref.vent_scelle:
		print("BLOCKED! Springtrap heurte la grille.")
		# Son de métal "BANG"
		tenter_jouer_son_vent() 
		
		# RETOUR A LA CASE DEPART (Cam02)
		var index_start = path_list.find("Cam02")
		changer_position(index_start)
	else:
		print("SPRINGTRAP SORT DE LA VENT !")
		office_ref.trigger_jumpscare("Springtrap")

func attaquer_porte(cote : String):
	print("SPRINGTRAP TENTE D'ENTRER PAR : ", cote)
	
	var porte_bloquee = false
	
	# On vérifie les portes via l'office directement
	if cote == "left":
		if office_ref.porte_gauche.est_fermee: porte_bloquee = true
	elif cote == "right":
		if office_ref.porte_droite.est_fermee: porte_bloquee = true
		
	if porte_bloquee:
		print("BLOCKED! Springtrap repart.")
		# Bruit de coup sur la porte ?
		
		# RETOUR A LA CASE DEPART (Cam02)
		var index_start = path_list.find("Cam02")
		changer_position(index_start)
	else:
		# Jumpscare immédiat car invisible à la lumière
		office_ref.trigger_jumpscare("Springtrap")
