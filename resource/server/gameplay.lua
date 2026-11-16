-- Pure, non-yielding state transitions. Caller commits a successful copy atomically.
local C = NSTConfig
local function check(ok,msg) if not ok then error(msg,0) end end
local function player(s,c)
    local p=NST.player(s,c.id)
    check(p.alive and (p.jailUntil or 0)<=c.now,'You cannot do this right now.')
    return p
end
local function criminal(s,c)
    local p=player(s,c); check(p.role=='criminal','Only criminals can do this.'); check(not p.surrendered and (p.protectedUntil or 0)<=c.now,'You have spawn protection or have surrendered.'); return p
end
local function gang(s,p,manage)
    local g=p.gang and s.gangs[p.gang]
    local identity; for id,entry in pairs(s.players) do if entry==p then identity=id; break end end
    check(g and identity and g.members[identity],'You are not in a gang.')
    if manage then check(g.members[manage]=='leader' or g.members[manage]=='officer','Permission denied.') end
    return g
end
local function amount(v) check(type(v)=='number' and v==math.floor(v) and v>0 and v<=1000000,'Invalid amount.'); return v end
local function near(c,pos,r) check(NST.near(c.pos,pos,r or 4),'You are too far away.') end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function add(p,item,n)
    local total=0; for _,v in pairs(p.items) do total=total+v end
    check(total+n<=C.inventoryLimit,'Your inventory is full.'); p.items[item]=(p.items[item] or 0)+n
end
local function take(p,item,n) check((p.items[item] or 0)>=n,'You do not have enough items.'); p.items[item]=p.items[item]-n end
local function hideout(s,c,p)
    for id,h in pairs(s.hideouts) do
        if C.hideouts[id] and h.gang==p.gang and p.gang and NST.near(c.pos,C.hideouts[id].pos,5) then check(not h.raid,'Storage is locked during a raid.'); return h,id end
    end
    error('Visit your gang hideout.',0)
end
NST.handlers.gangCreate=function(s,c,a)
    local p=criminal(s,c); check(not p.gang,'You are already in a gang.')
    check(type(a.name)=='string' and #a.name>=3 and #a.name<=28 and not a.name:find('[%c<>]'),'The name must be 3-28 characters long.')
    for _,g in pairs(s.gangs) do check(g.name:lower()~=a.name:lower(),'That name is already in use.') end
    check(p.cash>=C.gangCost,'You do not have enough money.'); p.cash=p.cash-C.gangCost
    p.gang=c.id; s.gangs[c.id]={name=a.name,members={[c.id]='leader'},bank=0,items={},score=0,invites={}}
end
NST.handlers.gangInvite=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); local t=s.players[a.target]
    check(t and not t.gang and t.role=='criminal','This player cannot be invited.')
    check(count(g.members)<C.gangLimit,'The gang is full.'); g.invites=g.invites or {}; g.invites[a.target]=c.now+300
end
NST.handlers.gangAccept=function(s,c,a)
    local p=criminal(s,c); check(not p.gang,'You are already in a gang.'); local g=s.gangs[a.gang]
    check(g and g.invites and (g.invites[c.id] or 0)>c.now,'The invitation is missing or has expired.')
    check(count(g.members)<C.gangLimit,'The gang is full.'); p.gang=a.gang; g.members[c.id]='member'; g.invites[c.id]=nil
end
NST.handlers.gangRole=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p); check(g.members[c.id]=='leader','Only the leader can change roles.')
    check(a.target~=c.id and g.members[a.target] and (a.role=='officer' or a.role=='member'),'Invalid role change.'); g.members[a.target]=a.role
end
NST.handlers.gangDeposit=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p); hideout(s,c,p); local n=amount(a.amount)
    check(p.cash>=n,'You do not have enough money.'); p.cash=p.cash-n; g.bank=g.bank+n
end
NST.handlers.gangWithdraw=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); hideout(s,c,p); local n=amount(a.amount)
    check(g.bank>=n,'The gang treasury has insufficient funds.'); g.bank=g.bank-n; p.cash=p.cash+n
end
NST.handlers.robberyStart=function(s,c,a)
    local p=criminal(s,c); local def=C.robberies[a.id]; check(def,'Unknown robbery.'); near(c,def.pos,def.radius)
    check(not p.robbery,'You already have an active robbery.'); local r=s.robberies[a.id] or {}
    check(not r.actor and (r.cooldown or 0)<=c.now,'This robbery is unavailable.')
    check((c.policeCount or 0)>=def.police,'Not enough officers on duty. Try the store robbery.')
    check((p.protectedUntil or 0)<=c.now,'Wait for your spawn protection to expire.')
    if def.tool then take(p,def.tool,1) end
    r.actor=c.id; r.progress=0; r.lastSeen=c.now; r.started=c.now; r.ends=c.now+def.duration; r.expires=c.now+def.timeout; r.cooldown=c.now+def.cooldown
    s.robberies[a.id]=r; p.robbery=a.id; p.wantedUntil=math.max(p.wantedUntil or 0,c.now+600)
    s.alerts['robbery:'..a.id]={kind='robbery',text=def.label,pos=def.pos,expiresAt=c.now+180,actor=c.id}
