extends SceneTree
var checks=0
var failures=0
func expect(value:bool,message:String):
	checks+=1
	if not value: failures+=1; printerr("FAIL: "+message)
func _initialize(): call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate(); g.world.save_directory="user://harvest-v04-tests"; root.add_child(g); await process_frame
	g.world.new_world(1234); g.hud.close_panel(); g.set_process(false)
	expect(g.world.map.layout_version==4,"new world uses clustered town map v4")
	expect(g.world.has_method("harvest_plant"),"harvest transaction available")
	if g.world.has_method("harvest_plant"):
		var plants=g.world.map.plants_at(Vector2(600,500),2000,"camp"); expect(not plants.is_empty(),"camp approach has edible plants")
		var p=plants[0]; g.set_pos(p.pos+Vector2(0,28)); var target=g.nearest_target()
		expect(target.get("kind","")=="harvest","nearby plant is an interaction target")
		g.interact(); expect(g.is_searching() and not g.action.is_empty(),"harvest begins timed crouched action")
		g.damage_player(1); expect(g.action.is_empty() and g.world.state.harvests.is_empty(),"damage cancels without consuming plant")
		g.last_damage=0; g.interact(); g.complete_action()
		expect(g.world.count_item(p.kind)>0 and g.world.state.harvests.has(p.id),"harvest produces matching fruit and saves cooldown")
		var count=g.world.count_item(p.kind); expect(not g.world.harvest_plant(p.id) and g.world.count_item(p.kind)==count,"plant cannot be harvested twice")
		g.world.state.hunger=30; g.world.state.thirst=30
		expect(g.world.use_item(p.kind) and g.world.state.hunger>30 and g.world.state.thirst>30,"fruit replenishes hunger and water")
		g.world.save_game(); g.world.load_game(); expect(g.world.state.harvests.has(p.id) and not g.world.harvest_plant(p.id),"loading does not reset cooldown")
		g.world.state.minute=g.world.state.harvests[p.id]; g.world.capacity=g.world.weight("player")
		expect(not g.world.harvest_plant(p.id),"full bag prevents harvest without advancing cooldown")
		g.world.capacity=100; expect(g.world.harvest_plant(p.id),"regrown plant can be harvested with enough space")
		g.set_pos(Vector2(430,440)); expect(not g.world.harvest_plant(p.id),"cannot harvest distant plant")
	var cleaner=load("res://scripts/icon_image.gd")
	var im=Image.create(7,7,false,Image.FORMAT_RGBA8); im.fill(Color.TRANSPARENT)
	for y in range(1,6):
		for x in range(1,6): im.set_pixel(x,y,Color.WHITE if x in [1,5] or y in [1,5] else Color.DARK_GREEN)
	im.set_pixel(3,3,Color.WHITE); var clean=cleaner.strip_outline(im)
	expect(clean.get_pixel(1,3).a==0 and clean.get_pixel(3,3)==Color.WHITE,"remove outer white rim but preserve internal white detail")
	var bandage=cleaner.strip_outline(load("res://assets/minidayz/icons/bandage.png").get_image())
	expect(bandage.get_used_rect().size.y>=3,"tiny bandage keeps recognisable roll silhouette")
	print("HARVEST V04 RESULT: %d checks, %d failures"%[checks,failures]); await create_timer(0.55).timeout
	for voice in g.sound.voices: voice.stop()
	g.queue_free(); await create_timer(0.2).timeout; quit(1 if failures else 0)



