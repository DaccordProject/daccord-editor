extends Control

## daccord-editor: Plugin development harness.
## Loads a Lua plugin (.lua source or .daccord-plugin bundle) and runs
## it locally with action loopback (no server required).

const DEFAULT_CANVAS_SIZE := Vector2i(640, 480)

var _runtime: ScriptedRuntime
var _loaded_path: String = ""
var _lua_source: String = ""
var _manifest: Dictionary = {}
var _assets: Dictionary = {}  # path -> PackedByteArray
var _modules: Dictionary = {}  # module_name -> lua source string

# Virtual participants for testing
var _users: Array = [
	{"user_id": "user_1", "display_name": "User 1", "role": "player"},
	{"user_id": "user_2", "display_name": "User 2", "role": "player"},
]
var _active_user_index: int = 0

# Rejoin simulation state
var _pending_rejoin: bool = false
var _rejoin_state_sync: Dictionary = {}

# UI references
@onready var _canvas_rect: TextureRect = %CanvasRect
@onready var _plugin_dropdown: OptionButton = %PluginDropdown
@onready var _load_btn: Button = %LoadBtn
@onready var _reload_btn: Button = %ReloadBtn
@onready var _user_list: ItemList = %UserList
@onready var _add_user_btn: Button = %AddUserBtn
@onready var _switch_user_btn: Button = %SwitchUserBtn
@onready var _next_user_btn: Button = %NextUserBtn
@onready var _simulate_rejoin_btn: Button = %SimulateRejoinBtn
@onready var _status_label: Label = %StatusLabel
@onready var _browse_btn: Button = %BrowseBtn
@onready var _file_dialog: FileDialog = %FileDialog


func _ready() -> void:
	_load_btn.pressed.connect(_on_load_pressed)
	_reload_btn.pressed.connect(_on_reload_pressed)
	_add_user_btn.pressed.connect(_on_add_user_pressed)
	_switch_user_btn.pressed.connect(_on_switch_user_pressed)
	_next_user_btn.pressed.connect(_on_next_user_pressed)
	_simulate_rejoin_btn.pressed.connect(_on_simulate_rejoin_pressed)
	_canvas_rect.gui_input.connect(_on_canvas_input)
	_browse_btn.pressed.connect(_on_browse_pressed)
	_file_dialog.file_selected.connect(_on_file_selected)

	_populate_plugin_dropdown()
	_refresh_user_list()
	_set_status("Ready. Load a plugin to begin.")

	# Auto-load plugin from --plugin <path> command-line argument
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--plugin" and i + 1 < args.size():
			var path: String = args[i + 1]
			_select_dropdown_path(path)
			_load_plugin(path)
			break


# ---------------------------------------------------------------------------
# Plugin loading
# ---------------------------------------------------------------------------

func _populate_plugin_dropdown() -> void:
	_plugin_dropdown.clear()
	_plugin_dropdown.add_item("-- Select a plugin --")
	_plugin_dropdown.set_item_metadata(0, "")
	var scan_dir := "res://games"
	if not DirAccess.dir_exists_absolute(scan_dir):
		scan_dir = OS.get_executable_path().get_base_dir().path_join("games")
	_scan_for_plugins(scan_dir)


