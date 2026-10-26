extends SceneTree
func _initialize():
	var root = "res://assets/minidayz/"
	var files = {"food":"canned_bean.png","water":"water_bottle.png","bandage":"bandage.png","wood":"wood_piles.png","parts":"duct_tape.png","ammo9":"9mm_ammo.png","ammo_rifle":"7.62x39_ammo.png","ammo_makarov":"9x18_ammo.png","ammo45":".45_acp_ammo.png","ammo357":".357_ammo.png","ammo545":"5.45x39_ammo.png","ammo556":"5.56x45_ammo.png","ammo76254":"7.62_ammo.png","ammo12":"12cal_ammo.png","backpack":"burlap_sack.png"}
	for id in files:
		var source = Image.load_from_file(root + "item/" + files[id])
		if source == null: continue
		source.save_png(root + "icons/" + id + ".png")
	var source = Image.load_from_file(root + "equipment/weapon/melee/gui_melee.png").get_region(Rect2i(88,0,44,44))
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var c = source.get_pixel(x,y)
			if c.b > 0.7 and c.r < 0.15 and c.g < 0.15: source.set_pixel(x,y,Color.TRANSPARENT)
	source.save_png(root + "icons/knife.png")
	source = Image.load_from_file(root + "equipment/weapon/melee/gui_melee.png").get_region(Rect2i(88,44,44,44))
	for y in range(source.get_height()):
		for x in range(source.get_width()):
			var c = source.get_pixel(x,y)
			if c.b > 0.7 and c.r < 0.15 and c.g < 0.15: source.set_pixel(x,y,Color.TRANSPARENT)
	source.save_png(root + "icons/building_hammer.png")
	Image.load_from_file(root + "building/b_police_station_chest.png").save_png(root + "icons/cabinet.png")
	print("Extracted icon for every basic item and ammunition"); quit()
