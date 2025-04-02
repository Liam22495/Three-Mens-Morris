import eventlet
eventlet.monkey_patch()

from flask import Flask, request
from flask_socketio import SocketIO, emit

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

games = {}  # session_id -> game state

def create_game(session_id):
    games[session_id] = {
        "positions": {},  # e.g., {"Position0": "player1"}
        "players": [],
        "turn": "player1",
        "phase": "placement"
    }

def check_win(positions, player):
    win_conditions = [
        ["Position0", "Position1", "Position2"],
        ["Position3", "Position4", "Position5"],
        ["Position6", "Position7", "Position8"],
        ["Position0", "Position3", "Position6"],
        ["Position1", "Position4", "Position7"],
        ["Position2", "Position5", "Position8"],
        ["Position0", "Position4", "Position8"],
        ["Position2", "Position4", "Position6"]
    ]
    for combo in win_conditions:
        if all(pos in positions and positions[pos] == player for pos in combo):
            return True
    return False

def count_player_pieces(positions, player):
    return list(positions.values()).count(player)

@socketio.on("place_piece")
def handle_place_piece(data):
    session = data["session"]
    player = data["player"]
    pos = data["position"]

    if session not in games:
        create_game(session)
    game = games[session]

    # Assign player ID if not yet set
    if player == "":
        if len(game["players"]) >= 2:
            emit("move_rejected", {"reason": "Game is full"}, room=request.sid)
            return
        assigned_id = "player1" if "player1" not in game["players"] else "player2"
        game["players"].append(assigned_id)
        emit("assign_player_id", {"player_id": assigned_id}, room=request.sid)
        return  # client will resend with correct player ID

    # Validate turn and position
    if game["turn"] != player:
        emit("move_rejected", {"reason": "Not your turn"}, room=request.sid)
        return
    if pos in game["positions"]:
        emit("move_rejected", {"reason": "Position already occupied"}, room=request.sid)
        return

    game["positions"][pos] = player

    # Switch to movement phase after 3 pieces each
    if count_player_pieces(game["positions"], "player1") >= 3 and count_player_pieces(game["positions"], "player2") >= 3:
        game["phase"] = "movement"

    game["turn"] = "player2" if player == "player1" else "player1"

    socketio.emit("update_state", {
        "positions": game["positions"],
        "turn": game["turn"],
        "phase": game["phase"]
    }, room=session)

@socketio.on("move_piece")
def handle_move_piece(data):
    session = data["session"]
    player = data["player"]
    from_pos = data["from"]
    to_pos = data["to"]

    if session not in games:
        emit("move_rejected", {"reason": "Invalid session"}, room=request.sid)
        return

    game = games[session]

    if game["phase"] != "movement":
        emit("move_rejected", {"reason": "Not in movement phase"}, room=request.sid)
        return
    if game["turn"] != player:
        emit("move_rejected", {"reason": "Not your turn"}, room=request.sid)
        return
    if from_pos not in game["positions"] or game["positions"][from_pos] != player:
        emit("move_rejected", {"reason": "Invalid from-position"}, room=request.sid)
        return
    if to_pos in game["positions"]:
        emit("move_rejected", {"reason": "Position already occupied"}, room=request.sid)
        return

    # Adjacency validation
    adjacency = {
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
    if to_pos not in adjacency.get(from_pos, []):
        emit("move_rejected", {"reason": "Invalid move: not adjacent"}, room=request.sid)
        return

    # Perform the move
    del game["positions"][from_pos]
    game["positions"][to_pos] = player

    if check_win(game["positions"], player):
        socketio.emit("game_won", {"winner": player}, room=session)
        return

    game["turn"] = "player2" if player == "player1" else "player1"

    socketio.emit("update_state", {
        "positions": game["positions"],
        "turn": game["turn"],
        "phase": game["phase"]
    }, room=session)

@socketio.on("connect")
def on_connect():
    print("🔌 Client connected:", request.sid)

@socketio.on("disconnect")
def on_disconnect():
    print("❌ Client disconnected:", request.sid)

if __name__ == '__main__':
    socketio.run(app, port=8000)