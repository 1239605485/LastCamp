extends SceneTree
var checks = 0
var failures = 0
var clicks = 0
func expect(value: bool, message: String):
	checks += 1
	if not value: failures += 1; printerr("FAIL: " + message)
func touch(hud, id: int, point: Vector2, down: bool):
	var event = InputEventScreenTouch.new(); event.index = id; event.position = point; event.pressed = down; hud._input(event)
func drag(hud, id: int, point: Vector2):
	var event = InputEventScreenDrag.new(); event.index = id; event.position = point; hud._input(event)
func _initialize(): call_deferred("run")
func run():
	var game = load("res://main.tscn").instantiate(); game.world.save_directory = "user://touch-ui-tests"; root.add_child(game)
	await process_frame
	game.world.new_world(); game.hud.close_panel(); var hud = game.hud
	var joystick = InputEventScreenTouch.new(); joystick.index = 0; joystick.position = hud.move_origin + Vector2(30,0); joystick.pressed = true; hud._unhandled_input(joystick)
	expect(hud.move_touch == 0,"joystick owns first touch")
	# Synthetic overflowing list makes touch tests independent of starter inventory sizes.
	hud.clear_body(); hud.panel.visible = true
	var entries = hud.scroll_column(hud.body,"Touch regression list")
	for i in range(28): entries.add_child(hud.button("row %d" % i,func(): clicks += 1,Vector2(500,58)))
	await process_frame; await process_frame
	var scroll: ScrollContainer = entries.get_parent(); var point = scroll.get_global_rect().position + Vector2(110,70)
	touch(hud,1,point,true); expect(clicks == 0,"touch down does not prematurely activate row")
	drag(hud,1,point-Vector2(0,55)); touch(hud,1,point-Vector2(0,55),false)
	expect(scroll.scroll_vertical > 30,"content drag scrolls an overflowing list")
	expect(clicks == 0,"content drag does not click a row")
	expect(hud.move_touch == 0 and hud.move_axis.x > 0,"second finger scrolling retains held joystick")
	touch(hud,2,point,true); touch(hud,2,point,false)
	expect(clicks == 1,"stationary touch dispatches exactly one click on release")
	var bar = scroll.get_v_scroll_bar(); var bar_point = bar.get_global_rect().position + Vector2(bar.size.x*0.5,12); var before = scroll.scroll_vertical
	touch(hud,3,bar_point,true); drag(hud,3,bar_point+Vector2(0,70)); touch(hud,3,bar_point+Vector2(0,70),false)
	expect(scroll.scroll_vertical > before,"scrollbar touch drag moves content in thumb direction")
	expect(clicks == 1,"scrollbar drag does not activate content")
	hud.panel.visible = false
	var fire_point = hud.find_action_rect("fire").get_center(); touch(hud,4,fire_point,true)
	expect(hud.fire_held and hud.fire_touch == 4,"fire owns independent touch")
	touch(hud,4,fire_point,false); expect(not hud.fire_held,"fire release clears independently")
	expect(hud.find_action_rect("reload").size.x > 40 and hud.find_action_rect("bandage").size.x > 40,"semantic action rectangles available")
	game.free(); print("TOUCH UI RESULT: %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
