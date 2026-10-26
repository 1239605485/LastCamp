extends SceneTree

var failures = 0
var checks = 0

func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func _initialize():
	var script = load("res://scripts/world.gd")
	if script == null:
		printerr("FAIL: World state implementation missing")
		quit(1)
		return
	var w = script.new()
	w.new_world()
	var id = w.add_item("food", 2, "house")
	w.capacity = 0
	expect(not w.transfer(id, "player"), "full bag rejects transfer")
	expect(w.items[id].owner == "house", "rejected transfer retains owner")
	w.capacity = 80
	expect(w.transfer(id, "player"), "transfer succeeds with space")
	var gun = w.player_weapon("pistol")
	var sil = w.add_item("suppressor", 1, "player")
	expect(w.attach(gun, sil), "compatible suppressor attaches")
	expect(w.items[sil].owner == gun, "attachment has exactly one gun owner")
	var stock_before = w.owned("warehouse").size()
	w.die()
	var grave = w.graves[0].id
	expect(w.owned("player").is_empty(), "death empties all personal equipment")
	expect(w.items[gun].owner == grave and w.items[sil].owner == gun, "death preserves gun and attachment identity")
	expect(w.owned("warehouse").size() == stock_before, "death preserves warehouse")
	w.add_item("water", 1, "player")
	w.die()
	expect(w.graves.size() == 2, "second death retains both graves")
	var cabinet = w.furniture[0]
	var contents = w.add_item("food", 1, cabinet.id)
	expect(not w.pack_furniture(cabinet.id), "nonempty furniture cannot be packed")
	w.transfer(contents, "warehouse")
	expect(w.pack_furniture(cabinet.id), "empty furniture packs once")
	expect(not w.pack_furniture(cabinet.id), "furniture cannot be duplicated")
	expect(w.place_furniture(cabinet.id, "camp", Vector2(360, 360)), "same furniture instance can be placed")
	w.new_world()
	gun = w.player_weapon("pistol")
	var mag = w.add_item("extended_mag", 1, "player")
	expect(w.attach(gun, mag), "mag attaches")
	w.items[gun].ammo = 18
	w.capacity = 0
	expect(not w.detach(gun, "mag"), "full inventory prevents magazine removal")
	expect(w.items[gun].ammo == 18 and w.items[mag].owner == gun, "rejected detach preserves bullets and magazine")
	w.capacity = 80
	expect(w.detach(gun, "mag"), "mag removal succeeds with room")
	expect(w.items[gun].ammo == 12 and w.count_item("ammo9", "player") >= 6, "overflow bullets returned")
	w.state.minute = 20 * 60 + 59
	w.advance(2)
	var event = w.state.wave_day
	var enemy_count = w.enemies.size()
	w.advance(0)
	expect(event == 1 and w.state.wave_day == 1 and w.enemies.size() == enemy_count, "night event spawns once")
	var minute = w.state.minute
	w.paused = true
	w.tick(10)
	expect(w.state.minute == minute, "pause freezes world")
	w.paused = false
	w.npcs[0].status = "down"
	w.npcs[0].zone = "town"
	w.save_game("user://test_save.json")
	var other = script.new()
	expect(other.load_game("user://test_save.json"), "save loads")
	expect(other.state.wave_day == 1 and other.npcs[0].status == "down", "wave and downed companion survive reload")
	expect(other.items.size() == w.items.size(), "items persist without reroll")
	w.save_game("user://test_save.json")
	var file = FileAccess.open("user://test_save.json", FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	expect(other.load_game("user://test_save.json"), "corrupt primary recovers valid backup")
	w.new_world()
	gun = w.player_weapon("pistol")
	sil = w.add_item("suppressor",1,"player")
	w.attach(gun,sil)
	w.transfer(gun,"warehouse")
	w.capacity = w.weight("player") + 1.25
	expect(not w.transfer(gun,"player"), "attached part weight prevents overloaded gun recovery")
	w.new_world()
	w.state.wall = 80
	w.npcs[0].job = "维修"
	w.advance(30)
	expect(w.state.wall > 80 and w.count_item("wood","warehouse") < 12, "repair worker consumes material and repairs during world time")
	w.new_world()
	w.npcs[0].status = "injured"; w.npcs[0].hp = 35
	w.advance(30)
	expect(w.npcs[0].hp > 39.5 and w.count_item("bandage","warehouse") < 4, "medical worker consumes supplies to speed recovery")
	w.new_world(); w.state.zone = "camp"; w.state.minute = 1261; w.state.wave_day = 1
	w.spawn_enemy("camp",Vector2(340,265),"breaker",true)
	w.npcs[0].job = "医疗"
	w.die()
	expect(w.state.wall < 240, "camp death recovery still advances hostile camp battle")
	w.new_world(); w.state.minute = 1259; w.advance(2)
	var all_in_bounds = true
	for e in w.enemies:
		if e.wave and e.y < 20: all_in_bounds = false
	expect(all_in_bounds, "all wave spawns start within traversable map bounds")
	w.enemies = w.enemies.filter(func(e): return not e.wave)
	w.finish_wave()
	expect(not w.state.wave_active and w.state.has("battle_report"), "cleared wave produces persistent battle report")
	var log_count = w.logs.size(); w.finish_wave()
	expect(w.logs.size() == log_count, "battle result is not duplicated")
	var bad = w.snapshot(); bad.npcs = null
	expect(not w.valid(bad), "malformed NPC collection rejects entire snapshot")
	bad = w.snapshot(); bad.items.values()[0].owner = "missing_owner"
	expect(not w.valid(bad), "orphan item ownership rejects snapshot")
	var first_path = "user://tests/first_%d.json" % Time.get_ticks_usec()
	w.save_game(first_path)
	expect(FileAccess.file_exists(first_path + ".bak"), "first successful save also keeps verified backup")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
