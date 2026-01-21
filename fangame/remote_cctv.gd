extends Control

# Lien vers le cerveau du système
@export var cameras_system : Node 

# --- SIGNAUX DES BOUTONS ---

func _on_cam_01_pressed():
	# AVANT : cameras_system.activer_camera(0)
	# MAINTENANT : On envoie le nom en toutes lettres
	cameras_system.changer_camera("Cam01")

func _on_cam_02_pressed():
	cameras_system.changer_camera("Cam02")

func _on_cam_03_pressed():
	cameras_system.changer_camera("Cam03")
	
func _on_cam_04_pressed():
	cameras_system.changer_camera("Cam04")
	
func _on_cam_05_pressed():
	cameras_system.changer_camera("Cam05")
	
func _on_cam_06_pressed():
	cameras_system.changer_camera("Cam06")
	
func _on_cam_07_pressed():
	cameras_system.changer_camera("Cam07")
	
func _on_cam_08_pressed():
	cameras_system.changer_camera("Cam08")
	
func _on_cam_09_pressed():
	cameras_system.changer_camera("Cam09")
	
func _on_cam_10_pressed():
	cameras_system.changer_camera("Cam10")

func _on_cam_11_pressed():
	cameras_system.changer_camera("Cam11")

func _on_cam_12_pressed():
	cameras_system.changer_camera("Cam12")

# ... Fais pareil pour tous les autres boutons ...

# BOUTON QUITTER / FERMER
# Si tu as un bouton pour fermer la tablette
func _on_bouton_exit_pressed():
	if cameras_system.has_method("fermer_moniteur"):
		cameras_system.fermer_moniteur()

# --- OPTIONNEL : Si tu utilisais une fonction intermédiaire ---
# Si tu avais une fonction qui ressemblait à ça, supprime-la ou adapte-la :
# func changer_camera(index):
#    cameras_system.activer_camera(index) <--- C'est cette ligne qui plante !


func _on_wind_start() -> void:
	pass # Replace with function body.


func _on_wind_stop() -> void:
	pass # Replace with function body.
