## Codenames — a scripted plugin for daccord.
##
## All game logic + rendering lives here. The server relays actions to all
## session participants. Every client applies actions deterministically so
## their states stay in sync. The host generates the initial board and
## broadcasts it via the "start_game" action.
##
## Bridge API (from ScriptedRuntime):
##   api.draw_rect, api.draw_text, api.draw_line, api.draw_circle,
##   api.send_action, api.get_participants, api.get_role, api.get_user_id,
##   api.canvas_width, api.canvas_height

# ---------------------------------------------------------------------------
# Bridge API reference (set by host)
# ---------------------------------------------------------------------------
var api: Dictionary = {}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const CW := 640
const CH := 480

const GRID_COLS := 5
const GRID_ROWS := 5
const CARD_COUNT := 25

const CARD_W := 118.0
const CARD_H := 70.0
const CARD_GAP_X := 8.0
const CARD_GAP_Y := 6.0

const GRID_X := 7.0
const GRID_Y := 46.0
const TOP_BAR_H := 40.0
const BOTTOM_BAR_Y := 430.0

# Colors
const BG_COLOR := "#1a1a2e"
const TOP_BAR_COLOR := "#16213e"
const BOTTOM_BAR_COLOR := "#16213e"
const CARD_UNREVEALED := "#37474f"
const CARD_HOVER := "#546e7a"
const CARD_RED := "#c62828"
const CARD_BLUE := "#1565c0"
const CARD_NEUTRAL := "#616161"
const CARD_ASSASSIN := "#212121"
const TEXT_COLOR := "#ffffff"
const TEXT_DIM := "#90a4ae"
const RED_LIGHT := "#ef9a9a"
const BLUE_LIGHT := "#90caf9"
const CLUE_BG := "#263238"
const BTN_COLOR := "#0d7377"
const BTN_HOVER := "#14a3a8"

# Spymaster overlay colors (semi-transparent tints on unrevealed cards)
const SPY_RED := [0.78, 0.16, 0.16, 0.35]
const SPY_BLUE := [0.08, 0.40, 0.75, 0.35]
const SPY_NEUTRAL := [0.38, 0.38, 0.38, 0.25]
const SPY_ASSASSIN := [0.0, 0.0, 0.0, 0.55]

# ---------------------------------------------------------------------------
# Game state
# ---------------------------------------------------------------------------
var phase: String = "lobby"  # lobby | clue | guess | game_over
var board: Array = []        # [{word, color, revealed}, ...]
var teams: Dictionary = {
	"red": {"spymaster": "", "operatives": []},
	"blue": {"spymaster": "", "operatives": []},
}
var current_team: String = "red"
var clue_word: String = ""
var clue_count: int = 0
var guesses_remaining: int = 0
var scores: Dictionary = {"red": 0, "blue": 0}
var winner: String = ""

# Targets: how many cards each team needs to find
var targets: Dictionary = {"red": 9, "blue": 8}

# Local UI state
var hover_card: int = -1
var mouse_x: float = 0.0
var mouse_y: float = 0.0
var clue_input: String = ""
var clue_count_input: int = 1
var is_typing_clue: bool = false

