extends RefCounted

# All Alone/Gun.cs inspired burst spread and recovery, adapted for 2D radians.
# This is transient shot handling, never ammunition or persistent gun ownership.
const MAX_SPREAD = 0.22
const RECOVERY_PER_SECOND = 0.18

static func after_shot(heat: float,base_spread: float) -> float:
	return minf(MAX_SPREAD,maxf(0,heat)+clampf(base_spread*0.45,0.012,0.05))

static func cool(heat: float,seconds: float) -> float:
	return maxf(0,heat-maxf(0,seconds)*RECOVERY_PER_SECOND)
