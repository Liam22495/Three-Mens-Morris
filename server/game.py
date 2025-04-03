import uuid


class GameSession:
    def __init__(self):
        self.board = {f"Position{i}": None for i in range(9)}  # Positions 0 to 8
        self.players = []
        self.turn = None
        self.phase = "placement"  # or "movement"
        self.piece_counts = {}
        self.max_pieces = 3
        self.winner = None

    def add_player(self, sid):
        if len(self.players) < 2:
            self.players.append(sid)
            self.piece_counts[sid] = 0
            if len(self.players) == 2:
                self.turn = self.players[0]
            return True
        return False

    def get_opponent(self, sid):
        return self.players[1] if sid == self.players[0] else self.players[0]

    def can_place(self, sid, position):
        return (
            self.phase == "placement"
            and self.board[position] is None
            and self.piece_counts[sid] < self.max_pieces
        )

    def place_piece(self, sid, position, adjacency_map):
        if self.can_place(sid, position):
            self.board[position] = sid
            self.piece_counts[sid] += 1

            # ✅ Check win after placing
            if self._check_win(sid):
                self.winner = sid
                return True

            self._advance_turn()
            self._check_transition_to_movement(adjacency_map)
            return True
        return False


    def can_move(self, sid, from_pos, to_pos, adjacency_map):
        print(
            f"🧠 CAN_MOVE check: turn={self.turn}, sid={sid}, from={from_pos}, to={to_pos}"
        )
        return (
            self.phase == "movement"
            and self.turn == sid
            and self.board[from_pos] == sid
            and self.board[to_pos] is None
            and to_pos in adjacency_map[from_pos]
        )

    def move_piece(self, sid, from_pos, to_pos, adjacency_map):
        print(f"🔁 Move requested from {from_pos} to {to_pos} by {sid}")
        print(f"Current turn: {self.turn}, Phase: {self.phase}")
        print(f"Board ownership @ {from_pos}: {self.board[from_pos]}")
        print(f"Board empty @ {to_pos}: {self.board[to_pos] is None}")
        print(f"Is adjacent: {to_pos in adjacency_map[from_pos]}")

        if self.can_move(sid, from_pos, to_pos, adjacency_map):
            self.board[from_pos] = None
            self.board[to_pos] = sid

            if self._check_win(sid):
                self.winner = sid
            else:
                self._advance_turn()

            print("✅ Move accepted")
            return True

        print("❌ Move rejected")
        return False


    def _advance_turn(self):
        self.turn = self.get_opponent(self.turn)

    def _check_transition_to_movement(self, adjacency_map):
        if all(count == self.max_pieces for count in self.piece_counts.values()):
            self.phase = "movement"



    def _check_win(self, sid):
        win_conditions = [
            ["Position0", "Position1", "Position2"],
            ["Position3", "Position4", "Position5"],
            ["Position6", "Position7", "Position8"],
            ["Position0", "Position3", "Position6"],
            ["Position1", "Position4", "Position7"],
            ["Position2", "Position5", "Position8"],
            ["Position0", "Position4", "Position8"],
            ["Position2", "Position4", "Position6"],
        ]
        
        for condition in win_conditions:
            if all(self.board.get(pos) == sid for pos in condition):
                return True
        return False


    def _get_adjacent_positions(self, position):
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
        return adjacency_map.get(position, [])


class GameManager:
    def __init__(self):
        self.sessions = {}

    def create_game(self):
        game_id = str(uuid.uuid4())[:8]
        self.sessions[game_id] = GameSession()
        return game_id

    def join_game(self, game_id, sid=None):
        if game_id in self.sessions:
            game = self.sessions[game_id]
            if sid and game.add_player(sid):
                return True
        return False

    def get_game(self, game_id):
        return self.sessions.get(game_id)
