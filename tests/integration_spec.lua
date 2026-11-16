-- Real modules, deterministic server context: no FiveM/native stubs are claimed as a game test.
dofile('resource/server/core.lua')
dofile('resource/shared/config.lua')
dofile('resource/server/gameplay.lua')
dofile('resource/server/police.lua')
local s={players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1}
local now=10000
local positions={a=NSTConfig.robberies.shop.pos,b=NSTConfig.fence,c=NSTConfig.policeStation}
for id in pairs(positions) do NST.player(s,id) end
local function context(id)
    local c={id=id,now=now,pos=positions[id],online={},policeCount=0}
    for key,pos in pairs(positions) do c.online[key]={pos=pos,alive=s.players[key].alive}; if s.players[key].role=='police' and s.players[key].kit and s.players[key].alive then c.policeCount=c.policeCount+1 end end
    return c
end
local function act(id,name,args) s=NST.apply(s,context(id),name,args) end
local function fail(id,name,args) local before=NST.copy(s); local ok=pcall(NST.apply,s,context(id),name,args); assert(not ok,name..' accepted invalid transition'); assert(s.players[id].cash==before.players[id].cash) end
local function advance(seconds)
    for _=1,seconds do now=now+1; local c=context('a'); NST.gameTick(s,c); NST.policeTick(s,c) end
end
-- A full public progression path: two robberies -> cash -> gang -> hideout.
act('a','robberyStart',{id='shop'}); advance(45); act('a','robberyFinish',{id='shop'})
positions.a=NSTConfig.fence; act('a','fence',{amount=6}); assert(s.players.a.cash==950)
advance(555); positions.a=NSTConfig.robberies.shop.pos
act('a','robberyStart',{id='shop'}); advance(45); act('a','robberyFinish',{id='shop'})
positions.a=NSTConfig.fence; act('a','fence',{amount=6}); assert(s.players.a.cash==1400)
act('a','gangCreate',{name='Concrete'}); positions.a=NSTConfig.hideouts.davis.pos
act('a','hideoutBuy',{id='davis'}); act('a','gangDeposit',{amount=100}); assert(s.gangs[s.players.a.gang].bank==100)
-- Lawful duty produces reusable kit flags, never saleable inventory.
act('c','police_duty'); assert(s.players.c.kit and next(s.players.c.items)==nil)
positions.a=NSTConfig.shop; act('a','shopBuy',{item='lockpick',amount=1})
positions.a=NSTConfig.robberies.depot.pos; act('a','robberyStart',{id='depot'}); advance(100); act('a','robberyFinish',{id='depot'})
assert(s.players.a.items.stolen==16 and s.players.a.items.lockpick==0)
fail('a','robberyFinish',{id='depot'})
positions.a=NSTConfig.hideouts.davis.pos; act('a','hideoutStore',{item='stolen',amount=16})
assert(s.gangs[s.players.a.gang].items.stolen==16)
-- Rival raids the secured loot. A defender cannot withdraw during warning.
act('b','gangCreate',{name='Rivaler'}); positions.b=NSTConfig.hideouts.davis.pos
act('b','raid_start',{hideout='davis'}); fail('a','hideoutTake',{item='stolen',amount=16}); fail('a','gangWithdraw',{amount=100})
fail('b','raid_finish',{hideout='davis'}); advance(120); act('b','raid_finish',{hideout='davis'})
assert(s.gangs[s.players.a.gang].bank==75 and s.gangs[s.players.a.gang].items.stolen==12)
assert(s.players.b.cash==275 and s.players.b.items.stolen==4)
fail('b','raid_finish',{hideout='davis'}); fail('b','raid_start',{hideout='davis'})
-- Arrest of the raider confiscates loot; reconnect cannot clear sentence.
positions.c=positions.b; fail('a','police_arrest',{target='b'})
fail('c','police_arrest',{target='b'}); act('b','surrender'); act('c','police_arrest',{target='b'})
assert(not s.players.b.items.stolen and s.players.b.jailUntil>now)
fail('b','robberyStart',{id='shop'}); fail('b','raid_start',{hideout='davis'})
local sentence=s.players.b.jailUntil; NST.onDisconnect(s,context('b')); assert(s.players.b.jailUntil==sentence)
-- Death drops obey a single-consumer rule; police equipment never enters drops.
positions.c=NSTConfig.policeStation; NST.onDeath(s,context('c'))
local policeDrop=s.drops[tostring(s.nextDrop)]; assert(next(policeDrop.items)==nil)
NST.onDeath(s,context('a')); local id=tostring(s.nextDrop); assert(s.drops[id])
advance(21); positions.b=positions.a
fail('b','loot',{drop=id}) -- still incarcerated
advance(90); assert(s.players.b.alive); advance(21); act('b','loot',{drop=id}); assert(not s.drops[id]); fail('b','loot',{drop=id})
-- Invariant: inventories and cash remain nonnegative across the complete chain.
for _,p in pairs(s.players) do assert(p.cash>=0); for _,n in pairs(p.items) do assert(n>=0 and n%1==0) end end
for _,g in pairs(s.gangs) do assert(g.bank>=0); for _,n in pairs(g.items) do assert(n>=0 and n%1==0) end end
print('integration_spec: earned progression, police-gated depot, secured loot, bounded raid, arrest persistence, single-consumer drops passed')
