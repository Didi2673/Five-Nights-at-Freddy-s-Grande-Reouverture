extends Node3D

# --- CONFIGURATION ---
@export var cameras : Array[Camera3D]
@export var joueur_node : Node3D 

# NOUVEAU : On a besoin de savoir quel est le CanvasLayer de la tablette pour le cacher/montrer
@export var ui_moniteur : CanvasLayer 

# --- VARIABLES INTERNES ---
var camera_bureau : Camera3D 
var est_ouvert : bool = false # Pour savoir si la tablette est levée
var index_derniere_camera : int = 0 # Pour se souvenir de la dernière caméra regardée

func _ready():
	# Récupération de la caméra du joueur
	if joueur_node:
		camera_bureau = joueur_node.get_node("Camera3D")
	
	# Au démarrage, on s'assure que tout est fermé
	fermer_moniteur()

# NOUVEAU : Cette fonction écoute le clavier en permanence
func _input(event):
	# Si on appuie sur ESPACE (ui_accept est l'action par défaut pour Espace/Entrée)
	if event.is_action_pressed("ui_accept"):
		toggle_moniteur()

# Cette fonction bascule entre ouvert et fermé
func toggle_moniteur():
	if est_ouvert:
		fermer_moniteur()
	else:
		ouvrir_moniteur()

func ouvrir_moniteur():
	est_ouvert = true
	
	# 1. On affiche l'interface 2D (la tablette)
	if ui_moniteur:
		ui_moniteur.visible = true
	
	# 2. On active la dernière caméra utilisée
	activer_camera(index_derniere_camera)

func fermer_moniteur():
	est_ouvert = false
	
	# 1. On cache l'interface 2D
	if ui_moniteur:
		ui_moniteur.visible = false
	
	# 2. On désactive toutes les caméras CCTV
	for cam in cameras:
		cam.current = false
	
	# 3. On remet la vue du joueur
	if camera_bureau:
		camera_bureau.current = true

func activer_camera(index : int):
	# On mémorise cette caméra pour la prochaine fois qu'on ouvre le moniteur
	index_derniere_camera = index
	
	# Si le moniteur est fermé, on ne change pas la vue 3D (pour éviter les bugs)
	if not est_ouvert:
		return

	# Logique standard de changement de caméra
	if camera_bureau: camera_bureau.current = false
	
	for i in range(cameras.size()):
		if i == index:
			cameras[i].current = true
		else:
			cameras[i].current = false
