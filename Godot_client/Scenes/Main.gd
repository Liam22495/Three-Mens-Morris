extends Node2D

@export var PlayerPieceScene: PackedScene
@export var OpponentPieceScene: PackedScene

@onready var positions = $Board/Background/Positions
@onready var turn_label = $UI/TurnLabel

var current_turn = "player"
var position_occupied = {}   # e.g., { "Position0": "player" }
var player_piece_count = 0
var opponent_piece_count = 0

var in_movement_phase = false
var selected_piece = null
var selected_marker = null

#Map to enforce andjacent moves only
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

const MAX_PIECES = 3

func _ready():
	for area in positions.get_children():
		area.input_pickable = true
		area.connect("input_event", Callable(self, "_on_position_clicked").bind(area))

	turn_label.text = "Your Turn"

func _on_position_clicked(_viewport, event: InputEvent, _shape_idx: int, area: Area2D):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Clicked on a position
		if not in_movement_phase:
			_handle_placement(area)
		else:
			_handle_movement(area)

func _handle_placement(area: Area2D):
	if area and not position_occupied.has(area.name):
		if current_turn == "player" and player_piece_count < MAX_PIECES:
			var piece = PlayerPieceScene.instantiate()
			piece.position = Vector2.ZERO
			area.add_child(piece)
			position_occupied[area.name] = {"player": piece}
			player_piece_count += 1
			current_turn = "opponent"
			turn_label.text = "Opponent's Turn"

		elif current_turn == "opponent" and opponent_piece_count < MAX_PIECES:
			var piece = OpponentPieceScene.instantiate()
			piece.position = Vector2.ZERO
			area.add_child(piece)
			position_occupied[area.name] = {"opponent": piece}
			opponent_piece_count += 1
			current_turn = "player"
			turn_label.text = "Your Turn"

	# Check if placement is done
	if player_piece_count == MAX_PIECES and opponent_piece_count == MAX_PIECES:
		in_movement_phase = true
		print(">>> Movement phase started <<<")
		turn_label.text = current_turn.capitalize() + "'s Turn (Move a piece)"

func _handle_movement(area: Area2D):
	# If the clicked marker has a piece belonging to the current player
	if position_occupied.has(area.name):
		var data = position_occupied[area.name]
		if current_turn in data:
			# Deselects if it's already selected
			if selected_marker == area:
				selected_piece = null
				selected_marker = null
				print("Deselected piece.")
			else:
				selected_piece = data[current_turn]
				selected_marker = area
				print("Selected piece from:", area.name)
			return  # Skip the rest of the logic if selecting
	#Move to an empty, adjacent marker
	elif selected_piece and not position_occupied.has(area.name):
		var valid_moves = adjacency_map.get(selected_marker.name, [])
		if area.name in valid_moves:
			selected_marker.remove_child(selected_piece)
			area.add_child(selected_piece)
			selected_piece.position = Vector2.ZERO

			position_occupied.erase(selected_marker.name)
			position_occupied[area.name] = {current_turn: selected_piece}

			selected_piece = null
			selected_marker = null

			current_turn = "opponent" if current_turn == "player" else "player"
			turn_label.text = current_turn.capitalize() + "'s Turn (Move a piece)"
		else:
			print("Invalid move: ", area.name, " is not adjacent to ", selected_marker.name)
