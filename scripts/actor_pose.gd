extends RefCounted
# Frame order taken from Mini player.tscn Animation resources, not guessed from columns.
static func facing(direction:Vector2)->int:
	if absf(direction.x)>absf(direction.y): return 2 if direction.x>0 else 3
	return 0 if direction.y>=0 else 1
static func frame(direction:Vector2,kind:String,walking:bool,step:int,armed:bool=false)->int:
	var d=facing(direction)
	if kind in ["normal","fast","breaker"]: return d*4+posmod(step,4) if walking else d*4
	if walking: return (d+1)*4+posmod(step,4)
	return [29,28,31,30][d] if armed else [0,1,2,3][d]
static func gun_length(weapon:String)->float:
	return 23.0 if weapon in ["pistol","pm","colt","magnum"] else 33.0
static func grip(pos:Vector2)->Vector2: return pos+Vector2(0,-12)
static func muzzle(pos:Vector2,direction:Vector2,weapon:String)->Vector2:
	return grip(pos)+direction.normalized()*(gun_length(weapon)+2)
