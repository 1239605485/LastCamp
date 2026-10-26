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
	var s = StyleBoxTexture.new()
	s.texture = load("res://assets/kenney/panel-blue.png" if light else "res://assets/kenney/panel-dark.png")
	s.modulate_color = Color(0.65,0.75,0.63) if light else Color(0.36,0.49,0.43)
	s.texture_margin_left = 5; s.texture_margin_right = 5; s.texture_margin_top = 5; s.texture_margin_bottom = 5
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 9; s.content_margin_bottom = 9
	return s

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
	var hud_back = Panel.new(); hud_back.position=Vector2(64,0); hud_back.size=Vector2(715,106); hud_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud_back.add_theme_stylebox_override("panel",style(Color(0.04,0.08,0.08,0.58),Color.TRANSPARENT)); root.add_child(hud_back)
	var portrait = TextureRect.new(); portrait.texture = gui_texture("portrait/gui_portrait_bg-sheet0.png"); portrait.position = Vector2(10,10); portrait.size = Vector2(40,58); portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; root.add_child(portrait)
	var face = TextureRect.new(); var face_tex=AtlasTexture.new(); face_tex.atlas=art.mini_player; face_tex.region=Rect2(8,0,16,17); face.texture=face_tex; face.position=Vector2(15,14); face.size=Vector2(30,34); face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; root.add_child(face)
	top = text("",15); top.position = Vector2(82,12); root.add_child(top)
	status = text("",15); status.position = Vector2(82,78); root.add_child(status)
	build_vital_bars()
	objective = text("",13,Color("e2cf9f")); objective.position = Vector2(18,109); root.add_child(objective)
	radio = text("",14); radio.position = Vector2(340,680); radio.size = Vector2(620,24); radio.clip_text = true; root.add_child(radio)
	var actions = [
		["bag","背包","inventory",func(): open_panel("bag")],
		["map","地图","zoom",func(): open_panel("map")],
		["people","人员","talk",func(): open_panel("people")],
		["camp","营地","builder",func(): open_panel("camp")],
		["pause","暂停","switch",func(): open_panel("pause")],
		["survival","生存操作","interact",func(): open_panel("mechanics")],
		["reload","换弹","reload",func(): game.reload_request()],
		["bandage","绷带","interact",func(): game.world.use_item("bandage")],
		["interact","互动","interact",func(): game.interact()],
		["fire","开火","attack",func(): pass]]
	for i in range(actions.size()):
		var e = actions[i]; var b = button("",e[3],Vector2(58,58)); b.size = Vector2(58,58); b.position = Vector2(1200,12+i*65); b.tooltip_text = e[1]; b.set_meta("action_name",e[0])
		b.icon = gui_texture("control/gui_btn_" + e[2] + "-sheet0.png")
		if e[0] == "bandage": b.icon = art.icon("bandage")
		if e[0] == "pause": b.icon = pause_icon()
		if e[0] == "survival": b.icon = survival_icon()
		if e[0] == "camp": b.icon=load("res://assets/minidayz/icons/building_hammer.png")
		prepare_action_icon(b)
		b.expand_icon = true; b.add_theme_constant_override("icon_max_width",56); root.add_child(b)
		if e[0] == "fire": b.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.set_meta("fire_control",true)
	for i in range(3):
		var index = i; var b = button("",func():
			if index == 0: game.world.state.weapon = "knife"
			else: game.cycle_weapon("sidearm" if index == 1 else "primary"),Vector2(54,48))
		b.set_meta("action_name",["melee","secondary","primary"][i]); b.tooltip_text = ["近战武器","副武器","主武器"][i]
		b.icon = art.icon(["knife","pm","ak74"][i]); b.expand_icon = true; b.add_theme_constant_override("icon_max_width",56)
		b.position = Vector2(1010+i*60,650); root.add_child(b)
		prepare_action_icon(b)
	progress = ProgressBar.new(); progress.position = Vector2(495,594); progress.size = Vector2(290,12); progress.visible = false; progress.show_percentage = false; root.add_child(progress)
	progress_label = text("",16); progress_label.position = Vector2(510,565); root.add_child(progress_label)
	new_world_dialog = ConfirmationDialog.new(); new_world_dialog.title = "新世界"; new_world_dialog.dialog_text = "清除当前世界并重新开始？"; root.add_child(new_world_dialog)
	new_world_dialog.confirmed.connect(func(): game.start_new_game())
	sticks = Control.new(); sticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(sticks)
	sticks.draw.connect(draw_sticks)
	panel = PanelContainer.new(); panel.position = Vector2(170,106); panel.size = Vector2(940,500); panel.visible = false; root.add_child(panel)
	var parchment = StyleBoxTexture.new(); var paper=AtlasTexture.new(); paper.atlas=gui_texture("inventory/gui_inventory_card_cover.png"); paper.region=Rect2(0,0,228,66); parchment.texture=paper; parchment.texture_margin_left = 7; parchment.texture_margin_right = 7; parchment.texture_margin_top = 7; parchment.texture_margin_bottom = 7; parchment.content_margin_left = 16; parchment.content_margin_right = 16; parchment.content_margin_top = 12; parchment.content_margin_bottom = 12; panel.add_theme_stylebox_override("panel",parchment)
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
	radio.position = display_bounds.position+Vector2((display_bounds.size.x-620)/2,display_bounds.size.y-40)
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
		var backing = style(Color(0.06,0.11,0.10,0.38),Color(0.70,0.76,0.63,0.32),5)
		backing.set_content_margin_all(0)
		if state=="pressed": backing.bg_color=Color(0.42,0.47,0.31,0.7)
		b.add_theme_stylebox_override(state,backing)

