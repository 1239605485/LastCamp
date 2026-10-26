extends SceneTree
const World = preload("res://scripts/world.gd")
var checks = 0
var failures = 0
func expect(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func _initialize():
	var w = World.new()
	w.new_world(321)
	w.save_directory="user://test-resource-cycle"
	expect(w.has_method("resource_actions"),"resource loop is available in world")
	if not w.has_method("resource_actions"):
		print("RESOURCE_CYCLE: ",checks-failures,"/",checks)
		quit(1)
		return
	var cycle = load("res://scripts/resource_cycle.gd")
	w.enemies.clear()
	var house = w.map.buildings[0]
	var geometry = load("res://scripts/building_geometry.gd")
	var kitchen: Vector2 = geometry.loot_point(house)
	w.state.px = kitchen.x; w.state.py = kitchen.y
	w.add_item("dirty_water",2,"player")
	w.add_item("wood",6,"player")
	var water_before = w.count_item("water")
	expect(cycle.complete(w,{"kind":"sys_cycle_boil"}),"boil at house cooking point")
	expect(w.count_item("dirty_water")==1 and w.count_item("water")==water_before+1,"boil consumes one raw water and produces one safe water")
	w.state.px = 3000; w.state.py = 3000
	var before = w.items.duplicate(true)
	expect(not cycle.complete(w,{"kind":"sys_cycle_boil"}),"remote kitchen rejected")
	expect(w.items==before,"remote request consumes nothing")
	w.capacity = 0.1
	expect(not cycle.complete(w,{"kind":"sys_cycle_collect"}),"failed request cannot overflow bag")
	expect(w.items==before,"failed request preserves all inventory")
	w.capacity = 28
	w.state.px = kitchen.x; w.state.py = kitchen.y
	w.add_item("parts",3,"player")
	expect(cycle.complete(w,{"kind":"sys_cycle_craft","recipe":"collector"}),"craft rain collector kit")
	w.state.px = 3000; w.state.py = 3000
	expect(cycle.complete(w,{"kind":"sys_cycle_deploy"}),"deploy collector outdoors")
	var collector: Dictionary = w.state.resource_cycle.collectors[0]
	expect(collector.map_id=="town" and w.count_item("rain_collector")==0,"deployed kit has one world owner")
	cycle.collect_rain(w,60,"rain")
	expect(is_equal_approx(collector.water,1.0),"one hour rain produces one raw water")
	cycle.collect_rain(w,6000,"heavy_rain")
	expect(collector.water==8.0,"collector has finite capacity")
	expect(cycle.complete(w,{"kind":"sys_cycle_collect","id":collector.id}),"take one rain water nearby")
	expect(collector.water==7.0,"taking water decrements source once")
	w.capacity = 0.1
	before = w.items.duplicate(true)
	expect(not cycle.complete(w,{"kind":"sys_cycle_collect","id":collector.id}),"full bag rejects collected water")
	expect(collector.water==7.0 and w.items==before,"source retained when bag full")
	w.capacity = 28
	w.state.minute=359.0
	collector.water=0.0
	w.advance(2.0)
	expect(is_equal_approx(collector.water,1.0/60.0),"weather boundary charges only the one rainy minute")
	var saved = w.snapshot()
	expect(w.valid(saved),"new resource state validates")
	var bad = saved.duplicate(true)
	bad.state.resource_cycle.collectors[0].water = -1
	expect(not w.valid(bad),"negative saved water rejected")
	bad = saved.duplicate(true)
	bad.state.resource_cycle.collectors.append(bad.state.resource_cycle.collectors[0].duplicate(true))
	expect(not w.valid(bad),"duplicate collector identity rejected")
	var old = saved.duplicate(true)
	old.state.erase("resource_cycle")
	expect(w.valid(old),"schema6 missing optional new state remains compatible")
	w.restore_snapshot(old)
	expect(w.state.resource_cycle.collectors.is_empty(),"old save initializes empty collectors without freebies")
	w.restore_snapshot(saved)
	var amount = w.state.resource_cycle.collectors[0].water
	w.restore_snapshot(saved)
	expect(w.state.resource_cycle.collectors[0].water==amount,"loading does not grant extra rain water")
	var exit: Dictionary=w.exits()[0]
	w.state.px=exit.x; w.state.py=exit.y
	expect(w.travel("forest"),"collector source region can be left")
	var old_water: float=w.state.resource_cycle.collectors[0].water
	w.advance(60)
	expect(w.state.resource_cycle.collectors[0].water>old_water,"inactive-region collector receives world-time rain")
	expect(w.state.resource_cycle.collectors[0].map_id=="town","travel preserves collector location")
	expect(w.valid(w.snapshot()),"cross-region resource state validates")
	var fresh = w.add_item("berry",1,"player")
	var deadline = w.items[fresh].fresh_until
	w.advance(1440)
	expect(w.items[fresh].fresh_until==deadline and not w.Survival.can_eat(w,w.items[fresh]),"one day advances existing spoilage deadline without refreshing it")
	expect(not w.use_item("dirty_water"),"raw water cannot be drunk as safe water")
	print("RESOURCE_CYCLE: ",checks-failures,"/",checks)
	quit(1 if failures else 0)
