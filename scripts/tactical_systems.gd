extends RefCounted
const G = preload("res://scripts/building_geometry.gd")
static var window_cache: Dictionary = {}

static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func valid_state(state: Dictionary) -> bool:
	if not state.has("tactics_v5"): return true
	var s = state.tactics_v5
	if not s is Dictionary: return false
	for key in ["doors","windows"]:
		if not s.has(key): continue
		if not s[key] is Dictionary: return false
		for id in s[key]:
			var barrier = s[key][id]
			if not id is String or id.is_empty() or not barrier is Dictionary: return false
			for field in ["hp","board_hp"]:
				if barrier.has(field) and (not number(barrier[field]) or barrier[field] < 0 or barrier[field] > 10000): return false
			if barrier.has("broken") and not barrier.broken is bool: return false
	if s.has("traps"):
		if not s.traps is Array or s.traps.size() > 200: return false
		var ids: Dictionary = {}
		for trap in s.traps:
			if not trap is Dictionary: return false
			for field in ["id","kind","zone"]:
				if not trap.get(field) is String: return false
			if trap.id.is_empty() or ids.has(trap.id) or trap.kind not in ["spike","alarm"] or trap.zone not in ["town","camp"]: return false
			ids[trap.id] = true
			for field in ["x","y","hp"]:
				if not number(trap.get(field)): return false
			if trap.hp < 0 or trap.hp > 10000 or not trap.get("armed") is bool: return false
			if trap.has("triggered_minute") and not number(trap.triggered_minute): return false
	return true

static func ensure(w):
	if not w.state.get("tactics_v5") is Dictionary: w.state["tactics_v5"] = {}
	var s: Dictionary = w.state.tactics_v5
	if w.has_meta("tactics_validated") and is_same(w.get_meta("tactics_validated"),s) and s.get("doors") is Dictionary and s.get("windows") is Dictionary and s.get("traps") is Array: return
	for key in ["doors","windows"]:
		if not s.get(key) is Dictionary: s[key] = {}
		for id in s[key].keys():
			if not id is String or id.is_empty(): s[key].erase(id); continue
			if not s[key][id] is Dictionary: s[key][id] = {}
			var barrier: Dictionary = s[key][id]
			for field in ["hp","board_hp"]:
				if not number(barrier.get(field)): barrier[field] = (100.0 if key == "doors" else 30.0) if field == "hp" else 0.0
				barrier[field] = clampf(barrier[field],0,10000)
			if not barrier.get("broken") is bool: barrier["broken"] = barrier.hp <= 0
	if not s.get("traps") is Array: s["traps"] = []
	var good: Array = []; var ids: Dictionary = {}
	for original in s.traps:
		if not original is Dictionary or original.get("kind","") not in ["spike","alarm"] or not number(original.get("x")) or not number(original.get("y")):
			if not s.get("rejected_traps") is Array: s["rejected_traps"] = []
			s.rejected_traps.append(original); continue
		var trap: Dictionary = original
		if not trap.get("id") is String or trap.id.is_empty(): trap["id"] = w.uid("trap_repaired_")
		if ids.has(trap.id):
			if not s.get("rejected_traps") is Array: s["rejected_traps"] = []
			s.rejected_traps.append(trap); continue
		ids[trap.id] = true
		if trap.get("zone","") not in ["town","camp"]: trap["zone"] = w.state.get("zone","camp")
		if not number(trap.get("hp")): trap["hp"] = 40.0
		trap.hp = clampf(trap.hp,0,10000)
		if not trap.get("armed") is bool: trap["armed"] = false
		if trap.has("triggered_minute") and not number(trap.triggered_minute): trap.erase("triggered_minute")
		good.append(trap)
	s.traps = good
	w.set_meta("tactics_validated",s)

static func door_state(w, id: String) -> Dictionary:
	ensure(w)
	if not w.state.tactics_v5.doors.has(id): w.state.tactics_v5.doors[id] = {"hp":100.0,"board_hp":0.0,"broken":false}
	return w.state.tactics_v5.doors[id]

static func door_blocked(w, b: Dictionary) -> bool:
	var id: String = b.container + "0"; var d = door_state(w,id)
	return d.board_hp > 0 or (not d.broken and not w.doors.get(id,false))

