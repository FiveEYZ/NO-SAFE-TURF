-- Pure authoritative state transitions. No network handlers or native calls here.
local L = assert(NSTPoliceLocale)
local check = NST.assert
local near = NST.near
local player = NST.player
local raidWarning, raidHold, raidWindow, raidCooldown = 60, 60, 180, 1800

local function cfg(key, default)
    return (NSTConfig.police or {})[key] or default
end

local function active(p, now)
    check(p.alive ~= false, L.dead)
    check((p.jailUntil or 0) <= now, L.jailed)
end

local function free(p, now)
    active(p, now)
    check(not p.surrendered, L.surrendered)
    check((p.protectedUntil or 0) <= now, L.protected)
end

local function atStation(ctx)
    check(near(ctx.pos,cfg('station', NSTConfig.policeStation),8), L.visitStation)
end

local function onDuty(p)
    return p.role == 'police' and p.kit == true
end

local function gangMember(s, p, id)
    local g = p.gang and s.gangs[p.gang]
    return p.role == 'criminal' and g and g.members and g.members[id]
end

local function cancelRaid(s, p, id)
    if not p.raid then return end
    local h = s.hideouts[p.raid]
    if h and h.raid and h.raid.attacker == id then
        h.raid = nil
        if s.alerts then s.alerts['raid:' .. p.raid] = nil end
    end
    p.raid = nil
end

local function drop(s, p, pos, now, id)
    local items = {}
    for name,n in pairs(p.items or {}) do
        if n > 0 then items[name] = n end
    end
    local cash = math.floor((p.cash or 0) / 5)
    p.cash = (p.cash or 0) - cash
    if p.bag then items[p.bag]=(items[p.bag] or 0)+1;p.bag=nil end
    p.items = {}
    p.kit = false
    p.vehicleRequested = false
    if cash == 0 and not next(items) then return end
    s.drops = s.drops or {}
    s.nextDrop = (s.nextDrop or 0) + 1
    local key = tostring(s.nextDrop)
    s.drops[key] = {id=key,owner=id,pos=pos,items=items,cash=cash,unlockAt=now+20,expiresAt=now+600}
end

NST.handlers.police_duty = function(s, ctx)
    local p = player(s, ctx.id)
    active(p, ctx.now)
    atStation(ctx)
    check(not p.surrendered, L.surrendered)
    check((p.roleLockedUntil or 0) <= ctx.now, L.roleCooldown)
    check((p.combatUntil or 0) <= ctx.now, L.combatRoleChange)
    check((p.wantedUntil or 0) <= ctx.now and not p.robbery and not p.raid, L.criminalActivity)
    check(not p.gang, L.leaveGang)
    check((p.items.stolen or 0) == 0, L.stolenGoods)
    if p.role == 'police' then
        p.role = 'criminal'
        p.kit = false
        p.vehicleRequested = false
    else
        p.role = 'police'
        p.kit = true
    end
    p.roleLockedUntil = ctx.now + cfg('roleCooldown', 600)
    return L.dutyChanged
end

NST.handlers.police_vehicle = function(s, ctx)
    local p = player(s, ctx.id)
    active(p, ctx.now)
    atStation(ctx)
    check(not p.surrendered, L.surrendered)
    check(onDuty(p), L.onDutyOnly)
    check(not p.vehicleRequested, L.returnVehicleFirst)
    p.vehicleRequested = true
    return L.vehicleRequested
end

NST.handlers.police_return_vehicle = function(s, ctx)
    local p = player(s, ctx.id)
    active(p, ctx.now)
    atStation(ctx)
    check(p.role == 'police', L.policeOnly)
    p.vehicleRequested = false
    return L.vehicleReturned
end

NST.handlers.surrender = function(s, ctx)
    local p = player(s, ctx.id)
    active(p, ctx.now)
    p.surrendered = not p.surrendered
    if p.surrendered then cancelRaid(s, p, ctx.id) end
    return p.surrendered and L.surrendered or L.unsurrendered
end

