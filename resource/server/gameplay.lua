-- Pure, non-yielding state transitions. Caller commits a successful copy atomically.
local C, L = NSTConfig, NSTGameplayText
local function check(ok,msg) if not ok then error(msg,0) end end
local function player(s,c)
    local p=NST.player(s,c.id)
    check(p.alive and (p.jailUntil or 0)<=c.now,L.unavailable)
    return p
end
local function criminal(s,c)
    local p=player(s,c); check(p.role=='criminal',L.criminalOnly); check(not p.surrendered and (p.protectedUntil or 0)<=c.now,L.protectedOrSurrendered); return p
end
local function gang(s,p,manage)
    local g=p.gang and s.gangs[p.gang]
    local identity; for id,entry in pairs(s.players) do if entry==p then identity=id; break end end
    check(g and identity and g.members[identity],L.noGang)
    if manage then check(g.members[manage]=='leader' or g.members[manage]=='officer',L.permissionDenied) end
    return g
end
local function amount(v) check(type(v)=='number' and v==math.floor(v) and v>0 and v<=1000000,L.invalidAmount); return v end
local function near(c,pos,r) check(NST.near(c.pos,pos,r or 4),L.tooFar) end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function gangChange(s,c,p)
    check((p.gangChangeUntil or 0)<=c.now,L.gangCooldown)
    check(not p.robbery and not p.raid and (p.combatUntil or 0)<=c.now,L.gangActivity)
    for _,t in pairs(s.territories) do check(not t.capture or t.capture.actor~=c.id,L.gangActivity) end
end
local function rivalEligible(s,c,ownGang,owner)
    if owner and not s.gangs[owner] then owner=nil end
    local rival=false;local n=0
    for id,o in pairs(c.online or {}) do local p=s.players[id]
        if o.alive and p and p.alive~=false and (p.jailUntil or 0)<=c.now then
            n=n+1
            local g=p.gang and s.gangs[p.gang]
            if p.role=='criminal' and g and g.members[id] and p.gang~=ownGang and (not owner or p.gang==owner) then rival=true end
        end
    end
    return rival and n>=C.captureMinPlayers
end
local function add(p,item,n)
    local total=0; for _,v in pairs(p.items) do total=total+v end
    check(total+n<=C.inventoryLimit,L.inventoryFull); p.items[item]=(p.items[item] or 0)+n
end
local function take(p,item,n) check((p.items[item] or 0)>=n,L.notEnoughItems); p.items[item]=p.items[item]-n end
local function hideout(s,c,p)
    for id,h in pairs(s.hideouts) do
        if C.hideouts[id] and h.gang==p.gang and p.gang and NST.near(c.pos,C.hideouts[id].pos,5) then check(not h.raid,L.raidLock); return h,id end
    end
    error(L.visitHideout,0)
end
NST.handlers.gangCreate=function(s,c,a)
    local p=criminal(s,c); check(not p.gang,L.alreadyInGang)
    gangChange(s,c,p)
    check(type(a.name)=='string' and #a.name>=3 and #a.name<=28 and not a.name:find('[%c<>]'),L.gangName)
    for _,g in pairs(s.gangs) do check(g.name:lower()~=a.name:lower(),L.gangNameInUse) end
    check(p.cash>=C.gangCost,L.notEnoughMoney); p.cash=p.cash-C.gangCost
    s.nextGang=(s.nextGang or 0)+1; p.gang='gang:'..s.nextGang
    p.gangChangeUntil=c.now+C.gangChangeCooldown
    s.gangs[p.gang]={name=a.name,members={[c.id]='leader'},bank=0,items={},score=0,invites={}}
end
NST.handlers.gangInvite=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); local t=s.players[a.target]
    check(t and not t.gang and t.role=='criminal',L.cannotInvite)
    check(count(g.members)<C.gangLimit,L.gangFull); g.invites=g.invites or {}; g.invites[a.target]=c.now+C.gangInviteSeconds
end
NST.handlers.gangAccept=function(s,c,a)
    local p=criminal(s,c); check(not p.gang,L.alreadyInGang); local g=s.gangs[a.gang]
    gangChange(s,c,p)
    check(g and g.invites and (g.invites[c.id] or 0)>c.now,L.invitationExpired)
    check(count(g.members)<C.gangLimit,L.gangFull); p.gang=a.gang; g.members[c.id]='member'; g.invites[c.id]=nil; p.gangChangeUntil=c.now+C.gangChangeCooldown
