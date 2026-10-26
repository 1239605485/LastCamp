extends SceneTree

var checks = 0
var failures = 0
func expect(value: bool,label: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); game.world.save_directory = "user://world-v03-tests"
	root.add_child(game); await process_frame
	game.world.new_world(1234); game.hud.close_panel()
	var G = load("res://scripts/building_geometry.gd")
	game.world.state.zone = "town"; var house = game.world.map.buildings[0]
	game.set_pos(house.rect.get_center())
	expect(G.interior(house).has_point(G.point(house,Vector2(110,140))),"source sprite offset puts lower hallway inside walkable interior")
	expect(absf(G.outside_frame(house,Vector2(229,290)).end.y-G.frame(house).end.y)<2,"exterior and interior share original ground baseline")
	expect(game.blocked(G.point(house,Vector2(200,55))),"rear wall/stair projection is not walkable")
	expect(not game.blocked(G.loot_point(house)),"actual interior has a reachable loot point")
	var door = G.door(house); var outside = door.get_center()+Vector2(0,20)
	var closed = game.move_with_collision(outside,Vector2(0,-45))
	expect(closed.y > door.position.y,"closed source doorway blocks movement without tunneling")
	game.world.doors[house.container+"0"] = true
	var opened = game.move_with_collision(outside,Vector2(0,-45))
	expect(opened.y < door.position.y,"opened source doorway allows entering actual floor")
	var shop = game.world.map.buildings.filter(func(b): return b.art=="b_gunshop")[0]
	game.set_pos(shop.rect.get_center())
	var shop_start = G.point(shop,Vector2(94,140)); var shop_end = G.point(shop,Vector2(94,110))
	var shop_stop = game.move_with_collision(shop_start,shop_end-shop_start)
	expect(shop_stop.y > G.point(shop,Vector2(94,122)).y,"closed gunshop door covers actual off-centre entrance gap")
	var car = game.world.map.cars_at(Vector2(600,500),2000,"camp")[0]
	game.world.state.zone = "camp"; game.set_pos(car.trunk_pos + Vector2(20,0))
	expect(game.blocked(car.pos),"rendered car has physical body")
	var trees = game.world.map.trees_at(Vector2(600,500),900,"camp")
	expect(not trees.is_empty() and game.blocked(trees[0].pos),"rendered tree trunk has physical body")
	if not game.has_method("is_searching"):
		expect(false,"search progress/crouch service exists"); game.queue_free(); await process_frame; quit(1); return
	game.interact()
	expect(game.is_searching(),"car trunk starts timed search before opening loot")
	var count = game.world.owned(car.id).size(); game.damage_player(1)
	expect(game.action.is_empty() and not game.world.state.searched.has(car.id),"damage interrupts search without completing")
	game.last_damage = 0; game.interact(); game.complete_action()
	expect(game.world.state.searched.has(car.id) and game.hud.panel_kind == "loot" and game.world.owned(car.id).size() == count,"successful search opens original trunk contents without transfer")
	game.hud.close_panel(); game.world.state.zone = "town"; game.world.enemies.clear(); game.set_pos(Vector2(1150,900))
	game.world.spawn_enemy("town",Vector2(800,490),"normal"); var original = Vector2(800,490)
	for i in range(120): game.update_enemies(0.1)
	expect(Vector2(game.world.enemies[0].x,game.world.enemies[0].y).distance_to(original) > 10,"unalerted zombies actually wander")
	game.world.state.zone = "camp"; game.world.state.px = 430; game.world.state.py = 440
	expect(game.world.build_defense("barricade",Vector2(600,300)),"camp barricade consumes available building materials")
	game.world.save_game("user://tests/world-v03.json")
	var other = load("res://scripts/world.gd").new(); expect(other.load_game("user://tests/world-v03.json"),"seeded world and trunk save loads")
	expect(other.map.seed == 1234 and other.map.buildings == game.world.map.buildings and other.defenses.size() == 1,"seed and defenses persist without regeneration")
	game.world.new_world(); var first_seed = game.world.map.seed; game.world.new_world()
	expect(first_seed != game.world.map.seed,"new games select fresh seeds")
	var art = load("res://scripts/art.gd").new()
	for id in load("res://scripts/rules.gd").ITEMS:
		expect(art.icon(id) != null,"inventory icon exists: " + id)
	game.queue_free(); await create_timer(0.2).timeout
	print("WORLD V03 RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
