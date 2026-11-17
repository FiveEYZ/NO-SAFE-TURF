local envelope, busy, queue = nil, false, {}
local sessions, rates, vehicles, respawning, damageRates = {}, {}, {}, {}, {}
local administrativeDrops,adminHealing={},{}
local authorizedShots={}
local recoveryState=nil
local lastStorageError=nil
local function request(path,method,data)
    local p=promise.new()
    local ok=pcall(function() exports[GetCurrentResourceName()]:storageRequest(path,method or 'GET',data and json.encode(data) or '',function(code,body)
        local ok,obj=pcall(json.decode,body or '')
        p:resolve({code=code,data=ok and obj or nil})
    end) end)
    if not ok then p:resolve({code=503}) end
    local result=Citizen.Await(p)
    if result.code==503 then
        local message=result.data and result.data.error or NSTText('databaseNotReady')
        if message~=lastStorageError then print('[NST] '..message);lastStorageError=message end
    elseif result.code==200 then lastStorageError=nil end
    return result
end
local function identity(src)
    for _,id in ipairs(GetPlayerIdentifiers(src)) do if id:sub(1,8)=='license:' then return id end end
end
local function position(src)
    local ped=GetPlayerPed(src)
    if not ped or ped==0 then return nil end
    local v=GetEntityCoords(ped); return {x=v.x,y=v.y,z=v.z},GetEntityHealth(ped)>0
end
local function context(id,src)
    local c={id=id,now=os.time(),online={},policeCount=0}
    for _,n in ipairs(GetPlayers()) do
        local sid=tonumber(n); local key=identity(sid); local pos,alive=position(sid)
        if key and pos then
            c.online[key]={pos=pos,alive=alive,source=sid}
            local p=envelope and envelope.state.players[key]
            if p and p.role=='police' and p.kit and alive then c.policeCount=c.policeCount+1 end
        end
    end
    c.pos=c.online[id] and c.online[id].pos or (sessions[src] and sessions[src].pos)
    return c
