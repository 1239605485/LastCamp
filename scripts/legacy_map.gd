extends RefCounted

const SECTOR = Vector2(1280,1120)
const GRID = 8
var size = SECTOR * GRID
var buildings: Array = []
var sectors: Array = []
var seed = 471113

func _init():
	buildings = [
		{"name":"榆树街民居","rect":Rect2(210,170,290,250),"container":"house","kind":"house","art":"b_city_house_1"},
		{"name":"社区诊所","rect":Rect2(720,150,290,250),"container":"clinic","kind":"clinic","art":"b_hospital"},
		{"name":"警务站","rect":Rect2(480,610,330,260),"container":"police","kind":"police","art":"b_police_station"}
	]
	var names = ["榆树镇","石桥村","旧工业区","东林地","河湾营区","南部住宅","北站聚落","荒野农舍"]
	for y in range(GRID):
		for x in range(GRID):
			var index = x + y * GRID
			var kind = ["village","forest","industrial","village","military","farm","city","forest"][posmod(x * 3 + y * 5,8)]
			sectors.append({"id":"%d_%d" % [x,y],"name":names[posmod(x + y * 3,8)] + " %02d" % (index + 1),"kind":kind,"rect":Rect2(Vector2(x,y) * SECTOR,SECTOR)})
			if index == 0: continue
			for i in range(2):
				var building_kind = ["house","clinic","police","shop"][posmod(index + i * 2,4)]
				var art = {"house":"b_city_house_2","clinic":"b_hospital","police":"b_police_station","shop":"b_gunshop"}[building_kind]
				var offset = Vector2(190,170) if i == 0 else Vector2(750,650)
				buildings.append({"name":sectors.back().name + " · " + {"house":"民居","clinic":"医疗站","police":"警务点","shop":"武器铺"}[building_kind],"rect":Rect2(Vector2(x,y) * SECTOR + offset,Vector2(280,230)),"container":"site_%d_%d_%d" % [x,y,i],"kind":building_kind,"art":art})

func buildings_at(pos: Vector2, radius: float = 1200) -> Array:
	var area = Rect2(pos - Vector2.ONE * radius,Vector2.ONE * radius * 2)
	return buildings.filter(func(b): return b.rect.intersects(area))

func sector_id(pos: Vector2) -> String:
	return "%d_%d" % [clampi(int(pos.x / SECTOR.x),0,GRID - 1),clampi(int(pos.y / SECTOR.y),0,GRID - 1)]

func region_name(pos: Vector2) -> String:
	return sectors[clampi(int(pos.x / SECTOR.x),0,GRID - 1) + clampi(int(pos.y / SECTOR.y),0,GRID - 1) * GRID].name

func road_at(pos: Vector2) -> bool:
	return absf(fposmod(pos.x,SECTOR.x) - 610) < 48 or absf(fposmod(pos.y,SECTOR.y) - 490) < 48

func water_at(pos: Vector2) -> bool:
	return absf(pos.x - 5050) < 65 and absf(fposmod(pos.y,SECTOR.y) - 490) > 72

func container_pos(id: String) -> Vector2:
	for b in buildings:
		if b.container == id:
			if id == "house": return Vector2(265,350)
			if id == "clinic": return Vector2(945,330)
			if id == "police": return Vector2(740,780)
			return b.rect.end - Vector2(58,55)
	return Vector2(-999,-999)