static func damage_door(w, id: String, damage: float) -> bool:
	var d = door_state(w,id)
	if damage <= 0: return d.broken
	var absorbed = minf(d.board_hp,damage); d.board_hp -= absorbed; damage -= absorbed
	if damage > 0 and not d.broken: d.hp = maxf(0,d.hp - damage)
	if d.hp <= 0: d.broken = true; w.doors[id] = true
	return d.broken and d.board_hp <= 0

static func damage_window(w, id: String, damage: float) -> bool:
	ensure(w)
	if not w.state.tactics_v5.windows.has(id): return false
	var win: Dictionary = w.state.tactics_v5.windows[id]
	var absorbed = minf(win.board_hp,maxf(0,damage)); win.board_hp -= absorbed; damage -= absorbed
	if damage > 0: win.hp = maxf(0,win.hp - damage)
	if win.hp <= 0:
		if not win.broken: win["glass_cleared"] = false
		win.broken = true
	return win.broken and win.board_hp <= 0
# Front facade window: both landing points must lie on native walkable floor.
static func windows(w, center: Vector2, radius: float = 180) -> Array:
	ensure(w); var out: Array = []
	for b in w.map.buildings_at(center,radius + 300):
		var key=hash([b.rect,b.art,b.container])
		if not window_cache.has(key):
			if window_cache.size()>400: window_cache.clear()
			window_cache[key]={}
			var f:Rect2=G.frame(b)
			for ratio in [0.3,0.7,0.15,0.85,0.4,0.6]:
				var p=Vector2(lerpf(f.position.x,f.end.x,ratio),G.door(b).get_center().y)
				var inside=p-Vector2(0,18); var outside=p+Vector2(0,18)
				if p.distance_to(G.door(b).get_center())<42 or G.solid_at(b,inside,6) or G.solid_at(b,outside,6): continue
				window_cache[key]={"id":b.container+"_window","pos":p,"inside":inside,"outside":outside,"rect":Rect2(p-Vector2(14,4),Vector2(28,8))}; break
		if window_cache[key].is_empty(): continue
		var data:Dictionary=window_cache[key].duplicate()
		if not w.state.tactics_v5.windows.has(data.id): w.state.tactics_v5.windows[data.id]={"hp":30.0,"board_hp":0.0,"broken":false}
		data.state=w.state.tactics_v5.windows[data.id]; out.append(data)
	return out

static func solids(game) -> Array:
	var out: Array = []
	if game.world.state.zone != "town": return out
	for win in windows(game.world,game.player_pos(),2000):
		if win.state.board_hp > 0: out.append(win.rect)
	return out

static func add_action(out: Array, label: String, request: Dictionary, duration: float):
	out.append({"label":label,"request":request,"duration":duration})

static func opening_threat(w,p: Vector2) -> bool:
	return w.enemies.any(func(e):return e.zone==w.state.zone and e.hp>0 and Vector2(e.x,e.y).distance_to(p)<80)

static func boarding_action(out: Array,w,p: Vector2,label: String,request: Dictionary):
	if opening_threat(w,p):
		out.append({"label":"敌人贴近，暂时无法加固","request":request,"duration":2.4,"enabled":false})
	else: add_action(out,label,request,2.4)

