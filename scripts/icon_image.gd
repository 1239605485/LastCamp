extends RefCounted
static func strip_outline(source:Image)->Image:
	var image=source.duplicate(); image.decompress(); image.convert(Image.FORMAT_RGBA8)
	var original=image.duplicate()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c=original.get_pixel(x,y)
			if c.a<0.01 or minf(c.r,minf(c.g,c.b))<0.89 or maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b))>0.10: continue
			var edge=false
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var p=Vector2i(x,y)+delta
				if p.x<0 or p.y<0 or p.x>=image.get_width() or p.y>=image.get_height() or original.get_pixelv(p).a<0.05: edge=true; break
			if edge: image.set_pixel(x,y,Color.TRANSPARENT)
	# Tiny rolls and thin parts can consist almost entirely of their outline.
	# Keep their silhouette in muted grey rather than collapsing to a 1px strip.
	var used = image.get_used_rect()
	if used.size.x < 3 or used.size.y < 3:
		for y in range(original.get_height()):
			for x in range(original.get_width()):
				if original.get_pixel(x,y).a > 0.05 and image.get_pixel(x,y).a < 0.05:
					image.set_pixel(x,y,Color(0.48,0.51,0.43,original.get_pixel(x,y).a))
	return image
static func texture(source:Texture2D)->Texture2D:
	var image=strip_outline(source.get_image())
	var used=image.get_used_rect()
	if used.has_area(): image=image.get_region(used)
	return ImageTexture.create_from_image(image)