# ---------------------------------------------------------------------------
# Word list (400 classic Codenames words)
# ---------------------------------------------------------------------------
const WORDS: Array = [
	"AFRICA", "AGENT", "AIR", "ALIEN", "ALPS", "AMAZON", "AMBULANCE",
	"AMERICA", "ANGEL", "ANTARCTICA", "APPLE", "ARM", "ATLANTIS", "AUSTRALIA",
	"AZTEC", "BACK", "BALL", "BAND", "BANK", "BAR", "BARK", "BAT", "BATTERY",
	"BEACH", "BEAR", "BEAT", "BED", "BEIJING", "BELL", "BELT", "BERLIN",
	"BERRY", "BILL", "BLOCK", "BOARD", "BOLT", "BOMB", "BOND", "BOOM",
	"BOW", "BOX", "BRIDGE", "BRUSH", "BUCK", "BUFFALO", "BUG", "BUGLE",
	"BUTTON", "CALF", "CANADA", "CAP", "CAPITAL", "CAR", "CARD", "CARROT",
	"CASINO", "CAST", "CAT", "CELL", "CENTAUR", "CENTER", "CHAIR", "CHANGE",
	"CHARGE", "CHECK", "CHEST", "CHICK", "CHINA", "CHOCOLATE", "CHURCH",
	"CIRCLE", "CLIFF", "CLOAK", "CLOCK", "CLOUD", "CLOWN", "CODE", "COLD",
	"COMIC", "COMPOUND", "CONCERT", "CONDUCTOR", "CONTRACT", "COOK", "COPPER",
	"COTTON", "COURT", "COVER", "CRANE", "CRASH", "CRICKET", "CROSS", "CROWN",
	"CYCLE", "CZECH", "DANCE", "DATE", "DAY", "DEATH", "DECK", "DEGREE",
	"DIAMOND", "DICE", "DINOSAUR", "DISEASE", "DOCTOR", "DOG", "DRAFT",
	"DRAGON", "DRESS", "DRILL", "DROP", "DRUM", "DUCK", "DWARF", "EAGLE",
	"EGYPT", "EMBASSY", "ENGINE", "ENGLAND", "EUROPE", "EYE", "FACE", "FAIR",
	"FALL", "FAN", "FENCE", "FIELD", "FIGHTER", "FIGURE", "FILE", "FILM",
	"FIRE", "FISH", "FLY", "FOOT", "FORCE", "FOREST", "FORK", "FRANCE",
	"GAME", "GAS", "GENIUS", "GERMANY", "GHOST", "GIANT", "GLASS", "GLOVE",
	"GOLD", "GRACE", "GRASS", "GREECE", "GREEN", "GROUND", "HAM", "HAND",
	"HAWK", "HEAD", "HEART", "HELICOPTER", "HIMALAYAS", "HOLE", "HOLLYWOOD",
	"HONEY", "HOOD", "HOOK", "HORN", "HORSE", "HOSPITAL", "HOTEL", "ICE",
	"ICE CREAM", "INDIA", "IRON", "IVORY", "JACK", "JAM", "JET", "JUPITER",
	"KANGAROO", "KETCHUP", "KEY", "KID", "KING", "KIWI", "KNIFE", "KNIGHT",
	"LAB", "LAP", "LASER", "LAWYER", "LEAD", "LEMON", "LEMONADE", "LEPRECHAUN",
	"LIFE", "LIGHT", "LIMOUSINE", "LINE", "LINK", "LION", "LOCH NESS", "LOCK",
	"LOG", "LONDON", "LUCK", "MAIL", "MAMMOTH", "MAPLE", "MARBLE", "MARCH",
	"MASS", "MATCH", "MERCURY", "MEXICO", "MICROSCOPE", "MILLIONAIRE", "MINE",
	"MINT", "MISSILE", "MODEL", "MOLE", "MOON", "MOSCOW", "MOUNT", "MOUSE",
	"MOUTH", "MUG", "NAIL", "NEEDLE", "NET", "NEW YORK", "NIGHT", "NINJA",
	"NOTE", "NOVEL", "NURSE", "NUT", "OCTOPUS", "OIL", "OLIVE", "OLYMPUS",
	"OPERA", "ORANGE", "ORGAN", "PALM", "PAN", "PANTS", "PAPER", "PARACHUTE",
	"PARK", "PART", "PASS", "PASTE", "PENGUIN", "PHOENIX", "PIANO", "PIE",
	"PILOT", "PIN", "PIPE", "PIRATE", "PISTOL", "PIT", "PITCH", "PLANE",
	"PLASTIC", "PLATE", "PLATYPUS", "PLAY", "PLOT", "POINT", "POISON",
	"POLE", "POLICE", "POOL", "PORT", "POST", "POUND", "PRESS", "PRINCESS",
	"PUMPKIN", "PUPIL", "PYRAMID", "QUEEN", "RABBIT", "RACKET", "RAY",
	"REVOLUTION", "RING", "ROBIN", "ROBOT", "ROCK", "ROME", "ROOT", "ROSE",
	"ROULETTE", "ROUND", "ROW", "RULER", "RUSSIA", "SAIL", "SATURN",
	"SCALE", "SCHOOL", "SCIENTIST", "SCORPION", "SCREEN", "SCUBA DIVER",
	"SEAL", "SERVER", "SHADOW", "SHAKESPEARE", "SHARK", "SHIP", "SHOE",
	"SHOP", "SHOT", "SHOWER", "SINK", "SKYSCRAPER", "SLIP", "SLUG", "SMUGGLER",
	"SNOW", "SNOWMAN", "SOCK", "SOLDIER", "SOUL", "SOUND", "SPACE", "SPELL",
	"SPIDER", "SPIKE", "SPOT", "SPRING", "SPY", "SQUARE", "STADIUM", "STAFF",
	"STAR", "STATE", "STICK", "STOCK", "STRAW", "STREAM", "STRIKE", "STRING",
	"SUB", "SUIT", "SUPERHERO", "SWING", "SWITCH", "TABLE", "TABLET", "TAG",
	"TAIL", "TAP", "TEACHER", "TELESCOPE", "TEMPLE", "THEATER", "THIEF",
	"THUMB", "TICK", "TIE", "TIME", "TOKYO", "TOOTH", "TORCH", "TOWER",
	"TRACK", "TRAIN", "TRIANGLE", "TRIP", "TRUNK", "TUBE", "TURKEY",
	"UNDERTAKER", "UNICORN", "VACUUM", "VAN", "VET", "VIKING", "VIOLET",
	"VIRUS", "VOLCANO", "WALL", "WAR", "WASHER", "WASHINGTON", "WATCH",
	"WATER", "WAVE", "WEB", "WELL", "WHALE", "WHIP", "WIND", "WITCH",
	"WORM", "YARD",
]


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _set_api(a: Dictionary) -> void:
	api = a


