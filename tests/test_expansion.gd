extends SceneTree

var checks = 0
var failures = 0

func expect(value: bool, label: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + label)

func _initialize():
	var R = load("res://scripts/rules.gd")
	var guns = R.ITEMS.values().filter(func(d): return d.has("capacity"))
	var parts = R.ITEMS.values().filter(func(d): return d.has("slot"))
	expect(guns.size() >= 16,"at least sixteen distinct guns")
	expect(parts.size() >= 14,"at least fourteen attachments")
	if not R.has_method("weapon_stats") or not ResourceLoader.exists("res://scripts/world_map.gd"):
		expect(false,"weapon effects and large-map service exist")
		print("EXPANSION RESULT: %d checks, %d failures" % [checks,failures]); quit(1); return
	var w = load("res://scripts/world.gd").new(); w.new_world()
	var gun = w.add_item("m4",1,"player")
	var suppressor = w.add_item("rifle_suppressor",1,"player")
	var original = R.weapon_stats(w.items[gun],w.items)
	expect(w.attach(gun,suppressor),"rifle suppressor installs on matching rifle interface")
	expect(R.weapon_stats(w.items[gun],w.items).noise < original.noise,"suppressor reduces actual noise")
	var optic = w.add_item("scope4x",1,"player")
	expect(w.attach(gun,optic),"optic uses its own slot")
	expect(R.weapon_stats(w.items[gun],w.items).range > original.range,"scope changes firing range")
	var wrong = w.add_item("suppressor",1,"player")
	expect(not w.attach(gun,wrong) and w.items[wrong].owner == "player","wrong muzzle does not disappear")
	var fast = w.add_item("quick_mag",1,"player")
	expect(w.attach(gun,fast),"quick magazine installs")
	expect(R.weapon_stats(w.items[gun],w.items).reload < original.reload,"quick magazine changes reload duration")
	w.items[gun].ammo = 0
	w.add_item("ammo9",30,"player")
	expect(not w.reload_weapon(gun),"9mm cannot reload 5.56 rifle")
	w.add_item("ammo556",12,"player")
	expect(w.reload_weapon(gun) and w.items[gun].ammo == 12,"correct cartridge count is consumed")
	var world_map = load("res://scripts/world_map.gd").new()
	expect(world_map.size.x >= 10000 and world_map.buildings.size() > 80,"continuous large map contains many enterable locations")
	var same = load("res://scripts/world_map.gd").new()
	expect(world_map.buildings == same.buildings,"map generation is deterministic")
	expect(world_map.buildings_at(Vector2(5000,5000),1800).size() < world_map.buildings.size(),"distant buildings are culled")
	expect(w.state.get("content_version",0) >= 2 and w.owned("armory").size() > 20,"new equipment is available in persistent armory")
	var item_count = w.items.size(); w.ensure_expansion()
	expect(w.items.size() == item_count,"upgrade cannot duplicate armory or map loot")
	var far = w.map.buildings.back().container
	expect(w.owned(far).size() > 0,"remote location has persistent loot")
	w.save_game("user://tests/expansion.json")
	var other = load("res://scripts/world.gd").new()
	expect(other.load_game("user://tests/expansion.json") and other.owned(far).size() == w.owned(far).size(),"remote container survives save and reload")
	if w.has_method("equip"):
		var duplicate_gun = w.add_item("m4",1,"player")
		expect(w.equip(duplicate_gun) and w.player_weapon("m4") == duplicate_gun,"same-model weapons equip by instance rather than first match")
	else: expect(false,"weapon instance selection exists")
	var legacy = load("res://scripts/world.gd").new()
	expect(legacy.load_game("res://tests/fixtures/v0.1-dawn.json"),"real v0.1 save upgrades without reset")
	expect(legacy.state.minute == 480 and legacy.items["item_3"].owner == "player" and legacy.items["item_3"].ammo == 12,"upgrade retains clock and original weapon identity")
	var upgraded_count = legacy.items.size(); legacy.ensure_expansion()
	expect(legacy.items.size() == upgraded_count and legacy.owned("armory").size() > 20,"legacy expansion grants armory exactly once")
	var stored = w.add_item("pm",1,"player"); w.equip(stored); w.transfer(stored,"warehouse")
	expect(w.state.weapon != "pm","stored last equipped weapon no longer appears usable")
	w.items[stored].ammo = 0; w.add_item("ammo_makarov",8,"player")
	expect(not w.reload_weapon(stored),"reload cannot alter a weapon no longer owned by player")
	print("EXPANSION RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)

