extends RefCounted
const C = preload("res://scripts/catalog.gd")
const MINI = "res://assets/minidayz/"
const IconImage = preload("res://scripts/icon_image.gd")
static var clean_icons: Dictionary = {}

# Source atlas coordinates are in the author's original 16px pixel grid.
const BASE = "res://assets/orven/Wastland_Essentials_Free/"
var player: Texture2D = load(BASE + "Player/PlayerBase.png")
var hands: Texture2D = load(BASE + "Player/PlayerHands.png")
var zombie: Texture2D = load(BASE + "Enemies/zombie.png")
var props: Texture2D = load(BASE + "Outdoor decoration/decorations.png")
var terrain: Texture2D = load(BASE + "Tiles/tileset.png")
var shadow: Texture2D = load(BASE + "Other/CharacterShadow.png")
var weapon: Texture2D = load(BASE + "Player/Shotgun .png")
var items: Texture2D = load(BASE + "Items/Items.png")
var town: Texture2D = load("res://assets/kenney/tiny-town.png")
var ruins: Texture2D = load("res://assets/cobralad/apocalypse.png")
var mini_ground: Texture2D = load(MINI + "environment/ground_tilemap.png")
var mini_decor: Texture2D = load(MINI + "environment/ground_enviroment_tilemap.png")
var mini_player: Texture2D = load(MINI + "character/player_skin_def_1.png")
var mini_enemies: Dictionary = {"normal":load(MINI + "character/zed_normal_skin1-sheet0.png"),"fast":load(MINI + "character/zed_fast_skin1-sheet0.png"),"breaker":load(MINI + "character/zed_army_skin1-sheet0.png")}
var mini_car: Texture2D = load(MINI + "environment/car/car_regular.png")
var mini_trees: Array = [load(MINI + "environment/tree_leaves_1.png"),load(MINI + "environment/tree_leaves_2.png"),load(MINI + "environment/tree_pine_1.png")]
var mini_icons: Dictionary = {}
var mini_buildings: Dictionary = {}

func _init():
	for id in C.GUNS + C.PARTS: mini_icons[id] = load(MINI + "icons/" + id + ".png")
	for id in ["food","water","bandage","wood","parts","knife","backpack","cabinet","ammo9","ammo_rifle","ammo_makarov","ammo45","ammo357","ammo545","ammo556","ammo76254","ammo12"]:
		mini_icons[id] = load(MINI + "icons/" + id + ".png")
	for name in ["b_city_house_1","b_city_house_2","b_hospital","b_police_station","b_gunshop"]:
		mini_buildings[name] = {"outside":load(MINI + "building/" + name + "-sheet0.png"),"inside":load(MINI + "building/" + name + "_int-sheet0.png")}
	for entry in [["berry","bilberry"],["apple","apple"],["tomato","tomato"],["squash","zucchini"]]:
		mini_icons[entry[0]] = load(MINI + "item/"+entry[1]+".png")
	mini_icons["battery"] = load(MINI+"item/battery.png")
	mini_icons["fuel"] = load(MINI+"item/gasoline.png")
	for id in mini_icons:
		if not clean_icons.has(id): clean_icons[id] = IconImage.texture(mini_icons[id])
		mini_icons[id] = clean_icons[id]

func icon(definition: String) -> AtlasTexture:
	if mini_icons.has(definition):
		var mini = AtlasTexture.new(); mini.atlas = mini_icons[definition]; mini.region = Rect2(Vector2.ZERO,mini.atlas.get_size())
		return mini
	var texture = AtlasTexture.new(); texture.atlas = items
	if definition != "bandage" and not definition.begins_with("ammo") and definition not in ["cabinet","backpack"]: return null
	var column = 0 if definition == "bandage" else (1 if definition.begins_with("ammo") else 2)
	texture.region = Rect2(column * 16,0,16,16)
	return texture