func _ready() -> void:
	pass


# ---------------------------------------------------------------------------
# Event handling (actions relayed by server)
# ---------------------------------------------------------------------------

func _on_event(event_type: String, data: Dictionary) -> void:
	if event_type != "action":
		return

	var action: String = str(data.get("action", ""))
	match action:
		"join_team":
			_handle_join_team(data)
		"start_game":
			_handle_start_game(data)
		"give_clue":
			_handle_give_clue(data)
		"guess_card":
			_handle_guess_card(data)
		"end_guessing":
			_handle_end_guessing(data)
		"new_game":
			_handle_new_game(data)


func _handle_join_team(data: Dictionary) -> void:
	if phase != "lobby":
		return
	var user_id: String = str(data.get("user_id", ""))
	var team: String = str(data.get("team", ""))
	var role: String = str(data.get("role", ""))
	if team != "red" and team != "blue":
		return
	if role != "spymaster" and role != "operative":
		return

	# Remove user from any existing position
	_remove_user_from_teams(user_id)

	# Assign to new position
	if role == "spymaster":
		teams[team]["spymaster"] = user_id
	else:
		var ops: Array = teams[team]["operatives"]
		if not ops.has(user_id):
			ops.append(user_id)


func _handle_start_game(data: Dictionary) -> void:
	if phase != "lobby":
		return

	# The host sends board data with the start_game action
	var board_data: Array = data.get("board", [])
	if board_data.size() != CARD_COUNT:
		return

	board = []
	for card_data in board_data:
		board.append({
			"word": str(card_data.get("word", "")),
			"color": str(card_data.get("color", "neutral")),
			"revealed": false,
		})

	# Count targets
	targets = {"red": 0, "blue": 0}
	for card in board:
		if card["color"] == "red":
			targets["red"] += 1
		elif card["color"] == "blue":
			targets["blue"] += 1

	scores = {"red": 0, "blue": 0}
	current_team = "red"  # Red always goes first (has more cards)
	clue_word = ""
	clue_count = 0
	guesses_remaining = 0
	winner = ""
	phase = "clue"
	is_typing_clue = false
	clue_input = ""
	clue_count_input = 1


func _handle_give_clue(data: Dictionary) -> void:
	if phase != "clue":
		return
	var user_id: String = str(data.get("user_id", ""))
	# Verify it's the current team's spymaster
	if user_id != teams[current_team]["spymaster"]:
		return

	clue_word = str(data.get("word", ""))
	clue_count = int(data.get("count", 0))
	guesses_remaining = clue_count + 1  # +1 bonus guess
	phase = "guess"
	is_typing_clue = false