end
NST.handlers.gangRole=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p); check(g.members[c.id]=='leader',L.leaderOnly)
    check(a.target~=c.id and g.members[a.target] and (a.role=='officer' or a.role=='member'),L.invalidRole); g.members[a.target]=a.role
end
NST.handlers.gangDeposit=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p); hideout(s,c,p); local n=amount(a.amount)
    check(p.cash>=n,L.notEnoughMoney); p.cash=p.cash-n; g.bank=g.bank+n
end
NST.handlers.gangWithdraw=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); hideout(s,c,p); local n=amount(a.amount)
    check(g.bank>=n,L.bankInsufficient); g.bank=g.bank-n; p.cash=p.cash+n
end
NST.handlers.robberyStart=function(s,c,a)
    local p=criminal(s,c); local def=C.robberies[a.id]; check(def,L.unknownRobbery); near(c,def.pos,def.radius)
    check(not p.robbery,L.alreadyRobbing); local r=s.robberies[a.id] or {}
    check(not r.actor and (r.cooldown or 0)<=c.now,L.robberyUnavailable)
    check((c.policeCount or 0)>=def.police,L.notEnoughPolice)
    check((p.protectedUntil or 0)<=c.now,L.protectedOrSurrendered)
    if def.tool then take(p,def.tool,1) end
    r.actor=c.id; r.progress=0; r.lastSeen=c.now; r.started=c.now; r.ends=c.now+def.duration; r.expires=c.now+def.timeout; r.cooldown=c.now+def.cooldown
    s.robberies[a.id]=r; p.robbery=a.id; p.wantedUntil=math.max(p.wantedUntil or 0,c.now+600)
    s.alerts['robbery:'..a.id]={kind='robbery',text=def.label,pos=def.pos,expiresAt=c.now+180,actor=c.id}
end
NST.handlers.robberyFinish=function(s,c,a)
    local p=criminal(s,c); local def=C.robberies[a.id]; local r=s.robberies[a.id]
    check(def and r and r.actor==c.id and p.robbery==a.id,L.noActiveRobbery)
    near(c,def.pos,def.radius); check((r.progress or 0)>=def.duration and c.now>=r.ends and c.now<=r.expires,L.robberyIncomplete)
    add(p,'stolen',def.reward); r.actor=nil; p.robbery=nil
end
NST.handlers.fence=function(s,c,a)
    local p=criminal(s,c); near(c,C.fence); local n=amount(a.amount); take(p,'stolen',n)
    local bonus=0; if p.gang then for _,t in pairs(s.territories) do if t.owner==p.gang then bonus=bonus+C.territoryBonus end end end
    p.cash=p.cash+math.floor(n*C.fencePrice*(1+math.min(bonus,0.15)))
    if p.gang and s.gangs[p.gang] then s.gangs[p.gang].score=s.gangs[p.gang].score+n end
end
NST.handlers.shopBuy=function(s,c,a)
    local p=criminal(s,c); near(c,C.shop); local price=C.prices[a.item]; check(price,L.unknownItem)
    local n=amount(a.amount or 1); check(n<=10 and p.cash>=price*n,L.shopInsufficient); add(p,a.item,n); p.cash=p.cash-price*n
end
NST.handlers.hideoutBuy=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); local def=C.hideouts[a.id]; check(def,L.unknownHideout); near(c,def.pos)
    check(not s.hideouts[a.id],L.hideoutOwned)
    for _,h in pairs(s.hideouts) do check(h.gang~=p.gang,L.gangOwnsHideout) end
    check(p.cash>=def.cost,L.notEnoughMoney); p.cash=p.cash-def.cost
    s.hideouts[a.id]={gang=p.gang,level=1,raidCooldown=0,purchasedAt=c.now,lastDefenderSeen=c.now,upkeepAt=c.now+C.upkeepSeconds}
end
NST.handlers.hideoutStore=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p); hideout(s,c,p); local n=amount(a.amount)
    check(a.item=='stolen' or C.prices[a.item],L.itemNotStorable); take(p,a.item,n); g.items[a.item]=(g.items[a.item] or 0)+n
end
NST.handlers.hideoutTake=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); hideout(s,c,p); local n=amount(a.amount)
    check(type(a.item)=='string' and (g.items[a.item] or 0)>=n,L.storageInsufficient); add(p,a.item,n); g.items[a.item]=g.items[a.item]-n
