extends SceneTree
var failures=0
var checks=0
func expect(ok,message):
	checks+=1
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize():
	call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate()
	game.world.save_directory="user://test-exploration-loop"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.world.new_world(20261026)
	game.world.enemies.clear()
	var w=game.world
	var b=w.map.buildings[0]
	var door=game.Geometry.door(b)
	game.set_pos(door.get_center()+Vector2(0,35))
	game.solid_cache_key=-1
	var stopped=game.move_with_collision(game.player_pos(),Vector2(0,-70))
	expect(stopped.y>door.position.y,"closed door blocks entrance")
	expect(game.Tactics.complete(game,{"kind":"tac_door_toggle","id":b.container+"0"}),"nearby door opens")
	game.solid_cache_key=-1
	var entered=game.move_with_collision(game.player_pos(),Vector2(0,-70))
	expect(game.Geometry.interior(b).has_point(entered),"opened door leads to actual walkable interior")
	var loot_point=game.Geometry.loot_point(b)
	game.set_pos(loot_point+Vector2(-28,0)); game.solid_cache_key=-1
	var stock=w.owned(b.container)
	expect(not stock.is_empty(),"real house has finite loot")
	var item_id=stock[0].id
	game.start_action({"kind":"search","id":b.container,"pos":loot_point},2.6)
	game.complete_action()
	expect(game.hud.panel_kind=="loot" and w.paused,"completed search opens paused nearby container UI")
	game.hud.transfer_request(item_id,b.container,"player")
	expect(not w.paused,"transfer request resumes world")
	game.complete_action()
	expect(w.items[item_id].owner=="player","completed physical transfer commits ownership once")
	var bed=w.beds()[0]
	game.hud.close_panel(); game.set_pos(Vector2(bed.x,bed.y)); game.solid_cache_key=-1
	expect(w.register_shelter(bed.id,"路边住处"),"ordinary indoor bed registers personal shelter")
	game.hud.open_panel("camp")
	expect(w.paused and game.hud.panel.visible,"shelter management pauses world")
	game.hud.close_panel()
	expect(game.Survival.complete(w,{"kind":"sys_sleep"}),"safe bed permits real sleep")
	w.state.systems_v5.fatigue=60
	var minute=w.state.minute
	w.tick(1)
	expect(w.state.minute>minute and w.state.systems_v5.fatigue<60,"sleep advances shared clock and restores fatigue")
	w.spawn_enemy("town",game.player_pos()+Vector2(100,0),"normal")
	expect(game.wake_for_threat() and not w.state.systems_v5.sleeping,"approaching actual enemy interrupts sleep")
	w.enemies.clear()
	var exit=w.exits()[0]
	game.set_pos(Vector2(exit.x,exit.y)); game.solid_cache_key=-1
	var travel_minute=w.state.minute
	game.start_action({"kind":"ex_travel","target_id":exit.target_id},2)
	game.complete_action()
	expect(w.state.map_id=="forest","timed exit interaction changes to forest")
	expect(w.state.minute==travel_minute+15,"one journey charges time exactly once")
	w.enemies.clear(); exit=w.exits()[0]
	game.set_pos(Vector2(exit.x,exit.y)); game.solid_cache_key=-1
	expect(game.travel_request("town"),"explicit forest exit returns to town")
	expect(w.items[item_id].owner=="player" and not w.owned(b.container).any(func(i):return i.id==item_id),"return does not respawn stolen loot")
	expect(w.doors.get(b.container+"0",false),"opened house door persists across return")
	expect(w.state.shelters.any(func(s):return s.name=="路边住处"),"registered shelter remains across regions")
	expect(w.save_game(),"complete exploration loop saves valid snapshot")
	var restored=load("res://scripts/world.gd").new()
	restored.save_directory=w.save_directory
	expect(restored.load_game(),"loop snapshot reloads")
	expect(restored.state.minute==w.state.minute and restored.items[item_id].owner=="player","reload preserves exact time and looted ownership")
	game.free()
	print("EXPLORATION_LOOP: ",checks-failures,"/",checks)
	quit(1 if failures else 0)
