extends SceneTree

func vector(line: String, name: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var re = RegEx.new(); re.compile("(?m)^" + name + " = Vector2\\(([^,]+), ([^)]+)\\)")
	var hit = re.search(line)
	return Vector2(float(hit.get_string(1)),float(hit.get_string(2))) if hit else fallback

func _initialize():
	var result: Dictionary = {}
	for name in ["city_house_1","city_house_2","hospital","police_station","gunshop"]:
		var text = FileAccess.get_file_as_string("res://builds/source-" + name + ".tscn")
		var re = RegEx.new(); re.compile("(?s)\\[node ([^\\]]+)\\]\\r?\\n(.*?)(?=\\r?\\n\\[|\\z)")
		var blocks = re.search_all(text); var offset = Vector2.ZERO; var inside_pos = Vector2.ZERO; var outside = Vector2.ZERO
		var polygons: Array = []; var rectangles: Array = []; var door = Vector2(-1,-1); var interior = Rect2()
		var shapes: Dictionary = {}; var shape_re = RegEx.new(); shape_re.compile('(?s)\\[sub_resource type="RectangleShape2D" id="([^"]+)"\\]\\s*(.*?)(?=\\n\\[|\\z)')
		for shape in shape_re.search_all(text): shapes[shape.get_string(1)] = vector(shape.get_string(2),"size")
		for block in blocks:
			var h = block.get_string(1); var body = block.get_string(2)
			if h.begins_with('name="Inside" '): offset = vector(body,"offset"); inside_pos = vector(body,"position")
			if h.begins_with('name="Outside" '): outside = vector(body,"position") + vector(body,"offset")
		for block in blocks:
			var h = block.get_string(1); var body = block.get_string(2)
			if 'parent="Inside/StaticBody2D"' in h and "polygon = PackedVector2Array(" in body:
				var start = body.find("PackedVector2Array(") + 19; var end = body.find(")",start); var numbers = body.substr(start,end - start).split(",")
				var points: Array = []; var origin = vector(body,"position") - offset
				for i in range(0,numbers.size(),2): points.append([float(numbers[i])+origin.x,float(numbers[i+1])+origin.y])
				polygons.append(points)
			if 'name="Door" parent="."' in h: door = vector(body,"position") - inside_pos - offset
			if 'parent="Inside/' in h and 'shape = SubResource("' in body:
				var key = body.get_slice('SubResource("',1).get_slice('"',0)
				if not shapes.has(key): continue
				var size: Vector2 = shapes[key]; var pos = vector(body,"position") - offset - size / 2
				if 'parent="Inside/InteriorArea"' in h: interior = Rect2(pos,size)
				elif 'parent="Inside/StaticBody2D"' in h: rectangles.append([pos.x,pos.y,size.x,size.y])
		var texture_name = "b_" + name
		var image = Image.load_from_file("res://assets/minidayz/building/" + texture_name + "_int-sheet0.png")
		if door.x < 0: door = Vector2(image.get_width() * 0.5,image.get_height() - 4)
		if name == "gunshop": door = Vector2(100,122)
		result[texture_name] = {"size":[image.get_width(),image.get_height()],"ceiling":maxf(0,-offset.y - 7),"polygons":polygons,"rectangles":rectangles,"door":[door.x,door.y],"inside":[interior.position.x,interior.position.y,interior.size.x,interior.size.y],"outside_offset":[outside.x - inside_pos.x - offset.x,outside.y - inside_pos.y - offset.y]}
	var file = FileAccess.open("res://assets/minidayz/building_geometry.json",FileAccess.WRITE); file.store_string(JSON.stringify(result)); file.close()
	print("Extracted Mini collision polygons and sprite offsets for five building types"); quit()
