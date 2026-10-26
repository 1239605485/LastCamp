extends SceneTree
const Game = preload("res://scripts/game.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
const G = preload("res://scripts/building_geometry.gd")
var failures = 0
var checks = 0
func expect(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",message)
func _initialize():
	var game = Game.new()
	game.world.new_world(321)
	expect(game.has_method("cool_recoil"),"burst recoil recovers separately from aim focus")
	if not game.has_method("cool_recoil"):
		game.free(); quit(1); return
	var recoil = load("res://scripts/weapon_recoil.gd")
	var heat = 0.0
	for i in range(100): heat = recoil.after_shot(heat,0.05)
	expect(is_equal_approx(heat,recoil.MAX_SPREAD),"long burst has bounded spread")
	expect(recoil.cool(heat,0.5)<heat,"ceasing fire recovers precision")
	expect(recoil.cool(heat,10)==0.0,"recovery does not overshoot")
	var first: String=game.world.player_weapon("pistol")
	var second: String=game.world.add_item("rifle",1,"player")
	game.recoil_heat = {first:0.1,second:0.2}
	game.cool_recoil(0.25)
	expect(game.recoil_heat[first]<0.1 and game.recoil_heat[second]<0.2,"switched-away weapons also cool independently")
	var w = game.world
	w.enemies.clear()
	var b = w.map.buildings[0]
	game.set_pos(G.door(b).get_center()+Vector2(0,18))
	w.add_item("wood",4,"player")
	var id: String = b.container+"0"
	expect(Tactics.actions(game).any(func(a):return a.request.kind=="tac_door_board" and a.request.id==id),"safe opening offers boarding")
	w.spawn_enemy("town",G.door(b).get_center()+Vector2(0,30),"normal")
	var before = w.count_item("wood")
	expect(not Tactics.complete(game,{"kind":"tac_door_board","id":id}),"enemy at opening blocks completion")
	expect(w.count_item("wood")==before,"blocked boarding keeps materials")
	expect(Tactics.actions(game).any(func(a):return a.label.contains("敌人贴近")),"blocked boarding explains threat")
	game.free()
	print("REFERENCE_COMBAT: ",checks-failures,"/",checks)
	quit(1 if failures else 0)
