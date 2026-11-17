# NO SAFE TURF: first-version gameplay rules

All prices and map positions are in `resource/shared/config.lua`. Money, storage, and missions are controlled by the server. Quantities must be positive integers. Changes are saved before results are displayed. Melee weapons and physical pistol/rifle ammunition are supported; see GRID_INVENTORY.md for the initial server-paced firearm behavior.

For the current mixed loot rewards, sizes, rarities and values, see GRID_INVENTORY.md. The original generic-goods values below describe legacy items and custom robbery overrides.

## From robbery to secured loot

The store in Strawberry requires no police, takes 45 seconds of uninterrupted presence, and creates six stolen goods and $150 in world loot. The depot in La Mesa requires at least one police officer, a lockpick, and 100 seconds, and creates 16 stolen goods and $500 in world loot. Leaving the area, dying, or disconnecting cancels the robbery. Each reward container is created once. Collect its contents nearby through Inventory before transporting them; equipped bags and all carried cash affect capacity. See INVENTORY.md. The store cooldown is 10 minutes and the depot cooldown is 20 minutes, including after failure. Wanted status lasts at least 10 minutes. A time gap after a restart does not count as active presence.

Transport stolen goods to the fence at 1005, -1528 for $75 per unit, or store them in the gang hideout. Each unit sold earns one season point. The equipment shop sells lockpicks for $90, medkits for $120, and bats for $250. Players start with $500; there are no recurring free payouts. All amounts are in-game currency.

## Gangs and hideouts

A gang costs $250, holds six members, and has leader, officer, and member roles. Leaders/officers can invite players; invitations expire after five minutes. Only the leader can change roles. Members can deposit money/items. Withdrawals require officer or leader status. All storage and bank operations require presence at the gang's own hideout and are locked during a raid.

Hideouts in Davis and Rancho cost $900 from the buyer's personal balance, with one hideout per gang. Upgrades cost $600 and $1,200 from the shared bank. Upkeep costs $40 per level per active server hour; unpaid upkeep reduces the level, never below one. Restarts do not create retroactive debt. Raid losses decrease from 25 to 20 and 15 percent with each level. Freeform base building is not included.

Joining, creating or leaving a gang applies a 10-minute membership-change cooldown. Members/officers can leave only outside combat, wanted status, robbery, raid and territory capture. The leader can leave only if the gang has no other members and no hideout or territory. Leadership transfers and hideout sales are future work; leaders with hideouts therefore remain criminals during the season.

## Territories

Davis, Rancho, and Strawberry require three minutes of active presence. At least one eligible rival must be online; an owned zone requires an online member of the defending gang. A rival present in the zone resets capture progress. Death, disconnection, or leaving the zone cancels the capture. The first capture of each zone by a given gang that season awards 25 points; recapturing it grants no repeat points. A completed capture locks it for 30 minutes. Each owned zone raises the fence price by five percent, up to 15 percent. There are no passive payouts, so zones generate no overnight passive income. Collusion between accounts cannot be fully prevented without moderation.

## Integration contract

Run `NST.gameTick(state, context)` every second and before actions. Context comes from the server: `id`, UTC seconds `now`, `pos`, `online[id]={pos,alive}`, and `policeCount`. Client-provided coordinates are not accepted. Robberies and captures count at most two seconds per tick. `NST.apply` copies state before a transition; only a successful transaction may be published. The adapter must resolve `args.target` from an online server ID to an account ID. `gangAccept.gang` is the inviting gang's ID.

Season objects: `gangs[id]={name,members,bank,items,score,invites}`, `hideouts[id]={gang,level,raidCooldown,upkeepAt}`, and `territories[id]={owner,capture,cooldown}`. The police module's raid state is stored in `hideouts[id].raid`. The stolen-goods item key is `stolen`. Alerts use keyed objects with `kind`, `pos`, `expiresAt`, and `text`.
