extends SceneTree

const C = preload("res://scripts/catalog.gd")
const ROOT = "res://assets/minidayz/"

func _initialize():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT + "icons"))
	var primary = Image.load_from_file(ROOT + "equipment/weapon/main/gui_main_weapon.png")
	var pistols = Image.load_from_file(ROOT + "equipment/weapon/pistol/gui_pistol.png")
	var ids = {"pistol":28,"rifle":3,"pm":32,"colt":26,"magnum":30,"mp5":14,"ump":23,"bizon":6,"ak74":2,"m4":11,"aug":5,"sks":19,"mosin":13,"svd":22,"shotgun":15,"izh":7}
	for id in ids:
		var index: int = ids[id]; var image: Image
		if index >= 25:
			index -= 25
			image = pistols.get_region(Rect2i((index % 4) * 82,(index / 4) * 82,82,82))
		else:
			image = primary.get_region(Rect2i((index % 5) * 68,(index / 5) * 185,68,185))
			image.rotate_90(CLOCKWISE)
		var used = image.get_used_rect()
		if used.has_area(): image = image.get_region(used)
		image.save_png(ROOT + "icons/" + id + ".png")
	var parts = Image.load_from_file(ROOT + "equipment/weapon/main/gui_firearm_device.png")
	for id in C.PARTS:
		var definition = C.definitions()[id]
		var rect = {"muzzle":Rect2i(0,0,28,66),"optic":Rect2i(56,0,56,66),"mag":Rect2i(56,76,28,42),"underbarrel":Rect2i(112,76,28,42),"stock":Rect2i(140,76,28,42)}[definition.slot]
		var image = parts.get_region(rect); var used = image.get_used_rect()
		if used.has_area(): image = image.get_region(used)
		image.save_png(ROOT + "icons/" + id + ".png")
	print("Extracted 16 weapon icons and 14 attachment icons from user-supplied Mini atlases")
	quit()
