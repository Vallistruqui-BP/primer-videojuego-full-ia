extends Node2D

const DESK_TEXTURE: Texture2D = preload("res://art/office/desk.png")
const SQUARE_DESK_TEXTURE: Texture2D = preload("res://art/office/desk_square.png")
const CHAIR_TEXTURE: Texture2D = preload("res://art/office/chair.png")
const DOOR_TEXTURE: Texture2D = preload("res://art/office/door.png")

var OUTLINE := PackedVector2Array([Vector2(20,440),Vector2(700,440),Vector2(700,90),Vector2(1130,90),Vector2(1130,690),Vector2(1230,780),Vector2(1130,880),Vector2(980,840),Vector2(20,840)])
var walls: Array[Rect2] = []
var furniture: Array[Dictionary] = []
var rooms: Array[Dictionary] = []
var labels: Array[Dictionary] = []
var plants: Array[Vector2] = []
var door_visuals: Array[Dictionary] = []

func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 room(Rect2(20,440,115,140), "Oficina 1", Color("e6d8bc"))
 room(Rect2(20,580,115,110), "Oficina 2", Color("e4d6bd"))
 room(Rect2(20,690,115,150), "Oficina 3", Color("e8d9bf"))
 room(Rect2(700,90,205,105), "Oficina norte", Color("dbe3d8"))
 room(Rect2(700,195,205,110), "Reunión breve", Color("dbe3d8"))
 room(Rect2(700,305,205,100), "Sala común", Color("e1dfd1"))
 room(Rect2(700,405,205,70), "Salas privadas", Color("e1dfd1"))
 room(Rect2(520,440,180,150), "Baños", Color("d6e2e0"), true)
 box(Rect2(710,530,200,80), "core")
 labels.append({"p":Vector2(725,577),"text":"ESCALERA  /  ASCENSOR"})
 for x in [250,350,450]:
  for y in [480,525,570]: box(Rect2(x,y,55,27), "desk")
 for x in [235,335,435,535]:
  for y in [680,725,770]: box(Rect2(x,y,54,27), "desk")
 box(Rect2(285,625,160,22), "table")
 for y in [140,260,370,480,590]:
  for x in [985,1040]: box(Rect2(x,y,44,45), "desk")
 for y in [475,610,735]: box(Rect2(45,y,43,22), "desk")
 box(Rect2(735,125,54,25), "desk")
 box(Rect2(785,235,60,30), "table")
 box(Rect2(735,340,100,28), "sofa")
 box(Rect2(775,680,90,26), "reception")
 box(Rect2(1060,765,85,30), "table")
 plants = [Vector2(155,465),Vector2(490,630),Vector2(680,800),Vector2(930,115),Vector2(1100,640),Vector2(1020,750),Vector2(740,680)]
 labels.append({"p":Vector2(265,460),"text":"ESTUDIO OESTE"})
 labels.append({"p":Vector2(975,120),"text":"ESTUDIO NORTE"})
 labels.append({"p":Vector2(790,735),"text":"RECEPCIÓN"})
 labels.append({"p":Vector2(990,700),"text":"LOUNGE"})
 labels.append({"p":Vector2(1040,825),"text":"SALA DE REUNIONES"})
 labels.append({"p":Vector2(580,827),"text":"ENTRADA"})
 for i in range(OUTLINE.size()):
  var a := OUTLINE[i]
  var b := OUTLINE[(i + 1) % OUTLINE.size()]
  var body := StaticBody2D.new()
  var shape := CollisionShape2D.new()
  var segment := SegmentShape2D.new()
  segment.a = a
  segment.b = b
  shape.shape = segment
  body.add_child(shape)
  add_child(body)
 queue_redraw()

func solid(rect: Rect2) -> void:
 var body := StaticBody2D.new()
 var collision := CollisionShape2D.new()
 var shape := RectangleShape2D.new()
 shape.size = rect.size
 collision.shape = shape
 body.position = rect.get_center()
 body.add_child(collision)
 add_child(body)

