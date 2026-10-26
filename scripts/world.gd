extends RefCounted

const R = preload("res://scripts/rules.gd")
const Map = preload("res://scripts/world_map.gd")
const Forage = preload("res://scripts/forage.gd")
const Survival = preload("res://scripts/survival_systems.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
const Exploration = preload("res://scripts/exploration.gd")
const Cycle = preload("res://scripts/resource_cycle.gd")
const G = preload("res://scripts/building_geometry.gd")
var regions: Dictionary = {}
var map = Map.new()
var state: Dictionary = {}
var items: Dictionary = {}
var npcs: Array = []
var furniture: Array = []
var enemies: Array = []
var graves: Array = []
var logs: Array = []
var doors: Dictionary = {}
var defenses: Array = []
var capacity = R.BAG_WEIGHT
var slot_capacity = 24
var paused = false
var serial = 0
var sim_acc = 0.0
var save_directory = "user://"

func dawn_path() -> String:
	return save_directory.path_join("dawn.json")

func uid(prefix: String) -> String:
	serial += 1
	return prefix + str(serial)

func new_world(world_seed: int = -1):
	items.clear(); enemies.clear(); graves.clear(); logs.clear(); doors.clear(); defenses.clear(); regions.clear()
	serial = 0
	var seed_value = world_seed if world_seed>=0 else int(randi() & 0x7fffffff)
	state = {"schema_version":6,"world_seed":seed_value,"minute":480.0,"zone":"town","map_id":"town","px":900.0,"py":450.0,"hp":100.0,"hunger":95.0,"thirst":95.0,"stamina":100.0,"bleeding":false,"wall":0.0,"core":0.0,"wave_day":0,"kills":0,"failed":false,"guard_ammo":0,"weapon":"pistol","last_dawn":1,"threat":0,"speed":1.0,"map_layout_version":4,"content_version":6,"world_features_version":6,"v5_starter_resources":true,"shelters":[],"preferred_shelter_id":"","known_regions":{"town":"entered","forest":"rumor"}}
	capacity = R.BAG_WEIGHT
	slot_capacity=24
	Survival.ensure(self); Cycle.ensure(self)
	for entry in [["backpack",1],["knife",1],["pistol",1],["ammo9",42],["food",2],["water",2],["bandage",3]]: add_item(entry[0],entry[1],"player")
	create_region("town")
	Exploration.activate_region(self,"town")
	var start = Exploration.safe_point(self,Vector2(900,450),180)
	if start!=Vector2.INF: state.px=start.x; state.py=start.y
	note("自由探索：搜刮附近建筑，寻找床位与落脚点。西侧道路通往松溪林区；夜晚无需返营。")
	Exploration.commit_region(self)

func create_region(id: String):
	var old_map = map
	var old_id = state.map_id
	state.map_id = id
	map = Map.new(int(state.world_seed)+(8911 if id=="forest" else 0),4)
	Exploration.decorate_map(map,id)
	var region = {"seed":map.seed,"beds":[],"npcs":[],"furniture":[],"enemies":[],"graves":[],"defenses":[],"doors":{},"local":{"harvests":{},"searched":{},"explored":[map.sector_id(Vector2(610,450))],"tactics_v5":{"doors":{},"windows":{},"traps":[]}},"last_minute":state.minute}
	regions[id]=region
	region.beds=Exploration.make_beds(self)
	var rng=RandomNumberGenerator.new(); rng.seed=map.seed+723
	for index in range(map.buildings.size()):
		var building=map.buildings[index]
		var owner: String=building.container
		match building.kind:
			"house":
				add_item("cloth",2,owner); add_item("food",rng.randi_range(1,3),owner); add_item("water",rng.randi_range(1,2),owner); add_item("wood",rng.randi_range(1,4),owner)
			"clinic":
				add_item("purification_tablet",2,owner); add_item("bandage",rng.randi_range(2,4),owner); add_item("water",1,owner)
			"police":
				var gun_name=R.Catalog.GUNS[rng.randi_range(0,R.Catalog.GUNS.size()-1)]
				add_item(gun_name,1,owner); add_item(R.ITEMS[gun_name].ammo,rng.randi_range(12,30),owner)
				add_item(R.Catalog.PARTS[rng.randi_range(0,R.Catalog.PARTS.size()-1)],1,owner)
			_:
				add_item("parts",rng.randi_range(2,4),owner); add_item("battery",1,owner); add_item("water",1,owner)
		if index%3==0:
			var p: Vector2=building.rect.end+Vector2(90,60)
			region.enemies.append({"id":uid("z_"),"zone":"town","map_id":id,"x":p.x,"y":p.y,"hp":65.0,"kind":"normal","wave":false,"cd":0.0,"alert":0.0,"tx":p.x,"ty":p.y,"ai_state":"wander"})
		if index==0:
			var p=G.loot_point(building)+Vector2(-45,0)
			region.furniture.append({"id":uid("cabinet_"),"zone":"town","map_id":id,"x":p.x,"y":p.y,"rotation":0,"hp":90.0,"packed":false})
	for car in map.cars_at(map.size/2,20000,"town"):
		add_item(["food","water","bandage","parts"][rng.randi_range(0,3)],rng.randi_range(1,2),car.id)
	if id=="town":
		var p=G.loot_point(map.buildings[0])
		var npc={"id":uid("npc_"),"name":"林舟","job":"守卫","status":"healthy","hp":90.0,"zone":"town","map_id":id,"x":p.x-30,"y":p.y,"follow":false,"xp":0,"hold_fire":false}
		region.npcs.append(npc)
		add_item("pistol",1,npc.id); add_item("ammo9",24,npc.id)
	map=old_map; state.map_id=old_id

func ensure_expansion():
	# v0.6 new worlds generate finite place-specific loot exactly once.
	pass

func ensure_world_features():
	Survival.ensure(self); Tactics.ensure(self); Cycle.ensure(self)
	if not state.has("harvests"): state["harvests"]={}
	if not state.has("searched"): state["searched"]={}
	if not state.has("explored"): state["explored"]=[]

func resource_actions() -> Array: return Cycle.actions(self)

func exits() -> Array: return Exploration.exits(self)
func beds() -> Array: return Exploration.beds(self)
func near_bed() -> Dictionary: return Exploration.near_bed(self)
func travel(target_map_id: String) -> bool: return Exploration.travel(self,target_map_id)
func register_shelter(bed_id: String,name: String="") -> bool: return Exploration.register_shelter(self,bed_id,name)
func unregister_shelter(id: String) -> bool:
	var before=state.shelters.size()
	state.shelters=state.shelters.filter(func(s):return s.id!=id)
	if state.preferred_shelter_id==id: state.preferred_shelter_id="" if state.shelters.is_empty() else state.shelters[0].id
	return state.shelters.size()<before
func set_preferred_shelter(id: String) -> bool:
	if not state.shelters.any(func(s):return s.id==id): return false
	state.preferred_shelter_id=id; return true

func container_position(id: String) -> Vector2:
	for group in [graves,furniture,npcs]:
		for entity in group:
			if entity.id==id and not entity.get("packed",false): return Vector2(entity.x,entity.y)
	for building in map.buildings:
		if building.container==id: return G.loot_point(building)
	for car in map.cars_at(Vector2(state.px,state.py),2500,"town"):
		if car.id==id: return car.trunk_pos
	return Vector2.INF

func container_accessible(id: String) -> bool:
	if id=="player": return true
	var target=container_position(id)
	if target==Vector2.INF or target.distance_to(Vector2(state.px,state.py))>115: return false
	var player_pos=Vector2(state.px,state.py)
	for building in map.buildings_at(player_pos,500):
		var inside=G.interior(building)
		if inside.has_point(target)!=inside.has_point(player_pos): return false
	return true

func map_for_state(data: Dictionary):
	var map_seed = int(data.get("map_seed",471113)); var version = int(data.get("map_layout_version",2))
	return map if map.seed == map_seed and map.layout_version == version else Map.new(map_seed,version)

func build_defense(kind: String, pos: Vector2) -> bool:
	var costs={"barricade":{"wood":4,"parts":0,"hp":180},"wire":{"wood":1,"parts":2,"hp":90},"guardpost":{"wood":6,"parts":3,"hp":150}}
	if not costs.has(kind) or defenses.size()>=24 or pos.distance_to(Vector2(state.px,state.py))>130: return false
	var data: Dictionary=costs[kind]
	if count_item("wood")<data.wood or count_item("parts")<data.parts: return false
	consume("wood",data.wood); consume("parts",data.parts)
	defenses.append({"id":uid("defense_"),"map_id":state.map_id,"zone":"town","kind":kind,"x":pos.x,"y":pos.y,"hp":float(data.hp),"max_hp":float(data.hp),"cd":0.0})
	return true

func add_item(definition: String, quantity: int, owner: String) -> String:
	var id = uid("item_")
	items[id] = {"id":id, "def":definition, "qty":quantity, "owner":owner}
	if R.ITEMS[definition].has("capacity"):
		items[id]["ammo"] = int(R.ITEMS[definition].capacity)
		items[id]["slots"] = {}
		items[id]["mag_bonus"] = 0
	Survival.register_food(self,items[id])
	return id

func owned(owner: String) -> Array:
	return items.values().filter(func(i): return i.owner == owner)

func weight(owner: String) -> float:
	var total = 0.0
	for i in owned(owner):
		total += R.ITEMS[i.def].weight * i.qty
		for child in owned(i.id):
			total += R.ITEMS[child.def].weight * child.qty
	return total

func has_slot_room(count: int=1) -> bool:
	return owned("player").size()+count<=slot_capacity

func transfer(id: String, target: String) -> bool:
	if not items.has(id): return false
	var item = items[id]
	if not container_accessible(str(item.owner)) or not container_accessible(target): return false
	if item.owner == target: return false
	var incoming = R.ITEMS[item.def].weight * item.qty + weight(id)
	if target == "player" and weight("player") + incoming > capacity: return false
	if target == "player" and not has_slot_room(): return false
	var was_equipped = item.owner == "player" and item.def == state.weapon
	item.owner = target
	if was_equipped:
		var remaining = player_weapon(state.weapon)
		state["weapon_id"] = remaining
		if remaining.is_empty(): state.weapon = "knife"
	return true

func count_item(definition: String, owner: String = "player") -> int:
	var count = 0
	for i in owned(owner):
		if i.def == definition: count += int(i.qty)
	return count

func consume(definition: String, amount: int, owner: String = "player") -> bool:
	if count_item(definition, owner) < amount: return false
	for i in owned(owner):
		if i.def != definition: continue
		var take = mini(amount, int(i.qty))
		i.qty -= take; amount -= take
		if i.qty == 0: items.erase(i.id)
		if amount == 0: break
	return true

func player_weapon(definition: String) -> String:
	var selected: String = state.get("weapon_id","")
	if items.has(selected) and items[selected].owner == "player" and items[selected].def == definition: return selected
	for i in owned("player"):
		if i.def == definition: return i.id
	return ""

func equip(id: String) -> bool:
	if not items.has(id) or items[id].owner != "player" or (not items[id].has("slots") and items[id].def != "knife"): return false
	state.weapon = items[id].def; state["weapon_id"] = id
	return true

func attach(gun_id: String, part_id: String) -> bool:
	if not items.has(gun_id) or not items.has(part_id): return false
	var gun = items[gun_id]; var part = items[part_id]; var d = R.ITEMS[part.def]
	if gun.owner != "player" or part.owner != "player" or not d.has("slot") or not gun.has("slots"): return false
	if not R.compatible(gun,part) or gun.slots.has(d.slot): return false
	gun.slots[d.slot] = part_id; part.owner = gun_id
	if d.slot == "mag": gun["mag_bonus"] = d.get("effects",{}).get("capacity_add",0)
	return true

func detach(gun_id: String, slot: String) -> bool:
	if not items.has(gun_id) or items[gun_id].owner != "player" or not items[gun_id].get("slots", {}).has(slot): return false
	var gun = items[gun_id]; var part_id = gun.slots[slot]
	var overflow = maxi(0, int(gun.ammo) - int(R.ITEMS[gun.def].capacity)) if slot == "mag" else 0
	if not has_slot_room(1+(1 if overflow>0 else 0)): return false
	# Attached parts already count toward carried weight; only newly loose ammunition adds weight.
	if weight("player") + overflow * R.ITEMS[R.ITEMS[gun.def].ammo].weight > capacity: return false
	gun.slots.erase(slot); items[part_id].owner = "player"
	if slot == "mag": gun["mag_bonus"] = 0
	if overflow:
		gun.ammo -= overflow; add_item(R.ITEMS[gun.def].ammo, overflow, "player")
	return true

func reload_weapon(gun_id: String) -> bool:
	if not items.has(gun_id) or items[gun_id].owner != "player": return false
	var gun = items[gun_id]; var d = R.ITEMS[gun.def]
	var count = mini(R.capacity_for(gun) - int(gun.ammo), count_item(d.ammo))
	if count <= 0: return false
	consume(d.ammo, count); gun.ammo += count
	return true

func use_item(definition: String, instance_id: String = "") -> bool:
	if not R.ITEMS.has(definition): return false
	if definition not in ["food","water","bandage"] and not R.ITEMS[definition].has("nutrition"): return false
	var food_factor=1.0
	if R.ITEMS[definition].has("nutrition"):
		var edible=owned("player").filter(func(i):return i.def==definition and Survival.can_eat(self,i))
		if not instance_id.is_empty(): edible=edible.filter(func(i):return i.id==instance_id)
		if edible.is_empty(): note("食物已经变质，无法食用。"); return false
		var chosen=edible[0]; food_factor=Survival.nutrition_factor(self,chosen)
		chosen.qty-=1
		if chosen.qty<=0: items.erase(chosen.id)
	elif not consume(definition, 1): return false
	if R.ITEMS[definition].has("nutrition"):
		state.hunger = minf(100,state.hunger + R.ITEMS[definition].nutrition*food_factor)
		state.thirst = minf(100,state.thirst + R.ITEMS[definition].water_gain*food_factor)
		return true
	match definition:
		"food": state.hunger = minf(100, state.hunger + 35)
		"water": state.thirst = minf(100, state.thirst + 40)
		"bandage": state.hp = minf(100, state.hp + 35); state.bleeding = false
	return true

func harvest_plant(plant_id: String) -> bool:
	for plant in map.plants_at(Vector2(state.px,state.py),85,state.zone):
		if plant.id != plant_id: continue
		var definition = Forage.definition(plant.kind)
		if not Forage.ready(state.harvests,plant.id,int(state.minute)): return false
		if weight("player") + R.ITEMS[plant.kind].weight * definition.qty > capacity: return false
		if not has_slot_room(): return false
		var quantity = Forage.commit(state.harvests,plant.id,plant.kind,int(state.minute))
		if quantity <= 0: return false
		add_item(plant.kind,quantity,"player")
		note("采集获得%s ×%d" % [R.ITEMS[plant.kind].name,quantity]); return true
	return false

func pack_furniture(id: String) -> bool:
	for f in furniture:
		if f.id != id: continue
		if f.packed or f.hp<=0 or not owned(id).is_empty() or weight("player") + 5 > capacity or not has_slot_room() or Vector2(f.x,f.y).distance_to(Vector2(state.px,state.py))>100: return false
		f.packed = true
		items[id] = {"id":id, "def":"cabinet", "owner":"player", "qty":1}
		return true
	return false

func place_furniture(id: String, zone: String, pos: Vector2) -> bool:
	if not items.has(id) or items[id].owner != "player" or zone!="town" or pos.distance_to(Vector2(state.px,state.py))>130: return false
	if Exploration.safe_point(self,pos).distance_to(pos)>0.1: return false
	for f in furniture:
		if f.id == id and f.packed:
			f.zone = zone; f.map_id=state.map_id; f.x = pos.x; f.y = pos.y; f.packed = false; items.erase(id)
			return true
	return false

func die():
	var id = uid("grave_")
	graves.append({"id":id,"zone":"town","map_id":state.map_id,"x":state.px,"y":state.py})
	for item in owned("player"): item.owner=id
	for npc in npcs:
		if npc.follow: npc.follow=false; npc["command"]="wait"; npc.erase("retreat_until")
	state.hp=65.0; state.hunger=maxf(35,state.hunger); state.thirst=maxf(35,state.thirst)
	state.bleeding=false; state.weapon="knife"; state.weapon_id=""
	state.systems_v5.resting=false; state.systems_v5.sleeping=false
	Exploration.commit_region(self)
	Exploration.recover(self)
	advance(60,true)
	note("负伤恢复，经过1小时；全部随身物品留在原处遗物中，世界没有回档。")
	Exploration.commit_region(self)

func spawn_enemy(zone: String, pos: Vector2, kind: String, wave: bool = false):
	enemies.append({"id":uid("z_"), "map_id":state.get("map_id","town"), "zone":zone, "x":pos.x, "y":pos.y, "hp":100.0 if kind == "breaker" else (40.0 if kind == "fast" else 65.0), "kind":kind, "wave":wave, "cd":0.0, "alert":0.0, "tx":pos.x, "ty":pos.y})

func note(message: String):
	logs.append(message)
	if logs.size() > 30: logs.pop_front()

func tick(delta: float):
	if paused or state.failed: return
	advance(delta * 1440.0 / R.DAY_SECONDS * state.speed)

func advance(minutes: float, recovering: bool = false):
	var left=maxf(0,minutes)
	while left>0:
		var step=minf(left,1.0); left-=step; state.minute+=step
		Survival.advance(self,step)
		Cycle.advance(self,step)
		state.hunger=maxf(0,state.hunger-step*0.018); state.thirst=maxf(0,state.thirst-step*0.024)
		if not recovering:
			if state.hunger<=0 or state.thirst<=0: state.hp-=step*0.06
			if state.bleeding: state.hp-=step*0.12
		# No offscreen random attacks, teleporting companions, core loss or nightly waves.
		state.failed=false

func offscreen_camp(_minutes: float): pass
func finish_wave(): pass

func snapshot() -> Dictionary:
	state["bag_capacity"]=capacity; state["bag_slots"]=slot_capacity
	Exploration.commit_region(self)
	return {"schema_version":6,"state":state.duplicate(true),"regions":regions.duplicate(true),"items":items.duplicate(true),"npcs":npcs.duplicate(true),"furniture":furniture.duplicate(true),"enemies":enemies.duplicate(true),"graves":graves.duplicate(true),"logs":logs.duplicate(),"doors":doors.duplicate(true),"serial":serial,"defenses":defenses.duplicate(true)}

func restore_snapshot(data: Dictionary):
	state=data.state.duplicate(true); regions=data.regions.duplicate(true); items=data.items.duplicate(true)
	capacity=float(state.get("bag_capacity",R.BAG_WEIGHT)); slot_capacity=int(state.get("bag_slots",24))
	logs=data.logs.duplicate(); serial=int(data.serial)
	Exploration.activate_region(self,str(state.map_id))

func finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func valid(data) -> bool:
	if not data is Dictionary or data.get("schema_version")!=6: return false
	for key in ["state","regions","items"]:
		if not data.get(key) is Dictionary: return false
	if not data.get("serial") is float and not data.get("serial") is int: return false
	if not data.get("logs") is Array: return false
	var s: Dictionary=data.state
	if s.get("map_id","") not in ["town","forest"] or s.get("zone","")!="town" or not data.regions.has(s.map_id): return false
	for key in ["minute","px","py","hp","hunger","thirst","stamina","world_seed"]:
		if not (s.get(key) is float or s.get(key) is int) or not is_finite(float(s[key])): return false
	if not finite_number(s.get("bag_capacity",R.BAG_WEIGHT)) or float(s.get("bag_capacity",R.BAG_WEIGHT))<=0: return false
	if not finite_number(s.get("bag_slots",24)) or int(s.get("bag_slots",24))<1 or int(s.get("bag_slots",24))>1000: return false
	if not s.get("shelters") is Array or not s.get("known_regions") is Dictionary or not s.get("preferred_shelter_id") is String: return false
	if not R.ITEMS.has(s.get("weapon","")) or not Survival.valid_state(s) or not Tactics.valid_state(s) or not Cycle.valid_state(s): return false
	var owners={"player":true}
	var entity_ids={}
	var bed_ids={}
	for region_id in data.regions:
		if region_id not in ["town","forest"]: return false
		var region=data.regions[region_id]
		if not region is Dictionary or not region.get("seed") is float and not region.get("seed") is int: return false
		if not region.get("local") is Dictionary or not region.get("doors") is Dictionary or not region.get("beds") is Array: return false
		if not Tactics.valid_state({"tactics_v5":region.local.get("tactics_v5",{})}): return false
		for bed in region.beds:
			if not bed is Dictionary or not bed.get("id") is String or bed_ids.has(bed.id) or bed.get("map_id")!=region_id: return false
			if not bed.get("building_id") is String: return false
			for field in ["x","y","hp"]:
				if not finite_number(bed.get(field)): return false
			bed_ids[bed.id]=region_id
		for key in ["npcs","furniture","enemies","graves","defenses"]:
			if not region.get(key) is Array: return false
			for entity in region[key]:
				if not entity is Dictionary or not entity.get("id") is String or entity_ids.has(entity.id) or entity.get("map_id")!=region_id: return false
				for field in ["x","y"]:
					if not (entity.get(field) is float or entity.get(field) is int) or not is_finite(float(entity[field])): return false
				entity_ids[entity.id]=true; owners[entity.id]=true
				if key=="npcs":
					if not entity.get("follow") is bool or entity.get("status","") not in ["healthy","injured","down","waiting"] or not finite_number(entity.get("hp")) or not entity.get("job") is String: return false
				elif key=="furniture":
					if not entity.get("packed") is bool or not finite_number(entity.get("hp")): return false
				elif key=="enemies":
					if not finite_number(entity.get("hp")) or not finite_number(entity.get("alert")) or entity.get("kind","") not in ["normal","fast","breaker"]: return false
		var check_map=Map.new(int(region.seed),4); Exploration.decorate_map(check_map,region_id)
		for building in check_map.buildings: owners[building.container]=true
		for car in check_map.cars_at(check_map.size/2,20000,"town"): owners[car.id]=true
	var shelter_ids={}
	for shelter in s.shelters:
		if not shelter is Dictionary or not shelter.get("id") is String or shelter_ids.has(shelter.id): return false
		if not bed_ids.has(shelter.get("bed_id","")) or bed_ids[shelter.bed_id]!=shelter.get("map_id",""): return false
		if not finite_number(shelter.get("x")) or not finite_number(shelter.get("y")) or not shelter.get("name") is String: return false
		shelter_ids[shelter.id]=true
	if not s.preferred_shelter_id.is_empty() and not shelter_ids.has(s.preferred_shelter_id): return false
	for event in s.get("systems_v5",{}).get("events",[]): owners[event.id]=true
	for id in data.items:
		var item=data.items[id]
		if not item is Dictionary or item.get("id")!=id or not R.ITEMS.has(item.get("def","")): return false
		if item.has("fresh_until") and (not finite_number(item.fresh_until) or item.fresh_until<0): return false
		if not finite_number(item.get("qty")) or item.qty<=0 or floor(float(item.qty))!=float(item.qty): return false
		if data.items.has(item.get("owner","")):
			var parent=data.items[item.owner]
			if not parent is Dictionary or not parent.get("slots") is Dictionary or id not in parent.slots.values(): return false
			if not R.ITEMS.has(parent.get("def","")) or not R.compatible(parent,item): return false
		var owner=item.get("owner",""); var seen=[id]
		while data.items.has(owner):
			if owner in seen: return false
			seen.append(owner); owner=data.items[owner].get("owner","")
		if not owners.has(owner): return false
		if R.ITEMS[item.def].has("capacity"):
			if not item.get("slots") is Dictionary or not (item.get("ammo") is float or item.get("ammo") is int) or item.ammo<0 or item.ammo>R.capacity_for(item): return false
			for slot in item.slots:
				var part_id=item.slots[slot]
				if not data.items.has(part_id) or data.items[part_id].owner!=id: return false
				if R.ITEMS[data.items[part_id].def].get("slot","")!=slot: return false
			var mag_id=item.slots.get("mag","")
			var expected_bonus=R.ITEMS[data.items[mag_id].def].get("effects",{}).get("capacity_add",0) if data.items.has(mag_id) else 0
			if item.get("mag_bonus",0)!=expected_bonus or not finite_number(item.ammo) or floor(float(item.ammo))!=float(item.ammo): return false
	return true

func parse_save(path: String):
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

func save_game(path: String = "") -> bool:
	if path.is_empty(): path = save_directory.path_join("save.json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var data = snapshot()
	if not valid(data): return false
	var temp = path + ".tmp"
	var f = FileAccess.open(temp, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(data)); f.flush(); f.close()
	if not valid(parse_save(temp)): return false
	var absolute = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and valid(parse_save(path)):
		if DirAccess.copy_absolute(absolute, absolute + ".bak")!=OK: return false
	elif not FileAccess.file_exists(path + ".bak") or not valid(parse_save(path + ".bak")):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(temp),absolute+".bak")!=OK: return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) != OK: return false
	return true

func load_game(path: String = "") -> bool:
	if path.is_empty(): path = save_directory.path_join("save.json")
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var data = parse_save(candidate)
		if not valid(data): continue
		restore_snapshot(data)
		return true
	return false
