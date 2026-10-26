@tool
extends SceneTree
func _initialize(): call_deferred("configure")
func configure():
	while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	var settings=EditorInterface.get_editor_settings()
	var sdk=OS.get_environment("ANDROID_HOME")
	var java=OS.get_environment("JAVA_HOME")
	if not sdk.is_empty(): settings.set_setting("export/android/android_sdk_path",sdk)
	if not java.is_empty(): settings.set_setting("export/android/java_sdk_path",java)
	print("Uses ANDROID_HOME and JAVA_HOME when configured. Otherwise set SDK paths in Godot Editor Settings.")
	quit()
