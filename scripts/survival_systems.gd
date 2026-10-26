extends RefCounted

const R = preload("res://scripts/rules.gd")
const FRESH_MINUTES = {"berry":1440.0,"apple":4320.0,"tomato":2880.0,"squash":5760.0}
const WEATHER_NAMES = {"clear":"晴","cloudy":"多云","rain":"雨","heavy_rain":"暴雨"}
const RECIPES = [
	{"id":"ammo","label":"2罐头换18发9mm","cost":{"food":2},"reward":{"ammo9":18}},
	{"id":"battery","label":"3零件换1电池","cost":{"parts":3},"reward":{"battery":1}},
	{"id":"fuel","label":"5木材换1燃油","cost":{"wood":5},"reward":{"fuel":1}}
]

static func ensure(w):
	if not w.state.get("systems_v5",null) is Dictionary: w.state["systems_v5"] = {}
	var s: Dictionary = w.state.systems_v5
	if not s.has("sleeping"): s["sleeping"]=false
	var defaults = {"version":1,"fatigue":0.0,"resting":false,"battery":100.0,"flashlight_on":false,"generator_on":false,"fuel_minutes":0.0,"weather":"clear","weather_block":-1,"trader_day":-1,"trader_stock":{},"events":[],"last_event":-1,"last_announcement":-1,"migrated_food":false}
	for key in defaults:
		if not s.has(key): s[key] = defaults[key]
	for key in ["fatigue","battery","fuel_minutes"]:
		if not (s[key] is float or s[key] is int) or not is_finite(float(s[key])): s[key] = 0.0
	s.fatigue = clampf(float(s.fatigue),0,100); s.battery = clampf(float(s.battery),0,100)
	s.fuel_minutes = maxf(0,float(s.fuel_minutes))
	for key in ["resting","sleeping","flashlight_on","generator_on"]:
		if not s[key] is bool: s[key] = false
	for key in ["weather_block","trader_day","last_event","last_announcement"]:
		if not (s[key] is float or s[key] is int): s[key] = -1
	if not WEATHER_NAMES.has(s.weather): s.weather = "clear"
	if not s.events is Array: s.events = []
	s.events = s.events.filter(func(e): return _valid_event(e))
	if not s.trader_stock is Dictionary: s.trader_stock = {}
	if not s.migrated_food:
		for item in w.items.values(): register_food(w,item)
		s.migrated_food = true
	_refresh_trader(w)

static func register_food(w,item: Dictionary):
	if FRESH_MINUTES.has(item.get("def","")) and not item.has("fresh_until"):
		item["fresh_until"] = float(w.state.get("minute",480)) + FRESH_MINUTES[item.def]

static func can_eat(w,item: Dictionary) -> bool:
	return not FRESH_MINUTES.has(item.get("def","")) or float(w.state.minute) < float(item.get("fresh_until",0))

static func nutrition_factor(w,item: Dictionary) -> float:
	if not can_eat(w,item): return 0.0
	if not FRESH_MINUTES.has(item.get("def","")): return 1.0
	return 0.65 if float(item.fresh_until) - float(w.state.minute) < FRESH_MINUTES[item.def] * 0.25 else 1.0

static func _refresh_trader(w):
	var s: Dictionary = w.state.systems_v5
	var day = int(float(w.state.minute) / 1440)
	if int(s.trader_day) != day:
		s.trader_day = day; s.trader_stock = {"ammo":3,"battery":2,"fuel":2}

