extends Node2D

var hub: Node
var player: CharacterBody2D
var camera: Camera2D
var status_label: Label
var map_mode := true
var network: Node
var remote_players := {}
var hud: Control
var title_label: Label
var zoom_button: Button
var footer: Label
var reset_button: Button

func _ready() -> void:
 # Web canvas dimensions use physical pixels; keep controls in CSS pixels.
 if OS.has_feature("web"):
  get_window().content_scale_factor = maxf(1.0,float(JavaScriptBridge.eval("window.devicePixelRatio || 1",true)))
 RenderingServer.set_default_clear_color(Color("203d35"))
 var map := Node2D.new()
 map.set_script(load("res://scripts/office_map.gd"))
 add_child(map)
 player = CharacterBody2D.new()
 player.set_script(load("res://scripts/office_player.gd"))
 player.position = Vector2(620,790)
 player.z_index = 10
 add_child(player)
 camera = Camera2D.new()
 add_child(camera)
 build_ui()
 map_mode = get_viewport_rect().size.x >= 650
 get_viewport().size_changed.connect(resize)
 resize()
 if ResourceLoader.exists("res://scripts/office_network.gd"):
  network = Node.new()
  network.set_script(load("res://scripts/office_network.gd"))
  add_child(network)
  network.attach(self)
 hub = load("res://scripts/playground_hub.gd").new()
 add_child(hub)
 hub.attach(self)
 call_deferred("layout_playground_controls")

func _process(_delta: float) -> void:
 if OS.has_feature("web"):
  var ratio := maxf(1.0,float(JavaScriptBridge.eval("window.devicePixelRatio || 1",true)))
  if absf(get_window().content_scale_factor-ratio)>0.01: get_window().content_scale_factor = ratio
 if hub and hub.zone != "office":
  camera.position = Vector2(2100,550)
  camera.zoom = Vector2.ONE * minf((get_viewport_rect().size.x-20)/640.0,(get_viewport_rect().size.y-210)/460.0)
 elif not map_mode: camera.position = player.position
 if OS.has_feature("web"):
  JavaScriptBridge.eval("window.officePreviewState=" + JSON.stringify({"x":player.position.x,"y":player.position.y,"peers":remote_players.size(),"room":network.match_id if network else "","status":status_label.text,"zone":hub.zone if hub else "office","screen":hub.screen if hub else "","game":hub.game.get("kind","") if hub else ""}),true)

func resize() -> void:
 var size := get_viewport_rect().size
 var factor := minf((size.x-36)/1260.0,(size.y-190)/900.0)
 if map_mode:
  camera.position = Vector2(625,465)
  camera.zoom = Vector2.ONE * maxf(0.15,factor)
 else: camera.zoom = Vector2.ONE * 1.4
 title_label.text = "LÍDERES  /  PLAYGROUND" if size.x > 650 else "LÍDERES"
 title_label.add_theme_font_size_override("font_size",22 if size.x>650 else 16)
 zoom_button.text = "Seguir" if map_mode else "Mapa"
 status_label.size = Vector2(maxf(100,size.x-56),42)
 footer.visible = size.x > 650
 call_deferred("layout_playground_controls")

func layout_playground_controls() -> void:
 if not hub or not network: return
 var viewport_size := get_viewport_rect().size
 # Keep the interaction target clear of the fixed 146px direction pad.
 var interaction: Button = hub.interact_button
 var interaction_width := minf(185,viewport_size.x-190)
 interaction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 interaction.offset_left = -interaction_width-18
 interaction.offset_right = -18
 interaction.offset_top = -126
 interaction.offset_bottom = -62
 var menus: Array[Button] = []
 for item in hud.get_children():
  if item is Button and item.text in ["Jugar con alguien","Personaje y juegos"]:
   menus.append(item)
 for i in range(menus.size()):
  var stacked := viewport_size.x < 370
  menus[i].position = Vector2(18 if stacked else 18+i*162,144+i*46 if stacked else 144)
  menus[i].size = Vector2(viewport_size.x-36 if stacked else 152,40)
 if network.has_method("resize_dialog"): network.resize_dialog()

func build_ui() -> void:
 var layer := CanvasLayer.new()
 add_child(layer)
 hud = Control.new()
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 layer.add_child(hud)
 var top := PanelContainer.new()
 top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 top.offset_left = 18
 top.offset_top = 18
 top.offset_right = -18
 top.offset_bottom = 82
 top.add_theme_stylebox_override("panel",style(Color("f3eddf")))
 hud.add_child(top)
 var row := HBoxContainer.new()
 top.add_child(row)
 title_label = Label.new()
 title_label.add_theme_color_override("font_color",Color("203d35"))
 title_label.add_theme_font_size_override("font_size",22)
 title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(title_label)
 var zoom := Button.new()
 zoom_button = zoom
 zoom.text = "Seguir / mapa"
 zoom.pressed.connect(func(): map_mode = not map_mode; resize())
 row.add_child(zoom)
 var reset := Button.new()
 reset_button = reset
 reset.text = "Volver"
 reset.pressed.connect(func():
  if network and not network.match_id.is_empty(): network.leave()
  player.position = Vector2(620,790))
 row.add_child(reset)
 status_label = Label.new()
 status_label.position = Vector2(28,94)
 # Set the wrapping width before text establishes its minimum height.
 status_label.size = Vector2(maxf(100,get_viewport_rect().size.x-56),42)
 status_label.text = "Exploración local · WASD o flechas"
 status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 status_label.add_theme_color_override("font_color",Color("d8e4ce"))
 status_label.add_theme_font_size_override("font_size",14)
 var status_style := StyleBoxFlat.new()
 status_style.bg_color = Color("203d35e8")
 status_style.set_corner_radius_all(4)
 status_style.content_margin_left = 6
 status_label.add_theme_stylebox_override("normal",status_style)
 hud.add_child(status_label)
 footer = Label.new()
 footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
 footer.offset_left = -290
 footer.offset_top = -58
 footer.offset_right = -20
 footer.text = "OFICINA JUGABLE\nCreá · compartí · jugá"
 footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
 footer.add_theme_font_size_override("font_size",12)
 footer.add_theme_color_override("font_color",Color("c9d7bd"))
 hud.add_child(footer)
 for item in [["W",Vector2(68,-154),Vector2.UP],["A",Vector2(18,-104),Vector2.LEFT],["S",Vector2(68,-104),Vector2.DOWN],["D",Vector2(118,-104),Vector2.RIGHT]]:
  var button := Button.new()
  button.text = item[0]
  hud.add_child(button)
  button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
  button.offset_left = item[1].x
  button.offset_top = item[1].y
  button.offset_right = item[1].x+46
  button.offset_bottom = item[1].y+46
  button.size = Vector2(46,46)
  button.focus_mode = Control.FOCUS_NONE
  button.button_down.connect(func(): player.touch_input = item[2])
  button.button_up.connect(func(): player.touch_input = Vector2.ZERO)

func style(color: Color) -> StyleBoxFlat:
 var result := StyleBoxFlat.new()
 result.bg_color = color
 result.set_corner_radius_all(10)
 result.content_margin_left = 18
 result.content_margin_right = 12
 result.content_margin_top = 10
 result.content_margin_bottom = 10
 return result
