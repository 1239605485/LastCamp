extends SceneTree
# Resource-path simulation, NOT a seven-day gameplay/pathfinding or Android test.
# Relocates the player to real generated sources. No daily inventory injection.
const World = preload("res://scripts/world.gd")
const Cycle = preload("res://scripts/resource_cycle.gd")
const G = preload("res://scripts/building_geometry.gd")
var failures = 0
var checks = 0
func expect(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func move_to(w,p: Vector2):
	w.state.px=p.x; w.state.py=p.y
func _initialize():
	var w=World.new()
	w.new_world(321)
	w.save_directory="user://seven-day-resource-tests"
	w.enemies.clear()
	var kitchen: Vector2=G.loot_point(w.map.buildings[0])
	var trees=w.map.trees_at(Vector2(3000,3000),1000,"town")
	var plants=w.map.plants_at(Vector2(3000,3000),1600,"town")
	expect(not trees.is_empty() and plants.size()>=4,"seed provides real trees and food sources")
	if failures:
		quit(1); return
	var start: float=w.state.minute
	var safe_water=0
	var harvests=0
	for day in range(7):
		move_to(w,trees[0].pos+Vector2(30,0))
		var wood_id=Cycle.deadwood_near(w)
		expect(Cycle.complete(w,{"kind":"sys_cycle_wood","id":wood_id}),"day %d: renewable deadwood"%(day+1))
		expect(not Cycle.complete(w,{"kind":"sys_cycle_wood","id":wood_id}),"day %d: same-day harvest cannot repeat"%(day+1))
		move_to(w,Vector2(w.map._shore_x(3000)-20,3000))
		expect(Cycle.complete(w,{"kind":"sys_cycle_draw"}),"day %d: shoreline raw water"%(day+1))
		move_to(w,kitchen)
		expect(Cycle.complete(w,{"kind":"sys_cycle_boil"}),"day %d: convert raw water using real wood"%(day+1))
		safe_water+=1
		# Feed before advancing, maintaining a surplus against 25.92 daily hunger.
		for plant in plants:
			if w.state.hunger>=95: break
			move_to(w,plant.pos)
			if not w.harvest_plant(plant.id): continue
			harvests+=1
			for item in w.owned("player"):
				if item.def!=plant.kind: continue
				while w.items.has(item.id) and w.state.hunger<95:
					if not w.use_item(item.def,item.id): break
		# Consume one fresh safe-water portion daily, no free bottle reset.
		expect(w.use_item("water"),"day %d: drink from actual inventory"%(day+1))
		w.advance(1440)
		expect(w.state.hp>0 and w.state.hunger>0 and w.state.thirst>0,"day %d: water and food budget survives"%(day+1))
		expect(w.valid(w.snapshot()),"day %d: ownership and state remain valid"%(day+1))
		if day==3:
			var snapshot=w.snapshot()
			expect(w.save_game(),"midweek save succeeds")
			expect(w.load_game() and w.state.minute==snapshot.state.minute,"midweek reload grants no extra time")
	expect(is_equal_approx(w.state.minute,start+7*1440),"seven days charged exactly once")
	expect(safe_water==7 and harvests>0,"supplies obtained through renewable sources")
	print("SEVEN_DAY_RESOURCES: ",checks-failures,"/",checks,"; water=",safe_water,"; harvests=",harvests)
	quit(1 if failures else 0)