static func advance(w,minutes: float):
	ensure(w)
	if minutes <= 0 or w.state.get("failed",false): return
	var s: Dictionary = w.state.systems_v5
	s.fatigue = clampf(float(s.fatigue) + minutes * (-0.85 if s.sleeping else (-0.55 if s.resting else 0.035)),0,100)
	if s.resting: w.state.stamina = minf(100,float(w.state.stamina) + minutes * 0.9)
	if s.flashlight_on and _night(w):
		s.battery = maxf(0,float(s.battery) - minutes * 0.16)
		if s.battery <= 0: s.flashlight_on = false; w.note("手电电量耗尽。")
	if s.generator_on:
		s.fuel_minutes = maxf(0,float(s.fuel_minutes) - minutes)
		if s.fuel_minutes <= 0: s.generator_on = false; w.note("营地发电机燃油耗尽。")
	var block = int(float(w.state.minute) / 360)
	if int(s.weather_block) != block:
		s.weather_block = block
		var index = posmod(block * 17 + int(w.map.seed),10)
		var weather: String = "clear" if index < 4 else ("cloudy" if index < 6 else ("rain" if index < 9 else "heavy_rain"))
		if s.weather != weather: s.weather = weather; w.note("天气转为" + WEATHER_NAMES[weather] + "。")
	_events(w)

static func _night(w) -> bool:
	var hour = fmod(float(w.state.minute),1440.0) / 60.0
	return hour >= 20 or hour < 6

static func visibility_factor(w) -> float:
	return {"clear":1.0,"cloudy":0.94,"rain":0.82,"heavy_rain":0.66}.get(w.state.get("systems_v5",{}).get("weather","clear"),1.0)

static func light_factor(w) -> float:
	var s: Dictionary = w.state.get("systems_v5",{})
	return 1.0 if not _night(w) else (0.9 if s.get("flashlight_on",false) and s.get("battery",0) > 0 else (0.8 if w.state.zone == "camp" and s.get("generator_on",false) else 0.45))

static func summary(w) -> String:
	ensure(w)
	var s: Dictionary = w.state.systems_v5
	return "%s | 疲劳%d%s | 手电%d%% %s | 发电机%d分%s" % [WEATHER_NAMES.get(s.weather,"晴"),roundi(s.fatigue),"(休息)" if s.resting else "",roundi(s.battery),"开" if s.flashlight_on else "关",ceili(s.fuel_minutes),"运行" if s.generator_on else "停机"]

static func _near(w,zone: String,p: Vector2,radius: float = 90.0) -> bool:
	return w.state.zone == zone and Vector2(w.state.px,w.state.py).distance_to(p) <= radius

static func actions(w) -> Array:
	ensure(w)
	var s: Dictionary = w.state.systems_v5
	var result: Array = []
	result.append({"label":"结束休息" if s.resting else "原地休息（移动会结束）","request":{"kind":"sys_rest"},"duration":2.0})
	if _near(w,"camp",Vector2(505,500),85): result.append({"label":"床位睡眠（移动或受击醒来）","request":{"kind":"sys_sleep"},"duration":3.0})
	result.append({"label":"关闭手电" if s.flashlight_on else "开启手电","request":{"kind":"sys_light"},"duration":0.4})
	if w.owned("player").any(func(item):return FRESH_MINUTES.has(item.def) and not can_eat(w,item)):
		result.append({"label":"清理随身变质食物","request":{"kind":"sys_discard_food"},"duration":1.2})
	if w.count_item("battery") > 0: result.append({"label":"更换手电电池" if s.battery<100 else "手电电量已满","request":{"kind":"sys_battery"},"duration":2.0,"enabled":s.battery<100})
	if _near(w,"camp",Vector2(430,440),150):
		result.append({"label":"关闭发电机" if s.generator_on else ("开启发电机" if s.fuel_minutes>0 else "开启发电机 · 需先添加燃油"),"request":{"kind":"sys_generator"},"duration":1.2,"enabled":s.generator_on or s.fuel_minutes>0})
		result.append({"label":"添加燃油（120分钟）" if w.count_item("fuel")>0 else "添加燃油 · 请从仓库取出燃油","request":{"kind":"sys_fuel"},"duration":2.0,"enabled":w.count_item("fuel")>0})
	if _near(w,"camp",Vector2(740,420)):
		for recipe in RECIPES:
			if int(s.trader_stock.get(recipe.id,0)) > 0: result.append({"label":"商人：" + recipe.label,"request":{"kind":"sys_trade","recipe":recipe.id},"duration":2.0})
	for event in s.events:
		if event.status == "active" and _near(w,event.zone,Vector2(event.x,event.y)):
			result.append({"label":"领取空投" if event.type == "supply" else "救助幸存者（交付1饮用水）","request":{"kind":"sys_event","id":event.id},"duration":4.0})
	return result

