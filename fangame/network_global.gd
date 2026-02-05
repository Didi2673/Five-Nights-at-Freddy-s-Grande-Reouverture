extends Node

# Signaux pour prévenir le menu qu'il se passe des choses
signal player_list_changed
signal connection_failed
signal connection_success
signal game_started
signal challenge_changed(challenge_id)

signal start_night_selection # Pour dire au menu d'afficher le choix
signal game_ended # Pour dire au menu de réafficher le lobby au retour

var active_challenge_multi_id : String = "custom" # ID par défaut

var selected_night_multi : int = 1
var is_in_game : bool = false

var peer = ENetMultiplayerPeer.new()
var PORT = 9999
var MAX_PLAYERS = 4 # Limité à 2 pour l'instant (Coop ou VS)

# Structure : { id_unique : { "name": "Pseudo", "ready": false } }
var players = {}
var player_info = {"name": "Joueur", "ready": false}

# Infos de la partie (Gérées par l'hôte)
var game_mode = "Coop" # "Coop" ou "VS"


func recuperer_mon_ip_locale() -> String:
	var ip_list = IP.get_local_addresses()
	var ip_a_afficher = ""
	
	for ip in ip_list:
		# On ignore localhost et IPv6
		if ip == "127.0.0.1" or ":" in ip:
			continue
			
		# PRIORITÉ 1 : Radmin VPN (Commence souvent par 26.)
		if ip.begins_with("26."):
			return ip # On retourne direct celle-là, c'est la meilleure pour le VPN
			
		# PRIORITÉ 2 : Réseau local classique (192.168. ou 10.)
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			ip_a_afficher = ip
			
	# Si on a trouvé une IP locale mais pas Radmin, on la retourne
	if ip_a_afficher != "":
		return ip_a_afficher
		
	return "IP Introuvable"

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


@rpc("authority", "call_local", "reliable")
func sync_challenge_selection(challenge_id : String):
	active_challenge_multi_id = challenge_id
	print("Challenge Multi changé pour : ", challenge_id)
	
	# C'est ici qu'on émet le signal.
	# Si le signal n'est pas déclaré en haut, ça plante ici aussi !
	challenge_changed.emit(challenge_id)


# --- FONCTIONS DE CONNEXION ---

func host_game(pseudo : String, mode : String):
	var err = peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		print("Impossible de créer le serveur : " + str(err))
		return
		
	multiplayer.multiplayer_peer = peer
	
	player_info["name"] = pseudo
	player_info["ready"] = false
	game_mode = mode
	
	players[1] = player_info # 1 est toujours l'ID de l'hôte
	player_list_changed.emit()
	print("Serveur créé. Mode : " + mode)

func join_game(pseudo : String, ip : String):
	peer.create_client(ip, PORT)
	multiplayer.multiplayer_peer = peer
	
	player_info["name"] = pseudo
	player_info["ready"] = false
	print("Tentative de connexion...")

# --- GESTION DES EVÉNEMENTS RÉSEAU ---

func _on_player_connected(id):
	print("Joueur connecté : ", id)
	# Quand quelqu'un arrive, on lui envoie nos infos
	rpc_id(id, "register_player", player_info)

func _on_player_disconnected(id):
	print("Joueur parti : ", id)
	players.erase(id)
	player_list_changed.emit()

func _on_connected_ok():
	print("Connecté au serveur avec succès !")
	connection_success.emit()
	
	var my_id = multiplayer.get_unique_id()
	
	# --- AJOUT ICI : On s'ajoute soi-même à notre liste locale ---
	players[my_id] = player_info
	player_list_changed.emit()
	# -------------------------------------------------------------
	
	# On envoie nos infos à l'hôte (ça, c'était déjà là)
	rpc_id(1, "register_player", player_info)

func _on_connected_fail():
	print("Echec connexion")
	connection_failed.emit()

func _on_server_disconnected():
	print("Serveur fermé")
	players.clear()
	peer.close()
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn") # Retour menu

# --- RPC (Synchronisation) ---

@rpc("any_peer", "reliable")
func register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	player_list_changed.emit()
	
	# Si je suis l'hôte, je dois dire au nouveau quel est le mode de jeu
	if multiplayer.is_server():
		rpc("sync_game_mode", game_mode)

@rpc("any_peer", "call_local", "reliable")
func update_player_ready(est_pret : bool):
	var id = multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id]["ready"] = est_pret
		player_list_changed.emit()
		
		# Vérification démarrage (Seul l'hôte vérifie)
		if multiplayer.is_server():
			check_start_game()

@rpc("authority", "call_local", "reliable")
func sync_game_mode(mode : String):
	game_mode = mode
	player_list_changed.emit() # Pour mettre à jour l'interface

# --- DEMARRAGE ---

func check_start_game():
	var all_ready = true
	if players.size() < 2: return # Pas de jeu tout seul en multi
	
	for id in players:
		if not players[id]["ready"]:
			all_ready = false
			break
	
	if all_ready:
		print("TOUT LE MONDE EST PRÊT ! Lancement séquence...")
		# On dit à tout le monde de lancer le compte à rebours
		rpc("pre_start_countdown")
		
@rpc("any_peer", "call_local", "reliable")
func pre_start_countdown():
	# On peut émettre un signal pour que le menu affiche "Lancement dans 3..."
	# Pour simplifier ici, on attend juste 3 secondes
	print("Lancement dans 3 secondes...")
	
	# Seul le serveur gère le timer pour éviter les désynchros
	if multiplayer.is_server():
		await get_tree().create_timer(3.0).timeout
		rpc("show_night_selector")

@rpc("authority", "call_local", "reliable")
func show_night_selector():
	# Ce signal va dire au MainMenu : 
	# - Si je suis HOST : Affiche le panneau de choix de nuit
	# - Si je suis CLIENT : Affiche "L'hôte choisit la nuit..."
	start_night_selection.emit()

@rpc("authority", "call_local", "reliable")
func launch_game_scene(nuit : int):
	selected_night_multi = nuit
	is_in_game = true
	print("Chargement de la Nuit ", nuit, " en Coop...")
	
	# Changement de scène pour tout le monde
	get_tree().change_scene_to_file("res://Scenes/office.tscn")

@rpc("any_peer", "call_local", "reliable")
func return_to_lobby_multi():
	is_in_game = false
	
	# 1. On remet tout le monde en "Pas Prêt"
	# Sinon, si les joueurs reviennent et sont encore marqués "Prêts", le jeu redémarre direct !
	player_info["ready"] = false
	
	if multiplayer.is_server():
		for id in players:
			players[id]["ready"] = false
	
	# 2. On charge la scène du menu
	# Comme NetworkGlobal est un Autoload, la connexion NE COUPE PAS ici.
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
