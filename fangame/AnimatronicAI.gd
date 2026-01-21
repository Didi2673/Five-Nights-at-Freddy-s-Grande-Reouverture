class_name AnimatronicAI extends Node

# --- DONNÉES ---
var nom : String
var data_json : Dictionary
var path_list : Array = []
var current_path_index : int = 0

# --- RÉFÉRENCES ---
var camera_system_ref : Node 
var porte_cible : Node3D 
var office_ref : Node3D 

# --- TIMER ---
var move_timer : float = 0.0
var move_interval : float = 5.0

func setup(data, _camera_system_ref, _porte_cible, _office_ref):
	data_json = data
	nom = data["name"]
	path_list = data["path"]
	move_interval = data["movement_interval"]
	
	move_timer = move_interval
	
	camera_system_ref = _camera_system_ref
	porte_cible = _porte_cible
	office_ref = _office_ref
	
	# INITIALISATION SÉCURISÉE
	# On s'ajoute à la première salle si on n'y est pas déjà
	var salle_depart = path_list[0]
	if camera_system_ref.etat_salles.has(salle_depart):
		if not camera_system_ref.etat_salles[salle_depart].has(nom):
			camera_system_ref.etat_salles[salle_depart].append(nom)
			camera_system_ref.mettre_a_jour_image()

func process_ai(delta, current_ai_level):
	if nom == "Freddy":
		# 1. Où est Freddy ?
		var salle_actuelle = path_list[current_path_index]
		
		# 2. Le joueur regarde-t-il cette salle ?
		# On vérifie : Moniteur ouvert + Bonne Caméra
		if camera_system_ref.est_ouvert and camera_system_ref.camera_actuelle == salle_actuelle:
			# OUI -> On le bloque !
			# On remet son timer à fond (il ne peut pas bouger tant qu'on le regarde)
			move_timer = move_interval
			# print("Freddy est observé, il ne bouge pas...")
			return # On arrête la fonction ici, le timer ne descendra pas
	move_timer -= delta
	if move_timer <= 0:
		move_timer = move_interval
		attempt_movement(current_ai_level)

func attempt_movement(ai_level):
	if office_ref.game_over: return

	# --- SPECIAL FOXY ---
	if nom == "Foxy":
		
		# SÉCURITÉ : Si Foxy court déjà, on ne fait RIEN.
		if camera_system_ref.foxy_attacking:
			return 
		
		# 1. On tente le jet de dé
		var roll = randi_range(1, 20)
		if roll <= ai_level:
			# REUSSITE : La rage augmente !
			camera_system_ref.foxy_rage += 1
			print("Foxy s'énerve... Rage : ", camera_system_ref.foxy_rage)
			
			# EST-IL PRÊT A ATTAQUER ?
			if camera_system_ref.foxy_rage >= camera_system_ref.foxy_max_rage:
				lancer_attaque_foxy()
			else:
				# Mise à jour visuelle
				camera_system_ref.mettre_a_jour_image()
		return
	# ### NOUVEAU : LOGIQUE SPÉCIALE FREDDY ###
	# Si je suis Freddy ET que je suis encore au début (Scène)
	if nom == "Freddy" and current_path_index == 0:
		# Je vérifie qui est avec moi sur la Cam01
		var occupants_scene = camera_system_ref.etat_salles["Cam01"]
		
		# Si Bonnie OU Chica sont là, je refuse de bouger
		if occupants_scene.has("Bonnie") or occupants_scene.has("Chica"):
			# print("Freddy attend que les autres partent...")
			return 
	# #########################################

	var roll = randi_range(1, 20)
	if roll <= ai_level:
		avancer_sur_chemin()

func lancer_attaque_foxy():
	print("FOXY COURT VERS LA PORTE !")
	camera_system_ref.foxy_attacking = true
	camera_system_ref.mettre_a_jour_image() # Affiche le rideau vide
	
	# Foxy met un certain temps à arriver (ex: 5 à 10 secondes de course)
	# On peut simuler ça avec un Timer ou await
	await office_ref.get_tree().create_timer(randf_range(6.0, 10.0)).timeout
	
	knock_door_foxy()

func knock_door_foxy():
	if office_ref.game_over: return
	
	# VERIFICATION DE LA PORTE (Gauche)
	if porte_cible and porte_cible.est_fermee:
		# --- ECHEC (PORTE FERMEE) ---
		print("FOXY BANG BANG ! (Batterie perdue)")
		
		# 1. Perte de batterie
		office_ref.batterie -= 5.0
		if office_ref.batterie < 0: office_ref.batterie = 0
		office_ref.label_batterie.text = "Power: " + str(int(office_ref.batterie)) + "%"
		
		# 2. Reset Foxy
		camera_system_ref.foxy_rage = 0
		camera_system_ref.foxy_attacking = false
		camera_system_ref.mettre_a_jour_image() # Retourne dans le rideau
		
		# 3. Son de frappe (Optionnel)
		# porte_cible.jouer_son_bang()
		
	else:
		# --- REUSSITE (JUMPSCARE) ---
		print("JUMPSCARE FOXY !")
		office_ref.trigger_jumpscare("Foxy")

func avancer_sur_chemin():
	# 1. NETTOYAGE
	for nom_camera in camera_system_ref.etat_salles:
		while camera_system_ref.etat_salles[nom_camera].has(nom):
			camera_system_ref.etat_salles[nom_camera].erase(nom)

	# 2. DÉPLACEMENT
	if current_path_index == path_list.size() - 1:
		tenter_attaque()
		camera_system_ref.mettre_a_jour_image()
		return

	current_path_index += 1
	var nouvelle_salle = path_list[current_path_index]
	
	# 3. AFFICHAGE
	if current_path_index == path_list.size() - 1:
		print(nom, " est caché dans l'angle mort (", nouvelle_salle, ")")
	else:
		if camera_system_ref.etat_salles.has(nouvelle_salle):
			camera_system_ref.etat_salles[nouvelle_salle].append(nom)
			print(nom, " a bougé vers ", nouvelle_salle)
	
	camera_system_ref.mettre_a_jour_image()

func tenter_attaque():
	print(nom, " TENTE D'ENTRER !")
	
	# --- CAS SPÉCIAL FREDDY (VENTILATION) ---
	if nom == "Freddy":
		print("FREDDY SORT DE LA VENTILATION !")
		# Pas de vérification de porte. C'est une mort directe.
		office_ref.trigger_jumpscare("Freddy")
		return
	
	if porte_cible and porte_cible.est_fermee:
		# --- ÉCHEC (BLOCKED) ---
		print("BLOCKED! ", nom, " repart.")
		
		# ### NOUVEAU : LOGIQUE DE RETOUR (Cam 02) ###
		
		var salle_retour = ""
		var index_retour = 0
		
		# On cherche "Cam02" dans le chemin de cet animatronique
		var index_trouve = path_list.find("Cam02")
		
		if index_trouve != -1:
			# Si Cam02 existe dans son chemin, on y va
			index_retour = index_trouve
			salle_retour = "Cam02"
		else:
			# Sinon (sécurité), on retourne au début (Cam01)
			index_retour = 0
			salle_retour = path_list[0]
		
		# On applique le retour
		current_path_index = index_retour
		
		# On s'affiche visuellement dans la salle de retour
		if camera_system_ref.etat_salles.has(salle_retour):
			camera_system_ref.etat_salles[salle_retour].append(nom)
		
		camera_system_ref.mettre_a_jour_image()
		# ###########################################
		
	else:
		# --- RÉUSSITE (JUMPSCARE) ---
		print("JUMPSCARE !!!")
		office_ref.trigger_jumpscare(nom)
