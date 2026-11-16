local L = NSTGameplayText
NSTConfig = {
    startingCash = 500, gangLimit = 6, gangCost = 250, inventoryLimit = 80,
    gangChangeCooldown = 600, gangInviteSeconds = 300,
    fence = {x=1005.7,y=-1527.7,z=30.8}, fencePrice = 75,
    shop = {x=22.0,y=-1107.2,z=29.8},
    prices = { lockpick=90, medkit=120, bat=250 },
    robberies = {
        shop = {label=L.storeRobbery,pos={x=24.5,y=-1345.5,z=29.5},radius=12,duration=45,timeout=120,cooldown=600,reward=6,police=0},
        depot = {label=L.depotRobbery,pos={x=907.7,y=-1517.1,z=30.5},radius=18,duration=100,timeout=210,cooldown=1200,reward=16,police=1,tool='lockpick'}
    },
    hideouts = {
        davis={label=L.davisHideout,pos={x=118.1,y=-1948.6,z=20.7},cost=900},
        rancho={label=L.ranchoHideout,pos={x=485.6,y=-1529.1,z=29.3},cost=900}
    },
    territories = {
        davis={label=L.davis,pos={x=100.0,y=-1820.0,z=26.0},radius=65},
        rancho={label=L.rancho,pos={x=443.0,y=-1706.0,z=29.0},radius=65},
        strawberry={label=L.strawberry,pos={x=234.0,y=-1500.0,z=29.0},radius=65}
    },
    captureSeconds=180, captureCooldown=1800, captureMinPlayers=2, capturePoints=25,
    upkeepSeconds=3600, upkeepCost=40, territoryBonus=0.05,
    spawn={x=211.2,y=-1395.1,z=30.6}, policeStation={x=441.0,y=-981.9,z=30.7}
}
