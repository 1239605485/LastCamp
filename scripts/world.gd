extends RefCounted

const R = preload("res://scripts/rules.gd")
const Map = preload("res://scripts/world_map.gd")
const Forage = preload("res://scripts/forage.gd")
const Survival = preload("res://scripts/survival_systems.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
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
	items.clear(); enemies.clear(); graves.clear(); logs.clear(); doors.clear()
	defenses.clear()
	map = Map.new(world_seed if world_seed >= 0 else int(randi() & 0x7fffffff),4)
	serial = 0
	state = {"schema_version":1, "minute":480.0, "zone":"camp", "px":430.0, "py":440.0, "hp":100.0, "hunger":95.0, "thirst":95.0, "stamina":100.0, "bleeding":false, "wall":240.0, "core":400.0, "wave_day":0, "kills":0, "failed":false, "guard_ammo":110, "weapon":"pistol", "last_dawn":1, "threat":0, "speed":1.0}
	state["map_seed"] = map.seed; state["map_layout_version"] = 4
	capacity = R.BAG_WEIGHT
	npcs = [{"id":"lin", "name":"林舟", "job":"守卫", "status":"healthy", "hp":90.0, "zone":"camp", "x":490.0, "y":320.0, "follow":false, "xp":0}, {"id":"chen", "name":"陈阿姨", "job":"医疗", "status":"healthy", "hp":80.0, "zone":"camp", "x":545.0, "y":485.0, "follow":false, "xp":0}, {"id":"yu", "name":"小雨", "job":"维修", "status":"waiting", "hp":70.0, "zone":"town", "x":825.0, "y":285.0, "follow":false, "xp":0}]
	furniture = [{"id":"cabinet_01", "zone":"town", "x":395.0, "y":260.0, "rotation":0, "hp":90.0, "packed":false}]
	for entry in [["backpack",1],["knife",1],["pistol",1],["ammo9",42],["food",2],["water",2],["bandage",3]]:
		add_item(entry[0], entry[1], "player")
	for entry in [["knife",1],["ammo9",65],["ammo_rifle",36],["food",5],["water",6],["bandage",4],["wood",12],["parts",5]]:
		add_item(entry[0], entry[1], "warehouse")
	for entry in [["food",4,"house"],["water",2,"house"],["wood",6,"house"],["extended_mag",1,"house"],["bandage",5,"clinic"],["water",3,"clinic"],["parts",4,"clinic"],["rifle",1,"police"],["ammo_rifle",72,"police"],["suppressor",1,"police"],["ammo9",32,"police"]]:
		add_item(entry[0], entry[1], entry[2])
	for i in range(10):
		spawn_enemy("town", Vector2(550 + (i % 4) * 160, 450 + (i / 4) * 140), "normal" if i % 3 else "fast")
	note("第1天：搜刮民居、诊所与警务站。21:00 尸潮从营地北面来袭。")
	ensure_expansion()
	ensure_world_features()

func ensure_expansion():
	if state.get("content_version",0) >= 2: return
	for definition in R.Catalog.GUNS: add_item(definition,1,"armory")
	for definition in R.Catalog.PARTS: add_item(definition,1,"armory")
	for definition in ["ammo9","ammo_rifle","ammo_makarov","ammo45","ammo357","ammo545","ammo556","ammo76254","ammo12"]: add_item(definition,60,"armory")
	var rng = RandomNumberGenerator.new(); rng.seed = map.seed
	for b in map.buildings:
		if b.container in ["house","clinic","police"]: continue
		add_item("food" if b.kind == "house" else "bandage",rng.randi_range(1,3),b.container)
		add_item("water",rng.randi_range(1,3),b.container)
		var weapon_index = rng.randi_range(0,R.Catalog.GUNS.size() - 1)
		var weapon: String = R.Catalog.GUNS[weapon_index]
		if b.kind in ["police","shop"] or rng.randf() < 0.25:
			add_item(weapon,1,b.container)
			add_item(R.ITEMS[weapon].ammo,rng.randi_range(12,40),b.container)
			add_item(R.Catalog.PARTS[rng.randi_range(0,R.Catalog.PARTS.size() - 1)],1,b.container)
		else: add_item("wood",rng.randi_range(2,6),b.container)
		var center: Vector2 = b.rect.get_center()
		spawn_enemy("town",center + Vector2(190,80),"fast" if rng.randf() < 0.3 else "normal")
	for item in items.values():
		if item.has("slots"):
			var mag_id = item.slots.get("mag","")
			item["mag_bonus"] = R.ITEMS[items[mag_id].def].get("effects",{}).get("capacity_add",0) if items.has(mag_id) else 0
	state["content_version"] = 2; state["map_seed"] = map.seed
	state["explored"] = [map.sector_id(Vector2(95,490))]; state["control_mode"] = "mini"
	note("军械补给箱已备好16种枪械和14种配件，地图记录已开启。")

func ensure_world_features():
	Survival.ensure(self)
	Tactics.ensure(self)
	if not state.get("v5_starter_resources",false):
		add_item("battery",2,"warehouse"); add_item("fuel",2,"warehouse")
		state["v5_starter_resources"]=true
	if not state.has("harvests"): state["harvests"] = {}
	if not state.has("searched"): state["searched"] = {}
	if state.get("world_features_version",0) >= 3: return
	var rng = RandomNumberGenerator.new(); rng.seed = map.seed + 3947
	for car in map.cars_at(map.size / 2,20000,"town") + map.cars_at(Vector2(600,500),2000,"camp"):
		add_item(["food","water","bandage","parts"][rng.randi_range(0,3)],rng.randi_range(1,3),car.id)
		add_item("ammo9",rng.randi_range(4,14),car.id)
	state["world_features_version"] = 3
	var geometry = load("res://scripts/building_geometry.gd")
	for f in furniture:
		if f.id == "cabinet_01" and f.zone == "town" and not f.packed and Vector2(f.x,f.y).distance_to(Vector2(395,260)) < 1:
			var p = geometry.point(map.buildings[0],Vector2(185,151)); f.x = p.x; f.y = p.y
	for n in npcs:
		if n.id == "yu" and n.status == "waiting":
			var p = geometry.loot_point(map.buildings[1]); n.x = p.x; n.y = p.y

func map_for_state(data: Dictionary):
	var map_seed = int(data.get("map_seed",471113)); var version = int(data.get("map_layout_version",2))
	return map if map.seed == map_seed and map.layout_version == version else Map.new(map_seed,version)

func build_defense(kind: String, pos: Vector2) -> bool:
	var definitions = {"barricade":{"wood":4,"parts":0,"hp":180},"wire":{"wood":1,"parts":2,"hp":90},"guardpost":{"wood":6,"parts":3,"hp":150}}
	if state.zone != "camp" or not definitions.has(kind) or defenses.size() >= 24: return false
	var definition: Dictionary = definitions[kind]
	for material in ["wood","parts"]:
		if count_item(material) + count_item(material,"warehouse") < definition[material]: return false
	for material in ["wood","parts"]:
		var take = mini(count_item(material),definition[material]); consume(material,take); consume(material,definition[material] - take,"warehouse")
	defenses.append({"id":uid("defense_"),"kind":kind,"x":pos.x,"y":pos.y,"hp":float(definition.hp),"max_hp":float(definition.hp),"cd":0.0})
	note("营地城防已建成：" + {"barricade":"木制路障","wire":"铁丝阻拦","guardpost":"守卫哨位"}[kind])
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

func transfer(id: String, target: String) -> bool:
	if not items.has(id): return false
	var item = items[id]
	if item.owner == target: return false
	var incoming = R.ITEMS[item.def].weight * item.qty + weight(id)
	if target == "player" and weight("player") + incoming > capacity: return false
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
		var quantity = Forage.commit(state.harvests,plant.id,plant.kind,int(state.minute))
		if quantity <= 0: return false
		add_item(plant.kind,quantity,"player")
		note("采集获得%s ×%d" % [R.ITEMS[plant.kind].name,quantity]); return true
	return false

func pack_furniture(id: String) -> bool:
	for f in furniture:
		if f.id != id: continue
		if f.packed or not owned(id).is_empty() or weight("player") + 5 > capacity: return false
		f.packed = true
		items[id] = {"id":id, "def":"cabinet", "owner":"player", "qty":1}
		return true
	return false

func place_furniture(id: String, zone: String, pos: Vector2) -> bool:
	if not items.has(id) or items[id].owner != "player": return false
	for f in furniture:
		if f.id == id and f.packed:
			f.zone = zone; f.x = pos.x; f.y = pos.y; f.packed = false; items.erase(id)
			return true
	return false

func die():
	var id = uid("grave_")
	graves.append({"id":id, "zone":state.zone, "x":state.px, "y":state.py})
	for i in owned("player"): i.owner = id
	for npc in npcs:
		if npc.follow and npc.status != "down": npc.follow = false; npc["retreat_until"] = state.minute + 45
	state.hp = 65.0; state.bleeding = false; state.weapon = "knife"
	state["weapon_id"] = ""
	advance(60, true)
	state.zone = "camp"; state.px = 430.0; state.py = 440.0
	note("负伤回营，经过1小时。全部随身物品留在遗物中。")

func spawn_enemy(zone: String, pos: Vector2, kind: String, wave: bool = false):
	enemies.append({"id":uid("z_"), "zone":zone, "x":pos.x, "y":pos.y, "hp":100.0 if kind == "breaker" else (40.0 if kind == "fast" else 65.0), "kind":kind, "wave":wave, "cd":0.0, "alert":0.0, "tx":pos.x, "ty":pos.y})

func note(message: String):
	logs.append(message)
	if logs.size() > 30: logs.pop_front()

func tick(delta: float):
	if paused or state.failed: return
	advance(delta * 1440.0 / R.DAY_SECONDS * state.speed)

func advance(minutes: float, recovering: bool = false):
	if state.failed: return
	var left = minutes
	while left > 0:
		var step = minf(left, 1.0)
		state.minute += step; left -= step
		Survival.advance(self,step)
		Tactics.advance_offscreen(self,step)
		if recovering and state.zone=="camp": Tactics.trigger_contacts(self,"camp")
		state.hunger = maxf(0, state.hunger - step * 0.018)
		state.thirst = maxf(0, state.thirst - step * 0.024)
		if state.hunger <= 0 or state.thirst <= 0: state.hp -= step * 0.06
		if state.bleeding: state.hp -= step * 0.12
		var day = int(state.minute / 1440) + 1
		if int(state.minute) % 1440 >= 1260 and state.wave_day < day:
			state.wave_day = day
			state["wave_active"] = true
			state["wave_start_ammo"] = state.guard_ammo
			state["wave_start_wall"] = state.wall
			for i in range(12 + mini(day, 4) * 3):
				spawn_enemy("camp", Vector2(310 + (i % 7) * 35, 50 + (i / 7) * 24), ["normal","normal","fast","breaker"][i % 4], true)
			note("无线电：北侧尸潮来袭！守卫开始消耗营地弹药。")
		if state.zone != "camp" or recovering: offscreen_camp(step)
		finish_wave()
		for npc in npcs:
			if npc.has("retreat_until") and state.minute >= npc.retreat_until:
				npc.zone = "camp"; npc.x = 490; npc.y = 330; npc.erase("retreat_until")
			if npc.zone == "camp" and npc.status == "injured":
				npc.hp = minf(90, npc.hp + step * 0.15)
				if npc.hp >= 85: npc.status = "healthy"
		state["work_minutes"] = state.get("work_minutes", 0.0) + step
		if state.work_minutes >= 20:
			state.work_minutes -= 20
			for worker in npcs:
				if worker.zone != "camp" or worker.follow or worker.status in ["down","waiting"]: continue
				if worker.job == "维修" and state.wall < 240 and consume("wood",1,"warehouse"):
					state.wall = minf(240,state.wall + 28); worker.xp += 2
					if state.wall < 100: note("无线电：维修工修补北墙，消耗木材1。")
				if worker.job == "医疗":
					for patient in npcs:
						if patient.zone == "camp" and patient.status == "injured" and consume("bandage",1,"warehouse"):
							patient.hp = minf(90,patient.hp + 14); worker.xp += 2
							if patient.hp >= 85: patient.status = "healthy"
		if state.core <= 0:
			state.failed = true; note("核心失守。请读取清晨恢复点重试。")
			break
		if int(state.minute / 1440) * 1440 + 480 <= state.minute and state.last_dawn < day:
			state.last_dawn = day
			note("第%d天清晨：防线与库存保留。请治疗、修理、准备下次出发。" % day)
			save_game(dawn_path())

func offscreen_camp(minutes: float):
	var remaining = enemies.filter(func(e): return e.zone == "camp" and e.hp > 0)
	var guards = npcs.filter(func(n): return n.zone == "camp" and n.status != "down" and n.status != "waiting" and n.job == "守卫" and not n.get("hold_fire",false))
	for e in remaining:
		e.y = minf(285, e.y + minutes * 26)
		if e.y < 260: continue
		if state.wall > 0: state.wall = maxf(0, state.wall - minutes * (2.4 if e.kind == "breaker" else 0.8))
		else:
			var blockers = defenses.filter(func(d): return d.hp>0 and d.kind!="guardpost" and d.y<400 and d.y>260 and absf(d.x-e.x)<70)
			if not blockers.is_empty(): blockers[0].hp = maxf(0,blockers[0].hp - minutes*1.5)
			else: state.core = maxf(0,state.core-minutes*0.8)
	if not remaining.is_empty() and not guards.is_empty() and state.guard_ammo > 0:
		var posts = defenses.filter(func(d): return d.hp>0 and d.kind=="guardpost").size()
		state["guard_fraction"] = state.get("guard_fraction", 0.0) + minutes * (1.5 + mini(posts,3)*0.7)
		while state.guard_fraction >= 1 and state.guard_ammo > 0:
			state.guard_fraction -= 1; state.guard_ammo -= 1
			var target = remaining.filter(func(e): return e.hp > 0)
			if target.is_empty(): break
			target[0].hp -= 30
	enemies = enemies.filter(func(e): return e.hp > 0)

func finish_wave():
	if not state.get("wave_active",false) or state.failed: return
	if enemies.any(func(e): return e.wave and e.hp > 0): return
	state.wave_active = false
	state["battle_report"] = {"day":state.wave_day,"ammo":state.get("wave_start_ammo",state.guard_ammo) - state.guard_ammo,"wall_lost":maxf(0,state.get("wave_start_wall",state.wall) - state.wall),"core":state.core,"down":npcs.filter(func(n): return n.status == "down").size()}
	state["report_seen"] = false
	note("无线电：本夜尸潮已清除。防线、人员和消耗已记录，请整理营地。")

func snapshot() -> Dictionary:
	return {"schema_version":1, "state":state.duplicate(true), "items":items.duplicate(true), "npcs":npcs.duplicate(true), "furniture":furniture.duplicate(true), "enemies":enemies.duplicate(true), "graves":graves.duplicate(true), "logs":logs.duplicate(), "doors":doors.duplicate(), "serial":serial,"defenses":defenses.duplicate(true)}

func valid(data) -> bool:
	if not data is Dictionary or data.get("schema_version") != 1: return false
	for key in ["state","items","npcs","furniture","enemies","graves","logs","doors","serial"]:
		if not data.has(key): return false
	if not data.state is Dictionary or not data.items is Dictionary: return false
	if not Survival.valid_state(data.state): return false
	if not Tactics.valid_state(data.state): return false
	for key in ["npcs","furniture","enemies","graves","logs"]:
		if not data[key] is Array: return false
	if not data.doors is Dictionary: return false
	for key in ["minute","px","py","hp","hunger","thirst","stamina","wall","core","wave_day","guard_ammo","last_dawn","speed"]:
		if not data.state.has(key) or not (data.state[key] is float or data.state[key] is int): return false
	if data.state.get("zone","") not in ["camp","town"] or not data.state.has("failed") or not R.ITEMS.has(data.state.get("weapon","")): return false
	if data.state.has("harvests"):
		if not data.state.harvests is Dictionary: return false
		for ready_minute in data.state.harvests.values():
			if not (ready_minute is float or ready_minute is int) or not is_finite(float(ready_minute)) or ready_minute < 0: return false
	var owners: Array = ["player","warehouse","house","clinic","police","armory"]
	for event in data.state.get("systems_v5",{}).get("events",[]): owners.append(event.id)
	var data_map = map_for_state(data.state)
	for b in data_map.buildings: owners.append(b.container)
	for car in data_map.cars_at(data_map.size / 2,20000,"town") + data_map.cars_at(Vector2(600,500),2000,"camp"): owners.append(car.id)
	if data.has("defenses"):
		if not data.defenses is Array: return false
		for defense in data.defenses:
			if not defense is Dictionary or not defense.has("kind") or not defense.has("hp") or not defense.has("x") or not defense.has("y"): return false
	for key in ["npcs","furniture","enemies","graves"]:
		for entity in data[key]:
			if not entity is Dictionary or not entity.has("id") or not entity.has("x") or not entity.has("y") or entity.get("zone","") not in ["camp","town"]: return false
			owners.append(entity.id)
	for npc in data.npcs:
		if not npc.has("status") or not npc.has("hp") or not npc.has("follow") or not npc.has("job"): return false
	for f in data.furniture:
		if not f.has("packed") or not f.has("hp"): return false
	for e in data.enemies:
		if not e.has("hp") or not e.has("kind") or not e.has("wave") or not e.has("cd") or not e.has("alert") or not e.has("tx") or not e.has("ty"): return false
	for id in data.items:
		var item = data.items[id]
		if not item is Dictionary or not R.ITEMS.has(item.get("def", "")) or item.get("id","") != id or not item.has("owner") or item.get("qty", 0) <= 0: return false
		var owner = item.owner; var seen: Array = [id]
		while data.items.has(owner):
			if owner in seen: return false
			seen.append(owner); owner = data.items[owner].get("owner","")
		if owner not in owners: return false
		if R.ITEMS[item.def].has("capacity"):
			if not item.has("ammo") or not item.get("slots") is Dictionary: return false
			for slot_id in item.slots.values():
				if not data.items.has(slot_id) or data.items[slot_id].owner != id: return false
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
		DirAccess.copy_absolute(absolute, absolute + ".bak")
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), absolute) != OK: return false
	if not FileAccess.file_exists(path + ".bak") or not valid(parse_save(path + ".bak")):
		return DirAccess.copy_absolute(absolute, absolute + ".bak") == OK
	return true

func load_game(path: String = "") -> bool:
	if path.is_empty(): path = save_directory.path_join("save.json")
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var data = parse_save(candidate)
		if not valid(data): continue
		state = data.state; items = data.items; npcs = data.npcs; furniture = data.furniture
		enemies = data.enemies; graves = data.graves; logs = data.logs; doors = data.doors; serial = int(data.serial)
		map = map_for_state(state); defenses = data.get("defenses",[])
		ensure_expansion()
		ensure_world_features()
		return true
	return false
