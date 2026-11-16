NST = {handlers={}}
function NST.assert(ok,message) if not ok then error(message,0) end end
function NST.amount(n)
  NST.assert(type(n)=='number' and n==n and n%1==0 and n>0 and n<=1000000,'Invalid amount')
  return n
end
function NST.near(a,b,r)
  if not a or not b then return false end
  return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=r*r
end
function NST.player(s,id)
  NST.assert(type(id)=='string','Player not found')
  if not s.players[id] then s.players[id]={cash=500,items={},role='criminal',alive=true,wantedUntil=0,jailUntil=0,protectedUntil=0} end
  return s.players[id]
end
function NST.copy(t)
  if type(t)~='table' then return t end
  local n={} for k,v in pairs(t) do n[k]=NST.copy(v) end return n
end
-- Never publish speculative mutations: caller persists this copy before effects.
function NST.apply(s,ctx,action,args)
  NST.assert(NST.handlers[action],'Unknown action')
  local nextState=NST.copy(s)
  local result=NST.handlers[action](nextState,ctx,args or {})
  return nextState,result
end
