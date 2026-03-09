extends Node3D

# --- Paramètres PC ---
# La vitesse de rotation de la tête
var rotation_speed : float = 2.0
# La zone en pixels sur les bords qui déclenche la rotation
var scroll_margin : int = 150

# --- Paramètres Mobile ---
# La sensibilité du glissement du doigt
var swipe_sensitivity : float = 0.005 

# Limites de rotation (Gauche / Droite) en radians
var limit_left : float = deg_to_rad(60.0) 
var limit_right : float = deg_to_rad(-60.0)

var is_mobile : bool = false

func _ready():
	# On détecte si le jeu tourne sur mobile
	is_mobile = OS.has_feature("android") or OS.has_feature("mobile")
	
	if not is_mobile:
		# IMPORTANT : On confine la souris uniquement sur PC
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED

func _process(delta):
	# Si on est sur mobile, on ignore la vérification des bords de l'écran
	if is_mobile: return
	
	# --- Logique de mouvement PC ---
	var viewport_width = get_viewport().get_visible_rect().size.x
	var mouse_x = get_viewport().get_mouse_position().x
	
	if mouse_x < scroll_margin:
		rotation.y += rotation_speed * delta
	elif mouse_x > viewport_width - scroll_margin:
		rotation.y -= rotation_speed * delta
	
	# --- Blocage (Clamp) ---
	rotation.y = clamp(rotation.y, limit_right, limit_left)

func _input(event):
	# --- Logique de mouvement Mobile ---
	# On détecte le glissement du doigt sur l'écran
	if is_mobile and event is InputEventScreenDrag:
		
		# event.relative.x contient le nombre de pixels parcourus par le doigt
		# On l'ajoute à la rotation (multiplié par la sensibilité)
		rotation.y += event.relative.x * swipe_sensitivity
		
		# Note : Si la caméra tourne dans le "mauvais" sens selon vos préférences,
		# changez le "+=" en "-=" juste au-dessus !
		
		# --- Blocage (Clamp) pour le mobile ---
		rotation.y = clamp(rotation.y, limit_right, limit_left)
