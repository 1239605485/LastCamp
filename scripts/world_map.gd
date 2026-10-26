extends RefCounted

# Regions describe discovery only: geography and roads never repeat per sector.
const LegacyMap = preload("res://scripts/legacy_map.gd")
const SECTOR = Vector2(1280,1120)
const GRID = 8
const ROAD_WIDTH = 88.0
var size = Vector2(10240,8960)
var seed = 471113
var layout_version = 3
var buildings: Array = []
var sectors: Array = []
var roads: Array = []
var settlements: Array = []
var water_regions: Array = []
var _legacy
var _noise = FastNoiseLite.new()
var _tree_cache: Dictionary = {}
var _plant_cache: Dictionary = {}
var _cars: Array = []

func _init(map_seed: int = 471113, version: int = 3):
	seed = map_seed
	layout_version = version
	_noise.seed = seed
	_noise.frequency = 0.00065
	_noise.fractal_octaves = 3
	if version <= 2:
		_legacy = LegacyMap.new()
		buildings = _legacy.buildings
		sectors = _legacy.sectors
		for x in range(8):
			roads.append({"a":Vector2(x * 1280 + 610,0),"b":Vector2(x * 1280 + 610,size.y)})
		for y in range(8):
			roads.append({"a":Vector2(0,y * 1120 + 490),"b":Vector2(size.x,y * 1120 + 490)})
	elif version >= 4:
		_generate_v4()
	else:
		_generate()
	_generate_cars()

func _generate():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	buildings = [
		{"name":"榆树街民居","rect":Rect2(210,170,290,250),"container":"house","kind":"house","art":"b_city_house_1"},
		{"name":"社区诊所","rect":Rect2(720,150,290,250),"container":"clinic","kind":"clinic","art":"b_hospital"},
		{"name":"警务站","rect":Rect2(480,610,330,260),"container":"police","kind":"police","art":"b_police_station"}]
	settlements.append(Vector2(610,490))
	# Poisson-like rejection creates irregular settlements across a single mainland.
	for attempt in range(1200):
		if settlements.size() >= 23: break
		var p = Vector2(rng.randf_range(900,9000),rng.randf_range(1300,8000))
		var clear = true
		for q in settlements:
			if p.distance_to(q) < 1300: clear = false; break
		if clear: settlements.append(p)
	# Each new centre links to its nearest predecessor, a connected spanning tree.
	roads.append({"a":settlements[0],"b":Vector2(1150,490)})
	for i in range(1,settlements.size()):
		var a: Vector2 = settlements[i]
		var nearest: Vector2 = settlements[0]
		for j in range(i):
			if a.distance_squared_to(settlements[j]) < a.distance_squared_to(nearest): nearest = settlements[j]
		if nearest == settlements[0]: nearest = Vector2(1150,490)
		roads.append({"a":a,"b":nearest})
	for c in settlements:
		roads.append({"a":c - Vector2(550,0),"b":c})
		roads.append({"a":c,"b":c + Vector2(550,0)})
	var names = ["榆树镇","风车坡","松溪聚落","废弃工场","青石村","远山哨所","白桦屯","旧车站"]
	for i in range(settlements.size()):
		var c: Vector2 = settlements[i]
		var name: String = names[i % names.size()] + ("" if i == 0 else "·%d" % i)
		sectors.append({"id":"region_%d" % i,"name":name,"kind":"city" if i % 5 == 0 else "village","center":c,"rect":Rect2(c - Vector2(700,650),Vector2(1400,1300))})
		if i == 0: continue
		# Houses face one shared street; irregular gaps and sizes avoid stamped blocks.
		for side in [-1,1]:
			for slot in range(4):
				var width = rng.randf_range(185,245)
				var height = rng.randf_range(170,225)
				var p = c + Vector2(-530 + slot * 285 + rng.randf_range(-16,16),95 if side == 1 else -95 - height)
				var rect = Rect2(p,Vector2(width,height))
				var clear = true
				for road in roads:
					# Keep main transport corridors outside every building footprint.
					if _segment_hits_rect(road.a,road.b,rect.grow(50)): clear = false; break
				if not clear: continue
				var kinds = ["house","house","clinic","police","shop","house"]
				var kind: String = kinds[rng.randi_range(0,kinds.size()-1)]
				var art: String = {"house":"b_city_house_2","clinic":"b_hospital","police":"b_police_station","shop":"b_gunshop"}[kind]
				buildings.append({"name":name + "·" + {"house":"民居","clinic":"医疗站","police":"警务点","shop":"武器铺"}[kind],"rect":rect,"container":"site_v3_%d_%d_%d" % [i,side,slot],"kind":kind,"art":art})
	# One winding eastern shore, attached to the boundary, never partitions land.
	for y in range(0,8961,160):
		water_regions.append({"rect":Rect2(_shore_x(y),y,10240-_shore_x(y),160)})

