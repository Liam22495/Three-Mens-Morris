from flask import Flask, request
from flask_socketio import SocketIO, emit, join_room, leave_room
import uuid

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# Store active game sessions
sessions = {}

@app.route('/')
def index():
    return "Three Men's Morris server is running."

@socketio.on('create_session')
def handle_create_session():
    session_id = str(uuid.uuid4())[:6]  # generate unique session code
    sessions[session_id] = {
        "players": [],
        "board": {},
        "turn": None,
        "phase": "placement",
        "game_over": False
    }
    print(f"Session created: {session_id}")
    emit('session_created', {"session_id": session_id})

@socketio.on('join_session')
def handle_join_session(data):
    session_id = data.get("session_id")
    username = data.get("username")
    sid = request.sid

    if session_id not in sessions:
        emit('error', {"message": "Session does not exist."})
        return

    session = sessions[session_id]

    if len(session["players"]) >= 2:
        emit('error', {"message": "Session is full."})
        return

    session["players"].append({"id": sid, "username": username})
    join_room(session_id)

    emit('joined_session', {
        "session_id": session_id,
        "player_index": len(session["players"]),
        "players": [p["username"] for p in session["players"]]
    }, room=session_id)

    # Start game if both players are in
    if len(session["players"]) == 2:
        session["turn"] = 0
        socketio.emit('start_game', {"message": "Game started!"}, room=session_id)

@socketio.on('disconnect')
def handle_disconnect():
    print("Client disconnected:", request.sid)

if __name__ == '__main__':
    print("🟢 Flask-SocketIO Server starting on http://localhost:5000")
    socketio.run(app, host='0.0.0.0', port=5000)