func gui_texture(path: String) -> Texture2D:
	var full = "res://assets/minidayz/gui/" + path
	var texture: Texture2D
	if ResourceLoader.exists(full): texture=load(full)
	else:
		var image=Image.load_from_file(full); texture=ImageTexture.create_from_image(image) if image!=null else null
	var region=Rect2()
	if path=="portrait/gui_portrait_bg-sheet0.png": region=Rect2(0,0,42,64)
	elif path=="control/gui_btn_interact-sheet0.png": region=Rect2(63,11,41,41)
	if region.has_area():
		var cropped=AtlasTexture.new(); cropped.atlas=texture; cropped.region=region; return cropped
	return texture

func find_action_rect(action_name: String) -> Rect2:
	for b in touch_buttons:
		if is_instance_valid(b) and b.get_meta("action_name", "") == action_name: return b.get_global_rect()
	return Rect2()

func text(message: String, size: int = 18, color: Color = Color("e1e4d3")) -> Label:
	if not panel_kind.is_empty(): color=color.darkened(0.68)
	var label = Label.new(); label.text = message; label.add_theme_font_size_override("font_size",size); label.add_theme_color_override("font_color",color)
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
	top.text = "DAY %02d   %02d:%02d   %s" % [day,minute / 60,minute % 60,"营地 · 北侧防线" if s.zone == "camp" else w.map.region_name(game.player_pos())]
	var gun_id = w.player_weapon(s.weapon); var ammo = ""
	if not gun_id.is_empty() and w.items[gun_id].has("ammo"):
		var gun = w.items[gun_id]; ammo = " %d/%d · 备弹%d" % [gun.ammo,R.capacity_for(gun),w.count_item(R.ITEMS[gun.def].ammo)]
	status.text = "%s%s   %.1f/%.0f kg%s" % [R.ITEMS[s.weapon].name,ammo,w.weight("player"),w.capacity,"   流血！" if s.bleeding else ""]
	for key in vital_bars:
		vital_bars[key].bar.value = s[key]; vital_bars[key].value.text = str(int(s[key]))
	status.add_theme_font_size_override("font_size",15)
	var night = minute >= 1260 or minute < 360
	objective.text = ("尸潮进行中" if night else "21:00 北侧防线") + "   ·   北墙 %d   核心 %d   守卫弹药 %d" % [s.wall,s.core,s.guard_ammo]
	if s.has("systems_v5"):
		objective.text+=" · %s 疲劳%d%s" % [game.Survival.WEATHER_NAMES.get(s.systems_v5.weather,"晴"),s.systems_v5.fatigue," 休息中" if s.systems_v5.resting else ""]
	if s.zone == "town" and s.has("waypoint"):
		objective.text += "  目标 %.0fm" % (game.player_pos().distance_to(Vector2(s.waypoint[0],s.waypoint[1])) / 32)
	if not w.logs.is_empty(): radio.text = "[无线电]  " + str(w.logs.back())
	progress.visible = not game.action.is_empty()
	progress_label.visible = progress.visible
	if progress.visible:
		progress.value = (1.0 - game.action.remaining / maxf(game.action.duration,0.01)) * 100
		progress_label.text = "采集中…" if game.action.get("kind","")=="harvest" else ("搜寻…" if game.action.get("kind","") in ["search","transfer"] else "进行中…")
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
	var titles = {"mechanics":"生存操作","camp":"营地防线", "bag":"随身背包", "loot":"搜刮与转移", "parts":"枪械配件", "people":"幸存者", "map":"区域地图", "pause":"暂停 · 世界时间已停止", "failure":"本夜防守失败", "battle":"战后记录 · 本夜守住了"}
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
		help.add_child(text("食物与饮水可在背包中使用。\n\n物资不会因进出建筑刷新。\n所有随身物品在死亡后留下遗物。\n\n靠近营地北墙可消耗木材修理。\n小柜子清空后可打包带走。\n\n装备与地图菜单暂停整个世界。",17))

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
		list.add_child(text("尚未携带枪械。\n营地东侧军械箱提供测试装备。",17)); return
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
	var people_entries = scroll_column(body,"幸存者与营地分工")
	body.add_child(text("最多1名随行；倒地保留原位，需要靠近并持续救援。守卫共享独立营地弹药。",16))
	for n in w.npcs:
		var row = HBoxContainer.new(); people_entries.add_child(row)
		var states = {"healthy":"健康","injured":"负伤","down":"倒地待救","waiting":"待招募"}
		var label = text("%s  |  %s  |  %s  HP%d  |  %s  经验%d" % [n.name,n.job,states.get(n.status,n.status),n.hp,"营地" if n.zone == "camp" else "榆树镇",n.xp],17)
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
	body.add_child(text("完整地图 · %d处聚落 / %d处建筑 · 黄点玩家 / 绿点营地" % [w.map.sectors.size(),w.map.buildings.size()],16))
	var display = preload("res://scripts/map_screen.gd").new(); display.game = game; body.add_child(display)
	var row = HBoxContainer.new(); body.add_child(row)
	row.add_child(button("放大 +",func(): display.change_zoom(1.5)))
	row.add_child(button("缩小 −",func(): display.change_zoom(0.67)))
	row.add_child(button("定位玩家",func(): display.center = game.player_pos() if w.state.zone == "town" else Vector2(45,490); display.zoom = 3; display.queue_redraw()))
	row.add_child(button("清除目标",func(): w.state.erase("waypoint"); display.queue_redraw()))
	row.add_child(text("拖动查看 · 点按标记目标，不传送",15))

