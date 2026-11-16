'use strict';
module.exports={
 usage:'node tools/database.js check|init|export|restore --config PRIVATE_JSON [--id BACKUP_ID --file FILE] [--reschedule]',
 version:'Database version:',tables:'Table count:',metadata:'; NO SAFE TURF metadata present:',
 checked:'Read-only check passed. No data changed.',initialized:'Schema initialized. No game server started.',
 exported:'Backup exported to a new file.',restored:'Backup restored to the empty destination database.'
};
