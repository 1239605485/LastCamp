extends SceneTree
var game
func _initialize():
	root.size=Vector2i(1584,720); call_deferred("run")
func shot(name:String):
	game.hud.refresh(); game.camera.position=game.player_pos()+Vector2(0,-40); game.view.queue_redraw()
	await process_frame; RenderingServer.force_draw(); root.get_texture().get_image().save_png("res://builds/"+name+".png")
func run():
	game=load("res://main.tscn").instantiate(); game.world.save_directory="user://preview-v05"; root.add_child(game); await process_frame; await process_frame
	root.size=Vector2i(1584,720); await process_frame; await process_frame
	game.set_process(false); game.world.new_world(20261026); game.hud.controls_path="user://preview-v05-controls.cfg"; game.hud.reset_control_layout(false); game.hud.update_display_layout(); game.hud.close_panel()
	game.set_pos(Vector2(470,440)); await shot("v05-fullscreen")
	var icon_button=game.hud.touch_buttons.filter(func(b):return is_instance_valid(b) and b.get_meta("action_name","")=="interact")[0]
	icon_button.icon.get_image().save_png("res://builds/v05-interact-icon.png")
	print("interact icon size "+str(icon_button.icon.get_size())+" image "+str(icon_button.icon.get_image().get_size()))
	game.hud.selected_control="interact"; game.hud.start_layout_editor(); game.hud.control_layout.interact.size=112; game.hud.apply_control_layout(); game.hud.update_layout_label(); await shot("v05-controls-fullscreen"); game.hud.close_panel()
	game.hud.open_panel("mechanics"); await shot("v05-mechanics"); game.hud.close_panel()
	game.world.state.zone="town"; var b=game.world.map.buildings[0]; var door=game.Geometry.door(b).get_center(); game.set_pos(door+Vector2(0,25)); game.world.add_item("wood",8,"player")
	game.Tactics.complete(game,{"kind":"tac_door_board","id":"house0"}); game.hud.open_panel("mechanics"); await shot("v05-door-actions"); game.hud.close_panel()
	game.world.state.zone="camp"; game.set_pos(Vector2(800,700)); game.aim=Vector2.RIGHT; game.Tactics.complete(game,{"kind":"tac_trap","trap":"spike"}); await shot("v05-trap")
	game.set_pos(Vector2(740,420)); game.hud.open_panel("mechanics"); await shot("v05-trade"); game.hud.close_panel()
	game.world.state.minute=2040; game.Survival.advance(game.world,1); game.hud.open_panel("map"); await shot("v05-event-map"); game.hud.close_panel()
	var event=game.Survival.event_markers(game.world)[0]; game.world.state.zone="town"; game.set_pos(Vector2(event.x,event.y)+Vector2(0,45)); await shot("v05-event")
	game.world.state.systems_v5.weather="heavy_rain"; await shot("v05-rain")
	game.world.state.zone="camp"; game.set_pos(Vector2(470,440)); game.world.state.minute=1260; game.world.state.systems_v5.flashlight_on=true; game.world.state.systems_v5.generator_on=true; game.world.state.systems_v5.fuel_minutes=120; await shot("v05-night-power")
	for voice in game.sound.voices: voice.stop()
	game.queue_free(); await create_timer(0.2).timeout; print("V05 previews: 10 captured, viewport "+str(root.size)); quit()


