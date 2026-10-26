extends SceneTree
const World = preload("res://scripts/world.gd")
var failures = 0
var checks = 0
func expect(ok, message):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: ",message)
func _initialize():
	var w = World.new()
	w.save_directory = "user://exploration-tests"
	w.new_world(321)
	expect(w.state.zone == "town", "start in explorable world, no fixed camp")
	expect(not w.enemies.any(func(e):return Vector2(e.x,e.y).distance_to(Vector2(w.state.px,w.state.py))<200),"new world starts clear of nearby hostiles")
	expect(w.has_method("travel"), "persistent region travel API exists")
	if not w.has_method("travel"):
		print("EXPLORATION: ", checks-failures,"/",checks); quit(1); return
	expect(w.state.map_id == "town", "initial map identity")
	expect(w.count_item("food","warehouse") == 0, "no remote warehouse")
	var starting_enemies = w.enemies.size()
	w.state.core = 0
	w.advance(900)
	expect(not w.state.failed, "zero obsolete core does not end world")
	expect(not w.enemies.any(func(e):return e.get("wave",false)), "night has no compulsory camp horde")
	expect(w.enemies.size() == starting_enemies, "time alone does not spawn nightly waves")
	var beds = w.beds()
	expect(beds.size() >= 2,"multiple actual beds")
	var bed = beds[0]
	w.state.px = bed.x; w.state.py = bed.y
	w.enemies.clear()
	expect(w.register_shelter(bed.id,"测试住所"),"register nearby bed")
	var shelter_id = w.state.shelters[0].id
	expect(w.set_preferred_shelter(shelter_id),"select recovery shelter")
	var container = w.map.buildings[0].container
	var stored = w.add_item("water",1,container)
	var item = w.add_item("parts",1,"player")
	expect(not w.transfer(item,"warehouse"),"invalid remote owner rejected")
	w.state.px = 4000; w.state.py = 4000
	expect(not w.transfer(stored,"player"),"remote container transfer rejected")
	var town_items = w.items.size()
	var town_building_count=w.map.buildings.size()
	var old_time = w.state.minute
	var exit = w.exits()[0]
	w.state.px = exit.x; w.state.py = exit.y
	var pursuer_pos = Vector2(exit.x+30,exit.y)
	w.spawn_enemy("town",pursuer_pos,"normal")
	w.enemies[-1].alert = 5
	expect(not w.travel("forest"),"pursuit blocks boundary escape")
	expect(w.state.minute == old_time,"failed travel costs no time")
	w.enemies.clear()
	expect(w.travel("forest"),"first forest trip succeeds")
	expect(w.state.map_id == "forest", "target region active")
	expect(is_equal_approx(w.state.minute,old_time+15),"travel charges time once")
	expect(w.state.known_regions.forest == "entered","forest entered separately from rumor")
	expect(w.items.has(stored),"world item identity survives travel")
	expect(w.map.buildings[0].container != container,"region containers have distinct ownership")
	expect(w.map.buildings.size()<town_building_count,"forest uses sparse cabins rather than town density")
	var forest_container = w.map.buildings[0].container
	var exit_back = w.exits()[0]
	w.state.px = exit_back.x; w.state.py = exit_back.y; w.enemies.clear()
	expect(w.travel("town"),"return town succeeds")
	expect(w.items.has(stored) and w.items[stored].owner == container,"town inventory not regenerated")
	expect(w.state.shelters[0].id == shelter_id,"shelter persists across regions")
	var gun = w.player_weapon("pistol")
	var part = w.add_item("suppressor",1,"player")
	expect(w.attach(gun,part),"attach compatible part")
	w.items[gun].ammo = 3
	var before_death_items = w.items.size()
	w.die()
	expect(w.graves.size() == 1,"death creates one remains")
	expect(w.owned("player").is_empty(),"all inventory dropped")
	expect(w.items[gun].owner == w.graves[0].id,"weapon becomes remains item")
	expect(w.items[part].owner == gun and w.items[gun].ammo == 3,"parts and gun ammo conserved")
	expect(w.items.size() == before_death_items,"death creates no starter equipment")
	expect(w.items[stored].owner == container,"stored goods unaffected by death")
	expect(Vector2(w.state.px,w.state.py).distance_to(Vector2(bed.x,bed.y)) < 60,"recover at preferred valid bed")
	w.die()
	expect(w.graves.size() == 2,"second death does not overwrite prior remains")
	expect(w.save_game(),"valid complete world saves")
	var other = World.new(); other.save_directory = w.save_directory
	expect(other.load_game(),"saved state reloads")
	expect(other.graves.size() == 2 and other.items[gun].ammo == 3,"saved graves and ammo retained")
	expect(other.state.shelters.size() == 1,"registered shelter reloads")
	var current_map = other.state.map_id
	var bad = FileAccess.open(w.save_directory.path_join("save.json"),FileAccess.WRITE); bad.store_string("broken"); bad.close()
	expect(other.load_game() and other.state.map_id == current_map,"corrupted latest recovers valid backup")
	var p = World.new(); p.save_directory="user://exploration-roundtrip-tests"; p.new_world(42)
	p.enemies.clear(); p.capacity=100
	var companion=p.npcs[0]; companion.follow=true; companion.hp=31; companion.status="injured"
	var cabinet=p.furniture[0]
	p.state.px=cabinet.x; p.state.py=cabinet.y
	expect(p.pack_furniture(cabinet.id),"empty nearby cabinet packs as same instance")
	p.doors[p.map.buildings[0].container+"_0"]=true
	p.state.tactics_v5.doors[p.map.buildings[0].container]={"hp":12.0,"broken":false,"board_hp":8.0}
	p.state.searched[p.map.buildings[0].container]=true
	var door_keys=p.doors.keys().duplicate()
	var npc_id=companion.id
	p.state.px=95; p.state.py=490
	expect(p.exits().size()==1 and p.state.known_regions.forest=="entrance","nearby sign discovers entrance without entering")
	expect(p.travel("forest"),"packed furniture and companion travel")
	expect(p.npcs.size()==1 and p.npcs[0].id==npc_id and p.npcs[0].hp==31 and p.npcs[0].status=="injured","companion neither cloned nor healed across maps")
	expect(p.furniture.any(func(f):return f.id==cabinet.id and f.packed),"same packed furniture instance crosses maps")
	var destination=Vector2(p.state.px,p.state.py)+Vector2(65,0)
	expect(p.place_furniture(cabinet.id,"town",destination),"packed cabinet places in destination region")
	expect(not p.items.has(cabinet.id),"placing furniture consumes only packed representation")
	var water=p.add_item("water",1,"player")
	expect(p.transfer(water,cabinet.id),"nearby placed cabinet has real independent storage")
	p.state.px=95; p.state.py=490; p.enemies.clear()
	expect(p.travel("town"),"return with companion")
	expect(p.doors.has(door_keys[0]) and p.state.searched.size()==1,"door and search state persist through travel")
	expect(p.state.tactics_v5.doors.values()[0].hp==12,"damaged door health persists")
	expect(not p.transfer(water,"player"),"stored destination furniture cannot be looted remotely")
	expect(p.save_game(),"save includes packed/placed region ownership and follower")
	var loaded=World.new(); loaded.save_directory=p.save_directory
	expect(loaded.load_game(),"all regions with moved entities reload")
	var invalid=loaded.snapshot(); invalid.items[water].owner="nonexistent-remote-owner"
	expect(not loaded.valid(invalid),"dangling inventory owner rejected before save")
	invalid=loaded.snapshot(); invalid.items[loaded.player_weapon("pistol")].ammo=999999
	expect(not loaded.valid(invalid),"impossible loaded gun ammunition rejected")
	invalid=loaded.snapshot(); invalid.regions.town.beds[0].hp="bad"
	expect(not loaded.valid(invalid),"malformed saved bed rejected")
	invalid=loaded.snapshot(); invalid.state.shelters.append({"id":"bad"})
	expect(not loaded.valid(invalid),"malformed shelter reference rejected")
	invalid=loaded.snapshot(); invalid.items[water].qty=1.5
	expect(not loaded.valid(invalid),"fractional item count rejected")
	p.save_directory="user://exploration-writefailure-fixture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.save_directory.path_join("save.json.tmp")))
	p.state.px=95; p.state.py=490; p.enemies.clear()
	var time_before_failed_write=p.state.minute
	var inventory_before_failed_write=p.items.duplicate(true)
	expect(not p.travel("forest"),"disk failure aborts region transaction")
	expect(p.state.map_id=="town" and p.state.minute==time_before_failed_write,"disk failure restores source map and time")
	expect(p.items==inventory_before_failed_write,"disk failure conserves all item instances")
	var bag=World.new(); bag.new_world(31); bag.enemies.clear()
	bag.capacity=999; bag.slot_capacity=bag.owned("player").size()
	var cabinet_to_pack=bag.furniture[0]
	bag.state.px=cabinet_to_pack.x; bag.state.py=cabinet_to_pack.y
	expect(not bag.pack_furniture(cabinet_to_pack.id) and not cabinet_to_pack.packed,"slot-full bag cannot pack furniture")
	var extra=bag.add_item("water",1,cabinet_to_pack.id)
	expect(not bag.transfer(extra,"player") and bag.items[extra].owner==cabinet_to_pack.id,"slot-full loot request leaves source unchanged")
	var bag_gun=bag.player_weapon("pistol")
	var mag=bag.add_item("extended_mag",1,"player")
	expect(bag.attach(bag_gun,mag),"mag attachment consumes no extra carried slot")
	bag.slot_capacity=bag.owned("player").size()
	bag.items[bag_gun].ammo=bag.R.capacity_for(bag.items[bag_gun])
	var bag_before=bag.items.duplicate(true)
	expect(not bag.detach(bag_gun,"mag") and bag.items==bag_before,"full bag cannot detach part or overflow ammunition halfway")
	bag.slot_capacity+=1
	expect(not bag.detach(bag_gun,"mag") and bag.items==bag_before,"one free slot insufficient for part plus new overflow ammo stack")
	bag.slot_capacity+=1
	expect(bag.detach(bag_gun,"mag"),"two slots accept detached part and overflow ammo")
	var guarded=World.new(); guarded.save_directory="user://exploration-blocked-arrival-tests"; guarded.new_world(73)
	guarded.enemies.clear(); guarded.state.px=95; guarded.state.py=490
	expect(guarded.travel("forest"),"arrival-blocking fixture enters forest")
	guarded.enemies.clear()
	for yy in range(-3,4):
		for xx in range(-3,4): guarded.spawn_enemy("town",Vector2(150+xx*100,490+yy*100),"normal")
	guarded.state.px=95; guarded.state.py=490
	expect(guarded.travel("town"),"unalerted distant-region enemies persist when leaving")
	guarded.enemies.clear(); guarded.state.px=95; guarded.state.py=490
	var minute_before_block=guarded.state.minute
	var inventory_before_block=guarded.items.duplicate(true)
	expect(not guarded.travel("forest"),"unsafe target arrival rejects travel")
	expect(guarded.state.map_id=="town" and guarded.state.minute==minute_before_block,"unsafe arrival restores source map and time")
	expect(guarded.items==inventory_before_block,"unsafe arrival has no item side effects")
	print("EXPLORATION: ",checks-failures,"/",checks," checks passed")
	quit(0 if failures==0 else 1)
