extends Node

var socket: SocketIOClient
var session_id := "default-session"
var player_id: String = ""  # Will be assigned by the server

signal player_assigned(player_id)
signal game_state_updated(data)
signal game_won(winner)
signal move_rejected(reason)

func _ready():
	socket = SocketIOClient.new("http://localhost:8000/socket.io/", {"player": ""})
	socket.on_engine_connected.connect(_on_engine_connected)
	socket.on_connect.connect(_on_socket_connected)
	socket.on_event.connect(_on_socket_event)
	add_child(socket)

func _on_engine_connected(_sid):
	socket.socketio_connect()

func _on_socket_connected(_payload, _namespace, error):
	if error:
		push_error("❌ Socket connection failed")
	else:
		print("✅ Socket connected to Flask server")

func _on_socket_event(event_name: String, payload: Variant, _namespace):
	match event_name:
		"assign_player_id":
			player_id = payload["player_id"]
			print("✅ You are:", player_id)
			emit_signal("player_assigned", player_id)

		"update_state":
			emit_signal("game_state_updated", payload)

		"game_won":
			emit_signal("game_won", payload["winner"])

		"move_rejected":
			emit_signal("move_rejected", payload["reason"])

# Call this when player clicks an empty marker during placement
func send_place_piece(position: String):
	if player_id == "":
		print("⏳ Waiting for player ID...")
		return

	var data = {
		"session": session_id,
		"player": player_id,
		"position": position
	}
	print("📤 Sending place_piece:", data)
	socket.socketio_send("place_piece", data)

# Call this when a player attempts a legal move
func send_move_piece(from_pos: String, to_pos: String):
	if player_id == "":
		print("⏳ Waiting for player ID...")
		return

	var data = {
		"session": session_id,
		"player": player_id,
		"from": from_pos,
		"to": to_pos
	}
	print("📤 Sending move_piece:", data)
	socket.socketio_send("move_piece", data)
