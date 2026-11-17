dofile('resource/server/core.lua')
dofile('resource/server/gameplay.lua')
dofile('resource/server/police.lua')
local s={players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1}
local c={id='a',now=1000,pos=NSTConfig.shop,online={},policeCount=1}
NST.player(s,'a');NST.player(s,'b')
local function act(name,args) s=NST.apply(s,c,name,args) end
local function fail(name,args)
 local cash=s.players.a.cash;local nextDrop=s.nextDrop
 assert(not pcall(NST.apply,s,c,name,args),name..' must fail')
 assert(s.players.a.cash==cash and s.nextDrop==nextDrop,'failure mutated source')
end
assert(NST.inventoryInfo(s.players.a).weight==50)
act('bagBuy',{item='bag_small'});assert(s.players.a.cash==350 and s.players.a.items.bag_small==1)
act('bagEquip',{item='bag_small'});assert(s.players.a.bag=='bag_small' and NST.inventoryInfo(s.players.a).capacity==18000)
fail('bagEquip',{item='bag_large'})
-- A robbery creates shared physical loot, never automatic inventory or cash.
c.pos=NSTConfig.robberies.depot.pos;s.players.a.items.lockpick=1
act('robberyStart',{id='depot'})
for _=1,100 do c.now=c.now+1;c.online.a={pos=c.pos,alive=true};NST.gameTick(s,c) end
act('robberyFinish',{id='depot'});local key=tostring(s.nextDrop)
assert(not s.players.a.items.stolen and s.players.a.cash==350 and s.drops[key].cash==500)
fail('robberyFinish',{id='depot'})
act('loot',{drop=key,item='stolen',amount=10});assert(s.drops[key].items.stolen==6)
fail('bagEquip',{item='none'})
fail('loot',{drop=key,item='stolen',amount=7})
local before=s.drops[key].cash;c.pos=NSTConfig.shop;fail('loot',{drop=key,item='cash',amount=100});assert(s.drops[key].cash==before)
c.pos=NSTConfig.robberies.depot.pos
-- Serialized competing claims cannot consume the same remaining stack twice.
c.id='b';act('loot',{drop=key,item='stolen',amount=6});c.id='a';fail('loot',{drop=key,item='stolen',amount=1})
act('loot',{drop=key,item='cash',amount=500});assert(not s.drops[key] and s.players.a.cash==850)
-- Full pockets reject cash, not just goods; source loot survives failure.
s.players.a.items={stolen=17};s.players.a.cash=10000
local d=NST.newDrop(s,c,{},100,'ground');fail('loot',{drop=d,item='cash',amount=1});assert(s.drops[d].cash==100)
-- Dropping and recollecting conserves cash, refreshes expiry and is bounded.
act('inventoryDrop',{item='cash',amount=500});local expiry=s.drops[d].expiresAt;c.now=c.now+899
act('inventoryDrop',{item='cash',amount=100});assert(s.drops[d].expiresAt>expiry and s.drops[d].cash==700)
fail('inventoryDrop',{item='cash',amount=-1})
-- Legacy overweight saves are retained and can unload, but cannot grow.
s.players.a.items={stolen=100};s.players.a.cash=1000
act('inventoryDrop',{item='stolen',amount=1});fail('loot',{drop=d,item='stolen',amount=1})
-- Equipped bags fall on death exactly once, and are not silently deleted.
NST.onDeath(s,c);local death=s.drops[tostring(s.nextDrop)];assert(death.items.bag_small==1 and not s.players.a.bag)
local count=s.nextDrop;NST.onDeath(s,c);assert(s.nextDrop==count)
print('inventory_spec: physical robbery loot, cash weight, bags, partial concurrent claims, range, atomic refusal, expiry and death passed')