func _handle_guess_card(data: Dictionary) -> void:
	if phase != "guess":
		return
	var user_id: String = str(data.get("user_id", ""))
	# Verify it's a current team operative
	var ops: Array = teams[current_team]["operatives"]
	if not ops.has(user_id):
		return

	var idx: int = int(data.get("index", -1))
	if idx < 0 or idx >= CARD_COUNT:
		return
	if board[idx]["revealed"]:
		return

	board[idx]["revealed"] = true
	var card_color: String = board[idx]["color"]

	if card_color == "red":
		scores["red"] += 1
	elif card_color == "blue":
		scores["blue"] += 1

	# Check win conditions
	if card_color == "assassin":
		# Guessing team loses
		winner = "blue" if current_team == "red" else "red"
		phase = "game_over"
		return

	if scores["red"] >= targets["red"]:
		winner = "red"
		phase = "game_over"
		return
	if scores["blue"] >= targets["blue"]:
		winner = "blue"
		phase = "game_over"
		return

	# Wrong color or neutral → end turn
	if card_color != current_team:
		_end_turn()
		return

	# Correct guess — decrement remaining
	guesses_remaining -= 1
	if guesses_remaining <= 0:
		_end_turn()


func _handle_end_guessing(data: Dictionary) -> void:
	if phase != "guess":
		return
	var user_id: String = str(data.get("user_id", ""))
	var ops: Array = teams[current_team]["operatives"]
	if not ops.has(user_id):
		return
	_end_turn()


func _handle_new_game(data: Dictionary) -> void:
	# Reset to lobby
	phase = "lobby"
	board = []
	teams = {
		"red": {"spymaster": "", "operatives": []},
		"blue": {"spymaster": "", "operatives": []},
	}
	current_team = "red"
	clue_word = ""
	clue_count = 0
	guesses_remaining = 0
	scores = {"red": 0, "blue": 0}
	winner = ""
	is_typing_clue = false
	clue_input = ""


func _end_turn() -> void:
	current_team = "blue" if current_team == "red" else "red"
	clue_word = ""
	clue_count = 0
	guesses_remaining = 0
	phase = "clue"
	is_typing_clue = false
	clue_input = ""
	clue_count_input = 1


func _remove_user_from_teams(user_id: String) -> void:
	for team_name in ["red", "blue"]:
		if teams[team_name]["spymaster"] == user_id:
			teams[team_name]["spymaster"] = ""
		var ops: Array = teams[team_name]["operatives"]
		ops.erase(user_id)


# ---------------------------------------------------------------------------
# Helper — is the local user the host? (first participant)
# ---------------------------------------------------------------------------

func _is_host() -> bool:
	if not api.has("get_participants"):
		return false
	var parts: Array = api.get_participants.call()
	if parts.size() == 0:
		return false
	var first = parts[0]
	var first_id: String = ""
	if first is Dictionary:
		first_id = str(first.get("user_id", first.get("id", "")))
	else:
		first_id = str(first)
	return first_id == _user_id()


func _user_id() -> String:
	if api.has("get_user_id"):
		return api.get_user_id.call()
	return ""


func _is_spymaster() -> bool:
	var uid: String = _user_id()
	return uid == teams[current_team]["spymaster"]


func _is_current_operative() -> bool:
	var uid: String = _user_id()
	var ops: Array = teams[current_team]["operatives"]
	return ops.has(uid)


func _user_team() -> String:
	var uid: String = _user_id()
	for team_name in ["red", "blue"]:
		if teams[team_name]["spymaster"] == uid:
			return team_name
		if teams[team_name]["operatives"].has(uid):
			return team_name
	return ""


func _is_user_spymaster_of_any_team() -> bool:
	var uid: String = _user_id()
	return uid == teams["red"]["spymaster"] or uid == teams["blue"]["spymaster"]


# ---------------------------------------------------------------------------
# Board generation (host only)
# ---------------------------------------------------------------------------

func _generate_board() -> Array:
	# Shuffle and pick 25 words
	var pool: Array = WORDS.duplicate()
	_shuffle(pool)
	var words: Array = pool.slice(0, CARD_COUNT)

	# Assign colors: 9 red, 8 blue, 7 neutral, 1 assassin
	var colors: Array = []
	for i in range(9):
		colors.append("red")
	for i in range(8):
		colors.append("blue")
	for i in range(7):
		colors.append("neutral")
	colors.append("assassin")
	_shuffle(colors)

	var result: Array = []
	for i in range(CARD_COUNT):
		result.append({
			"word": words[i],
			"color": colors[i],
			"revealed": false,
		})
	return result


