# Police, combat, and raids

All transitions run on copies of server state and are published only after database confirmation. Clients cannot invoke death or disconnection as network events; the adapter calls `NST.onDeath` after a server-observed death and `NST.onDisconnect` on `playerDropped`.

## Event contract

| Action | Arguments | Rule |
|---|---|---|
| police_duty | none | At the station, alive, free, no gang or stolen goods; 10-minute role lock |
| police_vehicle | none | Police at the station; at most one requested vehicle |
| police_return_vehicle | none | Police at the station; the adapter removes the vehicle |
| surrender | none | Toggles surrender |
| police_arrest | target: server-resolved account ID | Police, within 3 m, target wanted, surrendered, alive, and without spawn protection |
| respawn | none | After server-recorded death and a 15-second wait |
| loot | drop: string ID | Within 3 m, 20-second owner priority, all or nothing; police destroy seized loot |
| raid_start | hideout: configured ID | Rival gang or police, defenders online or 15-minute offline protection expired, within 15 m, 30-minute target cooldown |
| raid_finish | hideout | Same attacker, 60 seconds of active presence after a 60-second warning, completed within 180 seconds |

Arrest seizes stolen goods without a police reward and imposes 90 seconds in custody. The release deadline persists through death, logout, and restart. The server adapter must return a reconnecting prisoner to the cell. Sentences run in real time, including offline time.

Death drops the entire inventory and 20% of cash in a loot drop lasting 10 minutes. Police equipment is stored separately as `kit`, never becomes an inventory item, and cannot be sold or looted. Respawning preserves the remaining money and grants 20 seconds of protection. Repeated death events do not create additional items. Logging out during marked combat, a robbery, a raid, or surrender counts as death. The adapter is responsible for server-observed combat marking and physical equipment/vehicles.

Run `NST.policeTick` at least every five seconds. It counts only active presence and cancels a raid on death, disconnection, or moving more than 15 m away. The latest presence of any defender is saved in the database. An empty hideout is protected for 15 minutes after that time; offline raids are then allowed. The purchase time is used until a defender has been observed. Older records without a timestamp receive 15 minutes from their first tick. A restart does not reset already saved protection. Defenders disconnecting after a raid starts cannot cancel it. Maximum loss is 25/20/15% of the gang bank and stolen goods at hideout levels 1/2/3; other items, ownership, and upgrades are preserved. Police seizures destroy the assets. The same raid cannot pay out twice.

Police settings can be configured in `NSTConfig.police`: station, roleCooldown, sentence, respawnDelay, spawnProtection, and offlineProtection (seconds; default 900). The first version requires voluntary surrender for arrest; ad hoc client reports of handcuffs or tasers are not treated as authoritative.
