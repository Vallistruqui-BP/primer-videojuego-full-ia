extends RefCounted

const PATH := "res://data/office_layout.json"
const LOCAL_PATH := "user://office-layout-draft.json"
const KINDS := ["desk","desk_square","chair","table","sofa","reception","core","plant","wall"]

static func canonical() -> Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string(PATH))

static func validate(data: Variant) -> String:
 if not data is Dictionary or data.get("schema") != 1: return "Formato de mapa no compatible."
 if not data.get("objects") is Array or data.objects.size()>250: return "El mapa admite hasta 250 piezas."
 var outline := PackedVector2Array()
 for point in canonical().outline:
  outline.append(Vector2(point[0],point[1]))
 var ids := {}
 for item in data.objects:
  if not item is Dictionary: return "Pieza inválida."
  if not item.get("id") is String or item.id.is_empty() or item.id.length()>64 or ids.has(item.id): return "Identificador de pieza inválido o repetido."
  ids[item.id] = true
  if not item.get("kind") in KINDS or item.get("zone") != "office": return "Tipo de pieza no compatible."
  for key in ["x","y","w","d","rotation"]:
   if not (item.get(key) is float or item.get(key) is int) or not is_finite(float(item[key])): return "Coordenadas inválidas."
  if item.x<0 or item.x>1230 or item.y<90 or item.y>880 or item.w<4 or item.w>200 or item.d<4 or item.d>200 or absf(item.rotation)>TAU: return "La pieza excede los límites del mapa."
  if not footprint_fits(item,outline): return "La pieza debe quedar dentro del contorno de la oficina."
 return ""

static func footprint_fits(item: Dictionary,outline: PackedVector2Array) -> bool:
 var center := Vector2(item.x,item.y)
 var half := Vector2(item.w,item.d)*0.5
 var footprint := PackedVector2Array()
 for corner in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),half,Vector2(-half.x,half.y)]:
  footprint.append(center+corner.rotated(-float(item.rotation)))
 # Polygon difference also detects edges passing over the concave notch.
 return Geometry2D.clip_polygons(footprint,outline).is_empty()

static func sanitized(data: Dictionary) -> Dictionary:
 # Only editable pieces are imported; structural outline and interaction anchors stay canonical.
 var result := canonical()
 result.objects = data.objects.duplicate(true)
 return result

static func load_local() -> Dictionary:
 if FileAccess.file_exists(LOCAL_PATH):
  var value = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_PATH))
  if validate(value).is_empty(): return sanitized(value)
 return canonical()

static func save_local(data: Dictionary) -> bool:
 if not validate(data).is_empty(): return false
 var file := FileAccess.open(LOCAL_PATH,FileAccess.WRITE)
 if not file: return false
 file.store_string(JSON.stringify(sanitized(data),"  "))
 return true
