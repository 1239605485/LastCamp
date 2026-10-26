extends Node2D

const R = preload("res://scripts/rules.gd")
const Art = preload("res://scripts/art.gd")
const G = preload("res://scripts/building_geometry.gd")
const Pose = preload("res://scripts/actor_pose.gd")
const Forage = preload("res://scripts/forage.gd")
const Survival = preload("res://scripts/survival_systems.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
const Road = preload("res://scripts/road_profile.gd")
var game
var font: Font
var flashes: Array = []
var art
var animation_time = 0.0
var modulation: CanvasModulate
var lights: Array = []
var ground_cache: Dictionary = {}
var ground_order: Array[Vector2i] = []
var ground_seed = -1
var ground_map_id = ""
var grass_variants: Array = []
var detail_cache: Dictionary = {}
var detail_cache_seed = -1
var detail_cache_map_id = ""
var road_mark_cache: Dictionary = {}
var curb_horizontal: Image
var curb_vertical: Image
const TILE = 32
const CHUNK = 512

func _ready():
	font = load("res://assets/NotoSansCJKsc-Regular.otf"); art = Art.new()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

func _road_info(p: Vector2) -> Dictionary:
	var best={"distance":99999.0,"point":p,"dir":Vector2.RIGHT}
	for road in game.world.map.roads:
		var q=Geometry2D.get_closest_point_to_segment(p,road.a,road.b)
		var distance=p.distance_to(q)
		if distance<best.distance: best={"distance":distance,"point":q,"dir":(road.b-road.a).normalized()}
	return best

func _dirt(p: Vector2) -> bool:
	for b in game.world.map.buildings_at(p,450):
		var door=G.door(b).get_center()+Vector2(0,18)
		var road=_road_info(door)
		var line=Geometry2D.get_closest_point_to_segment(p,door,road.point)
		var wave=sin((line.y+line.x)*0.035+hash(b.container)%17)*9
		if p.distance_to(line+Vector2(wave,0))<23: return true
	return false

func ground_chunk(cx: int,cy: int) -> Texture2D:
	var key=Vector2i(cx,cy)
	var map_id=game.world.state.get("map_id","town")
	if ground_seed!=game.world.map.seed or ground_map_id!=map_id:
		ground_cache.clear(); ground_order.clear(); road_mark_cache.clear()
		ground_seed=game.world.map.seed; ground_map_id=map_id
	if ground_cache.has(key):
		ground_order.erase(key); ground_order.append(key)
		return ground_cache[key]
	var image=Image.create(256,256,false,Image.FORMAT_RGBA8)
	var atlas=Art.asset("Tiles/Background_Green_TileSet.png").get_image()
	if curb_horizontal==null:
		curb_horizontal=_make_curb(false); curb_vertical=_make_curb(true)
	if grass_variants.is_empty():
		for variant in range(4):
			var grass=atlas.get_region(Rect2i(0,0,16,16))
			if variant%2==1: grass.flip_x()
			if variant>1: grass.flip_y()
			grass_variants.append(grass)
	for ty in range(16):
		for tx in range(16):
			var p=Vector2(cx*CHUNK+tx*TILE+16,cy*CHUNK+ty*TILE+16)
			var tile=Vector2i(0,0)
			var road=_road_info(p)
			var forest=game.world.state.get("map_id","town")=="forest"
			if game.world.map.water_at(p):
				image.fill_rect(Rect2i(tx*16,ty*16,16,16),Color("54747b")); continue
			var band=Road.band(road.distance,forest)
			if band==Road.BAND_ASPHALT:
				tile=Vector2i(4,7)
			elif band==Road.BAND_CURB:
				var curb=curb_horizontal if absf(road.dir.x)>absf(road.dir.y) else curb_vertical
				image.blit_rect(curb,Rect2i(Vector2i.ZERO,Vector2i(16,16)),Vector2i(tx*16,ty*16))
				continue
			elif band==Road.BAND_SIDEWALK:
				tile=Vector2i(8,1)
			elif band==Road.BAND_DIRT:
				tile=Vector2i(6,7)
			elif _dirt(p):
				tile=Vector2i(8,1)
				if not _dirt(p+Vector2(TILE,0)): tile=Vector2i(5,6)
				elif not _dirt(p-Vector2(TILE,0)): tile=Vector2i(2,6)
			if tile==Vector2i.ZERO:
				image.blit_rect(grass_variants[posmod(hash([cx*16+tx,cy*16+ty]),4)],Rect2i(0,0,16,16),Vector2i(tx*16,ty*16))
			else: image.blit_rect(atlas,Rect2i(tile*16,Vector2i(16,16)),Vector2i(tx*16,ty*16))
	var tex=ImageTexture.create_from_image(image)
	if ground_cache.size()>=64:
		var oldest=ground_order.pop_front(); ground_cache.erase(oldest)
	ground_cache[key]=tex; ground_order.append(key)
	return tex

func _make_curb(vertical: bool) -> Image:
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color("999a91"))
	for i in range(16):
		if vertical:
			image.set_pixel(0,i,Color("777b75")); image.set_pixel(1,i,Color("b1b0a5")); image.set_pixel(14,i,Color("a5a49a")); image.set_pixel(15,i,Color("6d716c"))
		else:
			image.set_pixel(i,0,Color("777b75")); image.set_pixel(i,1,Color("b1b0a5")); image.set_pixel(i,14,Color("a5a49a")); image.set_pixel(i,15,Color("6d716c"))
	for i in [3,10]:
		if vertical:
			image.set_pixel(5,i,Color("8d8e86")); image.set_pixel(6,i,Color("a4a398"))
		else:
			image.set_pixel(i,5,Color("8d8e86")); image.set_pixel(i,6,Color("a4a398"))
	return image

