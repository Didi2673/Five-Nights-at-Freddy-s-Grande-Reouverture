extends Node

# On stocke les données chargées ici
var nights_data = []
var animatronics_data = []

var index_nuit_selectionnee : int = 0

func _ready():
	load_data()

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
	# Sécurités pour éviter les crashs si les fichiers sont mal remplis
	if animatronic_index >= animatronics_data.size(): return 0
	var data = animatronics_data[animatronic_index]
	
	if night_index >= data["ai_levels"].size(): return 0
	var night_ai = data["ai_levels"][night_index]
	
	if hour >= night_ai.size(): return night_ai[night_ai.size() - 1] # Retourne la dernière valeur si on dépasse
	
	return night_ai[hour]
