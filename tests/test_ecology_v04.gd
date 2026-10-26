extends SceneTree
var failures = 0
var checks = 0
func expect(value: bool,label: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: "+label)
func _initialize():
	var Map = load("res://scripts/world_map.gd")
	var a = Map.new(471113,4)
	var b = Map.new(471113,4)
	expect(a.settlements.size() >= 5 and a.settlements.size() <= 8,"five to eight concentrated towns")
	expect(a.buildings == b.buildings and a.roads == b.roads,"v4 layout deterministic")
	if not a.has_method("plants_at") or not ResourceLoader.exists("res://scripts/forage.gd"):
		expect(false,"plant queries and harvest helper exist")
		quit(1); return
	for map_seed in range(10):
		var m = Map.new(map_seed,4)
		var reached = [m.settlements[0]]
		for sweep in range(m.roads.size()):
			for road in m.roads:
				if reached.has(road.a) and not reached.has(road.b): reached.append(road.b)
				if reached.has(road.b) and not reached.has(road.a): reached.append(road.a)
		for c in m.settlements: expect(reached.has(c),"towns share a connected road network")
		var isolated = 0
		for building in m.buildings:
			var close = false
			for c in m.settlements:
				if c.distance_to(building.rect.get_center()) < 1150: close = true
			if not close: isolated += 1
			expect(not m.water_at(building.rect.get_center()),"building on mainland")
			for road in m.roads:
				expect(not m._segment_hits_rect(road.a,road.b,building.rect.grow(25)),"roads do not cross building footprints")
		expect(isolated >= 4 and isolated <= 6,"only a handful of isolated buildings")
		for c in m.settlements:
			var count = 0
			for building in m.buildings:
				if c.distance_to(building.rect.get_center()) < 1150: count += 1
			expect(count >= 8 and count <= 16,"town contains eight to sixteen buildings (%d)" % count)
	var plants = a.plants_at(Vector2(5000,4400),6500)
	expect(plants == b.plants_at(Vector2(5000,4400),6500),"plant IDs stable across query order")
	var kinds = {}
	var ids = {}
	for plant in plants:
		expect(not ids.has(plant.id),"unique harvest identity")
		ids[plant.id] = true; kinds[plant.kind] = true
		expect(a.terrain_at(plant.pos) not in ["water","shore"] and not a.road_at(plant.pos),"plant outside water shore and roads")
		for building in a.buildings:
			expect(not building.rect.grow(70).has_point(plant.pos),"plant outside building access margin")
	expect(kinds.size() >= 4 and plants.size() > 150,"varied plentiful edible plants")
	var sample = a.plants_at(Vector2(3500,3500),800)
	for i in range(220): a.plants_at(Vector2(i % 20 * 512,i / 20 * 512),100)
	expect(a._plant_cache.size() <= 160 and a.plants_at(Vector2(3500,3500),800) == sample,"bounded cache eviction preserves plants")
	var F = load("res://scripts/forage.gd")
	var harvests = {}
	expect(F.ready(harvests,"p",500),"unharvested plant ready")
	expect(F.commit(harvests,"p","berry",500) > 0,"completed harvest gives food")
	expect(not F.ready(harvests,"p",500) and F.commit(harvests,"p","berry",500) == 0,"cannot double harvest")
	var restored = JSON.parse_string(JSON.stringify(harvests))
	expect(not F.ready(restored,"p",501),"reload preserves cooldown")
	expect(not F.ready(restored,"p",500+2879) and F.ready(restored,"p",500+2880),"berries regenerate at forty eight hours")
	expect(F.commit(harvests,"fruit","apple",500) > 0 and not F.ready(harvests,"fruit",500+2880) and F.ready(harvests,"fruit",500+4320),"fruit tree regenerates after seventy two hours")
	print("ECOLOGY V04 RESULT: %d checks, %d failures; %d plants" % [checks,failures,plants.size()])
	quit(1 if failures else 0)
