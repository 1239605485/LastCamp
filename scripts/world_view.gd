extends Node2D

const R = preload("res://scripts/rules.gd")
const Art = preload("res://scripts/art.gd")
const G = preload("res://scripts/building_geometry.gd")
const Pose = preload("res://scripts/actor_pose.gd")
const Forage = preload("res://scripts/forage.gd")
const Survival = preload("res://scripts/survival_systems.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
var game
var font: Font
var flashes: Array = []
var art
var animation_time = 0.0
var modulation: CanvasModulate
var lights: Array = []
var plant_textures = {"berry":load("res://assets/minidayz/environment/berry_bush.png"),"tomato":load("res://assets/minidayz/environment/plant_tomato.png"),"squash":load("res://assets/minidayz/environment/plant_squash.png")}

func _ready():
	font = load("res://assets/NotoSansCJKsc-Regular.otf"); art = Art.new()
	modulation = CanvasModulate.new(); add_child(modulation)
	var image = Image.create(128,128,false,Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var alpha = pow(clampf(1.0-Vector2(x-64,y-64).length()/64,0,1),1.7)
			image.set_pixel(x,y,Color(1,1,1,alpha))
	var texture = ImageTexture.create_from_image(image)
	for i in range(4):
		var light = PointLight2D.new(); light.texture = texture; light.texture_scale = 3.5 if i == 0 else 2.8
		light.color = Color("c9d7d7") if i == 0 else Color("ffbf72"); add_child(light); lights.append(light)

static func night_strength(minute: float) -> float:
	var t = fposmod(minute,1440)
	if t >= 1200 or t < 300: return 1.0
	if t >= 1050: return (t-1050)/150.0
	if t < 420: return 1.0-(t-300)/120.0
	return 0.0

func _process(delta):
	if game == null or game.world.state.is_empty() or modulation == null: return
	if not game.world.paused: animation_time += delta
	var night = night_strength(game.world.state.minute)
	var systems:Dictionary=game.world.state.systems_v5
	var weather_dark={"clear":0.0,"cloudy":0.12,"rain":0.2,"heavy_rain":0.3}.get(systems.weather,0.0)
	modulation.color = Color.WHITE.lerp(Color("667b87"),weather_dark).lerp(Color("14232e"),night)
	for i in range(lights.size()):
		lights[i].energy = night * (1.25 if i == 0 else 1.6)
		lights[i].visible = i == 0 or game.world.state.zone == "camp"
	lights[0].energy=night*1.25 if systems.flashlight_on and systems.battery>0 else 0.0
	lights[1].energy=night*0.7
	for i in [2,3]: lights[i].energy=night*1.6 if systems.generator_on and systems.fuel_minutes>0 else 0.0
	lights[0].position = game.player_pos()
	if game.current_stats().get("light",false): lights[0].position += game.aim * 95; lights[0].texture_scale = 5.0
	else: lights[0].texture_scale = 3.5
	lights[1].position = Vector2(436,491); lights[2].position = Vector2(440,325); lights[3].position = Vector2(573,435)

func block(rect: Rect2,color: Color):
	draw_rect(rect.grow(1),color.darkened(0.45)); draw_rect(rect,color)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x,3)),color.lightened(0.15))

