extends Control
const Survival = preload("res://scripts/survival_systems.gd")

var game
var zoom = 1.0
var center = Vector2(5120,4480)
var dragging = false
var drag_start = Vector2.ZERO
var last_pointer = Vector2.ZERO
var font: Font

func _ready():
	custom_minimum_size = Vector2(880,300); clip_contents = true
	font = load("res://assets/NotoSansCJKsc-Regular.otf")
	queue_redraw()

func scale_factor() -> float:
	return minf(size.x / game.world.map.size.x,size.y / game.world.map.size.y) * zoom

func to_view(world: Vector2) -> Vector2:
	return (world - center) * scale_factor() + size / 2

func to_world(screen: Vector2) -> Vector2:
	return (screen - size / 2) / scale_factor() + center

func change_zoom(multiplier: float):
	zoom = clampf(zoom * multiplier,0.8,6.0); queue_redraw()

func _draw():
	if game == null or font == null: return
	var map = game.world.map; var s = scale_factor()
	draw_rect(Rect2(Vector2.ZERO,size),Color("101e20"))
	for y in range(0,int(map.size.y),256):
		for x in range(0,int(map.size.x),256):
			var pos = Vector2(x,y); var terrain = map.terrain_at(pos)
			var color = {"grass":Color("aaa487"),"forest":Color("69785c"),"urban":Color("b0a186"),"shore":Color("c9ba8e"),"water":Color("577785")}[terrain]
			if map.sector_id(pos) not in game.world.state.explored: color = color.darkened(0.4)
			draw_rect(Rect2(to_view(pos),Vector2(257,257)*s),color)
	for road in map.roads: draw_line(to_view(road.a),to_view(road.b),Color("6e6959"),maxf(1,70*s))
	for sector in map.sectors:
		if sector.id in game.world.state.explored and zoom >= 1.3: draw_string(font,to_view(sector.get("center",sector.rect.get_center()))+Vector2(3,-12),sector.name,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e2d5a8"))
	for b in map.buildings:
		if map.sector_id(b.rect.get_center()) not in game.world.state.explored: continue
		var color = {"house":Color("d5bb89"),"clinic":Color("8fc4bb"),"police":Color("9daecc"),"shop":Color("c29c7a")}[b.kind]
		draw_rect(Rect2(to_view(b.rect.position),b.rect.size * s).grow(1),color)
	var player = to_view(game.player_pos()) if game.world.state.zone == "town" else to_view(Vector2(45,490))
	draw_circle(player,5,Color("e5c465")); draw_arc(player,9,0,TAU,20,Color("e5c465"),1)
	var camp = to_view(Vector2(30,490)); draw_rect(Rect2(camp - Vector2(5,5),Vector2(10,10)),Color("8adca4"))
	for grave in game.world.graves:
		if grave.zone == "town": draw_circle(to_view(Vector2(grave.x,grave.y)),4,Color("d18c66"))
	for npc in game.world.npcs:
		if npc.zone == "town" and npc.status == "down": draw_circle(to_view(Vector2(npc.x,npc.y)),4,Color("ee8e89"))
	for event in Survival.event_markers(game.world):
		var pos=to_view(Vector2(event.x,event.y))
		draw_rect(Rect2(pos-Vector2(5,5),Vector2(10,10)),Color("e4c77f") if event.type=="supply" else Color("8dd9cd"))
		draw_string(font,pos+Vector2(8,3),"空投" if event.type=="supply" else "求救",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f0e8cd"))
	if game.world.state.has("waypoint"):
		var p = to_view(Vector2(game.world.state.waypoint[0],game.world.state.waypoint[1]))
		draw_line(player,p,Color("d9c572"),1); draw_arc(p,6,0,TAU,16,Color("f4df8a"),2)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed: change_zoom(1.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed: change_zoom(0.8)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: dragging = true; drag_start = event.position; last_pointer = event.position
			else:
				if dragging and drag_start.distance_to(event.position) < 10:
					var pos = to_world(event.position).clamp(Vector2.ZERO,game.world.map.size)
					game.world.state["waypoint"] = [pos.x,pos.y]
				dragging = false; queue_redraw()
		accept_event()
	if event is InputEventMouseMotion and dragging:
		center -= (event.position - last_pointer) / scale_factor(); last_pointer = event.position
		center = center.clamp(Vector2.ZERO,game.world.map.size); queue_redraw(); accept_event()
