extends SceneTree

var game
func _initialize(): call_deferred("run")

func snapshot(name: String):
	game.hud.refresh(); game.camera.position = game.player_pos() + Vector2(0,-40)
	game.view.queue_redraw()
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://builds/" + name + ".png")

func run():
	game = load("res://main.tscn").instantiate(); game.world.save_directory = "user://preview-mini"
	root.add_child(game); await process_frame; await process_frame
	game.set_process(false); game.world.new_world(); game.hud.close_panel()
	game.world.paused = true; game.set_pos(Vector2(470,430))
	await snapshot("mini-camp-preview")
	game.world.state.zone = "town"; game.set_pos(Vector2(560,485)); game.aim = Vector2.RIGHT
	await snapshot("mini-town-preview")
	game.set_pos(Vector2(5050,2730))
	await snapshot("mini-world-preview")
	game.world.state.zone = "camp"; game.set_pos(Vector2(470,430))
	for id in ["m4","shotgun","mosin","mp5"]: game.world.add_item(id,1,"player")
	for id in ["rifle_suppressor","scope4x","drum_mag","angled_grip","tactical_stock"]: game.world.add_item(id,1,"player")
	var m4 = game.world.player_weapon("m4")
	for part in game.world.owned("player"):
		if part.def in ["rifle_suppressor","scope4x","drum_mag","angled_grip","tactical_stock"]: game.world.attach(m4,part.id)
	game.hud.selected_gun = game.world.player_weapon("m4"); game.hud.open_panel("parts")
	await snapshot("mini-weapons-preview")
	game.hud.open_panel("loot"); game.hud.container_id = "armory"; game.hud.open_panel("loot")
	await snapshot("mini-armory-preview")
	game.hud.open_panel("map")
	await snapshot("mini-map-preview")
	game.queue_free(); await create_timer(0.2).timeout
	print("MINI SCREENSHOTS: 6 captured"); quit()
