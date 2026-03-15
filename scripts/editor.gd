extends Control

## daccord-editor: Plugin development harness.
## Loads a scripted plugin (.sgd source, .elf binary, or .daccord-plugin
## bundle) and runs it locally with action loopback (no server required).

const DEFAULT_CANVAS_SIZE := Vector2i(640, 480)

var _runtime: ScriptedRuntime
var _loaded_path: String = ""
var _elf_data: PackedByteArray
var _sgd_source: String = ""
var _manifest: Dictionary = {}

# Virtual participants for testing
var _users: Array = [
	{"user_id": "user_1", "display_name": "User 1", "role": "player"},
	{"user_id": "user_2", "display_name": "User 2", "role": "player"},
]
var _active_user_index: int = 0

# UI references
@onready var _canvas_rect: TextureRect = %CanvasRect
@onready var _path_field: LineEdit = %PathField
@onready var _load_btn: Button = %LoadBtn
@onready var _reload_btn: Button = %ReloadBtn
@onready var _user_list: ItemList = %UserList
@onready var _add_user_btn: Button = %AddUserBtn
@onready var _switch_user_btn: Button = %SwitchUserBtn
@onready var _action_log: RichTextLabel = %ActionLog
@onready var _status_label: Label = %StatusLabel
@onready var _browse_btn: Button = %BrowseBtn
@onready var _file_dialog: FileDialog = %FileDialog


func _ready() -> void:
	_load_btn.pressed.connect(_on_load_pressed)
	_reload_btn.pressed.connect(_on_reload_pressed)
	_add_user_btn.pressed.connect(_on_add_user_pressed)
	_switch_user_btn.pressed.connect(_on_switch_user_pressed)
	_canvas_rect.gui_input.connect(_on_canvas_input)
	_browse_btn.pressed.connect(_on_browse_pressed)
	_file_dialog.file_selected.connect(_on_file_selected)

	_refresh_user_list()
	_set_status("Ready. Load a plugin to begin.")


# ---------------------------------------------------------------------------
# Plugin loading
# ---------------------------------------------------------------------------

func _on_browse_pressed() -> void:
	_file_dialog.popup_centered()


func _on_file_selected(path: String) -> void:
	_path_field.text = path
	_load_plugin(path)


func _on_load_pressed() -> void:
	var path: String = _path_field.text.strip_edges()
	if path.is_empty():
		_set_status("Enter a file path first.")
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

	_elf_data = PackedByteArray()
	_sgd_source = ""
	_manifest = {}

	if path.ends_with(".daccord-plugin"):
		if not _load_bundle(path):
			return
	elif path.ends_with(".sgd"):
		if not _load_sgd(path):
			return
	elif path.ends_with(".elf"):
		if not _load_elf(path):
			return
	else:
		_set_status("Unsupported file type. Use .daccord-plugin, .sgd, or .elf")
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

	# Determine format: SGD (source) or ELF (compiled)
	var fmt: String = str(_manifest.get("format", ""))
	var entry: String = str(_manifest.get("entry", ""))

	if fmt == "sgd" or (entry.ends_with(".sgd") and reader.file_exists(entry)):
		# SGD bundle — load source + gdscript.elf runtime
		var sgd_path: String = entry if entry != "" else "src/main.sgd"
		if reader.file_exists(sgd_path):
			_sgd_source = reader.read_file(sgd_path).get_string_from_utf8()
		else:
			_set_status("Bundle missing %s" % sgd_path)
			reader.close()
			return false
		# Load gdscript.elf runtime from addons
		var elf_path := "res://addons/godot_sandbox/gdscript.elf"
		var elf_file := FileAccess.open(elf_path, FileAccess.READ)
		if elf_file == null:
			_set_status("Missing gdscript.elf runtime in addons/godot_sandbox/")
			reader.close()
			return false
		_elf_data = elf_file.get_buffer(elf_file.get_length())
		elf_file.close()
	elif reader.file_exists("bin/plugin.elf"):
		# Legacy ELF bundle
		_elf_data = reader.read_file("bin/plugin.elf")
	else:
		_set_status("Bundle missing entry file (src/main.sgd or bin/plugin.elf)")
		reader.close()
		return false

	reader.close()
	return true


