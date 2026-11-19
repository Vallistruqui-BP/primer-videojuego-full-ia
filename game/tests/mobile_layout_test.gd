extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
 var office = load("res://scenes/office.tscn").instantiate()
 root.add_child(office)
 await process_frame
 for viewport_size in [Vector2i(320,568),Vector2i(390,844),Vector2i(412,915),Vector2i(844,390)]:
  root.size = viewport_size
  await process_frame
  await process_frame
  var right: Button
  var menu: Button
  var network_menu: Button
  for item in office.hud.get_children():
   if item is Button:
    if item.text == "D": right = item
    if item.text == "Personaje y juegos": menu = item
    if item.text == "Jugar con alguien": network_menu = item
  var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
  var interact: Button = office.hub.interact_button
  if right.get_global_rect().intersects(interact.get_global_rect()):
   printerr("MOBILE_LAYOUT_FAIL movement overlaps interaction ",viewport_size)
   quit(1)
   return
  for button in [menu,network_menu,right,interact]:
   if not viewport_rect.encloses(button.get_global_rect()):
    printerr("MOBILE_LAYOUT_FAIL clipped control ",button.text," ",viewport_size)
    quit(1)
    return
  if menu.get_global_rect().intersects(network_menu.get_global_rect()):
   printerr("MOBILE_LAYOUT_FAIL menu overlap")
   quit(1)
   return
 print("MOBILE_LAYOUT_PASS four_viewports movement interaction menus")
 quit(0)