func camp_panel():
	var list = scroll_column(body,"营地防线 · 角色附近建造，靠近设施互动维修")
	for e in [["barricade","木路障"],["wire","铁丝网"],["guardpost","岗哨"]]:
		var kind: String = e[0]
		list.add_child(button(e[1] + " · 建造",func(): close_panel(); game.start_defense(kind)))
	for defense in game.world.defenses:
		list.add_child(text("%s  耐久 %d" % [defense.get("kind","设施"),defense.get("hp",0)],17))

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
	body.add_child(text("保存目录：user://save.json · 清晨恢复点：user://dawn.json\n第一版验证一天闭环，多日补给经济仍待平衡。",15,Color("9eafa3")))
	body.add_child(text("美术：Orven（免费版非商业） / Kenney（CC0） / CobraLad（CC-BY-SA 3.0）",13,Color("9eafa3")))
	body = pause_body

func failure_panel():
	body.add_child(text("避难屋核心已失守。世界已停止。\n北墙破损可修复；核心完全失守需要回到最近清晨。\n重试会同时恢复物品、人员、遗物、敌人与时间。",21,Color("dab296")))
	body.add_child(button("读取清晨恢复点重试",func():
		if game.world.load_game(game.world.dawn_path()):
			game.world.state.failed = false; game.world.save_game(); close_panel()))
	body.add_child(button("保存失败结算并退出",func(): game.world.save_game(); get_tree().quit()))

