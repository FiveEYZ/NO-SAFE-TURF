'use strict';
module.exports=Object.freeze({
  configuration:'Storage configuration is not ready.', unavailable:'Storage unavailable; reload state before retry',
  body:'Invalid body size', request:'Invalid request', operation:'Unknown storage operation', conflict:'Stale revision; reload state',
  invalid:'Invalid state or operation', backup:'Verified backup unavailable; wipe aborted. Check private backup storage.',
  ready:'MariaDB connection and schema are ready.', backupArmed:'Backup directory configured; write/read verification is required at every wipe.',
  backupMissing:'Wipes are blocked: configure nst_backup_directory before operation.',
  failure:'Storage operation failed ({code}). Check the private database configuration and schema.'
});
