extends Node

var socket: SocketIOClient
var session_id := "default-session"
var player_id: String = ""
var queued_position: String = ""

signal player_assigned(player_id)
signal game_state_updated(data)
signal game_won(winner)
signal move_rejected(reason)

func _ready():
	# Connect to Socket.IO server
	socket = SocketIOClient.new("http://localhost:8000/socket.io/")
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
	print("📥 Event from server:", event_name, payload)

	match event_name:
		"assign_player_id":
			player_id = payload["player_id"]
			print("✅ You are:", player_id)
			emit_signal("player_assigned", player_id)

			# Retry any queued placement
			if queued_position != "":
				print("🔁 Retrying queued placement:", queued_position)
				send_place_piece(queued_position)
				queued_position = ""

		"update_state":
			emit_signal("game_state_updated", payload)

		"game_won":
			emit_signal("game_won", payload["winner"])

		"move_rejected":
			emit_signal("move_rejected", payload["reason"])

# Request piece placement at a specific marker
func send_place_piece(position: String):
	if player_id == "":
		print("🚫 Cannot send place_piece, player_id is empty. Queuing placement:", position)
		queued_position = position
		return

	var data = {
		"session": session_id,
		"player": player_id,
		"position": position
	}
	print("📤 Sending place_piece:", data)
	socket.socketio_send("place_piece", data, "/")


# Request movement from one marker to another
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
	socket.socketio_send("move_piece", data, "/")