end
NST.handlers.hideoutUpgrade=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); local h=hideout(s,c,p)
    check(h.level<3,L.maxUpgrade); local cost=h.level*600
    check(g.bank>=cost,L.bankInsufficient); g.bank=g.bank-cost; h.level=h.level+1
end
NST.handlers.territoryStart=function(s,c,a)
    local p=criminal(s,c); gang(s,p); local def=C.territories[a.id]; check(def,L.unknownTerritory); near(c,def.pos,def.radius)
    local t=s.territories[a.id] or {}; check(not t.capture and t.owner~=p.gang and (t.cooldown or 0)<=c.now,L.territoryUnavailable)
    for _,existing in pairs(s.territories) do check(not existing.capture or existing.capture.actor~=c.id,L.alreadyCapturing) end
    check(rivalEligible(s,c,p.gang,t.owner),L.territoryPopulation)
    t.scored=t.scored or {};if t.owner then t.scored[t.owner]=true end
    t.capture={actor=c.id,gang=p.gang,ends=c.now+C.captureSeconds,progress=0,lastSeen=c.now}; s.territories[a.id]=t
end
function NST.gameTick(s,c)
    for id,r in pairs(s.robberies) do
        if r.actor then local o=(c.online or {})[r.actor]; local p=s.players[r.actor]
            if not o or not o.alive or not p or not p.alive or p.role~='criminal' or p.robbery~=id or p.surrendered or (p.jailUntil or 0)>c.now or (p.protectedUntil or 0)>c.now or c.now>r.expires or not NST.near(o.pos,C.robberies[id].pos,C.robberies[id].radius) then
                if p then p.robbery=nil end; r.actor=nil
            else r.progress=(r.progress or 0)+math.max(0,math.min(2,c.now-(r.lastSeen or c.now))); r.lastSeen=c.now end
        end
    end
    for id,t in pairs(s.territories) do
        if t.capture then
            local a=t.capture; local o=(c.online or {})[a.actor]; local p=s.players[a.actor]; local def=C.territories[id]; local rival=false; local contested=false
            for pid,po in pairs(c.online or {}) do local pp=s.players[pid]
                if pp and po.alive and pp.gang and pp.gang~=a.gang then rival=true; if NST.near(po.pos,def.pos,def.radius) then contested=true end end
            end
            if not o or not o.alive or not p or not p.alive or p.role~='criminal' or p.surrendered or (p.jailUntil or 0)>c.now or (p.protectedUntil or 0)>c.now or p.gang~=a.gang or not rivalEligible(s,c,a.gang,t.owner) or not NST.near(o.pos,def.pos,def.radius) then t.capture=nil
            elseif contested then a.contested=true; a.ends=c.now+C.captureSeconds; a.progress=0; a.lastSeen=c.now
            else a.contested=false; a.progress=(a.progress or 0)+math.max(0,math.min(2,c.now-(a.lastSeen or c.now))); a.lastSeen=c.now
            if a.progress>=C.captureSeconds then t.owner=a.gang; t.cooldown=c.now+C.captureCooldown; t.capture=nil; t.scored=t.scored or {}; if not t.scored[a.gang] then s.gangs[a.gang].score=s.gangs[a.gang].score+25;t.scored[a.gang]=true end end end
        end
    end
    for _,h in pairs(s.hideouts) do if c.now>=(h.upkeepAt or c.now+C.upkeepSeconds) then
        local g=s.gangs[h.gang]; if g then if g.bank>=C.upkeepCost*h.level then g.bank=g.bank-C.upkeepCost*h.level else h.level=math.max(1,h.level-1) end end
        h.upkeepAt=c.now+C.upkeepSeconds
    end end
end

NST.handlers.gangLeave=function(s,c)
    local p=criminal(s,c); local g=gang(s,p)
    gangChange(s,c,p);check((p.wantedUntil or 0)<=c.now,L.noLeaveWanted)
    for _,h in pairs(s.hideouts) do check(h.gang~=p.gang or not h.raid,L.gangUnderAttack) end
    if g.members[c.id]=='leader' then
        check(count(g.members)==1,L.leaderHasMembers)
        for _,h in pairs(s.hideouts) do check(h.gang~=p.gang,L.leaderHasHideout) end
        for _,t in pairs(s.territories) do check(t.owner~=p.gang,L.leaderHasTerritory) end
        s.gangs[p.gang]=nil
    else g.members[c.id]=nil end
    p.gang=nil;p.gangChangeUntil=c.now+C.gangChangeCooldown
end
