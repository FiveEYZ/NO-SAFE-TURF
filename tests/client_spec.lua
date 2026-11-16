local commands,callbacks,threads={}, {}, {}
local focused=true;local focusChanges=0;local sends=0
function RegisterCommand(name,fn) commands[name]=fn end
function RegisterNUICallback(name,fn) callbacks[name]=fn end
function RegisterNetEvent() end
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
print('client_spec: existing NUI focus respected; own menu toggles normally')