func _shore_x(y: float) -> float:
	return 9850 + sin(y / 1130.0 + seed % 101) * 140 + _noise.get_noise_2d(9000,y) * 130

func _generate_v4():
	var rng = RandomNumberGenerator.new()
	rng.seed = seed
	settlements = [Vector2(610,650)]
	# A connected north/south street makes the opening town a navigable junction.
	roads.append({"a":Vector2(1140,200),"b":Vector2(1140,1600)})
	# Jittered, widely spaced towns leave broad stretches of unbuilt countryside.
	for row in range(2):
		for col in range(3):
			settlements.append(Vector2(1850+col*2900,2850+row*3900)+Vector2(rng.randf_range(-200,200),rng.randf_range(-180,180)))
	for i in range(settlements.size()):
		var c: Vector2 = settlements[i]
		roads.append({"a":c-Vector2(590,0),"b":c})
		roads.append({"a":c,"b":c+Vector2(590,0)})
		if i > 0:
			var nearest: Vector2 = settlements[0]
			for j in range(i):
				if c.distance_squared_to(settlements[j]) < c.distance_squared_to(nearest): nearest = settlements[j]
			# Leave the original clinic/police blocks via the eastern street end.
			if nearest == settlements[0]: nearest += Vector2(590,0)
			roads.append({"a":c,"b":nearest})
	var names = ["榆树镇","松溪镇","青石镇","白桦镇","风车镇","远山镇","旧车站镇"]
	# Preserve the three starter addresses and container approach positions.
	buildings = [
		{"name":"榆树街民居","rect":Rect2(210,170,290,250),"container":"house","kind":"house","art":"b_city_house_1"},
		{"name":"社区诊所","rect":Rect2(720,150,290,250),"container":"clinic","kind":"clinic","art":"b_hospital"},
		{"name":"警务站","rect":Rect2(480,800,330,260),"container":"police","kind":"police","art":"b_police_station"}]
	for i in range(settlements.size()):
		var c: Vector2 = settlements[i]
		sectors.append({"id":"region_%d" % i,"name":names[i],"kind":"city" if i == 0 else "village","center":c,"rect":Rect2(c-Vector2(1150,1050),Vector2(2300,2100))})
		var count = 3 if i == 0 else 0
		var target = 10 if i == 0 else rng.randi_range(10,14)
		for ring in range(4):
			for side in [-1,1]:
				for slot in range(5):
					if count >= target: continue
					var rect = Rect2(c+Vector2(-650+slot*270,side*(240+ring*210))-Vector2(100,85),Vector2(200,170))
					if rect.position.x < 50 or rect.position.y < 50 or rect.end.y > size.y-60: continue
					var clear = true
					for road in roads:
						if _segment_hits_rect(road.a,road.b,rect.grow(65)): clear = false; break
					for existing in buildings:
						if existing.rect.grow(35).intersects(rect): clear = false; break
					if not clear: continue
					var kind: String = ["house","house","house","clinic","police","shop"][rng.randi_range(0,5)]
					buildings.append({"name":names[i]+"·"+{"house":"民居","clinic":"医疗站","police":"警务点","shop":"杂货铺"}[kind],"rect":rect,"container":"site_v4_%d_%d" % [i,count],"kind":kind,"art":{"house":"b_city_house_2","clinic":"b_hospital","police":"b_police_station","shop":"b_gunshop"}[kind]})
					count += 1
	var isolated = 0
	for attempt in range(1500):
		if isolated == 5: break
		var p = Vector2(rng.randf_range(500,9100),rng.randf_range(1500,8350))
		var clear = true
		for c in settlements:
			if c.distance_to(p) < 1550: clear = false; break
		for existing in buildings:
			if existing.rect.grow(360).has_point(p): clear = false; break
		for road in roads:
			if _segment_hits_rect(road.a,road.b,Rect2(p-Vector2(150,140),Vector2(300,280))): clear = false; break
		if not clear: continue
		buildings.append({"name":"林间农舍" if isolated % 2 == 0 else "偏僻小屋","rect":Rect2(p-Vector2(100,85),Vector2(200,170)),"container":"farm_v4_%d" % isolated,"kind":"house","art":"b_city_house_1"})
		isolated += 1
	for y in range(0,8961,160):
		water_regions.append({"rect":Rect2(_shore_x(y),y,10240-_shore_x(y),160)})

