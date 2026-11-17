-- Shared English defaults. All player/admin wording belongs in locale modules.
NSTLocale = {
    inventoryTooHeavy='Not enough carrying capacity. Move less or equip a larger bag.',
    robberyLootReady='Loot is ready at the robbery location. Approach it and open your inventory to collect it.',
    groundFull='Too many ground containers. Collect existing loot first.',
    openLoot='Press E to open nearby loot',
    spawnWorldUnavailable='The spawn area could not load. Please reconnect. Contact an administrator if this continues.',
    invalidAmount='Invalid amount', playerMissing='Player not found', unknownAction='Unknown action',
    newSeason='A new season has started. Please reconnect.',
    storageChanged='Storage changed or did not respond. Refresh and check the result.',
    cannotUse='You cannot use this right now.', noMedkit='You do not have a medkit.', medkitWait='Wait before using another medkit.',
    databaseNotReady='The database is not ready.', characterLoading='Wait for your character to load.',
    actionComplete='Action completed.', serverBusy='The server is busy. Try again.',
    wipeHelp='nst_wipe dryrun|execute UNIQUE-KEY', wipeSimulating='Simulating wipe.',
    wipeMaintenance='Maintenance: resetting the season.', wipeFailed='Wipe failed; check the server log.',
    wipeSimulated='Simulation complete; no data changed.', wipeComplete='Wipe complete.',
    status='Season %s, revision %s, queue %s',
    wipeWarning='Season reset in %s minute(s). Secure your score for the week.',
    fence='Fence', equipment='Equipment', policeDuty='Police duty', menuBinding='NO SAFE TURF: open menu'
}
function NSTText(key, ...)
    local text=assert(NSTLocale[key], 'Missing English locale key: '..tostring(key))
    if select('#',...)>0 then return string.format(text,...) end
    return text
end
