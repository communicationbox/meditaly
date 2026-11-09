extends Node
## Punto di ingresso: menu oppure avvio diretto da riga di comando.
##   -- --server [--port N]        server dedicato (anche --headless)
##   -- --connect IP [--house N]   entra direttamente in una partita
##   -- --solo [--house N]         partita in solitaria immediata
##   -- --tutorial [--house N]     partita guidata
##   -- --demo                     dimostrazione: assedio visto dall'alto + screenshot
##   -- --scena-re                 solo la scena del re sul gabinetto, a ripetizione

var game: Game
var menu: Control


func _ready() -> void:
	# font di tutta l'interfaccia (anche dove un controllo non ne sceglie uno)
	ThemeDB.fallback_font = UiStyle.body_font()
	ThemeDB.fallback_font_size = 15
	Settings.load_all()
	# tooltip nello stile del gioco (prima erano i riquadri grigi di sistema)
	var th := Theme.new()
	th.default_font = UiStyle.body_font()  # anche i controlli che non scelgono un font restano medievali
	th.set_stylebox("panel", "TooltipPanel", UiStyle.panel_box(UiStyle.WALNUT, UiStyle.GOLD_DIM, 10))
	th.set_color("font_color", "TooltipLabel", UiStyle.INK)
	th.set_font("font", "TooltipLabel", UiStyle.body_font())
	th.set_font_size("font_size", "TooltipLabel", 14)
	get_tree().root.theme = th
	add_child.call_deferred(TipLayer.new())
	var a := OS.get_cmdline_user_args()
	var pref := _opt(a, "--house", "1").to_int()
	var pname := _opt(a, "--name", "")
	if "--server" in a or "--test-server" in a:
		_start_game().start_dedicated(_opt(a, "--port", str(Defs.PORT)).to_int(), a)
	elif "--connect" in a:
		_start_game().start_client(_opt(a, "--connect", "127.0.0.1"), _opt(a, "--port", str(Defs.PORT)).to_int(), pref, pname, a)
	elif "--solo" in a or "--demo" in a or "--tutorial" in a or "--scena-re" in a:
		_start_game().start_solo(pref, pname, a)
	else:
		_show_menu()


func _opt(a: PackedStringArray, key: String, def: String) -> String:
	var i := a.find(key)
	return a[i + 1] if i >= 0 and i + 1 < a.size() else def


func _start_game() -> Game:
	if menu:
		menu.queue_free()
		menu = null
	game = Game.new()
	game.name = "Game"
	add_child(game)
	return game


func _show_menu() -> void:
	menu = (load("res://scripts/menu.gd") as GDScript).new()
	add_child(menu)
	menu.tutorial.connect(func(house: int, pname: String): _start_game().start_solo(house, pname, PackedStringArray(["--tutorial"])))
	menu.play_solo.connect(func(house: int, pname: String): _start_game().start_solo(house, pname, PackedStringArray()))
	menu.host.connect(func(house: int, pname: String, port: int): _start_game().start_host(port, house, pname))
	menu.join.connect(func(ip: String, house: int, pname: String, port: int): _start_game().start_client(ip, port, house, pname, PackedStringArray()))
	menu.continue_game.connect(func():
		if not _start_game().start_loaded():
			back_to_menu())


func back_to_menu() -> void:
	if game:
		game.queue_free()
		game = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_show_menu()
