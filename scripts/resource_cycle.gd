extends RefCounted

# Additive schema-6 state. Every source has a region identity and a bounded stock.
const R = preload("res://scripts/rules.gd")
const G = preload("res://scripts/building_geometry.gd")
const RECIPES = {
	"collector":{"label":"制作集雨桶（木材4、零件2）","cost":{"wood":4,"parts":2},"reward":{"rain_collector":1},"seconds":8.0},
	"bandage":{"label":"裁制绷带（干净布料2）","cost":{"cloth":2},"reward":{"bandage":1},"seconds":4.0}}
const CAPACITY = 8.0

static func ensure(w):
	if not w.state.has("resource_cycle"):
		w.state["resource_cycle"] = {"version":1,"collectors":[]}

static func valid_state(state: Dictionary) -> bool:
	if not state.has("resource_cycle"): return true
	var data = state.resource_cycle
	if not data is Dictionary or data.get("version")!=1 or not data.get("collectors") is Array: return false
	if data.collectors.size()>32: return false
	var seen = {}
	for c in data.collectors:
		if not c is Dictionary or not c.get("id") is String or not c.id.begins_with("collector_") or seen.has(c.id): return false
		if c.get("map_id","") not in ["town","forest"]: return false
		for key in ["x","y","water"]:
			if not (c.get(key) is float or c.get(key) is int) or not is_finite(float(c[key])): return false
		if c.water<0 or c.water>CAPACITY or c.x<0 or c.y<0 or c.x>10240 or c.y>8960: return false
		seen[c.id] = true
	return true

static func outdoors(w,p: Vector2) -> bool:
	if w.map.water_at(p): return false
	for b in w.map.buildings_at(p,500):
		if b.rect.has_point(p): return false
	return true

static func kitchen_near(w) -> bool:
	var p = Vector2(w.state.px,w.state.py)
	for b in w.map.buildings_at(p,220):
		if b.kind in ["house","clinic","workshop"] and G.interior(b).has_point(p) and p.distance_to(G.loot_point(b))<=90:
			return true
	return false

static func shore_near(w) -> bool:
	var p = Vector2(w.state.px,w.state.py)
	if not outdoors(w,p): return false
	for i in range(16):
		if w.map.water_at(p+Vector2(64,0).rotated(i*TAU/16)): return true
	return false

static func deadwood_near(w) -> String:
	var p = Vector2(w.state.px,w.state.py)
	if not outdoors(w,p): return ""
	for tree in w.map.trees_at(p,85,w.state.zone):
		if tree.trunk.get_center().distance_to(p)<=85:
			return str(w.state.map_id)+":deadwood:%d:%d"%[roundi(tree.trunk.position.x),roundi(tree.trunk.position.y)]
	return ""

static func nearby_collectors(w) -> Array:
	ensure(w)
	var p = Vector2(w.state.px,w.state.py)
	if not outdoors(w,p): return []
	return w.state.resource_cycle.collectors.filter(func(c):return c.map_id==w.state.map_id and p.distance_to(Vector2(c.x,c.y))<=65)

static func actions(w) -> Array:
	ensure(w)
	var out: Array = []
	if shore_near(w):
		out.append({"label":"岸边取脏水（须煮沸或净化）","request":{"kind":"sys_cycle_draw"},"duration":4.0})
	if kitchen_near(w):
		out.append({"label":"料理点煮水（脏水1、木材1 → 饮用水1）","request":{"kind":"sys_cycle_boil"},"duration":12.0,"enabled":w.count_item("dirty_water")>0 and w.count_item("wood")>0})
	if w.count_item("purification_tablet")>0:
		out.append({"label":"净水片处理（脏水1、净水片1）","request":{"kind":"sys_cycle_purify"},"duration":6.0,"enabled":w.count_item("dirty_water")>0})
	for id in RECIPES:
		var recipe: Dictionary = RECIPES[id]
		var enabled = true
		for material in recipe.cost:
			if w.count_item(material)<recipe.cost[material]: enabled=false
		out.append({"label":recipe.label,"request":{"kind":"sys_cycle_craft","recipe":id},"duration":recipe.seconds,"enabled":enabled})
	if w.count_item("rain_collector")>0 and outdoors(w,Vector2(w.state.px,w.state.py)):
		out.append({"label":"原地放下集雨桶（户外，上限8份）","request":{"kind":"sys_cycle_deploy"},"duration":4.0})
	for c in nearby_collectors(w):
		out.append({"label":"集雨桶 %.1f/8：取脏水1份"%c.water,"request":{"kind":"sys_cycle_collect","id":c.id},"duration":3.0,"enabled":c.water>=1.0})
		out.append({"label":"收起空集雨桶","request":{"kind":"sys_cycle_pack","id":c.id},"duration":4.0,"enabled":c.water==0})
	var wood_id = deadwood_near(w)
	if not wood_id.is_empty():
		out.append({"label":"拾取枯枝（木材2，24小时恢复）","request":{"kind":"sys_cycle_wood","id":wood_id},"duration":4.0,"enabled":float(w.state.harvests.get(wood_id,0))<=w.state.minute})
	return out

