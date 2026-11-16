-- Pure authoritative state transitions. No network handlers or native calls here.
local function check(v,m) if not v then error(m,0) end end
local function cfg(k,default) return (NSTConfig.police or {})[k] or default end
local function player(s,id) return NST.player(s,id) end
local function active(p,now)
    check(p.alive ~= false, 'You are dead.')
    check((p.jailUntil or 0)<=now, 'You are serving a sentence.')
end
local function near(a,b,r) return a and b and NST.near(a,b,r) end
local function station(ctx) check(near(ctx.pos,cfg('station',NSTConfig.policeStation or {x=441.2,y=-981.9,z=30.7}),8),'Visit the police station.') end
local function free(p,now) active(p,now); check(not p.surrendered,'You have surrendered.'); check((p.protectedUntil or 0)<=now,'You have spawn protection.') end
local function drop(s,p,pos,now,id)
    s.drops=s.drops or {}; s.nextDrop=(s.nextDrop or 0)+1
    local items={}; for name,n in pairs(p.items or {}) do if n>0 then items[name]=n end end
    local cash=math.floor((p.cash or 0)*0.2)
    p.cash=(p.cash or 0)-cash; p.items={}; p.kit=false; p.vehicleRequested=false
    local key=tostring(s.nextDrop)
    s.drops[key]={id=key,owner=id,pos=pos,items=items,cash=cash,unlockAt=now+20,expiresAt=now+600}
end
NST.handlers.police_duty=function(s,ctx,a)
    local p=player(s,ctx.id); active(p,ctx.now); station(ctx)
    check((p.roleLockedUntil or 0)<=ctx.now,'Wait before changing roles again.')
    check((p.wantedUntil or 0)<=ctx.now and not p.robbery and not p.raid,'You cannot change roles during criminal activity.')
    check(not p.gang,'Leave your gang before joining the police.')
    check((p.items.stolen or 0)==0,'Store or sell your stolen goods first.')
    if p.role=='police' then p.role='criminal'; p.kit=false; p.vehicleRequested=false
    else p.role='police'; p.kit=true end
    p.surrendered=false; p.roleLockedUntil=ctx.now+cfg('roleCooldown',600)
    return 'Duty status changed.'
end
NST.handlers.police_vehicle=function(s,ctx)
    local p=player(s,ctx.id); active(p,ctx.now); station(ctx)
    check(p.role=='police' and p.kit,'Only on-duty officers can do this.')
    check(not p.vehicleRequested,'Return your current duty vehicle first.')
    p.vehicleRequested=true
    return 'Duty vehicle requested.'
end
NST.handlers.police_return_vehicle=function(s,ctx)
    local p=player(s,ctx.id); station(ctx); check(p.role=='police','Police only.')
    p.vehicleRequested=false; return 'Duty vehicle returned.'
end
NST.handlers.surrender=function(s,ctx)
    local p=player(s,ctx.id); active(p,ctx.now)
    p.surrendered=not p.surrendered
    return p.surrendered and 'You have surrendered.' or 'You are no longer surrendering.'
end
NST.handlers.police_arrest=function(s,ctx,a)
    local p=player(s,ctx.id); active(p,ctx.now); check(p.role=='police','Only on-duty officers can do this.')
    check(a.target~=ctx.id and ctx.online[a.target],'The player is not connected.')
    local target=player(s,a.target)
    check(near(ctx.pos,ctx.online[a.target].pos,3),'The player is too far away.')
    check(target.role~='police' and (target.wantedUntil or 0)>ctx.now,'The player is not wanted.')
    check((target.protectedUntil or 0)<=ctx.now,'The player has spawn protection.')
    check(target.alive~=false and target.surrendered,'The player must be alive and surrendering.')
    target.items.stolen=nil; target.wantedUntil=0; target.surrendered=false
    target.jailUntil=ctx.now+cfg('sentence',90); target.robbery=nil; target.raid=nil
    target.kit=false; target.vehicleRequested=false
    return 'Arrest recorded. Stolen goods confiscated.'
end
NST.onDeath=function(s,ctx)
    local p=player(s,ctx.id); if p.alive==false then return end
    p.alive=false; p.deadAt=ctx.now; p.surrendered=false; p.robbery=nil; p.raid=nil
    drop(s,p,ctx.pos,ctx.now,ctx.id)
end
NST.onDisconnect=function(s,ctx)
    local p=s.players[ctx.id]; if not p then return end
    -- Custody deadline and wanted status persist across reconnects.
    if p.alive~=false and ((p.combatUntil or 0)>ctx.now or p.robbery or p.raid or p.surrendered) then
        NST.onDeath(s,ctx)
    end
    p.robbery=nil; p.raid=nil; p.kit=false; p.vehicleRequested=false
end
NST.handlers.respawn=function(s,ctx)
    local p=player(s,ctx.id)
    check(p.alive==false and ctx.now>=(p.deadAt or ctx.now)+cfg('respawnDelay',15),'Respawn is not available yet.')
    p.alive=true; p.surrendered=false; p.protectedUntil=ctx.now+cfg('spawnProtection',20)
    p.kit=p.role=='police' and (p.jailUntil or 0)<=ctx.now
    p.respawnSerial=(p.respawnSerial or 0)+1
    return 'You have respawned.'
