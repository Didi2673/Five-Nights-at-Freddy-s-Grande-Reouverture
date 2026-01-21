extends Node3D

# --- Paramètres ---
# La vitesse de rotation de la tête
var rotation_speed : float = 2.0

# La zone en pixels sur les bords qui déclenche la rotation
# (ex: 150 pixels sur les côtés)
var scroll_margin : int = 150

# Limites de rotation (Gauche / Droite) en radians
var limit_left : float = deg_to_rad(60.0) 
var limit_right : float = deg_to_rad(-60.0)

func _ready():
	# IMPORTANT : On garde la souris visible mais confinée dans la fenêtre du jeu
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func _process(delta):
	# On récupère la taille de la fenêtre et la position de la souris
	var viewport_width = get_viewport().get_visible_rect().size.x
	var mouse_x = get_viewport().get_mouse_position().x
	
	# --- Logique de mouvement ---
	
	# 1. Si la souris est à GAUCHE (dans la marge de gauche)
	if mouse_x < scroll_margin:
		# On tourne vers la gauche (Positif dans Godot)
		rotation.y += rotation_speed * delta
		
	# 2. Si la souris est à DROITE (dans la marge de droite)
	elif mouse_x > viewport_width - scroll_margin:
		# On tourne vers la droite (Négatif dans Godot)
		rotation.y -= rotation_speed * delta
	
	# --- Blocage (Clamp) ---
	# On empêche la tête d'aller trop loin
	# Note : On inverse min/max car limit_right est négatif
	rotation.y = clamp(rotation.y, limit_right, limit_left)