NST.handlers.police_arrest = function(s, ctx, a)
    local p = player(s, ctx.id)
    free(p, ctx.now)
    check(onDuty(p), L.onDutyOnly)
    local observed = ctx.online[a.target]
    local target = s.players[a.target]
    check(a.target ~= ctx.id and observed and target, L.targetOffline)
    check(near(ctx.pos, observed.pos, 3), L.targetDistant)
    check(target.role ~= 'police' and (target.wantedUntil or 0) > ctx.now, L.targetNotWanted)
    check((target.protectedUntil or 0) <= ctx.now, L.targetProtected)
    check(observed.alive and target.alive ~= false and target.surrendered, L.targetMustSurrender)
    target.items.stolen = nil
    target.wantedUntil = 0
    target.surrendered = false
    target.jailUntil = ctx.now + cfg('sentence', 90)
    target.robbery = nil
    cancelRaid(s, target, a.target)
    target.kit = false
    target.vehicleRequested = false
    return L.arrestRecorded
end

function NST.onDeath(s, ctx)
    local p = player(s, ctx.id)
    if p.alive == false then return end
    p.alive = false
    p.deadAt = ctx.now
    p.surrendered = false
    p.robbery = nil
    cancelRaid(s, p, ctx.id)
    drop(s, p, ctx.pos, ctx.now, ctx.id)
end

function NST.onDisconnect(s, ctx)
    local p = s.players[ctx.id]
    if not p then return end
    -- Preserve the custody deadline and wanted status across reconnects.
    local leftDuringActivity = ((p.combatUntil or 0) > ctx.now or p.robbery or p.raid or p.surrendered)
    if ctx.physicallyDead or (not ctx.administrative and leftDuringActivity) then
        NST.onDeath(s, ctx)
    end
    p.robbery = nil
    cancelRaid(s, p, ctx.id)
    p.kit = false
    p.vehicleRequested = false
end

local function revive(p, now)
    p.alive = true
    p.deadAt = nil
    p.surrendered = false
    p.combatUntil = nil
    p.protectedUntil = now + cfg('spawnProtection', 20)
    p.kit = p.role == 'police' and (p.jailUntil or 0) <= now
end

-- The adapter invokes this only after a trusted txAdmin heal event.
function NST.onAdminRevive(s, ctx)
    local p = s.players[ctx.id]
    if not p or p.alive ~= false then return false end
    revive(p, ctx.now)
    return true
end

NST.handlers.respawn = function(s, ctx)
    local p = player(s, ctx.id)
    check(p.alive == false and ctx.now >= (p.deadAt or ctx.now) + cfg('respawnDelay', 15), L.respawnUnavailable)
    revive(p, ctx.now)
    p.respawnSerial = (p.respawnSerial or 0) + 1
    return L.respawned
end

NST.handlers.loot = function(s, ctx, a)
    local p = player(s, ctx.id)
    free(p, ctx.now)
    local key = tostring(a.drop)
    local d = s.drops[key]
    check(d and d.expiresAt > ctx.now, L.lootUnavailable)
    check(near(ctx.pos, d.pos, 3), L.lootDistant)
    check(d.owner == ctx.id or ctx.now >= d.unlockAt, L.lootPriority)
    if p.role == 'police' then
        check(onDuty(p), L.onDutyOnly)
        s.drops[key] = nil
        return L.lootConfiscated
    end
    if a.item then
        local n=NST.amount(a.amount)
        if a.item=='cash' then
            check(d.cash>=n,L.lootUnavailable);d.cash=d.cash-n;p.cash=p.cash+n
        else
            check((d.items[a.item] or 0)>=n,L.lootUnavailable)
            d.items[a.item]=d.items[a.item]-n;p.items[a.item]=(p.items[a.item] or 0)+n
        end
        local remains=d.cash>0;for _,n in pairs(d.items) do if n>0 then remains=true end end
        if not remains then s.drops[key]=nil end
    else
        for name,n in pairs(d.items) do p.items[name]=(p.items[name] or 0)+n end
        p.cash=p.cash+d.cash;s.drops[key]=nil
    end
    NST.checkCarry(p)
    return L.lootCollected
end

local function hideout(s, id)
    local h = s.hideouts[id]
    local def = (NSTConfig.hideouts or {})[id]
    check(h and def, L.hideoutMissing)
    return h, def
end

local function defenderOnline(s, ctx, gang)
    for id in pairs(ctx.online or {}) do
        local p = s.players[id]
        if p and p.gang == gang and gangMember(s, p, id) then return true end
    end
    return false
end

local function raidEligible(s, p, id, r)
    if r.police then return onDuty(p) end
    return p.gang == r.gang and gangMember(s, p, id)
end

