-- FXServer adapter smoke tests with native/storage-export stubs. Not an in-game test.
dofile('resource/server/core.lua'); dofile('resource/shared/config.lua'); dofile('resource/server/gameplay.lua'); dofile('resource/server/police.lua')
local handlers,commands,threads,events={},{},{},{}
local now,timer=1000,1000
local players={[1]={id='license:a',pos=NSTConfig.spawn,health=200},[2]={id='license:b',pos=NSTConfig.spawn,health=200}}
local db={revision=0,state={players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1},nextWipe=20000}
local wire,serial={},0
json={encode=function(value) serial=serial+1;local key='wire'..serial;wire[key]=NST.copy(value);return key end,decode=function(key) assert(wire[key]);return NST.copy(wire[key]) end}
promise={new=function() local p={};function p:resolve(v) self.value=v end;return p end}
Citizen={Await=function(p) return p.value end}
local fault=false; local commits=0; local commitLost=false; local stateFault=0;local stateLostWipe=false
local function storageRequest(_,url,method,body,callback)
    if method=='GET' and stateFault>0 then stateFault=stateFault-1;callback(503,'');return end
    if method=='GET' and stateLostWipe then stateLostWipe=false;db.state={season=2,players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={}};db.revision=db.revision+1;callback(503,'');return end
    if method=='POST' and url=='/commit' then
        if fault then fault=false; callback(503,'');return end
        local input=json.decode(body); assert(input.revision==db.revision,'CAS mismatch')
        db.state=input.state; db.revision=db.revision+1; commits=commits+1
        if commitLost then commitLost=false;stateFault=1;callback(503,'');return end
    end
    callback(200,json.encode(db))
end
exports=setmetatable({},{__index=function() return {storageRequest=storageRequest} end})
function GetConvar(name,default) if name=='nst_token' then return string.rep('x',32) end;return default end
function GetPlayerIdentifiers(src) return players[tonumber(src)] and {players[tonumber(src)].id} or {} end
function GetPlayerPed(src) return players[tonumber(src)] and tonumber(src) or 0 end
function GetEntityCoords(ped) return players[ped].pos end
function GetEntityHealth(ped) return players[ped].health end
function GetPlayers() local out={};for id in pairs(players) do out[#out+1]=tostring(id) end;return out end
function GetPlayerName(src) return 'player '..src end
function GetGameTimer() return timer end
function RegisterNetEvent(name,fn) handlers[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
function RegisterCommand(name,fn) commands[name]=fn end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(_) coroutine.yield() end
function TriggerClientEvent(name,src,data) events[#events+1]={name=name,src=src,data=NST.copy(data),revision=db.revision} end
function DoesEntityExist(_) return false end
function DeleteEntity(_) end
function joaat(_) return 1 end
function CreateVehicleServerSetter(...) return 99 end
function SetEntityCoords(ped,x,y,z) players[ped].pos={x=x,y=y,z=z} end
function IsPlayerAceAllowed(...) return false end
local droppedMessages={}
function DropPlayer(src,message) droppedMessages[#droppedMessages+1]=message;players[tonumber(src)]=nil end
function GetCurrentResourceName() return 'nst' end
local invoking='untrusted'
function GetInvokingResource() return invoking end
os.time=function() return now end
local function step() timer=timer+20;local ok,err=coroutine.resume(threads[1]);assert(ok,err) end
local function action(src,name,args) source=src;handlers['nst:action'](name,args or {});step() end
local function eventCount(name,src) local n=0;for _,e in ipairs(events) do if e.name==name and (not src or src==e.src) then n=n+1 end end;return n end
dofile('resource/server/main.lua'); assert(#threads==1);step()
action(1,'sync'); assert(db.state.players['license:a'].cash==500 and commits>0)
-- Rejected authorization never reaches persistence.
local revision=db.revision;players[1].pos=NSTConfig.policeStation
action(1,'police_vehicle');assert(db.revision==revision and not db.state.players['license:a'].vehicleRequested)
-- Failed commit publishes no proposed economy and emits no healing effect.
db.state.players['license:a'].items.medkit=1
-- Refresh adapter envelope from this test fixture by forcing reconciliation first.
fault=true;action(1,'sync')
local healed=eventCount('nst:heal',1);fault=true;action(1,'useItem',{item='medkit'})
assert(db.state.players['license:a'].items.medkit==1 and eventCount('nst:heal',1)==healed)
action(1,'useItem',{item='medkit'});assert(db.state.players['license:a'].items.medkit==0 and eventCount('nst:heal',1)==healed+1)
-- Death is derived from server ped health, not an accepted client action.
now=1002; timer=2000; players[1].health=0;step();assert(db.state.players['license:a'].alive==false)
local drops=db.state.nextDrop;now=1004;timer=4000;step();assert(db.state.nextDrop==drops)
-- Respawn effect is persisted first and tolerates the old dead ped during async spawn.
now=1020;timer=20000;action(1,'respawn');assert(db.state.players['license:a'].alive and eventCount('nst:respawn',1)==1)
now=1021;timer=21000;step();assert(db.state.players['license:a'].alive and db.state.nextDrop==drops)
players[1].health=200;now=1022;timer=22000;step();assert(db.state.players['license:a'].alive)
-- Queued stale session action cannot apply to a recycled source id.
now=1023;timer=23000;players[1].health=200
source=2;handlers['nst:action']('sync',{})
source=2;handlers.playerDropped();players[2]={id='license:replacement',pos=NSTConfig.spawn,health=200}
step();assert(not db.state.players['license:b'] and not db.state.players['license:replacement'])
step()
-- Persisted respawn survives a lost commit response and a second failed read.
now=1100;timer=100000;players[1].health=0;step();assert(not db.state.players['license:a'].alive)
local priorRespawns=eventCount('nst:respawn',1);local priorDrops=db.state.nextDrop
now=1120;timer=120000;commitLost=true;action(1,'respawn')
assert(eventCount('nst:respawn',1)==priorRespawns)
step();assert(db.state.players['license:a'].alive and db.state.nextDrop==priorDrops)
assert(eventCount('nst:respawn',1)==priorRespawns+1)
players[1].health=200
-- Only txAdmin's local monitor event can reconcile death state; no loot refund.
now=1200;timer=200000;players[1].health=0;step()
local cash=db.state.players['license:a'].cash;local countDrops=db.state.nextDrop
handlers['txAdmin:events:playerHealed']({target=1,author='test'});step();assert(not db.state.players['license:a'].alive)
invoking='monitor';handlers['txAdmin:events:playerHealed']({target=1,author='test'});step()
assert(db.state.players['license:a'].alive and db.state.players['license:a'].cash==cash and db.state.nextDrop==countDrops)
assert(eventCount('nst:adminRevive',1)==1)
-- A scheduled wipe committed behind a failed read is reconciled on later reload.
players[1].health=200;now=1300;timer=300000;stateLostWipe=true;step();local beforeKicks=#droppedMessages
step();assert(#droppedMessages>beforeKicks and droppedMessages[#droppedMessages]==NSTText('newSeason'))
print('adapter_spec: passed (boot, identity/session, authorization, failed commit, post-commit heal, server death)')
