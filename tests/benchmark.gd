extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var game = load("res://main.tscn").instantiate()
	game.world.save_directory = "user://benchmark"
	root.add_child(game)
	await process_frame
	var results: Array = []
	for count in [30,60,100]:
		game.world.new_world(); game.world.enemies.clear(); game.world.state.zone = "town"
		game.set_pos(Vector2(600,500)); game.world.state.hp = 100000; game.world.paused = false
		game.hud.close_panel()
		for i in range(count):
			game.world.spawn_enemy("town",Vector2(550 + (i % 10) * 21,440 + (i / 10) * 18),"normal")
		await create_timer(1.0).timeout
		var frames = 0; var worst = 0.0; var start = Time.get_ticks_usec(); var previous = start
		while Time.get_ticks_usec() - start < 3000000:
			await process_frame
			var now = Time.get_ticks_usec(); worst = maxf(worst,float(now - previous) / 1000.0); previous = now; frames += 1
		var elapsed = float(Time.get_ticks_usec() - start) / 1000000.0
		results.append({"enemies":count,"average_fps":snappedf(frames / elapsed,0.1),"worst_frame_ms":snappedf(worst,0.1),"renderer":RenderingServer.get_video_adapter_name(),"platform":"Windows desktop; NOT Android"})
		print(results.back())
	var file = FileAccess.open("user://desktop-benchmark.json",FileAccess.WRITE); file.store_string(JSON.stringify(results,"  ")); file.close()
	game.queue_free(); await create_timer(0.3).timeout; quit()

