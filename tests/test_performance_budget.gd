extends SceneTree
var failures = 0
func expect(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.world.save_directory="user://performance-budget-tests"
	root.add_child(game); await process_frame
	game.world.new_world(80423); game.world.paused=false; game.set_pos(Vector2(600,500))
	game.world.enemies.clear()
	expect(game.blocked(Vector2(225,250)),"spatial collision index still blocks building walls")
	expect(game.last_collision_candidates<game.solid_cache.size(),"point collision checks only nearby solids")
	expect(not game.visible(Vector2(100,250),Vector2(580,250)),"spatial visibility index still blocks sight through buildings")
	expect(game.last_visibility_candidates<game.solid_cache.size(),"line of sight checks only nearby solids")
	expect(game.visible(Vector2(520,500),Vector2(580,500)),"open street remains visible")
	for i in range(24): game.world.spawn_enemy("town",Vector2(520+(i%6)*18,420+(i/6)*18),"normal")
	game.update_enemies(0.1)
	var first_batch=game.world.enemies.filter(func(e): return e.get("ai_clock",0.0)==0.0).size()
	expect(first_batch==4,"24 nearby enemies split into four AI updates per frame")
	for i in range(36): game.update_enemies(1.0/60.0)
	var waiting=game.world.enemies.filter(func(e): return e.get("ai_clock",0.0)>=0.1).size()
	expect(waiting==0,"round-robin AI updates do not starve enemies")
	game.free(); await process_frame
	print("PERFORMANCE_BUDGET failures: ",failures)
	quit(1 if failures else 0)