func _scan_for_plugins(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan_for_plugins(full)
		elif name.ends_with(".daccord-plugin"):
			var label := name.get_basename()
			var idx := _plugin_dropdown.item_count
			_plugin_dropdown.add_item(label)
			_plugin_dropdown.set_item_metadata(idx, full)
		name = dir.get_next()
	dir.list_dir_end()


func _select_dropdown_path(path: String) -> void:
	for i in range(_plugin_dropdown.item_count):
		if _plugin_dropdown.get_item_metadata(i) == path:
			_plugin_dropdown.select(i)
			return


func _on_browse_pressed() -> void:
	_file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	# Add browsed file to dropdown and select it
	var label := path.get_file().get_basename()
	var idx := _plugin_dropdown.item_count
	_plugin_dropdown.add_item(label)
	_plugin_dropdown.set_item_metadata(idx, path)
	_plugin_dropdown.select(idx)
	_load_plugin(path)


func _on_load_pressed() -> void:
	var idx := _plugin_dropdown.selected
	if idx < 0:
		_set_status("Select a plugin first.")
		return
	var path: String = _plugin_dropdown.get_item_metadata(idx)
	if path.is_empty():
		_set_status("Select a plugin first.")
		return
	_load_plugin(path)


func _on_reload_pressed() -> void:
	if _loaded_path.is_empty():
		_set_status("Nothing loaded to reload.")
		return
	_load_plugin(_loaded_path)


func _load_plugin(path: String) -> void:
	# Stop existing runtime
	if _runtime != null:
		_runtime.stop()
		_runtime.queue_free()
		_runtime = null
		_canvas_rect.texture = null

	_lua_source = ""
	_manifest = {}
	_assets = {}
	_modules = {}

	if path.ends_with(".daccord-plugin"):
		if not _load_bundle(path):
			return
	elif path.ends_with(".lua"):
		if not _load_lua(path):
			return
	else:
		_set_status("Unsupported file type. Use .daccord-plugin or .lua")
		return

	_loaded_path = path
	_start_runtime()


func _load_bundle(path: String) -> bool:
	var reader := ZIPReader.new()
	var err := reader.open(path)
	if err != OK:
		_set_status("Failed to open bundle: %s" % error_string(err))
		return false

	# Read plugin.json
	if reader.file_exists("plugin.json"):
		var json_bytes := reader.read_file("plugin.json")
		var json := JSON.new()
		if json.parse(json_bytes.get_string_from_utf8()) == OK:
			_manifest = json.data
		else:
			_set_status("Failed to parse plugin.json")
			reader.close()
			return false
	else:
		_manifest = {}

	# Load the Lua source from the bundle
	var entry: String = str(_manifest.get("entry", "src/main.lua"))
	if reader.file_exists(entry):
		_lua_source = reader.read_file(entry).get_string_from_utf8()
	else:
		_set_status("Bundle missing %s" % entry)
		reader.close()
		return false

	# Extract assets/ files and sibling .lua modules from the bundle
	for file_path in reader.get_files():
		if file_path.begins_with("assets/"):
			_assets[file_path] = reader.read_file(file_path)
		elif file_path.ends_with(".lua") and file_path != entry:
			var module_name: String = file_path.get_file().get_basename()
			_modules[module_name] = reader.read_file(file_path).get_string_from_utf8()

	reader.close()
	return true


func _load_lua(path: String) -> bool:
	var src_file := FileAccess.open(path, FileAccess.READ)
	if src_file == null:
		_set_status("Failed to open: %s" % error_string(FileAccess.get_open_error()))
		return false
	_lua_source = src_file.get_as_text()
	src_file.close()

	_manifest = {
		"id": path.get_file().get_basename(),
		"format": "lua",
		"canvas_size": [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y],
	}

	# Load assets from assets/ directory next to or above the source file
	# Structure: plugin_root/src/main.lua + plugin_root/assets/
	var base_dir: String = path.get_base_dir()
	var assets_dir: String = base_dir.path_join("assets")
	if not DirAccess.dir_exists_absolute(assets_dir):
		assets_dir = base_dir.get_base_dir().path_join("assets")
	_load_assets_from_dir(assets_dir, "assets/")

	# Load sibling .lua files as modules for require()
	_load_lua_modules(base_dir, path.get_file())

	return true


func _load_lua_modules(src_dir: String, entry_filename: String) -> void:
	var dir := DirAccess.open(src_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".lua") and name != entry_filename:
			var full := src_dir.path_join(name)
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null:
				var module_name: String = name.get_basename()
				_modules[module_name] = file.get_as_text()
				file.close()
		name = dir.get_next()
	dir.list_dir_end()


func _load_assets_from_dir(dir_path: String, prefix: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_load_assets_from_dir(full, prefix + name + "/")
		else:
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null:
				_assets[prefix + name] = file.get_buffer(file.get_length())
				file.close()
		name = dir.get_next()
	dir.list_dir_end()


# ---------------------------------------------------------------------------
# Runtime management
# ---------------------------------------------------------------------------

func _start_runtime() -> void:
	_runtime = ScriptedRuntime.new()
	add_child(_runtime)

	# Set up user context
	_apply_user_context()

	# Pass bundled assets and module sources
	_runtime._assets = _assets
	_runtime._modules = _modules

	# Wire up action loopback
	var mock := MockClientPlugins.new()
	mock._editor = self
	_runtime._client_plugins = mock

	_runtime.runtime_error.connect(_on_runtime_error)

	var ok := _runtime.start(_lua_source, _manifest)
	if not ok:
		_set_status("Runtime failed to start.")
		return

	# Connect viewport texture to display
	var tex := _runtime.get_viewport_texture()
	if tex != null:
		_canvas_rect.texture = tex

	var plugin_name: String = _manifest.get("name", _manifest.get("id", "unknown"))
	_set_status("Running: %s" % plugin_name)
	print("[Plugin] Loaded: %s" % plugin_name)


func _apply_user_context() -> void:
	if _runtime == null:
		return
	var user: Dictionary = _users[_active_user_index]
	_runtime.local_user_id = user["user_id"]
	_runtime.local_role = user.get("role", "player")
	_runtime.participants = _users.duplicate(true)


func _on_runtime_error(message: String) -> void:
	_set_status("Runtime error")
	push_error("[Plugin] %s" % message)


# ---------------------------------------------------------------------------
# Action loopback (mock server)
# ---------------------------------------------------------------------------

class MockClientPlugins:
	var _editor  # Editor reference
	func send_action(_plugin_id: String, data: Dictionary) -> void:
		_editor._on_action_sent(data)


func _on_action_sent(data: Dictionary) -> void:
	# During rejoin simulation, intercept the host's state_sync response
	# instead of looping it back.
	if _pending_rejoin:
		var action: String = str(data.get("action", ""))
		if action == "state_sync":
			_rejoin_state_sync = data.duplicate(true)
			_pending_rejoin = false
			_do_simulated_rejoin()
			return

	# Loopback: deliver the action back to the plugin as a server event
	if _runtime != null:
		_runtime.on_plugin_event("action", data)


# ---------------------------------------------------------------------------
# Input forwarding
# ---------------------------------------------------------------------------

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("[Input] gui_input MouseButton pressed=%s" % str(event.pressed))
	if _runtime == null:
		print("[Input] _runtime is null, dropping event")
		return

	# Remap coordinates to canvas space
	var canvas_size := Vector2(
		_manifest.get("canvas_size", [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y])[0],
		_manifest.get("canvas_size", [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y])[1],
	)
	var rect_size: Vector2 = _canvas_rect.size

	if event is InputEventMouse:
		# Account for aspect-ratio-preserving stretch (KEEP_ASPECT_CENTERED)
		var scale_factor: float = minf(
			rect_size.x / canvas_size.x if canvas_size.x > 0 else 1.0,
			rect_size.y / canvas_size.y if canvas_size.y > 0 else 1.0,
		)
		var display_size := canvas_size * scale_factor
		var offset := (rect_size - display_size) * 0.5

		event = event.duplicate()
		event.position = (event.position - offset) / scale_factor
		if event is InputEventMouseMotion:
			event.relative = event.relative / scale_factor

	if not _canvas_rect.has_focus():
		_canvas_rect.grab_focus()
	_runtime.forward_input(event)


# ---------------------------------------------------------------------------
# Rejoin simulation
# ---------------------------------------------------------------------------

func _on_simulate_rejoin_pressed() -> void:
	if _runtime == null:
		_set_status("No runtime to simulate rejoin on.")
		return
	if _lua_source.is_empty():
		_set_status("No plugin loaded.")
		return

	_pending_rejoin = true
	_rejoin_state_sync = {}

	# Ask the host runtime to serialize its current game state.
	# The host's handle_state_request produces a state_sync action,
	# which _on_action_sent intercepts (see _pending_rejoin check).
	# Temporarily assume the host identity so Lua is_host() passes.
	var user: Dictionary = _users[_active_user_index]
	var prev_user_id: String = _runtime.local_user_id
	_runtime.local_user_id = _users[0]["user_id"]
	_runtime.on_plugin_event("action", {
		"action": "state_request",
		"user_id": user["user_id"],
	})
	_runtime.local_user_id = prev_user_id

	# If the host didn't respond (game still in lobby, or not host),
	# do a plain rejoin with no state sync.
	if _pending_rejoin:
		_pending_rejoin = false
		_do_simulated_rejoin()


func _do_simulated_rejoin() -> void:
	# Tear down existing runtime
	if _runtime != null:
		_runtime.stop()
		_runtime.queue_free()
		_runtime = null
		_canvas_rect.texture = null

	# Switch to the other player (simulate a non-host rejoining)
	if _users.size() > 1:
		_active_user_index = (_active_user_index + 1) % _users.size()

	# Start a fresh runtime — Lua _ready() runs, phase = lobby
	_start_runtime()

	if not _rejoin_state_sync.is_empty():
		# Wait one frame so _ready() has completed
		await get_tree().process_frame
		# Temporarily assume a non-host identity so Lua's
		# handle_state_sync doesn't skip the incoming snapshot.
		var prev_uid: String = _runtime.local_user_id
		if _active_user_index == 0 and _users.size() > 1:
			_runtime.local_user_id = _users[1]["user_id"]
		_runtime.on_plugin_event("action", _rejoin_state_sync)
		_runtime.local_user_id = prev_uid
		_set_status("Rejoin simulated — state_sync delivered to %s" % _users[_active_user_index]["display_name"])
	else:
		_set_status("Rejoin simulated — no state_sync (host had no state to share)")

	_refresh_user_list()


# ---------------------------------------------------------------------------
# User simulation
# ---------------------------------------------------------------------------

func _refresh_user_list() -> void:
	_user_list.clear()
	for i in range(_users.size()):
		var u: Dictionary = _users[i]
		var label: String = "%s (%s)" % [u["display_name"], u["user_id"]]
		if i == _active_user_index:
			label = "> " + label
		if i == 0:
			label += " [host]"
		_user_list.add_item(label)


func _on_add_user_pressed() -> void:
	var idx: int = _users.size() + 1
	_users.append({
		"user_id": "user_%d" % idx,
		"display_name": "User %d" % idx,
		"role": "player",
	})
	_refresh_user_list()
	_apply_user_context()


func _on_switch_user_pressed() -> void:
	var selected := _user_list.get_selected_items()
	if selected.is_empty():
		_set_status("Select a user in the list first.")
		return
	_active_user_index = selected[0]
	_refresh_user_list()
	_apply_user_context()
	var user: Dictionary = _users[_active_user_index]
	_set_status("Switched to: %s" % user["display_name"])


func _on_next_user_pressed() -> void:
	_active_user_index = (_active_user_index + 1) % _users.size()
	_refresh_user_list()
	_apply_user_context()
	var user: Dictionary = _users[_active_user_index]
	_set_status("Switched to: %s" % user["display_name"])


# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _set_status(msg: String) -> void:
	_status_label.text = msg
