extends Node2D

const World = preload("res://scripts/world.gd")
const R = preload("res://scripts/rules.gd")
const View = preload("res://scripts/world_view.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const Geometry = preload("res://scripts/building_geometry.gd")
const Pose = preload("res://scripts/actor_pose.gd")
const Forage = preload("res://scripts/forage.gd")
const Survival = preload("res://scripts/survival_systems.gd")
const Tactics = preload("res://scripts/tactical_systems.gd")
const Recoil = preload("res://scripts/weapon_recoil.gd")
const Navigation = preload("res://scripts/local_navigation.gd")
var world = World.new()
var view
var hud
var camera: Camera2D
var aim = Vector2.RIGHT
var moving = false
var action: Dictionary = {}
var recoil_heat: Dictionary = {}
var shot_cd = 0.0
var guard_cd = 0.0
var autosave = 0.0
var transition_cd = 0.0
var last_damage = 0.0
var sound
var placement: Dictionary = {}
var solid_cache: Array = []
var solid_cache_key = 0
var polygon_cache: Array = []
var solid_rect_grid: Dictionary = {}
var solid_polygon_grid: Dictionary = {}
var last_collision_candidates = 0
var last_visibility_candidates = 0
const SOLID_GRID_CELL = 128.0
var focus = 0.0
var combat_state = "idle"
var random = RandomNumberGenerator.new()
var world_zoom = 1.25
var footstep_noise = 0.0
var walk_direction = Vector2.DOWN
var visual_refresh_clock = 0.0
var hud_refresh_clock = 0.0
var enemy_update_cursor = 0

func set_world_zoom(value: float):
	world_zoom = clampf(value,0.65,2.0)
	if camera != null: camera.zoom = Vector2.ONE * world_zoom

func muzzle_position() -> Vector2:
	return Pose.muzzle(player_pos(),aim,world.state.weapon)

func _ready():
	if OS.get_name()=="Android": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not world.load_game():
		world.new_world(); world.save_game(world.dawn_path())
	view = View.new(); view.game = self; add_child(view)
	sound = Sound.new(); add_child(sound)
	camera = Camera2D.new(); camera.zoom = Vector2.ONE * world_zoom; add_child(camera)
	random.randomize()
	hud = Hud.new(); hud.game = self; add_child(hud)
	ensure_spawn_point()
	get_tree().auto_accept_quit = false

func player_pos() -> Vector2:
	return Vector2(world.state.px, world.state.py)

func set_pos(p: Vector2):
	world.state.px = p.x; world.state.py = p.y

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if hud != null:
			action.clear(); placement.clear(); hud.open_panel("pause"); world.save_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		world.save_game(); get_tree().quit()

func _process(delta: float):
	if hud == null: return
	hud_refresh_clock += delta
	if hud_refresh_clock >= 0.1:
		hud.refresh()
		hud_refresh_clock = fposmod(hud_refresh_clock,0.1)
	camera.position = player_pos() + Vector2(0,-40)
	visual_refresh_clock += delta
	if visual_refresh_clock >= 1.0/30.0:
		view.queue_redraw()
		visual_refresh_clock = fposmod(visual_refresh_clock,1.0/30.0)
	if world.paused: return
	delta = minf(delta,0.1)
	cool_recoil(delta)
	wake_for_threat()
	if world.state.systems_v5.sleeping: delta *= 4.0
	world.tick(delta)
	shot_cd = maxf(0, shot_cd - delta); guard_cd -= delta; autosave += delta; transition_cd -= delta; last_damage -= delta
	for f in view.flashes: f.life -= delta
	view.flashes = view.flashes.filter(func(f): return f.life > 0)
	var movement: Vector2 = hud.move_axis
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1
	movement = movement.limit_length()
	moving = movement.length() > 0.1
	if moving:
		world.state.systems_v5.resting=false; world.state.systems_v5.sleeping=false
		walk_direction = movement.normalized()
		action.clear()
		focus = maxf(0,focus - delta * 2.5); combat_state = "move"
		var speed = R.SPEED * (0.72 if world.state.stamina < 10 else 1.0) * (0.8 if world.state.systems_v5.fatigue>=80 else 1.0)
		set_pos(move_with_collision(player_pos(), movement * speed * delta))
		world.state.stamina = maxf(0, world.state.stamina - delta * 1.8)
		footstep_noise -= delta
		if footstep_noise<=0:
			emit_noise(player_pos(),80,false); footstep_noise=0.8
	else: world.state.stamina = minf(100, world.state.stamina + delta * (4 if world.state.systems_v5.fatigue>=80 else 8))
	if hud.aim_axis.length() > 0.2: aim = hud.aim_axis.normalized()
	elif not DisplayServer.is_touchscreen_available():
		var mouse_dir = get_global_mouse_position() - player_pos()
		if mouse_dir.length() > 6: aim = mouse_dir.normalized()
	var mouse_shoot = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not DisplayServer.is_touchscreen_available() and get_viewport().gui_get_hovered_control() == null
	var aiming = hud.aim_axis.length() > 0.2 or hud.fire_held or mouse_shoot or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not moving:
		combat_state = "aim" if aiming else "idle"
		focus = minf(1,focus + delta * current_stats().get("focus",1.0) * 0.8) if aiming else maxf(0,focus - delta * 0.3)
	if hud.fire_held or hud.aim_axis.length()>0.2 or mouse_shoot or Input.is_physical_key_pressed(KEY_SPACE): fire()
	if world.state.zone == "town":
		var sector = world.map.sector_id(player_pos())
		if sector not in world.state.explored:
			world.state.explored.append(sector); world.note("发现 " + world.map.region_name(player_pos()) + "，已记录到地图。")
	if not action.is_empty():
		action.remaining -= delta
		if action.remaining <= 0: complete_action()
	update_enemies(delta)
	if Tactics.tick(self,delta): sound.play("alarm")
	update_npcs(delta)
	if world.state.hp <= 0:
		action.clear(); placement.clear(); world.die(); solid_cache_key=-1; ensure_spawn_point(); world.save_game()
	if autosave > 20:
		world.save_game(); autosave = 0

func change_zone(zone: String, _pos: Vector2):
	# Compatibility entry point; regions now travel only through an explicit exit.
	travel_request("forest" if zone=="forest" else "town")

func travel_request(target_map_id: String) -> bool:
	if world.paused or not action.is_empty(): return false
	if not world.travel(target_map_id): return false
	solid_cache_key=-1; solid_cache.clear(); polygon_cache.clear(); placement.clear()
	Navigation.cache.clear(); transition_cd=2
	return true

func emit_noise(source: Vector2, radius: float, announce: bool = true):
	for enemy in world.enemies:
		if enemy.hp<=0 or enemy.zone!=world.state.zone: continue
		var ep=Vector2(enemy.x,enemy.y)
		var effective=radius if visible(source,ep) else radius*0.55
		if ep.distance_to(source)>effective: continue
		enemy.alert=maxf(enemy.get("alert",0),8)
		enemy["mode"]="investigate"; enemy.tx=source.x; enemy.ty=source.y
	if announce and radius>=300: world.note("响声传向附近街区，感染者会调查声源。")

func wake_for_threat() -> bool:
	if not world.state.get("systems_v5",{}).get("sleeping",false): return false
	for enemy in world.enemies:
		if enemy.hp>0 and enemy.zone==world.state.zone and Vector2(enemy.x,enemy.y).distance_to(player_pos())<140:
			world.state.systems_v5.sleeping=false; world.state.systems_v5.resting=false
			world.note("附近的动静惊醒了你。")
			return true
	return false

func building_walls(b: Dictionary) -> Array:
	return Geometry.rectangles(b)

func door_rect(b: Dictionary, side: int) -> Rect2:
	return Geometry.door(b) if side == 0 else Rect2(-99999,-99999,1,1)

func solids() -> Array:
	var chunk = Vector2i(player_pos() / 600)
	var key = hash([world.map.seed,world.state.get("map_id","town"),world.doors,world.furniture,chunk,world.defenses,world.state.get("tactics_v5",{})])
	if key == solid_cache_key and not solid_cache.is_empty(): return solid_cache
	var result: Array = []
	polygon_cache.clear()
	if world.state.zone == "town":
		for b in world.map.buildings_at(player_pos(),2000):
			result.append_array(building_walls(b))
			for polygon in Geometry.polygons(b):
				var box = Rect2(polygon[0],Vector2.ZERO)
				for p in polygon: box = box.expand(p)
				polygon_cache.append({"points":polygon,"bounds":box})
			for side in [0]:
				if Tactics.door_blocked(world,b): result.append(door_rect(b, side))
	for f in world.furniture:
		if not f.packed and f.hp > 0 and f.zone == world.state.zone: result.append(Rect2(f.x - 16, f.y - 16, 32, 28))
	for car in world.map.cars_at(player_pos(),2100,world.state.zone): result.append(car.body)
	for tree in world.map.trees_at(player_pos(),2100,world.state.zone): result.append(tree.trunk)
	for plant in world.map.plants_at(player_pos(),2100,world.state.zone):
		if plant.kind == "apple": result.append(Rect2(plant.pos-Vector2(6,4),Vector2(12,8)))
	result.append_array(Tactics.solids(self))
	for defense in world.defenses:
		if defense.hp > 0 and defense.kind != "wire": result.append(defense_rect(defense))
	solid_cache_key = key; solid_cache = result
	solid_rect_grid.clear(); solid_polygon_grid.clear()
	for index in range(solid_cache.size()): _index_spatial(solid_rect_grid,solid_cache[index],index)
	for index in range(polygon_cache.size()): _index_spatial(solid_polygon_grid,polygon_cache[index].bounds,index)
	return result

func _index_spatial(grid: Dictionary,rect: Rect2,index: int):
	var start=Vector2i(floori(rect.position.x/SOLID_GRID_CELL),floori(rect.position.y/SOLID_GRID_CELL))
	var end=Vector2i(floori(rect.end.x/SOLID_GRID_CELL),floori(rect.end.y/SOLID_GRID_CELL))
	for y in range(start.y,end.y+1):
		for x in range(start.x,end.x+1):
			var cell=Vector2i(x,y)
			if not grid.has(cell): grid[cell]=[]
			grid[cell].append(index)

func _spatial_candidates(grid: Dictionary,bounds: Rect2,count: int) -> Array:
	var start=Vector2i(floori(bounds.position.x/SOLID_GRID_CELL),floori(bounds.position.y/SOLID_GRID_CELL))
	var end=Vector2i(floori(bounds.end.x/SOLID_GRID_CELL),floori(bounds.end.y/SOLID_GRID_CELL))
	var seen={}; var result=[]
	for y in range(start.y,end.y+1):
		for x in range(start.x,end.x+1):
			for index in grid.get(Vector2i(x,y),[]):
				if index<count and not seen.has(index): seen[index]=true; result.append(index)
	return result

func blocked(pos: Vector2) -> bool:
	var limit: Vector2 = world.map.size
	if pos.x < 40 or pos.x > limit.x - 40 or pos.y < 20 or pos.y > limit.y - 40: return true
	if world.state.zone == "town" and world.map.water_at(pos): return true
	solids()
	var candidates=_spatial_candidates(solid_rect_grid,Rect2(pos-Vector2(6,6),Vector2(12,12)),solid_cache.size())
	last_collision_candidates=candidates.size()
	for index in candidates:
		var rect: Rect2=solid_cache[index]
		if rect.grow(4.5).has_point(pos): return true
	var polygon_candidates=_spatial_candidates(solid_polygon_grid,Rect2(pos-Vector2(6,6),Vector2(12,12)),polygon_cache.size())
	for index in polygon_candidates:
		var entry: Dictionary=polygon_cache[index]
		if not entry.bounds.grow(5).has_point(pos): continue
		for offset in [Vector2.ZERO,Vector2(4,0),Vector2(-4,0),Vector2(0,4),Vector2(0,-4)]:
			if Geometry2D.is_point_in_polygon(pos + offset,entry.points): return true
	return false

func move_with_collision(pos: Vector2, motion: Vector2) -> Vector2:
	var count = clampi(int(ceil(motion.length()/5)),1,128); var step = motion / count
	for i in range(count):
		var next = pos + Vector2(step.x,0)
		if not blocked(next): pos = next
		next = pos + Vector2(0,step.y)
		if not blocked(next): pos = next
	return pos

func visible(a: Vector2, b: Vector2, _ignore_low_cover: bool = false) -> bool:
	solids()
	var low=Vector2(minf(a.x,b.x),minf(a.y,b.y)); var high=Vector2(maxf(a.x,b.x),maxf(a.y,b.y))
	var bounds=Rect2(low,high-low).grow(2)
	var candidates=_spatial_candidates(solid_rect_grid,bounds,solid_cache.size())
	last_visibility_candidates=candidates.size()
	for index in candidates:
		var rect: Rect2=solid_cache[index]
		if not rect.grow(2).intersects(bounds): continue
		if Geometry2D.segment_intersects_segment(a,b,rect.position,Vector2(rect.end.x,rect.position.y)) != null: return false
		if Geometry2D.segment_intersects_segment(a,b,Vector2(rect.end.x,rect.position.y),rect.end) != null: return false
		if Geometry2D.segment_intersects_segment(a,b,rect.end,Vector2(rect.position.x,rect.end.y)) != null: return false
		if Geometry2D.segment_intersects_segment(a,b,Vector2(rect.position.x,rect.end.y),rect.position) != null: return false
	for index in _spatial_candidates(solid_polygon_grid,bounds,polygon_cache.size()):
		var entry: Dictionary=polygon_cache[index]
		if Geometry2D.get_closest_point_to_segment(entry.bounds.get_center(),a,b).distance_to(entry.bounds.get_center()) > entry.bounds.size.length()/2 + 3: continue
		var points: PackedVector2Array = entry.points
		for i in range(points.size()):
			if Geometry2D.segment_intersects_segment(a,b,points[i],points[(i+1)%points.size()]) != null: return false
	return true

func can_see_actor(pos: Vector2) -> bool:
	if player_pos().distance_to(pos) > 1100*Survival.visibility_factor(world)*Survival.light_factor(world): return false
	if world.state.zone == "town":
		for b in world.map.buildings_at(player_pos(),1300):
			if Geometry.interior(b).has_point(pos) and not Geometry.interior(b).has_point(player_pos()): return false
	return visible(player_pos(),pos)

func cool_recoil(delta: float):
	for id in recoil_heat.keys():
		recoil_heat[id] = Recoil.cool(float(recoil_heat[id]),delta)
		if recoil_heat[id]<=0 or not world.items.has(id): recoil_heat.erase(id)

func fire():
	if shot_cd > 0 or world.paused: return
	world.state.systems_v5.resting=false; world.state.systems_v5.sleeping=false
	action.clear()
	var weapon = world.state.weapon
	var id = world.player_weapon(weapon)
	if id.is_empty(): weapon = "knife"
	var melee = weapon == "knife"
	if melee and world.state.stamina < 8: return
	var damage = 30.0; var reach = 51.0; var pellets = 1; var spread = 0.0
	if hud.aim_assist and not melee:
		var smallest_angle = 0.13
		for enemy in world.enemies:
			if enemy.zone != world.state.zone or enemy.hp <= 0: continue
			var relative = Vector2(enemy.x,enemy.y-10) - Pose.grip(player_pos())
			var angle = absf(aim.angle_to(relative.normalized()))
			if relative.length() < current_stats().range and angle < smallest_angle and visible(player_pos(),Vector2(enemy.x,enemy.y)):
				aim = relative.normalized(); smallest_angle = angle
	var origin = player_pos() if melee else muzzle_position()
	if not melee:
		# Gun and barrel cannot pass through a wall to hit an enemy on its other side.
		if not visible(player_pos(),origin) or blocked(origin):
			shot_cd = 0.15; return
		var gun = world.items[id]
		if gun.ammo <= 0:
			shot_cd = 0.4; world.note("弹药耗尽：点击换弹，或切换近战。")
			return
		gun.ammo -= 1
		var d = R.weapon_stats(gun,world.items); damage = d.damage; reach = d.range; shot_cd = d.cooldown; pellets = d.pellets
		spread = d.spread * lerpf(2.6,0.4,focus) * (1.7 if moving else 1.0) + float(recoil_heat.get(id,0.0))
		recoil_heat[id] = Recoil.after_shot(float(recoil_heat.get(id,0.0)),d.spread)
		emit_noise(player_pos(),d.noise)
	else:
		shot_cd = 0.48; world.state.stamina -= 8
	sound.play("melee" if melee else "shot")
	for pellet in range(pellets):
		var ray = aim.rotated(random.randf_range(-spread,spread)) if not melee else aim
		var best = {}; var distance = reach
		if not melee and not visible(origin,origin+ray*distance):
			var low = 0.0; var high = distance
			for i in range(10):
				var mid = (low+high)/2
				if visible(origin,origin+ray*mid): low=mid
				else: high=mid
			distance=low
		for enemy in world.enemies:
			if enemy.zone != world.state.zone or enemy.hp <= 0: continue
			var hit = Vector2(enemy.x,enemy.y) if melee else Vector2(enemy.x,enemy.y-10)
			var relative = hit - origin; var dist = relative.length() if melee else relative.dot(ray)
			var intersects = relative.normalized().dot(ray) > 0.35 if melee else relative.dot(ray) >= 0 and absf(relative.cross(ray)) < 14
			if dist < distance and intersects and visible(origin,hit):
				best = enemy; distance = dist
		if not best.is_empty():
			best.hp -= damage
			if best.hp <= 0: world.state.kills += 1
		var end = origin + ray * distance
		view.flashes.append({"a":origin,"b":end,"life":0.08})
	if not melee: focus = maxf(0,focus - minf(0.12,spread * 0.6))

func current_stats() -> Dictionary:
	var id = world.player_weapon(world.state.weapon)
	return R.weapon_stats(world.items[id],world.items) if not id.is_empty() and world.items[id].has("slots") else {}

func cycle_weapon(category: String):
	var choices = world.owned("player").filter(func(i): return i.has("slots") and ((i.def in ["pistol","pm","colt","magnum"]) == (category == "sidearm")))
	if choices.is_empty(): world.note("背包中没有这类枪械，请探索警务点或建筑搜刮。"); return
	var identifiers = choices.map(func(i): return i.id)
	var selected = world.player_weapon(world.state.weapon)
	world.equip(identifiers[(identifiers.find(selected) + 1) % identifiers.size()])
	focus = 0; action.clear()

func update_enemies(delta: float):
	var active: Array=[]
	var player=player_pos()
	for e in world.enemies:
		if e.zone != world.state.zone or e.hp <= 0: continue
		if Vector2(e.x,e.y).distance_squared_to(player) > 1250 * 1250: continue
		e["ai_clock"]=e.get("ai_clock",0.0)+delta
		active.append(e)
	if active.is_empty(): enemy_update_cursor=0; return
	var budget=maxi(1,ceili(active.size()/6.0))
	var start=enemy_update_cursor%active.size()
	for offset in range(mini(budget,active.size())):
		var e: Dictionary=active[(start+offset)%active.size()]
		if e.ai_clock<0.08: continue
		var enemy_delta=minf(e.ai_clock,0.25)
		e.ai_clock=0.0
		var p=Vector2(e.x,e.y)
		e.cd-=enemy_delta; e.alert=maxf(0,e.alert-enemy_delta)
		if not e.has("mode"): e["mode"]="wander"
		var sight=(140.0 if is_night() else 240.0)*Survival.visibility_factor(world)
		e["sense_left"]=e.get("sense_left",0.0)-enemy_delta
		if e.sense_left<=0:
			e.sense_left=0.3
			if p.distance_to(player_pos())<sight and visible(p,player_pos()):
				e.alert=7; e.tx=world.state.px; e.ty=world.state.py; e.mode="chase"
			elif e.mode=="chase": e.mode="search"
		if e.alert<=0:
			e.mode="wander"
			e["wander_left"]=e.get("wander_left",0.0)-enemy_delta
			if e.wander_left<=0 or p.distance_to(Vector2(e.tx,e.ty))<9:
				e.wander_left=random.randf_range(3,8)
				var goal=p+Vector2.RIGHT.rotated(random.randf_range(-PI,PI))*random.randf_range(35,150)
				e.tx=clampf(goal.x,50,world.map.size.x-50); e.ty=clampf(goal.y,50,world.map.size.y-50)
		elif p.distance_to(Vector2(e.tx,e.ty))<12:
			e.mode="search"
			# Search locally around the last observed/heard point; never update from a hidden player.
			if e.alert>3:
				var search=p+Vector2.RIGHT.rotated(float(hash(e.id)%360))*38
				if not blocked(search): e.tx=search.x; e.ty=search.y
		var target=Vector2(e.tx,e.ty)
		var direction=(target-p).normalized()
		var speed=92.0 if e.kind=="fast" else (35.0 if e.kind=="breaker" else 48.0)
		if e.mode=="wander": speed*=0.3
		if e.get("slow_until",0)>world.state.minute: speed*=0.35
		var next=move_with_collision(p,direction*speed*enemy_delta)
		if next.distance_to(p)<0.1 and p.distance_to(target)>35:
			next=Navigation.next_step(self,p,target,speed,enemy_delta)
		e["walking"]=next.distance_to(p)>0.05
		if e.walking: e["facing_x"]=(next-p).normalized().x; e["facing_y"]=(next-p).normalized().y
		e.x=next.x; e.y=next.y
		if e.cd>0: continue
		if next.distance_to(player_pos())<26 and visible(next,player_pos()):
			damage_player(13 if e.kind=="breaker" else 8); e.cd=1.0
		elif e.alert>0:
			for f in world.furniture:
				if f.zone==e.zone and not f.packed and f.hp>0 and p.distance_to(Vector2(f.x,f.y))<38:
					f.hp=maxf(0,f.hp-9); e.cd=1
			for b in world.map.buildings_at(p,100):
				if Tactics.door_blocked(world,b) and p.distance_to(door_rect(b,0).get_center())<40:
					if Tactics.damage_door(world,b.container+"0",35 if e.kind=="breaker" else 14): world.note("门被撞坏了！")
					wake_for_barrier(b.container)
					e.cd=2
			if e.cd<=0:
				for win in Tactics.windows(world,p,100):
					if p.distance_to(win.pos)>40: continue
					if win.state.board_hp>0 or not win.state.broken:
						Tactics.damage_window(world,win.id,30 if e.kind=="breaker" else 12); e.cd=2
						wake_for_barrier(str(win.id).trim_suffix("_window"))
					elif (p.y-win.pos.y)*(e.ty-win.pos.y)<0:
						var landing:Vector2=win.inside if e.ty<win.pos.y else win.outside
						var approach:Vector2=win.outside if e.ty<win.pos.y else win.inside
						if p.distance_to(approach)<=26 and not blocked(landing): e.x=landing.x; e.y=landing.y; e.cd=1
	enemy_update_cursor=(start+mini(budget,active.size()))%active.size()
	world.enemies=world.enemies.filter(func(e):return e.hp>0)

func wake_for_barrier(building_id: String):
	if not world.state.systems_v5.sleeping: return
	var bed=world.near_bed()
	if bed.get("building_id","")!=building_id: return
	world.state.systems_v5.sleeping=false; world.state.systems_v5.resting=false
	world.note("撞击门窗的声音惊醒了你。")

func damage_player(amount: float):
	if last_damage > 0: return
	world.state.systems_v5.resting=false; world.state.systems_v5.sleeping=false
	world.state.hp -= amount; action.clear(); last_damage = 0.5
	sound.play("hurt")
	if world.state.hp < 35: world.state.bleeding = true

func update_npcs(delta: float):
	for n in world.npcs:
		if n.zone != world.state.zone or n.status in ["down","waiting"]: continue
		var p = Vector2(n.x,n.y)
		if n.status=="injured" and not world.enemies.any(func(e):return e.hp>0 and Vector2(e.x,e.y).distance_to(p)<140):
			for bed in world.beds():
				if bed.hp>0 and p.distance_to(Vector2(bed.x,bed.y))<75:
					n.hp=minf(90,n.hp+delta*0.35)
					if n.hp>=85: n.status="healthy"
					break
		n["walking"]=false
		var destination=p
		if n.follow and p.distance_to(player_pos())>60: destination=player_pos()
		elif n.get("order","")=="guard": destination=Vector2(n.get("anchor_x",n.x),n.get("anchor_y",n.y))
		elif n.get("order","")=="patrol":
			var anchor=Vector2(n.get("anchor_x",n.x),n.get("anchor_y",n.y))
			destination=anchor+Vector2(50 if int(world.state.minute/3)%2==0 else -50,0)
		if destination.distance_to(p)>5:
			var next=Navigation.next_step(self,p,destination,110,delta)
			n["walking"]=next.distance_to(p)>0.05
			if n.walking: n["facing_x"]=(next-p).normalized().x; n["facing_y"]=(next-p).normalized().y
			n.x=next.x; n.y=next.y
		for e in world.enemies:
			if e.zone == n.zone and Vector2(e.x,e.y).distance_to(p) < 25:
				n.hp -= delta * 13
				if n.hp <= 0: n.status = "down"; n.follow = false; world.note(n.name + "倒地待救，位置已标记。")
	if guard_cd <= 0:
		guard_cd = 1.1
		for n in world.npcs:
			if n.zone != world.state.zone or n.status in ["down","waiting"] or n.job != "守卫" or n.get("hold_fire",false): continue
			var guns=world.owned(n.id).filter(func(item):return item.has("slots"))
			if guns.is_empty(): continue
			var gun: Dictionary=guns[0]
			if gun.ammo<=0:
				var ammo_type: String=R.ITEMS[gun.def].ammo
				var amount=mini(R.capacity_for(gun),world.count_item(ammo_type,n.id))
				if amount<=0: continue
				world.consume(ammo_type,amount,n.id); gun.ammo+=amount
			for e in world.enemies:
				if e.zone == n.zone and Vector2(e.x,e.y).distance_to(Vector2(n.x,n.y)) < 340:
					if not visible(Vector2(n.x,n.y),Vector2(e.x,e.y),true): continue
					e.hp -= R.weapon_stats(gun,world.items).damage; gun.ammo-=1; n.xp += 1
					emit_noise(Vector2(n.x,n.y),280,false)
					view.flashes.append({"a":Vector2(n.x,n.y),"b":Vector2(e.x,e.y),"life":0.1})
					break

func is_night() -> bool:
	var minute = fmod(world.state.minute,1440)
	return minute >= 1200 or minute < 360

func container_pos(id: String) -> Vector2:
	for g in world.graves:
		if g.id == id: return Vector2(g.x,g.y)
	for f in world.furniture:
		if f.id == id: return Vector2(f.x,f.y)
	for car in world.map.cars_at(player_pos(),2500,world.state.zone):
		if car.id == id: return car.trunk_pos
	for b in world.map.buildings:
		if b.container == id: return Geometry.loot_point(b)
	return Vector2(-999,-999)

func targets() -> Array:
	var list: Array = []
	for b in world.map.buildings_at(player_pos(),200):
		list.append({"kind":"container","id":b.container,"pos":container_pos(b.container),"name":"搜刮"+b.name})
		list.append({"kind":"door","id":b.container+"0","pos":door_rect(b,0).get_center(),"name":"加固房门" if Tactics.door_state(world,b.container+"0").board_hp>0 else "开关门"})
	for bed in world.beds():
		list.append({"kind":"mechanics","id":bed.id,"pos":Vector2(bed.x,bed.y),"name":"床位 · 休息与落脚点"})
	for exit in world.exits():
		list.append({"kind":"mechanics","id":exit.id,"pos":Vector2(exit.x,exit.y),"name":exit.name})
	for event in Survival.event_markers(world):
		if event.zone==world.state.zone: list.append({"kind":"mechanics","id":event.id,"pos":Vector2(event.x,event.y),"name":"补给空投" if event.type=="supply" else "求救幸存者"})
	if world.state.zone=="town":
		for win in Tactics.windows(world,player_pos()): list.append({"kind":"mechanics","id":win.id,"pos":win.pos,"name":"窗户 · 生存操作"})
	for car in world.map.cars_at(player_pos(),180,world.state.zone): list.append({"kind":"container","id":car.id,"pos":car.trunk_pos,"name":"搜寻汽车后备箱"})
	for plant in world.map.plants_at(player_pos(),150,world.state.zone):
		if Forage.ready(world.state.harvests,plant.id,int(world.state.minute)):
			list.append({"kind":"harvest","id":plant.id,"plant_kind":plant.kind,"pos":plant.pos,"name":"采集"+Forage.definition(plant.kind).name})
	for f in world.furniture:
		if f.zone == world.state.zone and not f.packed and f.hp > 0: list.append({"kind":"furniture","id":f.id,"pos":Vector2(f.x,f.y),"name":"小型柜子"})
	for g in world.graves:
		if g.zone == world.state.zone: list.append({"kind":"container","id":g.id,"pos":Vector2(g.x,g.y),"name":"回收遗物"})
	for n in world.npcs:
		if n.zone == world.state.zone and n.status in ["down","waiting"]: list.append({"kind":"rescue","id":n.id,"pos":Vector2(n.x,n.y),"name":"救援" + n.name})
	return list

func nearest_target() -> Dictionary:
	var best = {}; var distance = 70.0
	for t in targets():
		var d = player_pos().distance_to(t.pos)
		if d < distance and (t.kind == "door" or interaction_visible(t.pos)):
			best = t; distance = d
	return best

func interact():
	if world.paused: return
	if not placement.is_empty():
		var p = placement_position()
		if valid_placement(p): start_action({"kind":"place","id":placement.id,"pos":p,"rotation":placement.rotation},2); placement.clear()
		else: world.note("红色区域无法放置，请留出通路。")
		return
	var t = nearest_target()
	if t.is_empty(): world.note("靠近房门、床位、物资、地区出口或待救同伴后互动。"); return
	match t.kind:
		"harvest": start_action({"kind":"harvest","id":t.id,"pos":t.pos},Forage.definition(t.plant_kind).duration)
		"container", "furniture":
			if not world.state.searched.has(t.id): start_action({"kind":"search","id":t.id,"pos":t.pos},2.6)
			else: hud.container_id = t.id; hud.open_panel("loot")
		"door":
			var d=Tactics.door_state(world,t.id)
			if d.board_hp>0 or d.broken: world.note("门已加固或损坏，请打开生存操作处理。")
			else: start_action({"kind":"tac_door_toggle","id":t.id},0.6)
		"mechanics": hud.open_panel("mechanics")
		"rescue": start_action({"kind":"rescue","id":t.id,"pos":t.pos},4)
		"repair": start_action({"kind":"repair","id":"wall","pos":t.pos},3)

func start_action(request: Dictionary, duration: float = R.ACTION_SECONDS):
	hud.close_panel()
	action = request.duplicate(true); action["remaining"] = duration; action["duration"] = duration
	action["zone"] = world.state.zone
	action["map_id"] = world.state.get("map_id","town")

func complete_action():
	var request = action.duplicate(true); action.clear()
	if request.zone != world.state.zone or request.get("map_id",world.state.get("map_id","town"))!=world.state.get("map_id","town"): return
	if request.has("pos") and (player_pos().distance_to(request.pos) > 85 or not interaction_visible(request.pos)):
		world.note("行动中断：目标不可达。"); return
	var ok = false
	match request.kind:
		"harvest": ok = world.harvest_plant(request.id)
		"search":
			emit_noise(player_pos(),110,false)
			world.state.searched[request.id] = true; ok = true
			hud.container_id = request.id; hud.open_panel("loot")
		"build_defense":
			if valid_placement(request.pos): ok = world.build_defense(request.defense_kind,request.pos)
		"transfer":
			if world.items.has(request.id) and world.items[request.id].owner == request.source: ok = world.transfer(request.id,request.target)
		"reload": ok = world.reload_weapon(request.id)
		"attach": ok = world.attach(request.gun,request.id)
		"detach": ok = world.detach(request.gun,request.slot)
		"pack": ok = world.pack_furniture(request.id)
		"place":
			var p: Vector2 = request.pos
			if valid_placement(p):
				ok = world.place_furniture(request.id,world.state.zone,p)
				if ok:
					for f in world.furniture:
						if f.id == request.id: f.rotation = request.get("rotation",0)
		"rescue":
			for n in world.npcs:
				if n.id == request.id and n.status in ["down","waiting"]:
					if n.status == "waiting" or world.consume("bandage",1):
						for other in world.npcs:
							if other.id != n.id and other.follow:
								other.follow = false
						n.status = "injured"; n.hp = 35; n.follow = true; ok = true; world.note(n.name + "加入队伍，可在安全床位休养。")
		_:
			if str(request.kind).begins_with("ex_"): ok=complete_exploration_action(request)
			elif str(request.kind).begins_with("sys_"): ok=Survival.complete(world,request)
			elif str(request.kind).begins_with("tac_"): ok=Tactics.complete(self,request)
	if ok:
		if request.kind in ["sys_cycle_boil","sys_cycle_wood","sys_cycle_craft"]: emit_noise(player_pos(),100,false)
		sound.play("reload")
		world.save_game()
		if request.has("queue") and not request.queue.is_empty():
			var rest: Array = request.queue; var next_id = rest.pop_front()
			start_action({"kind":"transfer","id":next_id,"source":request.source,"target":request.target,"pos":request.pos,"queue":rest})
	else: world.note("未完成：请检查容量、物资、兼容性及目标状态。")

func reload_request():
	if not placement.is_empty(): placement.rotation = (int(placement.rotation) + 90) % 360; return
	var id = world.player_weapon(world.state.weapon)
	if not id.is_empty() and world.items[id].has("ammo"): start_action({"kind":"reload","id":id},R.weapon_stats(world.items[id],world.items).reload)

func interaction_visible(pos: Vector2) -> bool:
	var distance = player_pos().distance_to(pos)
	var end = pos - (pos-player_pos()).normalized() * minf(18,distance * 0.5)
	return visible(player_pos(),end)

func is_searching() -> bool:
	return not action.is_empty() and action.get("kind","") in ["search","transfer","harvest"]

func defense_rect(defense: Dictionary) -> Rect2:
	var size = Vector2(70,18) if defense.kind != "guardpost" else Vector2(34,28)
	return Rect2(Vector2(defense.x,defense.y)-size/2,size)

func start_defense(kind: String):
	var pos = (player_pos()+aim*70).snapped(Vector2(16,16))
	if not valid_placement(pos): world.note("此处占用，请留出通行空间。"); return
	start_action({"kind":"build_defense","defense_kind":kind,"pos":pos},4)

func start_new_game():
	world.save_game(world.save_directory.path_join("previous-world.json"))
	action.clear(); placement.clear(); recoil_heat.clear(); solid_cache.clear(); polygon_cache.clear()
	world.new_world(); world.save_game(); world.save_game(world.dawn_path()); hud.close_panel()
	ensure_spawn_point()

func ensure_spawn_point():
	if not blocked(player_pos()): return
	var original = player_pos()
	for radius in range(12,240,12):
		for i in range(16):
			var p = original + Vector2.RIGHT.rotated(TAU*i/16)*radius
			if not blocked(p): set_pos(p); return

func placement_position() -> Vector2:
	return (player_pos() + aim * 53).snapped(Vector2(16,16))

func valid_placement(p: Vector2) -> bool:
	if p.distance_to(player_pos())<28: return false
	for offset in [Vector2(-16,-16),Vector2(16,16),Vector2(-16,16),Vector2(16,-16)]:
		if blocked(p + offset): return false
	return true

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE: hud.close_panel() if world.paused else hud.open_panel("pause")
	if world.paused: return
	match event.keycode:
		KEY_E: interact()
		KEY_R: reload_request()
		KEY_B, KEY_TAB: hud.open_panel("bag")
		KEY_M: hud.open_panel("map")
		KEY_1: world.state.weapon = "knife"
		KEY_2: cycle_weapon("sidearm")
		KEY_3: cycle_weapon("primary")
		KEY_Q: world.use_item("bandage")



func mechanic_actions() -> Array:
	return exploration_actions()+Survival.actions(world)+Tactics.actions(self)

func mechanic_summary() -> String:
	var result=Survival.summary(world)
	for event in Survival.event_markers(world):
		result+="\n%s：公路(%d,%d)，剩余%d分钟" % ["补给空投" if event.type=="supply" else "幸存者求救",event.x,event.y,maxi(0,int(event.expires-world.state.minute))]
	return result

func request_mechanic(request: Dictionary, duration: float = 1.0):
	if request.get("kind","")=="npc_order":
		request={"kind":"tac_order","id":request.get("npc",""),"order":request.get("order","follow")}
	if duration<=0:
		var ok=complete_exploration_action(request) if str(request.kind).begins_with("ex_") else (Survival.complete(world,request) if str(request.kind).begins_with("sys_") else Tactics.complete(self,request))
		if ok: world.save_game()
		else: world.note("操作未完成：请靠近目标并检查材料。")
		hud.open_panel("mechanics"); return
	start_action(request,duration)



func exploration_actions() -> Array:
	var out: Array=[]
	for exit in world.exits():
		if player_pos().distance_to(Vector2(exit.x,exit.y))<=100:
			out.append({"label":exit.name+"（步行15分钟）","request":{"kind":"ex_travel","target_id":exit.target_id},"duration":2.0})
	var bed=world.near_bed()
	if not bed.is_empty():
		out.append({"label":"登记此床位为落脚点","request":{"kind":"ex_register","bed_id":bed.id},"duration":1.0})
	for furniture in world.furniture:
		if not furniture.packed and furniture.hp>0 and player_pos().distance_to(Vector2(furniture.x,furniture.y))<=65:
			out.append({"label":"打包空柜子（保留同一实例）","request":{"kind":"pack","id":furniture.id,"pos":Vector2(furniture.x,furniture.y)},"duration":2.0})
	return out

func complete_exploration_action(request: Dictionary) -> bool:
	match request.get("kind",""):
		"ex_travel": return travel_request(request.get("target_id",""))
		"ex_register": return world.register_shelter(request.get("bed_id",""))
	return false
