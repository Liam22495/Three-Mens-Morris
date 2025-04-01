extends Node2D

@export var PlayerPieceScene: PackedScene
@export var OpponentPieceScene: PackedScene

@onready var positions = $Board/Background/Positions
@onready var turn_label = $UI/TurnLabel

var current_turn = "player"
var position_occupied = {}
var player_piece_count = 0
var opponent_piece_count = 0

const MAX_PIECES = 3

func _ready():
	for area in positions.get_children():
		area.input_pickable = true
		area.connect("input_event", Callable(self, "_on_position_clicked").bind(area))

	turn_label.text = "Your Turn"

func _on_position_clicked(_viewport, event: InputEvent, _shape_idx: int, area: Area2D):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if area and not position_occupied.has(area.name):
			if current_turn == "player" and player_piece_count < MAX_PIECES:
				var piece = PlayerPieceScene.instantiate()
				piece.position = Vector2.ZERO
				area.add_child(piece)
				position_occupied[area.name] = "player"
				player_piece_count += 1
				current_turn = "opponent"
				turn_label.text = "Opponent's Turn"

			elif current_turn == "opponent" and opponent_piece_count < MAX_PIECES:
				var piece = OpponentPieceScene.instantiate()
				piece.position = Vector2.ZERO
				area.add_child(piece)
				position_occupied[area.name] = "opponent"
				opponent_piece_count += 1
				current_turn = "player"
				turn_label.text = "Your Turn"