NST.handlers.raid_start = function(s, ctx, a)
    local p = player(s, ctx.id)
    free(p, ctx.now)
    local h, def = hideout(s, a.hideout)
    check(h.gang and h.gang ~= p.gang, L.raidOwnHideout)
    check(onDuty(p) or gangMember(s, p, ctx.id), L.raidEligible)
    check(not h.raid and (h.raidCooldown or 0) <= ctx.now, L.raidCooldown)
    check(not p.raid, L.raidActive)
    check(not p.robbery, L.raidDuringRobbery)
    local pos = def.pos or def
    check(near(ctx.pos, pos, 15), L.visitHideout)
    local defenders = defenderOnline(s, ctx, h.gang)
    local lastSeen = h.lastDefenderSeen or h.purchasedAt or ctx.now
    check(defenders or ctx.now - lastSeen >= cfg('offlineProtection', 900), L.raidOfflineProtection)
    if defenders then h.lastDefenderSeen = ctx.now end
    h.raid = {
        attacker=ctx.id,
        gang=p.gang,
        police=onDuty(p),
        startsAt=ctx.now+raidWarning,
        endsAt=ctx.now+raidWindow,
        lastSeen=ctx.now,
        presence=0
    }
    h.raidCooldown = ctx.now + raidCooldown
    p.raid = a.hideout
    if p.role ~= 'police' then p.wantedUntil = math.max(p.wantedUntil or 0, ctx.now + 600) end
    s.alerts = s.alerts or {}
    s.alerts['raid:' .. a.hideout] = {kind='raid',pos=pos,expiresAt=h.raid.endsAt,text=L.raidAlert}
    return L.raidWarningIssued
end

NST.handlers.raid_finish = function(s, ctx, a)
    local p = player(s, ctx.id)
    free(p, ctx.now)
    local h, def = hideout(s, a.hideout)
    local r = h.raid
    check(r and r.attacker == ctx.id and p.raid == a.hideout, L.raidInactive)
    check(ctx.now >= r.startsAt and ctx.now <= r.endsAt and r.presence >= raidHold, L.raidHoldTarget)
    check(near(ctx.pos, def.pos or def, 10), L.raidDistant)
    check(raidEligible(s, p, ctx.id, r), L.raidRoleChanged)
    local g = s.gangs[h.gang]
    check(g, L.raidDefenderMissing)
    local percent = 30 - 5 * math.min(3, math.max(1, h.level or 1))
    local cash = math.floor((g.bank or 0) * percent / 100)
    local stolen = math.floor(((g.items or {}).stolen or 0) * percent / 100)

    g.bank = (g.bank or 0) - cash
    g.items = g.items or {}
    g.items.stolen = (g.items.stolen or 0) - stolen
    if not r.police then
        p.cash = p.cash + cash
        p.items.stolen = (p.items.stolen or 0) + stolen
    end
    cancelRaid(s, p, ctx.id)
    return L.raidComplete
end

function NST.policeTick(s, ctx)
    for id,d in pairs(s.drops or {}) do
        if d.expiresAt <= ctx.now then s.drops[id] = nil end
    end
    for id,h in pairs(s.hideouts or {}) do
        if defenderOnline(s, ctx, h.gang) then
            h.lastDefenderSeen = ctx.now
        elseif not h.lastDefenderSeen then
            h.lastDefenderSeen = h.purchasedAt or ctx.now
        end
        local r = h.raid
        if r then
            local p = s.players[r.attacker]
            local observed = ctx.online[r.attacker]
            local def = (NSTConfig.hideouts or {})[id]
            local pos = def and (def.pos or def)
            if ctx.now > r.endsAt or not p or p.alive == false or p.surrendered or
                (p.jailUntil or 0) > ctx.now or (p.protectedUntil or 0) > ctx.now or
                p.raid ~= id or not raidEligible(s, p, r.attacker, r) or
                not observed or not observed.alive or not near(observed.pos, pos, 15) then
                if p and p.raid == id then p.raid = nil end
                h.raid = nil
                if s.alerts then s.alerts['raid:' .. id] = nil end
            else
                local inRange = near(observed.pos, pos, 10)
                if inRange and r.inRange and ctx.now >= r.startsAt then
                    local elapsed = ctx.now - math.max(r.lastSeen, r.startsAt)
                    r.presence = r.presence + math.max(0, math.min(5, elapsed))
                end
                r.inRange = inRange
                r.lastSeen = ctx.now
            end
        end
    end
end
