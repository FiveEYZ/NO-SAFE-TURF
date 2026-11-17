dofile('resource/server/core.lua')
dofile('resource/server/gameplay.lua')
dofile('resource/server/police.lua')
local s={players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1}
local c={id='a',now=1000,pos=NSTConfig.shop,online={},policeCount=1};NST.player(s,'a')
local function act(action,args) s=NST.apply(s,c,action,args) end
local function fail(action,args) assert(not pcall(NST.apply,s,c,action,args),action..' must fail') end
s.players.a.items={bat=1,medkit=1}
local layout=NST.gridLayout(s.players.a);assert(layout.overflow==0)
act('inventoryMove',{entry='bat:1',x=3,y=0,rotated=1,revision=0})
local rev=s.players.a.gridRevision;assert(s.players.a.grid['bat:1'].rotated==1)
fail('inventoryMove',{entry='bat:1',x=3,y=0,rotated=0,revision=rev}) -- outside bounds
fail('inventoryMove',{entry='bat:1',x=0,y=0,rotated=1,revision=0}) -- stale
fail('inventoryMove',{entry='bat:1',x=0.5,y=0,rotated=1,revision=rev})
local med=s.players.a.grid['medkit:1'];fail('inventoryMove',{entry='bat:1',x=med.x,y=med.y,rotated=1,revision=rev})
-- Distinct shapes, rarity and cash stacks remain physical.
assert(NST.itemCatalog.stolen_watch.w==1 and NST.itemCatalog.stolen_phone.w==2)
assert(NST.itemCatalog.stolen_tv.w==4 and NST.itemCatalog.stolen_art.h==3 and NST.itemCatalog.stolen_tools.h==1)
assert(NST.itemCatalog.stolen_art.rarity=='epic' and NST.itemCatalog.stolen_laptop.rarity=='rare')
s.players.a.items={};s.players.a.cash=10001
layout=NST.gridLayout(s.players.a);assert(#layout.entries==2)
-- Full 4x4 grid rejects an additional item even when weight is available.
s.players.a.cash=0;s.players.a.items={stolen_art=1,stolen_tools=1,stolen_phone=1,stolen_watch=1}
s.players.a.grid={};layout=NST.gridLayout(s.players.a);assert(layout.overflow==0)
local key=NST.newDrop(s,c,{lockpick=1},0);fail('loot',{drop=key,item='lockpick',amount=1});assert(s.drops[key].items.lockpick==1)
-- Reject failed drag transfer atomically; no loot removed on collision.
s.players.a.items={stolen_art=1};s.players.a.cash=0;s.players.a.grid={};s.players.a.gridRevision=5
local original=s.drops[key].items.lockpick
fail('loot',{drop=key,item='lockpick',amount=1,x=0,y=0,rotated=0,revision=5})
assert(s.drops[key].items.lockpick==original and not s.players.a.items.lockpick)
act('loot',{drop=key,item='lockpick',amount=1,x=3,y=0,rotated=0,revision=5});assert(s.players.a.grid['lockpick:1'].x==3)
-- Death/tick changes revision before persistence, not just action handlers.
local old=NST.copy(s);NST.onDeath(s,c);NST.refreshGrids(old,s);assert(s.players.a.gridRevision>old.players.a.gridRevision)
-- Mixed robbery reward types and rarity do not duplicate on replay.
s.players.a.alive=true;s.players.a.items={};s.players.a.cash=500;c.pos=NSTConfig.robberies.shop.pos
act('robberyStart',{id='shop'});for i=1,45 do c.now=c.now+1;c.online.a={pos=c.pos,alive=true};NST.gameTick(s,c) end
act('robberyFinish',{id='shop'});local d=s.drops[tostring(s.nextDrop)];assert(d.items.stolen_watch==2 and d.items.stolen_phone==2 and not d.items.stolen)
fail('robberyFinish',{id='shop'})
print('grid_spec: overlap, bounds, rotations, stale state, physical stacks, full grid, atomic drag transfer, death revisions and mixed rarity loot passed')
