extends SceneTree
var checks=0
var failures=0
func expect(v:bool,s:String):
	checks+=1
	if not v: failures+=1; printerr("FAIL: "+s)
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate(); game.world.save_directory="user://v04-pose-tests"
	root.add_child(game); await process_frame
	expect(game.has_method("muzzle_position"),"weapon supplies shared muzzle coordinate")
	expect(game.view.has_method("actor_frame"),"direction and walk frame mapping service")
	if game.view.has_method("actor_frame"):
		for d in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
			var row=-1
			for i in range(4):
				var f=game.view.actor_frame(d,"player",true,i, false)
				if row<0: row=int(f/4)
				expect(int(f/4)==row,"player walk does not cycle direction")
				var z=game.view.actor_frame(d,"normal",true,i,false)
				expect(int(z/4)==[Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT].find(d),"zombie fixed direction row")
	if game.has_method("muzzle_position"):
		game.world.new_world(1234); game.hud.close_panel(); game.set_process(false)
		game.world.state.zone="camp"; game.set_pos(Vector2(800,700)); game.world.enemies.clear()
		game.hud.aim_assist=false; game.aim=Vector2.RIGHT
		var p=game.muzzle_position(); expect(p.x>game.player_pos().x+15 and p.y<game.player_pos().y,"muzzle at hands and barrel not feet")
		game.fire(); expect(not game.view.flashes.is_empty() and game.view.flashes[-1].a.is_equal_approx(p),"shot starts at rendered muzzle")
		var gun=game.world.items[game.world.player_weapon("pistol")]; var spread=game.R.ITEMS.pistol.spread; game.R.ITEMS.pistol.spread=0
		game.set_pos(Vector2(200,272)); game.aim=Vector2.RIGHT; game.shot_cd=0; game.world.spawn_enemy("camp",Vector2(260,283),"normal")
		var enemy=game.world.enemies[-1]; var hp=enemy.hp; game.fire()
		expect(enemy.hp==hp,"shot blocked by corner cannot damage off-ray enemy")
		game.R.ITEMS.pistol.spread=spread
		var tree_frame=game.view.tree_frame({"pos":Vector2(500,500),"variant":1})
		expect(tree_frame.region.size.x==tree_frame.texture.get_width()/2 and tree_frame.rect.position.x+56==500,"tree renders living atlas half aligned to actual trunk")
		expect(game.has_method("set_world_zoom"),"world zoom API exists")
		if game.has_method("set_world_zoom"):
			game.set_world_zoom(0.2); expect(is_equal_approx(game.world_zoom,0.65),"zoom minimum clamp")
			game.set_world_zoom(5); expect(is_equal_approx(game.world_zoom,1.8),"zoom maximum clamp")
	print("POSE V04 RESULT: %d checks, %d failures"%[checks,failures]); await create_timer(0.55).timeout
	for voice in game.sound.voices: voice.stop()
	game.queue_free(); await create_timer(0.2).timeout; quit(1 if failures else 0)