func label_at(pos: Vector2,message: String,color: Color = Color("ded9bc"),size: int = 12):
	draw_string(font,pos+Vector2.ONE,message,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("172124"))
	draw_string(font,pos,message,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func prop(pos: Vector2,region: Rect2,scale_factor: float = 2.0):
	draw_texture_rect_region(art.props,Rect2(pos,region.size*scale_factor),region)

func mini_ground(area: Rect2):
	for y in range(int(floor(area.position.y/60)),int(ceil(area.end.y/60))):
		for x in range(int(floor(area.position.x/60)),int(ceil(area.end.x/60))):
			var p = Vector2(x,y)*60; var center = p+Vector2(30,30)
			var terrain = game.world.map.terrain_at(center) if game.world.state.zone == "town" else "grass"
			var source = {"grass":Rect2(60,60,60,60),"forest":Rect2(360,60,60,60),"urban":Rect2(60,60,60,60),"shore":Rect2(660,360,60,60),"water":Rect2(660,60,60,60)}[terrain]
			if (game.world.state.zone == "town" and game.world.map.road_at(center)) or (game.world.state.zone == "camp" and center.y>455 and center.y<530 and center.x>620): source = Rect2(360,360,60,60)
			draw_texture_rect_region(art.mini_ground,Rect2(p,Vector2(60,60)),source)
			if terrain not in ["water","shore"] and posmod(x*73+y*131+game.world.map.seed,83)==0 and not game.world.map.road_at(center):
				draw_texture_rect_region(art.mini_decor,Rect2(p+Vector2(10,5),Vector2(30,30)),Rect2(0,0,30,30))

func actor_frame(direction: Vector2,kind: String,walking: bool,step: int,armed: bool = false) -> int:
	return Pose.frame(direction,kind,walking,step,armed)

func actor(pos: Vector2,direction: Vector2,kind: String = "player",down: bool = false,walking_override: bool = false):
	pos = pos.round()
	draw_texture_rect(art.shadow,Rect2(pos+Vector2(-10,1),Vector2(20,8)),false,Color(1,1,1,0.55))
	if down:
		draw_texture_rect_region(art.mini_player,Rect2(pos+Vector2(-16,-16),Vector2(32,32)),Rect2(3*32,10*32,32,32))
		label_at(pos+Vector2(-18,-22),"待救",Color("edbb71")); return
	var zed = kind in ["normal","fast","breaker"]
	var searching = kind=="player" and game.is_searching()
	var resting=kind=="player" and game.world.state.systems_v5.resting
	var walking = game.moving if kind=="player" else walking_override
	var armed = kind=="player" and game.world.state.weapon!="knife" and not resting
	var facing = game.walk_direction if kind=="player" and walking and game.combat_state=="move" and game.hud.aim_axis.length()<0.2 and not game.hud.fire_held else direction
	var step = int(animation_time*(9 if kind=="fast" else 7))%4
	var frame = actor_frame(facing,kind,walking,step,armed)
	if searching: frame = 36+int(animation_time*5)%3
	if resting: frame=37
	var rect = Rect2(pos+Vector2(-16,-27),Vector2(32,32))
	var source = Rect2(posmod(frame,4)*32,int(frame/4)*32,32,32)
	draw_texture_rect_region(art.mini_enemies[kind] if zed else art.mini_player,rect,source)
	if resting and game.world.state.systems_v5.sleeping: label_at(pos+Vector2(7,-24),"Z",Color("b5d7db"),12)
	if armed and walking and not searching:
		var upper=actor_frame(facing,"player",false,0,true)
		draw_texture_rect_region(art.mini_player,Rect2(rect.position,Vector2(32,20)),Rect2(posmod(upper,4)*32,int(upper/4)*32,32,20))
	if kind=="player" and armed and not searching:
		var origin = Pose.grip(pos)
		var gun = art.mini_icons.get(game.world.state.weapon)
		var length = Pose.gun_length(game.world.state.weapon)
		
		if gun != null:
			draw_set_transform(origin,direction.angle(),Vector2(1,-1 if direction.x<0 else 1))
			var height = clampf(length*gun.get_height()/float(gun.get_width()),4,11)
			draw_texture_rect(gun,Rect2(2,-height/2,length,height),false)
			draw_circle(Vector2(6,2),2,Color("c99c76")); draw_circle(Vector2(12,2),2,Color("c99c76"))
			draw_set_transform(Vector2.ZERO)

func draw_car(car: Dictionary):
	var column = 1 if game.world.state.searched.has(car.id) else 0
	draw_texture_rect_region(art.mini_car,Rect2(car.pos-Vector2(51,28),Vector2(102,52)),Rect2(column*102,car.variant*52,102,52))

func tree_frame(tree: Dictionary) -> Dictionary:
	var variant = posmod(int(tree.variant),art.mini_trees.size())
	var texture: Texture2D = art.mini_trees[variant]
	# The source sheets have two horizontal frames: living tree / fallen tree.
	var region = Rect2(0,0,texture.get_width()/2,texture.get_height())
	var anchor = Vector2([42,56,50][variant],texture.get_height()-7)
	return {"texture":texture,"region":region,"rect":Rect2(tree.pos-anchor,region.size)}

func draw_tree(tree: Dictionary):
	var frame = tree_frame(tree)
	var rect: Rect2 = frame.rect
	var alpha = 0.35 if rect.has_point(game.player_pos()) and game.player_pos().y < tree.pos.y else 1.0
	draw_texture_rect_region(frame.texture,rect,frame.region,Color(1,1,1,alpha))

func draw_plant(plant: Dictionary):
	var ready = Forage.ready(game.world.state.harvests,plant.id,int(game.world.state.minute))
	if plant.kind == "apple":
		var frame = tree_frame({"pos":plant.pos,"variant":1})
		var rect: Rect2 = frame.rect
		var alpha = 0.4 if rect.has_point(game.player_pos()) and game.player_pos().y<plant.pos.y else 1.0
		draw_texture_rect_region(frame.texture,rect,frame.region,Color(1,1,1,alpha))
		if ready:
			for offset in [Vector2(-14,-39),Vector2(6,-56),Vector2(16,-32),Vector2(-4,-25)]:
				draw_texture_rect(art.icon("apple"),Rect2(plant.pos+offset,Vector2(7,7)),false,Color(1,1,1,alpha))
	else:
		var texture: Texture2D = plant_textures[plant.kind]
		var size = Vector2(30,30) if plant.kind=="berry" else Vector2(24,28)
		var region = Rect2(30 if ready else 0,0,30,30) if plant.kind=="berry" else Rect2(30,30 if ready else 0,30,30)
		draw_texture_rect_region(texture,Rect2(plant.pos-Vector2(size.x/2,size.y-4),size),region)

func _draw():
	if game==null or game.world.state.is_empty() or art==null: return
	var w = game.world; var town = w.state.zone=="town"; var player = game.player_pos()
	var extent = get_viewport_rect().size / maxf(0.65,game.world_zoom) / 2.0 + Vector2(120,120)
	var area = Rect2(player-extent,extent*2)
	mini_ground(area)
	var radius=maxf(1200,extent.length())
	var buildings = w.map.buildings_at(player,radius) if town else []
	for b in buildings: building(b)
	if not town: camp()
	var cars = w.map.cars_at(player,radius,w.state.zone); var trees = w.map.trees_at(player,radius,w.state.zone)
	var plants = w.map.plants_at(player,radius,w.state.zone)
	for trap in w.state.tactics_v5.traps:
		if trap.zone!=w.state.zone or Vector2(trap.x,trap.y).distance_to(player)>radius: continue
		var color=Color("bba46a") if trap.armed else Color("665d4c")
		if trap.kind=="spike":
			for x in [-12,0,12]: draw_colored_polygon(PackedVector2Array([Vector2(trap.x+x-5,trap.y+5),Vector2(trap.x+x,trap.y-9),Vector2(trap.x+x+5,trap.y+5)]),color)
		else:
			draw_line(Vector2(trap.x-20,trap.y),Vector2(trap.x+20,trap.y),color,1)
			draw_texture_rect(art.icon("food"),Rect2(trap.x-5,trap.y-9,10,13),false,color)
	for event in Survival.event_markers(w):
		if event.zone!=w.state.zone or Vector2(event.x,event.y).distance_to(player)>radius: continue
		var p=Vector2(event.x,event.y)
		if event.type=="supply": block(Rect2(p-Vector2(18,20),Vector2(36,28)),Color("637a57")); label_at(p+Vector2(-24,-30),"补给空投",Color("efce7c"))
		else: actor(p,Vector2.DOWN,"npc"); label_at(p+Vector2(-24,-35),"求救幸存者",Color("efce7c"))
	for plant in plants:
		if plant.pos.y <= player.y: draw_plant(plant)
	for car in cars:
		if car.pos.y <= player.y: draw_car(car)
	for tree in trees:
		if tree.pos.y <= player.y: draw_tree(tree)
	for f in w.furniture:
		if f.zone==w.state.zone and not f.packed and f.hp>0 and game.can_see_actor(Vector2(f.x,f.y)):
			draw_texture_rect(art.icon("cabinet"),Rect2(f.x-16,f.y-22,32,30),false)
	for grave in w.graves:
		if grave.zone==w.state.zone:
			draw_texture_rect(art.icon("backpack"),Rect2(grave.x-12,grave.y-16,24,20),false); label_at(Vector2(grave.x-16,grave.y-22),"遗物",Color("e4b989"))
	var actors: Array = [{"pos":player,"kind":"player","dir":game.aim,"down":false}]
	for n in w.npcs:
		if n.zone==w.state.zone and game.can_see_actor(Vector2(n.x,n.y)): actors.append({"pos":Vector2(n.x,n.y),"kind":"npc","dir":Vector2(n.get("facing_x",0),n.get("facing_y",1)),"walking":n.get("walking",false),"down":n.status=="down","name":n.name})
	for e in w.enemies:
		if e.zone==w.state.zone and e.hp>0 and game.can_see_actor(Vector2(e.x,e.y)): actors.append({"pos":Vector2(e.x,e.y),"kind":e.kind,"dir":Vector2(e.get("facing_x",0),e.get("facing_y",1)),"walking":e.get("walking",false),"down":false})
	actors.sort_custom(func(a,b): return a.pos.y<b.pos.y)
	for a in actors:
		actor(a.pos,a.dir,a.kind,a.down,a.get("walking",false))
		if a.has("name"): label_at(a.pos+Vector2(-20,-32),a.name,Color("dce5cc"))
	for b in buildings:
		if not G.interior(b).has_point(player):
			var texture: Texture2D = art.mini_buildings[b.art].outside
			var rect = G.outside_frame(b,texture.get_size())
			if rect.has_point(player) and player.y < G.door(b).get_center().y: draw_texture_rect(texture,rect,false,Color(1,1,1,0.32))
	for car in cars:
		if car.pos.y > player.y: draw_car(car)
	for tree in trees:
		if tree.pos.y > player.y: draw_tree(tree)
	for plant in plants:
		if plant.pos.y > player.y: draw_plant(plant)
	if not game.is_searching():
		var reticle = player+game.aim*lerpf(85,140,game.focus)
		draw_arc(reticle,lerpf(15,4,game.focus),0,TAU,16,Color(0.9,0.85,0.6,0.7),1)
	for flash in flashes: draw_line(flash.a,flash.b,Color(1,0.83,0.46,flash.life*9),2)
	if not game.placement.is_empty():
		var p = game.placement_position(); draw_rect(Rect2(p-Vector2(16,16),Vector2(32,32)),Color(0.5,0.85,0.6,0.65) if game.valid_placement(p) else Color(0.9,0.35,0.25,0.65))
	var target = game.nearest_target()
	if not target.is_empty():
		draw_arc(target.pos,24,0,TAU,24,Color("dfc88e"),1); label_at(target.pos+Vector2(-25,-30),target.name,Color("f5deb0"),12)
	if town:
		for win in Tactics.windows(w,player,radius):
			block(win.rect,Color("8c754b") if win.state.board_hp>0 else (Color("364748") if win.state.broken else Color("8bb9be")))
	weather_overlay(area,buildings)

func building(b: Dictionary):
	var appearance = art.mini_buildings[b.art]
	draw_texture_rect(appearance.inside,G.frame(b),false)
	var inside = G.interior(b).has_point(game.player_pos())
	if not inside:
		var texture: Texture2D = appearance.outside
		var rect = G.outside_frame(b,texture.get_size())
		draw_texture_rect(texture,rect,false,Color(1,1,1,0.28 if rect.has_point(game.player_pos()) else 1.0))
	else:
		var p = game.container_pos(b.container); draw_texture_rect(art.icon("cabinet"),Rect2(p-Vector2(10,15),Vector2(20,20)),false)
	var door = G.door(b)
	var state=Tactics.door_state(game.world,b.container+"0")
	if Tactics.door_blocked(game.world,b):
		block(door,Color("816d4c"))
		if state.board_hp>0: draw_line(door.position-Vector2(0,6),door.end+Vector2(0,6),Color("c4a366"),4)
	else: draw_line(door.position,door.position+Vector2(0,16),Color("947e57"),2)
	label_at(Vector2(b.rect.position.x,b.rect.end.y+15),b.name,Color("ded6b9"),12)

func camp():
	var w = game.world
	block(Rect2(300,290,150,88),Color("566d69")); block(Rect2(292,280,166,28),Color("344e51")); block(Rect2(357,335,28,43),Color("947b55"))
	label_at(Vector2(303,268),"核心避难屋",Color("d7ddba"),13); bar(Vector2(300,385),w.state.core/400.0,150,Color("8abf98"))
	if w.state.wall>0:
		for x in range(255,630,96): prop(Vector2(x,247),Rect2(0,32,48,16))
	bar(Vector2(300,235),w.state.wall/240.0,220,Color("c9ae6e")); label_at(Vector2(330,225),"北侧防线",Color("e1c797"),12)
	for p in [Vector2(573,435),Vector2(620,380)]: draw_texture_rect(art.icon("cabinet"),Rect2(p-Vector2(18,27),Vector2(36,34)),false)
	label_at(Vector2(540,395),"仓库"); label_at(Vector2(595,340),"军械箱")
	block(Rect2(310,470,62,25),Color("8a775c")); label_at(Vector2(305,460),"工作台")
	prop(Vector2(496,485),Rect2(0,16,16,16)); label_at(Vector2(495,478),"医疗角")
	prop(Vector2(420,475),Rect2(16,0,16,16))
	label_at(Vector2(730,440),"沿路向东 →",Color("eee0b2"),13)
	actor(Vector2(740,420),Vector2.DOWN,"npc"); label_at(Vector2(714,386),"中立商人",Color("e1c894"))
	block(Rect2(408,415,40,22),Color("56615c")); draw_texture_rect(art.icon("fuel"),Rect2(416,417,14,16),false)
	label_at(Vector2(400,407),"发电机",Color("e1c894"))
	block(Rect2(495,505,26,38),Color("796c52")); draw_rect(Rect2(497,509,22,30),Color("637d74")); draw_rect(Rect2(498,508,20,8),Color("b6b89a"))
	label_at(Vector2(483,557),"床位",Color("e1c894"))
	for d in w.defenses:
		if d.hp<=0: continue
		if d.kind=="wire":
			for x in range(-28,29,14):
				draw_line(Vector2(d.x+x,d.y-8),Vector2(d.x+x+15,d.y+8),Color("9a9d89"),2); draw_line(Vector2(d.x+x,d.y+8),Vector2(d.x+x+15,d.y-8),Color("9a9d89"),2)
		elif d.kind=="barricade":
			block(game.defense_rect(d),Color("9a8056")); draw_line(Vector2(d.x-30,d.y-6),Vector2(d.x+30,d.y+6),Color("554e3c"),3)
		else:
			block(game.defense_rect(d),Color("6d7660")); block(Rect2(d.x-22,d.y-25,44,10),Color("8a835e")); draw_rect(Rect2(d.x-4,d.y-38,8,15),Color("45514c"))
		bar(Vector2(d.x-25,d.y+18),d.hp/d.max_hp,50,Color("bfad76"))

func bar(pos: Vector2,value: float,width: float,color: Color):
	draw_rect(Rect2(pos,Vector2(width,4)),Color("303c3c")); draw_rect(Rect2(pos,Vector2(width*clampf(value,0,1),4)),color)




func weather_overlay(area:Rect2,buildings:Array):
	var weather=game.world.state.systems_v5.weather
	if weather not in ["rain","heavy_rain"]: return
	var count=65 if weather=="rain" else 130
	for i in range(count):
		var p=area.position+Vector2(fposmod(i*193.0+animation_time*80,area.size.x),fposmod(i*127.0+animation_time*390,area.size.y))
		var inside=false
		for b in buildings:
			if G.interior(b).has_point(p): inside=true; break
		if not inside: draw_line(p,p+Vector2(-5,16),Color(0.65,0.78,0.84,0.3 if weather=="rain" else 0.48),1)
