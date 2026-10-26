extends SceneTree
var game
var output = "C:/Users/liuxin/Documents/ChatGPT/安卓游戏制作/builds/v06-preview"
func _initialize():
	call_deferred("run")
func shot(name):
	game.hud.refresh(); game.camera.position=game.player_pos()+Vector2(0,-40); game.view.queue_redraw()
	await process_frame; await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run():
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://main.tscn").instantiate()
	game.world.save_directory="user://visual-v06-isolated"
	root.add_child(game)
	await process_frame; await process_frame
	game.set_process(false); game.world.new_world(20261026)
	game.hud.close_panel(); game.world.paused=false
	game.world.enemies.clear()
	game.set_pos(Vector2(900,450)); game.aim=Vector2(0.8,0.4).normalized()
	await shot("01-street")
	var b=game.world.map.buildings[0]
	game.set_pos(game.Geometry.interior(b).get_center()); game.world.doors[b.container+"0"]=true
	await shot("02-interior")
	game.set_pos(Vector2(900,450)); game.world.state.minute=1300
	game.world.state.systems_v5.flashlight_on=true
	await process_frame; await shot("03-night")
	game.hud.open_panel("bag"); await shot("04-inventory")
	game.queue_free(); await process_frame; quit()
