extends SceneTree

const S = preload("res://scripts/survival_systems.gd")
const World = preload("res://scripts/world.gd")
var failures = 0
var checks = 0

func expect(value: bool,label: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + label)

func _initialize():
	var w = World.new()
	w.new_world(471113)
	w.enemies.clear()
	S.ensure(w)
	var s: Dictionary = w.state.systems_v5
	expect(s.fatigue == 0 and s.battery == 100,"old save gets defaults")
	s.fatigue = 40.0
	S.ensure(w)
	expect(s.fatigue == 40,"ensure preserves state")
	expect(s.migrated_food,"food migration is tracked once")
	var apple = w.add_item("apple",1,"player")
	S.register_food(w,w.items[apple])
	var expiry = w.items[apple].fresh_until
	w.state.minute += 100
	S.register_food(w,w.items[apple])
	expect(w.items[apple].fresh_until == expiry,"expiry is immutable")
	w.state.minute = expiry
	expect(not S.can_eat(w,w.items[apple]) and S.nutrition_factor(w,w.items[apple]) == 0,"expired produce rejected")
	expect(S.can_eat(w,{"def":"food"}),"canned food keeps")
	w.state.minute = 480.0
	s.flashlight_on = true
	S.advance(w,10)
	expect(s.battery == 100,"daylight does not drain flashlight")
	w.state.minute = 1260.0
	S.advance(w,10)
	expect(is_equal_approx(s.battery,98.4),"night flashlight battery drains")
	s.flashlight_on = false
	S.advance(w,10)
	expect(is_equal_approx(s.battery,98.4),"switched off light does not drain")
	s.fatigue = 50.0
	S.complete(w,{"kind":"sys_rest"})
	S.advance(w,30)
	expect(s.fatigue < 50 and s.resting,"rest recovers fatigue over world time")
	S.complete(w,{"kind":"sys_rest"})
	var fatigue = s.fatigue
	S.advance(w,10)
	expect(s.fatigue > fatigue,"awake fatigue accumulates")
	w.state.zone = "camp"; w.state.px = 740.0; w.state.py = 420.0
	var food_before = w.count_item("food")
	w.capacity = w.weight("player") - 2.0
	var stock_before = s.trader_stock.ammo
	expect(not S.complete(w,{"kind":"sys_trade","recipe":"ammo"}),"overcapacity trade rejected")
	expect(w.count_item("food") == food_before and s.trader_stock.ammo == stock_before,"failed trade is atomic")
	w.capacity = 100.0
	expect(S.complete(w,{"kind":"sys_trade","recipe":"ammo"}),"trade succeeds with ingredients")
	expect(w.count_item("food") == food_before - 2 and s.trader_stock.ammo == stock_before - 1,"trade consumes costs and stock")
	w.add_item("food",20,"player")
	for i in range(5): S.complete(w,{"kind":"sys_trade","recipe":"ammo"})
	expect(s.trader_stock.ammo == 0 and not S.complete(w,{"kind":"sys_trade","recipe":"ammo"}),"daily trader stock bounded")
	w.state.minute = 1920.0
	S.advance(w,1)
	var announcements = w.logs.filter(func(line): return str(line).contains("无线电预告")).size()
	expect(announcements == 1 and s.events.is_empty(),"radio announces event two hours before rewards exist")
	S.advance(w,1)
	S.ensure(w)
	expect(w.logs.filter(func(line): return str(line).contains("无线电预告")).size() == announcements,"announcement does not repeat")
	w.state = JSON.parse_string(JSON.stringify(w.state))
	S.ensure(w)
	s = w.state.systems_v5
	S.advance(w,1)
	expect(w.logs.filter(func(line): return str(line).contains("无线电预告")).size() == announcements,"announcement survives save roundtrip")
	w.state.minute = 2040.0
	S.advance(w,1)
	expect(s.events.size() == 1,"first radio event generated")
	var event: Dictionary = s.events[0]
	var count_before = w.items.size()
	S.advance(w,1)
	expect(s.events.size() == 1 and w.items.size() == count_before,"event cannot regenerate reward")
	expect(not S.complete(w,{"kind":"sys_event","id":event.id}),"distant event cannot be claimed")
	w.state.zone = event.zone; w.state.px = event.x; w.state.py = event.y
	w.capacity = w.weight("player")
	expect(not S.complete(w,{"kind":"sys_event","id":event.id}) and event.status == "active","event capacity rejection keeps reward")
	w.capacity = 100
	expect(S.complete(w,{"kind":"sys_event","id":event.id}),"event requires reaching map location")
	expect(not S.complete(w,{"kind":"sys_event","id":event.id}) and w.owned(event.id).is_empty(),"event reward once only")
	var encoded = JSON.stringify(w.state)
	w.state = JSON.parse_string(encoded)
	S.ensure(w)
	expect(w.state.systems_v5.events[0].status == "claimed" and w.state.systems_v5.trader_stock.ammo == 3,"JSON state roundtrip retains event and new day stock")
	w.state.minute = 4920.0
	S.advance(w,1)
	var rescue: Dictionary = w.state.systems_v5.events[-1]
	expect(rescue.type == "rescue","alternating rescue radio event")
	w.state.zone = rescue.zone; w.state.px = rescue.x; w.state.py = rescue.y
	var npc_count = w.npcs.size()
	expect(S.complete(w,{"kind":"sys_event","id":rescue.id}) and w.npcs.size() == npc_count,"rescue consumes water, grants supplies without exceeding companion cap")
	w.state.minute = 7800.0
	S.advance(w,1)
	var expired: Dictionary = w.state.systems_v5.events[-1]
	w.state.minute = expired.expires
	S.advance(w,1)
	expect(expired.status == "expired" and w.owned(expired.id).is_empty(),"expired event stock is removed")
	print("survival_v05: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
