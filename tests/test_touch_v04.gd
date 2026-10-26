extends SceneTree
var failures = 0
var checks = 0
func expect(value: bool, message: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func touch(hud, id: int, point: Vector2, down: bool):
	var e = InputEventScreenTouch.new(); e.index=id; e.position=point; e.pressed=down; hud._input(e)
	if down and not hud.game.world.paused: hud._unhandled_input(e)
func drag(hud, id: int, point: Vector2):
	var e = InputEventScreenDrag.new(); e.index=id; e.position=point; hud._input(e)
	hud._unhandled_input(e)
func _initialize(): call_deferred("run")
func run():
	var game=load("res://main.tscn").instantiate(); game.world.save_directory="user://touch-v04-tests"; root.add_child(game)
	await process_frame
	game.world.new_world(); var hud=game.hud; hud.close_panel()
	expect(hud.has_method("start_layout_editor"),"layout editor is available")
	expect(hud.find_action_rect("fire").size.x >= 72,"fire target defaults to finger size")
	for b in hud.touch_buttons:
		if is_instance_valid(b) and b.has_meta("action_name"): expect(b.text.is_empty() and b.icon != null,"gameplay action is icon only")
	if hud.has_method("start_layout_editor"):
		hud.controls_path="user://touch-v04-controls.cfg"
		hud.reset_control_layout(); hud.start_layout_editor()
		var p=hud.find_action_rect("reload").get_center(); touch(hud,8,p,true); drag(hud,8,p+Vector2(-70,30)); touch(hud,8,p+Vector2(-70,30),false)
		var moved=hud.find_action_rect("reload"); expect(moved.get_center().distance_to(p+Vector2(-70,30)) < 2,"one finger drags selected control")
		hud.resize_selected_control(8); expect(hud.find_action_rect("reload").size.x==80,"selected control size changes")
		expect(hud.touch_buttons.filter(func(b):return is_instance_valid(b) and b.get_meta("action_name","")=="reload")[0].get_theme_constant("icon_max_width")==80,"resizing button also grows visible icon")
		hud.save_control_layout(); hud.reset_control_layout(false); hud.load_control_layout(); expect(hud.find_action_rect("reload").position==moved.position,"positions survive settings reload")
		var reloaded=load("res://scripts/hud.gd").new(); reloaded.game=game; reloaded.controls_path=hud.controls_path; root.add_child(reloaded)
		expect(reloaded.find_action_rect("reload").size.x==80 and reloaded.find_action_rect("reload").position==moved.position,"fresh HUD restores saved size and position"); reloaded.free()
		hud.close_panel(); game.world.new_world(); expect(hud.find_action_rect("reload").size.x==80,"new world retains control settings")
		hud.reset_control_layout(); hud.close_panel()
		touch(hud,10,Vector2(480,330),true); touch(hud,11,Vector2(680,330),true); drag(hud,11,Vector2(780,330))
		expect(game.world_zoom > 1.2,"two world touches pinch zoom")
		touch(hud,10,Vector2(480,330),false); touch(hud,11,Vector2(780,330),false)
		var prior_zoom=game.world_zoom; var fire= hud.find_action_rect("fire").get_center(); touch(hud,15,fire,true); touch(hud,16,Vector2(600,330),true); drag(hud,16,Vector2(800,330))
		expect(hud.fire_held and hud.fire_touch==15 and game.world_zoom==prior_zoom,"firing finger is excluded from pinch")
		touch(hud,15,fire,false); touch(hud,16,Vector2(800,330),false)
		touch(hud,12,hud.move_origin,true); touch(hud,13,Vector2(600,330),true); drag(hud,13,Vector2(800,330)); expect(hud.move_touch==12,"pinch does not steal joystick")
		expect(hud.vital_bars.size()==4,"four survival status bars")
		DirAccess.remove_absolute(hud.controls_path)
	game.free(); print("TOUCH V04 RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)