static func complete(w,request: Dictionary) -> bool:
	ensure(w)
	if w.state.get("failed",false): return false
	var s: Dictionary = w.state.systems_v5
	match request.get("kind",""):
		"sys_discard_food":
			var discarded=false
			for item in w.owned("player"):
				if request.has("id") and item.id!=request.id: continue
				if FRESH_MINUTES.has(item.def) and not can_eat(w,item): w.items.erase(item.id); discarded=true
			return discarded
		"sys_rest": s.resting = not s.resting; s.sleeping=false; return true
		"sys_sleep":
			if not _near(w,"camp",Vector2(505,500),85): return false
			if w.enemies.any(func(e):return e.zone==w.state.zone and e.hp>0 and Vector2(e.x,e.y).distance_to(Vector2(w.state.px,w.state.py))<140): return false
			s.resting=true; s.sleeping=true; return true
		"sys_light":
			if not s.flashlight_on and s.battery <= 0: return false
			s.flashlight_on = not s.flashlight_on; return true
		"sys_battery":
			if s.battery >= 100 or not w.consume("battery",1): return false
			s.battery = 100.0; return true
		"sys_generator":
			if not _near(w,"camp",Vector2(430,440),150) or (not s.generator_on and s.fuel_minutes <= 0): return false
			s.generator_on = not s.generator_on; return true
		"sys_fuel":
			if not _near(w,"camp",Vector2(430,440),150) or s.fuel_minutes > 480 or not w.consume("fuel",1): return false
			s.fuel_minutes += 120.0; return true
		"sys_trade":
			if not _near(w,"camp",Vector2(740,420)): return false
			for recipe in RECIPES:
				if recipe.id != request.get("recipe","") or int(s.trader_stock.get(recipe.id,0)) <= 0: continue
				if not _exchange(w,recipe.cost,recipe.reward): return false
				s.trader_stock[recipe.id] -= 1; w.note("与中立商人完成交易：" + recipe.label); return true
		"sys_event":
			for event in s.events:
				if event.id != request.get("id","") or event.status != "active" or float(w.state.minute) >= float(event.expires) or not _near(w,event.zone,Vector2(event.x,event.y)): continue
				var cost: Dictionary = {"water":1} if event.type == "rescue" else {}
				for key in cost:
					if w.count_item(key) < cost[key]: return false
				var released = 0.6 if event.type == "rescue" else 0.0
				if w.weight("player") - released + w.weight(event.id) > w.capacity: return false
				for key in cost: w.consume(key,cost[key])
				for item in w.owned(event.id): item.owner = "player"
				event.status = "claimed"
				if event.type == "rescue":
					for npc in w.npcs:
						if npc.status != "down": npc.xp = int(npc.get("xp",0)) + 5
				w.note("已领取空投。" if event.type == "supply" else "幸存者得到饮水并撤往安全区，留下补给；同伴经验+5。")
				return true
	return false

static func _exchange(w,cost: Dictionary,reward: Dictionary) -> bool:
	var delta = 0.0
	for key in cost:
		if not R.ITEMS.has(key) or w.count_item(key) < cost[key]: return false
		delta -= R.ITEMS[key].weight * cost[key]
	for key in reward:
		if not R.ITEMS.has(key): return false
		delta += R.ITEMS[key].weight * reward[key]
	if w.weight("player") + delta > w.capacity: return false
	for key in cost: w.consume(key,cost[key])
	for key in reward: w.add_item(key,reward[key],"player")
	return true