end
NST.handlers.robberyFinish=function(s,c,a)
    local p=criminal(s,c); local def=C.robberies[a.id]; local r=s.robberies[a.id]
    check(def and r and r.actor==c.id and p.robbery==a.id,'You do not have this robbery active.')
    near(c,def.pos,def.radius); check((r.progress or 0)>=def.duration and c.now>=r.ends and c.now<=r.expires,'The robbery is not complete or has expired.')
    add(p,'stolen',def.reward); r.actor=nil; p.robbery=nil
end
NST.handlers.fence=function(s,c,a)
    local p=criminal(s,c); near(c,C.fence); local n=amount(a.amount); take(p,'stolen',n)
    local bonus=0; if p.gang then for _,t in pairs(s.territories) do if t.owner==p.gang then bonus=bonus+C.territoryBonus end end end
    p.cash=p.cash+math.floor(n*C.fencePrice*(1+math.min(bonus,0.15)))
    if p.gang and s.gangs[p.gang] then s.gangs[p.gang].score=s.gangs[p.gang].score+n end
end
NST.handlers.shopBuy=function(s,c,a)
    local p=criminal(s,c); near(c,C.shop); local price=C.prices[a.item]; check(price,'Unknown item.')
    local n=amount(a.amount or 1); check(n<=10 and p.cash>=price*n,'Insufficient funds or purchase quantity too large.'); add(p,a.item,n); p.cash=p.cash-price*n
end
NST.handlers.hideoutBuy=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); local def=C.hideouts[a.id]; check(def,'Unknown hideout.'); near(c,def.pos)
    check(not s.hideouts[a.id],'This hideout is already owned.')
    for _,h in pairs(s.hideouts) do check(h.gang~=p.gang,'Your gang already owns a hideout.') end
    check(p.cash>=def.cost,'You do not have enough money.'); p.cash=p.cash-def.cost
    s.hideouts[a.id]={gang=p.gang,level=1,raidCooldown=0,purchasedAt=c.now,lastDefenderSeen=c.now,upkeepAt=c.now+C.upkeepSeconds}
end
NST.handlers.hideoutStore=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p); hideout(s,c,p); local n=amount(a.amount)
    check(a.item=='stolen' or C.prices[a.item],'This item cannot be stored.'); take(p,a.item,n); g.items[a.item]=(g.items[a.item] or 0)+n
end
NST.handlers.hideoutTake=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); hideout(s,c,p); local n=amount(a.amount)
    check(type(a.item)=='string' and (g.items[a.item] or 0)>=n,'Storage does not contain enough items.'); add(p,a.item,n); g.items[a.item]=g.items[a.item]-n
end
NST.handlers.hideoutUpgrade=function(s,c,a)
    local p=criminal(s,c); local g=gang(s,p,c.id); local h=hideout(s,c,p)
    check(h.level<3,'This hideout is fully upgraded.'); local cost=h.level*600
    check(g.bank>=cost,'The gang treasury has insufficient funds.'); g.bank=g.bank-cost; h.level=h.level+1
end
NST.handlers.territoryStart=function(s,c,a)
    local p=criminal(s,c); gang(s,p); local def=C.territories[a.id]; check(def,'Unknown territory.'); near(c,def.pos,def.radius)
    local t=s.territories[a.id] or {}; check(not t.capture and t.owner~=p.gang and (t.cooldown or 0)<=c.now,'This territory cannot be captured right now.')
    local rival=false; local n=0
    for id,o in pairs(c.online or {}) do local op=s.players[id]; if o.alive and op then n=n+1; if op.gang and op.gang~=p.gang then rival=true end end end
    check(n>=C.captureMinPlayers and rival,'A rival gang must be online.')
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
            if not o or not o.alive or not p or not p.alive or p.role~='criminal' or p.surrendered or (p.jailUntil or 0)>c.now or (p.protectedUntil or 0)>c.now or p.gang~=a.gang or not rival or not NST.near(o.pos,def.pos,def.radius) then t.capture=nil
            elseif contested then a.ends=c.now+C.captureSeconds; a.progress=0; a.lastSeen=c.now
            else a.progress=(a.progress or 0)+math.max(0,math.min(2,c.now-(a.lastSeen or c.now))); a.lastSeen=c.now
            if a.progress>=C.captureSeconds then t.owner=a.gang; t.cooldown=c.now+C.captureCooldown; t.capture=nil; s.gangs[a.gang].score=s.gangs[a.gang].score+25 end end
        end
    end
    for _,h in pairs(s.hideouts) do if c.now>=(h.upkeepAt or c.now+C.upkeepSeconds) then
        local g=s.gangs[h.gang]; if g then if g.bank>=C.upkeepCost*h.level then g.bank=g.bank-C.upkeepCost*h.level else h.level=math.max(1,h.level-1) end end
        h.upkeepAt=c.now+C.upkeepSeconds
    end end
end

NST.handlers.gangLeave=function(s,c)
    local p=criminal(s,c); local g=gang(s,p)
    check(not p.robbery and not p.raid and (p.wantedUntil or 0)<=c.now,'Finish your criminal activity before changing gangs.')
    for _,h in pairs(s.hideouts) do check(h.gang~=p.gang or not h.raid,'Your gang is under attack.') end
    if g.members[c.id]=='leader' then check(count(g.members)==1,'The leader can only leave a gang with no other members.'); for _,h in pairs(s.hideouts) do check(h.gang~=p.gang,'A gang that owns a hideout must retain its leader.') end; s.gangs[p.gang]=nil else g.members[c.id]=nil end
    p.gang=nil
end
