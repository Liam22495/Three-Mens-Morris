extends Node2D

@onready var socket := preload("res://SocketIOClient.gd").new("http://localhost:5000/socket.io/")
@export var PlayerPieceScene: PackedScene
@export var OpponentPieceScene: PackedScene

@onready var positions = $Board/Background/Positions
@onready var turn_label = $UI/TurnLabel

var current_turn = "player"
var position_occupied = {}   # e.g Position0": "player" }
var player_piece_count = 0
var opponent_piece_count = 0
var in_movement_phase = false
var selected_piece = null
var selected_marker = null
const MAX_PIECES = 3
var game_over = false
var game_id = ""
var player_id = ""

#Map to enforce andjacent moves
var adjacency_map = {
	"Position0": ["Position1", "Position3"],
	"Position1": ["Position0", "Position2", "Position4"],
	"Position2": ["Position1", "Position5"],
	"Position3": ["Position0", "Position4", "Position6"],
	"Position4": ["Position1", "Position3", "Position5", "Position7"],
	"Position5": ["Position2", "Position4", "Position8"],
	"Position6": ["Position3", "Position7"],
	"Position7": ["Position4", "Position6", "Position8"],
	"Position8": ["Position5", "Position7"]
}
#Map to enforce win conditions
var win_conditions = [
	["Position0", "Position1", "Position2"],
	["Position3", "Position4", "Position5"],
	["Position6", "Position7", "Position8"],
	["Position0", "Position3", "Position6"],
	["Position1", "Position4", "Position7"],
	["Position2", "Position5", "Position8"],
	["Position0", "Position4", "Position8"],
	["Position2", "Position4", "Position6"]
]

func _ready():
	await get_tree().process_frame  # Delay 1 frame to ensure nodes exist

	# Setup clickable board positions
	for area in positions.get_children():
		print("🔍 Setting up:", area.name)
		area.input_pickable = true
		area.connect("input_event", Callable(self, "_on_position_clicked").bind(area))
		print("✅ Bound click for", area.name)

	turn_label.text = "Connecting..."

	add_child(socket)
	socket.connect("on_connect", _on_socket_connected)
	socket.connect("on_event", _on_socket_event)
	socket.connect("on_engine_connected", _on_engine_connected)

func _on_position_clicked(_viewport: Viewport, event: InputEvent, _shape_idx: int, area: Area2D):
	if game_over:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicked on a position
		if not in_movement_phase:
			_handle_placement(area)
		else:
			_handle_movement(area)

func _handle_placement(area: Area2D):
	if game_over:
		print("❌ Game is over, can't place.")
		return

	if not area:
		print("❌ Clicked area is null.")
		return

	print("🟡 Clicked:", area.name)
	print("🔄 Current Turn:", current_turn)
	print("🆔 Player ID:", player_id)

	if position_occupied.has(area.name):
		print("❌ Position already occupied:", area.name)
		return

	if current_turn == player_id:
		print("✅ Sending place_piece to server...")
		socket.socketio_send("place_piece", {
			"game_id": game_id,
			"position": area.name
		})
	else:
		print("❌ Not your turn or you’ve placed 3 pieces already.")

func _handle_movement(area: Area2D):
	if not in_movement_phase or current_turn != player_id:
		print("⛔ Can't move: wrong phase or not your turn.")
		return

	if position_occupied.has(area.name):
		var data = position_occupied[area.name]
		if current_turn in data:
			# Deselect previously selected piece (if already selected)
			if selected_marker == area:
				var prev_highlight = selected_piece.get_node_or_null("Highlight")
				if prev_highlight:
					prev_highlight.visible = false

				selected_piece = null
				selected_marker = null
				print("Deselected piece.")

			else:
				# Deselect any previously selected piece
				if selected_marker and selected_piece:
					var prev_highlight = selected_piece.get_node_or_null("Highlight")
					if prev_highlight:
						prev_highlight.visible = false

				# Select new piece
				selected_piece = data[current_turn]
				selected_marker = area
				print("Selected piece from:", area.name)

				var new_highlight = selected_piece.get_node_or_null("Highlight")
				if new_highlight:
					new_highlight.visible = true
			return  # Done selecting, skip move logic

	elif selected_piece and not position_occupied.has(area.name):
		var valid_moves = adjacency_map.get(selected_marker.name, [])
		print("💡 Attempting move from %s to %s" % [selected_marker.name, area.name])
		print("📍 Valid moves:", valid_moves)

		if area.name in valid_moves:
			print("🚀 Emitting move_piece:", selected_marker.name, "➡", area.name)
			socket.socketio_send("move_piece", {
				"game_id": game_id,
				"from": selected_marker.name,
				"to": area.name
			})

			# Reset selection + hide highlight
			var highlight = selected_piece.get_node_or_null("Highlight")
			if highlight:
				highlight.visible = false

			selected_piece = null
			selected_marker = null
		else:
			print("Invalid move: ", area.name, " is not adjacent to ", selected_marker.name)

func check_win(player: String) -> bool:
	for condition in win_conditions:
		var has_all = true
		for pos in condition:
			if not position_occupied.has(pos) or not position_occupied[pos].has(player):
				has_all = false
				break
		if has_all:
			return true
	return false

func _on_socket_connected(_payload, _namespace, _error):
	print("Connected to server.")
	turn_label.text = "Waiting for opponent..."

func _on_socket_event(event_name: String, payload: Variant, _namespace: String):
	match event_name:
		"game_created":
			game_id = payload["game_id"]
			print("Game created:", game_id)
			print("My SID is:", player_id)

		"game_joined":
			game_id = payload["game_id"]
			print("Joined game:", game_id)
			print("My SID is:", player_id)

		"start_game":
			print("Game starting...")

		"update_board":
			current_turn = payload["turn"]
			in_movement_phase = payload["phase"] == "movement"

			update_board_visual(payload["board"])
			print("📦 Board updated! Turn is now:", current_turn)

			if game_over:
				return

			if current_turn == player_id:
				turn_label.text = "Your Turn"
			else:
				turn_label.text = "Opponent's Turn"

		"game_over":
			var winner = payload["winner"]
			if winner == player_id:
				turn_label.text = "You win!"
			else:
				turn_label.text = "You lose!"
			game_over = true

		"error":
			print("Server error:", payload["message"])	
			
func _on_engine_connected(sid: String):
	print("Engine connected! SID from server:", sid)
	player_id = sid
	socket.socketio_send("join_or_create_game", {})

func update_board_visual(board: Dictionary):
	position_occupied.clear()
	selected_marker = null
	selected_piece = null

	for area in positions.get_children():
		for child in area.get_children():
			if not child is CollisionShape2D:
				child.queue_free()

	# Rebuild from server state
	for position_name in board.keys():
		var owner_sid = board[position_name]
		if owner_sid == null:
			continue

		var area = positions.get_node(position_name)
		var piece

		if owner_sid == player_id:
			piece = PlayerPieceScene.instantiate()
		else:
			piece = OpponentPieceScene.instantiate()

		position_occupied[position_name] = { owner_sid: piece }

		piece.position = Vector2.ZERO
		area.add_child(piece)