static func actions(game) -> Array:
	var w = game.world; ensure(w); var out: Array = []; var p: Vector2 = game.player_pos()
	if w.state.zone == "town":
		for b in w.map.buildings_at(p,200):
			if p.distance_to(G.door(b).get_center()) > 64: continue
			var id: String = b.container + "0"; var d = door_state(w,id)
			if d.board_hp <= 0:
				if not d.broken: add_action(out,"开关房门",{"kind":"tac_door_toggle","id":id},0.6)
				boarding_action(out,w,G.door(b).get_center(),"木板封门（木材2）",{"kind":"tac_door_board","id":id})
			else: add_action(out,"拆除门上木板",{"kind":"tac_door_unboard","id":id},2.0)
			if not d.broken or d.board_hp > 0: add_action(out,"破坏房门",{"kind":"tac_door_break","id":id},1.4)
		for win in windows(w,p):
			if p.distance_to(win.pos) > 62: continue
			if win.state.board_hp > 0:
				add_action(out,"拆除窗上木板",{"kind":"tac_window_unboard","id":win.id},2.0)
				add_action(out,"破坏封窗",{"kind":"tac_window_break","id":win.id},1.4)
			else:
				boarding_action(out,w,win.pos,"木板封窗（木材2）",{"kind":"tac_window_board","id":win.id})
				if not win.state.broken: add_action(out,"打破玻璃窗",{"kind":"tac_window_break","id":win.id},1.0)
				else:
					if not win.state.get("glass_cleared",false): add_action(out,"清理残留玻璃",{"kind":"tac_window_clear","id":win.id},1.8)
					add_action(out,"翻越窗户" if win.state.get("glass_cleared",false) else "翻越碎窗（可能割伤）",{"kind":"tac_window_climb","id":win.id},1.5)
	for f in w.furniture:
		if f.zone == w.state.zone and not f.packed and f.hp > 0 and p.distance_to(Vector2(f.x,f.y)) < 65:
			add_action(out,"推柜子",{"kind":"tac_push","id":f.id},1.2)
			add_action(out,"拉柜子",{"kind":"tac_pull","id":f.id},1.5)
	for n in w.npcs:
		if n.zone != w.state.zone or n.status in ["down","waiting"] or p.distance_to(Vector2(n.x,n.y)) > 110: continue
		for order in ["follow","guard","retreat","holdfire","patrol"]:
			add_action(out,n.name + "：" + {"follow":"跟随","guard":"守住此处","retreat":"撤到身边","holdfire":"停火/开火","patrol":"附近巡逻"}[order],{"kind":"tac_order","id":n.id,"order":order},0.4)
	add_action(out,"布置尖刺陷阱（木材2）",{"kind":"tac_trap","trap":"spike"},2.4)
	add_action(out,"布置响罐警报（零件1）",{"kind":"tac_trap","trap":"alarm"},2.0)
	for trap in w.state.tactics_v5.traps:
		if trap.zone==w.state.zone and not trap.armed and Vector2(trap.x,trap.y).distance_to(p)<65: add_action(out,"清理失效陷阱",{"kind":"tac_clear_trap","id":trap.id},1.2)
	return out

static func spend(w, cost: Dictionary) -> bool:
	for material in cost:
		var available: int = w.count_item(material)
		if available < cost[material]: return false
	for material in cost:
		w.consume(material,cost[material])
	return true

static func complete(game, request: Dictionary) -> bool:
	var w = game.world; ensure(w); var kind: String = request.get("kind",""); var id: String = request.get("id",""); var p: Vector2 = game.player_pos()
	# Revalidate context after the timed interaction, including range and current state.
	var allowed = false
	for a in actions(game):
		if not a.get("enabled",true): continue
		var matches = true
		for key in a.request:
			if request.get(key) != a.request[key]: matches = false; break
		if matches: allowed = true; break
	if not allowed: return false
	if kind.begins_with("tac_door_"):
		var d = door_state(w,id)
		match kind:
			"tac_door_toggle": w.doors[id] = not w.doors.get(id,false)
			"tac_door_board":
				if not spend(w,{"wood":2}): return false
				d.board_hp = 120.0; w.doors[id] = false
			"tac_door_unboard": d.board_hp = 0.0
			"tac_door_break":
				damage_door(w,id,45); w.state.stamina = maxf(0,w.state.stamina-7)
				game.emit_noise(p,320)
	elif kind.begins_with("tac_window_"):
		for win in windows(w,p):
			if win.id != id: continue
			match kind:
				"tac_window_board":
					if not spend(w,{"wood":2}): return false
					win.state.board_hp = 100.0
				"tac_window_unboard": win.state.board_hp = 0.0
				"tac_window_break": damage_window(w,id,40); noise(w,win.pos,w.state.zone)
				"tac_window_clear": win.state["glass_cleared"] = true
				"tac_window_climb":
					var approach:Vector2=win.outside if p.y>=win.pos.y else win.inside
					if p.distance_to(approach)>26: return false
					var target: Vector2 = win.inside if p.y >= win.pos.y else win.outside
					if game.blocked(target) or p.distance_to(target) > 78 or w.state.stamina < 6: return false
					game.set_pos(target); w.state.stamina -= 6
					if not win.state.get("glass_cleared",false): w.state.hp=maxf(0,w.state.hp-5); w.state.bleeding=true
			return true
	elif kind in ["tac_push","tac_pull"]: return move_furniture(game,id,kind == "tac_pull")
	elif kind == "tac_order":
		for n in w.npcs:
			if n.id != id: continue
			if request.order == "holdfire": n["hold_fire"] = not n.get("hold_fire",false)
			else:
				n["order"] = request.order; n.follow = request.order in ["follow","retreat"]
				if n.follow:
					for other in w.npcs:
						if other.id!=n.id: other.follow=false
				n["anchor_x"] = n.x; n["anchor_y"] = n.y
			return true
	elif kind == "tac_clear_trap":
		w.state.tactics_v5.traps=w.state.tactics_v5.traps.filter(func(trap):return trap.id!=id)
	elif kind == "tac_trap":
		var target: Vector2 = (p + game.aim.normalized()*48).snapped(Vector2(16,16))
		if game.blocked(target) or not game.valid_placement(target) or w.state.tactics_v5.traps.size() >= 80: return false
		for trap in w.state.tactics_v5.traps:
			if trap.zone == w.state.zone and Vector2(trap.x,trap.y).distance_to(target) < 34: return false
		if not spend(w,{"wood":2} if request.trap == "spike" else {"parts":1}): return false
		w.state.tactics_v5.traps.append({"id":w.uid("trap_"),"kind":request.trap,"zone":w.state.zone,"x":target.x,"y":target.y,"hp":40.0,"armed":true})
	return true

