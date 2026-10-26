extends SceneTree
var game
func _initialize(): call_deferred("run")
func shot(name: String):
	game.hud.refresh(); game.camera.position = game.player_pos()+Vector2(0,-40); game.view.queue_redraw()
	await process_frame; RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://builds/"+name+".png")
func run():
	game = load("res://main.tscn").instantiate(); game.world.save_directory="user://preview-v03"
	root.add_child(game); await process_frame; await process_frame; game.set_process(false)
	game.world.new_world(20261026); game.hud.close_panel(); game.world.state.zone="town"; game.set_pos(Vector2(570,490))
	await shot("v03-gameplay")
	game.set_pos(load("res://scripts/building_geometry.gd").loot_point(game.world.map.buildings[0])); game.world.doors["house0"]=true
	await shot("v03-interior")
	game.world.state.zone="camp"; var car=game.world.map.cars_at(Vector2(600,500),2000,"camp")[0]; game.set_pos(car.trunk_pos+Vector2(20,0)); game.interact(); game.action.remaining=1.3
	await shot("v03-search")
	game.complete_action(); await shot("v03-container")
	game.hud.open_panel("map"); await shot("v03-map")
	game.hud.close_panel(); game.world.state.zone="camp"; game.set_pos(Vector2(470,430))
	game.world.build_defense("barricade",Vector2(335,212)); game.world.build_defense("wire",Vector2(445,210)); game.world.build_defense("guardpost",Vector2(570,320))
	await shot("v03-camp-day")
	game.world.state.minute=1260; await shot("v03-camp-night")
	game.queue_free(); await create_timer(0.2).timeout; print("V03 previews: 7 captured"); quit()
