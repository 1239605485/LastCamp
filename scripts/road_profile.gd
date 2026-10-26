extends RefCounted

const BAND_ASPHALT = 0
const BAND_CURB = 1
const BAND_SIDEWALK = 2
const BAND_DIRT = 3
const BAND_GRASS = 4

static func band(distance: float, forest: bool = false) -> int:
	if forest:
		return BAND_DIRT if distance < 68.0 else BAND_GRASS
	if distance < 42.0: return BAND_ASPHALT
	if distance < 48.0: return BAND_CURB
	if distance < 64.0: return BAND_SIDEWALK
	if distance < 88.0: return BAND_DIRT
	return BAND_GRASS
