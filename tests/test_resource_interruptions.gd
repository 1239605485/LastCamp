extends SceneTree
const Game = preload("res://scripts/game.gd")
const G = preload("res://scripts/building_geometry.gd")
var failures = 0
var checks = 0
func expect(ok: bool, message: String):
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func run():
	var game=Game.new()
	game.world.save_directory="user://test-resource-interruptions"
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.world.new_world(321)
	game.world.enemies.clear()
	game.set_pos(G.loot_point(game.world.map.buildings[0]))
	game.world.add_item("dirty_water",1,"player")
	game.world.add_item("wood",2,"player")
	var before=game.world.items.duplicate(true)
	game.start_action({"kind":"sys_cycle_boil"},12)
	game.hud.move_axis=Vector2.RIGHT
	game._process(0.1)
	expect(game.action.is_empty() and game.world.items==before,"moving cancels boiling without material loss")
	game.hud.move_axis=Vector2.ZERO
	game.start_action({"kind":"sys_cycle_boil"},12)
	game.last_damage=0
	game.damage_player(1)
	expect(game.action.is_empty() and game.world.items==before,"damage cancels boiling without material loss")
	game.start_action({"kind":"sys_cycle_boil"},12)
	game.hud.open_panel("bag")
	expect(game.action.is_empty() and game.world.items==before,"opening bag cancels boiling without material loss")
	var minute=game.world.state.minute
	game._process(0.1)
	expect(game.world.state.minute==minute,"paused panel stops water and world time")
	game.free()
	print("RESOURCE_INTERRUPTION: ",checks-failures,"/",checks)
	quit(1 if failures else 0)
