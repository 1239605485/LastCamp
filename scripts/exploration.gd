extends RefCounted

const G = preload("res://scripts/building_geometry.gd")
const REGION_NAMES = {"town":"榆树镇", "forest":"松溪林区"}
const TRAVEL_MINUTES = 15.0
const LOCAL_KEYS = ["harvests","searched","explored","tactics_v5"]

static func map_id(w) -> String:
	return str(w.state.get("map_id","town"))

static func decorate_map(m, id: String):
	if m.get_meta("exploration_region","")==id: return
	if id=="forest":
		var cabins: Array=[]
		for building in m.buildings:
			if building.kind=="house" and cabins.size()<4:
				building.name="林间护林屋" if cabins.is_empty() else "林间旧屋%d"%(cabins.size()+1)
				cabins.append(building)
		m.buildings=cabins
		for sector in m.sectors: sector.name="松溪林区 · "+str(sector.id).replace("region_","")
	for b in m.buildings:
		if not str(b.container).begins_with(id+":"): b.container = id+":"+str(b.container)
	for car in m._cars:
		if not str(car.id).begins_with(id+":"): car.id = id+":"+str(car.id)
	m.set_meta("exploration_region",id)

static func exits(w) -> Array:
	var target = "forest" if map_id(w)=="town" else "town"
	if Vector2(w.state.px,w.state.py).distance_to(Vector2(95,490))<230 and w.state.known_regions.get(target,"rumor")=="rumor":
		w.state.known_regions[target]="entrance"
		w.note("发现路牌与地区入口："+REGION_NAMES[target]+"。入口已标记，尚未进入。")
	return [{"id":map_id(w)+":west-road","target_id":target,"x":95.0,"y":490.0,"name":"前往"+REGION_NAMES[target]}]

static func beds(w) -> Array:
	return w.regions.get(map_id(w),{}).get("beds",[])

static func near_bed(w) -> Dictionary:
	var pos = Vector2(w.state.px,w.state.py)
	for bed in beds(w):
		if bed.hp>0 and pos.distance_to(Vector2(bed.x,bed.y))<=90: return bed
	return {}

static func make_beds(w) -> Array:
	var result: Array = []
	for b in w.map.buildings:
		if b.kind not in ["house","clinic"]: continue
		var p = G.bed_point(b)
		result.append({"id":str(b.container)+":bed","map_id":map_id(w),"building_id":b.container,"x":p.x,"y":p.y,"hp":100.0})
	return result

static func stamp_entities(w):
	for group in [w.npcs,w.furniture,w.enemies,w.graves,w.defenses]:
		for entity in group: entity["map_id"] = map_id(w)

static func commit_region(w):
	var id = map_id(w)
	stamp_entities(w)
	var local = {}
	for key in LOCAL_KEYS: local[key] = w.state.get(key,{} if key!="explored" else []).duplicate(true)
	w.regions[id] = {"seed":w.map.seed,"beds":beds(w).duplicate(true),"npcs":w.npcs.duplicate(true),"furniture":w.furniture.duplicate(true),"enemies":w.enemies.duplicate(true),"graves":w.graves.duplicate(true),"defenses":w.defenses.duplicate(true),"doors":w.doors.duplicate(true),"local":local,"last_minute":w.state.minute}

static func activate_region(w,id: String):
	var region: Dictionary = w.regions[id]
	w.state.map_id = id
	w.state.zone = "town"
	w.map = w.Map.new(int(region.seed),4)
	decorate_map(w.map,id)
	w.state.map_seed = w.map.seed
	for key in LOCAL_KEYS: w.state[key] = region.local.get(key,{} if key!="explored" else []).duplicate(true)
	w.npcs = region.npcs.duplicate(true); w.furniture = region.furniture.duplicate(true)
	w.enemies = region.enemies.duplicate(true); w.graves = region.graves.duplicate(true)
	w.defenses = region.defenses.duplicate(true); w.doors = region.doors.duplicate(true)
	w.ensure_world_features()

static func chase_active(w) -> bool:
	var pos = Vector2(w.state.px,w.state.py)
	return w.enemies.any(func(e): return e.hp>0 and Vector2(e.x,e.y).distance_to(pos)<600 and (float(e.get("alert",0))>0 or e.get("ai_state","") in ["chase","pursue","search"]))