func mini_ground(area: Rect2):
	for cy in range(int(floor(area.position.y/CHUNK)),int(ceil(area.end.y/CHUNK))):
		for cx in range(int(floor(area.position.x/CHUNK)),int(ceil(area.end.x/CHUNK))):
			draw_texture_rect(ground_chunk(cx,cy),Rect2(cx*CHUNK,cy*CHUNK,CHUNK,CHUNK),false)
	# Centre lines follow connected streets. Road edge transitions are part of cached ground tiles.
	if game.world.state.get("map_id","town")!="forest":
		for cy in range(int(floor(area.position.y/CHUNK)),int(ceil(area.end.y/CHUNK))):
			for cx in range(int(floor(area.position.x/CHUNK)),int(ceil(area.end.x/CHUNK))):
				for marking in _road_markings_chunk(cx,cy): draw_line(marking.a,marking.b,Color("c6c5ae"),3)
	# Static roadside debris is generated once per chunk and reused while the camera moves.
	var map_id=game.world.state.get("map_id","town")
	if detail_cache_seed!=game.world.map.seed or detail_cache_map_id!=map_id:
		detail_cache.clear(); detail_cache_seed=game.world.map.seed; detail_cache_map_id=map_id
	for gy in range(int(floor(area.position.y/512))-1,int(ceil(area.end.y/512))):
		for gx in range(int(floor(area.position.x/512))-1,int(ceil(area.end.x/512))):
			var key=Vector2i(gx,gy)
			if not detail_cache.has(key): detail_cache[key]=_chunk_details(gx,gy)
			for detail in detail_cache[key]:
				if area.grow(80).has_point(detail.pos): stamp(detail.path,detail.pos,detail.scale)
	# Visible street furniture is fixed to this region's geometry, not a base.
	if game.world.state.get("map_id","town")=="town":
		for detail in [["Objects/Bench_1_down.png",Vector2(650,420),2.0],["Objects/Trash-can_1.png",Vector2(685,420),2.0],["Objects/Stop-sign_Down_1.png",Vector2(1090,595),2.0],["Objects/Street-Light_3_Down.png",Vector2(1090,740),2.0],["Objects/Traffic-cone.png",Vector2(1050,610),2.0],["Objects/Trash-bag_2.png",Vector2(860,700),2.0],["Objects/Nature/Green/Bush_2_Green.png",Vector2(870,710),2.0]]:
			if area.grow(100).has_point(detail[1]): stamp(detail[0],detail[1],detail[2])
	for b in game.world.map.buildings_at(game.player_pos(),1200):
		var p=G.door(b).get_center()+Vector2(65,25)
		stamp("Objects/Barrel_rust_red_1.png",p,2.0)
		if hash(b.container)%3==0: stamp("Objects/Street-Light_3_Down.png",p+Vector2(30,15),2.0)

func _road_markings_chunk(cx: int,cy: int) -> Array:
	var key=Vector2i(cx,cy)
	if road_mark_cache.has(key): return road_mark_cache[key]
	var result=[]
	var chunk=Rect2(cx*CHUNK,cy*CHUNK,CHUNK,CHUNK).grow(80)
	for road in game.world.map.roads:
		var direction: Vector2=(road.b-road.a).normalized()
		var length: float=road.a.distance_to(road.b)
		for step in range(30,int(length),85):
			var p: Vector2=road.a+direction*step
			if not chunk.has_point(p): continue
			var intersection=false
			for other in game.world.map.roads:
				if absf(direction.dot((other.b-other.a).normalized()))<0.8 and Geometry2D.get_closest_point_to_segment(p,other.a,other.b).distance_to(p)<55:
					intersection=true; break
			if not intersection: result.append({"a":p,"b":p+direction*23})
	road_mark_cache[key]=result
	return result

