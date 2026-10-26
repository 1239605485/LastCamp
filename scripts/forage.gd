extends RefCounted

# Values contain only JSON-safe numbers, so saving during a cooldown is lossless.
const DEFINITIONS = {
	"berry":{"name":"野莓丛","qty":2,"regen_minutes":2880,"duration":2},
	"apple":{"name":"苹果树","qty":3,"regen_minutes":4320,"duration":3},
	"tomato":{"name":"野番茄","qty":2,"regen_minutes":2880,"duration":2},
	"squash":{"name":"西葫芦藤","qty":3,"regen_minutes":4320,"duration":3}}

static func definition(kind: String) -> Dictionary:
	return DEFINITIONS.get(kind,{}).duplicate()

static func ready(harvests: Dictionary,id: String,minute: int) -> bool:
	return remaining_minutes(harvests,id,minute) == 0

static func remaining_minutes(harvests: Dictionary,id: String,minute: int) -> int:
	if not harvests.has(id): return 0
	return maxi(0,int(harvests[id])-minute)

# Call only after the timed action finishes. Records availability before returning
# the yield, so a second completion or a reload cannot repeat the same harvest.
static func commit(harvests: Dictionary,id: String,kind: String,minute: int) -> int:
	if not DEFINITIONS.has(kind) or not ready(harvests,id,minute): return 0
	var data: Dictionary = DEFINITIONS[kind]
	harvests[id] = minute + int(data.regen_minutes)
	return int(data.qty)
