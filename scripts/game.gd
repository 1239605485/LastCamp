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
const Navigation = preload("res://scripts/local_navigation.gd")
var world = World.new()
var view
var hud
var camera: Camera2D
var aim = Vector2.RIGHT
var moving = false
var action: Dictionary = {}
var shot_cd = 0.0
var guard_cd = 0.0
var autosave = 0.0
var transition_cd = 0.0
var last_damage = 0.0
var sound
var last_wave_day = 0
var placement: Dictionary = {}
var solid_cache: Array = []
var solid_cache_key = 0
var polygon_cache: Array = []
var focus = 0.0
var combat_state = "idle"
var random = RandomNumberGenerator.new()
var world_zoom = 1.0
var walk_direction = Vector2.DOWN

func set_world_zoom(value: float):
	world_zoom = clampf(value,0.65,1.8)
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
	if world.state.failed: hud.open_panel("failure")
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
	hud.refresh()
	camera.position = player_pos() + Vector2(0,-40)
	view.queue_redraw()
	if world.paused or world.state.failed: return
	world.tick(delta)
	if world.state.wave_day > last_wave_day:
		last_wave_day = world.state.wave_day; sound.play("alarm")
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
	if hud.fire_held or mouse_shoot or Input.is_physical_key_pressed(KEY_SPACE): fire()
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
	world.finish_wave()
	if world.state.has("battle_report") and not world.state.get("report_seen",true):
		world.state.report_seen = true; world.save_game(); hud.open_panel("battle")
	if world.state.hp <= 0:
		action.clear(); world.die(); world.save_game()
	if world.state.core <= 0 or world.state.failed:
		world.state.failed = true; action.clear(); world.save_game(); hud.open_panel("failure")
	if transition_cd <= 0:
		if world.state.zone == "camp" and player_pos().x > 1210: change_zone("town", Vector2(95, 490))
		elif world.state.zone == "town" and player_pos().x < 65 and absf(player_pos().y - 490) < 100: change_zone("camp", Vector2(1160, 490))
	if autosave > 20:
		world.save_game(); autosave = 0

func change_zone(zone: String, pos: Vector2):
	action.clear(); world.state.zone = zone; set_pos(pos); transition_cd = 2
	for n in world.npcs:
		if n.follow and n.status != "down": n.zone = zone; n.x = pos.x + 25; n.y = pos.y + 20
	world.save_game()
	world.note("进入榆树镇。建筑前后门可进入；物资不会因离开刷新。" if zone == "town" else "返回营地。北墙与守卫已按统一时间结算。")

func building_walls(b: Dictionary) -> Array:
	return Geometry.rectangles(b)

func door_rect(b: Dictionary, side: int) -> Rect2:
	return Geometry.door(b) if side == 0 else Rect2(-99999,-99999,1,1)

func solids() -> Array:
	var chunk = Vector2i(player_pos() / 600)
	var key = hash([world.map.seed,world.state.zone,world.doors,world.furniture,world.state.wall > 0,chunk,world.defenses,world.state.get("tactics_v5",{})])
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
	else:
		result.append(Rect2(300, 290, 150, 88))
		if world.state.wall > 0: result.append(Rect2(255, 250, 395, 21))
	for f in world.furniture:
		if not f.packed and f.hp > 0 and f.zone == world.state.zone: result.append(Rect2(f.x - 16, f.y - 16, 32, 28))
	for car in world.map.cars_at(player_pos(),2100,world.state.zone): result.append(car.body)
	for tree in world.map.trees_at(player_pos(),2100,world.state.zone): result.append(tree.trunk)
	for plant in world.map.plants_at(player_pos(),2100,world.state.zone):
		if plant.kind == "apple": result.append(Rect2(plant.pos-Vector2(6,4),Vector2(12,8)))
	result.append_array(Tactics.solids(self))
	if world.state.zone == "camp":
		for defense in world.defenses:
			if defense.hp > 0 and defense.kind != "wire": result.append(defense_rect(defense))
	solid_cache_key = key; solid_cache = result
	return result

func blocked(pos: Vector2) -> bool:
	var limit: Vector2 = world.map.size if world.state.zone == "town" else Vector2(1300,1090)
	if pos.x < 40 or pos.x > limit.x - 40 or pos.y < 20 or pos.y > limit.y - 40: return true
	if world.state.zone == "town" and world.map.water_at(pos): return true
	for rect in solids():
		if rect.grow(4.5).has_point(pos): return true
	for entry in polygon_cache:
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

