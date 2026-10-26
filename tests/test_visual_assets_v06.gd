extends SceneTree
const Art = preload("res://scripts/art.gd")
class ActorProbe extends "res://scripts/world_view.gd":
	func _draw():
		var index=0
		for kind in ["player","npc","normal","fast","breaker"]:
			for walking in [false,true]:
				for direction in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
					game.moving=walking
					actor(game.player_pos()+Vector2((index%8)*65-220,int(index/8)*60-160),direction,kind,false,walking)
					index+=1
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.world.save_directory="user://visual-asset-test-v06"
	root.add_child(game); await process_frame
	game.set_process(false); game.world.paused=true; game.hud.close_panel()
	var probe=ActorProbe.new(); probe.game=game; game.add_child(probe)
	probe.queue_redraw(); await process_frame; await process_frame
	RenderingServer.force_draw()
	var failures=0
	for path in Art.cache:
		if Art.cache[path]==null:
			printerr("Missing active texture: "+path); failures+=1
	print("VISUAL ASSETS: 40 actor state/direction combinations rendered; ",Art.cache.size()," loaded resources, ",failures," missing")
	game.queue_free(); await process_frame; quit(0 if failures==0 else 1)