func _chunk_details(gx: int,gy: int) -> Array:
	var result: Array=[]
	if game.world.state.get("map_id","town")!="town": return result
	for cy in range(6):
		for cx in range(6):
			var h=posmod(hash([game.world.map.seed,gx*6+cx,gy*6+cy,"detail"]),1000)
			var p=Vector2(gx*512+cx*80+posmod(h,41),gy*512+cy*80+posmod(h/7,41))
			if game.world.map.water_at(p) or not game.world.map._prop_clear(p,8,"town"): continue
			var distance=_road_info(p).distance
			if distance<54:
				if h<110: result.append({"path":"Objects/Trash-bag_1.png","pos":p,"scale":2.0})
				elif h<160: result.append({"path":"Objects/Traffic-cone.png","pos":p,"scale":2.0})
			elif h<220: result.append({"path":"Objects/Nature/Green/Grass_1_Green.png","pos":p,"scale":2.0})
			elif h<310: result.append({"path":"Objects/Nature/Green/Bush_1_Green.png","pos":p,"scale":2.0})
			elif h<370: result.append({"path":"Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Flowers_1_yellow.png","pos":p,"scale":2.0})
			elif h<420: result.append({"path":"Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Rocks/Rock_7.png","pos":p,"scale":2.0})
	return result

func stamp(path: String,pos: Vector2,scale_value: float=2.0,tint: Color=Color.WHITE):
	var texture=Art.asset(path); var size=texture.get_size()*scale_value
	draw_texture_rect(texture,Rect2((pos-Vector2(size.x/2,size.y-4)).round(),size),false,tint)

func atlas_patch(path: String,source: Rect2,destination: Rect2,tint: Color=Color.WHITE):
	draw_texture_rect_region(Art.texture(path),destination,source,tint)

func tile_patch(texture: Texture2D,source: Rect2,destination: Rect2,tile_size: Vector2=Vector2(32,32),tint: Color=Color.WHITE):
	for y in range(int(destination.position.y),int(destination.end.y),int(tile_size.y)):
		for x in range(int(destination.position.x),int(destination.end.x),int(tile_size.x)):
			var size=Vector2(minf(tile_size.x,destination.end.x-x),minf(tile_size.y,destination.end.y-y))
			draw_texture_rect_region(texture,Rect2(Vector2(x,y),size),Rect2(source.position,source.size*size/tile_size),tint)

func actor_frame(direction: Vector2,kind: String,walking: bool,step: int,armed: bool = false) -> int:
	return Pose.frame(direction,kind,walking,step,armed)

func actor(pos: Vector2,direction: Vector2,kind: String="player",down: bool=false,walking_override: bool=false):
	pos=pos.round()
	var facing="down"
	if absf(direction.x)>absf(direction.y): facing="side-left" if direction.x<0 else "side"
	elif direction.y<0: facing="up"
	var zed=kind in ["normal","fast","breaker"]
	var walking=game.moving if kind=="player" else walking_override
	var path: String
	var frames=6
	if zed:
		var species="Big" if kind=="breaker" else "Small"
		frames=8 if species=="Big" else 6
		var verb="walk" if species=="Small" and facing=="down" else "Walk"
		path="Enemies/Zombie_"+species+"/Zombie_"+species+"_"+{"down":"Down","up":"Up","side":"Side","side-left":"Side-left"}[facing]+"_"+verb+"-Sheet"+str(frames)+".png"
	else:
		var verb="run" if walking else "idle"
		path="Character/Main/"+("Run" if walking else "Idle")+"/Character_"+facing+"_"+verb+"-Sheet6.png"
	var tex=Art.asset(path); var source_size=Vector2(tex.get_width()/frames,tex.get_height())
	var step=int(animation_time*(10 if kind=="fast" else 7))%frames
	var size=Vector2(48,48) if kind!="breaker" else Vector2(62,62)
	if down:
		draw_set_transform(pos,PI/2); draw_texture_rect_region(tex,Rect2(-size/2,size),Rect2(Vector2.ZERO,source_size),Color(0.7,0.7,0.7)); draw_set_transform(Vector2.ZERO)
		label_at(pos+Vector2(-18,-22),"待救",Color("edbb71")); return
	var tint=Color(0.85,1.0,0.85) if kind=="npc" else Color.WHITE
	draw_texture_rect_region(tex,Rect2(pos-Vector2(size.x/2,size.y-6),size),Rect2(Vector2(step*source_size.x,0),source_size),tint)
	var resting=kind=="player" and game.world.state.systems_v5.resting
	if resting and game.world.state.systems_v5.sleeping: label_at(pos+Vector2(10,-45),"Z",Color("b5d7db"),12)
	if kind=="player" and game.world.state.weapon!="knife" and not resting and not game.is_searching():
		var origin=Pose.grip(pos); var gun=art.icon(game.world.state.weapon); var length=Pose.gun_length(game.world.state.weapon)
		draw_set_transform(origin,direction.angle(),Vector2(1,-1 if direction.x<0 else 1))
		var height=clampf(length*gun.get_height()/float(gun.get_width()),4,11)
		draw_texture_rect(gun,Rect2(2,-height/2,length,height),false)
		draw_set_transform(Vector2.ZERO)