func _shuffle(arr: Array) -> void:
	# Fisher-Yates shuffle using a simple LCG since we can't use
	# RandomNumberGenerator in the sandbox.
	var seed_val: int = int(Time.get_ticks_msec()) if Engine.has_singleton("Time") else 12345
	for i in range(arr.size() - 1, 0, -1):
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var j: int = seed_val % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: Dictionary) -> void:
	var etype: String = str(event.get("type", ""))

	if etype == "mouse_motion":
		mouse_x = float(event.get("position_x", 0))
		mouse_y = float(event.get("position_y", 0))
		hover_card = _hit_test_card(mouse_x, mouse_y)

	elif etype == "mouse_button":
		var pressed: bool = event.get("pressed", false)
		if not pressed:
			return
		var btn: int = int(event.get("button_index", 0))
		if btn != 1:  # Left click only
			return

		mouse_x = float(event.get("position_x", 0))
		mouse_y = float(event.get("position_y", 0))

		if phase == "lobby":
			_handle_lobby_click(mouse_x, mouse_y)
		elif phase == "clue":
			_handle_clue_click(mouse_x, mouse_y)
		elif phase == "guess":
			_handle_guess_click(mouse_x, mouse_y)
		elif phase == "game_over":
			_handle_game_over_click(mouse_x, mouse_y)

	elif etype == "key":
		var pressed: bool = event.get("pressed", false)
		if not pressed:
			return
		var keycode: int = int(event.get("keycode", 0))
		var unicode: int = int(event.get("unicode", 0))

		if is_typing_clue:
			_handle_clue_key(keycode, unicode)


# --- Lobby click handling ---

func _handle_lobby_click(mx: float, my: float) -> void:
	# Team/role buttons layout (centered):
	# Red Spymaster (120, 120, 180, 36)
	# Red Operative (120, 164, 180, 36)
	# Blue Spymaster (340, 120, 180, 36)
	# Blue Operative (340, 164, 180, 36)
	# Start Game button (240, 350, 160, 40) — host only

	if _hit_rect(mx, my, 120, 120, 180, 36):
		_send_join("red", "spymaster")
	elif _hit_rect(mx, my, 120, 164, 180, 36):
		_send_join("red", "operative")
	elif _hit_rect(mx, my, 340, 120, 180, 36):
		_send_join("blue", "spymaster")
	elif _hit_rect(mx, my, 340, 164, 180, 36):
		_send_join("blue", "operative")
	elif _hit_rect(mx, my, 240, 350, 160, 40) and _is_host():
		# Start game — host generates and sends board
		if _can_start():
			var bd: Array = _generate_board()
			api.send_action.call({
				"action": "start_game",
				"board": bd,
				"user_id": _user_id(),
			})


func _can_start() -> bool:
	# Need at least 1 player on each team
	var red_count: int = teams["red"]["operatives"].size()
	if teams["red"]["spymaster"] != "":
		red_count += 1
	var blue_count: int = teams["blue"]["operatives"].size()
	if teams["blue"]["spymaster"] != "":
		blue_count += 1
	return red_count >= 1 and blue_count >= 1


func _send_join(team: String, role: String) -> void:
	api.send_action.call({
		"action": "join_team",
		"team": team,
		"role": role,
		"user_id": _user_id(),
	})


# --- Clue phase click handling ---

func _handle_clue_click(mx: float, my: float) -> void:
	if not _is_spymaster():
		return

	# Clue text field: (160, 440, 240, 30)
	if _hit_rect(mx, my, 160, 440, 240, 30):
		is_typing_clue = true
		return

	# Count minus button: (410, 440, 30, 30)
	if _hit_rect(mx, my, 410, 440, 30, 30):
		if clue_count_input > 0:
			clue_count_input -= 1
		return

	# Count plus button: (480, 440, 30, 30)
	if _hit_rect(mx, my, 480, 440, 30, 30):
		if clue_count_input < 9:
			clue_count_input += 1
		return

	# Submit clue button: (520, 440, 100, 30)
	if _hit_rect(mx, my, 520, 440, 100, 30):
		if clue_input.length() > 0 and clue_count_input > 0:
			api.send_action.call({
				"action": "give_clue",
				"word": clue_input.to_upper(),
				"count": clue_count_input,
				"user_id": _user_id(),
			})
		return

	# Clicking elsewhere deselects text field
	is_typing_clue = false


# --- Clue keyboard input ---

