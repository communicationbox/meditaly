extends SceneTree
## Sala d'attesa di chi ospita: tempo fermo, si parte solo quando sono tutti pronti.
##   godot --headless --path . -s tests/lobby.gd

var fails := 0

func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1

func _init() -> void:
	_run.call_deferred()

func frames(n: int) -> void:
	for k in n:
		await physics_frame

func _run() -> void:
	Game.force_view = true
	root.size = Vector2i(1600, 900)
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	var g := Game.new()
	g.name = "Game"
	main.add_child(g)
	g.start_host(27111, 1, "Ospite")
	await frames(3)
	var sim: Sim = g.sim
	check("ospitando si entra in sala d'attesa", g.lobby and sim.lobby)
	check("la scheda della sala d'attesa si vede", g.hud.lobby_panel != null and g.hud.lobby_panel.visible)
	var t0 := sim.time
	await frames(30)
	check("in sala d'attesa il tempo non scorre (%.2f)" % sim.time, sim.time == t0)
	check("da soli si può avviare", g.lobby_all_ready() and not g.hud._lobby_btn.disabled)
	# arriva un amico (finto: nessuna rete vera)
	g._assign(7, 4, "Amico")
	g.lobby_ready[7] = false
	g._lobby_changed()
	check("l'amico compare in elenco", g.lobby_list.size() == 2)
	check("amico non pronto: Avvia bloccato", not g.lobby_all_ready() and g.hud._lobby_btn.disabled)
	var gold0: float = sim.houses[1].gold
	g._exec_cmd(1, "recruit", [1, Defs.FANTE])
	check("in sala d'attesa non si spende", float(sim.houses[1].gold) == gold0)
	g.lobby_start()
	check("Avvia non parte se qualcuno non è pronto", g.lobby)
	g.lobby_ready[7] = true
	g._lobby_changed()
	check("tutti pronti: Avvia si accende", g.lobby_all_ready() and not g.hud._lobby_btn.disabled)
	# casata: si cambia solo con una libera
	g.lobby_pick_house(4)
	check("la casata dell'amico non si prende", g.my_house == 1)
	g.lobby_pick_house(7)
	check("si passa a una casata libera (%d)" % g.my_house, g.my_house == 7 and not sim.houses[7].ai and sim.houses[1].ai)
	g.lobby_pick_house(1)
	# chat
	g._chat(7, "ciao a tutti")
	await frames(2)
	var said := false
	for l: Node in g.hud.find_children("*", "Label", true, false):
		if (l as Label).text.contains("Amico: ciao a tutti"):
			said = true
	check("la chat arriva con il nome di chi scrive", said)
	# salvataggio in rete: chi ospita salva, con i nomi di chi gioca
	SaveGame.NET_PATH = "user://test_rete.sav"
	check("chi ospita salva la partita in rete", SaveGame.save(g))
	var sm := SaveGame.summary(true)
	check("nel salvataggio ci sono i giocatori (%s)" % str(sm.get("players", {})), (sm.get("players", {}) as Dictionary).get("Amico", -1) == 4 and (sm.get("players", {}) as Dictionary).get("Ospite", -1) == 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.NET_PATH))
	# chi esce e rientra con lo stesso nome ritrova la sua casata
	g._on_peer_left(7)
	check("uscito: la sua casata passa all'IA", sim.houses[4].ai)
	var back := g._assign(9, 2, "Amico")
	g.lobby_ready[9] = true
	g._lobby_changed()
	check("rientrato con lo stesso nome: di nuovo i Fiorentini (%d)" % back, back == 4)
	g.lobby_start()
	await frames(30)
	check("avviata: niente più sala d'attesa", not g.lobby and not sim.lobby and g.hud.lobby_panel == null)
	check("avviata: il tempo scorre (%.2f)" % sim.time, sim.time > t0)
	print("FALLITI: %d" % fails)
	quit(1 if fails > 0 else 0)