func visible(a: Vector2, b: Vector2, ignore_low_cover: bool = false) -> bool:
	for rect in solids():
		if ignore_low_cover and world.state.zone=="camp" and rect==Rect2(255,250,395,21): continue
		if Geometry2D.segment_intersects_segment(a,b,rect.position,Vector2(rect.end.x,rect.position.y)) != null: return false
		if Geometry2D.segment_intersects_segment(a,b,Vector2(rect.end.x,rect.position.y),rect.end) != null: return false
		if Geometry2D.segment_intersects_segment(a,b,rect.end,Vector2(rect.position.x,rect.end.y)) != null: return false
		if Geometry2D.segment_intersects_segment(a,b,Vector2(rect.position.x,rect.end.y),rect.position) != null: return false
	for entry in polygon_cache:
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
		spread = d.spread * lerpf(2.6,0.4,focus) * (1.7 if moving else 1.0)
		for enemy in world.enemies:
			if enemy.zone == world.state.zone and Vector2(enemy.x,enemy.y).distance_to(player_pos()) < d.noise:
				enemy.alert = 7; enemy.tx = world.state.px; enemy.ty = world.state.py
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
	if choices.is_empty(): world.note("背包中没有这类枪械，请到军械箱或建筑搜刮。"); return
	var identifiers = choices.map(func(i): return i.id)
	var selected = world.player_weapon(world.state.weapon)
	world.equip(identifiers[(identifiers.find(selected) + 1) % identifiers.size()])
	focus = 0; action.clear()