static func _events(w):
	var s: Dictionary = w.state.systems_v5
	for event in s.events:
		if event.status == "active" and float(w.state.minute) >= float(event.expires):
			event.status = "expired"
			for item in w.owned(event.id): w.items.erase(item.id)
	# Radio gives two hours of advance notice, once per encounter, including after load.
	var upcoming = int(floor((float(w.state.minute) - 1920.0) / 2880.0))
	if upcoming >= 0 and upcoming > int(s.last_announcement):
		s.last_announcement = upcoming
		var upcoming_start = 2040.0 + upcoming * 2880.0
		if float(w.state.minute) < upcoming_start:
			var destination = _event_point(w,upcoming)
			w.note("无线电预告：今天10:00%s，公路坐标(%d,%d)。%s" % ["将投放补给" if upcoming % 2 == 0 else "有幸存者等待救助",destination.x,destination.y,"请预留背包空间。" if upcoming % 2 == 0 else "请携带1份饮用水。"])
	# First transmission day 2 at 10:00; one new encounter every two days.
	var index = int(floor((float(w.state.minute) - 2040.0) / 2880.0))
	if index < 0 or index <= int(s.last_event): return
	s.last_event = index
	var start = 2040.0 + index * 2880.0
	if float(w.state.minute) >= start + 1440: return
	var point = _event_point(w,index)
	var id = "event_v5_%d" % index
	var event = {"id":id,"type":"supply" if index % 2 == 0 else "rescue","zone":"town","x":point.x,"y":point.y,"status":"active","expires":start + 1440}
	s.events.append(event)
	while s.events.size() > 4: s.events.pop_front()
	for entry in [["food",2],["ammo9",12]] if event.type == "supply" else [["bandage",2],["parts",2]]: w.add_item(entry[0],entry[1],id)
	w.note("营地无线电：%s，公路坐标(%d,%d)，请在24小时内前往。" % ["补给空投已落地" if event.type == "supply" else "幸存者求助，需要1饮用水",point.x,point.y])

static func _event_point(w,index: int) -> Vector2:
	if w.map.roads.is_empty(): return Vector2(610,490)
	var road: Dictionary = w.map.roads[posmod(index,w.map.roads.size())]
	return (road.a + road.b) / 2.0

static func event_markers(w) -> Array:
	ensure(w)
	var result: Array = []
	for event in w.state.systems_v5.events:
		if event.status == "active": result.append(event)
	return result

static func valid_owners(w) -> Array:
	var result: Array = []
	for event in w.state.get("systems_v5",{}).get("events",[]): result.append(event.id)
	return result

static func _valid_event(event) -> bool:
	if not event is Dictionary: return false
	if not event.get("id",null) is String or not event.id.begins_with("event_v5_"): return false
	if event.get("type","") not in ["supply","rescue"] or event.get("status","") not in ["active","claimed","expired"] or event.get("zone","") != "town": return false
	for key in ["x","y","expires"]:
		if not (event.get(key) is float or event.get(key) is int) or not is_finite(float(event[key])) or event[key] < 0: return false
	return true

static func valid_state(state: Dictionary) -> bool:
	if not state.has("systems_v5"): return true
	var s = state.systems_v5
	if not s is Dictionary: return false
	for key in ["fatigue","battery","fuel_minutes"]:
		if not (s.get(key) is float or s.get(key) is int) or not is_finite(float(s[key])) or s[key] < 0: return false
	if s.fatigue > 100 or s.battery > 100: return false
	for key in ["resting","flashlight_on","generator_on"]:
		if not s.get(key) is bool: return false
	if not WEATHER_NAMES.has(s.get("weather","")) or not s.get("events") is Array or not s.get("trader_stock") is Dictionary: return false
	var seen: Array = []
	for event in s.events:
		if not _valid_event(event) or event.id in seen: return false
		seen.append(event.id)
	for value in s.trader_stock.values():
		if not (value is int or value is float) or not is_finite(float(value)) or value < 0 or value > 3: return false
	return true