static func travel(w,target: String) -> bool:
	if not REGION_NAMES.has(target) or target==map_id(w): return false
	var connection = {}
	for e in exits(w):
		if e.target_id==target and Vector2(e.x,e.y).distance_to(Vector2(w.state.px,w.state.py))<=100: connection=e; break
	if connection.is_empty(): w.note("请先走到地区出口。"); return false
	if chase_active(w): w.note("仍有僵尸追击，先甩脱追兵再旅行。"); return false
	var before = w.snapshot()
	var followers: Array = []
	for n in w.npcs:
		if n.get("follow",false) and n.status!="down": followers.append(n.duplicate(true))
	w.npcs = w.npcs.filter(func(n): return not (n.get("follow",false) and n.status!="down"))
	var carried: Array = []
	for f in w.furniture:
		if f.packed and w.items.has(f.id) and w.items[f.id].owner=="player": carried.append(f.duplicate(true))
	w.furniture = w.furniture.filter(func(f):return not (f.packed and w.items.has(f.id) and w.items[f.id].owner=="player"))
	commit_region(w)
	if not w.regions.has(target): w.create_region(target)
	activate_region(w,target)
	var entry = safe_point(w,Vector2(150,490))
	if entry==Vector2.INF:
		w.restore_snapshot(before); w.note("目标入口暂不可达，旅行已取消。"); return false
	w.state.px = entry.x; w.state.py = entry.y
	for n in followers:
		n.map_id=target; n.zone="town"; n.x=entry.x+28; n.y=entry.y+24; w.npcs.append(n)
	for f in carried: f.map_id=target; w.furniture.append(f)
	w.state.known_regions[target]="entered"
	w.advance(TRAVEL_MINUTES)
	w.note("抵达"+REGION_NAMES[target]+"，旅途经过15分钟。原地区物资与门窗已保留。")
	commit_region(w)
	if not w.save_game():
		w.restore_snapshot(before)
		w.note("旅行保存失败，已恢复出发前的完整状态。")
		return false
	return true

static func safe_point(w, preferred: Vector2,threat_radius: float=180.0) -> Vector2:
	for ring in range(10):
		for step in range(16):
			var p = preferred+Vector2(ring*24,0).rotated(step*TAU/16)
			if p.x<45 or p.y<30 or p.x>w.map.size.x-45 or p.y>w.map.size.y-45 or w.map.water_at(p): continue
			if w.enemies.any(func(e):return e.hp>0 and Vector2(e.x,e.y).distance_to(p)<threat_radius): continue
			var solid = false
			for b in w.map.buildings_at(p,500):
				if G.solid_at(b,p,7): solid=true; break
			if solid: continue
			for f in w.furniture:
				if not f.packed and f.hp>0 and Vector2(f.x,f.y).distance_to(p)<30: solid=true; break
			if solid: continue
			for car in w.map.cars_at(p,150,"town"):
				if car.body.grow(8).has_point(p): solid=true; break
			if solid: continue
			for tree in w.map.trees_at(p,100,"town"):
				if tree.trunk.grow(8).has_point(p): solid=true; break
			if not solid: return p
	return Vector2.INF

static func register_shelter(w,bed_id: String,name: String="") -> bool:
	var chosen = {}
	for bed in beds(w):
		if bed.id==bed_id and bed.hp>0: chosen=bed; break
	if chosen.is_empty() or Vector2(chosen.x,chosen.y).distance_to(Vector2(w.state.px,w.state.py))>90: return false
	for building in w.map.buildings:
		if building.container==chosen.building_id and not G.interior(building).has_point(Vector2(w.state.px,w.state.py)): return false
	if chase_active(w): w.note("追击中不能登记住所。"); return false
	for shelter in w.state.shelters:
		if shelter.bed_id==bed_id: return true
	var shelter = {"id":w.uid("shelter_"),"bed_id":bed_id,"map_id":map_id(w),"name":name if not name.strip_edges().is_empty() else "落脚点%d"%(w.state.shelters.size()+1),"x":chosen.x,"y":chosen.y}
	w.state.shelters.append(shelter)
	if w.state.preferred_shelter_id.is_empty(): w.state.preferred_shelter_id=shelter.id
	w.note("已登记"+shelter.name+"，仅用于地图、会合和恢复；库存仍留在原处。")
	return true

static func recover(w):
	var ordered = w.state.shelters.duplicate(true)
	ordered.sort_custom(func(a,b):return a.id==w.state.preferred_shelter_id and b.id!=w.state.preferred_shelter_id)
	for shelter in ordered:
		if not w.regions.has(shelter.map_id): continue
		var region = w.regions[shelter.map_id]
		if not region.beds.any(func(b):return b.id==shelter.bed_id and b.hp>0): continue
		var previous = map_id(w)
		if previous!=shelter.map_id: activate_region(w,shelter.map_id)
		var pos = safe_point(w,Vector2(shelter.x,shelter.y))
		if pos!=Vector2.INF and pos.distance_to(Vector2(shelter.x,shelter.y))<60:
			w.state.px=pos.x; w.state.py=pos.y; return
		if previous!=map_id(w): activate_region(w,previous)
	# A recovery fallback is a position only, never an owned or invulnerable base.
	var fallback = safe_point(w,Vector2(610,450))
	if fallback==Vector2.INF:
		for y in range(180,int(w.map.size.y)-180,256):
			for x in range(180,int(w.map.size.x)-180,256):
				fallback=safe_point(w,Vector2(x,y))
				if fallback!=Vector2.INF: break
			if fallback!=Vector2.INF: break
	if fallback==Vector2.INF:
		# A fully obstructed map cannot provide a valid recovery transaction.
		w.note("没有可用恢复位置，遗物已保存，请继续读取备份排查世界状态。")
		return
	w.state.px=fallback.x; w.state.py=fallback.y
	w.note("登记点不可用，已在当前地区的备用位置恢复。遗物仍保留。")
