extends SceneTree
## Nessuna scritta esce dal suo riquadro: menu, impostazioni, partita (truppe e costruzioni), pausa.
##   godot --path . -s tests/ui_overflow.gd -- OUTDIR

var fails := 0


func _init() -> void:
	_run.call_deferred()


func _text_width(c: Control, text: String) -> float:
	var f: Font = c.get_theme_font("font")
	var s: int = c.get_theme_font_size("font_size")
	var w := 0.0
	for line in text.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
	return w


func audit(n: Node, where: String, seen: Dictionary) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control:
		var c := n as Control
		var text := ""
		var wrap := false
		if c is Label:
			text = (c as Label).text
			wrap = (c as Label).autowrap_mode != TextServer.AUTOWRAP_OFF
		elif c is Button and (c as Button).text != "":
			text = (c as Button).text
		if text != "" and not wrap and c.modulate.a > 0.0:
			var r := c.get_global_rect()
			var tw := _text_width(c, text)
			var box: Control = c if c is Button else null
			var p := c.get_parent()
			while box == null and p != null:
				if p is Button or p is PanelContainer:
					box = p
				p = p.get_parent()
			if box != null:
				var left := r.position.x
				if c is Label and (c as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
					left = r.get_center().x - tw * 0.5
				elif c is Label and (c as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
					left = r.end.x - tw
				elif c is Button:
					left = r.get_center().x - tw * 0.5
				var over := left + tw - box.get_global_rect().end.x
				if over > 1.0 and not seen.has(text):
					seen[text] = true
					fails += 1
					print("FUORI [%s] «%s» sporge di %d px da %s" % [where, text, int(over), box.get_class()])
	for k in n.get_children():
		audit(k, where, seen)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await create_timer(16.0).timeout
	var seen := {}
	audit(main.menu, "menu", seen)
	main.menu._open_settings()
	await create_timer(0.5).timeout
	audit(main.menu, "impostazioni", seen)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/o_settings.png")
	for k in main.menu.get_children():
		if k is Settings.SettingsPanel:
			k.queue_free()
	await create_timer(0.2).timeout
	main.menu.play_solo.emit(1, "Prova")
	await create_timer(7.0).timeout
	var g: Game = main.game
	if g.tutorial:
		g.tutorial.queue_free()
	g.ctrl.selected_castle = 1
	await create_timer(1.0).timeout
	audit(g.hud, "partita", seen)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/o_hud.png")
	g.sim.houses[1].all_shops = true
	g.hud.show_tab(1) if g.hud.has_method("show_tab") else null
	await create_timer(0.6).timeout
	audit(g.hud, "costruzioni", seen)
	g.hud.toggle_pause()
	await create_timer(0.4).timeout
	audit(g.hud, "pausa", seen)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/o_pause.png")
	print("FALLITI: ", fails)
	quit(fails)
