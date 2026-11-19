extends Node2D
var zone := "office"
func _draw() -> void:
 # Original pixel furniture and portal art; no external sprite licenses required.
 for portal in [{"p":Vector2(920,685),"label":"ARCADE","color":Color("b577bc")},{"p":Vector2(470,635),"label":"TALLER","color":Color("e4ba62")}]:
  var p: Vector2 = portal.p
  draw_rect(Rect2(p+Vector2(-18,-36),Vector2(36,40)),Color("324941"))
  draw_rect(Rect2(p+Vector2(-13,-31),Vector2(26,34)),portal.color)
  draw_rect(Rect2(p+Vector2(6,-17),Vector2(3,3)),Color("fff1c9"))
  draw_string(ThemeDB.fallback_font,p+Vector2(-28,18),portal.label,HORIZONTAL_ALIGNMENT_CENTER,56,10,Color("455d50"))
 draw_rect(Rect2(650,797,22,25),Color("357a77"))
 draw_rect(Rect2(654,802,14,3),Color("1f3935"))
 draw_string(ThemeDB.fallback_font,Vector2(646,837),"BUZÓN",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("355c51"))
 var floor_color := Color("333d55") if zone == "arcade" else Color("425747")
 draw_rect(Rect2(1780,300,640,470),Color("192c29"))
 draw_rect(Rect2(1800,320,600,430),floor_color)
 for x in range(1800,2400,24):
  for y in range(320,750,24): draw_rect(Rect2(x,y,22,22),floor_color.lightened(0.05),false,1)
 var names := ["SNAKE","TERMINAL","PONG","TA-TE-TI","MEMORIA","TRIVIA"]
 for i in range(6):
  var p := Vector2(1870+(i%3)*220,390+(i/3)*150)
  var c := Color("b577bc") if zone == "arcade" else Color("dbb56a")
  draw_rect(Rect2(p-Vector2(24,36),Vector2(48,54)),Color("1e2e39"))
  draw_rect(Rect2(p-Vector2(20,32),Vector2(40,26)),c)
  draw_rect(Rect2(p-Vector2(16,28),Vector2(32,18)),Color("8cbab1"))
  draw_rect(Rect2(p+Vector2(-18,0),Vector2(36,7)),c.darkened(0.2))
  draw_string(ThemeDB.fallback_font,p+Vector2(-50,37),names[i],HORIZONTAL_ALIGNMENT_CENTER,100,12,Color("faf0d8"))
 draw_rect(Rect2(2075,708,50,42),Color("cdbd8d"))
 draw_string(ThemeDB.fallback_font,Vector2(2050,701),"OFICINA",HORIZONTAL_ALIGNMENT_CENTER,100,14,Color("faf0d8"))
