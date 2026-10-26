extends SceneTree
var game
func _initialize(): call_deferred("run")
func shot(name:String):
	game.hud.refresh(); game.camera.position=game.player_pos()+Vector2(0,-40); game.view.queue_redraw()
	await process_frame; RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://builds/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate(); game.world.save_directory="user://preview-v04"; root.add_child(game)
	await process_frame; await process_frame; game.set_process(false); game.hud.reset_control_layout(false)
	game.world.new_world(20261026); game.hud.close_panel(); game.world.state.zone="town"; game.set_pos(Vector2(570,490))
	game.world.state.hp=73; game.world.state.hunger=62; game.world.state.thirst=48; game.world.state.stamina=81
	await shot("v04-gameplay")
	game.hud.open_panel("bag"); await shot("v04-inventory"); game.hud.close_panel()
	game.hud.start_layout_editor(); await shot("v04-controls"); game.hud.close_panel()
	game.set_world_zoom(0.65); await shot("v04-zoom-out"); game.set_world_zoom(1.8); await shot("v04-zoom-in"); game.set_world_zoom(1)
	game.hud.open_panel("map"); await shot("v04-map"); game.hud.close_panel()
	var plants=game.world.map.plants_at(Vector2(4000,4000),6000,"town")
	var apple=plants.filter(func(p):return p.kind=="apple")[0]; game.set_pos(apple.pos+Vector2(0,30)); game.interact(); game.action.remaining=1.5
	await shot("v04-harvest"); game.complete_action(); game.hud.open_panel("bag"); await shot("v04-fruit")
	game.hud.close_panel(); game.world.state.zone="camp"; game.set_pos(Vector2(820,760)); game.world.enemies.clear(); game.aim=Vector2.RIGHT; game.fire()
	await shot("v04-muzzle")
	for voice in game.sound.voices: voice.stop()
	game.queue_free(); await create_timer(0.2).timeout; print("V04 previews: 9 captured"); quit()
