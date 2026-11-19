local nk=require('nakama')
local M={}
local SYSTEM='00000000-0000-0000-0000-000000000000'
M.templates={
 {id='snake',name='Snake',description='Dos tableros. La misma oportunidad.',defaults={speed=2,size=20,time=60},fields={{id='speed',name='Velocidad',values={1,2,3}},{id='size',name='Tablero',values={16,20,24}},{id='time',name='Segundos',values={60,120,180}}}},
 {id='terminal',name='Terminal Access',description='Descifrá la secuencia antes que tu rival.',defaults={length=4,mistakes=3,time=30},fields={{id='length',name='Secuencia',values={4,6,8}},{id='mistakes',name='Errores',values={1,3,5}},{id='time',name='Segundos',values={30,60,90}}}},
 {id='pong',name='Pong',description='Un clásico, dos paletas y una pelota.',defaults={points=5,speed=2},fields={{id='points',name='Puntos',values={5,7,11}},{id='speed',name='Velocidad',values={1,2,3}}}},
 {id='tateti',name='Ta-Te-Ti',description='Tres en línea. Pensá tu siguiente jugada.',defaults={rounds=1},fields={{id='rounds',name='Mejor de',values={1,3,5}}}},
 {id='memory',name='Memoria',description='Encontrá parejas y recordá las pistas.',defaults={pairs=6,repeat_turn=true},fields={{id='pairs',name='Parejas',values={6,8,12}},{id='repeat_turn',name='Repetir al acertar',values={true,false}}}},
 {id='trivia',name='Trivia',description='Tus preguntas, un desafío compartido.',defaults={time=15},fields={{id='time',name='Segundos por pregunta',values={15,30,45}}}}
}
M.questions={{text='¿Cuántos lados tiene un hexágono?',options={'Cinco','Seis','Ocho'},answer=2},{text='¿Cuál es un planeta?',options={'Marte','Luna','Sol'},answer=1},{text='¿Cuánto es 7 × 8?',options={'48','54','56'},answer=3}}
local function copy(t) return nk.json_decode(nk.json_encode(t)) end
M.copy=copy
function M.text(s,min,max)
 if type(s)~='string' or #s>max*4 or s:find('[%z\1-\8\11\12\14-\31]') then return nil end
 s=s:match('^%s*(.-)%s*$'); local _,n=s:gsub('[^\128-\193]','')
 if n<min or n>max then return nil end
 return s
end
local function read(collection,key,user)
 local a=nk.storage_read({{collection=collection,key=key,user_id=user or SYSTEM}})
 return a[1] and a[1].value,a[1] and a[1].version
end
M.read=read
local function record(collection,key,user,value,version)
 return {collection=collection,key=key,user_id=user or SYSTEM,value=value,version=version,permission_read=0,permission_write=0}
end
function M.profile(user)
 local v=read('playground_private','profile',user)
 return v or {name='Explorador',skin=1,hair=0,shirt=0,style=0}
end
function M.validate_profile(p)
 if type(p)~='table' then return nil end
 local name=M.text(p.name,1,24); if not name then return nil end
 local out={name=name}
 for _,k in ipairs({'skin','hair','shirt','style'}) do
  local v=p[k] or 0;local max=k=='style' and 2 or 5
  if type(v)~='number' or v%1~=0 or v<0 or v>max then return nil end
  out[k]=v
 end
 return out
