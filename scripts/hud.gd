extends CanvasLayer

const R = preload("res://scripts/rules.gd")
var game
var root: Control
var top: Label
var status: Label
var radio: Label
var objective: Label
var progress: ProgressBar
var panel: PanelContainer
var body: VBoxContainer
var panel_kind = ""
var container_id = ""
var move_axis = Vector2.ZERO
var aim_axis = Vector2.ZERO
var move_touch = -1
var aim_touch = -1
var move_origin = Vector2(160,570)
var aim_origin = Vector2(1110,565)
var sticks: Control
var font: Font
var queued: Array = []
var last_log = ""
var clock_acc = 0.0
var left_handed = false
var stick_scale = 1.0
var aim_assist = true
var art = preload("res://scripts/art.gd").new()
var fire_held = false
var selected_gun = ""
var fire_touch = -1
var fire_rect = Rect2(1140,405,108,76)
var touch_buttons: Array = []
var scroll_panels: Array = []
var ui_touches: Dictionary = {}
var progress_label: Label
var new_world_dialog: ConfirmationDialog
var controls_path = "user://controls.cfg"
var control_layout: Dictionary = {}
var vital_bars: Dictionary = {}
var layout_editing = false
var selected_control = "reload"
var layout_touch = -1
var layout_offset = Vector2.ZERO
var layout_label: Label
var world_touches: Dictionary = {}
var pinch_distance = 0.0
var pinch_zoom = 1.0
var display_bounds = Rect2(0,0,1280,720)
var cropped_icons: Dictionary = {}

func style(color: Color, border: Color = Color("46564f"), radius: int = 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color; s.border_color = border
	s.set_border_width_all(1); s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 9; s.content_margin_bottom = 9
	return s

func pixel_style(light: bool = false) -> StyleBoxTexture:
	var skin = StyleBoxTexture.new()
	skin.texture = load("res://assets/postapocalypse/UI/Inventory/"+("Inventory-Chosen.png" if light else "Inventory-Cell.png"))
	skin.texture_margin_left=3; skin.texture_margin_right=3; skin.texture_margin_top=3; skin.texture_margin_bottom=3
	skin.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	skin.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	skin.content_margin_left=12; skin.content_margin_right=12; skin.content_margin_top=9; skin.content_margin_bottom=9
	return skin

func _ready():
	font = load("res://assets/NotoSansCJKsc-Regular.otf")
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	var theme = Theme.new(); theme.default_font = font; theme.default_font_size = 18
	theme.set_stylebox("normal","Button",pixel_style())
	theme.set_stylebox("hover","Button",pixel_style(true))
	theme.set_stylebox("pressed","Button",style(Color("6c7354"),Color("dfc78c")))
	theme.set_stylebox("disabled","Button",style(Color("202c2d")))
	theme.set_color("font_color","Button",Color("e3e1c9"))
	theme.set_color("font_color","Label",Color("e1e4d3"))
	theme.set_stylebox("panel","PanelContainer",pixel_style())
	root.theme = theme
	root.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	top = text("",18); top.position=Vector2(278,16); root.add_child(top)
	status = text("",16); status.position=Vector2(278,46); root.add_child(status)
	build_vital_bars()
	objective = text("",15,Color("e2cf9f")); objective.position=Vector2(278,76); root.add_child(objective)
	radio = text("",14); radio.position=Vector2(340,610); radio.size=Vector2(600,24); radio.clip_text=true; root.add_child(radio)
	var actions = [
		["bag","背包","inventory",func(): open_panel("bag")],
		["map","地图","zoom",func(): open_panel("map")],
		["people","人员","talk",func(): open_panel("people")],
		["camp","住所","builder",func(): open_panel("camp")],
		["pause","暂停","switch",func(): open_panel("pause")],
		["survival","生存操作","interact",func(): open_panel("mechanics")],
		["reload","换弹","reload",func(): game.reload_request()],
		["bandage","绷带","interact",func(): game.world.use_item("bandage")],
		["interact","互动","interact",func(): game.interact()],
		["fire","开火","attack",func(): pass]]
	for i in range(actions.size()):
		var e = actions[i]; var b = button("",e[3],Vector2(58,58)); b.size = Vector2(58,58); b.position = Vector2(1200,12+i*65); b.tooltip_text = e[1]; b.set_meta("action_name",e[0])
		b.icon = action_icon(e[0])
		if e[0] == "bandage": b.icon = art.icon("bandage")
		if e[0] == "pause": b.icon = pause_icon()
		if e[0] == "survival": b.icon = survival_icon()
		if e[0] == "camp": b.icon=action_icon("camp")
		prepare_action_icon(b)
		b.expand_icon = true; b.add_theme_constant_override("icon_max_width",56); root.add_child(b)
		if e[0] == "fire": b.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.set_meta("fire_control",true)
	var quick_back=TextureRect.new(); quick_back.texture=load("res://assets/postapocalypse/UI/Inventory/Quick-Access-Inventory.png"); quick_back.position=Vector2(385,640); quick_back.size=Vector2(496,76); quick_back.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; quick_back.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(quick_back)
	for i in range(6):
		var index=i
		var b=button("",func():
			if index==0: game.world.state.weapon="knife"
			elif index<=2: game.cycle_weapon("sidearm" if index==1 else "primary")
			else: game.world.use_item(["food","water","bandage"][index-3]),Vector2(72,72))
		var id=["melee","secondary","primary","foodquick","waterquick","healquick"][i]
		b.set_meta("action_name",id); b.tooltip_text=["近战","副武器","主武器","进食","饮水","包扎"][i]
		b.icon=art.icon(["knife","pistol","rifle","food","water","bandage"][i]); b.position=Vector2(390+i*83,642); root.add_child(b); prepare_action_icon(b)
		b.set_meta("quick_index",i)
		var amount=text("",13); amount.mouse_filter=Control.MOUSE_FILTER_IGNORE; amount.position=Vector2(42,2); b.add_child(amount); b.set_meta("qty_label",amount)
	progress = ProgressBar.new(); progress.position = Vector2(495,594); progress.size = Vector2(290,12); progress.visible = false; progress.show_percentage = false; root.add_child(progress)
	progress_label = text("",16); progress_label.position = Vector2(510,565); root.add_child(progress_label)
	new_world_dialog = ConfirmationDialog.new(); new_world_dialog.title = "新世界"; new_world_dialog.dialog_text = "清除当前世界并重新开始？"; root.add_child(new_world_dialog)
	new_world_dialog.confirmed.connect(func(): game.start_new_game())
	sticks = Control.new(); sticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(sticks)
	sticks.draw.connect(draw_sticks)
	panel = PanelContainer.new(); panel.position = Vector2(170,106); panel.size = Vector2(940,500); panel.visible = false; root.add_child(panel)
	panel.add_theme_stylebox_override("panel",pixel_style())
	body = VBoxContainer.new(); body.add_theme_constant_override("separation",10); panel.add_child(body)
	reset_control_layout(false); load_control_layout()
	for child in root.get_children():
		if child is Control and child not in [panel,sticks,radio,progress,progress_label,new_world_dialog] and not child.has_meta("action_name"): child.set_meta("safe_position",child.position)
	get_viewport().size_changed.connect(update_display_layout)
	update_display_layout()

# The saved layout always uses the original1280x720 design coordinates.
# Right-side positions retain their distance from the screen edge on wide phones.
func display_position(position: Vector2) -> Vector2:
	return display_bounds.position+position*display_bounds.size/Vector2(1280,720)

func design_position(position: Vector2, _previous: Vector2 = Vector2.ZERO) -> Vector2:
	return (position-display_bounds.position)*Vector2(1280,720)/display_bounds.size

func update_display_layout():
	display_bounds = get_viewport().get_visible_rect()
	if OS.get_name()=="Android":
		var safe = DisplayServer.get_display_safe_area()
		var physical = Vector2(DisplayServer.window_get_size())
		if safe.has_area() and physical.x>0 and physical.y>0:
			var ratio = display_bounds.size / physical
			display_bounds = Rect2(Vector2(safe.position)*ratio,Vector2(safe.size)*ratio)
	apply_control_layout()
	for child in root.get_children():
		if child is Control and child.has_meta("safe_position"): child.position=display_bounds.position+child.get_meta("safe_position")
	radio.position = display_bounds.position+Vector2((display_bounds.size.x-620)/2,display_bounds.size.y-112)
	progress.position = display_bounds.get_center()+Vector2(-145,234)
	progress_label.position = progress.position+Vector2(15,-29)
	fit_panel()

func _process(_delta):
	if is_instance_valid(panel) and panel.visible: fit_panel()

func fit_panel():
	if not is_instance_valid(panel): return
	var desired = Vector2(640,170) if layout_editing else Vector2(940,500)
	panel.size = desired.max(panel.get_combined_minimum_size())
	var available = display_bounds.size-Vector2(32,32)
	var factor = minf(1,minf(available.x/panel.size.x,available.y/panel.size.y))
	panel.scale = Vector2.ONE*factor
	panel.position = display_bounds.get_center()-panel.size*factor/2
	if layout_editing: panel.position.y = display_bounds.position.y+minf(145,available.y-panel.size.y*factor)

func prepare_action_icon(b: Button):
	var source = b.icon
	if source!=null:
		var key = str(source.get_rid())
		if not cropped_icons.has(key):
			var image = source.get_image()
			if image!=null:
				var used = image.get_used_rect()
				if used.has_area(): image=image.get_region(used)
				cropped_icons[key]=ImageTexture.create_from_image(image)
		if cropped_icons.has(key): b.icon=cropped_icons[key]
	var image_view=TextureRect.new(); image_view.texture=b.icon
	image_view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image_view.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_view.mouse_filter=Control.MOUSE_FILTER_IGNORE; b.add_child(image_view); image_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.set_meta("icon_view",image_view)
	for state in ["normal","hover","pressed","focus","disabled","hover_pressed"]: b.add_theme_color_override("icon_"+state+"_color",Color.TRANSPARENT)
	for state in ["normal","hover","pressed","disabled"]:
		var backing=pixel_style(state=="pressed")
		backing.set_content_margin_all(4)
		b.add_theme_stylebox_override(state,backing)
	var caption=text(b.tooltip_text,12,Color("eee2cb")); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(caption); caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); caption.offset_top=-18; caption.offset_bottom=0