static func move_furniture(game, id: String, pull: bool) -> bool:
	var w = game.world
	if w.state.stamina < 8: return false
	for f in w.furniture:
		if f.id != id or f.packed or f.hp <= 0 or f.zone != w.state.zone: continue
		var start = Vector2(f.x,f.y); var direction = (start-game.player_pos()).normalized()
		if start.distance_to(game.player_pos()) > 65 or direction.length() < 0.5: return false
		direction = Vector2(signf(direction.x),0) if absf(direction.x) > absf(direction.y) else Vector2(0,signf(direction.y))
		if pull: direction = -direction
		var finish = start + direction*24
		var player_target: Vector2 = game.player_pos() + direction*24 if pull else game.player_pos()
		if finish.distance_to(player_target) < 26 or game.blocked(player_target): return false
		if pull and game.move_with_collision(game.player_pos(),direction*24).distance_to(player_target) > 1: return false
		# Exclude only this same instance while sweeping its whole footprint.
		f.packed = true; game.solid_cache_key = -1
		var valid = true
		for step in range(1,7):
			var at = start + direction*4*step
			for offset in [Vector2(-16,-16),Vector2(16,-16),Vector2(-16,12),Vector2(16,12),Vector2.ZERO]:
				if game.blocked(at+offset): valid = false; break
			if not valid: break
		f.packed = false; game.solid_cache_key = -1
		if not valid: return false
		f.x = finish.x; f.y = finish.y; w.state.stamina -= 8
		if pull: game.set_pos(player_target)
		return true
	return false

static func noise(w, p: Vector2, zone: String, radius: float = 360):
	for e in w.enemies:
		if e.zone == zone and e.hp > 0 and Vector2(e.x,e.y).distance_to(p) < radius:
			e.alert = maxf(e.get("alert",0),12); e["tx"] = p.x; e["ty"] = p.y; e["mode"]="investigate"
	w.note("响声惊动了附近的感染者。")

static func trigger_contacts(w, zone: String):
	ensure(w)
	for trap in w.state.tactics_v5.traps:
		if trap.zone != zone or not trap.armed or trap.hp <= 0: continue
		for e in w.enemies:
			if e.zone != zone or e.hp <= 0 or Vector2(e.x,e.y).distance_to(Vector2(trap.x,trap.y)) > 25: continue
			trap.armed = false; trap["triggered_minute"] = w.state.minute
			if trap.kind == "spike": e.hp -= 55; e["slow_until"] = w.state.minute + 4; w.note("尖刺陷阱命中感染者。")
			else: noise(w,Vector2(trap.x,trap.y),zone); w.note("响罐警报被触发！")
			break

static func tick(game, _delta: float) -> bool:
	var before=game.world.state.tactics_v5.traps.filter(func(t):return t.kind=="alarm" and t.armed).size()
	trigger_contacts(game.world,game.world.state.zone)
	return game.world.state.tactics_v5.traps.filter(func(t):return t.kind=="alarm" and t.armed).size()<before

static func advance_offscreen(w, _minutes: float):
	# Inactive regions are snapshots, not a second simulation of active traps.
	pass





