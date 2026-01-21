extends Node3D

# --- Variables ---
var est_fermee : bool = false # Par défaut : Ouverte
var hauteur_fermeture : float = 2.7
var position_ouverte : Vector3 

# --- Couleurs ---
# On définit nos couleurs ici pour pouvoir les changer facilement
var couleur_ouverte = Color(1, 0, 0) # ROUGE (Rouge=1, Vert=0, Bleu=0)
var couleur_fermee = Color(0, 1, 0) # VERT (Rouge=0, Vert=1, Bleu=0)

# --- Références ---
@onready var porte_mobile = $Porte_Mobile 
@onready var bouton = $Bouton_Rouge # <-- ASSURE-TOI QUE LE NOM EST BON DANS TA SCÈNE
var tween : Tween

var a_du_courant : bool = true

func _ready():
	if porte_mobile:
		position_ouverte = porte_mobile.position
	
	# Au lancement, on s'assure que le bouton a la bonne couleur (Rouge car ouverte)
	maj_couleur_bouton(couleur_ouverte)

func _on_area_3d_input_event(_camera, event, _event_position, _normal, _shape_idx):
	if a_du_courant and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_door()

func couper_courant():
	a_du_courant = false # Le bouton ne marche plus
	maj_couleur_bouton(Color(0.1, 0.1, 0.1)) # Bouton éteint (Gris sombre)
	
	if est_fermee:
		toggle_door() # On force l'ouverture si elle était fermée
		
func toggle_door():
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	if est_fermee:
		# --- ON OUVRE ---
		tween.tween_property(porte_mobile, "position:y", position_ouverte.y, 0.5)
		# La porte devient ouverte -> Bouton Rouge
		maj_couleur_bouton(couleur_ouverte)
	else:
		# --- ON FERME ---
		var position_fermee = position_ouverte.y - hauteur_fermeture
		tween.tween_property(porte_mobile, "position:y", position_fermee, 0.2)
		# La porte devient fermée -> Bouton Vert
		maj_couleur_bouton(couleur_fermee)
	
	est_fermee = !est_fermee

# --- Nouvelle fonction pour gérer la couleur ---
func maj_couleur_bouton(nouvelle_couleur):
	# On vérifie si le bouton a déjà un matériau
	if bouton.material == null:
		# S'il n'en a pas, on en crée un nouveau standard
		bouton.material = StandardMaterial3D.new()
	
	# On change la couleur de l'objet
	bouton.material.albedo_color = nouvelle_couleur
	
	# PETIT BONUS : On fait briller le bouton (Emission) pour le voir dans le noir !
	bouton.material.emission_enabled = true
	bouton.material.emission = nouvelle_couleur
	bouton.material.emission_energy_multiplier = 1.0 # Règle l'intensité ici
