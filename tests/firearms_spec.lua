dofile('resource/server/core.lua')
dofile('resource/server/gameplay.lua')
local s={players={},gangs={},territories={},robberies={},hideouts={},drops={},alerts={},season=1}
local c={id='a',now=1000,pos=NSTConfig.shop,online={},policeCount=0};local p=NST.player(s,'a');p.cash=5000;p.bag='bag_medium'
local function act(action,args) s=NST.apply(s,c,action,args) end
local function fail(action,args) assert(not pcall(NST.apply,s,c,action,args),action..' must fail') end
act('shopBuy',{item='pistol',amount=1});act('shopBuy',{item='ammo_9mm',amount=3})
assert(s.players.a.cash==3788 and s.players.a.items.ammo_9mm==3)
fail('weaponFire');act('weaponEquip',{item='pistol'});act('weaponFire')
assert(s.players.a.items.ammo_9mm==2 and s.players.a.shotSerial==1)
fail('weaponFire');assert(s.players.a.items.ammo_9mm==2)
c.now=1001;s.players.a.surrendered=true;fail('weaponFire');s.players.a.surrendered=false
s.players.a.protectedUntil=1002;fail('weaponFire');s.players.a.protectedUntil=0
act('weaponFire');c.now=1002;act('weaponFire');assert(s.players.a.items.ammo_9mm==0)
c.now=1003;fail('weaponFire');act('inventoryDrop',{item='pistol',amount=1});assert(not s.players.a.equippedWeapon)
assert(s.drops[tostring(s.nextDrop)].items.pistol==1)
print('firearms_spec: physical purchase, equip, ammo debit, rate limit, protection, surrender, empty ammo and weapon drop passed')
