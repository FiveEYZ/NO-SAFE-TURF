dofile('resource/server/core.lua')
dofile('resource/shared/config.lua')
dofile('resource/server/gameplay.lua')
dofile('resource/server/police.lua')
local function state() return {players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1} end
local function ctx(id,pos) return {id=id,now=1000,pos=pos or NSTConfig.robberies.shop.pos,online={},policeCount=1} end
local function reject(s,c,action,args) local ok=pcall(NST.apply,s,c,action,args); assert(not ok,action..' should reject') end
local s=state(); local c=ctx('a'); NST.player(s,'a')
s=NST.apply(s,c,'robberyStart',{id='shop'})
reject(s,c,'robberyFinish',{id='shop'})
for i=1,45 do c.now=1000+i; c.online.a={pos=c.pos,alive=true}; NST.gameTick(s,c) end
s=NST.apply(s,c,'robberyFinish',{id='shop'}); assert(not s.players.a.items.stolen)
s=NST.apply(s,c,'loot',{drop=tostring(s.nextDrop),item='stolen',amount=6}); assert(s.players.a.items.stolen==6)
reject(s,c,'robberyFinish',{id='shop'}); assert(s.players.a.items.stolen==6)
reject(s,c,'fence',{amount=6}); c.pos=NSTConfig.fence
s=NST.apply(s,c,'fence',{amount=6}); assert(s.players.a.cash==950 and s.players.a.items.stolen==0)
reject(s,c,'fence',{amount=-1}); reject(s,c,'fence',{amount=1})
-- A restart/time jump cannot count as continuous presence.
local jump=state(); local j=ctx('j'); NST.player(jump,'j'); jump=NST.apply(jump,j,'robberyStart',{id='shop'})
j.now=1050; j.online.j={pos=j.pos,alive=true}; NST.gameTick(jump,j); reject(jump,j,'robberyFinish',{id='shop'})
-- Disconnect forfeits active robbery, no payout.
j.online={}; NST.gameTick(jump,j); assert(not jump.players.j.robbery and not jump.robberies.shop.actor)
s.players.a.cash=5000; s=NST.apply(s,c,'gangCreate',{name='Asphalt'})
local b=ctx('b',NSTConfig.hideouts.davis.pos); NST.player(s,'b')
s=NST.apply(s,c,'gangInvite',{target='b'}); s=NST.apply(s,b,'gangAccept',{gang=s.players.a.gang})
c.pos=NSTConfig.hideouts.davis.pos; s=NST.apply(s,c,'hideoutBuy',{id='davis'})
s=NST.apply(s,c,'gangDeposit',{amount=500}); reject(s,b,'gangWithdraw',{amount=1})
s=NST.apply(s,c,'gangRole',{target='b',role='officer'}); s=NST.apply(s,b,'gangWithdraw',{amount=100}); assert(s.gangs[s.players.a.gang].bank==400)
-- Copy/commit semantics prevent partial debit on failed storage/capacity.
s.gangs[s.players.a.gang].items.stolen=5; s.players.b.items.bat=80
reject(s,b,'hideoutTake',{item='stolen',amount=1}); assert(s.gangs[s.players.a.gang].items.stolen==5)
s.players.b.items={}; s=NST.apply(s,b,'hideoutTake',{item='stolen',amount=5})
reject(s,c,'hideoutTake',{item='stolen',amount=5}); assert(s.players.b.items.stolen==5)
s.hideouts.davis.raid={}; reject(s,c,'gangWithdraw',{amount=1}); reject(s,b,'hideoutStore',{item='stolen',amount=1})
s.hideouts.davis.raid=nil
local x=ctx('outsider',c.pos); NST.player(s,'outsider'); reject(s,x,'gangWithdraw',{amount=1})
s.players.outsider.role='police'; reject(s,x,'robberyStart',{id='shop'})
-- Captures require another gang and continuous non-contested presence.
c.pos=NSTConfig.territories.davis.pos; c.online={a={pos=c.pos,alive=true}}
reject(s,c,'territoryStart',{id='davis'})
s.players.outsider.role='criminal'; s.players.outsider.gang='rival'; s.gangs.rival={members={outsider='leader'},score=0}
c.online.outsider={pos=NSTConfig.fence,alive=true}; s=NST.apply(s,c,'territoryStart',{id='davis'})
for i=1,NSTConfig.captureSeconds do c.now=c.now+1; NST.gameTick(s,c) end
assert(s.territories.davis.owner==s.players.a.gang and s.gangs[s.players.a.gang].score==25)
print('gameplay_spec: robbery replay, continuity, disconnect, fence, authorization, atomic storage, raid lock, territory passed')
-- Membership cannot churn and territory recapture cannot repeat season points.
reject(s,b,'gangLeave',{})
c.now=c.now+NSTConfig.captureCooldown+1;s.territories.davis.owner='rival'
s=NST.apply(s,c,'territoryStart',{id='davis'})
for i=1,NSTConfig.captureSeconds do c.now=c.now+1;NST.gameTick(s,c) end
assert(s.gangs[s.players.a.gang].score==25)
local own=s.players.a.gang;s.territories.davis.owner='rival';s.territories.davis.cooldown=0;c.online.outsider=nil
reject(s,c,'territoryStart',{id='davis'})
assert(not own:find('license:',1,true))
