local commands,callbacks,threads,events={}, {}, {}, {}
local focused=true;local focusChanges=0;local sends=0
function RegisterCommand(name,fn) commands[name]=fn end
function RegisterNUICallback(name,fn) callbacks[name]=fn end
function RegisterNetEvent(name,fn) events[name]=fn end
function RegisterKeyMapping() end
function AddEventHandler() end
function CreateThread(fn) threads[#threads+1]=fn end
function IsNuiFocused() return focused end
function SetNuiFocus(value) focused=value;focusChanges=focusChanges+1 end
function SendNUIMessage() end
function TriggerServerEvent() sends=sends+1 end
dofile('resource/client/main.lua')
commands.nst();assert(focusChanges==0 and sends==0,'must not steal txAdmin NUI focus')
focused=false;commands.nst();assert(focusChanges==1 and sends==1 and focused)
commands.nst();assert(focusChanges==2 and not focused)
local appearance={};local spawnCallback
local frozen=false;local collisionChecks=0;local groundAvailable=true;local position
function FreezeEntityPosition(_,value) frozen=value end
function SetEntityCoordsNoOffset(_,x,y,z) assert(frozen);position={x=x,y=y,z=z} end
function RequestCollisionAtCoord() assert(frozen) end
function GetGroundZFor_3dCoord() return groundAvailable,20.0 end
function HasCollisionLoadedAroundEntity() collisionChecks=collisionChecks+1;return collisionChecks>=3 end
function Wait() assert(frozen,'must stay frozen while terrain is streaming') end
function NSTText(key) return key end
NSTConfig={spawn={x=1,y=2,z=3}}
exports={spawnmanager={spawnPlayer=function(_,options,callback)
    assert(options.model=='mp_m_freemode_01');spawnCallback=callback
end}}
function PlayerPedId() return 42 end
function SetPedDefaultComponentVariation(ped) assert(ped==42);appearance.clothes=true end
function ClearAllPedProps(ped) assert(ped==42);appearance.props=true end
function ResetEntityAlpha(ped) assert(ped==42);appearance.alpha=true end
function SetEntityVisible(ped,visible) assert(ped==42 and visible);appearance.visible=true end
local before=sends
events['nst:respawn']();assert(sends==before and not appearance.clothes)
spawnCallback();assert(appearance.clothes and appearance.props and appearance.alpha and appearance.visible)
assert(sends==before+1,'sync must follow completed spawn appearance')
assert(not frozen and position.z==21.0 and collisionChecks>=3,'release only above confirmed ground with loaded collision')
groundAvailable=false;before=sends
events['nst:respawn']();spawnCallback()
assert(frozen and sends==before,'missing ground must not release the player or announce spawn completion')
print('client_spec: existing NUI focus respected; own menu toggles normally')
-- Server grants trigger at most one native shot and only for the equipped firearm.
function GetGameTimer() return 1000 end
function GetNumberOfPedDrawableVariations() return 100 end
function SetPedComponentVariation() end
function IsEntityDead() return false end
function RemoveAllPedWeapons() end
function GiveWeaponToPed() end
function SetCurrentPedWeapon() end
function SetPedInfiniteAmmoClip() end
function joaat(v) return v end
function SetPedAmmo() end
function DisablePlayerFiring() end
function PlayerId() return 1 end
function SetAmmoInClip() end
function GetGameplayCamCoord() return {x=0,y=0,z=1} end
function GetGameplayCamRot() return {x=0,y=0,z=0} end
local fired=0
function SetPedShootsAtCoord(_,x,y,z) fired=fired+1;assert(y==150) end
focused=false
local snapshot={now=1000,player={alive=true,cash=500,items={pistol=1,ammo_9mm=3},equippedWeapon='pistol'},inventory={bags={},catalog={pistol={weapon='WEAPON_PISTOL'}}}}
events['nst:state'](snapshot)
events['nst:shot']({weapon='WEAPON_PISTOL',serial=1});assert(fired==1)
events['nst:shot']({weapon='WEAPON_PISTOL',serial=1});assert(fired==1)
snapshot.player.equippedWeapon=nil;events['nst:state'](snapshot)
events['nst:shot']({weapon='WEAPON_PISTOL',serial=2});assert(fired==1)