# Check projected bag size and mass before consuming anything. No time is added
# here: game.gd owns the interruptible action and its single world-time advance.
static func exchange(w,cost: Dictionary,reward: Dictionary) -> bool:
	var mass = w.weight("player")
	for key in cost:
		if w.count_item(key)<cost[key]: return false
		mass -= R.ITEMS[key].weight*cost[key]
	for key in reward: mass += R.ITEMS[key].weight*reward[key]
	if mass>w.capacity or not w.has_slot_room(w.Survival.slot_delta(w,cost,reward.size())): return false
	for key in cost: w.consume(key,cost[key])
	for key in reward: w.add_item(key,reward[key],"player")
	return true

static func complete(w,request: Dictionary) -> bool:
	ensure(w)
	match request.get("kind",""):
		"sys_cycle_draw":
			return shore_near(w) and exchange(w,{}, {"dirty_water":1})
		"sys_cycle_boil":
			return kitchen_near(w) and exchange(w,{"dirty_water":1,"wood":1},{"water":1})
		"sys_cycle_purify":
			return exchange(w,{"dirty_water":1,"purification_tablet":1},{"water":1})
		"sys_cycle_craft":
			var recipe: Dictionary = RECIPES.get(request.get("recipe",""),{})
			return not recipe.is_empty() and exchange(w,recipe.cost,recipe.reward)
		"sys_cycle_wood":
			var id = deadwood_near(w)
			if id.is_empty() or id!=request.get("id","") or float(w.state.harvests.get(id,0))>w.state.minute: return false
			if not exchange(w,{}, {"wood":2}): return false
			w.state.harvests[id] = w.state.minute+1440.0
			return true
		"sys_cycle_deploy":
			var p = Vector2(w.state.px,w.state.py)
			if not outdoors(w,p) or not nearby_collectors(w).is_empty(): return false
			if w.state.resource_cycle.collectors.size()>=32 or not w.consume("rain_collector",1): return false
			w.state.resource_cycle.collectors.append({"id":w.uid("collector_"),"map_id":w.state.map_id,"x":p.x,"y":p.y,"water":0.0})
			return true
		"sys_cycle_collect", "sys_cycle_pack":
			for c in nearby_collectors(w):
				if c.id!=request.get("id",""): continue
				if request.kind=="sys_cycle_pack":
					if c.water>0 or not exchange(w,{}, {"rain_collector":1}): return false
					w.state.resource_cycle.collectors.erase(c)
					return true
				if c.water<1 or not exchange(w,{}, {"dirty_water":1}): return false
				c.water -= 1.0
				return true
	return false

static func weather_at(w,minute: float) -> String:
	var index = posmod(int(floor(minute/360.0))*17+int(w.state.world_seed),10)
	return "clear" if index<4 else ("cloudy" if index<6 else ("rain" if index<9 else "heavy_rain"))

static func collect_rain(w,minutes: float,weather: String):
	ensure(w)
	var gain = minutes/60.0 * (2.0 if weather=="heavy_rain" else (1.0 if weather=="rain" else 0.0))
	if gain<=0: return
	for c in w.state.resource_cycle.collectors: c.water = minf(CAPACITY,c.water+gain)

static func advance(w,minutes: float):
	var cursor = maxf(0,float(w.state.minute)-minutes)
	var end = float(w.state.minute)
	while cursor<end:
		var boundary = minf(end,(floor(cursor/360.0)+1)*360.0)
		collect_rain(w,boundary-cursor,weather_at(w,cursor))
		cursor = boundary