func battle_panel():
	var report = game.world.state.battle_report
	body.add_child(text("第%d天夜战结束\n\n守卫消耗弹药：%d 发\n北墙耐久损失：%d\n核心剩余耐久：%d\n倒地待救人员：%d" % [report.day,report.ammo,report.wall_lost,report.core,report.down],22,Color("d9d9bb")))
	body.add_child(text("世界会从当前时间继续，天亮前不会自动传送。\n下一天保留库存、伤势、遗物和防线。",18))
	body.add_child(button("整理营地并继续",close_panel))

func pause_icon() -> Texture2D:
	var image = Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(7,5,6,22),Color("e3e1c9")); image.fill_rect(Rect2i(19,5,6,22),Color("e3e1c9"))
	return ImageTexture.create_from_image(image)

func vital_icon(kind: String) -> Texture2D:
	if kind == "hunger": return art.icon("food")
	if kind == "thirst": return art.icon("water")
	var image = Image.create(16,16,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	var rows = ["01100110","11111111","11111111","01111110","00111100","00011000"] if kind == "hp" else ["00011000","00110000","01100000","11111110","00011100","00111000","00110000","01100000"]
	for y in range(rows.size()):
		for x in range(8):
			if rows[y][x] == "1": image.set_pixel(x+4,y+4,Color("e46661") if kind == "hp" else Color("efcf77"))
	return ImageTexture.create_from_image(image)

func build_vital_bars():
	var index = 0
	for key in ["hp","hunger","thirst","stamina"]:
		var p = Vector2(82+index*174,43)
		var icon = TextureRect.new(); icon.texture = vital_icon(key); icon.position = p; icon.size = Vector2(28,28); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(icon)
		var bar = ProgressBar.new(); bar.position = p+Vector2(34,6); bar.size=Vector2(98,16); bar.show_percentage=false; bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background",style(Color("162322"),Color("64796a")))
		bar.add_theme_stylebox_override("fill",style(Color(["ca5658","c99d50","518fba","6aa87c"][index]),Color.TRANSPARENT)); root.add_child(bar)
		var number=text("100",14); number.position=p+Vector2(136,1); root.add_child(number)
		vital_bars[key]={"bar":bar,"value":number}; index+=1

func reset_control_layout(persist: bool = true):
	control_layout.clear()
	var defaults = {"bag":Vector2(870,12),"map":Vector2(950,12),"people":Vector2(1030,12),"camp":Vector2(1110,12),"pause":Vector2(1190,12),"survival":Vector2(1110,185),"reload":Vector2(1028,360),"bandage":Vector2(1110,280),"interact":Vector2(1190,350),"fire":Vector2(1182,450),"melee":Vector2(870,640),"secondary":Vector2(950,640),"primary":Vector2(1030,640)}
	for key in defaults: control_layout[key]={"position":defaults[key],"size":80.0 if key=="fire" else 72.0}
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
	var names={"bag":"背包","map":"地图","people":"人员","camp":"营地","pause":"暂停","reload":"换弹","bandage":"绷带","interact":"互动","fire":"开火","melee":"近战","secondary":"副武器","primary":"主武器","survival":"生存操作","move":"移动摇杆","aim":"瞄准摇杆"}
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
	var image=Image.create(24,24,false,Image.FORMAT_RGBA8); image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(2,5,20,16),Color("a08b62")); image.fill_rect(Rect2i(8,2,8,5),Color("69765c"))
	image.fill_rect(Rect2i(5,8,14,10),Color("354c45")); image.fill_rect(Rect2i(10,8,4,10),Color("dac99d")); image.fill_rect(Rect2i(7,11,10,4),Color("dac99d"))
	return ImageTexture.create_from_image(image)

func mechanics_panel():
	var entries=scroll_column(body,"生存与环境 · 靠近门窗、家具、商人可出现更多操作")
	entries.add_child(text(game.mechanic_summary(),16))
	for entry in game.mechanic_actions():
		var request:Dictionary=entry.request.duplicate(true); var duration:float=entry.duration
		var b=button(entry.label,func(): game.request_mechanic(request,duration))
		b.disabled=not entry.get("enabled",true); entries.add_child(b)
