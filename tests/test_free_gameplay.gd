extends SceneTree
const Game = preload("res://scripts/game.gd")
const Survival = preload("res://scripts/survival_systems.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
const Geometry = preload("res://scripts/building_geometry.gd")
class FakeHud extends RefCounted:
	var container_id=""
	var game
	func close_panel(): game.world.paused=false
	func open_panel(_name): game.world.paused=true
class FakeSound extends RefCounted:
	func play(_name): pass
var checks = 0
var failures = 0
func expect(condition: bool, message: String):
	checks += 1
	if not condition: failures += 1; printerr("FAIL: ",message)
func _initialize():
	var game = Game.new()
	game.world.new_world(471113)
	game.world.save_directory="user://test-free-gameplay"
	game.hud=FakeHud.new(); game.hud.game=game
	game.sound=FakeSound.new()
	expect(game.has_method("travel_request"),"explicit travel interaction exists")
	expect(game.has_method("emit_noise"),"noise creates investigation rather than omniscient chase")
	expect(game.has_method("wake_for_threat"),"sleep responds to approaching danger")
	if failures>0:
		game.free(); print("FREE_GAMEPLAY: ",checks-failures,"/",checks); quit(1); return
	game.world.enemies.clear()
	game.world.state.zone="town"
	game.set_pos(Vector2(2000,2000))
	game.world.spawn_enemy("town",Vector2(2200,2000),"normal")
	var enemy: Dictionary = game.world.enemies[0]
	game.emit_noise(Vector2(2180,2000),360)
	expect(enemy.get("mode","")=="investigate","sound makes enemy investigate")
	expect(Vector2(enemy.tx,enemy.ty)==Vector2(2180,2000),"sound target is source location")
	game.set_pos(Vector2(2000,2300))
	game.emit_noise(Vector2(5000,5000),100)
	expect(Vector2(enemy.tx,enemy.ty)==Vector2(2180,2000),"unheard sound does not reveal new player location")
	enemy.alert=0; enemy["mode"]="search"; enemy["sense_left"]=999; enemy.tx=enemy.x; enemy.ty=enemy.y
	game.update_enemies(0.1)
	expect(enemy.mode=="wander","expired search returns to wandering")
	game.world.state.systems_v5.sleeping=true; game.world.state.systems_v5.resting=true
	enemy.x=game.player_pos().x+80; enemy.y=game.player_pos().y; enemy.hp=65
	expect(game.wake_for_threat(),"nearby danger wakes player")
	expect(not game.world.state.systems_v5.sleeping,"wake stops sleep immediately")
	game.world.enemies.clear()
	var bed: Dictionary=game.world.beds()[0]
	game.set_pos(Vector2(bed.x,bed.y)); game.solid_cache_key=-1
	expect(game.world.state.shelters.is_empty(),"sleep test has no registered home")
	expect(Survival.complete(game.world,{"kind":"sys_sleep"}),"ordinary world bed permits sleep without home registration")
	expect(game.world.state.systems_v5.sleeping,"bed starts sleep mode")
	game.world.state.systems_v5.sleeping=false; game.world.state.systems_v5.resting=false
	var windows=Tactics.windows(game.world,game.player_pos(),2000)
	var tested_window=false
	for win in windows:
		game.set_pos(win.outside); game.solid_cache_key=-1
		if game.blocked(win.inside) or game.blocked(win.outside): continue
		win.state.broken=true; win.state.hp=0; win.state["glass_cleared"]=false
		expect(Tactics.complete(game,{"kind":"tac_window_clear","id":win.id}),"broken window glass can be cleared in reach")
		var health: float=game.world.state.hp
		expect(Tactics.complete(game,{"kind":"tac_window_climb","id":win.id}),"cleared window can be crossed")
		expect(game.world.state.hp==health,"cleared glass causes no injury")
		tested_window=true; break
	expect(tested_window,"at least one real building has usable window")
	var f: Dictionary=game.world.furniture[0]
	game.set_pos(Vector2(f.x,f.y)+Vector2(40,0)); game.solid_cache_key=-1
	game.start_action({"kind":"pack","id":f.id,"pos":Vector2(f.x,f.y)},2)
	game.set_pos(Vector2(f.x,f.y)+Vector2(200,0))
	game.complete_action()
	expect(not f.packed,"out-of-range timed furniture action cannot commit")
	var exit: Dictionary=game.world.exits()[0]
	game.set_pos(Vector2(exit.x,exit.y)); game.solid_cache_key=-1
	var minute_before: float=game.world.state.minute
	expect(game.travel_request(exit.target_id),"explicit exit travels to new region")
	expect(game.world.state.map_id=="forest" and game.world.state.minute==minute_before+15,"travel changes region and advances time once")
	game.set_pos(Vector2(610,490))
	expect(not game.travel_request("town"),"cannot travel from arbitrary position away from exit")
	var event={"id":"event_v5_999","map_id":"town","zone":"town","x":610.0,"y":490.0,"type":"supply","status":"active","expires":game.world.state.minute+100}
	game.world.state.systems_v5.events.append(event)
	game.world.add_item("food",1,event.id)
	expect(not Survival.complete(game.world,{"kind":"sys_event","id":event.id}),"event at same coordinates in other region cannot be claimed")
	expect(not Survival.event_markers(game.world).any(func(e):return e.id==event.id),"other-region event not drawn on local map")
	event.map_id="forest"
	expect(Survival.complete(game.world,{"kind":"sys_event","id":event.id}),"event in current region can be claimed")
	expect(not Survival.complete(game.world,{"kind":"sys_event","id":event.id}),"event rewards cannot be claimed twice")
	game.world.enemies.clear()
	var forest_exit: Dictionary=game.world.exits()[0]
	game.set_pos(Vector2(forest_exit.x,forest_exit.y)); game.solid_cache_key=-1
	expect(game.travel_request("town"),"return to original town for physical trader")
	var shop_count=0
	for shop in game.world.map.buildings:
		if shop.kind!="shop": continue
		game.set_pos(Geometry.loot_point(shop)); game.solid_cache_key=-1
		game.world.add_item("food",2,"player")
		var stock_key=Survival.trader_key(game.world,"ammo")
		expect(not stock_key.is_empty(),"shop trader is a physical local interaction")
		var stock: int=game.world.state.systems_v5.trader_stock[stock_key]
		expect(Survival.complete(game.world,{"kind":"sys_trade","recipe":"ammo"}),"physical shop can exchange owned ingredients")
		expect(game.world.state.systems_v5.trader_stock[stock_key]==stock-1,"trade consumes this merchant stock")
		shop_count+=1
		break
	expect(shop_count==1,"generated region contains a shop to verify trader")
	var wood_before=game.world.count_item("wood","warehouse")
	game.world.state.zone="camp"
	expect(not Tactics.spend(game.world,{"wood":999}),"materials cannot come from legacy warehouse")
	expect(game.world.count_item("wood","warehouse")==wood_before,"failed spend leaves container inventory unchanged")
	game.free()
	print("FREE_GAMEPLAY: ",checks-failures,"/",checks," passed")
	quit(0 if failures==0 else 1)