func update_enemies(delta: float):
	for e in world.enemies:
		if e.zone != world.state.zone or e.hp <= 0: continue
		if e.zone == "town" and Vector2(e.x,e.y).distance_squared_to(player_pos()) > 1250 * 1250: continue
		var p = Vector2(e.x, e.y); e.cd -= delta; e.alert = maxf(0, e.alert - delta)
		var sight = (140.0 if is_night() else 240.0)*Survival.visibility_factor(world)
		e["sense_left"] = e.get("sense_left",0.0) - delta
		if e.sense_left <= 0:
			e.sense_left = 0.3
			if p.distance_to(player_pos()) < sight and visible(p, player_pos()): e.alert = 5; e.tx = world.state.px; e.ty = world.state.py
		if e.alert <= 0 and not e.wave:
			e["wander_left"] = e.get("wander_left",0.0) - delta
			if e.wander_left <= 0 or p.distance_to(Vector2(e.tx,e.ty)) < 9:
				e.wander_left = random.randf_range(3,8)
				var goal = p + Vector2.RIGHT.rotated(random.randf_range(-PI,PI)) * random.randf_range(35,150)
				e.tx = clampf(goal.x,50,world.map.size.x - 50); e.ty = clampf(goal.y,50,world.map.size.y - 50)
		var target = Vector2(e.tx, e.ty)
		if e.wave:
			target = Vector2(clampf(p.x, 270, 625), 260) if world.state.wall > 0 else Vector2(375, 380)
		if e.alert > 0 and (not e.wave or p.distance_to(player_pos()) < 125): target = Vector2(e.tx,e.ty)
		var direction = (target - p).normalized()
		var speed = 92 if e.kind == "fast" else (35 if e.kind == "breaker" else 48)
		if e.alert <= 0 and not e.wave: speed *= 0.3
		if e.get("slow_until",0)>world.state.minute: speed*=0.35
		if e.zone == "camp":
			for defense in world.defenses:
				if defense.hp > 0 and defense.kind == "wire" and defense_rect(defense).grow(10).has_point(p): speed *= 0.35
		var step = direction * speed * delta
		var next = move_with_collision(p, step)
		if next.distance_to(p) < 0.1 and p.distance_to(target) > 35:
			var tangent = Vector2(-direction.y,direction.x) * speed * delta
			next = move_with_collision(p,tangent)
			if next.distance_to(p) < 0.1: next = move_with_collision(p,-tangent)
		e["walking"] = next.distance_to(p)>0.05
		if e.walking: e["facing_x"]=(next-p).normalized().x; e["facing_y"]=(next-p).normalized().y
		e.x = next.x; e.y = next.y
		if e.cd > 0: continue
		if p.distance_to(player_pos()) < 26:
			damage_player(13 if e.kind == "breaker" else 8); e.cd = 1.0
		elif e.wave and world.state.zone == "camp" and world.state.wall > 0 and p.y > 222 and p.y < 280:
			world.state.wall = maxf(0, world.state.wall - (15 if e.kind == "breaker" else 6)); e.cd = 1
		elif e.wave and world.state.zone == "camp" and world.state.wall <= 0 and p.distance_to(Vector2(375,380)) < 125:
			world.state.core -= 7; e.cd = 1
		else:
			for defense in world.defenses:
				if e.zone == "camp" and defense.hp > 0 and p.distance_to(Vector2(defense.x,defense.y)) < 55:
					defense.hp = maxf(0,defense.hp - (15 if e.kind == "breaker" else 7)); e.cd = 1
			for f in world.furniture:
				if f.zone == e.zone and not f.packed and f.hp > 0 and p.distance_to(Vector2(f.x,f.y)) < 38:
					f.hp -= 9; e.cd = 1
			for b in world.map.buildings_at(p,100):
				for side in [0]:
					if e.alert > 0 and Tactics.door_blocked(world,b) and p.distance_to(door_rect(b,side).get_center()) < 40:
						if Tactics.damage_door(world,b.container+str(side),35 if e.kind=="breaker" else 14): world.note("门被撞坏了！")
						e.cd = 2
			if e.cd<=0 and e.alert>0 and world.state.zone=="town":
				for win in Tactics.windows(world,p,100):
					if p.distance_to(win.pos)>40: continue
					if win.state.board_hp>0 or not win.state.broken:
						Tactics.damage_window(world,win.id,30 if e.kind=="breaker" else 12); e.cd=2
					elif (p.y-win.pos.y)*(e.ty-win.pos.y)<0:
						var landing:Vector2=win.inside if e.ty<win.pos.y else win.outside
						var approach:Vector2=win.outside if e.ty<win.pos.y else win.inside
						if p.distance_to(approach)<=26 and not blocked(landing): e.x=landing.x; e.y=landing.y; e.cd=1
	world.enemies = world.enemies.filter(func(e): return e.hp > 0)

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
			if world.state.guard_ammo <= 0: continue
			for e in world.enemies:
				if e.zone == n.zone and Vector2(e.x,e.y).distance_to(Vector2(n.x,n.y)) < 340:
					if not visible(Vector2(n.x,n.y),Vector2(e.x,e.y),true): continue
					e.hp -= 32; world.state.guard_ammo -= 1; n.xp += 1
					view.flashes.append({"a":Vector2(n.x,n.y),"b":Vector2(e.x,e.y),"life":0.1})
					break
	if world.state.zone == "camp" and world.npcs.any(func(n): return n.zone == "camp" and n.job == "守卫" and n.status not in ["down","waiting"] and not n.get("hold_fire",false)):
		for defense in world.defenses:
			if defense.kind != "guardpost" or defense.hp <= 0: continue
			defense.cd -= delta
			if defense.cd > 0 or world.state.guard_ammo <= 0: continue
			for e in world.enemies:
				if e.zone == "camp" and Vector2(e.x,e.y).distance_to(Vector2(defense.x,defense.y)) < 380:
					if not visible(Vector2(defense.x,defense.y),Vector2(e.x,e.y),true): continue
					e.hp -= 30; world.state.guard_ammo -= 1; defense.cd = 1.8
					view.flashes.append({"a":Vector2(defense.x,defense.y),"b":Vector2(e.x,e.y),"life":0.1}); break

func is_night() -> bool:
	var minute = fmod(world.state.minute,1440)
	return minute >= 1200 or minute < 360

