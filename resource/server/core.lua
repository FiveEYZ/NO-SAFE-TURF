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
  for _,p in pairs(nextState.players) do NST.saveGrid(p,NST.gridLayout(p)) end
  local result=NST.handlers[action](nextState,ctx,args or {})
  for id,p in pairs(nextState.players) do
    local after=NST.inventoryInfo(p);local before=s.players[id] and NST.inventoryInfo(s.players[id])
    -- Preserve legacy overloaded inventories, but never increase their load or reduce capacity.
    NST.assert(after.weight<=after.capacity or (before and after.weight<=before.weight and after.capacity>=before.capacity),NSTText('inventoryTooHeavy'))
    local old=s.players[id];local grid=NST.gridLayout(p);local oldGrid=old and NST.gridLayout(old)
    if grid.overflow>0 then
      NST.assert(oldGrid and grid.overflow<=oldGrid.overflow and (p.cash or 0)<=(old.cash or 0),NSTText('inventoryNoRoom'))
      for item,n in pairs(p.items) do NST.assert(n<=(old.items[item] or 0),NSTText('inventoryNoRoom')) end
    end
    NST.saveGrid(p,grid)
    if not old or NST.inventorySignature(p)~=NST.inventorySignature(old) then p.gridRevision=(old and old.gridRevision or 0)+1 end
    if p.equippedWeapon and (p.items[p.equippedWeapon] or 0)<1 then p.equippedWeapon=nil end
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
  for item,n in pairs(p.items or {}) do weight=weight+(weights[item] or NST.itemDefinition(item).weight or 1000)*n end
  return {weight=weight,capacity=p.bag and bags[p.bag] and bags[p.bag].capacity or rules.pockets or 8000,bag=p.bag,bags=bags,weights=weights,catalog=NST.itemCatalog,grid=NST.gridLayout(p)}
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

-- Shared catalog for authoritative geometry, loot value and physical ammunition.
NST.itemCatalog={
 cash={w=1,h=1,stack=10000,label='Cash',kind='cash'},
 stolen={w=2,h=1,stack=1,label='Stolen goods',kind='loot',value=1,weight=1000},
 stolen_watch={w=1,h=1,stack=1,label='Stolen watch',kind='loot',value=1,weight=500},
 stolen_phone={w=2,h=1,stack=1,label='Stolen phone',kind='loot',value=2,weight=800},
 stolen_laptop={w=2,h=2,stack=1,label='Stolen laptop',kind='loot',value=4,weight=2000},
 stolen_tv={w=4,h=2,stack=1,label='Stolen television',kind='loot',value=8,weight=6000},
 stolen_art={w=3,h=3,stack=1,label='Stolen artwork',kind='loot',value=9,weight=3000},
 stolen_tools={w=4,h=1,stack=1,label='Stolen tool case',kind='loot',value=4,weight=4000},
 lockpick={w=1,h=1,stack=5,label='Lockpick',kind='tool',weight=150},
 medkit={w=2,h=2,stack=3,label='Medkit',kind='medical',weight=750},
 bat={w=4,h=1,stack=1,label='Baseball bat',kind='weapon',weight=1200},
 bag_small={w=2,h=2,stack=1,label='Small bag',kind='bag',weight=500},
 bag_medium={w=3,h=2,stack=1,label='Backpack',kind='bag',weight=1000},
 bag_large={w=4,h=2,stack=1,label='Large duffel',kind='bag',weight=1500},
 pistol={w=2,h=2,stack=1,label='Pistol',kind='weapon',weight=1000,price=1200,weapon='WEAPON_PISTOL',ammo='ammo_9mm',range=65},
 rifle={w=4,h=2,stack=1,label='Carbine rifle',kind='weapon',weight=3500,price=3600,weapon='WEAPON_CARBINERIFLE',ammo='ammo_rifle',range=120},
 ammo_9mm={w=1,h=1,stack=30,label='9 mm rounds',kind='ammo',weight=12,price=4},
 ammo_rifle={w=2,h=1,stack=30,label='Rifle rounds',kind='ammo',weight=20,price=8}
}
function NST.itemDefinition(item)
 return NST.itemCatalog[item] or {w=1,h=1,stack=1,label=item,kind='item',weight=1000}
end
function NST.gridSize(p)
 local defaults={pockets={4,4},bag_small={6,6},bag_medium={8,8},bag_large={10,10}}
 local size=defaults[p.bag] or defaults.pockets
 return size[1],size[2]
end
local function integer(n) return type(n)=='number' and n==n and n%1==0 end
function NST.gridFits(entries,id,x,y,w,h,cols,rows)
 if not integer(x) or not integer(y) or x<0 or y<0 or x+w>cols or y+h>rows then return false end
 for _,e in ipairs(entries) do
  if e.id~=id and not e.overflow and x<e.x+e.w and x+w>e.x and y<e.y+e.h and y+h>e.y then return false end
 end
 return true
