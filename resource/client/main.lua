local state,opened,spawned,lastKit,lastBat=nil,false,false,nil,nil
local function send(action,args) TriggerServerEvent('nst:action',action,args or {}) end
local function spawn()
    local p=NSTConfig.spawn
    exports.spawnmanager:spawnPlayer({x=p.x,y=p.y,z=p.z,heading=90,model='mp_m_freemode_01',skipFade=false},function()
        spawned=true; lastKit=nil; lastBat=nil; send('sync')
    end)
end
CreateThread(function()
    exports.spawnmanager:setAutoSpawn(false)
    while not NetworkIsSessionStarted() do Wait(200) end
    spawn()
    local function blip(pos,label,sprite,color)
        local b=AddBlipForCoord(pos.x,pos.y,pos.z); SetBlipSprite(b,sprite); SetBlipColour(b,color); SetBlipScale(b,0.75); SetBlipAsShortRange(b,true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString(label); EndTextCommandSetBlipName(b)
    end
    for _,d in pairs(NSTConfig.robberies) do blip(d.pos,d.label,156,1) end
    for _,d in pairs(NSTConfig.hideouts) do blip(d.pos,d.label,40,5) end
    for _,d in pairs(NSTConfig.territories) do blip(d.pos,d.label,437,47) end
    blip(NSTConfig.fence,'Fence',500,2); blip(NSTConfig.shop,'Equipment',110,2); blip(NSTConfig.policeStation,'Police duty',60,3)
end)
RegisterCommand('nst',function()
    opened=not opened; SetNuiFocus(opened,opened); SendNUIMessage({type='open',value=opened}); if opened then send('sync') end
end,false)
RegisterKeyMapping('nst','NO SAFE TURF: open menu','keyboard','F6')
RegisterNUICallback('close',function(_,cb) opened=false; SetNuiFocus(false,false); SendNUIMessage({type='open',value=false}); cb({ok=true}) end)
RegisterNUICallback('action',function(data,cb)
    if type(data)=='table' then send(data.action,data.args) end; cb({ok=true})
end)
RegisterNUICallback('waypoint',function(data,cb)
    local collection=NSTConfig[data.group]; local point=type(collection)=='table' and collection[data.id]
    if point and point.pos then SetNewWaypoint(point.pos.x,point.pos.y)
    elseif data.group=='fence' or data.group=='shop' or data.group=='policeStation' then point=NSTConfig[data.group];SetNewWaypoint(point.x,point.y) end
    cb({ok=true})
end)
RegisterNetEvent('nst:notice',function(text) SendNUIMessage({type='notice',text=text}) end)
RegisterNetEvent('nst:state',function(value)
    state=value; state.receivedAt=GetGameTimer(); SendNUIMessage({type='state',value=value,config=NSTConfig})
    local p=value.player; local ped=PlayerPedId()
    if p.alive==false and not IsEntityDead(ped) then SetEntityHealth(ped,0) end
    local kit=p.kit==true and p.alive~=false; local bat=(p.items.bat or 0)>0 and p.alive~=false
    if lastKit~=kit or lastBat~=bat then
        RemoveAllPedWeapons(ped,true)
        if kit then GiveWeaponToPed(ped,joaat('WEAPON_NIGHTSTICK'),1,false,true) end
        if bat then GiveWeaponToPed(ped,joaat('WEAPON_BAT'),1,false,true) end
        lastKit=kit;lastBat=bat
    end
end)
RegisterNetEvent('nst:respawn',function() spawn() end)
RegisterNetEvent('nst:release',function() local p=NSTConfig.policeStation; SetEntityCoords(PlayerPedId(),p.x,p.y,p.z,false,false,false,false) end)
RegisterNetEvent('nst:heal',function() local p=PlayerPedId(); if not IsEntityDead(p) then SetEntityHealth(p,math.min(GetEntityMaxHealth(p),GetEntityHealth(p)+50)) end end)
CreateThread(function()
    while true do Wait(5000); if spawned and not state then send('sync') end end
end)
CreateThread(function()
    while true do
        Wait(0)
        SetPlayerWantedLevel(PlayerId(),0,false); SetPlayerWantedLevelNow(PlayerId(),false)
        SetDispatchCopsForPlayer(PlayerId(),false)
        for i=1,15 do EnableDispatchService(i,false) end
        if state then
            local p=state.player; local now=state.now+math.floor((GetGameTimer()-(state.receivedAt or GetGameTimer()))/1000)
            local safe=(p.protectedUntil or 0)>now; local jailed=(p.jailUntil or 0)>now
            SetPlayerInvincible(PlayerId(),safe)
            if safe or jailed or p.surrendered then
                DisablePlayerFiring(PlayerId(),true); DisableControlAction(0,24,true); DisableControlAction(0,25,true); DisableControlAction(0,140,true)
            end
            if p.surrendered then
                DisableControlAction(0,21,true)
                if not IsEntityPlayingAnim(PlayerPedId(),'missminuteman_1ig_2','handsup_base',3) then
                    RequestAnimDict('missminuteman_1ig_2')
                    if HasAnimDictLoaded('missminuteman_1ig_2') then TaskPlayAnim(PlayerPedId(),'missminuteman_1ig_2','handsup_base',8,-8,-1,49,0,false,false,false) end
                end
            elseif IsEntityPlayingAnim(PlayerPedId(),'missminuteman_1ig_2','handsup_base',3) then ClearPedSecondaryTask(PlayerPedId()) end
            for _,d in pairs(state.drops or {}) do DrawMarker(1,d.pos.x,d.pos.y,d.pos.z-1,0,0,0,0,0,0,0.6,0.6,0.4,255,190,60,160,false,false,2,false,nil,nil,false) end
        end
    end
end)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then SetNuiFocus(false,false); SetPlayerInvincible(PlayerId(),false) end end)