end
local function tell(src,text) if src and src>0 then TriggerClientEvent('nst:notice',src,text) else print('[NST] '..tostring(text)) end end
local function view(src)
    if not envelope then return end
    local id=identity(src); local s=envelope.state; local p=id and s.players[id]; if not p then return end
    local gang=p.gang and s.gangs[p.gang]; local leaderboard,invites,people={}, {}, {}
    for key,g in pairs(s.gangs) do
        leaderboard[#leaderboard+1]={name=g.name,score=g.score or 0}
        if g.invites and (g.invites[id] or 0)>os.time() then invites[#invites+1]={id=key,name=g.name} end
    end
    table.sort(leaderboard,function(a,b)return a.score>b.score end)
    for _,n in ipairs(GetPlayers()) do people[#people+1]={id=tonumber(n),name=GetPlayerName(n)} end
    local pos=position(src); local drops={}
    for key,d in pairs(s.drops) do if NST.near(pos,d.pos,35) then drops[#drops+1]={id=key,pos=d.pos,unlockAt=d.unlockAt,kind=d.kind,expiresAt=d.expiresAt,items=NST.near(pos,d.pos,3) and d.items or nil,cash=NST.near(pos,d.pos,3) and d.cash or nil,canOpen=NST.near(pos,d.pos,3) and (d.owner==id or os.time()>=d.unlockAt)} end end
    local alerts={}
    for _,a in pairs(s.alerts or {}) do
        if (a.expiresAt or a.expires or 0)>os.time() and (p.role=='police' or a.kind=='raid') then alerts[#alerts+1]={kind=a.kind,text=a.text,pos=a.pos,expiresAt=a.expiresAt} end
    end
    -- Never expose other players' inventories. Invitation IDs are opaque gang keys.
    local ownGang=gang and {name=gang.name,bank=gang.bank,items=gang.items,score=gang.score,role=gang.members[id]}
    local territories,hideouts,robberies={},{},{}
    for key,r in pairs(s.robberies) do robberies[key]={progress=r.actor==id and r.progress or nil,cooldown=r.cooldown,active=r.actor~=nil,mine=r.actor==id} end
    for key,t in pairs(s.territories) do territories[key]={owner=t.owner and s.gangs[t.owner] and s.gangs[t.owner].name,capture=t.capture and {ends=t.capture.ends,progress=t.capture.progress,contested=t.capture.contested}} end
    for key,h in pairs(s.hideouts) do hideouts[key]={owner=s.gangs[h.gang] and s.gangs[h.gang].name,level=h.level,raid=h.raid and {startsAt=h.raid.startsAt,endsAt=h.raid.endsAt,presence=h.raid.presence}} end
    TriggerClientEvent('nst:state',src,{player=p,inventory=NST.inventoryInfo(p),gang=ownGang,invites=invites,people=people,drops=drops,alerts=alerts,territories=territories,hideouts=hideouts,robberies=robberies,leaderboard=leaderboard,season=s.season,nextWipe=envelope.nextWipe,now=os.time()})
end
local function broadcast()
    for _,src in ipairs(GetPlayers()) do view(tonumber(src)) end
end
local function cleanupVehicle(id)
    local entity=vehicles[id]; if entity and DoesEntityExist(entity) then DeleteEntity(entity) end; vehicles[id]=nil
end
local function effects(old,s)
    for id in pairs(vehicles) do if not s.players[id] or not s.players[id].vehicleRequested then cleanupVehicle(id) end end
    for _,n in ipairs(GetPlayers()) do
        local src=tonumber(n); local id=identity(src); local p=s.players[id]; local prev=old.players[id]
        if p then
            if p.vehicleRequested and not vehicles[id] then
                local v=CreateVehicleServerSetter(joaat('police'),'automobile',436.5,-1007.4,27.3,180.0)
                if v and v~=0 then vehicles[id]=v end
            elseif not p.vehicleRequested then cleanupVehicle(id) end
            if prev and (p.respawnSerial or 0)>(prev.respawnSerial or 0) then
                respawning[id]=GetGameTimer()+10000; TriggerClientEvent('nst:respawn',src)
            end
            if prev and (p.adminReviveSerial or 0)>(prev.adminReviveSerial or 0) then
                respawning[id]=GetGameTimer()+10000; TriggerClientEvent('nst:adminRevive',src)
            end
            if (p.jailUntil or 0)>os.time() then
                local ped=GetPlayerPed(src); local pos=position(src)
                local jail={x=459.2,y=-994.4,z=24.9}
                if ped~=0 and not NST.near(pos,jail,9) then SetEntityCoords(ped,jail.x,jail.y,jail.z,false,false,false,false) end
            elseif prev and (prev.jailUntil or 0)>0 and p.jailUntil==0 then TriggerClientEvent('nst:release',src) end
        end
    end
end
local function commit(nextState,action,actor)
    local old=envelope.state
    NST.refreshGrids(old,nextState)
    local r=request('/commit','POST',{revision=envelope.revision,state=nextState,audit={action=action,actor=actor or 'system'}})
    if r.code~=200 then
        recoveryState=old
        envelope=nil -- Unknown outcome is reconciled before accepting more work.
        local fresh=request('/state'); if fresh.code==200 then
            envelope=fresh.data; effects(old,envelope.state); recoveryState=nil
            if old.season~=envelope.state.season then for _,n in ipairs(GetPlayers()) do DropPlayer(n,NSTText('newSeason')) end else broadcast() end
        end
        error(NSTText('storageChanged'),0)
    end
    envelope=r.data; effects(old,envelope.state); broadcast()
end
local function tick(s,c)
    for id,o in pairs(c.online) do
        local p=s.players[id]
        if p then
            if o.alive then respawning[id]=nil end
            if not o.alive and p.alive~=false and not adminHealing[id] and (respawning[id] or 0)<=GetGameTimer() then NST.onDeath(s,{id=id,now=c.now,pos=o.pos,online=c.online}) end
            if (p.jailUntil or 0)>0 and p.jailUntil<=c.now then p.jailUntil=0 end
        end
    end
    NST.gameTick(s,c); NST.policeTick(s,c)
    for key,a in pairs(s.alerts) do if (a.expiresAt or a.expires or 0)<=c.now then s.alerts[key]=nil end end
end
NST.handlers.useItem=function(s,c,a)
    local p=NST.player(s,c.id)
    NST.assert(p.alive and (p.jailUntil or 0)<=c.now and not p.surrendered,NSTText('cannotUse'))
    NST.assert(a.item=='medkit' and (p.items.medkit or 0)>0,NSTText('noMedkit'))
    NST.assert((p.healCooldown or 0)<=c.now,NSTText('medkitWait'))
    p.items.medkit=p.items.medkit-1; p.healCooldown=c.now+30
end
local function enqueue(job,src)
    if src and #queue>=96 then return false end
    queue[#queue+1]=function()
        local ok,err=pcall(job)
        if not ok then tell(src,tostring(err)) end
    end
    return true
end
RegisterNetEvent('nst:action',function(action,args)
    local src=source; local id=identity(src); if not id then return end
    local now=GetGameTimer(); local r=rates[src] or {at=now,n=0}; rates[src]=r
    if now-r.at>1000 then r.at=now;r.n=0 end
    r.n=r.n+1; if r.n>5 then return end
    if type(action)~='string' or #action>40 or type(args)~='table' then return end
    local clean={}; local count=0
    for k,v in pairs(args) do
        count=count+1; if count>8 or type(k)~='string' or #k>32 or (type(v)~='string' and type(v)~='number') then return end
        if type(v)=='string' and #v>128 then return end
        if type(v)=='number' and (v~=v or math.abs(v)>1000000) then return end
        clean[k]=v
    end
    if clean.target then clean.target=identity(tonumber(clean.target) or -1); if not clean.target then return end end
    if not sessions[src] then sessions[src]={id=id,nonce={}} end
    local nonce=sessions[src].nonce
    if not enqueue(function()
        if identity(src)~=id or not sessions[src] or sessions[src].nonce~=nonce then return end
        NST.assert(envelope,NSTText('databaseNotReady'))
        local c=context(id,src); NST.assert(c.pos,NSTText('characterLoading'))
        sessions[src].pos=c.pos
        local s=NST.copy(envelope.state); local isNew=not s.players[id]; local p=NST.player(s,id)
        if isNew then p.protectedUntil=c.now+20 end
        tick(s,c)
        if action=='sync' then
            if p.role=='police' and p.alive and (p.jailUntil or 0)<=c.now then p.kit=true end
        else
            NST.assert(NST.handlers[action],NSTText('unknownAction'))
            s=NST.apply(s,c,action,clean)
        end
        commit(s,action,id)
        if identity(src)==id and sessions[src] and sessions[src].nonce==nonce then
            if action=='useItem' then TriggerClientEvent('nst:heal',src) end
            if action=='weaponFire' then
                local shooter=s.players[id];local def=NST.itemCatalog[shooter.equippedWeapon]
                authorizedShots[id]={weapon=joaat(def.weapon),expires=GetGameTimer()+1500,serial=shooter.shotSerial,nonce=nonce}
                TriggerClientEvent('nst:shot',src,{weapon=def.weapon,serial=shooter.shotSerial})
            elseif action=='weaponEquip' or action=='inventoryDrop' or action=='hideoutStore' then authorizedShots[id]=nil end
            if action~='sync' and action~='weaponFire' and action~='inventoryMove' then tell(src,NSTText('actionComplete')) end
        end
    end,src) then tell(src,NSTText('serverBusy')) end
end)
-- txAdmin server-local event only: never expose this as a network event.
AddEventHandler('txAdmin:events:playerHealed',function(data)
    if GetInvokingResource()~='monitor' or type(data)~='table' then return end
    for _,n in ipairs(GetPlayers()) do
        local src=tonumber(n); local id=identity(src)
        if id and (data.target==-1 or tonumber(data.target)==src) then
            local session=sessions[src]; local nonce=session and session.nonce
            adminHealing[id]=true
            enqueue(function()
                local ok,err=pcall(function()
                    if not envelope or identity(src)~=id or (nonce and (not sessions[src] or sessions[src].nonce~=nonce)) then return end
                    local s=NST.copy(envelope.state); local c=context(id,src)
                    if s.players[id] then
                        NST.onAdminRevive(s,c)
                        s.players[id].adminReviveSerial=(s.players[id].adminReviveSerial or 0)+1
                        commit(s,'admin_revive','txAdmin')
                    end
                end)
                adminHealing[id]=nil
                if not ok then error(err,0) end
            end)
        end
    end
end)
AddEventHandler('txAdmin:events:playerKicked',function(data)
    if GetInvokingResource()~='monitor' or type(data)~='table' then return end
    for _,n in ipairs(GetPlayers()) do local src=tonumber(n); if data.target==-1 or tonumber(data.target)==src then administrativeDrops[src]=identity(src) end end
end)
AddEventHandler('txAdmin:events:serverShuttingDown',function()
    if GetInvokingResource()~='monitor' then return end
    for _,n in ipairs(GetPlayers()) do local src=tonumber(n);administrativeDrops[src]=identity(src) end
end)
AddEventHandler('playerDropped',function()
    local droppedAt=os.time()
    local src=source; local session=sessions[src]; local id=session and session.id or identity(src)
    local administrative=administrativeDrops[src]==id; administrativeDrops[src]=nil
    local ped=GetPlayerPed(src); local physicallyDead=ped and ped~=0 and GetEntityHealth(ped)<=0
    sessions[src]=nil; rates[src]=nil; damageRates[src]=nil
    if not id then return end
    local pos=position(src) or (session and session.pos) or NSTConfig.spawn
    authorizedShots[id]=nil
    cleanupVehicle(id)
    enqueue(function()
        if not envelope then return end
        local s=NST.copy(envelope.state); NST.onDisconnect(s,{id=id,pos=pos,now=droppedAt,online={},administrative=administrative,physicallyDead=physicallyDead})
        commit(s,'disconnect',id)
    end)
end)
AddEventHandler('weaponDamageEvent',function(sender,data)
    local id=identity(sender); if not id or not envelope then CancelEvent(); return end
    local targetId=data.hitGlobalId
    if type(targetId)~='number' or targetId<=0 then CancelEvent();return end
    if data.hitGlobalIds and (#data.hitGlobalIds>1 or (#data.hitGlobalIds==1 and data.hitGlobalIds[1]~=targetId)) then CancelEvent();return end
    local victimEntity=NetworkGetEntityFromNetworkId(targetId)
    if victimEntity==0 or not DoesEntityExist(victimEntity) then CancelEvent();return end
    local targetOwner=NetworkGetEntityOwner(victimEntity)
    local victim=targetOwner and victimEntity==GetPlayerPed(targetOwner) and identity(targetOwner) or nil
    local attackerPos,attackerAlive=position(sender)
    if not attackerAlive then CancelEvent(); return end
    local shooter=envelope.state.players[id]
    local firearm=shooter and shooter.equippedWeapon and NST.itemCatalog[shooter.equippedWeapon]
    local isFirearm=firearm and firearm.weapon and data.weaponType==joaat(firearm.weapon)
    if isFirearm then
        local ticket=authorizedShots[id]
        if not ticket or ticket.weapon~=data.weaponType or ticket.expires<GetGameTimer() or not sessions[sender] or ticket.nonce~=sessions[sender].nonce or (shooter.items[shooter.equippedWeapon] or 0)<1 then CancelEvent();return end
        if data.hitGlobalIds and #data.hitGlobalIds>1 then CancelEvent();return end
        if data.overrideDefaultDamage or data.hitWeaponAmmoAttachment or data.hitEntityWeapon then CancelEvent();return end
    end
    local targetCoords=GetEntityCoords(victimEntity)
    if not NST.near(attackerPos,{x=targetCoords.x,y=targetCoords.y,z=targetCoords.z},isFirearm and firearm.range or 5) or GetPlayerRoutingBucket(sender)~=GetEntityRoutingBucket(victimEntity) then CancelEvent();return end
    if victim then
        local victimSrc=NetworkGetEntityOwner(victimEntity); local victimPos,victimAlive=position(victimSrc)
        if victimEntity~=GetPlayerPed(victimSrc) or not victimAlive or not NST.near(attackerPos,victimPos,isFirearm and firearm.range or 5) or GetPlayerRoutingBucket(sender)~=GetPlayerRoutingBucket(victimSrc) then CancelEvent(); return end
    end
    local p=envelope.state.players[id]; local v=victim and envelope.state.players[victim]
    if not p or not p.alive or (p.protectedUntil or 0)>os.time() or (p.jailUntil or 0)>os.time() or p.surrendered or (v and (v.protectedUntil or 0)>os.time()) then CancelEvent(); return end
    local weapon=data.weaponType
    if not isFirearm and weapon~=joaat('WEAPON_UNARMED') and not (weapon==joaat('WEAPON_BAT') and (p.items.bat or 0)>0) and not (weapon==joaat('WEAPON_NIGHTSTICK') and p.role=='police' and p.kit) then CancelEvent(); return end
    if isFirearm then authorizedShots[id]=nil end
    if (damageRates[sender] or 0)>GetGameTimer() then return end
    damageRates[sender]=GetGameTimer()+1000
    enqueue(function()
        if not envelope then return end
        local s=NST.copy(envelope.state)
        for _,key in pairs({id,victim}) do if s.players[key] then s.players[key].combatUntil=os.time()+30 end end
        commit(s,'combat',id)
    end)
end)
RegisterCommand('nst_status',function(src)
    if src~=0 and not IsPlayerAceAllowed(src,'nst.admin') then return end
    tell(src,envelope and NSTText('status',envelope.state.season,envelope.revision,#queue) or NSTText('databaseNotReady'))
end,false)
RegisterCommand('nst_wipe',function(src,args)
    if src~=0 and not IsPlayerAceAllowed(src,'nst.admin') then return end
    local dry=args[1]~='execute'; local key=args[2]
    if not key then tell(src,NSTText('wipeHelp')); return end
    enqueue(function()
        local old=envelope and envelope.state
        TriggerClientEvent('nst:notice',-1,dry and NSTText('wipeSimulating') or NSTText('wipeMaintenance'))
        local r=request('/wipe','POST',{key=key,dryRun=dry})
        if r.code~=200 then recoveryState=old; envelope=nil; error((r.data and r.data.error) or NSTText('wipeFailed'),0) end
        envelope=r.data
        if old then effects(old,envelope.state) end
        if not dry and not r.data.alreadyDone then for _,n in ipairs(GetPlayers()) do DropPlayer(n,NSTText('newSeason')) end end
        tell(src,dry and NSTText('wipeSimulated') or NSTText('wipeComplete'))
    end,src)
end,false)
CreateThread(function()
    local lastTick=0; local warned={}
    while true do
        if not envelope then
            local r=request('/state'); if r.code==200 then
                envelope=r.data
                if recoveryState then
                    effects(recoveryState,envelope.state)
                    if recoveryState.season~=envelope.state.season then for _,n in ipairs(GetPlayers()) do DropPlayer(n,NSTText('newSeason')) end end
                    recoveryState=nil
                end
            end
            if not envelope then Wait(3000) end
        end
        if envelope then
            local job=table.remove(queue,1)
            if job then
                busy=true; local ok,err=pcall(job); busy=false
                if not ok then print('[NST] Rejected: '..tostring(err)) end
            end
            if envelope and GetGameTimer()-lastTick>=1000 then
                lastTick=GetGameTimer()
                local ok,err=pcall(function()
                    local c=context('system',0); local s=NST.copy(envelope.state); tick(s,c)
                    -- GET also processes due wipes even on an empty server.
                    local fresh=request('/state')
                    if fresh.code~=200 then recoveryState=envelope.state; envelope=nil; return end
                    local remaining=(fresh.data.nextWipe or 0)-os.time()
                    for _,seconds in ipairs({900,300,60}) do
                        local key=tostring(fresh.data.nextWipe)..':'..seconds
                        if remaining>0 and remaining<=seconds and not warned[key] then warned[key]=true; TriggerClientEvent('nst:notice',-1,NSTText('wipeWarning',math.ceil(remaining/60))) end
                    end
                    if fresh.data.revision~=envelope.revision then
                        local changedSeason=fresh.data.state.season~=envelope.state.season
                        envelope=fresh.data
                        if changedSeason then for _,n in ipairs(GetPlayers()) do DropPlayer(n,NSTText('newSeason')) end end
                    elseif json.encode(s)~=json.encode(envelope.state) then commit(s,'tick','system')
                    else effects(envelope.state,envelope.state); broadcast() end
                end)
                if not ok then print('[NST] Tick: '..tostring(err)) end
            end
        end
        Wait(20)
    end
end)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then for id in pairs(vehicles) do cleanupVehicle(id) end end end)
