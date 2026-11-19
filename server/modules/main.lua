local nk=require('nakama')
nk.register_rpc(require('playground_store').rpc,'playground')
nk.register_rpc(function(context,payload)
  if not context.user_id then error('Authentication required') end
  local read=nk.storage_read({{collection='office_private',key='last_room',user_id=context.user_id}})
  local now=nk.time()
  if #read>0 and now-read[1].value.at<10000 then error('Esperá unos segundos antes de crear otra sala') end
  local id=nk.match_create('office',{})
  nk.storage_write({{collection='office_private',key='last_room',user_id=context.user_id,value={at=now},permission_read=0,permission_write=0}})
  return nk.json_encode({match_id=id})
end,'office_create')
