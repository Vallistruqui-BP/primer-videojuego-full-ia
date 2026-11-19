extends VBoxContainer
signal action(data: Dictionary)
var state := {}
var score: Label
var hint: Label
var canvas: Control
var cells: Array[Button] = []
var question: Label
var options: Array[Button] = []
var pong_axis := 0.0
var built := false
var direction_labels := ["W","D","S","A"]

class BoardCanvas extends Control:
 var snapshot := {}
 func _draw() -> void:
  if snapshot.is_empty(): return
  var scale_factor: float = minf(size.x/640.0,size.y/360.0)
  draw_set_transform(Vector2.ZERO,0,Vector2(scale_factor,scale_factor))
  draw_rect(Rect2(0,0,640,360),Color("162d2b"))
  if snapshot.kind == "pong":
   draw_line(Vector2(320,0),Vector2(320,360),Color("4b6b5e"),2)
   for i in range(2): draw_rect(Rect2(20+i*584,float(snapshot.paddles[i])-35,12,70),Color("c4dca1") if i==0 else Color("e1aa7b"))
   draw_rect(Rect2(float(snapshot.ball.x)-7,float(snapshot.ball.y)-7,14,14),Color("f1e5b4"))
  elif snapshot.kind == "snake":
   var n: int = int(snapshot.size)
   var unit: float = 280.0/n
   for i in range(2):
    var origin := Vector2(15+i*325,40)
    draw_rect(Rect2(origin,Vector2(280,280)),Color("4d6a4a"),false,2)
    var snake: Dictionary = snapshot.snakes[i]
    for p in snake.body: draw_rect(Rect2(origin+Vector2(p.x,p.y)*unit,Vector2.ONE*(unit-1)),Color("a6c779") if i==0 else Color("d99a6d"))
    draw_rect(Rect2(origin+Vector2(snake.food.x,snake.food.y)*unit,Vector2.ONE*(unit-1)),Color("e7c862"))
    draw_string(ThemeDB.fallback_font,origin+Vector2(0,-10),"VOS" if i+1==int(snapshot.you) else "RIVAL",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f0e7cd"))

func _ready() -> void:
 add_theme_constant_override("separation",12)

func text(value: String) -> Label:
 var item := Label.new()
 item.text = value
 item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 add_child(item)
 return item

func add_button(value: String, callback: Callable, parent: Node = null) -> Button:
 var item := Button.new()
 item.text = value
 item.custom_minimum_size = Vector2(0,48)
 item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 item.pressed.connect(callback)
 (parent if parent else self).add_child(item)
 return item

func update_state(value: Dictionary) -> void:
 state = value
 if not built:
  built = true
  build()
 score.text = "Vos %s  ·  Rival %s" % [int(state.scores[int(state.you)-1]),int(state.scores[2-int(state.you)])]
 var active: bool = state.phase == "playing" and not state.get("paused",false)
 var mine: bool = state.get("your_turn",false)
 hint.text = "Partida terminada" if not active else "Tu turno" if mine else "Turno de tu rival" if state.kind in ["tateti","memory"] else "¡A jugar!"
 if state.kind == "tateti":
  for i in range(cells.size()):
   cells[i].text = ["·","X","O"][int(state.board[i])]
   cells[i].disabled = not active or not mine or int(state.board[i]) != 0 or state.get("waiting",false)
 elif state.kind == "memory":
  for i in range(cells.size()):
   cells[i].text = "?" if int(state.cards[i]) == 0 else str(state.cards[i])
   cells[i].disabled = not active or not mine or int(state.cards[i]) != 0 or state.get("waiting",false)
 elif state.kind == "terminal":
  var arrows := ""
  for i in range(state.sequence.size()): arrows += ("["+direction_labels[int(state.sequence[i])]+"]" if i==int(state.progress) else direction_labels[int(state.sequence[i])]) + " "
  question.text = arrows
  hint.text = "Avance %s/%s · Errores %s/%s · %ss" % [state.progress,state.sequence.size(),state.mistakes,state.allowed_mistakes,maxi(0,int(state.limit-state.elapsed))]
 elif state.kind == "trivia":
  question.text = "%s/%s · %s\n%s segundos" % [int(state.question_index),int(state.total),state.question,int(state.remaining)]
  for i in range(options.size()):
   options[i].visible = i < state.options.size()
   if i < state.options.size(): options[i].text = str(state.options[i])
   options[i].disabled = not active or state.answered or state.reveal
  if state.reveal: hint.text = "Respuesta correcta: " + str(state.options[int(state.correct)-1])
  elif state.answered: hint.text = "Respuesta enviada. Esperando a tu rival…"
 elif state.kind == "snake": hint.text = "Flechas / WASD · %ss · Evitá paredes y tu cola" % maxi(0,int(state.limit-state.elapsed))
 elif state.kind == "pong": hint.text = "Tu paleta: " + ("izquierda" if int(state.you)==1 else "derecha") + " · Arriba/abajo · A %s puntos" % state.target
 if canvas:
  canvas.snapshot = state
  canvas.queue_redraw()

func build() -> void:
 score = text("")
 score.add_theme_font_size_override("font_size",22)
 hint = text("")
 if state.kind in ["tateti","memory"]:
  var grid := GridContainer.new()
  grid.columns = 3 if state.kind == "tateti" else 4
  add_child(grid)
  var count: int = 9 if state.kind == "tateti" else state.cards.size()
  for i in range(count):
   var b := add_button("?",func(): action.emit({"cell":i+1}),grid)
   b.add_theme_font_size_override("font_size",24)
   b.custom_minimum_size.y = 54
   cells.append(b)
 elif state.kind == "trivia":
  question = text("")
  question.add_theme_font_size_override("font_size",20)
  for i in range(4):
   var b := add_button("",func(): action.emit({"answer":i+1}))
   b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
   options.append(b)
 elif state.kind == "terminal":
  question = text("")
  question.add_theme_font_size_override("font_size",27)
  directions()
 else:
  canvas = BoardCanvas.new()
  canvas.custom_minimum_size.y = 190
  canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  add_child(canvas)
  canvas.resized.connect(func(): canvas.custom_minimum_size.y = minf(360,canvas.size.x*0.5625))
  if state.kind == "snake": directions()
  else:
   var row := HBoxContainer.new()
   add_child(row)
   var up := add_button("Subir (W)",func(): pass,row)
   var down := add_button("Bajar (S)",func(): pass,row)
   up.button_down.connect(func(): pong_axis=-1)
   down.button_down.connect(func(): pong_axis=1)
   up.button_up.connect(func(): pong_axis=0)
   down.button_up.connect(func(): pong_axis=0)

func directions() -> void:
 var row := HBoxContainer.new()
 add_child(row)
 for i in range(4): add_button(direction_labels[i],func(): action.emit({"direction":i}),row)

func _unhandled_key_input(event: InputEvent) -> void:
 if not visible or state.is_empty() or state.phase != "playing": return
 if event is InputEventKey and event.pressed and not event.echo:
  var keys := [[KEY_UP,KEY_W],[KEY_RIGHT,KEY_D],[KEY_DOWN,KEY_S],[KEY_LEFT,KEY_A]]
  if state.kind in ["snake","terminal"]:
   for i in range(4):
    if event.physical_keycode in keys[i]: action.emit({"direction":i}); get_viewport().set_input_as_handled()
