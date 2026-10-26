extends RefCounted
# Shared collision, cutaway, door and furniture geometry in world pixels.
static var loot_cache: Dictionary = {}
static func definition(b: Dictionary) -> Dictionary:
	return {"size":[b.rect.size.x-20,b.rect.size.y-20],"door":[(b.rect.size.x-20)/2,b.rect.size.y-28]}
static func frame(b: Dictionary) -> Rect2:
	return b.rect.grow(-10)
static func interior(b: Dictionary) -> Rect2:
	return frame(b).grow(-12)
static func door(b: Dictionary) -> Rect2:
	var f=frame(b)
	return Rect2(f.get_center().x-22,f.end.y-12,44,12)
static func rectangles(b: Dictionary) -> Array:
	var f=frame(b); var d=door(b)
	return [Rect2(f.position,Vector2(f.size.x,10)),Rect2(f.position,Vector2(10,f.size.y)),Rect2(f.end.x-10,f.position.y,10,f.size.y),Rect2(f.position.x,f.end.y-10,d.position.x-f.position.x,10),Rect2(d.end.x,f.end.y-10,f.end.x-d.end.x,10)]
static func polygons(_b: Dictionary) -> Array:
	return []
static func point(b: Dictionary,pixel: Vector2) -> Vector2:
	return frame(b).position+pixel
static func outside_frame(b: Dictionary,_texture_size: Vector2) -> Rect2:
	return frame(b)
static func solid_at(b: Dictionary,pos: Vector2,radius: float=4) -> bool:
	for rect in rectangles(b):
		if rect.grow(radius).has_point(pos): return true
	return false
static func loot_point(b: Dictionary) -> Vector2:
	return interior(b).end-Vector2(40,35)
static func bed_point(b: Dictionary) -> Vector2:
	return interior(b).position+Vector2(35,50)
