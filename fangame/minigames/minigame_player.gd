extends CharacterBody2D

@export var speed : float = 150.0

func _physics_process(delta):
	# Mouvement simple haut/bas/gauche/droite
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()
	
	# Optionnel : Animation simple si tu as un AnimatedSprite2D
	# if direction != Vector2.ZERO: $AnimatedSprite2D.play("walk")
	# else: $AnimatedSprite2D.play("idle")

# Fonction pour finir le mini-jeu (à connecter à un signal)
func terminer_minijeu():
	print("Mini-jeu terminé, retour au titre.")
	get_tree().change_scene_to_file("res://main_menu.tscn")