func gui_texture(_path: String) -> Texture2D:
	return load("res://assets/postapocalypse/UI/Inventory/Inventory-Cell.png")

func action_icon(action_name: String) -> Texture2D:
	if action_name=="bag": return art.icon("backpack")
	if action_name in ["map","people"]: return navigation_icon(action_name)
	var icons={"bag":"Icon_Bullet-crate_Green.png","map":"Icon_Canned-soup.png","people":"Icon_First-Aid-Kit_White.png","camp":"Icon_Wooden-wall_Gate.png","reload":"Icon_Bullet-box_Blue.png","interact":"Icon_Reinforced-wooden-wall_Gate.png","fire":"Icon_Gun.png"}
	return load("res://assets/postapocalypse/UI/Inventory/Objects/"+icons.get(action_name,"Icon_Rock.png"))

func navigation_icon(kind: String) -> Texture2D:
	var image=Image.create(20,20,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	if kind=="map":
		image.fill_rect(Rect2i(2,4,16,13),Color("e0d1aa"))
		image.fill_rect(Rect2i(7,3,5,13),Color("b9bba0"))
		image.fill_rect(Rect2i(8,4,1,12),Color("777b6e"))
		image.fill_rect(Rect2i(13,5,1,12),Color("777b6e"))
		for i in range(5): image.fill_rect(Rect2i(4+i*2,13-i,2,1),Color("8c7d80"))
		image.fill_rect(Rect2i(12,7,3,3),Color("b36c70"))
	else:
		for p in [Vector2i(3,4),Vector2i(11,5)]:
			image.fill_rect(Rect2i(p,Vector2i(5,5)),Color("ceba9d"))
			image.fill_rect(Rect2i(p+Vector2i(-1,6),Vector2i(7,7)),Color("8eaa9b"))
	return ImageTexture.create_from_image(image)

func find_action_rect(action_name: String) -> Rect2:
	for b in touch_buttons:
		if is_instance_valid(b) and b.get_meta("action_name", "") == action_name: return b.get_global_rect()
	return Rect2()

func text(message: String, size: int = 18, color: Color = Color("e1e4d3")) -> Label:
	
	var label = Label.new(); label.text = message; label.add_theme_font_size_override("font_size",size); label.add_theme_color_override("font_color",color); label.add_theme_color_override("font_shadow_color",Color("24212d")); label.add_theme_constant_override("shadow_offset_x",1); label.add_theme_constant_override("shadow_offset_y",2)
	return label

func button(message: String, callback: Callable, min_size: Vector2 = Vector2(0,48)) -> Button:
	var b = Button.new(); b.text = message; b.custom_minimum_size = min_size; b.pressed.connect(callback)
	b.focus_mode = Control.FOCUS_NONE
	touch_buttons.append(b)
	var definition = "bandage" if "绷带" in message else ("ammo9" if "子弹" in message else ("cabinet" if "打包小柜" in message else ""))
	if not definition.is_empty():
		b.icon = art.icon(definition); b.expand_icon = true; b.add_theme_constant_override("icon_max_width",30)
	return b

func item_button(message: String, callback: Callable, definition: String) -> Button:
	var b = button(message,callback,Vector2(190,74)); b.icon = art.icon(definition)
	b.expand_icon = true; b.add_theme_constant_override("icon_max_width",56 if R.ITEMS[definition].has("slots") else 36); b.clip_text = true
	b.add_theme_font_size_override("font_size",16)
	return b

func refresh():
	if game.world.state.is_empty(): return
	var w = game.world; var s = w.state
	var day = int(s.minute / 1440) + 1; var minute = int(s.minute) % 1440
	top.text = "DAY %02d   %02d:%02d   %s" % [day,minute / 60,minute % 60,("榆树镇" if s.get("map_id","town")=="town" else "松溪林区")]
	var gun_id = w.player_weapon(s.weapon); var ammo = ""
	if not gun_id.is_empty() and w.items[gun_id].has("ammo"):
		var gun = w.items[gun_id]; ammo = " %d/%d · 备弹%d" % [gun.ammo,R.capacity_for(gun),w.count_item(R.ITEMS[gun.def].ammo)]
	status.text = "%s%s   %.1f/%.0fkg · %d/%d格%s" % [R.ITEMS[s.weapon].name,ammo,w.weight("player"),w.capacity,w.owned("player").size(),w.slot_capacity,"   流血！" if s.bleeding else ""]
	for key in vital_bars:
		vital_bars[key].bar.value = s[key]; vital_bars[key].value.text = str(int(s[key]))
	status.add_theme_font_size_override("font_size",15)
	objective.text="自由探索 · 无强制返程"
	if s.has("systems_v5"):
		objective.text+="  疲劳 %d  %s%s" % [s.systems_v5.fatigue,game.Survival.WEATHER_NAMES.get(s.systems_v5.weather,"晴")," · 休息中" if s.systems_v5.resting else ""]
	if s.zone == "town" and s.has("waypoint"):
		objective.text += "  目标 %.0fm" % (game.player_pos().distance_to(Vector2(s.waypoint[0],s.waypoint[1])) / 32)
	if not w.logs.is_empty(): radio.text = "[探索]  " + str(w.logs.back())
	progress.visible = not game.action.is_empty()
	progress_label.visible = progress.visible
	if progress.visible:
		progress.value = (1.0 - game.action.remaining / maxf(game.action.duration,0.01)) * 100
		progress_label.text = "采集中…" if game.action.get("kind","")=="harvest" else ("搜寻…" if game.action.get("kind","") in ["search","transfer"] else "进行中…")
	for b in touch_buttons:
		if not is_instance_valid(b) or not b.has_meta("quick_index"): continue
		var index=int(b.get_meta("quick_index"))
		var amount=b.get_meta("qty_label")
		if index>=3: amount.text="×%d"%w.count_item(["food","water","bandage"][index-3])
		var active=(index==0 and s.weapon=="knife") or (index==1 and s.weapon in ["pistol","pm","colt","magnum"]) or (index==2 and s.weapon not in ["knife","pistol","pm","colt","magnum"])
		b.add_theme_stylebox_override("normal",pixel_style(active))
	sticks.queue_redraw()

func draw_sticks():
	if game.world.paused and not layout_editing: return
	for info in [[move_origin,move_axis,"move"],[aim_origin,aim_axis,"aim"]]:
		var p: Vector2 = info[0]; var axis: Vector2 = info[1]
		var scale_value = joystick_scale(info[2])
		sticks.draw_circle(p,65 * scale_value,Color(0.05,0.10,0.11,0.48))
		sticks.draw_arc(p,65 * scale_value,0,TAU,48,Color(0.77,0.8,0.68,0.65),2)
		sticks.draw_circle(p + axis * 40 * scale_value,24 * scale_value,Color(0.7,0.74,0.61,0.48))
	if layout_editing:
		var rect = control_rect(selected_control)
		sticks.draw_rect(rect.grow(4),Color("f5ce72"),false,3)

func _unhandled_input(event):
	if game.world.paused: return
	if event is InputEventScreenTouch and (ui_touches.has(event.index) or event.index == fire_touch or point_on_action(event.position)): return
	if event is InputEventScreenTouch:
		if not event.pressed:
			if event.index == move_touch: move_touch = -1; move_axis = Vector2.ZERO
			if event.index == aim_touch: aim_touch = -1; aim_axis = Vector2.ZERO
		elif event.position.distance_to(move_origin) < 85 * joystick_scale("move") and move_touch == -1:
			move_touch = event.index; move_axis = ((event.position - move_origin) / (60 * joystick_scale("move"))).limit_length()
		elif event.position.distance_to(aim_origin) < 85 * joystick_scale("aim") and aim_touch == -1:
			aim_touch = event.index; aim_axis = ((event.position - aim_origin) / (60 * joystick_scale("aim"))).limit_length()
		elif event.pressed:
			world_touches[event.index] = event.position; begin_pinch()
	if event is InputEventScreenDrag:
		if event.index == move_touch: move_axis = ((event.position - move_origin) / (60 * joystick_scale("move"))).limit_length()
		if event.index == aim_touch: aim_axis = ((event.position - aim_origin) / (60 * joystick_scale("aim"))).limit_length()
		if world_touches.has(event.index):
			world_touches[event.index] = event.position
			if world_touches.size() == 2 and pinch_distance > 0:
				var points = world_touches.values(); game.set_world_zoom(pinch_zoom * points[0].distance_to(points[1]) / pinch_distance)

func _input(event):
	if layout_editing and layout_input(event): get_viewport().set_input_as_handled(); return
	if event is InputEventScreenTouch and not event.pressed:
		world_touches.erase(event.index); pinch_distance = 0.0
	# These controls are dispatched from physical touch release. Ignore the
	# synthetic mouse event for them while leaving native mouse and map intact.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION and not new_world_dialog.visible:
		for b in touch_buttons:
			if is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(event.position): get_viewport().set_input_as_handled(); return
		for scroll in scroll_panels:
			if is_instance_valid(scroll) and scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(event.position): get_viewport().set_input_as_handled(); return
	if event is InputEventScreenTouch:
		if event.pressed and not game.world.paused and fire_touch == -1 and find_action_rect("fire").has_point(event.position):
			fire_touch = event.index; fire_held = true; get_viewport().set_input_as_handled(); return
		if not event.pressed and event.index == fire_touch:
			fire_touch = -1; fire_held = false; get_viewport().set_input_as_handled(); return
		if event.pressed and event.index != move_touch and event.index != aim_touch:
			var target: Button = null
			for i in range(touch_buttons.size()-1,-1,-1):
				var b = touch_buttons[i]
				if is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(event.position):
					var ancestor = b.get_parent(); var clipped = false
					while ancestor != null:
						if ancestor is ScrollContainer and not ancestor.get_global_rect().has_point(event.position): clipped = true
						ancestor = ancestor.get_parent()
					if not clipped: target = b; break
			var scroller: ScrollContainer = null
			for candidate in scroll_panels:
				if is_instance_valid(candidate) and candidate.is_visible_in_tree() and candidate.get_global_rect().has_point(event.position): scroller = candidate
			if target != null or scroller != null:
				ui_touches[event.index] = {"start":event.position,"last":event.position,"button":target,"scroll":scroller,"drag":false,"thumb":scroller != null and scroller.get_v_scroll_bar().get_global_rect().has_point(event.position)}
				get_viewport().set_input_as_handled(); return
		if not event.pressed and ui_touches.has(event.index):
			var touch = ui_touches[event.index]; ui_touches.erase(event.index); var b = touch.button
			if not touch.drag and event.position.distance_to(touch.start) < 14 and is_instance_valid(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(event.position): b.pressed.emit()
			get_viewport().set_input_as_handled(); return
	if event is InputEventScreenDrag and ui_touches.has(event.index):
		var touch = ui_touches[event.index]
		if event.position.distance_to(touch.start) > 14: touch.drag = true
		if touch.drag and is_instance_valid(touch.scroll):
			var scroll: ScrollContainer = touch.scroll; var delta = event.position.y - touch.last.y
			if touch.thumb:
				var bar = scroll.get_v_scroll_bar(); delta *= -(bar.max_value-bar.page) / maxf(24.0,bar.size.y-bar.size.y*bar.page/maxf(1.0,bar.max_value))
			scroll.scroll_vertical -= int(delta)
		touch.last = event.position; get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and find_action_rect("fire").has_point(event.position) and not game.world.paused: fire_held = true
		elif not event.pressed and fire_touch == -1: fire_held = false
	# A held joystick keeps its touch ID even when the finger crosses a GUI button.
	if event is InputEventScreenTouch and not event.pressed:
		if event.index == move_touch: move_touch = -1; move_axis = Vector2.ZERO
		if event.index == aim_touch: aim_touch = -1; aim_axis = Vector2.ZERO
	if event is InputEventScreenDrag:
		if event.index == move_touch: move_axis = ((event.position - move_origin) / (60 * joystick_scale("move"))).limit_length()
		if event.index == aim_touch: aim_axis = ((event.position - aim_origin) / (60 * joystick_scale("aim"))).limit_length()

func clear_body():
	ui_touches.clear(); scroll_panels.clear()
	for child in body.get_children(): body.remove_child(child); child.queue_free()

func close_panel():
	if game.world.state.failed: return
	if layout_editing: save_control_layout()
	layout_editing = false; layout_touch = -1; panel.position = Vector2(170,106); panel.size = Vector2(940,500)
	panel.visible = false; panel_kind = ""; game.world.paused = false
	move_axis = Vector2.ZERO; aim_axis = Vector2.ZERO; move_touch = -1; aim_touch = -1
	fire_held = false
	fire_touch = -1
	queued.clear()

func open_panel(kind: String):
	if body == null: return
	world_touches.clear(); pinch_distance = 0.0
	game.action.clear(); game.world.paused = true; panel_kind = kind
	move_axis = Vector2.ZERO; aim_axis = Vector2.ZERO; move_touch = -1; aim_touch = -1
	fire_held = false
	fire_touch = -1
	clear_body(); panel.visible = true
	var header = HBoxContainer.new(); body.add_child(header)
	var titles = {"mechanics":"生存操作","camp":"我的落脚点", "bag":"随身背包", "loot":"搜刮与转移", "parts":"枪械配件", "people":"幸存者", "map":"区域地图", "pause":"暂停 · 世界时间已停止", "failure":"恢复与存档", "battle":"探索记录"}
	var title = text(titles.get(kind,kind),25,Color("dcc693")); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	if kind != "failure": header.add_child(button("返回游戏  ×",close_panel,Vector2(140,45)))
	match kind:
		"bag", "loot": inventory_panel(kind)
		"parts": parts_panel()
		"people": people_panel()
		"map": map_panel()
		"pause": pause_panel()
		"failure": failure_panel()
		"battle": battle_panel()
		"camp": camp_panel()
		"mechanics": mechanics_panel()

func scroll_column(parent: Control, heading: String) -> VBoxContainer:
	var col = VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(col)
	col.add_child(text(heading,18,Color("b6c8b6")))
	var scroll = ScrollContainer.new(); scroll.custom_minimum_size = Vector2(415,300); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; col.add_child(scroll); scroll_panels.append(scroll)
	var entries = VBoxContainer.new(); entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL; entries.add_theme_constant_override("separation",5); scroll.add_child(entries)
	return entries

func inventory_panel(kind: String):
	var w = game.world
	var tabs = HBoxContainer.new(); body.add_child(tabs)
	tabs.add_child(button("枪械配件",func(): open_panel("parts")))
	tabs.add_child(text("负重 %.1f / %.0f kg · 点按物品操作" % [w.weight("player"),w.capacity],17))
	var columns = HBoxContainer.new(); columns.add_theme_constant_override("separation",22); body.add_child(columns)
	var bag_entries = scroll_column(columns,"随身物品")
	var bag = GridContainer.new(); bag.columns = 2; bag.add_theme_constant_override("h_separation",5); bag.add_theme_constant_override("v_separation",5); bag_entries.add_child(bag)
	for item in w.owned("player"):
		var item_id: String = item.id
		var label = "%s  ×%d" % [R.ITEMS[item.def].name,item.qty]
		if item.has("fresh_until"): label+=" · "+("变质" if w.state.minute>=item.fresh_until else ("将变质" if item.fresh_until-w.state.minute<360 else "新鲜"))
		if kind == "loot":
			bag.add_child(item_button(label + " → 存入",func(): transfer_request(item_id,"player",container_id),item.def))
		elif item.has("fresh_until") and w.state.minute>=item.fresh_until:
			bag.add_child(item_button(label+" · 清理",func():game.request_mechanic({"kind":"sys_discard_food","id":item_id},1.2),item.def))
		elif item.def in ["food","water","bandage"] or R.ITEMS[item.def].has("nutrition"):
			bag.add_child(item_button(label + " · 使用",func(): w.use_item(item.def,item_id); open_panel("bag"),item.def))
		elif item.def == "knife" or item.has("slots"):
			bag.add_child(item_button(label + " · 装备",func(): w.equip(item_id); open_panel("bag"),item.def))
		elif item.def == "cabinet":
			bag.add_child(button(label + "  · 放置预览",func(): close_panel(); game.placement = {"id":item_id,"rotation":0}))
		else: bag.add_child(item_button(label,func(): pass,item.def))
	if kind == "loot":
		var loot = scroll_column(columns,"汽车后备箱" if container_id.begins_with("car_") else "附近容器")
		for item in w.owned(container_id):
			var item_id: String = item.id
			loot.add_child(item_button("%s ×%d → 取出" % [R.ITEMS[item.def].name,item.qty],func(): transfer_request(item_id,container_id,"player"),item.def))
		var all = w.owned(container_id)
		if not all.is_empty():
			loot.add_child(button("全部取出 · 逐项耗时，可被中断",func():
				var ids: Array = all.map(func(i): return i.id)
				var first = ids.pop_front()
				game.start_action({"kind":"transfer","id":first,"source":container_id,"target":"player","pos":game.container_pos(container_id),"queue":ids})))
		for f in w.furniture:
			if f.id == container_id:
				loot.add_child(button("清空后打包柜子 · 5kg",func(): game.start_action({"kind":"pack","id":container_id,"pos":game.container_pos(container_id)},2)))
		body.add_child(text("选择后恢复世界并耗时执行；移动或受击中断。容量不足时保留原物。",15,Color("a9b9ae")))
	else:
		var help = scroll_column(columns,"生存提示")
		help.add_child(text("食物与饮水可在背包中使用。\n\n物资不会因进出建筑刷新。\n所有随身物品在死亡后留下遗物。\n\n找床休息，登记多个落脚点。\n小柜子清空后可打包带走。\n\n装备与地图菜单暂停整个世界。",17))

func transfer_request(id: String, source: String, target: String):
	game.start_action({"kind":"transfer","id":id,"source":source,"target":target,"pos":game.container_pos(container_id)})

func parts_panel():
	var w = game.world
	body.add_child(text("枪口 / 瞄具 / 弹匣 / 下挂 / 枪托 · 只安装接口兼容的配件，确认后耗时执行。",15))
	var columns = HBoxContainer.new(); columns.add_theme_constant_override("separation",18); body.add_child(columns)
	var list = scroll_column(columns,"携带枪械 · 点选查看")
	var details = scroll_column(columns,"装配与性能")
	var guns = w.owned("player").filter(func(i): return i.has("slots"))
	if guns.is_empty():
		list.add_child(text("尚未携带枪械。\n前往警务点或搜刮物资取得装备。",17)); return
	if not w.items.has(selected_gun) or w.items[selected_gun].owner != "player": selected_gun = guns[0].id
	for gun in guns:
		var gun_id: String = gun.id
		list.add_child(item_button(R.ITEMS[gun.def].name + (" ◀" if gun.id == selected_gun else ""),func(): selected_gun = gun_id; open_panel("parts"),gun.def))
	var gun = w.items[selected_gun]; var stats = R.weapon_stats(gun,w.items); var gun_id: String = gun.id
	var image = TextureRect.new(); image.texture = art.icon(gun.def); image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.custom_minimum_size = Vector2(390,68); details.add_child(image)
	details.add_child(text("%s · 枪内 %d/%d" % [stats.name,gun.ammo,R.capacity_for(gun)],20,Color("dcc693")))
	details.add_child(text("伤害%d×%d  射程%d  换弹%.1fs\n噪声%d  散布%.1f°  弹药：%s" % [stats.damage,stats.pellets,stats.range,stats.reload,stats.noise,rad_to_deg(stats.spread),R.ITEMS[stats.ammo].name],16))
	for slot in R.Catalog.SLOTS:
		var slot_id: String = slot
		if gun.slots.has(slot):
			var part_id: String = gun.slots[slot]
			details.add_child(item_button(R.Catalog.SLOTS[slot] + ": " + R.ITEMS[w.items[part_id].def].name + " · 拆下",func(): game.start_action({"kind":"detach","gun":gun_id,"slot":slot_id},2),w.items[part_id].def))
		else: details.add_child(text(R.Catalog.SLOTS[slot] + "：空",16,Color("9caf9d")))
	for part in w.owned("player"):
		if not R.ITEMS[part.def].has("slot"): continue
		var part_id: String = part.id; var compatible = R.compatible(gun,part)
		var b = item_button(("安装 " if compatible else "不兼容 ") + R.ITEMS[part.def].name,func(): game.start_action({"kind":"attach","gun":gun_id,"id":part_id},2),part.def)
		b.disabled = not compatible or gun.slots.has(R.ITEMS[part.def].slot); details.add_child(b)

func people_panel():
	var w = game.world
	var people_entries = scroll_column(body,"幸存者与同行状态")
	body.add_child(text("最多1名随行；倒地保留原位，需要靠近并持续救援。救援需靠近，医疗物资完成时消耗。",16))
	for n in w.npcs:
		var row = HBoxContainer.new(); people_entries.add_child(row)
		var states = {"healthy":"健康","injured":"负伤","down":"倒地待救","waiting":"待招募"}
		var label = text("%s  |  %s  |  %s  HP%d  |  %s  经验%d" % [n.name,n.job,states.get(n.status,n.status),n.hp,("榆树镇" if w.state.get("map_id","town")=="town" else "松溪林区"),n.xp],17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		if n.status in ["healthy","injured"] and n.zone == w.state.zone:
			row.add_child(button("留守" if n.follow else "随行",func():
				if n.follow: n.follow = false; n["order"]="guard"; n["anchor_x"]=n.x; n["anchor_y"]=n.y
				else:
					for other in w.npcs: other.follow = false
					n.follow = true
					n["order"]="follow"
				open_panel("people")))
		if n.zone == "camp" and n.status not in ["down","waiting"]:
			row.add_child(button("轮换分工",func(): n.job = {"守卫":"维修","维修":"医疗","医疗":"守卫"}[n.job]; open_panel("people")))
		if n.zone==w.state.zone and n.status not in ["down","waiting"] and Vector2(n.x,n.y).distance_to(game.player_pos())<110:
			row.add_child(button("附近指令",func():open_panel("mechanics")))
	if w.state.zone == "camp":
		body.add_child(button("把随身9mm弹药补给守卫（最多30发）",func():
			var count = mini(30,w.count_item("ammo9"))
			if w.consume("ammo9",count): w.state.guard_ammo += count
			open_panel("people")))

func map_panel():
	var w = game.world
	body.add_child(text("地区地图 · %d处聚落 / %d处建筑 · 黄点玩家 / 蓝点出口 / 绿点住所" % [w.map.sectors.size(),w.map.buildings.size()],16))
	var known=w.state.get("known_regions",{})
	var discovery={"rumor":"听说过","entrance":"已发现入口","entered":"已抵达"}
	body.add_child(text("世界连接：榆树镇 ↔ 松溪林区   |   林区："+str(discovery.get(known.get("forest","rumor"),"尚未知晓")),16))
	var display = preload("res://scripts/map_screen.gd").new(); display.game = game; display.center=game.player_pos(); body.add_child(display)
	var row = HBoxContainer.new(); body.add_child(row)
	row.add_child(button("放大 +",func(): display.change_zoom(1.5)))
	row.add_child(button("缩小 −",func(): display.change_zoom(0.67)))
	row.add_child(button("定位玩家",func(): display.center = game.player_pos() if w.state.zone == "town" else Vector2(45,490); display.zoom = 3; display.queue_redraw()))
	row.add_child(button("清除目标",func(): w.state.erase("waypoint"); display.queue_redraw()))
	row.add_child(text("拖动查看 · 点按标记目标，不传送",15))

func camp_panel():
	var w=game.world
	body.add_child(text("住所是你选中的普通房屋。失守可以撤离，没有必须守住的核心。",16))
	var near=w.near_bed()
	if not near.is_empty():
		var row=HBoxContainer.new(); body.add_child(row)
		var shelter_name=LineEdit.new(); shelter_name.placeholder_text="给落脚点取名"; shelter_name.custom_minimum_size=Vector2(270,48); row.add_child(shelter_name)
		row.add_child(button("登记附近床位",func(): w.register_shelter(near.id,shelter_name.text); open_panel("camp")))
	else: body.add_child(text("靠近房屋内的床位后，可命名并登记落脚点。",16))
	var list=scroll_column(body,"已登记的住所 · 库存只在现场存取")
	for shelter in w.state.get("shelters",[]):
		var id: String=shelter.id
		var row=HBoxContainer.new(); list.add_child(row)
		var preferred=w.state.get("preferred_shelter_id","")==id
		var title=text(str(shelter.get("name","落脚点"))+(" ★ 首选恢复" if preferred else "")+" · "+str(shelter.get("map_id","town")),17); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(title)
		row.add_child(button("设为首选",func(): w.set_preferred_shelter(id); open_panel("camp")))
		row.add_child(button("取消登记",func(): w.unregister_shelter(id); open_panel("camp")))
	if w.state.get("shelters",[]).is_empty(): list.add_child(text("尚未登记。未登记也可以在安全床位睡觉。",17))
	body.add_child(text("恢复时会检查床位、站位与附近威胁；个人死亡不会清空住所容器。",15))

func pause_panel():
	var pause_body = body
	body = scroll_column(pause_body,"触控 / 存档 / 调试")
	body.add_child(button("调整触控布局 · 拖动位置 / 调整大小",start_layout_editor))
	body.add_child(button("新世界",func(): new_world_dialog.popup_centered(Vector2i(420,180))))
	body.add_child(text("左摇杆移动 · 右摇杆瞄准 · 右侧按钮独立开火\n停步持续瞄准会收紧准星；移动射击散布更大。\n主/副武器按钮轮换已携带枪械，背包可指定装备。",18))
	var row = HBoxContainer.new(); body.add_child(row)
	row.add_child(button("保存并继续",func(): game.world.save_game(); close_panel()))
	row.add_child(button("读取最近存档",func():
		if game.world.load_game():
			if game.world.state.failed: open_panel("failure")
			else: close_panel()))
	row.add_child(button("左手模式：" + ("开" if left_handed else "关"),func():
		left_handed = not left_handed
		move_origin = Vector2(1110,565) if left_handed else Vector2(160,570)
		aim_origin = Vector2(160,570) if left_handed else Vector2(1110,565)
		control_layout.move.position = move_origin; control_layout.aim.position = aim_origin; save_control_layout()
		open_panel("pause")))
	var settings = HBoxContainer.new(); body.add_child(settings)
	settings.add_child(button("摇杆大小 %.0f%%" % (stick_scale * 100),func(): stick_scale = 1.25 if stick_scale == 1.0 else (0.85 if stick_scale == 1.25 else 1.0); control_layout.move.size = 130 * stick_scale; control_layout.aim.size = 130 * stick_scale; save_control_layout(); open_panel("pause")))
	settings.add_child(button("辅助瞄准：" + ("开" if aim_assist else "关"),func(): aim_assist = not aim_assist; save_control_layout(); open_panel("pause")))
	body.add_child(text("原型调试 · 用于快速检查完整昼夜，正常游玩建议 1×",15,Color("b7ab87")))
	var debug = HBoxContainer.new(); body.add_child(debug)
	for speed in [1,6,20]: debug.add_child(button("时间 %d×" % speed,func(): game.world.state.speed = speed; close_panel()))
	body.add_child(text("独立存档：LastCamp-FreeExploration-v0.6 / save.json\n旧版存档保留，本版暂不自动迁移；读档不重置世界时间。",15,Color("9eafa3")))
	body.add_child(text("美术：用户提供的 PostApocalypse 与生存物品素材包",13,Color("9eafa3")))
	body = pause_body

func failure_panel():
	body.add_child(text("本版没有核心防守失败。死亡后遗物保留在原处，玩家在有效落脚点恢复。",20))
	body.add_child(button("返回探索",func(): game.world.state.failed=false; close_panel()))

func battle_panel():
	var list=scroll_column(body,"最近探索记录")
	for message in game.world.logs: list.add_child(text(str(message),16))

func pause_icon() -> Texture2D:
	var image = Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(7,5,6,22),Color("e3e1c9")); image.fill_rect(Rect2i(19,5,6,22),Color("e3e1c9"))
	return ImageTexture.create_from_image(image)

func vital_icon(kind: String) -> Texture2D:
	if kind=="hp": return load("res://assets/postapocalypse/UI/HP/Heart_Full.png")
	if kind=="hunger": return load("res://assets/postapocalypse/UI/Hunger/Hunger_Full.png")
	return art.icon("water" if kind=="thirst" else "battery")

func build_vital_bars():
	var index=0
	for key in ["hp","stamina","hunger","thirst"]:
		var p=Vector2(18,12+index*34)
		var frame=TextureRect.new(); frame.texture=load("res://assets/postapocalypse/UI/HP/HP-Bar.png"); frame.position=p; frame.size=Vector2(165,36); frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; frame.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(frame)
		var icon=TextureRect.new(); icon.texture=vital_icon(key); icon.position=p; icon.size=Vector2(32,32); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(icon)
		var bar=TextureProgressBar.new(); bar.nine_patch_stretch=true; bar.position=p+Vector2(32,13); bar.size=Vector2(129,9); bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.texture_progress=load("res://assets/postapocalypse/UI/HP/HP.png")
		bar.tint_progress=Color(["ffffff","d5df92","e5ca85","98cadf"][index]); root.add_child(bar)
		var number=text("100",14); number.position=p+Vector2(176,6); root.add_child(number)
		vital_bars[key]={"bar":bar,"value":number}; index+=1

func reset_control_layout(persist: bool = true):
	control_layout.clear()
	var defaults={"bag":Vector2(914,16),"map":Vector2(984,16),"people":Vector2(1054,16),"camp":Vector2(1124,16),"pause":Vector2(1194,16),"survival":Vector2(1194,222),"reload":Vector2(1110,345),"bandage":Vector2(1194,300),"interact":Vector2(1194,390),"fire":Vector2(1182,490),"melee":Vector2(390,640),"secondary":Vector2(473,640),"primary":Vector2(556,640),"foodquick":Vector2(639,640),"waterquick":Vector2(722,640),"healquick":Vector2(805,640)}
	for key in defaults: control_layout[key]={"position":defaults[key],"size":80.0 if key=="fire" else (72.0 if key in ["melee","secondary","primary","foodquick","waterquick","healquick"] else 62.0)}
	control_layout.move={"position":Vector2(145,565),"size":146.0}; control_layout.aim={"position":Vector2(1040,550),"size":146.0}
	apply_control_layout()
	if persist: save_control_layout()

func apply_control_layout():
	for b in touch_buttons:
		if not is_instance_valid(b): continue
		var key = str(b.get_meta("action_name",""))
		if not control_layout.has(key): continue
		var settings = control_layout[key]; var extent = clampf(float(settings.size),56,160)
		b.custom_minimum_size=Vector2(extent,extent); b.size=Vector2(extent,extent)
		b.add_theme_constant_override("icon_max_width",int(extent))
		b.position=display_position(Vector2(settings.position)).clamp(display_bounds.position,display_bounds.end-b.size)
		settings.position=design_position(b.position); settings.size=extent
	for key in ["move","aim"]:
		var radius=float(control_layout[key].size)/2+8
		var pos=display_position(Vector2(control_layout[key].position)).clamp(display_bounds.position+Vector2(radius,150),display_bounds.end-Vector2(radius,radius))
		control_layout[key].position=design_position(pos)
		if key=="move": move_origin=pos
		else: aim_origin=pos
	if is_instance_valid(sticks): sticks.queue_redraw()

func save_control_layout():
	var cfg=ConfigFile.new()
	for key in control_layout:
		cfg.set_value(key,"position",control_layout[key].position); cfg.set_value(key,"size",control_layout[key].size)
	cfg.set_value("options","aim_assist",aim_assist); cfg.set_value("options","left_handed",left_handed)
	cfg.save(controls_path)

func load_control_layout():
	var cfg=ConfigFile.new()
	if cfg.load(controls_path)!=OK: return
	for key in control_layout:
		var pos=cfg.get_value(key,"position",control_layout[key].position); var extent=cfg.get_value(key,"size",control_layout[key].size)
		if pos is Vector2: control_layout[key].position=pos
		if extent is float or extent is int: control_layout[key].size=clampf(float(extent),100 if key in ["move","aim"] else 56,190 if key in ["move","aim"] else 160)
	aim_assist=bool(cfg.get_value("options","aim_assist",true)); left_handed=bool(cfg.get_value("options","left_handed",false)); apply_control_layout()

func joystick_scale(key: String) -> float:
	return float(control_layout.get(key,{"size":130.0}).size)/130.0

func point_on_action(point: Vector2) -> bool:
	for b in touch_buttons:
		if is_instance_valid(b) and b.has_meta("action_name") and b.is_visible_in_tree() and b.get_global_rect().has_point(point): return true
	return false

func control_rect(key: String) -> Rect2:
	if key in ["move","aim"]:
		var extent=float(control_layout[key].size); return Rect2(display_position(Vector2(control_layout[key].position))-Vector2.ONE*extent/2,Vector2.ONE*extent)
	return find_action_rect(key)

func begin_pinch():
	if world_touches.size()!=2: pinch_distance=0.0; return
	var points=world_touches.values(); pinch_distance=maxf(1,points[0].distance_to(points[1])); pinch_zoom=game.world_zoom

func start_layout_editor():
	open_panel("pause"); clear_body(); layout_editing=true; layout_touch=-1
	panel.position=Vector2(320,145); panel.size=Vector2(640,170)
	layout_label=text("拖动按钮或摇杆 · 当前："+selected_control,20); body.add_child(layout_label)
	var row=HBoxContainer.new(); body.add_child(row)
	row.add_child(button("缩小 −",func(): resize_selected_control(-8),Vector2(110,52)))
	row.add_child(button("放大 +",func(): resize_selected_control(8),Vector2(110,52)))
	row.add_child(button("恢复默认",func(): reset_control_layout(); update_layout_label(),Vector2(130,52)))
	row.add_child(button("保存并返回",func(): save_control_layout(); layout_editing=false; panel.position=Vector2(170,106); panel.size=Vector2(940,500); open_panel("pause"),Vector2(160,52)))
	body.add_child(text("双指捏合场景可缩放视野 · 布局独立于世界存档",15)); update_layout_label(); sticks.queue_redraw()

func update_layout_label():
	var names={"bag":"背包","map":"地图","people":"人员","camp":"住所","pause":"暂停","reload":"换弹","bandage":"绷带","interact":"互动","fire":"开火","melee":"近战","secondary":"副武器","primary":"主武器","survival":"生存操作","move":"移动摇杆","aim":"瞄准摇杆"}
	if is_instance_valid(layout_label): layout_label.text="拖动按钮或摇杆 · %s · 尺寸 %d" % [names.get(selected_control,selected_control),control_layout[selected_control].size]

func resize_selected_control(delta: float):
	var joystick=selected_control in ["move","aim"]
	control_layout[selected_control].size=clampf(control_layout[selected_control].size+delta,100 if joystick else 56,190 if joystick else 160)
	apply_control_layout(); update_layout_label(); save_control_layout()

func layout_input(event) -> bool:
	var point=Vector2.ZERO
	var pressed=false; var released=false; var pointer=-2
	if event is InputEventScreenTouch:
		point=event.position; pointer=event.index; pressed=event.pressed; released=not event.pressed
	elif event is InputEventScreenDrag: point=event.position; pointer=event.index
	elif event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION and event.button_index==MOUSE_BUTTON_LEFT:
		point=event.position; pointer=-3; pressed=event.pressed; released=not event.pressed
	elif event is InputEventMouseMotion and event.device!=InputEvent.DEVICE_ID_EMULATION: point=event.position; pointer=-3
	else: return false
	if pointer==layout_touch:
		if released: layout_touch=-1; save_control_layout()
		else: control_layout[selected_control].position=design_position(point+layout_offset); apply_control_layout()
		return true
	if not pressed or panel.get_global_rect().has_point(point): return false
	if layout_touch!=-1: return true
	for key in control_layout:
		if control_rect(key).has_point(point):
			selected_control=key; layout_touch=pointer; layout_offset=display_position(Vector2(control_layout[key].position))-point; update_layout_label(); sticks.queue_redraw(); return true
	return true



func survival_icon() -> Texture2D:
	return load("res://assets/postapocalypse/UI/Inventory/Objects/Icon_First-Aid-Kit_Red.png")

func mechanics_panel():
	var entries=scroll_column(body,"生存与环境 · 靠近门窗、家具、商人可出现更多操作")
	entries.add_child(text(game.mechanic_summary(),16))
	for entry in game.mechanic_actions():
		var request:Dictionary=entry.request.duplicate(true); var duration:float=entry.duration
		var b=button(entry.label,func(): game.request_mechanic(request,duration))
		b.disabled=not entry.get("enabled",true); entries.add_child(b)

