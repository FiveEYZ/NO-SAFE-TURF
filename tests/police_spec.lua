dofile('resource/server/core.lua')
dofile('resource/shared/config.lua')
dofile('resource/server/police.lua')
local function state() return {players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1} end
local function ctx(id,now,pos) return {id=id,now=now,pos=pos or NSTConfig.policeStation,online={},policeCount=1} end
local function fails(f) assert(not pcall(f),'expected rejection') end
local s=state(); local a=NST.player(s,'a'); local b=NST.player(s,'b')
local c=ctx('a',1000); c.online.b={pos=c.pos,alive=true}
b.wantedUntil=2000; b.surrendered=true
fails(function() NST.apply(s,c,'police_arrest',{target='b'}) end)
s=NST.apply(s,c,'police_duty',{}); assert(s.players.a.kit)
s=NST.apply(s,c,'police_arrest',{target='b'}); assert(s.players.b.jailUntil==1090)
local jail=s.players.b.jailUntil; NST.onDisconnect(s,ctx('b',1001)); assert(s.players.b.jailUntil==jail)
fails(function() NST.apply(s,ctx('b',1002),'police_duty',{}) end)
fails(function() NST.apply(s,ctx('a',1002),'police_duty',{}) end)
-- Protected suspects cannot be arrested.
s.players.b.jailUntil=0; s.players.b.wantedUntil=2000; s.players.b.surrendered=true; s.players.b.protectedUntil=1100
fails(function() NST.apply(s,c,'police_arrest',{target='b'}) end)
-- Exactly one looter gets the persisted drop, including replay by same player.
s=state(); a=NST.player(s,'a'); b=NST.player(s,'b'); local d=NST.player(s,'d'); a.items={stolen=8}; a.cash=100
NST.onDeath(s,ctx('a',100)); assert(s.players.a.cash==80); assert(s.drops['1'].items.stolen==8)
NST.onDeath(s,ctx('a',101)); assert(s.nextDrop==1)
fails(function() NST.apply(s,ctx('b',110),'loot',{drop='1'}) end)
s.players.b.bag='bag_small'
s=NST.apply(s,ctx('b',121),'loot',{drop='1'}); assert(s.players.b.items.stolen==8)
fails(function() NST.apply(s,ctx('d',121),'loot',{drop='1'}) end)
fails(function() NST.apply(s,ctx('b',122),'loot',{drop='1'}) end)
s=NST.apply(s,ctx('a',121),'respawn',{}); assert(s.players.a.alive and s.players.a.protectedUntil==141)
-- Raid warning, continuous presence, capped loss, replay prevention and disconnect cancellation.
s=state(); a=NST.player(s,'a'); b=NST.player(s,'b'); a.gang='attack'; b.gang='defend'
s.gangs.attack={members={a='leader'}}; s.gangs.defend={members={b='leader'},bank=1000,items={stolen=20}}; s.hideouts.davis={gang='defend',level=1}
c=ctx('a',1000,NSTConfig.hideouts.davis.pos); c.online={a={pos=c.pos,alive=true},b={pos=c.pos,alive=true}}
s=NST.apply(s,c,'raid_start',{hideout='davis'})
fails(function() NST.apply(s,c,'raid_finish',{hideout='davis'}) end)
for time=1002,1122,2 do c.now=time; NST.policeTick(s,c) end
s=NST.apply(s,c,'raid_finish',{hideout='davis'}); assert(s.gangs.defend.bank==750 and s.gangs.defend.items.stolen==15)
fails(function() NST.apply(s,c,'raid_finish',{hideout='davis'}) end)
fails(function() NST.apply(s,c,'raid_start',{hideout='davis'}) end)
c.now=3000; c.online.b=nil; s.hideouts.davis.lastDefenderSeen=2900
fails(function() NST.apply(s,c,'raid_start',{hideout='davis'}) end)
c.now=3800; local offlineRaid=NST.apply(s,c,'raid_start',{hideout='davis'}); assert(offlineRaid.hideouts.davis.raid)
assert(not s.hideouts.davis.raid) -- The test's speculative transition did not mutate the input.
c.online.b={pos=c.pos,alive=true}; s=NST.apply(s,c,'raid_start',{hideout='davis'}); c.online.a=nil; NST.policeTick(s,c); assert(not s.hideouts.davis.raid)
-- Combat logout drops only once and retains wanted status; surrender blocks loot.
s=state(); a=NST.player(s,'a'); a.items.stolen=3; a.combatUntil=200; a.wantedUntil=700
NST.onDisconnect(s,ctx('a',100)); assert(a.alive==false and a.wantedUntil==700 and s.nextDrop==1)
NST.onDisconnect(s,ctx('a',101)); assert(s.nextDrop==1)
b=NST.player(s,'b'); b.surrendered=true
fails(function() NST.apply(s,ctx('b',125),'loot',{drop='1'}) end)
-- Changing to surrender cancels an active raid before payout.
s=state(); a=NST.player(s,'a'); b=NST.player(s,'b'); a.gang='attack'; b.gang='defend'
s.gangs.attack={members={a='leader'}}; s.gangs.defend={members={b='leader'},bank=1000,items={stolen=20}}; s.hideouts.davis={gang='defend',level=3}
c=ctx('a',1000,NSTConfig.hideouts.davis.pos); c.online={a={pos=c.pos,alive=true},b={pos=c.pos,alive=true}}
s=NST.apply(s,c,'raid_start',{hideout='davis'}); s.players.a.surrendered=true; c.now=1002; NST.policeTick(s,c)
assert(not s.hideouts.davis.raid and not s.players.a.raid)
-- Purchased time survives restarts and starts the limited offline grace period.
s=state(); s.hideouts.davis={gang='absent',level=1,purchasedAt=1000}
c=ctx('a',1100,NSTConfig.hideouts.davis.pos); NST.policeTick(s,c); assert(s.hideouts.davis.lastDefenderSeen==1000)
print('police_spec: passed (roles, arrest, reconnect, spawn protection, death, loot race/replay, raid)')
-- Off-duty stale police role cannot arrest or raid; native-dead suspects cannot be arrested.
s=state(); a=NST.player(s,'a'); b=NST.player(s,'b');a.role='police';a.kit=false;b.wantedUntil=2000;b.surrendered=true
c=ctx('a',1000);c.online.b={pos=c.pos,alive=true};fails(function()NST.apply(s,c,'police_arrest',{target='b'})end)
a.kit=true;c.online.b.alive=false;fails(function()NST.apply(s,c,'police_arrest',{target='b'})end)
-- Administrative disconnect avoids combat-log penalty, actual death still drops once.
a.combatUntil=2000;local admin=ctx('a',1000);admin.administrative=true;NST.onDisconnect(s,admin);assert(a.alive)
admin.physicallyDead=true;NST.onDisconnect(s,admin);assert(not a.alive and s.nextDrop==1)
local cash=a.cash;assert(NST.onAdminRevive(s,ctx('a',1010)));assert(a.alive and a.cash==cash and s.nextDrop==1)
assert(not NST.onAdminRevive(s,ctx('a',1011)))
