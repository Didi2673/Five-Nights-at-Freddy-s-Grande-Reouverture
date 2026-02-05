extends Control

# --- VARIABLES ---
var office_ref
var energy : float = 50.0
var max_energy : float = 100.0
var regen_rate : float = 3.5 # Régénération par seconde (Ajustable pour l'équilibrage)

# --- COÛTS EN ÉNERGIE ---
# Vous pouvez ajuster ces valeurs pour équilibrer le jeu VS
var costs = {
	"Bonnie": 15,
	"Chica": 15,
	"Freddy": 20, # Plus cher car il ne recule pas
	"Foxy": 25,   # Cher car c'est une phase d'attaque
	"Mangle": 15,
	"Springtrap": 15,
	"Golden-Freddy": 60, # Très cher (attaque directe)
	"Shadow-Bonnie": 40  # Cher (sabotage)
}

# --- RÉFÉRENCES UI ---
@onready var lbl_energy = $Panel_Header/HBoxContainer/Label_Energy
@onready var progress_bar = $Panel_Header/HBoxContainer/ProgressBar
@onready var feedback_lbl = $Label_Feedback

@onready var grid_buttons = $Panel_Controls/Grid_Actions

func setup(_office):
	office_ref = _office
	actualiser_boutons()

func _ready():
	# Configuration initiale de la barre
	if progress_bar:
		progress_bar.max_value = max_energy
		progress_bar.value = energy
	
	# Connexion automatique des boutons si vous les avez nommés correctement
	# Exemple : Btn_Bonnie, Btn_Chica...
	for btn in grid_buttons.get_children():
		if btn is Button:
			# On extrait le nom (ex: "Btn_Bonnie" -> "Bonnie")
			var nom_bot = btn.name.replace("Btn_", "")
			
			# On met le texte du bouton avec le coût
			if costs.has(nom_bot):
				btn.text = nom_bot + "\n(" + str(costs[nom_bot]) + " E)"
			
			# Connexion dynamique
			btn.pressed.connect(_on_command_pressed.bind(nom_bot))

func _process(delta):
	# Régénération passive
	if energy < max_energy:
		energy += regen_rate * delta
		if energy > max_energy: energy = max_energy
		update_ui()

func update_ui():
	if lbl_energy:
		lbl_energy.text = "ENERGIE : " + str(int(energy))
	if progress_bar:
		progress_bar.value = energy
		
	# Griser les boutons si pas assez d'énergie
	for btn in grid_buttons.get_children():
		var nom_bot = btn.name.replace("Btn_", "")
		if costs.has(nom_bot):
			btn.disabled = (energy < costs[nom_bot])

func _on_command_pressed(nom_bot):
	if not costs.has(nom_bot): return
	
	var cout = costs[nom_bot]
	
	if energy >= cout:
		# 1. On paie le coût
		energy -= cout
		update_ui()
		
		# 2. Gestion Spéciale : Shadow Bonnie (Cible la caméra regardée)
		var extra_arg = ""
		if nom_bot == "Shadow-Bonnie":
			# L'argument est la caméra que le Purple Guy regarde ACTUELLEMENT
			if office_ref.systeme_camera:
				extra_arg = office_ref.systeme_camera.camera_actuelle
				afficher_feedback("Shadow Bonnie envoyé en " + extra_arg)
			else:
				extra_arg = "Cam01" # Sécurité
		else:
			afficher_feedback("Ordre envoyé à " + nom_bot)
		
		# 3. Envoi au Serveur (via Office)
		office_ref.rpc("server_versus_command", nom_bot, extra_arg)
		
	else:
		afficher_feedback("Pas assez d'énergie !", Color.RED)

func afficher_feedback(texte : String, couleur : Color = Color.WHITE):
	if feedback_lbl:
		feedback_lbl.text = texte
		feedback_lbl.modulate = couleur
		feedback_lbl.visible = true
		
		# Petit effet pour cacher le texte après 2 secondes
		await get_tree().create_timer(2.0).timeout
		if feedback_lbl.text == texte: # Si le texte n'a pas changé entre temps
			feedback_lbl.visible = false

# Fonction optionnelle si vous voulez que les boutons se génèrent tout seuls
# (Au lieu de les placer à la main dans l'éditeur)
func actualiser_boutons():
	# Si vous préférez placer les boutons à la main dans l'éditeur, ignorez cette fonction.
	# Sinon, elle peut créer les boutons manquants.
	pass
