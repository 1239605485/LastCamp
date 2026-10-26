extends SceneTree

var failures = 0
var checks = 0

func expect(condition: bool, label: String):
	checks += 1
	if not condition: failures += 1; printerr("FAIL: " + label)

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://main.tscn").instantiate()
	game.world.save_directory = "user://integration-tests"
	root.add_child(game)
	await process_frame
	game.world.new_world(); game.hud.close_panel()
	game.world.paused = false
	var pointer = InputEventMouseMotion.new(); pointer.position = Vector2(650,650)
	Input.parse_input_event(pointer)
	await process_frame
	var click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = Vector2(650,650)
	Input.parse_input_event(click)
	game.reload_request()
	await process_frame
	expect(not game.action.is_empty() and game.action.get("kind") == "reload", "desktop click on reload button does not fire and cancel reload")
	click.pressed = false; Input.parse_input_event(click); game.action.clear()
	# A cancelled looting action must never move the item.
	game.world.state.zone = "town"; game.set_pos(Vector2(270,350))
	var id = game.world.owned("house")[0].id
	game.start_action({"kind":"transfer","id":id,"source":"house","target":"player","pos":Vector2(265,350)})
	game.set_pos(Vector2(600,500)); game.complete_action()
	expect(game.world.items[id].owner == "house", "distant loot is rejected at commit")
	game.set_pos(Vector2(270,350))
	game.start_action({"kind":"transfer","id":id,"source":"house","target":"player","pos":Vector2(265,350)})
	game.damage_player(8)
	expect(game.action.is_empty() and game.world.items[id].owner == "house", "damage interrupts loot without transfer")
	game.start_action({"kind":"transfer","id":id,"source":"house","target":"player","pos":Vector2(265,350)})
	game.complete_action()
	expect(game.world.items[id].owner == "player", "reachable loot commits")
	game.set_pos(Vector2(350,450))
	var geometry = load("res://scripts/building_geometry.gd")
	expect(game.blocked(geometry.point(game.world.map.buildings[0],Vector2(200,55))), "source-aligned building wall/stair projection collides")
	expect(not game.visible(Vector2(180,300),Vector2(280,300)), "walls block targeting and looting")
	var npc = game.world.npcs[2]
	game.world.npcs[0].follow = true
	game.set_pos(Vector2(825,310))
	game.start_action({"kind":"rescue","id":npc.id,"pos":Vector2(825,285)},4); game.complete_action()
	expect(npc.status == "injured" and npc.follow, "recruitment creates following injured companion")
	expect(game.world.npcs.filter(func(n): return n.follow).size() == 1, "rescue cannot create a second active follower")
	game.change_zone("camp",Vector2(800,490))
	expect(npc.zone == "camp", "following companion transitions with player")
	game.hud.open_panel("bag")
	var minute = game.world.state.minute
	game.world.tick(30)
	expect(game.world.state.minute == minute, "inventory pauses simulation")
	game.hud.close_panel()
	var touch = InputEventScreenTouch.new(); touch.index = 0; touch.pressed = true; touch.position = game.hud.move_origin + Vector2(35,0)
	game.hud._unhandled_input(touch)
	touch = InputEventScreenTouch.new(); touch.index = 1; touch.pressed = true; touch.position = game.hud.aim_origin + Vector2(0,-35)
	game.hud._unhandled_input(touch)
	touch = InputEventScreenTouch.new(); touch.index = 2; touch.pressed = false; touch.position = Vector2(740,650)
	game.hud._input(touch)
	expect(game.hud.move_axis.x > 0 and game.hud.aim_axis.y < 0, "third finger leaves both sticks active")
	touch = InputEventScreenTouch.new(); touch.index = 0; touch.pressed = false; touch.position = Vector2(740,650)
	game.hud._input(touch)
	expect(game.hud.move_axis == Vector2.ZERO and game.hud.aim_axis.y < 0, "joystick release over GUI clears only its own touch")
	for kind in ["parts","people","map","pause","loot"]:
		game.hud.container_id = "warehouse"; game.hud.open_panel(kind)
		await process_frame
		expect(game.hud.panel.visible, "panel renders " + kind)
	game.hud.close_panel()
	game.world.new_world(); game.world.state.zone = "town"
	game.world.state.minute = 1259
	game.world.advance(5)
	var wave_ids = game.world.enemies.filter(func(e): return e.wave).map(func(e): return e.id)
	game.change_zone("camp",Vector2(800,490))
	game.change_zone("town",Vector2(95,490))
	expect(game.world.enemies.filter(func(e): return e.wave).map(func(e): return e.id) == wave_ids, "zone transitions neither reset nor duplicate wave")
	game.world.advance(600)
	expect(game.world.state.minute > 1800 and game.world.state.core > 0, "offscreen guards allow first-night recovery")
	game.world.new_world(); game.world.paused = false
	game.hud.close_panel(); game.set_pos(Vector2(470,430))
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/camp-preview.png")
		game.hud.open_panel("bag")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/bag-preview.png")
		game.hud.close_panel(); game.world.state.zone = "town"; game.set_pos(Vector2(355,370))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/town-preview.png")
		game.world.new_world(); game.world.state.minute = 1259
		game.world.advance(3); game.set_pos(Vector2(470,430))
		await create_timer(6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/night-preview.png")
	print("GAME RESULT: %d checks, %d failures" % [checks,failures])
	game.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)
