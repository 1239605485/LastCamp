extends RefCounted

const DAY_SECONDS = 1800.0
const SPEED = 145.0
const BAG_WEIGHT = 28.0
const ACTION_SECONDS = 1.2
const Catalog = preload("res://scripts/catalog.gd")
const BASE_ITEMS = {
	"food": {"name":"罐头", "weight":0.5, "color":"d6a154"},
	"berry": {"name":"野莓", "weight":0.12, "color":"716a9d", "nutrition":12, "water_gain":6},
	"apple": {"name":"苹果", "weight":0.2, "color":"b7b352", "nutrition":18, "water_gain":8},
	"tomato": {"name":"番茄", "weight":0.18, "color":"bd6a50", "nutrition":14, "water_gain":10},
	"squash": {"name":"西葫芦", "weight":0.4, "color":"899d52", "nutrition":24, "water_gain":7},
	"water": {"name":"饮用水", "weight":0.6, "color":"6aaec7"},
	"bandage": {"name":"绷带", "weight":0.1, "color":"e4dfc5"},
	"ammo9": {"name":"9mm 子弹", "weight":0.012, "color":"d9bc65"},
	"ammo_rifle": {"name":"步枪子弹", "weight":0.02, "color":"bca063"},
	"wood": {"name":"木材", "weight":0.6, "color":"a97a4d"},
	"parts": {"name":"零件", "weight":0.2, "color":"9ea9a7"},
	"battery": {"name":"电池", "weight":0.2, "color":"c7b774"},
	"fuel": {"name":"燃油", "weight":0.8, "color":"9f8053"},
	"knife": {"name":"撬棍", "weight":1.0, "color":"a4a8aa"},
	"pistol": {"name":"9mm 手枪", "weight":1.2, "color":"b6bbc3", "capacity":12, "ammo":"ammo9", "damage":34, "cooldown":0.30, "range":340.0},
	"rifle": {"name":"突击步枪", "weight":3.0, "color":"82968b", "capacity":24, "ammo":"ammo_rifle", "damage":48, "cooldown":0.15, "range":480.0},
	"suppressor": {"name":"9mm 消音器", "weight":0.3, "color":"73888c", "slot":"muzzle", "compatible":["pistol"]},
	"extended_mag": {"name":"通用扩容弹匣", "weight":0.25, "color":"879c7d", "slot":"mag", "compatible":["pistol","rifle"]},
	"backpack": {"name":"旅行背包", "weight":0.5, "color":"858c58"},
	"cabinet": {"name":"打包小柜", "weight":5.0, "color":"a97c50"}
}
static var ITEMS: Dictionary = BASE_ITEMS.merged(Catalog.definitions(),true)

const BUILDINGS = [
	{"name":"榆树街民居", "rect":Rect2(210, 170, 290, 250), "container":"house"},
	{"name":"社区诊所", "rect":Rect2(720, 150, 290, 250), "container":"clinic"},
	{"name":"警务站", "rect":Rect2(480, 610, 330, 260), "container":"police"}
]

static func capacity_for(item: Dictionary) -> int:
	return int(ITEMS[item.def].get("capacity",0)) + int(item.get("mag_bonus",6 if item.get("slots",{}).has("mag") else 0))

static func compatible(gun: Dictionary, part: Dictionary) -> bool:
	var definition: Dictionary = ITEMS[part.def]
	return gun.def in definition.get("compatible",[]) and definition.get("interface","") in ITEMS[gun.def].get("interfaces",[])

static func weapon_stats(gun: Dictionary, inventory: Dictionary) -> Dictionary:
	var stats: Dictionary = ITEMS[gun.def].duplicate(true)
	stats["focus"] = 1.0; stats["light"] = false
	for id in gun.get("slots",{}).values():
		if not inventory.has(id): continue
		for key in ITEMS[inventory[id].def].get("effects",{}):
			var value = ITEMS[inventory[id].def].effects[key]
			if key == "capacity_add": continue
			if key == "light": stats.light = value
			else: stats[key] = stats.get(key,1.0) * value
	return stats
