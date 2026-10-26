extends SceneTree
func _initialize():
	var aspect=ProjectSettings.get_setting("display/window/stretch/aspect","keep")
	if aspect!="expand": printerr("FAIL: widescreen must expand rather than letterbox"); quit(1); return
	print("PROJECT DISPLAY V05 RESULT: expand configured"); quit()
