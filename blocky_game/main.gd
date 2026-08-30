extends Node

const BlockyGame = preload("./blocky_game.gd")
const BlockyGameScene = preload("./blocky_game.tscn")
const MainMenu = preload("./main_menu.gd")
const UPNPHelper = preload("./upnp_helper.gd")

@onready var _main_menu : MainMenu = $MainMenu

var _game : BlockyGame
var _upnp_helper : UPNPHelper


func _ready() -> void:
	DDD.visible = false
	_show_main_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_menu"):
		DDD.visible = not DDD.visible


func _on_main_menu_singleplayer_requested():
	_start_game(BlockyGame.NETWORK_MODE_SINGLEPLAYER)


func _on_main_menu_connect_to_server_requested(ip: String, port: int):
	_start_game(BlockyGame.NETWORK_MODE_CLIENT, ip, port)
	get_window().title = "Client"


func _on_main_menu_host_server_requested(port: int):
	if _upnp_helper != null and not _upnp_helper.is_setup():
		_upnp_helper.setup(port, PackedStringArray(["UDP"]), "VoxelBlockyGame", 20 * 60)
	
	_start_game(BlockyGame.NETWORK_MODE_HOST, "", port)
	get_window().title = "Server"


func _on_main_menu_upnp_toggled(pressed: bool):
	if pressed:
		if _upnp_helper == null:
			_upnp_helper = UPNPHelper.new()
			add_child(_upnp_helper)
	else:
		if _upnp_helper != null:
			_upnp_helper.queue_free()
			_upnp_helper = null


func _start_game(network_mode: int, ip := "", port := -1) -> void:
	if _game != null:
		return

	_game = BlockyGameScene.instantiate()
	_game.set_network_mode(network_mode)
	_game.set_ip(ip)
	_game.set_port(port)
	_game.quit_requested.connect(_on_game_quit_requested)

	_main_menu.hide()
	add_child(_game)


func _on_game_quit_requested() -> void:
	_return_to_main_menu.call_deferred()


func _return_to_main_menu() -> void:
	if _game == null:
		return

	_game.shutdown()
	remove_child(_game)
	_game.queue_free()
	_game = null

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_show_main_menu()


func _show_main_menu() -> void:
	_main_menu.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_window().title = str(ProjectSettings.get_setting("application/config/name"))