func _handle_clue_key(keycode: int, unicode: int) -> void:
	# Enter (keycode 4194304 in Godot) → submit
	if keycode == 4194304:
		if clue_input.length() > 0 and clue_count_input > 0:
			api.send_action.call({
				"action": "give_clue",
				"word": clue_input.to_upper(),
				"count": clue_count_input,
				"user_id": _user_id(),
			})
			is_typing_clue = false
		return

	# Backspace (keycode 4194308)
	if keycode == 4194308:
		if clue_input.length() > 0:
			clue_input = clue_input.substr(0, clue_input.length() - 1)
		return

	# Escape
	if keycode == 4194305:
		is_typing_clue = false
		return

	# Printable character
	if unicode >= 32 and unicode < 127 and clue_input.length() < 20:
		var ch: String = char(unicode)
		# Only allow letters (no spaces — Codenames rule: one-word clue)
		if ch.to_upper() >= "A" and ch.to_upper() <= "Z":
			clue_input += ch


# --- Guess phase click handling ---

func _handle_guess_click(mx: float, my: float) -> void:
	if not _is_current_operative():
		return

	# Check "End Guessing" button: (250, 445, 140, 28)
	if _hit_rect(mx, my, 250, 445, 140, 28):
		api.send_action.call({
			"action": "end_guessing",
			"user_id": _user_id(),
		})
		return

	# Check card clicks
	var idx: int = _hit_test_card(mx, my)
	if idx >= 0 and not board[idx]["revealed"]:
		api.send_action.call({
			"action": "guess_card",
			"index": idx,
			"user_id": _user_id(),
		})


# --- Game over click handling ---

func _handle_game_over_click(mx: float, my: float) -> void:
	# "New Game" button: (250, 370, 140, 40) — host only
	if _hit_rect(mx, my, 250, 370, 140, 40) and _is_host():
		api.send_action.call({
			"action": "new_game",
			"user_id": _user_id(),
		})


# --- Hit testing ---

func _hit_test_card(mx: float, my: float) -> int:
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var cx: float = GRID_X + col * (CARD_W + CARD_GAP_X)
			var cy: float = GRID_Y + row * (CARD_H + CARD_GAP_Y)
			if mx >= cx and mx < cx + CARD_W \
					and my >= cy and my < cy + CARD_H:
				return row * GRID_COLS + col
	return -1


func _hit_rect(
	mx: float, my: float,
	rx: float, ry: float, rw: float, rh: float,
) -> bool:
	return mx >= rx and mx < rx + rw and my >= ry and my < ry + rh


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------

func _draw() -> void:
	if api.size() == 0:
		return

	# Background
	api.draw_rect.call(0, 0, CW, CH, BG_COLOR, true)

	match phase:
		"lobby":
			_draw_lobby()
		"clue", "guess":
			_draw_game()
		"game_over":
			_draw_game()
			_draw_game_over_overlay()


# --- Lobby drawing ---

func _draw_lobby() -> void:
	# Title
	api.draw_text.call(220, 30, "CODENAMES", TEXT_COLOR, 28)

	# Subtitle
	api.draw_text.call(210, 58, "Choose your team and role", TEXT_DIM, 14)

	# Red team column
	api.draw_text.call(160, 100, "RED TEAM", CARD_RED, 18)
	_draw_lobby_btn(120, 120, 180, 36, "Spymaster",
		teams["red"]["spymaster"] == _user_id(), CARD_RED)
	_draw_lobby_btn(120, 164, 180, 36, "Operative",
		teams["red"]["operatives"].has(_user_id()), CARD_RED)

	# Red team members
	var ry := 210
	if teams["red"]["spymaster"] != "":
		api.draw_text.call(130, ry, "SM: " + _short_id(teams["red"]["spymaster"]), RED_LIGHT, 12)
		ry += 18
	for op in teams["red"]["operatives"]:
		api.draw_text.call(130, ry, "OP: " + _short_id(op), RED_LIGHT, 12)
		ry += 18

	# Blue team column
	api.draw_text.call(380, 100, "BLUE TEAM", CARD_BLUE, 18)
	_draw_lobby_btn(340, 120, 180, 36, "Spymaster",
		teams["blue"]["spymaster"] == _user_id(), CARD_BLUE)
	_draw_lobby_btn(340, 164, 180, 36, "Operative",
		teams["blue"]["operatives"].has(_user_id()), CARD_BLUE)

	# Blue team members
	var by := 210
	if teams["blue"]["spymaster"] != "":
		api.draw_text.call(350, by, "SM: " + _short_id(teams["blue"]["spymaster"]), BLUE_LIGHT, 12)
		by += 18
	for op in teams["blue"]["operatives"]:
		api.draw_text.call(350, by, "OP: " + _short_id(op), BLUE_LIGHT, 12)
		by += 18

	# Divider
	api.draw_line.call(320, 90, 320, 320, TEXT_DIM, 1.0)

	# Start button (host only)
	if _is_host():
		var can: bool = _can_start()
		var btn_c: String = BTN_COLOR if can else "#455a64"
		_draw_button(240, 350, 160, 40, "START GAME", btn_c)

	# Waiting message
	if not _is_host():
		api.draw_text.call(220, 380, "Waiting for host to start...", TEXT_DIM, 14)


