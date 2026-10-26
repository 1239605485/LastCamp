extends SceneTree
var failures = 0
func expect(ok,message):
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize():
	var hud = load("res://scripts/hud.gd").new()
	var style = hud.pixel_style()
	expect(style.texture.resource_path.contains("postapocalypse"),"UI panels use supplied pixel asset pack")
	hud.free()
	var game = load("res://main.tscn").instantiate()
	game.world.save_directory="user://test-pixel-ui"
	root.add_child(game)
	call_deferred("verify",game)
func verify(game):
	await process_frame
	game.hud.refresh()
	expect(not game.hud.objective.text.contains("核心"),"HUD removes fixed core goal")
	expect(not game.hud.objective.text.contains("21:00"),"HUD removes mandatory night siege deadline")
	game.hud.open_panel("bag")
	expect(game.world.paused,"Inventory pauses world")
	game.hud.close_panel()
	expect(not game.world.paused,"Closing inventory resumes world")
	for name in ["bag","map","interact","fire","reload"]:
		var r = game.hud.find_action_rect(name)
		expect(r.size.x>=48 and r.size.y>=48,"Touch target >=48 for "+name)
	game.free()
	print("PIXEL_UI failures: ",failures)
	quit(1 if failures else 0)
