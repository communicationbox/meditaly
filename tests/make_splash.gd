extends SceneTree
## Genera assets/ui/splash.png: il paesaggio del menu, senza interfaccia.
## È lo sfondo della schermata di caricamento e dell'avvio.
##   godot --path . -s tests/make_splash.gd

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	while not main.menu.revealed:
		await create_timer(0.2).timeout
	await create_timer(3.0).timeout
	for n in main.menu.get_children():
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var err: int = root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://assets/ui/splash.png"))
	print("splash salvato, errore=", err)
	quit()
