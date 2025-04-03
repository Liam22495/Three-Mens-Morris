from flask import Flask, request
from flask_socketio import SocketIO, emit, join_room
from game import GameManager

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")
games = GameManager()

# Reuse from client-side logic
adjacency_map = {
    "Position0": ["Position1", "Position3"],
    "Position1": ["Position0", "Position2", "Position4"],
    "Position2": ["Position1", "Position5"],
    "Position3": ["Position0", "Position4", "Position6"],
    "Position4": ["Position1", "Position3", "Position5", "Position7"],
    "Position5": ["Position2", "Position4", "Position8"],
    "Position6": ["Position3", "Position7"],
    "Position7": ["Position4", "Position6", "Position8"],
    "Position8": ["Position5", "Position7"],
}


@socketio.on("create_game")
def handle_create_game(data):
    game_id = games.create_game()
    sid = request.sid
    games.join_game(game_id, sid)
    join_room(game_id)
    emit("game_created", {"game_id": game_id})


@socketio.on("join_game")
def handle_join_game(data):
    sid = request.sid
    game_id = data.get("game_id")
    if games.join_game(game_id, sid):
        join_room(game_id)
        emit("game_joined", {"game_id": game_id, "sid": sid}, room=game_id)
        emit("start_game", {"status": "start"}, room=game_id)
    else:
        emit("error", {"message": "Game full or invalid ID"})


@socketio.on("join_or_create_game")
def handle_join_or_create_game(data):
    sid = request.sid

    # Try to find an available game with just 1 player
    for game_id, session in games.sessions.items():
        if len(session.players) == 1:
            if games.join_game(game_id, sid):
                join_room(game_id)
                emit("game_joined", {"game_id": game_id}, room=game_id)
                emit("start_game", {"status": "start"}, room=game_id)

                # ✅ Emit first board update right after game starts
                emit(
                    "update_board",
                    {
                        "board": session.board,
                        "turn": session.turn,
                        "phase": session.phase,
                    },
                    room=game_id,
                )

                return

    # No game found, create one
    game_id = games.create_game()
    games.join_game(game_id, sid)
    join_room(game_id)
    emit("game_created", {"game_id": game_id})


@socketio.on("place_piece")
def handle_place_piece(data):
    sid = request.sid
    game_id = data.get("game_id")
    position = data.get("position")
    game = games.get_game(game_id)

    if not game or not position:
        emit("error", {"message": "Invalid game or position"})
        return

    if game.place_piece(sid, position, adjacency_map):
        emit(
            "update_board",
            {"board": game.board, "turn": game.turn, "phase": game.phase},
            room=game_id,
        )
    else:
        emit("error", {"message": "Invalid placement"})


@socketio.on("move_piece")
def handle_move_piece(data):
    sid = request.sid
    game_id = data.get("game_id")
    from_pos = data.get("from")
    to_pos = data.get("to")
    game = games.get_game(game_id)

    if not game or not from_pos or not to_pos:
        emit("error", {"message": "Invalid game or move"})
        return

    if game.move_piece(sid, from_pos, to_pos, adjacency_map):
        emit(
            "update_board",
            {"board": game.board, "turn": game.turn, "phase": game.phase},
            room=game_id,
        )

        if game.winner:
            emit("game_over", {"winner": game.winner}, room=game_id)
    else:
        emit("error", {"message": "Invalid movement"})


if __name__ == "__main__":
    socketio.run(app, host="0.0.0.0", port=5000)