func draw_car(car: Dictionary):
	var names=["Objects/Vehicles/Normal/Car_1/Car_1_Gray.png","Objects/Vehicles/Overgrown/Car_1_Overgrown/Green/Car_1_Overgrown_Green_Blue.png","Objects/Vehicles/Normal/Car_3_Van/Car_3_Blue_Van.png","Objects/Vehicles/Normal/Car_6_Scrap/Car_6_Green_Scrap.png"]
	stamp(names[posmod(int(car.variant),names.size())],car.pos,2.0)

func tree_frame(tree: Dictionary) -> Dictionary:
	var texture: Texture2D=art.mini_trees[posmod(int(tree.variant),art.mini_trees.size())]
	var size=texture.get_size()*2
	return {"texture":texture,"region":Rect2(Vector2.ZERO,texture.get_size()),"rect":Rect2(tree.pos-Vector2(size.x/2,size.y-5),size)}

func draw_tree(tree: Dictionary):
	var info=tree_frame(tree); var rect: Rect2=info.rect
	var alpha=0.4 if rect.has_point(game.player_pos()) and game.player_pos().y<tree.pos.y else 1.0
	draw_texture_rect_region(info.texture,rect,info.region,Color(1,1,1,alpha))

func draw_plant(plant: Dictionary):
	var ready=Forage.ready(game.world.state.harvests,plant.id,int(game.world.state.minute))
	if plant.kind=="apple": draw_tree({"pos":plant.pos,"variant":1})
	else: stamp("Objects/Nature/Green/Bush_2_Green.png",plant.pos,1.5,Color.WHITE if ready else Color(0.65,0.65,0.65))
	if ready:
		draw_texture_rect(art.icon(plant.kind),Rect2(plant.pos-Vector2(7,21),Vector2(14,14)),false)

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
			atlas_patch(Art.SHELTER+"Shelter_Furniture_16x16.png",Rect2(9*16,12*16,16,64),Rect2(f.x-20,f.y-47,40,52))
	for c in w.state.get("resource_cycle",{}).get("collectors",[]):
		if c.map_id==w.state.map_id and game.can_see_actor(Vector2(c.x,c.y)):
			draw_texture_rect(art.icon("rain_collector"),Rect2(c.x-12,c.y-24,24,24),false,Color("7daeb2"))
			label_at(Vector2(c.x-25,c.y-30),"集雨 %.1f/8"%c.water,Color("b5dbe0"))
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
	for car in cars:
		if car.pos.y > player.y: draw_car(car)
	for tree in trees:
		if tree.pos.y > player.y: draw_tree(tree)
	for plant in plants:
		if plant.pos.y > player.y: draw_plant(plant)
	if not game.is_searching():
		var reticle = player+game.aim*lerpf(85,140,game.focus)
		draw_arc(reticle,lerpf(15,4,game.focus)+float(game.recoil_heat.get(w.player_weapon(w.state.weapon),0.0))*60.0,0,TAU,16,Color(0.9,0.85,0.6,0.7),1)
	for flash in flashes: draw_line(flash.a,flash.b,Color(1,0.83,0.46,flash.life*9),2)
	if not game.placement.is_empty():
		var p = game.placement_position(); draw_rect(Rect2(p-Vector2(16,16),Vector2(32,32)),Color(0.5,0.85,0.6,0.65) if game.valid_placement(p) else Color(0.9,0.35,0.25,0.65))
	for exit_point in w.exits():
		var p=Vector2(exit_point.x,exit_point.y)
		if area.has_point(p):
			stamp("Objects/Stop-sign_Down_1.png",p+Vector2(30,-10),2.0)
			label_at(p+Vector2(-55,-35),exit_point.name,Color("e8d49c"),13)
	for shelter in w.state.get("shelters",[]):
		if shelter.get("map_id","")!=w.state.get("map_id","town"): continue
		var p=Vector2(shelter.get("x",0),shelter.get("y",0))
		if area.has_point(p): label_at(p+Vector2(-25,-57),"⌂ "+str(shelter.get("name","落脚点")),Color("a9ccad"),12)
	var target = game.nearest_target()
	if not target.is_empty():
		draw_arc(target.pos,24,0,TAU,24,Color("dfc88e"),1); label_at(target.pos+Vector2(-25,-30),target.name,Color("f5deb0"),12)
	if town:
		for win in Tactics.windows(w,player,radius):
			block(win.rect,Color("8c754b") if win.state.board_hp>0 else (Color("364748") if win.state.broken else Color("8bb9be")))
	weather_overlay(area,buildings)