end
NST.handlers.loot=function(s,ctx,a)
    local p=player(s,ctx.id); free(p,ctx.now)
    local d=s.drops[tostring(a.drop)]
    check(d and d.expiresAt>ctx.now,'This loot is no longer available.')
    check(near(ctx.pos,d.pos,3),'The loot is too far away.')
    check(d.owner==ctx.id or ctx.now>=d.unlockAt,'The owner has temporary priority.')
    if p.role=='police' then s.drops[tostring(a.drop)]=nil; return 'Loot confiscated.' end
    local total=0; for _,n in pairs(p.items) do total=total+n end
    for _,n in pairs(d.items) do total=total+n end
    check(total<=(NSTConfig.inventoryLimit or 80),'Your inventory is full.')
    for name,n in pairs(d.items) do p.items[name]=(p.items[name] or 0)+n end
    p.cash=p.cash+d.cash; s.drops[tostring(a.drop)]=nil
    return 'Loot collected.'
end
local function hideout(s,id)
    local h=s.hideouts[id]; local c=(NSTConfig.hideouts or {})[id]
    check(h and c,'This hideout does not exist.'); return h,c
end
local function defenderOnline(s,ctx,gang)
    for id in pairs(ctx.online or {}) do if s.players[id] and s.players[id].gang==gang then return true end end
    return false
end
NST.handlers.raid_start=function(s,ctx,a)
    local p=player(s,ctx.id); free(p,ctx.now)
    check((p.protectedUntil or 0)<=ctx.now,'Wait for your spawn protection to expire.')
    local h,c=hideout(s,a.hideout)
    check(h.gang and h.gang~=p.gang,'You cannot raid your own hideout.')
    check(p.role=='police' or p.gang,'You must be in a gang or be a police officer.')
    check(not h.raid and (h.raidCooldown or 0)<=ctx.now,'This hideout is protected against another raid.')
    check(not p.raid,'You are already taking part in a raid.')
    check(near(ctx.pos,c.pos or c,15),'Visit the hideout.')
    local defenders=defenderOnline(s,ctx,h.gang)
    local lastSeen=h.lastDefenderSeen or h.purchasedAt or ctx.now
    check(defenders or ctx.now-lastSeen>=cfg('offlineProtection',900),'This hideout has temporary offline protection.')
    if defenders then h.lastDefenderSeen=ctx.now end
    h.raid={attacker=ctx.id,gang=p.gang,police=p.role=='police',startsAt=ctx.now+60,endsAt=ctx.now+180,lastSeen=ctx.now,presence=0}
    h.raidCooldown=ctx.now+1800; p.raid=a.hideout; p.combatUntil=ctx.now+180
    if p.role~='police' then p.wantedUntil=math.max(p.wantedUntil or 0,ctx.now+600) end
    s.alerts=s.alerts or {}; s.alerts['raid:'..a.hideout]={kind='raid',pos=c.pos or c,expiresAt=ctx.now+180,text='Raid starts in 60 seconds!'}
    return 'Raid warning issued. Stay near the target.'
end
NST.handlers.raid_finish=function(s,ctx,a)
    local p=player(s,ctx.id); free(p,ctx.now)
    local h,c=hideout(s,a.hideout); local r=h.raid
    check(r and r.attacker==ctx.id and p.raid==a.hideout,'No active raid.')
    check(ctx.now>=r.startsAt and ctx.now<=r.endsAt and r.presence>=60,'Hold the target for at least 60 seconds during the raid window.')
    check(near(ctx.pos,c.pos or c,10),'You are too far from the target.')
    check((r.police and p.role=='police') or (not r.police and p.gang==r.gang),'Your role has changed.')
    local g=s.gangs[h.gang]; check(g,'The defending gang no longer exists.')
    local fraction=0.30-0.05*math.min(3,math.max(1,h.level or 1))
    local cash=math.floor((g.bank or 0)*fraction); local stolen=math.floor(((g.items or {}).stolen or 0)*fraction)
    local total=0; for _,n in pairs(p.items) do total=total+n end
    check(r.police or total+stolen<=(NSTConfig.inventoryLimit or 80),'Your inventory is full.')
    g.bank=(g.bank or 0)-cash; g.items=g.items or {}; g.items.stolen=(g.items.stolen or 0)-stolen
    if not r.police then p.cash=p.cash+cash; p.items.stolen=(p.items.stolen or 0)+stolen end
    h.raid=nil; p.raid=nil
    return 'Raid complete. At most 25 percent of the treasury and stolen goods were taken.'
end
NST.policeTick=function(s,ctx)
    for id,d in pairs(s.drops or {}) do if d.expiresAt<=ctx.now then s.drops[id]=nil end end
    for id,h in pairs(s.hideouts or {}) do
        if defenderOnline(s,ctx,h.gang) then h.lastDefenderSeen=ctx.now
        elseif not h.lastDefenderSeen then h.lastDefenderSeen=h.purchasedAt or ctx.now end
        local r=h.raid
        if r then
            local p=s.players[r.attacker]; local o=ctx.online[r.attacker]; local c=(NSTConfig.hideouts or {})[id]
            if ctx.now>r.endsAt or not p or p.alive==false or p.surrendered or (p.jailUntil or 0)>ctx.now or p.raid~=id or (r.police and p.role~='police') or (not r.police and p.gang~=r.gang) or not o or not o.alive or not c or not near(o.pos,c.pos or c,15) then
                h.raid=nil; if p then p.raid=nil end
            else
                if ctx.now>=r.startsAt then r.presence=r.presence+math.max(0,math.min(5,ctx.now-math.max(r.lastSeen,r.startsAt))) end
                r.lastSeen=ctx.now
            end
        end
    end
end
