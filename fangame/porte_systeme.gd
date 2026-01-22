extends Node2D

# --- CONFIGURATION ---
@export_enum("left", "right") var cote : String = "left"

# --- IMAGES (A assigner dans la scène Office pour différencier gauche/droite) ---
@export_group("Visuels")
@export var tex_porte_metal : Texture2D    # Image porte fermée
@export var tex_panel_vert : Texture2D     # Panneau bouton VERT
@export var tex_panel_rouge : Texture2D    # Panneau bouton ROUGE

# --- SONS ---
@export_group("Sons")
@export var son_door : AudioStream
@export var son_light : AudioStream

# --- REFERENCES INTERNES ---
@onready var sprite_porte = $Sprite_Porte
@onready var sprite_panel = $Sprite_Panel
@onready var audio_porte = $Audio_Porte
@onready var audio_light = $Audio_Light

# --- ETAT ---
var est_fermee : bool = false
var est_allumee : bool = false

# On récupère le parent (Office) pour lui dire de changer le fond
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
	
	# 3. Connexion des boutons invisibles
	$Zone_Clic_Door.pressed.connect(_on_door_toggle)
	
	# Pour la lumière, on veut l'effet "Maintenir appuyé"
	$Zone_Clic_Light.button_down.connect(_on_light_start)
	$Zone_Clic_Light.button_up.connect(_on_light_stop)
	
	# Sécurité visuelle
	sprite_porte.visible = false

# --- ACTION PORTE ---
func _on_door_toggle():
	if est_coupure_courant(): return # Pas d'action si plus de jus
	
	est_fermee = !est_fermee
	
	# Visuel Métal
	sprite_porte.visible = est_fermee
	
	# Visuel Panneau (Vert <-> Rouge)
	if est_fermee:
		if tex_panel_rouge: sprite_panel.texture = tex_panel_rouge
	else:
		if tex_panel_vert: sprite_panel.texture = tex_panel_vert
	
	# Son
	audio_porte.play()

# --- ACTION LUMIERE ---
func _on_light_start():
	if est_coupure_courant(): return
	
	est_allumee = true
	audio_light.play()
	
	# On dit à Office.gd : "Change le fond d'écran !"
	if office_ref and office_ref.has_method("set_light_state"):
		office_ref.set_light_state(cote, true)

func _on_light_stop():
	est_allumee = false
	audio_light.stop()
	
	# On dit à Office.gd : "Remets le fond éteint"
	if office_ref and office_ref.has_method("set_light_state"):
		office_ref.set_light_state(cote, false)

# --- SECURITES ---
func est_coupure_courant() -> bool:
	# On vérifie si l'office a du jus
	if office_ref and "est_coupure_courant" in office_ref:
		return office_ref.est_coupure_courant
	return false

func couper_courant():
	# Appelée par Office.gd lors du blackout
	est_fermee = false
	est_allumee = false
	sprite_porte.visible = false
	audio_light.stop()
	
	# On désactive les boutons pour qu'on ne puisse plus cliquer
	$Zone_Clic_Door.disabled = true
	$Zone_Clic_Light.disabled = true
	
	# On force l'extinction visuelle
	if office_ref: office_ref.set_light_state(cote, false)
