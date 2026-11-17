# Physical inventory and bags — v0.6.0

Open Inventory through F6 or /nst, or press E beside accessible world loot. The left panel shows carried items and cash; the right shows nearby containers. Enter a quantity and Collect or Drop on ground. Transfers are explicit buttons, not drag-and-drop. Items must be carried to the fence or hideout before selling or storing them.

## Capacity

| Equipment | Total capacity | Purchase price |
|---|---:|---:|
| Pockets | 8 kg | Included |
| Small bag | 18 kg | $150 |
| Backpack | 35 kg | $450 |
| Large duffel | 60 kg | $900 |

Buy bags at Equipment, then Equip them in Inventory. Only one bag can be equipped. Removing or replacing a bag returns it to the carried inventory and is refused if the resulting load would exceed capacity. Capacity is total carrying space, not additional space. Bag changes are blocked during combat, robberies and raids. All cash occupies space at 0.1 grams per dollar ($10,000 = 1 kg). Each stolen-goods unit weighs 1 kg, lockpicks 150 g, medkits 750 g and bats 1.2 kg. Unequipped bags also weigh something. These are gameplay weights, not claims about real-world mass.

Server defaults are in NST.inventoryDefaults in server/core.lua. For overrides, add a complete NSTConfig.inventory table in shared/config.lua using the same structure (weights/capacity in grams). That private gameplay configuration remains excluded from automatic code updates. inventoryLimit is superseded by weight capacity.

## Physical loot

Completing a store robbery creates six stolen goods and $150 at the robbery location. The depot creates 16 goods and $500. No payout is placed directly into the robber's inventory. cashReward on each robbery definition can override the cash reward, including zero. Loot is accessible to other players as well; robbery loot has no owner-priority delay. Police on duty confiscate containers instead of keeping their contents.

Transfers require a living, free, unprotected player within three meters and obey existing death-drop priority. Partial collection is supported. Full capacity or a stale request rejects the whole transfer. Existing serialized transactions and revision checks prevent duplicate claims. The live event adapter uses the same capacity validation as the pure transitions, including purchases, withdrawals, fence sales and raid rewards.

Ground and robbery loot expires after 15 minutes; death loot keeps its existing 10-minute lifetime and 20-second owner priority. Dropping additional items into your nearby voluntary container refreshes its expiry. Voluntary drops are limited when 200 world containers exist. Do not use world loot as permanent storage.

On death, the equipped bag and all inventory items are dropped. The existing rule retaining 80% of cash is unchanged; 20% falls into the death container. If retained cash or an existing save exceeds the new capacity, nothing is deleted. Such a player can reduce their load but cannot increase it beyond capacity. Gang bank funds are stored money and do not consume personal capacity until withdrawn.

Bag appearance uses the current freemode model's bag component; world loot uses a local bag prop plus a marker. These visual entities do not authorize transfers: the server's saved records do. Model/component appearance still needs Enhanced in-game verification.

## Upgrade and validation

No SQL migration or wipe is required. Existing entity JSON persists equipped bags, item stacks and loot. v0.5.0 installations have the same managed file set and can receive this release through nst_updater on a full restart. v0.4.0 installations must first install the new loading-screen files and matching baseline, or install the complete v0.6.0 package while preserving shared/config.lua and private settings. Do not mix baseline files between releases.

Local checks cover physical robbery payouts, partial claims, cash weight, bag ownership/equip/death, capacity rejection, nearby distance, expiry, legacy overweight saves, live adapter validation and keyed NUI quantities. Chrome preview confirms panel layout. Actual multi-client Enhanced transfers, visible bags/props and persistence after a real server restart still require a test session.