func _draw_lobby_btn(
	x: float, y: float, w: float, h: float,
	label: String, selected: bool, team_color: String,
) -> void:
	var bg: String = team_color if selected else "#455a64"
	api.draw_rect.call(x, y, w, h, bg, true)
	api.draw_rect.call(x, y, w, h, team_color, false)
	api.draw_text.call(x + 40, y + 24, label, TEXT_COLOR, 16)


# --- Game drawing ---

func _draw_game() -> void:
	_draw_top_bar()
	_draw_board()
	_draw_bottom_bar()


func _draw_top_bar() -> void:
	api.draw_rect.call(0, 0, CW, TOP_BAR_H, TOP_BAR_COLOR, true)

	# Red score
	api.draw_rect.call(8, 6, 80, 28, CARD_RED, true)
	api.draw_text.call(16, 27, "RED: %d/%d" % [scores["red"], targets["red"]], TEXT_COLOR, 14)

	# Blue score
	api.draw_rect.call(100, 6, 80, 28, CARD_BLUE, true)
	api.draw_text.call(108, 27, "BLU: %d/%d" % [scores["blue"], targets["blue"]], TEXT_COLOR, 14)

	# Phase indicator
	var phase_text: String = ""
	if phase == "clue":
		phase_text = "%s's spymaster giving clue" % current_team.to_upper()
	elif phase == "guess":
		phase_text = "%s guessing (%d left)" % [current_team.to_upper(), guesses_remaining]
	elif phase == "game_over":
		phase_text = "%s WINS!" % winner.to_upper()
	api.draw_text.call(240, 27, phase_text, TEXT_COLOR, 14)

	# Turn indicator dot
	var dot_color: String = CARD_RED if current_team == "red" else CARD_BLUE
	api.draw_circle.call(225, 20, 6.0, dot_color)


func _draw_board() -> void:
	var is_spy: bool = _is_user_spymaster_of_any_team()

	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			var card: Dictionary = board[idx]
			var cx: float = GRID_X + col * (CARD_W + CARD_GAP_X)
			var cy: float = GRID_Y + row * (CARD_H + CARD_GAP_Y)

			if card["revealed"]:
				# Revealed card — show color
				var bg: String = _card_color_to_hex(card["color"])
				api.draw_rect.call(cx, cy, CARD_W, CARD_H, bg, true)
				api.draw_text.call(
					cx + 6, cy + 42, card["word"], TEXT_COLOR, 13,
				)
			else:
				# Unrevealed card
				var bg: String = CARD_UNREVEALED
				if hover_card == idx and phase == "guess" and _is_current_operative():
					bg = CARD_HOVER
				api.draw_rect.call(cx, cy, CARD_W, CARD_H, bg, true)
				api.draw_text.call(
					cx + 6, cy + 42, card["word"], TEXT_COLOR, 13,
				)

				# Spymaster overlay — tint showing card's true color
				if is_spy:
					var tint = _spy_tint(card["color"])
					api.draw_rect.call(
						cx, cy, CARD_W, CARD_H, tint, true,
					)

			# Card border
			var border_color: String = TEXT_DIM
			if hover_card == idx:
				border_color = TEXT_COLOR
			api.draw_rect.call(cx, cy, CARD_W, CARD_H, border_color, false)