func wall(rect: Rect2) -> void:
 walls.append(rect)
 solid(rect)

func room(rect: Rect2, title: String, color: Color, south_door := false) -> void:
 rooms.append({"rect":rect,"title":title,"color":color})
 wall(Rect2(rect.position,Vector2(rect.size.x,6)))
 wall(Rect2(rect.position,Vector2(6,rect.size.y)))
 if south_door:
  door_visuals.append({"center":Vector2(rect.get_center().x,rect.end.y-3),"width":rect.size.x-110,"rotation":0.0})
  wall(Rect2(rect.end.x-6,rect.position.y,6,rect.size.y))
  wall(Rect2(rect.position.x,rect.end.y-6,55,6))
  wall(Rect2(rect.end.x-55,rect.end.y-6,55,6))
 else:
  door_visuals.append({"center":Vector2(rect.end.x-3,rect.get_center().y),"width":44.0,"rotation":PI/2})
  wall(Rect2(rect.position.x,rect.end.y-6,rect.size.x,6))
  wall(Rect2(rect.end.x-6,rect.position.y,6,rect.size.y/2-22))
  wall(Rect2(rect.end.x-6,rect.position.y+rect.size.y/2+22,6,rect.size.y/2-22))

func box(rect: Rect2, kind: String) -> void:
 furniture.append({"rect":rect,"kind":kind})
 solid(rect)

func _draw() -> void:
 draw_colored_polygon(OUTLINE,Color("eee8db"))
 for x in range(24,1230,24):
  for y in range(96,840,24):
   if Geometry2D.is_point_in_polygon(Vector2(x,y),OUTLINE):
    draw_rect(Rect2(x,y,22,22),Color("e4ddcc"),false,1)
 for item in rooms:
  draw_rect(item.rect,item.color)
  draw_string(ThemeDB.fallback_font,item.rect.position+Vector2(12,item.rect.size.y-15),item.title,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("4a635e"))
 for rect in walls:
  draw_rect(Rect2(rect.position+Vector2(2,4),rect.size),Color(0,0,0,0.1))
  draw_rect(rect,Color("52675e"))
 # Open thresholds decorate the existing passages; collision geometry is unchanged.
 for door in door_visuals:
  draw_set_transform(door.center,door.rotation)
  draw_texture_rect(DOOR_TEXTURE,Rect2(-door.width/2,-6,door.width,12),false)
 draw_set_transform(Vector2.ZERO)
 for item in furniture:
  var rect: Rect2 = item.rect
  draw_rect(Rect2(rect.position+Vector2(2,3),rect.size),Color(0,0,0,0.12))
  if item.kind == "desk":
   var desk_texture := SQUARE_DESK_TEXTURE if rect.size.x < rect.size.y * 1.5 else DESK_TEXTURE
   draw_texture_rect(desk_texture,rect,false)
   draw_texture_rect(CHAIR_TEXTURE,Rect2(rect.get_center().x-6,rect.end.y+2,12,12),false)
   continue
  var color := Color("cba77b")
  if item.kind == "core": color = Color("c4cbc3")
  if item.kind == "sofa": color = Color("80a59b")
  if item.kind == "reception": color = Color("375f56")
  draw_rect(rect,Color("675a48"))
  draw_rect(rect.grow(-2),color)
 for pos in plants:
  draw_circle(pos+Vector2(1,3),11,Color("a58a69"))
  draw_circle(pos,10,Color("456f55"))
  draw_circle(pos+Vector2(-4,-3),6,Color("729c6f"))
 for item in labels: draw_string(ThemeDB.fallback_font,item.p,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("5b7066"))
 var closed := OUTLINE.duplicate()
 closed.append(OUTLINE[0])
 draw_polyline(closed,Color("52675e"),7,false)
 # Interactive box; proximity/action handled by playground_hub.
 draw_rect(Rect2(655,809,12,15),Color("368e89"))

func panel(color: Color) -> StyleBoxFlat:
 var result := StyleBoxFlat.new()
 result.bg_color = color
 result.set_corner_radius_all(3)
 return result