func building(b: Dictionary):
	var f=G.frame(b); var inside=G.interior(b).has_point(game.player_pos())
	var wall=Art.asset("Tiles/Buildings/Buildings_"+("white" if b.kind=="clinic" else "beige")+"_TileSet.png")
	var ground=Art.texture(Art.OFFICE+"Office_Terrain_16x16.png")
	# The same footprint is used in collision; roof hiding never changes walls.
	tile_patch(ground,Rect2(176,16,16,16),f,Vector2(32,32),Color(0.8,0.78,0.75))
	var door=G.door(b); var door_state=Tactics.door_state(game.world,b.container+"0")
	var blocked=Tactics.door_blocked(game.world,b)
	var facade=Rect2(f.position.x,f.end.y-40,f.size.x,40)
	if not inside:
		var roof=Art.asset("Tiles/Roof_TileSet.png")
		tile_patch(roof,Rect2(16,48,16,8),Rect2(f.position.x,f.position.y-20,f.size.x,f.size.y-20),Vector2(32,16))
		# Eaves and facade use the pack's weathered masonry and glazed windows.
		draw_line(Vector2(f.position.x,f.end.y-40),Vector2(f.end.x,f.end.y-40),Color("4d414d"),6)
		tile_patch(wall,Rect2(16,48,16,16),facade,Vector2(32,32))
		for x in [f.position.x+24,f.end.x-60]:
			draw_texture_rect_region(wall,Rect2(x,f.end.y-38,32,24),Rect2(9*16,16,16,12))
		stamp("Objects/Buildings/Air-vent_2_rusty.png",f.position+Vector2(38,35),2.0)
		if hash(b.container)%2==0: stamp("Objects/Buildings/Roof-hole_1_Gray.png",f.position+Vector2(f.size.x*0.65,f.size.y*0.4),2.0)
		draw_line(Vector2(f.position.x,f.position.y+f.size.y*0.35),Vector2(f.end.x,f.position.y+f.size.y*0.35),Color("4b4657"),3)
		if b.kind in ["clinic","police"]: stamp("Objects/Buildings/Antenna_1.png",f.position+Vector2(f.size.x-25,20),2.0)
	else:
		for rect in G.rectangles(b): tile_patch(wall,Rect2(16,48,16,16),rect,Vector2(32,32),Color(1,1,1,0.7))
		var p=G.loot_point(b)
		atlas_patch(Art.OFFICE+"Office_Furniture_16x16.png",Rect2(0,0,32,32),Rect2(p-Vector2(20,32),Vector2(40,40)))
		if b.kind in ["house","clinic"]:
			var bed=G.bed_point(b)
			atlas_patch(Art.SHELTER+"Shelter_Furniture_16x16.png",Rect2(22*16,0,32,48),Rect2(bed-Vector2(20,40),Vector2(40,60)))
			label_at(bed+Vector2(-14,-45),"床位",Color("c7d4c4"),10)
		atlas_patch(Art.SHELTER+"Shelter_Furniture_16x16.png",Rect2(7*16,0,32,48),Rect2(f.end.x-75,f.position.y+18,40,55))
	if blocked:
		stamp("Objects/Buildings/Door_5_Rusty_Metal.png",door.get_center()+Vector2(0,6),1.8)
		if door_state.board_hp>0: draw_line(door.position-Vector2(0,9),door.end+Vector2(0,9),Color("c4a366"),4)
	else:
		stamp("Objects/Buildings/Door_2_Ajar_Beige.png",door.get_center()+Vector2(-15,6),1.8)
	label_at(Vector2(b.rect.position.x,b.rect.end.y+15),b.name,Color("ded6b9"),12)

func camp():
	# Legacy display entry point retained for old tests; exploration uses world buildings.
	pass

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