func container_pos(id: String) -> Vector2:
	match id:
		"warehouse": return Vector2(573,435)
		"armory": return Vector2(620,380)
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
	if world.state.zone == "camp":
		list.append({"kind":"container","id":"warehouse","pos":container_pos("warehouse"),"name":"仓库"})
		list.append({"kind":"container","id":"armory","pos":container_pos("armory"),"name":"军械补给箱"})
		list.append({"kind":"repair","id":"wall","pos":Vector2(470,290),"name":"修理北墙 · 木材×2"})
	else:
		for b in world.map.buildings_at(player_pos(),200):
			list.append({"kind":"container","id":b.container,"pos":container_pos(b.container),"name":"搜刮" + b.name})
			for side in [0]: list.append({"kind":"door","id":b.container + str(side),"pos":door_rect(b,side).get_center(),"name":"加固房门" if Tactics.door_state(world,b.container+str(side)).board_hp>0 else "开关门"})
	if world.state.zone=="camp":
		list.append({"kind":"mechanics","id":"trader","pos":Vector2(740,420),"name":"中立商人 · 交换物资"})
		list.append({"kind":"mechanics","id":"generator","pos":Vector2(430,440),"name":"发电机与休息"})
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
	if t.is_empty(): world.note("靠近门、物资箱、仓库或待救同伴后互动。"); return
	match t.kind:
		"harvest": start_action({"kind":"harvest","id":t.id,"pos":t.pos},Forage.definition(t.plant_kind).duration)
		"container", "furniture":
			if not world.state.searched.has(t.id): start_action({"kind":"search","id":t.id,"pos":t.pos},2.6)
			else: hud.container_id = t.id; hud.open_panel("loot")
		"door":
			if not Tactics.complete(self,{"kind":"tac_door_toggle","id":t.id}): world.note("门已加固或损坏，请打开生存操作处理。")
		"mechanics": hud.open_panel("mechanics")
		"rescue": start_action({"kind":"rescue","id":t.id,"pos":t.pos},4)
		"repair": start_action({"kind":"repair","id":"wall","pos":t.pos},3)

func start_action(request: Dictionary, duration: float = R.ACTION_SECONDS):
	hud.close_panel()
	action = request.duplicate(true); action["remaining"] = duration; action["duration"] = duration
	action["zone"] = world.state.zone

func complete_action():
	var request = action.duplicate(true); action.clear()
	if request.zone != world.state.zone: return
	if request.has("pos") and (player_pos().distance_to(request.pos) > 85 or not interaction_visible(request.pos)):
		world.note("行动中断：目标不可达。"); return
	var ok = false
	match request.kind:
		"harvest": ok = world.harvest_plant(request.id)
		"search":
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
		"repair":
			var owner = "player" if world.count_item("wood") >= 2 else "warehouse"
			if world.state.zone == "camp" and world.consume("wood",2,owner): world.state.wall = minf(240,world.state.wall + 85); ok = true
		"rescue":
			for n in world.npcs:
				if n.id == request.id and n.status in ["down","waiting"]:
					if n.status == "waiting" or world.consume("bandage",1):
						for other in world.npcs:
							if other.id != n.id and other.follow:
								other.follow = false
								if other.zone != "camp" and other.status != "down": other["retreat_until"] = world.state.minute + 45
						n.status = "injured"; n.hp = 35; n.follow = true; ok = true; world.note(n.name + "加入队伍，请护送回营休养。")
		_:
			if str(request.kind).begins_with("sys_"): ok=Survival.complete(world,request)
			elif str(request.kind).begins_with("tac_"): ok=Tactics.complete(self,request)
	if ok:
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
	if world.state.zone != "camp": world.note("需要在营地内建造城防。"); return
	var pos = (player_pos()+aim*70).snapped(Vector2(16,16))
	if not valid_placement(pos): world.note("此处占用或堵住核心出口，请移开后建造。"); return
	start_action({"kind":"build_defense","defense_kind":kind,"pos":pos},4)

func start_new_game():
	world.save_game(world.save_directory.path_join("previous-world.json"))
	action.clear(); placement.clear(); solid_cache.clear(); polygon_cache.clear()
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
	if world.state.zone == "camp" and p.distance_to(Vector2(375,378)) < 70: return false
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
	return Survival.actions(world)+Tactics.actions(self)

func mechanic_summary() -> String:
	var result=Survival.summary(world)
	for event in Survival.event_markers(world):
		result+="\n%s：公路(%d,%d)，剩余%d分钟" % ["补给空投" if event.type=="supply" else "幸存者求救",event.x,event.y,maxi(0,int(event.expires-world.state.minute))]
	return result

func request_mechanic(request: Dictionary, duration: float = 1.0):
	if world.state.failed: return
	if request.get("kind","")=="npc_order":
		request={"kind":"tac_order","id":request.get("npc",""),"order":request.get("order","follow")}
	if duration<=0:
		var ok=Survival.complete(world,request) if str(request.kind).begins_with("sys_") else Tactics.complete(self,request)
		if ok: world.save_game()
		else: world.note("操作未完成：请靠近目标并检查材料。")
		hud.open_panel("mechanics"); return
	start_action(request,duration)


