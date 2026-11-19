local nk = require('nakama')
local geometry = require('geometry')
local playground = require('playground_match')
local store = require('playground_store')
local M = {}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<100000 end
local function clear(x,y)
  local inside=false
  local poly=geometry.outline
  for i=1,#poly do
    local a,b=poly[i],poly[i%#poly+1]
    if (a[2]>y) ~= (b[2]>y) and x<(b[1]-a[1])*(y-a[2])/(b[2]-a[2])+a[1] then inside=not inside end
    local dx,dy=b[1]-a[1],b[2]-a[2]
    local t=math.max(0,math.min(1,((x-a[1])*dx+(y-a[2])*dy)/(dx*dx+dy*dy)))
    if (x-a[1]-t*dx)^2+(y-a[2]-t*dy)^2<81 then return false end
  end
  if not inside then return false end
  for _,r in ipairs(geometry.rects) do
    local dx=x-math.max(r[1],math.min(x,r[1]+r[3]))
    local dy=y-math.max(r[2],math.min(y,r[2]+r[4]))
    if dx*dx+dy*dy<81 then return false end
  end
  return true
end
function M.match_init(context,params)
  return {players={},pending={},empty=0},10,'office-preview-v1'
end
function M.match_join_attempt(context,dispatcher,tick,state,presence,metadata)
  local existing=state.players[presence.user_id]
  if existing and existing.offline and tick-existing.offline<300 then
    if state.pending[presence.session_id] then return state,false,'Entrada pendiente' end
    for _,v in pairs(state.pending) do if v.user_id==presence.user_id then return state,false,'Entrada pendiente' end end
    state.pending[presence.session_id]={user_id=presence.user_id,tick=tick}
    return state,true
  end
  local count=0
  for _ in pairs(state.players) do count=count+1 end
  for session,reservation in pairs(state.pending) do
    if tick-reservation.tick>100 then state.pending[session]=nil
    else
      count=count+1
      if reservation.user_id==presence.user_id then return state,false,'Identidad en proceso de entrada' end
    end
  end
  if state.players[presence.user_id] then return state,false,'Identidad ya conectada' end
  if count>=2 then return state,false,'Sala completa (2 personas)' end
  state.pending[presence.session_id]={user_id=presence.user_id,tick=tick}
  return state,true
end
function M.match_join(context,dispatcher,tick,state,presences)
  for _,p in ipairs(presences) do
    local reservation=state.pending[p.session_id]
    state.pending[p.session_id]=nil
    local count=0
    for _ in pairs(state.players) do count=count+1 end
    local existing=state.players[p.user_id]
    if reservation and reservation.user_id==p.user_id and existing and existing.offline then
      existing.session=p.session_id;existing.presence=p;existing.offline=nil;existing.action_seq=-1;existing.seq=-1;existing.dx=0;existing.dy=0
    elseif reservation and reservation.user_id==p.user_id and count<2 and not existing then
      state.players[p.user_id]={x=620,y=790,dx=0,dy=0,seq=-1,last=tick,session=p.session_id,presence=p,profile=store.profile(p.user_id),zone='office'}
    else dispatcher.match_kick({p}) end
  end
  return state
end
function M.match_leave(context,dispatcher,tick,state,presences)
  for _,p in ipairs(presences) do
    state.pending[p.session_id]=nil
    if state.players[p.user_id] and state.players[p.user_id].session==p.session_id then
      if state.activity and state.activity.phase=='playing' then state.players[p.user_id].offline=tick;state.players[p.user_id].dx=0;state.players[p.user_id].dy=0
      else state.players[p.user_id]=nil end
    end
  end
  return state
end
function M.match_loop(context,dispatcher,tick,state,messages)
  for session,reservation in pairs(state.pending) do
    if tick-reservation.tick>100 then state.pending[session]=nil end
  end
  for _,message in ipairs(messages) do
    local p=state.players[message.sender.user_id]
    if p and not p.offline and p.session==message.sender.session_id and message.op_code==3 and type(message.data)=='string' and #message.data<=1024 then
      if p.control_tick~=tick then p.control_tick=tick;p.control_count=0 end
      p.control_count=p.control_count+1
      if p.control_count<=12 then
        local ok,input=pcall(nk.json_decode,message.data)
        if ok and type(input)=='table' then playground.message(state,p,message.sender.user_id,input,tick) end
      end
    end
    if p and p.session==message.sender.session_id and message.op_code==1 and type(message.data)=='string' and #message.data<=256 then
      local ok,input=pcall(nk.json_decode,message.data)
      if ok and type(input)=='table' and finite(input.x) and finite(input.y) and finite(input.seq) and input.seq%1==0 and input.seq>p.seq and math.abs(input.x)<=1 and math.abs(input.y)<=1 then
        local length=math.max(1,math.sqrt(input.x^2+input.y^2))
        p.dx=input.x/length; p.dy=input.y/length; p.seq=input.seq; p.last=tick
      end
    end
  end
  local snapshot={tick=tick,players={}}
  local count=0
  for id,p in pairs(state.players) do
    count=count+1
    if tick-p.last>3 or (state.activity and (state.activity.ids[1]==id or state.activity.ids[2]==id)) or p.offline then p.dx=0; p.dy=0 end
    for step=1,6 do
      local x,y=p.x+p.dx*3,p.y+p.dy*3
      if p.zone and p.zone~='office' then
       p.x=math.max(1809,math.min(2391,x));p.y=math.max(329,math.min(741,y))
      else
       if clear(x,p.y) then p.x=x end
       if clear(p.x,y) then p.y=y end
      end
    end
    if not p.offline then snapshot.players[id]={x=p.x,y=p.y,profile=p.profile,zone=p.zone or 'office'} end
  end
  if count==0 then state.empty=state.empty+1 else state.empty=0 end
  if state.empty>300 or tick>36000 then return nil end
  dispatcher.broadcast_message(2,nk.json_encode(snapshot))
  playground.tick(state,dispatcher,tick)
  return state
end
function M.match_terminate(context,dispatcher,tick,state,grace) return state end
function M.match_signal(context,dispatcher,tick,state,data) return state,'' end
return M