func _segment_hits_rect(a: Vector2,b: Vector2,r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b): return true
	var corners = [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in range(4):
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null: return true
	return false

func buildings_at(pos: Vector2,radius: float = 1200) -> Array:
	var area = Rect2(pos - Vector2.ONE * radius,Vector2.ONE * radius * 2)
	return buildings.filter(func(b): return b.rect.intersects(area))

func _region_index(pos: Vector2) -> int:
	var best = 0
	for i in range(1,settlements.size()):
		if pos.distance_squared_to(settlements[i]) < pos.distance_squared_to(settlements[best]): best = i
	return best

func sector_id(pos: Vector2) -> String:
	return _legacy.sector_id(pos) if _legacy != null else sectors[_region_index(pos)].id

func region_name(pos: Vector2) -> String:
	return _legacy.region_name(pos) if _legacy != null else sectors[_region_index(pos)].name

func road_at(pos: Vector2) -> bool:
	if _legacy != null: return _legacy.road_at(pos)
	for r in roads:
		if Geometry2D.get_closest_point_to_segment(pos,r.a,r.b).distance_squared_to(pos) < 44 * 44: return true
	return false

func water_at(pos: Vector2) -> bool:
	return _legacy.water_at(pos) if _legacy != null else pos.x > _shore_x(pos.y)

func terrain_at(pos: Vector2) -> String:
	if water_at(pos): return "water"
	if layout_version >= 3 and pos.x > _shore_x(pos.y)-120: return "shore"
	for c in settlements:
		if pos.distance_squared_to(c) < 620 * 620: return "urban"
	return "forest" if _noise.get_noise_2d(pos.x,pos.y) > -0.08 else "grass"

func container_pos(id: String) -> Vector2:
	for b in buildings:
		if b.container == id:
			if id == "house": return Vector2(265,350)
			if id == "clinic": return Vector2(945,330)
			if id == "police": return Vector2(740,970)
			return b.rect.end - Vector2(58,55)
	return Vector2(-999,-999)

func _prop_clear(p: Vector2,padding: float,zone: String) -> bool:
	if zone == "camp":
		# Preserve tent/campfire/warehouse, construction and entry routes.
		return not Rect2(180,120,620,560).grow(padding).has_point(p) and not Rect2(850,170,390,320).grow(padding).has_point(p)
	if p.x < padding or p.y < padding or p.x > size.x-padding or p.y > size.y-padding or water_at(p): return false
	for b in buildings:
		if b.rect.grow(padding + 60).has_point(p): return false
	return true

func _generate_cars():
	_cars.append(_car("car_starter_wreck",Vector2(1128,650),1,"town"))
	_cars.append(_car("car_camp_0",Vector2(900,600),0,"camp"))
	var rng = RandomNumberGenerator.new()
	rng.seed = seed + 9791
	for i in range(roads.size()):
		var road: Dictionary = roads[i]
		var direction: Vector2 = (road.b-road.a).normalized()
		for j in range(2):
			var p: Vector2 = road.a.lerp(road.b,rng.randf_range(0.2,0.8)) + direction.orthogonal() * 68
			if not _prop_clear(p,70,"town"): continue
			var clear = true
			for car in _cars:
				if car.pos.distance_to(p) < 150: clear = false; break
			if clear: _cars.append(_car("car_%d_%d_%d" % [seed,i,j],p,rng.randi_range(0,3),"town"))

func _car(id: String,p: Vector2,variant: int,zone: String) -> Dictionary:
	return {"id":id,"pos":p,"variant":variant,"body":Rect2(p-Vector2(46,17),Vector2(92,35)),"trunk_pos":p+Vector2(61,0),"zone":zone}

func cars_at(pos: Vector2,radius: float = 1000,zone: String = "town") -> Array:
	return _cars.filter(func(c): return c.zone == zone and c.pos.distance_squared_to(pos) <= radius * radius)

func trees_at(pos: Vector2,radius: float = 1000,zone: String = "town") -> Array:
	var result: Array = []
	# Pure per-chunk seeds make query order and cache eviction irrelevant.
	var start = Vector2i(floor((pos.x-radius)/512),floor((pos.y-radius)/512))
	var end = Vector2i(floor((pos.x+radius)/512),floor((pos.y+radius)/512))
	for y in range(maxi(start.y,0),mini(end.y,18)+1):
		for x in range(maxi(start.x,0),mini(end.x,20)+1):
			var key = "%s_%d_%d" % [zone,x,y]
			if not _tree_cache.has(key):
				if _tree_cache.size() > 160: _tree_cache.clear()
				_tree_cache[key] = _chunk_trees(x,y,zone)
			for tree in _tree_cache[key]:
				if tree.pos.distance_squared_to(pos) <= radius*radius: result.append(tree)
	return result

func _chunk_trees(x: int,y: int,zone: String) -> Array:
	var result: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([seed,x,y,zone])
	for i in range(28):
		var p = Vector2(x,y)*512 + Vector2(rng.randf_range(16,496),rng.randf_range(16,496))
		if not _prop_clear(p,15,zone): continue
		if zone == "camp" and (p.x > 1500 or p.y > 1100): continue
		if zone == "town" and (road_at(p) or (terrain_at(p) != "forest" and rng.randf() > 0.18)): continue
		var clear = true
		for car in _cars:
			if car.zone == zone and car.pos.distance_to(p) < 110: clear = false; break
		if not clear: continue
		# Original horizontal capsule radius 4 / height 12, conservatively boxed.
		result.append({"id":"tree_%d_%s_%d_%d_%d" % [seed,zone,x,y,i],"pos":p,"variant":rng.randi_range(0,3),"trunk":Rect2(p-Vector2(6,4),Vector2(12,8))})
	return result

func plants_at(pos: Vector2,radius: float = 1000,zone: String = "town") -> Array:
	var result: Array = []
	var start = Vector2i(floor((pos.x-radius)/512),floor((pos.y-radius)/512))
	var end = Vector2i(floor((pos.x+radius)/512),floor((pos.y+radius)/512))
	for y in range(maxi(start.y,0),mini(end.y,17)+1):
		for x in range(maxi(start.x,0),mini(end.x,19)+1):
			var key = "%s_%d_%d" % [zone,x,y]
			if not _plant_cache.has(key):
				if _plant_cache.size() >= 160: _plant_cache.clear()
				_plant_cache[key] = _chunk_plants(x,y,zone)
			for plant in _plant_cache[key]:
				if plant.pos.distance_squared_to(pos) <= radius*radius: result.append(plant)
	return result

func _chunk_plants(x: int,y: int,zone: String) -> Array:
	var result: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = hash([seed,layout_version,"edible",x,y,zone])
	for i in range(12):
		var p = Vector2(x,y)*512 + Vector2(rng.randf_range(40,472),rng.randf_range(40,472))
		if zone == "camp":
			if p.x > 1450 or p.y > 1000 or not _prop_clear(p,65,zone): continue
		else:
			if not _prop_clear(p,40,zone) or p.x > _shore_x(p.y)-200: continue
			var clear_road = true
			for road in roads:
				if Geometry2D.get_closest_point_to_segment(p,road.a,road.b).distance_to(p) < 100: clear_road = false; break
			if not clear_road: continue
		var clear = true
		for plant in result:
			if plant.pos.distance_to(p) < 85: clear = false; break
		for car in _cars:
			if car.zone == zone and car.pos.distance_to(p) < 130: clear = false; break
		if not clear: continue
		var orchard = false
		for c in settlements:
			if c.distance_to(p) < 1450: orchard = true; break
		var choices = ["apple","apple","tomato","squash","berry"] if orchard else ["berry","berry","tomato","squash","apple"]
		result.append({"id":"plant_%d_v%d_%s_%d_%d_%d" % [seed,layout_version,zone,x,y,i],"pos":p,"kind":choices[rng.randi_range(0,choices.size()-1)]})
	return result