end
function M.validate(b)
 if type(b)~='table' then return nil end
 local t;for _,v in ipairs(M.templates) do if v.id==b.kind then t=v end end
 local title=M.text(b.title,1,48);local desc=M.text(b.description or '',0,240)
 if not t or not title or not desc or (b.rules and type(b.rules)~='table') then return nil end
 local r={};for _,f in ipairs(t.fields) do
  local v=b.rules and b.rules[f.id];if v==nil then v=t.defaults[f.id] end
  local valid=false;for _,allowed in ipairs(f.values) do if v==allowed then valid=true end end
  if not valid then return nil end;r[f.id]=v
 end
 if b.kind=='trivia' then
  local qs=(b.rules or {}).questions or M.questions
  if type(qs)~='table' or #qs<3 or #qs>10 then return nil end
  r.questions={};for _,q in ipairs(qs) do
   if type(q)~='table' then return nil end
   local question=M.text(q.text,1,160)
   if not question or type(q.options)~='table' or #q.options<2 or #q.options>4 or type(q.answer)~='number' or q.answer%1~=0 or q.answer<1 or q.answer>#q.options then return nil end
   local opts={};for _,s in ipairs(q.options) do local v=M.text(s,1,80);if not v then return nil end;opts[#opts+1]=v end
   r.questions[#r.questions+1]={text=question,options=opts,answer=q.answer}
  end
 end
 return {kind=b.kind,title=title,description=desc,rules=r}
end
function M.load(code,revision)
 if type(code)~='string' or #code<1 or #code>50 then return nil end
 if code:sub(1,8)=='builtin:' then
  local kind=code:sub(9);for _,t in ipairs(M.templates) do if t.id==kind then
   local b=M.validate({kind=kind,title=t.name,rules=t.defaults});b.code=code;b.revision=1;return b
  end end;return nil
 end
 local head=read('playground_codes',code)
 if not head then return nil end
 local rev=revision or head.revision
 if type(rev)~='number' or rev%1~=0 or rev<1 then return nil end
 return read('playground_revisions',code..':'..rev)
end
function M.public(b,owner)
 local v=copy(b)
 if v.kind=='trivia' and not owner then for _,q in ipairs(v.rules.questions) do q.answer=nil end end
 return v
end
local function budget(user,key,max,period)
 local v,version=read('playground_private',key,user);local now=nk.time()
 if not v or now-v.at>=period then v={at=now,count=0} end
 if v.count>=max then return nil end
 v.count=v.count+1;return record('playground_private',key,user,v,version or '*')
end
local function persist(writes)
 local ok=pcall(nk.storage_write,writes)
 if not ok then return {ok=false,error='Otro cambio se guardó primero. Volvé a intentar.'} end
end
function M.handle(context,p)
 local user=context.user_id
 if not user or type(p)~='table' then return {ok=false,error='Sesión necesaria.'} end
 local action=p.action
 if action=='catalog' then return {ok=true,templates=M.templates,questions=M.questions} end
 if action=='profile_get' then return {ok=true,profile=M.profile(user)} end
 if action=='profile_save' then
  local profile=M.validate_profile(p.profile);if not profile then return {ok=false,error='Revisá el nombre y la apariencia.'} end
  local quota=budget(user,'profile_rate',20,60000);if not quota then return {ok=false,error='Esperá un minuto.'} end
  local err=persist({quota,record('playground_private','profile',user,profile)})
  return err or {ok=true,profile=profile}
 end
 if action=='blueprint_list' then
  local index=read('playground_private','library',user) or {codes={}};local items={}
  for _,code in ipairs(index.codes) do local b=M.load(code);if b then items[#items+1]=b end end
  return {ok=true,items=items}
 end
 if action=='blueprint_get' then
  local b=M.load(p.code,p.revision)
  if not b then return {ok=false,error='No encontramos ese desafío.'} end
  return {ok=true,blueprint=M.public(b,b.owner==user)}
 end
 if action=='blueprint_save' then
  local b=M.validate(p.blueprint);if not b then return {ok=false,error='Las reglas o el texto no son válidos.'} end
  local index,iv=read('playground_private','library',user);index=index or {codes={}}
  local code=p.blueprint.code;local head,hv
  if code then
   if type(code)~='string' or #code<1 or #code>50 then return {ok=false,error='Código inválido.'} end
   head,hv=read('playground_codes',code)
   if not head or head.owner~=user then return {ok=false,error='Sólo el creador puede editarlo.'} end
   if p.blueprint.revision~=head.revision then return {ok=false,error='Esta versión cambió. Abrila de nuevo.'} end
  else
   if #index.codes>=20 then return {ok=false,error='Tu biblioteca admite 20 desafíos.'} end
   code=nk.uuid_v4();index.codes[#index.codes+1]=code
  end
  local quota=budget(user,'save_rate',5,60000);if not quota then return {ok=false,error='Guardaste cinco veces. Esperá un minuto.'} end
  b.code=code;b.owner=user;b.revision=head and head.revision+1 or 1;b.created_at=nk.time()
  local err=persist({quota,record('playground_private','library',user,index,iv or '*'),record('playground_codes',code,nil,{owner=user,revision=b.revision},hv or '*'),record('playground_revisions',code..':'..b.revision,nil,b,'*')})
  return err or {ok=true,blueprint=b}
 end
 if action=='suggest_create' then
  local title=M.text(p.title,1,80);local text=M.text(p.text,10,2000)
  if not title or not text or (p.category~='idea' and p.category~='error' and p.category~='otro') then return {ok=false,error='Completá título y sugerencia (10 a 2000 caracteres).'} end
  local quota=budget(user,'suggest_rate',3,3600000);if not quota then return {ok=false,error='Podés enviar tres sugerencias por hora.'} end
  local id=nk.uuid_v4();local item={id=id,title=title,text=text,category=p.category,status='pendiente',response='',created_at=nk.time(),history={}}
  local err=persist({quota,record('playground_suggestions',id,user,item,'*')})
  return err or {ok=true,id=id}
 end
 if action=='suggest_list' then
  local objects,cursor=nk.storage_list(user,'playground_suggestions',50,type(p.cursor)=='string' and p.cursor or nil)
  local items={};for _,o in ipairs(objects) do items[#items+1]=o.value end
  return {ok=true,items=items,cursor=cursor or ''}
 end
 return {ok=false,error='Operación no disponible.'}
end
function M.rpc(context,payload)
 if type(payload)~='string' or #payload>16384 then return nk.json_encode({ok=false,error='Solicitud demasiado grande.'}) end
 local ok,p=pcall(nk.json_decode,payload)
 if not ok then return nk.json_encode({ok=false,error='Solicitud inválida.'}) end
 local handled,result=pcall(M.handle,context,p)
 if not handled then return nk.json_encode({ok=false,error="No se pudo completar la solicitud. Revisá los datos e intentá de nuevo."}) end
 return nk.json_encode(result)
end
return M
