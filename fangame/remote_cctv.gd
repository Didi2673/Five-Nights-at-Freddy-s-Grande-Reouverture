extends Control

# --- CONNEXION ---
# On crée une variable pour relier ce script au système 3D
# Le "@export" permet de glisser le noeud Cameras_System depuis l'inspecteur
@export var cameras_system : Node3D 

# --- SIGNAUX DES BOUTONS ---

# CAM 1 : Show Stage (Index 0)
func _on_cam_1_pressed():
	changer_camera(0)

# CAM 2 : Dining Area (Index 1)
func _on_cam_2_pressed():
	changer_camera(1)

# CAM 3 : Pirate Cove (Index 2)
func _on_cam_3_pressed():
	changer_camera(2)

# CAM 4 : Corner Prize (Index 3)
func _on_cam_4_pressed():
	changer_camera(3)

func _on_cam_5_pressed():
	changer_camera(4)
	
func _on_cam_6_pressed():
	changer_camera(5)

func _on_cam_7_pressed():
	changer_camera(6)
	
func _on_cam_8_pressed():
	changer_camera(7)
	
func _on_cam_9_pressed():
	changer_camera(8)
	
func _on_cam_10_pressed():
	changer_camera(9)
	
func _on_cam_11_pressed():
	changer_camera(10)
	
func _on_cam_12_pressed():
	changer_camera(11)


# BOUTON QUITTER (Si tu as un bouton "Exit" sur l'écran)
func _on_bouton_exit_pressed():
	if cameras_system:
		cameras_system.fermer_moniteur()

# --- FONCTION UTILITAIRE ---
# Cette fonction évite de réécrire le "if" partout
func changer_camera(index_camera : int):
	if cameras_system:
		cameras_system.activer_camera(index_camera)
	else:
		print("ERREUR : Le système de caméra n'est pas relié dans l'inspecteur !")


func _on_bouton_cam_01_pressed() -> void:
	changer_camera(0)


func _on_bouton_cam_02_pressed() -> void:
	changer_camera(1)


func _on_bouton_cam_03_pressed() -> void:
	changer_camera(2)


func _on_bouton_cam_04_pressed() -> void:
	changer_camera(3)


func _on_bouton_cam_05_pressed() -> void:
	changer_camera(4)


func _on_bouton_cam_06_pressed() -> void:
	changer_camera(5)


func _on_bouton_cam_07_pressed() -> void:
	changer_camera(6)


func _on_bouton_cam_08_pressed() -> void:
	changer_camera(7)


func _on_bouton_cam_09_pressed() -> void:
	changer_camera(8)


func _on_bouton_cam_10_pressed() -> void:
	changer_camera(9)


func _on_bouton_cam_11_pressed() -> void:
	changer_camera(10)


func _on_bouton_cam_12_pressed() -> void:
	changer_camera(11)