end
function NST.gridLayout(p)
 local cols,rows=NST.gridSize(p);local entries,waiting={},{};local saved=p.grid or {};local keys={};local counts=NST.copy(p.items or {})
 counts.cash=p.cash or 0
 for item,n in pairs(counts) do if n>0 then keys[#keys+1]=item end end;table.sort(keys)
 local overflowUnits=0
 for _,item in ipairs(keys) do
  local def=NST.itemDefinition(item);local total=counts[item];local index=0
  while total>0 do
   index=index+1;local amount=math.min(total,def.stack);local id=item..':'..index;total=total-amount
   if #entries+#waiting>=200 then overflowUnits=overflowUnits+amount+total;break end
   local e={id=id,item=item,amount=amount,w=def.w,h=def.h,rotated=0}
   local old=saved[id]
   if old and (old.rotated==0 or old.rotated==1) then
    e.rotated=old.rotated;if e.rotated==1 then e.w,e.h=e.h,e.w end
    if NST.gridFits(entries,id,old.x,old.y,e.w,e.h,cols,rows) then e.x=old.x;e.y=old.y;entries[#entries+1]=e else waiting[#waiting+1]=e end
   else waiting[#waiting+1]=e end
  end
 end
 for _,e in ipairs(waiting) do
  local placed=false
  for turn=0,1 do
   if turn==1 then e.w,e.h=e.h,e.w;e.rotated=1-e.rotated end
   for y=0,rows-e.h do
    for x=0,cols-e.w do
     if NST.gridFits(entries,e.id,x,y,e.w,e.h,cols,rows) then e.x=x;e.y=y;placed=true;break end
    end
    if placed then break end
   end
   if placed then break end
  end
  if not placed then e.overflow=true;overflowUnits=overflowUnits+e.amount end
  entries[#entries+1]=e
 end
 return {cols=cols,rows=rows,entries=entries,overflow=overflowUnits,revision=p.gridRevision or 0}
end
function NST.saveGrid(p,layout)
 p.grid={}
 for _,e in ipairs(layout.entries) do if not e.overflow then p.grid[e.id]={x=e.x,y=e.y,rotated=e.rotated} end end
end
function NST.inventorySignature(p)
 local parts={p.bag or '',tostring(p.cash or 0),p.equippedWeapon or ''}
 local keys={};for item,n in pairs(p.items or {}) do if n>0 then keys[#keys+1]=item end end;table.sort(keys)
 for _,item in ipairs(keys) do parts[#parts+1]=item..'='..p.items[item] end
 for _,e in ipairs(NST.gridLayout(p).entries) do parts[#parts+1]=e.id..':'..tostring(e.x)..':'..tostring(e.y)..':'..e.rotated end
 return table.concat(parts,'|')
end
NST.handlers.inventoryMove=function(s,c,a)
 local p=NST.player(s,c.id)
 NST.assert(p.alive and (p.jailUntil or 0)<=c.now and not p.surrendered,NSTText('cannotUse'))
 NST.assert(a.revision==(p.gridRevision or 0),NSTText('inventoryChanged'))
 NST.assert(a.rotated==0 or a.rotated==1,NSTText('invalidPlacement'))
 local layout=NST.gridLayout(p);local chosen
 for _,entry in ipairs(layout.entries) do if entry.id==a.entry then chosen=entry;break end end
 NST.assert(chosen,NSTText('inventoryChanged'))
 local def=NST.itemDefinition(chosen.item);local w,h=def.w,def.h;if a.rotated==1 then w,h=h,w end
 NST.assert(NST.gridFits(layout.entries,chosen.id,a.x,a.y,w,h,layout.cols,layout.rows),NSTText('invalidPlacement'))
 chosen.x=a.x;chosen.y=a.y;chosen.w=w;chosen.h=h;chosen.rotated=a.rotated;chosen.overflow=nil
 NST.saveGrid(p,layout)
end
-- Rarity affects presentation and sale value, independently of occupied cells.
NST.itemCatalog.stolen.rarity='common'
NST.itemCatalog.stolen_watch.rarity='common'
NST.itemCatalog.stolen_phone.rarity='common'
NST.itemCatalog.stolen_tools.rarity='common'
NST.itemCatalog.stolen_laptop.rarity='rare';NST.itemCatalog.stolen_laptop.value=6
NST.itemCatalog.stolen_tv.rarity='rare';NST.itemCatalog.stolen_tv.value=10
NST.itemCatalog.stolen_art.rarity='epic';NST.itemCatalog.stolen_art.value=15
function NST.refreshGrids(old,nextState)
 for id,p in pairs(nextState.players) do
  local prior=old.players[id];local changed=not prior or NST.inventorySignature(prior)~=NST.inventorySignature(p)
  NST.saveGrid(p,NST.gridLayout(p))
  p.gridRevision=(prior and prior.gridRevision or 0)+(changed and 1 or 0)
 end
end
