local nk=require('nakama')
local store=require('playground_store')
local games=require('playground_games')
local M={}
local function clear_activity(state)
 state.activity=nil;state.invitation=nil
 for _,p in pairs(state.players) do
  p.dx=0;p.dy=0
  if p.zone~='office' then p.zone='office';p.x=p.return_x or 620;p.y=p.return_y or 790 end
 end
end
function M.message(state,p,id,input,tick)
 if type(input.seq)~='number' or input.seq%1~=0 or input.seq<0 or input.seq>1e9 or input.seq<=(p.action_seq or -1) then return end
 p.action_seq=input.seq
 local action=input.action
 if action=='profile' then p.profile=store.profile(id);return end
 local participating=state.activity and (state.activity.ids[1]==id or state.activity.ids[2]==id)
 if action=='travel' and not participating then
  if input.zone=='office' or input.zone=='arcade' or input.zone=='workshop' then
   if (p.zone or 'office')=='office' and input.zone~='office' then p.return_x=p.x;p.return_y=p.y end
   p.zone=input.zone;p.dx=0;p.dy=0
   if p.zone=='office' then p.x=p.return_x or 620;p.y=p.return_y or 790 else p.x=2100;p.y=680 end
  end;return
 end
 if action=='invite' or action=='practice' then
  if state.activity or state.invitation then p.notice='Ya hay una partida o invitación en esta sala.';return end
  local def=store.load(input.code,input.revision);if not def then p.notice='Desafío no disponible.';return end
  if action=='practice' then
   state.activity=games.new(def,{id,'practice'},math.random(1,1000000),nk.uuid_v4());return
  end
  local other;for uid,v in pairs(state.players) do if uid~=id and not v.offline then other=uid end end
  if not other then p.notice='Invitá a otra persona a la sala primero.';return end
  state.invitation={id=nk.uuid_v4(),from=id,to=other,definition=def,expires=tick+300};return
 end
 if action=='accept' or action=='reject' then
  local inv=state.invitation
  if not inv or inv.id~=input.invitation_id or inv.to~=id or tick>=inv.expires then return end
  if action=='accept' then state.activity=games.new(inv.definition,{inv.from,inv.to},math.random(1,1000000),nk.uuid_v4()) end
  state.invitation=nil;return
 end
 local game=state.activity
 if not game or (id~=game.ids[1] and id~=game.ids[2]) or input.run_id~=game.id then return end
 if action=='abandon' and game.phase=='playing' then
  game.phase='finished';game.reason='Una persona abandonó la partida.';game.winner='';game.abandoned=true
 elseif action=='return' and game.phase=='finished' then clear_activity(state)
 elseif action=='play' and not game.paused then games.action(game,id,input) end
end
function M.tick(state,dispatcher,tick)
 local inv=state.invitation
 if inv and (tick>=inv.expires or not state.players[inv.from] or not state.players[inv.to] or state.players[inv.from].offline or state.players[inv.to].offline) then state.invitation=nil end
 local game=state.activity
 if game and game.phase=='playing' then
  game.paused=false
  for _,id in ipairs(game.ids) do
   if id~='practice' then
    local p=state.players[id]
    if not p or (p.offline and tick-p.offline>=300) then
     game.phase='finished';game.reason='La otra persona se desconectó. Podés volver a la oficina.';game.winner='';game.abandoned=true
     if p and p.offline then state.players[id]=nil end
    elseif p.offline then game.paused=true end
   end
  end
  if game.ids[2]=='practice' and not state.players[game.ids[1]] then
   clear_activity(state);game=nil
  elseif not game.paused then games.tick(game,0.1) end
 end
 for id,p in pairs(state.players) do if p.presence and not p.offline then
  local view={tick=tick,zone=p.zone or 'office',notice=p.notice or '',profile=p.profile}
  if state.invitation then local i=state.invitation;view.invitation={id=i.id,from=i.from,to=i.to,title=i.definition.title,kind=i.definition.kind,expires_in=(i.expires-tick)/10} end
  if game then view.game=games.view(game,id);if view.game then view.game.paused=game.paused;view.game.practice=game.ids[2]=='practice';view.game.abandoned=game.abandoned or false end end
  dispatcher.broadcast_message(4,nk.json_encode(view),{p.presence})
 end end
end
return M
