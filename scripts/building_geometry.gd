extends RefCounted

static var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/minidayz/building_geometry.json"))
static var loot_cache: Dictionary = {}

static func definition(b: Dictionary) -> Dictionary:
	return definitions[b.get("art","b_city_house_1")]

static func frame(b: Dictionary) -> Rect2:
	var d = definition(b); var scale = (b.rect.size.x - 20) / float(d.size[0]); var size = Vector2(d.size[0],d.size[1]) * scale
	return Rect2(Vector2(b.rect.position.x + 10,b.rect.end.y - 10 - size.y),size)

static func point(b: Dictionary, pixel: Vector2) -> Vector2:
	var f = frame(b); return f.position + pixel * (f.size.x / float(definition(b).size[0]))

static func polygons(b: Dictionary) -> Array:
	var result: Array = []
	for raw in definition(b).polygons:
		var polygon = PackedVector2Array()
		for p in raw: polygon.append(point(b,Vector2(p[0],p[1])))
		result.append(polygon)
	return result

static func rectangles(b: Dictionary) -> Array:
	var d = definition(b); var f = frame(b); var scale = f.size.x / float(d.size[0]); var result: Array = []
	result.append(Rect2(f.position,Vector2(f.size.x,d.ceiling * scale)))
	for raw in d.rectangles: result.append(Rect2(point(b,Vector2(raw[0],raw[1])),Vector2(raw[2],raw[3]) * scale))
	# Sprite border strips belong to the wall, not walkable floor.
	result.append(Rect2(f.position,Vector2(4 * scale,f.size.y)))
	result.append(Rect2(Vector2(f.end.x-4*scale,f.position.y),Vector2(4*scale,f.size.y)))
	return result

static func door(b: Dictionary) -> Rect2:
	var d = definition(b); var p = point(b,Vector2(d.door[0],d.door[1])); var width = 28.0
	if b.get("kind","") == "clinic": width = 62
	return Rect2(p - Vector2(width/2,5),Vector2(width,10))

static func interior(b: Dictionary) -> Rect2:
	var d = definition(b); var f = frame(b); var v = d.inside
	return Rect2(point(b,Vector2(v[0],v[1])),Vector2(v[2],v[3]) * (f.size.x / float(d.size[0])))

static func outside_frame(b: Dictionary, texture_size: Vector2) -> Rect2:
	var d = definition(b); var scale = frame(b).size.x / float(d.size[0]); return Rect2(point(b,Vector2(d.outside_offset[0],d.outside_offset[1])),texture_size * scale)

static func solid_at(b: Dictionary, pos: Vector2, radius: float = 4) -> bool:
	for rect in rectangles(b):
		if rect.grow(radius).has_point(pos): return true
	for polygon in polygons(b):
		for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
			if Geometry2D.is_point_in_polygon(pos + offset,polygon): return true
	return false

static func loot_point(b: Dictionary) -> Vector2:
	var key = hash([b.rect,b.get("art","b_city_house_1")])
	if loot_cache.has(key): return loot_cache[key]
	if loot_cache.size() > 1024: loot_cache.clear()
	# Choose reachable floor, rather than a decorative wall or staircase pixel.
	for sy in range(8,-1,-1):
		for sx in range(2,9):
			var candidate = interior(b).position + interior(b).size * Vector2(sx/10.0,sy/10.0)
			if not solid_at(b,candidate,9): loot_cache[key] = candidate; return candidate
	var fallback = door(b).get_center() - Vector2(0,18); loot_cache[key] = fallback; return fallback
