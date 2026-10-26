extends RefCounted
const C = preload("res://scripts/catalog.gd")
const IconImage = preload("res://scripts/icon_image.gd")
const BASE = "res://assets/postapocalypse/"
const SHELTER = "res://assets/supplement/post-apoc-shelter-mega-bundle-free/Post Apoc Shelter - Asset Pack/Post Apoc - Shelter 16x16 Grid/"
const OFFICE = "res://assets/supplement/post-apoc-office-mega-bundle-free/Post Apoc Office - Asset Pack/Post Apoc - Office 16x16 Grid/"
static var cache: Dictionary = {}
var mini_icons: Dictionary = {}
var mini_buildings: Dictionary = {}
var mini_trees: Array = []
var mini_enemies: Dictionary = {}
var items: Texture2D
var props: Texture2D
var terrain: Texture2D
var player: Texture2D
var hands: Texture2D
var zombie: Texture2D
var shadow: Texture2D
var weapon: Texture2D
var town: Texture2D
var ruins: Texture2D
var mini_ground: Texture2D
var mini_decor: Texture2D
var mini_player: Texture2D
var mini_car: Texture2D

static func texture(path: String) -> Texture2D:
	if not cache.has(path): cache[path] = load(path)
	return cache[path]

static func asset(path: String) -> Texture2D:
	return texture(BASE+path)

func _init():
	terrain = asset("Tiles/Background_Green_TileSet.png"); mini_ground = terrain
	props = terrain; items = asset("UI/Inventory/Objects/Icon_Bandage.png")
	mini_decor = terrain; player = asset("Character/Main/Idle/Character_down_idle-Sheet6.png"); mini_player = player
	hands = player; zombie = asset("Enemies/Zombie_Small/Zombie_Small_Down_walk-Sheet6.png")
	weapon = asset("Objects/Pickable/Gun.png"); shadow=items; town=terrain; ruins=terrain
	mini_car=asset("Objects/Vehicles/Normal/Car_1/Car_1_Gray.png")
	for name in ["Tree_1_Spruce_Green.png","Tree_3_Normal_Green.png","Tree_7_Birch_Green.png"]: mini_trees.append(asset("Objects/Nature/Green/"+name))
	for id in C.GUNS+C.PARTS+["food","water","bandage","wood","parts","knife","backpack","cabinet","ammo9","ammo_rifle","ammo_makarov","ammo45","ammo357","ammo545","ammo556","ammo76254","ammo12","berry","apple","tomato","squash","battery","fuel"]:
		mini_icons[id] = _item_texture(id)

func region(path: String,rect: Rect2) -> Texture2D:
	var atlas=AtlasTexture.new(); atlas.atlas=texture(path); atlas.region=rect
	return IconImage.texture(atlas)

func backpack_icon() -> Texture2D:
	var image=Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for box in [Rect2i(6,1,4,2),Rect2i(3,3,10,12),Rect2i(1,6,2,7),Rect2i(13,6,2,7)]: image.fill_rect(box,Color("3f3c46"))
	image.fill_rect(Rect2i(4,4,8,10),Color("77805b")); image.fill_rect(Rect2i(5,4,6,3),Color("9b9e73")); image.fill_rect(Rect2i(5,9,6,4),Color("535d47")); image.fill_rect(Rect2i(7,8,2,2),Color("c9b482"))
	return ImageTexture.create_from_image(image)

func _item_texture(id: String) -> Texture2D:
	var workshop="res://assets/supplement/post-apocalyptic-workshop-set-free/PostApoc_Workshop/PostApoc_Workshop_Icons.png"
	if id in ["water","dirty_water","rain_collector"]: return region(workshop,Rect2(48,144,16,16))
	if id in ["cloth","purification_tablet"]: return asset("UI/Inventory/Objects/Icon_Bandage.png")
	if id=="parts": return region(workshop,Rect2(48,192,16,16))
	if id=="wood": return region(workshop,Rect2(160,48,16,16))
	if id=="battery": return region(workshop,Rect2(160,144,16,16))
	if id=="fuel": return region(SHELTER+"Shelter_Furniture_16x16.png",Rect2(16,16,16,32))
	if id=="cabinet": return region(SHELTER+"Shelter_Furniture_16x16.png",Rect2(144,192,16,64))
	if id=="backpack": return backpack_icon()
	if id in C.PARTS: return region(workshop,Rect2(32+16*(C.PARTS.find(id)%5),16,16,16))
	var guns={"pistol":"Glock.png","pm":"Beretta M9.png","colt":"Glock.png","magnum":"Desert Eagle.png","rifle":"AK-47.png","ak74":"AK-47.png","m4":"M4A1.png","aug":"Steyr AUG.png","sks":"Dragunov SVD.png","svd":"Dragunov SVD.png","mosin":"Dragunov SVD.png","shotgun":"Benelli M3.png","izh":"Benelli M3.png","knife":"Knife.png","mp5":"MP5.png","ump":"TDI Vector.png","bizon":"MP5.png"}
	if guns.has(id):
		var path="res://assets/supplement/pixel-guns-2d-weapon-pack/"+guns[id]
		if ResourceLoader.exists(path): return IconImage.texture(texture(path))
		return asset("Objects/Pickable/"+("Pistol" if id in ["pistol","pm","colt","magnum"] else "Gun")+".png")
	var name={"food":"Icon_Canned-food.png","water":"Icon_Canned-soup.png","bandage":"Icon_Bandage.png","parts":"Icon_Rock.png","wood":"Icon_Wooden-wall.png","backpack":"Icon_Bullet-crate_Green.png","cabinet":"Icon_Bullet-crate_Blue.png","fuel":"Icon_Canned-soup.png","battery":"Icon_Bullet-box_Blue.png"}.get(id,"Icon_Bullet-box_Green.png")
	if id in ["apple","tomato","berry","squash"]:
		var food={"apple":"Apple.png","tomato":"Tomato.png","berry":"Cherry.png","squash":"Eggplant.png"}[id]
		var path="res://assets/supplement/16x16-food-icons-variety-pack/"+food
		if ResourceLoader.exists(path): return texture(path)
	return asset("UI/Inventory/Objects/"+name)

func icon(definition: String) -> AtlasTexture:
	var tex: Texture2D = mini_icons.get(definition,items)
	var result=AtlasTexture.new(); result.atlas=tex; result.region=Rect2(Vector2.ZERO,tex.get_size())
	return result
