extends SceneTree
const Map = preload("res://scripts/world_map.gd")
const World = preload("res://scripts/world.gd")
var failures=0
func expect(ok: bool,message: String):
	if not ok: failures+=1; printerr("FAIL: ",message)
func _initialize():
	var map=Map.new(471113,4)
	var main_street=map.roads.any(func(r):return absf(r.a.y-650.0)<0.1 and absf(r.b.y-650.0)<0.1)
	expect(main_street,"starter town keeps its main street below the park and player")
	var crossing=Rect2(0,605,1280,90)
	expect(map.buildings.filter(func(b):return b.container in ["house","clinic","police"] and b.rect.intersects(crossing)).is_empty(),"starter buildings leave the street corridor unobstructed")
	var w=World.new(); w.new_world(471113)
	expect(absf(w.state.px-900.0)<40.0 and absf(w.state.py-450.0)<40.0 and absf(w.state.py-650.0)>150.0,"new survivor starts north of the street beside the vertical road")
	print("REFERENCE_LAYOUT failures: ",failures)
	quit(1 if failures else 0)

