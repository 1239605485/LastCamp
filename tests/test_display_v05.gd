extends SceneTree
var checks=0
var failures=0
func expect(v:bool,s:String):
	checks+=1
	if not v: failures+=1; printerr("FAIL: "+s)
func _initialize(): call_deferred("run")
func touch(h,id,p,down):
	var e=InputEventScreenTouch.new(); e.index=id; e.position=p; e.pressed=down; h._input(e)
func drag(h,id,p):
	var e=InputEventScreenDrag.new(); e.index=id; e.position=p; h._input(e)
func run():
	root.size=Vector2i(1584,720)
	var g=load("res://main.tscn").instantiate(); g.world.save_directory="user://display-v05"; root.add_child(g); await process_frame; await process_frame
	g.set_process(false); g.world.new_world(1234); var h=g.hud; h.controls_path="user://display-v05-controls.cfg"; h.reset_control_layout(false); h.close_panel(); h.update_display_layout()
	expect(root.get_visible_rect().size.x>=1580,"22:10 viewport expands beyond16:9")
	expect(h.find_action_rect("pause").position.x>1450,"right controls use wide screen edge")
	h.selected_control="interact"; h.start_layout_editor(); h.resize_selected_control(40)
	var b=h.touch_buttons.filter(func(v):return is_instance_valid(v) and v.get_meta("action_name","")=="interact")[0]
	expect(b.size==Vector2(112,112) and b.get_theme_constant("icon_max_width")==112,"112 size controls visible icon and hit box equally")
	expect(b.get_meta("icon_view").get_global_rect()==b.get_global_rect(),"drawn icon viewport equals touch rectangle")
	expect(b.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT)==0,"action icon has no hidden style inset")
	expect(b.icon.get_width()==b.icon.get_height(),"interact atlas is exactly one square frame")
	expect(Vector2(b.icon.get_image().get_used_rect().size)==b.icon.get_size(),"source alpha margin removed")
	var p=h.find_action_rect("interact").get_center(); touch(h,7,p,true); drag(h,7,Vector2(270,480)); touch(h,7,Vector2(270,480),false)
	expect(h.find_action_rect("interact").get_center().distance_to(Vector2(270,480))<1,"drag from right across center has no coordinate jump")
	var saved=h.find_action_rect("interact"); h.save_control_layout(); h.reset_control_layout(false); h.load_control_layout()
	expect(h.find_action_rect("interact").position.distance_to(saved.position)<1,"wide custom layout reloads in same location")
	h.open_panel("mechanics"); await process_frame
	expect(h.panel.visible and h.display_bounds.encloses(h.panel.get_global_rect()),"new mechanics menu fits expanded screen")
	root.size=Vector2i(1280,720); await process_frame; h.update_display_layout()
	for key in h.control_layout: expect(h.display_bounds.encloses(h.control_rect(key)),"saved control remains on16:9 screen: "+key)
	for v in g.sound.voices: v.stop()
	g.queue_free(); await process_frame
	print("DISPLAY V05 RESULT: %d checks, %d failures"%[checks,failures]); quit(1 if failures else 0)




