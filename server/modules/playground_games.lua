-- Original server-authoritative adaptations of classic mechanics.
-- Snake/Terminal lifecycle concepts originate in the local RPG Lideres project.
local store=require('playground_store')
local M={}
local function integer(v,min,max) return type(v)=='number' and v==v and v%1==0 and v>=min and v<=max end
local function rand(g,n) g.seed=(g.seed*48271)%2147483647;return g.seed%n+1 end
local function index(g,id) for i,v in ipairs(g.ids) do if id==v then return i end end end
local function finish(g,reason)
 g.phase='finished';g.reason=reason or 'Partida terminada'
 g.winner=g.scores[1]==g.scores[2] and '' or g.ids[g.scores[1]>g.scores[2] and 1 or 2]
end
local function round_board(g)
 g.board={0,0,0,0,0,0,0,0,0};g.turn=(g.round%2==1) and 1 or 2;g.round_wait=nil
end
local function food(g,s)
 local n=g.rules.size;local available={}
 for y=0,n-1 do for x=0,n-1 do
  local free=true;for _,p in ipairs(s.body) do if p.x==x and p.y==y then free=false;break end end
  if free then available[#available+1]={x=x,y=y} end
 end end
 if #available==0 then s.dead=true;return end
 -- Each participant has an independent identical-seed food sequence.
 s.seed=(s.seed*48271)%2147483647;s.food=available[s.seed%#available+1]
end
function M.new(def,ids,seed,id)
 local g={id=id,kind=def.kind,title=def.title,revision=def.revision or 1,rules=store.copy(def.rules),ids=ids,seed=seed or 1729,phase='playing',elapsed=0,scores={0,0},turn=1,round=1,bot_elapsed=0}
 if g.kind=='tateti' then round_board(g)
 elseif g.kind=='terminal' then
  g.sequence={};for i=1,g.rules.length do g.sequence[i]=rand(g,4)-1 end
  g.progress={0,0};g.mistakes={0,0};g.dead={false,false}
 elseif g.kind=='snake' then
  g.snakes={};g.accum=0
  for i=1,2 do local n=g.rules.size;local s={body={{x=math.floor(n/2),y=math.floor(n/2)},{x=math.floor(n/2)-1,y=math.floor(n/2)},{x=math.floor(n/2)-2,y=math.floor(n/2)}},direction=1,queued=1,dead=false,seed=g.seed};food(g,s);g.snakes[i]=s end
 elseif g.kind=='memory' then
  g.deck={};g.cards={};g.matched={};g.picked={}
  for i=1,g.rules.pairs*2 do g.deck[i]=math.floor((i-1)/2)+1;g.cards[i]=0 end
  for i=#g.deck,2,-1 do local j=rand(g,i);g.deck[i],g.deck[j]=g.deck[j],g.deck[i] end
 elseif g.kind=='trivia' then
  g.question_index=1;g.answers={0,0};g.question_elapsed=0;g.reveal=false
 elseif g.kind=='pong' then
  g.paddles={180,180};g.axes={0,0};g.last_input={0,0};g.ball={x=320,y=180};g.vx=210+g.rules.speed*55;g.vy=100;g.serve=0.7
 end
 return g
end
function M.action(g,id,input)
 local i=index(g,id);if not i or g.phase~='playing' or type(input)~='table' then return end
 if g.kind=='tateti' then
  if g.turn~=i or g.round_wait or not integer(input.cell,1,9) or g.board[input.cell]~=0 then return end
  g.board[input.cell]=i
  local win=false;for _,line in ipairs({{1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7}}) do if g.board[line[1]]==i and g.board[line[2]]==i and g.board[line[3]]==i then win=true end end
  local full=true;for _,v in ipairs(g.board) do if v==0 then full=false end end
  if win then g.scores[i]=g.scores[i]+1 end
  if win or full then
   if g.round>=g.rules.rounds or g.scores[i]>g.rules.rounds/2 then finish(g) else g.round_wait=1.5 end
  else g.turn=3-i end
 elseif g.kind=='terminal' then
  if g.dead[i] or not integer(input.direction,0,3) then return end
  if input.direction==g.sequence[g.progress[i]+1] then g.progress[i]=g.progress[i]+1;g.scores[i]=g.progress[i]
  else g.mistakes[i]=g.mistakes[i]+1;if g.mistakes[i]>=g.rules.mistakes then g.dead[i]=true end end
  if g.progress[i]>=#g.sequence or (g.dead[1] and g.dead[2]) then finish(g) end
 elseif g.kind=='snake' then
  local s=g.snakes[i];if integer(input.direction,0,3) and (input.direction+2)%4~=s.direction then s.queued=input.direction end
 elseif g.kind=='memory' then
  if g.turn~=i or g.hide_at or not integer(input.cell,1,#g.deck) or g.cards[input.cell]~=0 then return end
  local c=input.cell;g.cards[c]=g.deck[c];g.picked[#g.picked+1]=c
  if #g.picked==2 then
   if g.deck[g.picked[1]]==g.deck[g.picked[2]] then
    g.scores[i]=g.scores[i]+1;g.matched[#g.matched+1]=g.picked[1];g.matched[#g.matched+1]=g.picked[2];g.picked={}
    if #g.matched==#g.deck then finish(g) elseif not g.rules.repeat_turn then g.turn=3-i end
   else g.hide_at=g.elapsed+1 end
  end
 elseif g.kind=='trivia' then
  local q=g.rules.questions[g.question_index]
  if g.reveal or g.answers[i]~=0 or not integer(input.answer,1,#q.options) then return end
  g.answers[i]=input.answer
 elseif g.kind=='pong' then
  if type(input.axis)=='number' and input.axis==input.axis and math.abs(input.axis)<=1 then g.axes[i]=input.axis;g.last_input[i]=g.elapsed end
 end
end
function M.tick(g,dt)
 if g.phase~='playing' then return end
 g.elapsed=g.elapsed+dt
 if g.elapsed>600 then finish(g,'Tiempo máximo alcanzado');return end
 if g.ids[2]=='practice' then
  g.bot_elapsed=g.bot_elapsed+dt
  if g.kind=='pong' then M.action(g,'practice',{axis=math.max(-1,math.min(1,(g.ball.y-g.paddles[2])/65))}) end
  if g.bot_elapsed>=0.8 then
   g.bot_elapsed=0
   if g.kind=='tateti' and g.turn==2 then for c,v in ipairs(g.board) do if v==0 then M.action(g,'practice',{cell=c});break end end
   elseif g.kind=='memory' and g.turn==2 then for c,v in ipairs(g.cards) do if v==0 then M.action(g,'practice',{cell=c});break end end
   elseif g.kind=='trivia' then M.action(g,'practice',{answer=1})
   elseif g.kind=='terminal' and g.elapsed>2 then M.action(g,'practice',{direction=rand(g,4)-1}) end
  end
 end
 if g.kind=='tateti' and g.round_wait then
  g.round_wait=g.round_wait-dt;if g.round_wait<=0 then g.round=g.round+1;round_board(g) end
 elseif g.kind=='terminal' then if g.elapsed>=g.rules.time then finish(g,'Tiempo cumplido') end
 elseif g.kind=='snake' then
  g.accum=g.accum+dt;local interval=({0.28,0.18,0.1})[g.rules.speed]
  if g.accum>=interval then
   g.accum=g.accum-interval
   local moves={{x=0,y=-1},{x=1,y=0},{x=0,y=1},{x=-1,y=0}}
   for i,s in ipairs(g.snakes) do if not s.dead then
    s.direction=s.queued;local move=moves[s.direction+1];local head={x=s.body[1].x+move.x,y=s.body[1].y+move.y}
    local eating=head.x==s.food.x and head.y==s.food.y
    if head.x<0 or head.y<0 or head.x>=g.rules.size or head.y>=g.rules.size then s.dead=true end
    for j=1,#s.body-(eating and 0 or 1) do local p=s.body[j];if p.x==head.x and p.y==head.y then s.dead=true end end
    if not s.dead then table.insert(s.body,1,head);if eating then g.scores[i]=g.scores[i]+1;food(g,s) else table.remove(s.body) end end
   end end
  end
  if g.elapsed>=g.rules.time or (g.snakes[1].dead and g.snakes[2].dead) then finish(g,'Fin del recorrido') end
 elseif g.kind=='memory' then
  if g.hide_at and g.elapsed>=g.hide_at then
   for _,c in ipairs(g.picked) do g.cards[c]=0 end;g.picked={};g.hide_at=nil;g.turn=3-g.turn
  end
 elseif g.kind=='trivia' then
  g.question_elapsed=g.question_elapsed+dt
  if not g.reveal and ((g.answers[1]~=0 and g.answers[2]~=0) or g.question_elapsed>=g.rules.time) then
   local q=g.rules.questions[g.question_index];for i=1,2 do if g.answers[i]==q.answer then g.scores[i]=g.scores[i]+1 end end
   g.reveal=true;g.question_elapsed=0
  elseif g.reveal and g.question_elapsed>=2 then
   if g.question_index>=#g.rules.questions then finish(g) else g.question_index=g.question_index+1;g.answers={0,0};g.question_elapsed=0;g.reveal=false end
  end
 elseif g.kind=='pong' then
  for i=1,2 do if g.elapsed-g.last_input[i]>0.5 then g.axes[i]=0 end;g.paddles[i]=math.max(35,math.min(325,g.paddles[i]+g.axes[i]*300*dt)) end
  if g.serve>0 then g.serve=g.serve-dt;return end
  local oldx=g.ball.x;g.ball.x=g.ball.x+g.vx*dt;g.ball.y=g.ball.y+g.vy*dt
  if g.ball.y<8 then g.ball.y=8;g.vy=math.abs(g.vy) elseif g.ball.y>352 then g.ball.y=352;g.vy=-math.abs(g.vy) end
  for i,x in ipairs({28,612}) do
   local crosses=(i==1 and g.vx<0 and oldx>=x and g.ball.x<=x) or (i==2 and g.vx>0 and oldx<=x and g.ball.x>=x)
   if crosses and math.abs(g.ball.y-g.paddles[i])<=43 then g.ball.x=x;g.vx=-g.vx;g.vy=(g.ball.y-g.paddles[i])*5 end
  end
  if g.ball.x<0 or g.ball.x>640 then
   local winner=g.ball.x<0 and 2 or 1;g.scores[winner]=g.scores[winner]+1
   if g.scores[winner]>=g.rules.points then finish(g) else g.ball={x=320,y=180};g.vy=100;g.serve=0.6 end
  end
 end
end
function M.view(g,id)
 local i=index(g,id);if not i then return nil end
 local v={id=g.id,kind=g.kind,title=g.title,phase=g.phase,elapsed=g.elapsed,scores=g.scores,winner=g.winner or '',reason=g.reason or '',you=i,turn=g.ids[g.turn],round=g.round,your_turn=g.ids[g.turn]==id}
 if g.kind=='tateti' then v.board=g.board;v.waiting=g.round_wait~=nil
 elseif g.kind=='terminal' then v.sequence=g.sequence;v.progress=g.progress[i];v.mistakes=g.mistakes[i];v.dead=g.dead[i];v.limit=g.rules.time;v.allowed_mistakes=g.rules.mistakes
 elseif g.kind=='snake' then v.snakes=g.snakes;v.size=g.rules.size;v.limit=g.rules.time
 elseif g.kind=='memory' then v.cards=g.cards;v.picked=g.picked;v.matched=g.matched;v.waiting=g.hide_at~=nil
 elseif g.kind=='trivia' then
  local q=g.rules.questions[g.question_index];v.question=q.text;v.options=q.options;v.question_index=g.question_index;v.total=#g.rules.questions;v.remaining=math.max(0,g.rules.time-g.question_elapsed);v.reveal=g.reveal;v.answered=g.answers[i]~=0
  if g.reveal then v.correct=q.answer;v.answers=g.answers end
 elseif g.kind=='pong' then v.ball=g.ball;v.paddles=g.paddles;v.target=g.rules.points end
 return v
end
return M
