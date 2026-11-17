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
print('client_spec: existing NUI focus respected; own menu toggles normally')
