extends SceneTree
var failures = 0
var checks = 0
func expect(value: bool,label: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: "+label)
func _initialize():
	var Map = load("res://scripts/world_map.gd")
	var a = Map.new(471113,3)
	var b = Map.new(471113,3)
	var c = Map.new(982331,3)
	expect(a.buildings == b.buildings and a.roads == b.roads,"same seed reproducible")
	expect(a.buildings != c.buildings and a.roads != c.roads,"new seed changes full map")
	for value in [a,b,c]:
		expect(value.buildings.size() > 80,"expanded irregular settlements >80 buildings (%d)" % value.buildings.size())
		for p in value.settlements:
			expect(value.road_at(p),"all settlement centres connected to transport")
		# Roads are a tree with each centre attached to a predecessor, plus local arms.
		var reached = [value.settlements[0]]
		for sweep in range(value.roads.size()):
			for road in value.roads:
				if reached.has(road.a) and not reached.has(road.b): reached.append(road.b)
				if reached.has(road.b) and not reached.has(road.a): reached.append(road.a)
		for p in value.settlements: expect(reached.has(p),"settlement reachable in road graph")
		for road in value.roads:
			for step in range(11):
				expect(not value.water_at(road.a.lerp(road.b,step/10.0)),"road traversable on mainland")
		for building in value.buildings:
			expect(not value.water_at(building.rect.get_center()),"building on land")
	for random_seed in range(10):
		var sampled = Map.new(random_seed,3)
		expect(sampled.buildings.size() > 80,"seed sweep minimum capacity %d (%d)" % [random_seed,sampled.buildings.size()])
	var trees = a.trees_at(Vector2(2500,2500))
	expect(trees == b.trees_at(Vector2(2500,2500)),"tree IDs and positions stable")
	for tree in trees: expect(tree.trunk.size == Vector2(12,8),"tree tiny original trunk collision")
	var cars = a.cars_at(Vector2(900,600),300,"camp")
	expect(cars.size() >= 1,"accessible camp car")
	for car in cars:
		expect(car.body.size == Vector2(92,35),"source car body")
		expect(not car.body.has_point(car.trunk_pos),"car trunk outside collision")
	expect(a.cars_at(Vector2(4000,4000),6000) == b.cars_at(Vector2(4000,4000),6000),"town cars stable")
	var old = Map.new(471113,2)
	expect(old.buildings.size() == 129 and old.container_pos("site_7_7_1") != Vector2(-999,-999),"v02 loot IDs retained")
	expect(old.container_pos("house") == Vector2(265,350),"starter loot position retained")
	print("MAP V03 RESULT: %d checks, %d failures; %d buildings, %d settlements" % [checks,failures,a.buildings.size(),a.settlements.size()])
	quit(1 if failures else 0)