func _draw_bottom_bar() -> void:
	api.draw_rect.call(0, BOTTOM_BAR_Y, CW, CH - BOTTOM_BAR_Y, BOTTOM_BAR_COLOR, true)

	if phase == "clue":
		if _is_spymaster():
			# Clue input UI
			api.draw_text.call(20, 458, "Your clue:", TEXT_COLOR, 14)

			# Text field
			var tf_bg: String = "#1a1a2e" if is_typing_clue else CLUE_BG
			api.draw_rect.call(160, 440, 240, 30, tf_bg, true)
			api.draw_rect.call(160, 440, 240, 30, TEXT_DIM, false)
			var display_text: String = clue_input if clue_input.length() > 0 else "type clue..."
			var text_col: String = TEXT_COLOR if clue_input.length() > 0 else TEXT_DIM
			api.draw_text.call(168, 462, display_text, text_col, 14)

			# Cursor blink (when typing)
			if is_typing_clue:
				var cursor_x: float = 168 + clue_input.length() * 9.0
				api.draw_line.call(cursor_x, 444, cursor_x, 466, TEXT_COLOR, 1.0)

			# Count selector
			api.draw_rect.call(410, 440, 30, 30, CLUE_BG, true)
			api.draw_text.call(420, 462, "-", TEXT_COLOR, 16)
			api.draw_rect.call(445, 440, 30, 30, CLUE_BG, true)
			api.draw_text.call(454, 462, str(clue_count_input), TEXT_COLOR, 16)
			api.draw_rect.call(480, 440, 30, 30, CLUE_BG, true)
			api.draw_text.call(488, 462, "+", TEXT_COLOR, 16)

			# Submit button
			var can_submit: bool = clue_input.length() > 0 and clue_count_input > 0
			var btn_c: String = BTN_COLOR if can_submit else "#455a64"
			_draw_button(520, 440, 100, 30, "GIVE CLUE", btn_c)
		else:
			# Waiting for spymaster
			api.draw_text.call(
				200, 458,
				"Waiting for %s's spymaster..." % current_team.to_upper(),
				TEXT_DIM, 14,
			)

	elif phase == "guess":
		# Show current clue
		api.draw_text.call(
			20, 458,
			"Clue: %s %d" % [clue_word, clue_count],
			TEXT_COLOR, 16,
		)
		api.draw_text.call(
			300, 458,
			"Guesses remaining: %d" % guesses_remaining,
			TEXT_DIM, 14,
		)

		# End guessing button (for current operative)
		if _is_current_operative():
			_draw_button(250, 445, 140, 28, "END GUESSING", BTN_COLOR)

	elif phase == "game_over":
		api.draw_text.call(
			220, 458,
			"Game over! %s team wins!" % winner.to_upper(),
			TEXT_COLOR, 16,
		)


# --- Game over overlay ---

func _draw_game_over_overlay() -> void:
	# Semi-transparent overlay
	api.draw_rect.call(0, 0, CW, CH, [0.0, 0.0, 0.0, 0.6], true)

	# Winner banner
	var banner_color: String = CARD_RED if winner == "red" else CARD_BLUE
	api.draw_rect.call(140, 180, 360, 100, banner_color, true)
	api.draw_text.call(
		200, 230,
		"%s TEAM WINS!" % winner.to_upper(),
		TEXT_COLOR, 28,
	)
	api.draw_text.call(
		220, 260,
		"Red: %d  |  Blue: %d" % [scores["red"], scores["blue"]],
		TEXT_COLOR, 16,
	)

	# New game button (host only)
	if _is_host():
		_draw_button(250, 370, 140, 40, "NEW GAME", BTN_COLOR)


# --- Drawing helpers ---

func _draw_button(
	x: float, y: float, w: float, h: float,
	label: String, color: String,
) -> void:
	var bg: String = color
	if _hit_rect(mouse_x, mouse_y, x, y, w, h):
		bg = BTN_HOVER
	api.draw_rect.call(x, y, w, h, bg, true)
	# Center text approximately
	var tx: float = x + (w - label.length() * 8.0) / 2.0
	var ty: float = y + h * 0.7
	api.draw_text.call(tx, ty, label, TEXT_COLOR, 14)


func _card_color_to_hex(color: String) -> String:
	match color:
		"red":
			return CARD_RED
		"blue":
			return CARD_BLUE
		"neutral":
			return CARD_NEUTRAL
		"assassin":
			return CARD_ASSASSIN
	return CARD_UNREVEALED


func _spy_tint(color: String) -> Array:
	match color:
		"red":
			return SPY_RED
		"blue":
			return SPY_BLUE
		"neutral":
			return SPY_NEUTRAL
		"assassin":
			return SPY_ASSASSIN
	return [0.0, 0.0, 0.0, 0.0]


func _short_id(user_id: String) -> String:
	# Show first 8 chars of the user ID for display
	if user_id.length() > 8:
		return user_id.substr(0, 8) + "..."
	return user_id
