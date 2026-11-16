'use strict';
const L=require(require('node:path').join(GetResourcePath('nst_database_config'),'locale_en.js'));
// Runs before oxmysql. Never logs raw credentials or driver messages.
SetConvar('nst_db_configured','0');
SetConvar('mysql_connection_string','host=127.0.0.1;port=1;user=NST_CONFIG_INVALID;database=NST_CONFIG_INVALID');
try {
  const path=require('node:path');
  const root=GetResourcePath('no_safe_turf');
  const {readConfig,connectionConfig}=require(path.join(root,'server/storage/config.js'));
  const {oxConnectionString}=require(path.join(root,'server/storage/oxmysql.js'));
  const url=GetConvar('nst_db_connection','');
  const config=url?connectionConfig(url):readConfig(path.resolve(root,GetConvar('nst_db_config','server/mariadb.private.json')));
  const caPath=GetConvar('nst_db_ssl_ca','');
  if(caPath)config.ssl={ca:require('node:fs').readFileSync(path.resolve(root,caPath),'utf8'),rejectUnauthorized:true,verifyIdentity:true};
  SetConvar('mysql_connection_string',oxConnectionString(config));
  SetConvar('mysql_debug','false');SetConvar('mysql_ui','false');SetConvar('mysql_log_size','0');
  SetConvar('nst_db_configured','1');
}catch{
  console.error('[NST] '+L.configurationRejected);
}
