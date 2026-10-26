extends SceneTree

var checks = 0
var failures = 0
func expect(value: bool,label: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + label)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); game.world.save_directory = "user://expansion-game-tests"
	root.add_child(game); await process_frame
	game.world.new_world(1234); game.hud.close_panel()
	if not game.has_method("cycle_weapon"):
		expect(false,"expanded weapon selection and Mini control service exist")
		game.queue_free(); await process_frame; quit(1); return
	game.world.add_item("m4",1,"player")
	game.cycle_weapon("primary")
	expect(game.world.state.weapon == "m4","primary selector finds actually carried gun")
	game.world.enemies.clear(); game.world.state.zone = "camp"; game.set_pos(Vector2(800,700)); game.aim = Vector2.RIGHT
	var shotgun = game.world.add_item("shotgun",1,"player"); game.world.state.weapon = "shotgun"
	game.world.spawn_enemy("camp",Vector2(900,700),"normal")
	game.world.enemies.back().hp = 1000
	game.focus = 1.0; game.shot_cd = 0; game.fire()
	expect(game.world.items[shotgun].ammo == 5,"shotgun fires one cartridge")
	expect(game.world.enemies.back().hp < 950,"shotgun applies multiple actual pellets")
	game.world.state.zone="town"
	var remote_road=game.world.map.roads.filter(func(r):return r.a.x>5000)[0]
	var road_center:Vector2=(remote_road.a+remote_road.b)/2; game.set_pos(road_center)
	expect(not game.blocked(road_center) and game.move_with_collision(road_center,Vector2(5,0)).x>road_center.x,"player can walk beyond old small-map bounds")
	var far = game.world.map.buildings.back()
	game.set_pos(far.rect.get_center())
	var geometry = load("res://scripts/building_geometry.gd")
	expect(game.blocked(geometry.frame(far).position + Vector2(2,20)),"remote building still has source-aligned wall collision")
	game.hud.open_panel("map"); await process_frame
	expect(game.hud.panel.visible,"large map renders in paused panel")
	game.hud.open_panel("parts"); await process_frame
	expect(game.hud.panel.visible,"multi-gun attachment menu renders")
	game.hud.close_panel()
	game.world.new_world(); game.world.state.hp = 50
	var left = InputEventScreenTouch.new(); left.index = 0; left.pressed = true; left.position = game.hud.move_origin + Vector2(30,0); game.hud._unhandled_input(left)
	var right = InputEventScreenTouch.new(); right.index = 1; right.pressed = true; right.position = game.hud.aim_origin + Vector2(0,-30); game.hud._unhandled_input(right)
	var fire = InputEventScreenTouch.new(); fire.index = 2; fire.pressed = true; fire.position = game.hud.find_action_rect("fire").get_center(); game.hud._input(fire)
	expect(game.hud.fire_held and game.hud.move_axis.x > 0 and game.hud.aim_axis.y < 0,"third finger fires independently of held joysticks")
	fire.pressed = false; game.hud._input(fire)
	expect(not game.hud.fire_held and game.hud.move_axis.x > 0 and game.hud.aim_axis.y < 0,"fire release preserves both joystick IDs")
	var bandage = InputEventScreenTouch.new(); bandage.index = 2; bandage.pressed = true; bandage.position = game.hud.find_action_rect("bandage").get_center(); game.hud._input(bandage); bandage.pressed = false; game.hud._input(bandage)
	expect(game.world.state.hp == 85 and game.hud.move_axis.x > 0,"third finger can use medicine without cancelling movement")
	game.world.enemies.clear(); game.world.state.zone = "camp"; game.set_pos(Vector2(1260,1050))
	game.world.spawn_enemy("camp",Vector2(310,50),"normal",true)
	game.update_enemies(1)
	expect(game.world.enemies[0].y > 50,"standing at far camp corner does not freeze wave attackers")
	game.queue_free(); await create_timer(0.2).timeout
	print("EXPANSION GAME RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)


