extends Node2D

# --- CONFIGURATION ---
@export_enum("left", "right") var cote : String = "left"

# --- IMAGES ---
@export_group("Visuels")
@export var tex_porte_metal : Texture2D    # Image porte fermée
@export var tex_panel_vert : Texture2D     # Panneau bouton VERT
@export var tex_panel_rouge : Texture2D    # Panneau bouton ROUGE

# --- SONS ---
@export_group("Sons")
@export var son_door : AudioStreamPlayer
@export var son_light : AudioStreamPlayer

# --- REFERENCES INTERNES ---
@onready var sprite_porte = $Sprite_Porte
@onready var sprite_panel = $Sprite_Panel
@onready var audio_porte = $Audio_Porte
@onready var audio_light = $Audio_Light

# --- ETAT ---
var est_fermee : bool = false
var est_allumee : bool = false

# On récupère le parent (Office)
@onready var office_ref = get_owner() 

func _ready():
	# 1. Configuration initiale des images
	if tex_porte_metal:
		sprite_porte.texture = tex_porte_metal
	
	if tex_panel_vert:
		sprite_panel.texture = tex_panel_vert
		
	# 2. Configuration des sons
	if son_door: audio_porte.stream = son_door
	if son_light: audio_light.stream = son_light
	
	# 3. Connexion des boutons (MODIFIÉ)
	# On connecte le clic à des fonctions "INPUT" qui envoient l'ordre au bureau
	$Zone_Clic_Door.pressed.connect(_on_input_door_clicked)
	
	$Zone_Clic_Light.button_down.connect(_on_input_light_down)
	$Zone_Clic_Light.button_up.connect(_on_input_light_up)
	
	# Sécurité visuelle
	sprite_porte.visible = false

# ============================================================
# PARTIE 1 : INPUTS (Le joueur clique avec la souris)
# Ces fonctions ne font RIEN d'autre que demander au bureau
# ============================================================

func _on_input_door_clicked():
	# On ne change rien ici, on envoie l'ordre au "Cerveau" (Office)
	if office_ref and office_ref.has_method("commander_porte"):
		office_ref.commander_porte(cote)

func _on_input_light_down():
	if office_ref and office_ref.has_method("commander_lumiere"):
		office_ref.commander_lumiere(cote, true)

func _on_input_light_up():
	if office_ref and office_ref.has_method("commander_lumiere"):
		office_ref.commander_lumiere(cote, false)


# ============================================================
# PARTIE 2 : ACTIONS (Exécutées par le bureau / Réseau)
# Ces fonctions sont appelées par office.gd (via RPC ou local)
# ============================================================

# Appelée par office.gd -> commander_porte()
func _on_door_toggle():
	if est_coupure_courant(): return 
	
	est_fermee = !est_fermee
	
	# Visuel Métal
	sprite_porte.visible = est_fermee
	
	# Visuel Panneau (Vert <-> Rouge)
	if est_fermee:
		if tex_panel_rouge: sprite_panel.texture = tex_panel_rouge
	else:
		if tex_panel_vert: sprite_panel.texture = tex_panel_vert
	
	# Son
	if audio_porte.stream:
		audio_porte.play()

# Appelée par office.gd -> commander_lumiere(true)
func _on_light_start():
	if est_coupure_courant(): return
	
	est_allumee = true
	if not audio_light.playing:
		audio_light.play()
	
	# Note : Le changement de fond d'écran est maintenant géré par office.gd
	# dans sa fonction update_office_background(), mais on peut garder ça
	# pour la compatibilité solo si besoin.
	if office_ref and office_ref.has_method("set_light_state"):
		office_ref.set_light_state(cote, true)

# Appelée par office.gd -> commander_lumiere(false)
func _on_light_stop():
	est_allumee = false
	audio_light.stop()
	
	if office_ref and office_ref.has_method("set_light_state"):
		office_ref.set_light_state(cote, false)


# ============================================================
# SECURITES & BLACKOUT
# ============================================================

func est_coupure_courant() -> bool:
	if office_ref and "est_coupure_courant" in office_ref:
		return office_ref.est_coupure_courant
	return false

func couper_courant():
	# Appelée par Office.gd lors du blackout
	if est_fermee == true:
		est_fermee = false
		audio_porte.play()
		
	est_allumee = false
	sprite_porte.visible = false
	audio_light.stop()
	
	# On désactive les boutons pour qu'on ne puisse plus cliquer
	$Zone_Clic_Door.disabled = true
	$Zone_Clic_Light.disabled = true
	
	# Force visuelle
	if office_ref and office_ref.has_method("set_light_state"):
		office_ref.set_light_state(cote, false)
