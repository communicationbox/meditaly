extends SceneTree
## Partita in rete salvata e ripresa: chi ospita la riapre in sala d'attesa, chi rientra con il suo
## nome ritrova la sua casata.
##   godot --headless --path . -s tests/net_resume.gd

var fails := 0

func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveGame.NET_PATH = "user://test_ripresa.sav"
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var g := Game.new()
	main.add_child(g)
	g.start_host(27113, 1, "Ospite")
	await process_frame
	g._assign(7, 4, "Amico")
	g.lobby_ready[7] = true
	g._lobby_changed()
	g.lobby_start()
	for k in 40:
		await physics_frame
	g.sim.castles[9].owner = 4  # qualcosa che si deve ritrovare
	var t_saved: float = g.sim.time
	check("salvata", SaveGame.save(g))
	g.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	g.queue_free()
	await process_frame
	await process_frame
	var g2 := Game.new()
	main.add_child(g2)
	check("ripresa come chi ospita", g2.start_host_loaded(27114))
	await process_frame
	check("si riparte dalla sala d'attesa", g2.lobby and g2.sim.lobby)
	check("stessa casata per chi ospita (%d)" % g2.my_house, g2.my_house == 1)
	check("stesso tempo di gioco", is_equal_approx(g2.sim.time, t_saved))
	check("Bari è ancora dei Fiorentini", int(g2.sim.castles[9].owner) == 4)
	check("i Fiorentini aspettano l'Amico, intanto IA", g2.sim.houses[4].ai and int(g2.left_names.get("Amico", -1)) == 4)
	check("l'Amico rientra e li ritrova", g2._assign(5, -1, "Amico") == 4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.NET_PATH))
	g2.multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	print("FALLITI: %d" % fails)
	quit(1 if fails > 0 else 0)
