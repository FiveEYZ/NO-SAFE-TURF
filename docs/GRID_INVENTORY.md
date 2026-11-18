# Grid inventory, rarity and physical firearms — v0.7.2

## Inventory controls

Open the standalone inventory with TAB or /nst_inventory, or press E beside accessible world loot. Close with TAB, Escape or the close button. F6 / /nst opens the separate gameplay menu; inventory is no longer a tab there. The inventory key can be rebound in FiveM key bindings under NO SAFE TURF: open inventory. If txAdmin also uses TAB, rebind one of them to avoid a collision. The default GTA weapon wheel is disabled while this resource runs. The compact inventory is docked to the right of the screen. Nearby loot appears on its left only when accessible loot exists; your bag and equipment stay visible. Panel height follows content instead of stretching across the screen. The icons are original local SVG artwork; no reference-game art is distributed.

Select an item to inspect its quantity, footprint, rarity and base sale value. Drag it within your bag (the cell you grab stays under the pointer), or select it and click a destination cell. Press R or Rotate before placing it to rotate 90 degrees. The preview shows valid or blocked placement. You can also drag a nearby loot stack into a free location in your bag; Collect automatically finds space. Failed transfers leave the source unchanged. You cannot rearrange somebody else's world container, but can choose where its contents go in your bag.

Use the quantity field to drop, collect, store or sell part of a stack. Fence sales still require standing at the fence; hideout storage still requires your own hideout and appropriate permissions. Equipment displays the active firearm; holstering does not delete it. Weapons continue to occupy bag space while equipped. Cash is split into physical stacks of up to $10,000 and ammunition into stacks of 30 rounds.

| Carrying equipment | Grid | Weight capacity |
|---|---|---|
| Pockets | 4×4 | 8 kg |
| Small bag | 6×6 | 18 kg |
| Backpack | 8×8 | 35 kg |
| Large duffel | 10×10 | 60 kg |

Both weight and geometry must fit. Automatic placement tries both orientations without moving existing items. Rearrange manually if fragmentation prevents a pickup. Bag downgrades must fit the resulting inventory, including the removed bag. Placement revisions reject stale drag requests after another inventory change. Layouts are saved in the existing player JSON; no SQL migration is needed.

Existing oversized inventories are retained in an overflow section. You can unload them; no items are silently erased. The UI limits how many legacy stacks it draws and provides unloading actions for the remaining totals. Until overflow is resolved, additions are refused. This is not a persistent world-storage system: normal ground loot expiry still applies.

## Loot sizes and rarities

| Goods | Size | Rarity | Base sale value |
|---|---|---|---:|
| Watch | 1×1 | Common | $75 |
| Phone | 2×1 | Common | $150 |
| Tool case | 4×1 | Common | $300 |
| Laptop | 2×2 | Rare | $450 |
| Television | 4×2 | Rare | $750 |
| Artwork | 3×3 | Epic | $1,125 |

Common has a muted green-gray border, Rare blue, Epic purple. Rarity is currently defined per item type, not a randomized roll on each individual item. The shop robbery produces two watches and two phones. The depot alternates between two assortments containing larger goods; the choice currently follows the world's drop counter, not random rarity odds. Existing generic stolen goods remain usable and saleable. Territory bonuses still apply. Custom robbery definitions may provide an explicit `loot` item-count table. New reward values need playtesting and economy balancing.

## Firearms

The equipment shop sells a pistol ($1,200), carbine rifle ($3,600), 9 mm rounds ($4 each) and rifle rounds ($8 each). Pistols occupy 2×2 cells, rifles 4×2, 9 mm stacks 1×1 and rifle ammunition stacks 2×1. Select Equip in the inventory, aim, then click fire. Both firearms initially use server-paced single shots, at most one authorized round per second; the carbine is not automatic in this release.

The server removes one matching round in a committed transaction before granting a shot. The client then performs a native shot toward its camera aim. There is no separate magazine or reload state yet: each shot draws from carried ammunition. Replayed grants are ignored by the client. A short-lived server ticket permits at most one remotely owned target hit; mismatched target IDs, invalid range/bucket, protected targets and unauthorized firearms are rejected. Pistol range is 65 m and rifle range 120 m for validated network damage.

Death drops physical weapons and remaining ammunition under the existing inventory rules. Arrest seizes stolen goods, firearms and ammunition. Police can use personally owned firearms and matching ammunition; standard duty kit still only grants a baton. Holstering, death, dropping and storing a firearm remove access to it when ownership no longer permits use.

A failed database commit grants no shot. If a commit succeeded but its acknowledgement was lost, the round may be spent without firing; it is not refunded automatically. Server latency adds delay between clicking and firing. These gates do not replace a full anti-cheat: aim, wall penetration and locally owned entities still depend on GTA/network behavior and require live testing.

## Validation and upgrade

Local tests cover geometry, rotation, stale revisions, drag-transfer rollback, weight and space limits, cash/ammo stack sizing, mixed loot, rarity values, firearm ownership, ammo exhaustion, rate limits, failed ammo commits, mismatched damage targets and replayed hit tickets. Client-native calls are stub-tested, not in-game acceptance. Chrome preview verifies the three-panel layout. Test actual aiming, firing, damage, bag appearance, E interaction, drag/rotation and reconnect persistence with two Enhanced clients before opening the server broadly.

The release retains the managed runtime file set from v0.5.0/v0.6.0 and can update through nst_updater on a full server restart. No wipe, SQL migration or private configuration replacement is required. Older v0.4.0 installations still need the one-time file-set upgrade. Do not roll back to pre-grid code after adopting new item types without restoring a matching backup of the test data.

Native references: https://docs.fivem.net/docs/scripting-reference/events/server-events/ and https://raw.githubusercontent.com/citizenfx/natives/master/PED/SetPedShootsAtCoord.md
