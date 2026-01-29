extends Node

# On stocke les données chargées ici
var nights_data = []
var animatronics_data = []

var index_nuit_selectionnee : int = 0

var image_fin_a_afficher : String = ""

var achievements_data = [] # Le contenu du JSON
var unlocked_achievements = [] # Liste des IDs débloqués ["night_1", "honk"]

# --- DONNÉES GLOBALES ---
var save_path = "user://savegame.save" # Le chemin du fichier (caché dans l'ordi du joueur)
var nights_json_path = "res://data/nights.json" # Chemin vers ton fichier

# Par défaut, on est à la nuit 1
var unlocked_night : int = 1 
var current_night_played : int = 1 # Celle qu'on va lancer

var custom_night_levels : Dictionary = {} 

func reset_custom_levels():
	# Par défaut, on met tout le monde à 0
	custom_night_levels.clear()
	for anim in animatronics_data:
		custom_night_levels[anim["name"]] = 0

func _ready():
	load_nights_data()
	load_data()
	achievements_data = load_json_file("res://data/achievements.json")
	load_game()
	
	
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

# Fonction utilitaire pour récupérer les infos d'une nuit précise
func get_night_info(night_number : int):
	# Les tableaux commencent à 0, donc Nuit 1 est à l'index 0
	var index = night_number - 1
	if index >= 0 and index < nights_data.size():
		return nights_data[index]
	return null
	
func save_game():
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var data = {
			"unlocked": unlocked_night,
			"achievements": unlocked_achievements # On sauvegarde la liste
		}
		file.store_string(JSON.stringify(data))
		file.close()

func load_game():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.get_data()
			if data.has("unlocked"): unlocked_night = data["unlocked"]
			
			# Chargement des succès
			if data.has("achievements"):
				unlocked_achievements = data["achievements"]

func unlock_achievement(ach_id : String):
	# Si on l'a déjà, on ne fait rien
	if unlocked_achievements.has(ach_id): return
	
	# Sinon, on l'ajoute et on sauvegarde
	print(">>> SUCCÈS DÉBLOQUÉ : ", ach_id)
	unlocked_achievements.append(ach_id)
	save_game()
	
	# Optionnel : Tu pourrais émettre un signal ici pour afficher une popup en jeu
	# signal achievement_unlocked(ach_id)

func win_night(n_terminee : int):
	print("Victoire validée pour la nuit : ", n_terminee)
	
	# Si on vient de finir la nuit qu'on devait débloquer
	if n_terminee == unlocked_night:
		# On vérifie qu'il existe une nuit suivante
		if unlocked_night < nights_data.size():
			unlocked_night += 1
			save_game()
			print(">>> SUCCÈS : Nuit ", unlocked_night, " débloquée !")
		else:
			print("Jeu terminé à 100% !")
	else:
		print("Pas de déblocage (Nuit déjà acquise ou nuit précédente rejouée).")

func load_data():
	nights_data = load_json_file("res://data/nights.json")
	animatronics_data = load_json_file("res://data/animatronics.json")
	print("Données chargées : ", nights_data.size(), " nuits et ", animatronics_data.size(), " animatroniques.")

# Fonction utilitaire pour lire un JSON
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

# Fonction pour récupérer l'IA d'un animatronique pour une nuit et une heure précise
func get_ai_level(animatronic_index: int, night_index: int, hour: int) -> int:
	# Sécurité de base
	if animatronics_data.size() == 0 or animatronic_index >= animatronics_data.size():
		return 0
		
	var data = animatronics_data[animatronic_index]
	
	# Conversion : Nuit 1 (Humain) devient Index 0 (Tableau)
	var real_night_index = max(0, night_index - 1)
	
	# --- CORRECTION ICI ---
	# On vérifie si l'index dépasse la taille du tableau.
	# Si j'ai 5 nuits, les index vont de 0 à 4.
	# Si je demande la nuit 5 (index 4), 4 >= 5 est FAUX, donc ça passe. C'est bon !
	if real_night_index >= data["ai_levels"].size():
		print("ATTENTION : Pas de données IA pour la nuit ", night_index, ". IA forcée à 0.")
		return 0 
	
	var night_ai = data["ai_levels"][real_night_index]
	
	# Sécurité pour l'heure
	if hour >= night_ai.size(): 
		return night_ai[night_ai.size() - 1]
	
	return night_ai[hour]
	
