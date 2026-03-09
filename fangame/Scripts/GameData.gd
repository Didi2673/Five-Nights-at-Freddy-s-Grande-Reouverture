extends Node

# On stocke les données chargées ici
var nights_data = []
var animatronics_data = []

var no_cameras_mode_active : bool = false
var completed_no_cameras_nights : Array = []
# --- VARIABLES CHALLENGES ---
var active_challenge_id : String = "custom" 
var completed_challenges : Array = [] # Liste des ID réussis (ex: ["bear_attack", "ladies_night"])

var challenges_list = [
	{
		"id": "custom",
		"name": "Custom Night",
		"description": "Configurez votre nuit.",
		"levels": {} # Vide car c'est manuel
	},
	{
		"id": "bear_attack",
		"name": "Bear Attack",
		"description": "Freddy et Golden Freddy.",
		"levels": {"Freddy": 20, "Golden-Freddy": 20, "Mangle": 0, "Puppet": 0, "Bonnie": 0, "Chica": 0, "Foxy": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "ladies_night",
		"name": "Ladies Night",
		"description": "Chica, Puppet et Mangle sont actives.",
		"levels": {"Chica": 20, "Mangle": 20, "Puppet": 20, "Freddy": 0, "Bonnie": 0, "Foxy": 0, "Golden-Freddy": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "foxy_foxy",
		"name": "Foxy Foxy",
		"description": "Foxy et Mangle",
		"levels": {"Chica": 0, "Mangle": 20, "Puppet": 0, "Freddy": 0, "Bonnie": 0, "Foxy": 20, "Golden-Freddy": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "mad_bonnie",
		"name": "Mad Bonnie",
		"description": "Bonnie",
		"levels": {"Chica": 0, "Mangle": 0, "Puppet": 0, "Freddy": 0, "Bonnie": 20, "Foxy": 0, "Golden-Freddy": 0, "Shadow-Bonnie": 20}
	},
	{
		"id": "vent_lovers",
		"name": "Vent Lovers",
		"description": "vent",
		"levels": {"Chica": 0, "Mangle": 20, "Puppet": 0, "Freddy": 20, "Bonnie": 0, "Foxy": 0, "Golden-Freddy": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "not_real",
		"name": "Not Real",
		"description": "not",
		"levels": {"Chica": 0, "Mangle": 0, "Puppet": 0, "Freddy": 0, "Bonnie": 0, "Foxy": 0, "Golden-Freddy": 20, "Shadow-Bonnie": 20}
	},
	{
		"id": "on_the_stage",
		"name": "On the stage",
		"description": "Freddou, Bonnie et Chick!!",
		"levels": {"Chica": 20, "Mangle": 0, "Puppet": 0, "Freddy": 20, "Bonnie": 20, "Foxy": 0, "Golden-Freddy": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "misfits",
		"name": "Night of Misfits",
		"description": "les autres mdr",
		"levels": {"Chica": 0, "Mangle": 20, "Puppet": 20, "Freddy": 0, "Bonnie": 0, "Foxy": 0, "Golden-Freddy": 20, "Shadow-Bonnie": 20}
	},
	{
		"id": "5_5_5_5",
		"name": "4/5 Mode",
		"description": "4/5",
		"levels": {"Freddy": 5, "Bonnie": 5, "Golden-Freddy": 0, "Puppet": 0, "Chica": 5, "Foxy": 5, "Mangle": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "10_10_10_10",
		"name": "4/10 Mode",
		"description": "4/10",
		"levels": {"Freddy": 10, "Bonnie": 10, "Golden-Freddy": 0, "Puppet": 0, "Chica": 10, "Foxy": 10, "Mangle": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "20_20_20_20",
		"name": "4/20 Mode",
		"description": "4/20",
		"levels": {"Freddy": 20, "Bonnie": 20, "Golden-Freddy": 0, "Puppet": 0, "Chica": 20, "Foxy": 20, "Mangle": 0, "Shadow-Bonnie": 0}
	},
	{
		"id": "easy_challenge",
		"name": "Easy Challenge",
		"description": "Tout le monde à 1",
		"levels": {"Chica": 1, "Mangle": 1, "Puppet": 1, "Freddy": 1, "Bonnie": 1, "Foxy": 1, "Golden-Freddy": 1, "Shadow-Bonnie": 1}
	},
	{
		"id": "cupcake_challenge",
		"name": "Cupcake Challenge",
		"description": "Tout le monde à 5",
		"levels": {"Chica": 5, "Mangle": 5, "Puppet": 5, "Freddy": 5, "Bonnie": 5, "Foxy": 5, "Golden-Freddy": 5, "Shadow-Bonnie": 5}
	},
	{
		"id": "fazbear_fever",
		"name": "Fazbear Fever",
		"description": "Tout le monde à 10",
		"levels": {"Chica": 10, "Mangle": 10, "Puppet": 10, "Freddy": 10, "Bonnie": 10, "Foxy": 10, "Golden-Freddy": 10, "Shadow-Bonnie": 10}
	},
	{
		"id": "golden_freddy",
		"name": "Golden Freddy",
		"description": "Tout le monde",
		"levels": {"Chica": 20, "Mangle": 20, "Puppet": 20, "Freddy": 20, "Bonnie": 20, "Foxy": 20, "Golden-Freddy": 20, "Shadow-Bonnie": 20}
	}
]

var index_nuit_selectionnee : int = 0
var image_fin_a_afficher : String = ""

var achievements_data = [] 
var unlocked_achievements = [] # Liste des IDs débloqués ["night_1", "honk"]

# --- DONNÉES GLOBALES ---
var save_path = "user://savegame.save"
var nights_json_path = "res://data/nights.json"

# Par défaut, on est à la nuit 1
var unlocked_night : int = 1 
var current_night_played : int = 1 

var custom_night_levels : Dictionary = {} 

var keybinds_path = "user://keybinds.cfg"

# Liste des actions qu'on veut sauvegarder
var actions_a_sauvegarder = [
	"toggle_fan", "toggle_fullscreen", "toggle_silent_fan",
	"input_light_left", "input_light_right", 
	"input_door_left", "input_door_right", "input_seal_vent","toggle_monitor"
]

func save_keybinds():
	var config = ConfigFile.new()
	
	for action in actions_a_sauvegarder:
		var events = InputMap.action_get_events(action)
		if events.size() > 0:
			# On sauvegarde le keycode de la première touche trouvée
			if events[0] is InputEventKey:
				config.set_value("keybinds", action, events[0].keycode)
	
	config.save(keybinds_path)
	print("Touches sauvegardées !")

func reset_all_progress():
	# 1. Remise à zéro des variables en mémoire
	unlocked_night = 1
	current_night_played = 1
	unlocked_achievements.clear()
	completed_challenges.clear()
	completed_no_cameras_nights.clear()
	
	# 2. On écrase le fichier de sauvegarde avec ces données vides
	save_game()
	print(">>> PROGRESSION TOTALEMENT RÉINITIALISÉE <<<")


func load_keybinds():
	var config = ConfigFile.new()
	var err = config.load(keybinds_path)
	
	if err != OK:
		print("Pas de fichier de config trouvé. Création des touches par défaut...")
		
		# --- AJOUT IMPORTANT ICI ---
		# On sauvegarde immédiatement les touches actuelles (qui sont celles par défaut définies dans Godot)
		save_keybinds() 
		return
		
	for action in actions_a_sauvegarder:
		if config.has_section_key("keybinds", action):
			var keycode = config.get_value("keybinds", action)
			
			# Création du nouvel événement
			var new_event = InputEventKey.new()
			new_event.keycode = keycode
			
			# Remplacement dans l'InputMap
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, new_event)
			
	print("Touches chargées !")

func reset_custom_levels():
	custom_night_levels.clear()
	for anim in animatronics_data:
		custom_night_levels[anim["name"]] = 0

func _ready():
	load_nights_data()
	load_data()
	achievements_data = load_json_file("res://data/achievements.json")
	load_game() # Charge la sauvegarde au démarrage
	load_keybinds()

# --- CHARGEMENT DU JSON ---
func load_nights_data():
	if FileAccess.file_exists(nights_json_path):
		var file = FileAccess.open(nights_json_path, FileAccess.READ)
		var json_string = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			nights_data = json.get_data()
			print("Données des nuits chargées : ", nights_data.size(), " nuits trouvées.")
		else:
			print("Erreur JSON dans nights.json à la ligne ", json.get_error_line())
	else:
		print("ERREUR CRITIQUE : Fichier nights.json introuvable !")

func get_night_info(night_number : int):
	var index = night_number - 1
	if index >= 0 and index < nights_data.size():
		return nights_data[index]
	return null

# --- SYSTÈME DE SAUVEGARDE (MODIFIÉ) ---
func save_game():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var data = {
			"unlocked": unlocked_night,
			"achievements": unlocked_achievements,
			"completed_challenges": completed_challenges,
			"completed_no_cams": completed_no_cameras_nights # <--- NOUVEAU
		}
		file.store_string(JSON.stringify(data))
		file.close()

func load_game():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			
			if data.has("unlocked"): unlocked_night = int(data["unlocked"])
			if data.has("achievements"): unlocked_achievements = data["achievements"]
			if data.has("completed_challenges"): completed_challenges = data["completed_challenges"]
			
			# --- CORRECTION ICI ---
			if data.has("completed_no_cams"): 
				completed_no_cameras_nights.clear() # On vide par sécurité
				for numero in data["completed_no_cams"]:
					completed_no_cameras_nights.append(int(numero)) # On force en entier (int)
			# ----------------------
		file.close()

func win_night(n_terminee : int):
	print("Victoire validée pour la nuit : ", n_terminee)
	
	# --- NOUVEAU : Si on gagne en mode No Cameras ---
	if no_cameras_mode_active:
		if not completed_no_cameras_nights.has(n_terminee):
			completed_no_cameras_nights.append(n_terminee)
			if n_terminee == 6:
				unlock_achievement("no_cams")
			save_game()
			print(">>> SUCCÈS : Nuit ", n_terminee, " sans caméras terminée !")
		return # On arrête là pour ne pas débloquer la nuit suivante normale
	# ------------------------------------------------
	
	if n_terminee == unlocked_night:
		if unlocked_night < nights_data.size():
			unlocked_night += 1
			save_game()
			print(">>> SUCCÈS : Nuit ", unlocked_night, " débloquée !")
		else:
			print("Jeu terminé à 100% !")

func unlock_achievement(ach_id : String):
	if unlocked_achievements.has(ach_id): return
	
	print(">>> SUCCÈS DÉBLOQUÉ : ", ach_id)
	unlocked_achievements.append(ach_id)
	save_game()


func load_data():
	nights_data = load_json_file("res://data/nights.json")
	animatronics_data = load_json_file("res://data/animatronics.json")
	print("Données chargées : ", nights_data.size(), " nuits et ", animatronics_data.size(), " animatroniques.")

func load_json_file(path : String):
	if not FileAccess.file_exists(path):
		print("ERREUR: Fichier introuvable ", path)
		return []
	
	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)
	
	if error == OK:
		return json.data
	else:
		print("ERREUR JSON dans ", path, " : ", json.get_error_message())
		return []

func get_ai_level(animatronic_index: int, night_index: int, hour: int) -> int:
	if animatronics_data.size() == 0 or animatronic_index >= animatronics_data.size():
		return 0
		
	var data = animatronics_data[animatronic_index]
	var real_night_index = max(0, night_index - 1)
	
	if real_night_index >= data["ai_levels"].size():
		print("ATTENTION : Pas de données IA pour la nuit ", night_index, ". IA forcée à 0.")
		return 0 
	
	var night_ai = data["ai_levels"][real_night_index]
	
	if hour >= night_ai.size(): 
		return night_ai[night_ai.size() - 1]
	
	return night_ai[hour]