func _load_elf(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Failed to open: %s" % error_string(FileAccess.get_open_error()))
		return false
	_elf_data = file.get_buffer(file.get_length())
	file.close()
	_manifest = {
		"id": path.get_file().get_basename(),
		"canvas_size": [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y],
	}
	return true


func _load_sgd(path: String) -> bool:
	var src_file := FileAccess.open(path, FileAccess.READ)
	if src_file == null:
		_set_status("Failed to open: %s" % error_string(FileAccess.get_open_error()))
		return false
	_sgd_source = src_file.get_as_text()
	src_file.close()

	# Load gdscript.elf runtime from addons
	var elf_path := "res://addons/godot_sandbox/gdscript.elf"
	var elf_file := FileAccess.open(elf_path, FileAccess.READ)
	if elf_file == null:
		_set_status("Missing gdscript.elf runtime in addons/godot_sandbox/")
		return false
	_elf_data = elf_file.get_buffer(elf_file.get_length())
	elf_file.close()

	_manifest = {
		"id": path.get_file().get_basename(),
		"format": "sgd",
		"canvas_size": [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y],
	}
	return true


# ---------------------------------------------------------------------------
# Runtime management
# ---------------------------------------------------------------------------

func _start_runtime() -> void:
	_runtime = ScriptedRuntime.new()
	add_child(_runtime)

	# Set up user context
	_apply_user_context()

	# Wire up action loopback
	var mock := MockClientPlugins.new()
	mock._editor = self
	_runtime._client_plugins = mock

	_runtime.runtime_error.connect(_on_runtime_error)

	var ok := _runtime.start(_elf_data, _manifest, _sgd_source)
	if not ok:
		_set_status("Runtime failed to start.")
		return

	# Connect viewport texture to display
	var tex := _runtime.get_viewport_texture()
	if tex != null:
		_canvas_rect.texture = tex

	var plugin_name: String = _manifest.get("name", _manifest.get("id", "unknown"))
	_set_status("Running: %s" % plugin_name)
	_log_action("--- Plugin loaded: %s ---" % plugin_name)


func _apply_user_context() -> void:
	if _runtime == null:
		return
	var user: Dictionary = _users[_active_user_index]
	_runtime.local_user_id = user["user_id"]
	_runtime.local_role = user.get("role", "player")
	_runtime.participants = _users.duplicate(true)


func _on_runtime_error(message: String) -> void:
	_set_status("Runtime error: %s" % message)
	_log_action("[ERROR] %s" % message)


# ---------------------------------------------------------------------------
# Action loopback (mock server)
# ---------------------------------------------------------------------------

class MockClientPlugins:
	var _editor  # Editor reference
	func send_action(_plugin_id: String, data: Dictionary) -> void:
		_editor._on_action_sent(data)


func _on_action_sent(data: Dictionary) -> void:
	var action_name: String = str(data.get("action", "???"))
	_log_action(">> %s: %s" % [action_name, str(data)])

	# Loopback: deliver the action back to the plugin as a server event
	if _runtime != null:
		_runtime.on_plugin_event("action", data)


# ---------------------------------------------------------------------------
# Input forwarding
# ---------------------------------------------------------------------------

func _on_canvas_input(event: InputEvent) -> void:
	if _runtime == null:
		return

	# Remap coordinates to canvas space
	var canvas_size := Vector2(
		_manifest.get("canvas_size", [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y])[0],
		_manifest.get("canvas_size", [DEFAULT_CANVAS_SIZE.x, DEFAULT_CANVAS_SIZE.y])[1],
	)
	var rect_size: Vector2 = _canvas_rect.size

	if event is InputEventMouse:
		var scale_x: float = canvas_size.x / rect_size.x if rect_size.x > 0 else 1.0
		var scale_y: float = canvas_size.y / rect_size.y if rect_size.y > 0 else 1.0
		event = event.duplicate()
		event.position = Vector2(
			event.position.x * scale_x,
			event.position.y * scale_y,
		)
		if event is InputEventMouseMotion:
			event.relative = Vector2(
				event.relative.x * scale_x,
				event.relative.y * scale_y,
			)

	_runtime.forward_input(event)


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
	_log_action("--- Switched to %s (%s) ---" % [user["display_name"], user["user_id"]])


# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------

func _set_status(msg: String) -> void:
	_status_label.text = msg


func _log_action(msg: String) -> void:
	_action_log.append_text(msg + "\n")
