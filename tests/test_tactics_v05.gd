extends SceneTree
const W = preload("res://scripts/world.gd")
const T = preload("res://scripts/tactical_systems.gd")
const N = preload("res://scripts/local_navigation.gd")
const Game = preload("res://scripts/game.gd")
class FakeGame extends RefCounted:
	var world
	var aim = Vector2.RIGHT
	var solid_cache_key = 0
	var obstacle = Rect2(40,-35,20,70)
	func player_pos() -> Vector2: return Vector2(world.state.px,world.state.py)
	func set_pos(p: Vector2): world.state.px = p.x; world.state.py = p.y
	func blocked(p: Vector2) -> bool: return obstacle.has_point(p)
	func valid_placement(p: Vector2) -> bool: return not blocked(p)
	func move_with_collision(p: Vector2, delta: Vector2) -> Vector2:
		return p if blocked(p+delta) else p+delta
func _init():
	var w = W.new(); w.new_world(471113); T.ensure(w)
	assert(w.state.tactics_v5.traps.is_empty())
	assert(T.valid_state(w.state))
	var corrupt = w.state.duplicate(true); corrupt.tactics_v5.traps = "bad"; assert(not T.valid_state(corrupt))
	w.state.tactics_v5 = {"doors":{"repair":{"hp":"bad","board_hp":12,"broken":false}},"windows":[],"traps":[{"id":"preserve","kind":"alarm","zone":"camp","x":100.0,"y":100.0,"hp":40.0,"armed":true},"bad"]}
	T.ensure(w); assert(T.valid_state(w.state)); assert(w.state.tactics_v5.traps.size() == 1); assert(w.state.tactics_v5.traps[0].id == "preserve"); assert(w.state.tactics_v5.doors.repair.board_hp == 12)
	w.state.tactics_v5.traps.clear()
	assert(T.door_blocked(w,w.map.buildings[0]))
	assert(not T.damage_door(w,"house0",20))
	assert(T.damage_door(w,"house0",1000))
	assert(w.doors.house0)
	assert(not T.door_blocked(w,w.map.buildings[0]))
	var door = T.door_state(w,"house0"); door.board_hp = 120
	assert(T.door_blocked(w,w.map.buildings[0])); assert(not T.damage_door(w,"house0",40)); assert(door.board_hp == 80)
	assert(T.damage_door(w,"house0",100)); assert(not T.door_blocked(w,w.map.buildings[0]))
	var wood: int = w.count_item("wood","warehouse")
	assert(not T.spend(w,{"wood":2,"parts":999})); assert(w.count_item("wood","warehouse") == wood)
	w.state.zone = "town"; assert(not T.spend(w,{"wood":1})); assert(w.count_item("wood","warehouse") == wood)
	w.state.tactics_v5.traps.append({"id":"test","kind":"spike","zone":"camp","x":500.0,"y":500.0,"armed":true,"hp":40.0})
	w.enemies = [{"id":"test_enemy","zone":"camp","x":500.0,"y":500.0,"hp":100.0,"alert":0.0}]
	T.advance_offscreen(w,1); assert(w.enemies[0].hp == 45)
	T.advance_offscreen(w,1); assert(w.enemies[0].hp == 45)
	var game = FakeGame.new(); game.world = w
	w.state.zone = "camp"; game.set_pos(Vector2.ZERO)
	var next: Vector2 = N.next_step(game,Vector2.ZERO,Vector2(100,0),80,0.1)
	assert(next != Vector2.ZERO and not game.blocked(next))
	var turn: Vector2 = N.next_step(game,Vector2(20,0),Vector2(100,0),80,0.1)
	assert(absf(turn.y) > 0,"Route should detour vertically around the wall")
	assert(N.next_step(game,Vector2.ZERO,Vector2(50,0),80,0.1) == Vector2.ZERO,"Blocked goals must wait safely")
	w.furniture = [{"id":"cab","zone":"camp","x":24.0,"y":0.0,"packed":false,"hp":90.0}]
	var stamina: float = w.state.stamina
	assert(not T.move_furniture(game,"cab",false)); assert(w.furniture[0].x == 24); assert(w.state.stamina == stamina); assert(not w.furniture[0].packed)
	w.npcs[0].x = 0; w.npcs[0].y = 0
	assert(T.complete(game,{"kind":"tac_order","id":w.npcs[0].id,"order":"holdfire","remaining":0,"duration":0.4,"zone":"camp"}))
	assert(w.npcs[0].hold_fire)
	# Every window provides a short, static-geometry-safe landing on both sides.
	var wins: Array = T.windows(w,Vector2(500,300),2000)
	assert(not wins.is_empty())
	for win in wins: assert(win.inside.distance_to(win.outside) <= 40)
	game.obstacle = Rect2(1000,1000,20,20); w.furniture[0].x = 40; game.set_pos(Vector2.ZERO)
	assert(T.move_furniture(game,"cab",true)); assert(w.furniture[0].x == 16); assert(game.player_pos() == Vector2(-24,0))
	var actual = Game.new(); actual.world.new_world(471113); actual.world.state.zone = "town"
	var climbed = false
	for win in T.windows(actual.world,Vector2(500,300),2000):
		actual.set_pos(win.outside); actual.solid_cache_key = -1
		if actual.blocked(win.inside) or actual.blocked(win.outside): continue
		win.state.broken = true; win.state.hp = 0
		assert(T.complete(actual,{"kind":"tac_window_climb","id":win.id}))
		assert(actual.player_pos().distance_to(win.inside) < 1 and not actual.blocked(actual.player_pos()))
		assert(T.complete(actual,{"kind":"tac_window_climb","id":win.id}))
		assert(actual.player_pos().distance_to(win.outside) < 1); climbed = true; break
	assert(climbed,"At least one native window must permit a safe round trip")
	actual.free()
	print("TACTICS_V05_OK"); quit()




