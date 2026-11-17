NST = {handlers={}}
function NST.assert(ok,message) if not ok then error(message,0) end end
function NST.amount(n)
  NST.assert(type(n)=='number' and n==n and n%1==0 and n>0 and n<=1000000,NSTText('invalidAmount'))
  return n
end
function NST.near(a,b,r)
  if not a or not b then return false end
  return (a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2<=r*r
end
function NST.player(s,id)
  NST.assert(type(id)=='string',NSTText('playerMissing'))
  if not s.players[id] then s.players[id]={cash=(NSTConfig and NSTConfig.startingCash) or 500,items={},role='criminal',alive=true,wantedUntil=0,jailUntil=0,protectedUntil=0} end
  return s.players[id]
end
function NST.copy(t)
  if type(t)~='table' then return t end
  local n={} for k,v in pairs(t) do n[k]=NST.copy(v) end return n
end
-- Never publish speculative mutations: caller persists this copy before effects.
function NST.apply(s,ctx,action,args)
  NST.assert(NST.handlers[action],NSTText('unknownAction'))
  local nextState=NST.copy(s)
  local result=NST.handlers[action](nextState,ctx,args or {})
  for id,p in pairs(nextState.players) do
    local after=NST.inventoryInfo(p);local before=s.players[id] and NST.inventoryInfo(s.players[id])
    -- Preserve legacy overloaded inventories, but never increase their load or reduce capacity.
    NST.assert(after.weight<=after.capacity or (before and after.weight<=before.weight and after.capacity>=before.capacity),NSTText('inventoryTooHeavy'))
  end
  return nextState,result
end

-- Weight is integer grams; cash has a configurable bulk cost per dollar.
NST.inventoryDefaults={pockets=8000,cashWeight=0.1,weights={stolen=1000,lockpick=150,medkit=750,bat=1200,bag_small=500,bag_medium=1000,bag_large=1500},bags={bag_small={capacity=18000,price=150,drawable=40},bag_medium={capacity=35000,price=450,drawable=45},bag_large={capacity=60000,price=900,drawable=82}}}
function NST.inventoryRules() return NSTConfig.inventory or NST.inventoryDefaults end
function NST.inventoryInfo(p)
  local rules=NST.inventoryRules();local bags=rules.bags or NST.inventoryDefaults.bags
  local weights=rules.weights or NST.inventoryDefaults.weights
  local weight=math.ceil((p.cash or 0)*(rules.cashWeight or 0.1))
  for item,n in pairs(p.items or {}) do weight=weight+(weights[item] or 1000)*n end
  return {weight=weight,capacity=p.bag and bags[p.bag] and bags[p.bag].capacity or rules.pockets or 8000,bag=p.bag,bags=bags,weights=weights}
end
function NST.checkCarry(p)
  local i=NST.inventoryInfo(p);NST.assert(i.weight<=i.capacity,NSTText('inventoryTooHeavy'))
end
function NST.newDrop(s,c,items,cash,kind)
  NST.assert(c.pos,NSTGameplayText.tooFar)
  s.nextDrop=(s.nextDrop or 0)+1;local key=tostring(s.nextDrop)
  s.drops[key]={id=key,owner=c.id,pos=NST.copy(c.pos),items=items,cash=cash or 0,kind=kind or 'ground',unlockAt=c.now,expiresAt=c.now+900}
  return key
end
