extends RefCounted
# Bounded local A*: solves doorways and furniture detours without wall sliding.
static var cache: Dictionary = {}
const CELL = 20.0
const DIRECTIONS = [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

static func clear_line(game, a: Vector2, b: Vector2) -> bool:
	var count = maxi(1,int(ceil(a.distance_to(b)/7)))
	for i in range(1,count+1):
		if game.blocked(a.lerp(b,float(i)/count)): return false
	return true

static func next_step(game, pos: Vector2, target: Vector2, speed: float, delta: float) -> Vector2:
	if delta <= 0 or speed <= 0 or pos.distance_to(target) < 2 or game.blocked(target): return pos
	if clear_line(game,pos,target): return game.move_with_collision(pos,(target-pos).limit_length(speed*delta))
	var start = Vector2i((pos/CELL).round()); var end = Vector2i((target/CELL).round())
	var key = str(game.world.state.zone) + str(start) + str(end)
	var now = Time.get_ticks_msec()
	if cache.size() > 200: cache.clear()
	var waypoint = pos
	if cache.has(key) and now - cache[key].time < 500 and cache[key].solids_key == game.solid_cache_key:
		waypoint = cache[key].waypoint
	else:
		waypoint = search(game,pos,target,start)
		cache[key] = {"time":now,"waypoint":waypoint,"solids_key":game.solid_cache_key}
	if waypoint == pos or not clear_line(game,pos,waypoint): return pos
	return game.move_with_collision(pos,(waypoint-pos).limit_length(speed*delta))

static func search(game, pos: Vector2, target: Vector2, start: Vector2i) -> Vector2:
	# Anchor the lattice at the actor so a narrow doorway need not match the global grid.
	var open: Array = [Vector2i.ZERO]; var costs = {Vector2i.ZERO:0.0}; var parents: Dictionary = {}; var closed: Dictionary = {}
	var best = Vector2i.ZERO; var best_h = pos.distance_to(target)
	for _iteration in range(180):
		if open.is_empty(): break
		var pick = 0; var score = INF
		for i in range(open.size()):
			var candidate: Vector2i = open[i]
			var value: float = costs[candidate] + (pos+Vector2(candidate)*CELL).distance_to(target)
			if value < score: score = value; pick = i
		var current: Vector2i = open.pop_at(pick); closed[current] = true
		var p = pos + Vector2(current)*CELL; var h = p.distance_to(target)
		if h < best_h: best = current; best_h = h
		if h < CELL and clear_line(game,p,target): best = current; break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if closed.has(next) or absi(next.x)>14 or absi(next.y)>14: continue
			var point = pos+Vector2(next)*CELL
			if game.blocked(point) or not clear_line(game,p,point): continue
			var cost: float = costs[current] + CELL
			if not costs.has(next) or cost < costs[next]:
				costs[next] = cost; parents[next] = current
				if next not in open: open.append(next)
	if best == Vector2i.ZERO: return pos
	while parents.has(best) and parents[best] != Vector2i.ZERO: best = parents[best]
	var _unused_start = start
	return pos + Vector2(best)*CELL
