extends SceneTree
const Road = preload("res://scripts/road_profile.gd")
var failures = 0
func expect(ok: bool, message: String):
	if not ok: failures += 1; printerr("FAIL: " + message)
func _initialize():
	expect(Road.band(0.0)==Road.BAND_ASPHALT,"road center is asphalt")
	expect(Road.band(40.0)==Road.BAND_ASPHALT,"wide asphalt lanes reach the street edge")
	expect(Road.band(44.0)==Road.BAND_CURB,"road edge has a distinct curb")
	expect(Road.band(52.0)==Road.BAND_SIDEWALK,"road includes a pedestrian shoulder")
	expect(Road.band(72.0)==Road.BAND_DIRT,"sidewalk blends into a dirt verge")
	expect(Road.band(100.0)==Road.BAND_GRASS,"far ground stays grass")
	expect(Road.band(55.0,true)==Road.BAND_DIRT,"forest paths have no paved curb")
	print("ROAD_PROFILE failures: ",failures)
	quit(1 if failures else 0)
