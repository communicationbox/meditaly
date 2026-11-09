extends SceneTree
## Gioca il tutorial dal menu alla fine con input sintetici, come farebbe una persona.
##   godot --path . -s tests/tutorial_flow.gd -- OUTDIR

var out := ""
var fails := 0
var main: Node


func _init() -> void:
	_run.call_deferred()


func check(n: String, ok: bool) -> void:
	print("%s %s" % ["OK  " if ok else "FAIL", n])
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])


func click(p: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var m := InputEventMouseMotion.new()
	m.position = p
	m.global_position = p
	Input.parse_input_event(m)
	root.warp_mouse(p)
	await frames(2)
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.position = p
		e.global_position = p
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)


func key(k: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)


## Aspetta che il tutorial arrivi al passo indicato.
func wait_step(t: Tutorial, i: int, limit: float) -> bool:
	var left := limit
	while left > 0.0:
		if t.index >= i:
			return true
		await create_timer(0.2).timeout
		left -= 0.2
	return false


func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await frames(5)
	# prima la schermata di caricamento: il menu si usa quando l'Italia è pronta
	var t0 := Time.get_ticks_msec()
	while not main.menu.revealed and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await create_timer(1.0).timeout
	var btn: Button = null
	for n: Node in main.menu.find_children("*", "Button", true, false):
		if (n as Button).text.begins_with("Tutorial"):
			btn = n
	check("pulsante Tutorial nel menu", btn != null)
	main.menu.name_edit.text = "Prova"  # senza nome il gioco non parte
	await shot("tut_menu")
	await click(btn.get_global_rect().get_center())
	while main.game == null:
		await process_frame
	await create_timer(1.5).timeout
	var g: Game = main.game
	Settings.player_name = ""  # il nome di prova non resta nelle impostazioni di chi gioca
	Settings.save_all()
	var t: Tutorial = g.tutorial
	check("il tutorial parte", t != null and t.index == 0)
	check("IA ferma durante il tutorial", g.sim.ai_enabled == false)
	await shot("tut_1")
	await frames(4)
	await click(t.next_btn.get_global_rect().get_center())
	check("Avanti passa al passo 2", t.index == 1)
	# passo 2: rotella
	var w := InputEventMouseButton.new()
	w.button_index = MOUSE_BUTTON_WHEEL_UP
	w.position = Vector2(900, 400)
	w.global_position = w.position
	w.pressed = true
	root.warp_mouse(w.position)
	await frames(2)
	for k in 3:
		Input.parse_input_event(w)
		await frames(2)
	check("rotella completa il passo 2", await wait_step(t, 2, 2.0))
	# passo 3: tre clic su Fante
	await frames(4)
	await shot("tut_3")
	var fante: Rect2 = g.hud.recruit_btns[Defs.FANTE].get_global_rect()
	for k in 3:
		await click(fante.get_center())
	check("tre Fanti completano il passo 3", await wait_step(t, 3, 2.0))
	# passo 4: T
	await create_timer(0.5).timeout
	await key(KEY_T)
	check("T completa il passo 4", await wait_step(t, 4, 2.0))
	await create_timer(0.6).timeout
	await shot("tut_5")
	# passo 5: clic destro sul prato
	await click(Vector2(1000, 450), MOUSE_BUTTON_RIGHT)
	check("clic destro completa il passo 5", await wait_step(t, 5, 2.0))
	await frames(4)
	await shot("tut_6")
	# passo 6: clic destro sul cerchio della minimappa
	await click(t.map_point(), MOUSE_BUTTON_RIGHT)
	check("clic destro sulla minimappa completa il passo 6", await wait_step(t, 6, 2.0))
	# passo 7: marcia
	check("l'esercito arriva", await wait_step(t, 7, 60.0))
	await create_timer(1.0).timeout
	await shot("tut_8")
	# passo 8: pulsante potere + clic sul castello
	await click(g.hud.power_btns[Defs.P_PARMIGIANO].get_global_rect().get_center())
	check("pulsante arma il potere", g.ctrl.pending.get("id", -1) == Defs.P_PARMIGIANO)
	# il passo sposta la telecamera sul castello: aspetto che si fermi, o il clic cade nel posto sbagliato
	for k in 120:
		if absf(g.ctrl.dist - g.ctrl.target_dist) < 0.5:
			break
		await frames(1)
	await frames(10)
	var sp: Vector2 = g.ctrl.cam.unproject_position(t.target.center)
	await click(sp)
	check("clic lancia il Parmigiano", await wait_step(t, 8, 2.0))
	await create_timer(2.0).timeout
	await shot("tut_9")
	# passo 9: conquista
	check("il castello viene conquistato", await wait_step(t, 9, 120.0))
	# il re ucciso ha la sua scena: durante quella l'interfaccia è nascosta
	check("c'è stata la scena del re sul gabinetto", g.ctrl.stage != null)
	await shot("tut_9b_re")
	var waited := 0.0
	while not g.ctrl.cine.is_empty() and waited < 10.0:
		await create_timer(0.2).timeout
		waited += 0.2
	check("la scena del re finisce da sola (%.1f s)" % waited, g.ctrl.cine.is_empty())
	await create_timer(0.6).timeout
	await shot("tut_10")
	check("pannello difese visibile", g.hud.def_box.is_visible_in_tree())
	var nb: Vector2 = t.next_btn.get_global_rect().get_center()
	print("Avanti a ", nb, " visibile ", t.next_btn.is_visible_in_tree())
	await click(nb)
	print("sotto il mouse: ", root.gui_get_hovered_control(), " pos ", root.get_mouse_position(), " indice ", t.index)
	check("ultimo passo", t.index == 10)
	await shot("tut_11")
	check("IA ancora ferma prima della fine", g.sim.ai_enabled == false)
	await frames(4)  # il pannello si ridimensiona col testo dell'ultimo passo
	await click(t.next_btn.get_global_rect().get_center())
	await frames(4)
	check("Inizia a giocare chiude il tutorial", not is_instance_valid(t) or t.finished)
	check("IA attiva dopo il tutorial", g.sim.ai_enabled == true)
	print("FALLITI: ", fails)
	quit(fails)
