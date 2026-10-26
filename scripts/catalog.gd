extends RefCounted

const GUNS = ["pistol","rifle","pm","colt","magnum","mp5","ump","bizon","ak74","m4","aug","sks","mosin","svd","shotgun","izh"]
const RIFLES = ["rifle","ak74","m4","aug","sks","svd"]
const AUTOMATICS = ["rifle","ak74","m4","aug","mp5","ump","bizon"]
const PARTS = ["suppressor","rifle_suppressor","muzzle_brake","compensator","extended_mag","quick_mag","drum_mag","red_dot","scope2x","scope4x","vertical_grip","angled_grip","weapon_light","tactical_stock"]
const SLOTS = {"muzzle":"枪口","optic":"瞄具","mag":"弹匣","underbarrel":"下挂","stock":"枪托"}
const GUN_ART = {
	"pistol":["pistol/glock.png",28],"rifle":["main/akm.png",5],"pm":["pistol/pm.png",27],"colt":["pistol/kolt_1911.png",29],"magnum":["pistol/magnum.png",30],
	"mp5":["main/mp5k.png",8],"ump":["main/ump-45.png",9],"bizon":["main/bizon.png",10],"ak74":["main/ak-74.png",6],"m4":["main/m4_carbine.png",11],"aug":["main/aug.png",12],
	"sks":["main/sks.png",3],"mosin":["main/mosin.png",1],"svd":["main/svd.png",18],"shotgun":["main/remington_870.png",15],"izh":["main/izh-43.png",0]
}

static func definitions() -> Dictionary:
	var result: Dictionary = {}
	# id, display, cartridge, capacity, damage, interval, range, weight, reload, spread
	var rows = [
		["pistol","Glock 17 手枪","ammo9",12,34,0.30,340,1.2,1.8,0.045],
		["rifle","AKM 突击步枪","ammo_rifle",24,48,0.15,480,3.0,2.7,0.055],
		["pm","PM 马卡洛夫","ammo_makarov",8,28,0.34,270,0.75,1.7,0.055],
		["colt","Colt M1911","ammo45",7,46,0.33,325,1.1,1.9,0.05],
		["magnum","Magnum 左轮","ammo357",6,78,0.62,400,1.4,3.2,0.045],
		["mp5","MP5K 冲锋枪","ammo9",30,27,0.10,320,2.1,2.2,0.06],
		["ump","UMP45 冲锋枪","ammo45",25,39,0.13,360,2.5,2.5,0.055],
		["bizon","PP19 野牛","ammo_makarov",64,24,0.09,310,2.8,3.5,0.075],
		["ak74","AK74 突击步枪","ammo545",30,41,0.11,490,3.2,2.6,0.05],
		["m4","M4 卡宾枪","ammo556",30,40,0.10,520,2.9,2.5,0.04],
		["aug","AUG 突击步枪","ammo556",30,44,0.12,560,3.5,2.8,0.035],
		["sks","SKS 半自动步枪","ammo_rifle",10,66,0.43,580,3.8,3.0,0.032],
		["mosin","Mosin 纳甘步枪","ammo76254",5,115,1.15,760,4.0,3.7,0.018],
		["svd","SVD 精确射手步枪","ammo76254",10,96,0.65,730,4.3,3.0,0.025],
		["shotgun","Remington 870","ammo12",6,19,0.85,255,3.6,3.4,0.18],
		["izh","IZH43 双管霰弹枪","ammo12",2,23,0.65,235,3.3,2.6,0.22]
	]
	for row in rows:
		var id: String = row[0]
		var interfaces: Array = ["optic_rail","stock"]
		if id in ["pistol","mp5"]: interfaces.append("muzzle_9")
		if id in RIFLES or id == "mosin": interfaces.append("muzzle_rifle")
		if id in AUTOMATICS: interfaces.append("grip")
		if id not in ["mosin","izh","shotgun","magnum","sks"]: interfaces.append("magazine")
		result[id] = {"name":row[1],"ammo":row[2],"capacity":row[3],"damage":row[4],"cooldown":row[5],"range":float(row[6]),"weight":row[7],"reload":row[8],"spread":row[9],"interfaces":interfaces,"color":"a6b5a2","noise":480.0,"pellets":7 if id in ["shotgun","izh"] else 1}
	var ammo = [["ammo_makarov","9×18mm 子弹",0.011],["ammo45",".45 ACP 子弹",0.02],["ammo357",".357 Magnum 子弹",0.022],["ammo545","5.45×39mm 子弹",0.018],["ammo556","5.56×45mm 子弹",0.02],["ammo76254","7.62×54R 子弹",0.027],["ammo12","12号霰弹",0.045]]
	for row in ammo: result[row[0]] = {"name":row[1],"weight":row[2],"color":"d8b572"}
	var all_mag = ["pistol","rifle","pm","colt","mp5","ump","bizon","ak74","m4","aug","svd"]
	result["suppressor"] = part("9mm 消音器",0.3,"muzzle","muzzle_9",["pistol","mp5"],{"noise":0.34,"range":0.95})
	result["rifle_suppressor"] = part("步枪消音器",0.5,"muzzle","muzzle_rifle",RIFLES + ["mosin"],{"noise":0.4,"range":0.96})
	result["muzzle_brake"] = part("步枪制退器",0.2,"muzzle","muzzle_rifle",RIFLES + ["mosin"],{"spread":0.72,"noise":1.15})
	result["compensator"] = part("枪口补偿器",0.18,"muzzle","muzzle_9",["pistol","mp5"],{"spread":0.75})
	result["extended_mag"] = part("扩容弹匣",0.25,"mag","magazine",all_mag,{"capacity_add":6,"reload":1.08})
	result["quick_mag"] = part("快速弹匣",0.22,"mag","magazine",all_mag,{"reload":0.72})
	result["drum_mag"] = part("大容量弹鼓",0.9,"mag","magazine",AUTOMATICS,{"capacity_add":24,"reload":1.32,"spread":1.08})
	result["red_dot"] = part("红点瞄准镜",0.15,"optic","optic_rail",GUNS,{"spread":0.8,"focus":1.25})
	result["scope2x"] = part("2倍瞄准镜",0.25,"optic","optic_rail",RIFLES + ["mosin","mp5","ump"],{"range":1.18,"spread":0.7,"focus":0.95})
	result["scope4x"] = part("4倍瞄准镜",0.4,"optic","optic_rail",RIFLES + ["mosin"],{"range":1.4,"spread":0.5,"focus":0.7})
	result["vertical_grip"] = part("垂直握把",0.18,"underbarrel","grip",AUTOMATICS,{"spread":0.73})
	result["angled_grip"] = part("斜角握把",0.16,"underbarrel","grip",AUTOMATICS,{"spread":0.88,"focus":1.35})
	result["weapon_light"] = part("战术枪灯",0.2,"underbarrel","grip",AUTOMATICS,{"light":true})
	result["tactical_stock"] = part("稳定枪托",0.4,"stock","stock",GUNS,{"spread":0.82,"focus":1.15})
	return result

static func part(label: String, mass: float, slot: String, interface: String, compatible: Array, effects: Dictionary) -> Dictionary:
	return {"name":label,"weight":mass,"slot":slot,"interface":interface,"compatible":compatible,"effects":effects,"color":"9bab8d"}
