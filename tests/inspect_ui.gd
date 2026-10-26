extends SceneTree
func _initialize():
	var im=load("res://assets/minidayz/gui/control/gui_btn_interact-sheet0.png").get_image(); var seen={}; var parts=[]
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			var p=Vector2i(x,y)
			if seen.has(p) or im.get_pixelv(p).a<0.05: continue
			var queue=[p]; seen[p]=true; var rect=Rect2i(p,Vector2i.ONE); var count=0
			while not queue.is_empty():
				var at=queue.pop_back(); count+=1; rect=rect.expand(at)
				for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var n=at+d
					if n.x<0 or n.y<0 or n.x>=im.get_width() or n.y>=im.get_height() or seen.has(n) or im.get_pixelv(n).a<0.05: continue
					seen[n]=true; queue.append(n)
			if count>10: parts.append({"rect":rect,"count":count})
	parts.sort_custom(func(a,b):return a.count>b.count); print(parts); quit()
