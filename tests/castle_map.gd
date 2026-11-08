extends SceneTree
## Mappa ASCII di un castello: # struttura percorribile no, G porta, . terreno, ~ acqua, o ostacolo
##   godot --headless --path . -s tests/castle_map.gd -- Palermo
func _init() -> void:
	var name := OS.get_cmdline_user_args()[0]
	var world := VoxelWorld.new()
	var castles := WorldGen.generate(world, Game.SEED)
	for c: Dictionary in castles:
		if c.name != name:
			continue
		var cen: Vector3 = Vector3(c.x, 0, c.z) if not c.has("center") else c.center
		print(c.keys())
		print("centro ", cen, " dir ", c.get("dir"))
		var cx := int(cen.x)
		var cz := int(cen.z)
		var shift := OS.get_environment("MAP_SHIFT")
		if shift != "":
			cx += int(shift.split(",")[0])
			cz += int(shift.split(",")[1])
		var base := int(c.base)
		print("base ", base)
		for z in range(cz - 22, cz + 23):
			var line := ""
			for x in range(cx - 22, cx + 23):
				var y := world.walk_y(x + 0.5, base + 1, z + 0.5, true)
				var y2 := world.walk_y(x + 0.5, base + 1, z + 0.5, false)
				var ch := "."
				if y < -999.0:
					ch = "#"
				elif y2 < -999.0:
					ch = "G"
				elif y <= Defs.SEA + 0.5:
					ch = "~"
				elif y > base + 3:
					ch = "^"
				if x == cx and z == cz:
					ch = "C"
				for m: String in OS.get_cmdline_user_args().slice(1):
					var xy := m.split(",")
					if int(xy[0]) == x and int(xy[1]) == z:
						ch = "X"
				line += ch
			print("%4d " % z, line)
	quit()
