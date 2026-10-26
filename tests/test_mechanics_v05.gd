extends SceneTree
var checks=0
var failures=0
func expect(v:bool,s:String):
	checks+=1
	if not v: failures+=1; printerr("FAIL: "+s)
func _initialize(): call_deferred("run")
func run():
	var g=load("res://main.tscn").instantiate(); g.world.save_directory="user://mechanics-v05"; root.add_child(g); await process_frame
	g.set_process(false); g.world.new_world(1234); g.hud.close_panel(); var w=g.world; var T=g.Tactics; var S=g.Survival
	w.state.zone="town"; var b=w.map.buildings[0]; var d=g.Geometry.door(b).get_center(); g.set_pos(d+Vector2(0,24)); w.enemies.clear()
	w.add_item("wood",4,"player"); var wood=w.count_item("wood")
	g.request_mechanic({"kind":"tac_door_board","id":"house0"},2.4); g.damage_player(1)
	expect(g.action.is_empty() and w.count_item("wood")==wood and T.door_state(w,"house0").board_hp==0,"interrupted boarding does not spend or add barrier")
	g.last_damage=0; g.request_mechanic({"kind":"tac_door_board","id":"house0"},2.4); g.complete_action()
	expect(w.count_item("wood")==wood-2 and T.door_state(w,"house0").board_hp==120,"timed boarding commits once")
	T.damage_door(w,"house0",1000); g.request_mechanic({"kind":"tac_door_board","id":"house0"},2.4); g.complete_action()
	g.set_pos(d+Vector2(0,210)); w.spawn_enemy("town",d+Vector2(0,12),"normal"); var e=w.enemies[-1]; e.alert=7; e.tx=d.x; e.ty=d.y-30
	var hp=T.door_state(w,"house0").board_hp; g.update_enemies(0); e.cd=0; g.update_enemies(0)
	expect(T.door_state(w,"house0").board_hp==hp-28,"enemies repeatedly damage boards on previously broken door")
	w.enemies.clear(); w.state.zone="camp"; g.set_pos(Vector2(505,480)); w.state.systems_v5.fatigue=80
	g.request_mechanic({"kind":"sys_sleep"},3); g.complete_action(); w.state.minute=1259; w.advance(2)
	expect(w.state.systems_v5.sleeping and w.state.systems_v5.fatigue<80 and w.state.wave_day==1 and w.enemies.size()>0,"sleep recovers fatigue while same clock starts night attack")
	g.last_damage=0; g.damage_player(1); expect(not w.state.systems_v5.resting and not w.state.systems_v5.sleeping,"damage wakes player")
	w.enemies.clear(); g.set_pos(Vector2(740,420)); var ammo=w.count_item("ammo9"); var food=w.count_item("food")
	g.request_mechanic({"kind":"sys_trade","recipe":"ammo"},2); g.complete_action()
	expect(w.count_item("food")==food-2 and w.count_item("ammo9")==ammo+18,"actual trader action exchanges inventory")
	w.state.minute=2039; w.advance(1); var event=S.event_markers(w)[0]
	expect(w.valid(w.snapshot()) and w.owned(event.id).size()>0,"generated event owner accepted in complete save")
	w.state.zone="town"; g.set_pos(Vector2(event.x,event.y)); g.request_mechanic({"kind":"sys_event","id":event.id},4); g.complete_action()
	expect(event.status=="claimed" and w.owned(event.id).is_empty(),"nearby event transfers unique precreated reward")
	var count=w.items.size(); expect(not S.complete(w,{"kind":"sys_event","id":event.id}) and w.items.size()==count,"event reward cannot be repeated")
	var apple=w.add_item("apple",1,"player"); w.items[apple].fresh_until=w.state.minute-1; var fresh=w.add_item("apple",1,"player")
	expect(not w.use_item("apple",apple) and w.items.has(fresh),"expired selected stack cannot eat another fresh stack")
	expect(S.complete(w,{"kind":"sys_discard_food","id":apple}) and not w.items.has(apple) and w.items.has(fresh),"cleanup removes only selected expired food")
	w.state.zone="camp"; g.set_pos(Vector2(800,700)); w.enemies.clear(); var guard=w.npcs[0]; guard.hold_fire=true; w.state.guard_ammo=100
	w.spawn_enemy("camp",Vector2(490,230),"normal",true); g.guard_cd=0; g.update_npcs(0.1)
	expect(w.state.guard_ammo==100,"hold fire suppresses on-screen guard ammunition")
	w.state.zone="town"; w.offscreen_camp(1); expect(w.state.guard_ammo==100,"hold fire also suppresses off-screen guard ammunition")
	w.state.zone="camp"; w.enemies.clear(); g.set_pos(Vector2(800,700)); var marker=w.uid("trap_")
	w.state.tactics_v5.traps.append({"id":marker,"kind":"spike","zone":"camp","x":800.0,"y":720.0,"hp":40.0,"armed":false})
	g.request_mechanic({"kind":"tac_clear_trap","id":marker},1.2); g.complete_action()
	expect(not w.state.tactics_v5.traps.any(func(trap):return trap.id==marker),"spent traps can be cleared to free build capacity")
	var data=w.snapshot(); expect(w.save_game() and w.load_game() and w.state.systems_v5.events[0].status=="claimed","save reload keeps claimed event and new systems")
	data.state.tactics_v5.traps="bad"; expect(not w.valid(data),"bad tactical extension rejected")
	await create_timer(0.55).timeout
	for voice in g.sound.voices: voice.stop()
	g.queue_free(); await process_frame; print("MECHANICS V05 RESULT: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)


