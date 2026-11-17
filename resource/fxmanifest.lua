fx_version 'cerulean'
game 'gta5'
author 'NO SAFE TURF contributors'
description 'NO SAFE TURF — crime and survival with weekly seasons'
version '0.4.0'
node_version '22'
dependency '/onesync'
dependency 'spawnmanager'
dependency 'oxmysql'
dependency 'nst_database_config'
shared_scripts {'shared/locale_en.lua','shared/locale_gameplay_en.lua','shared/config.lua'}
server_scripts {'server/storage.js','server/locales/police_en.lua','server/core.lua','server/gameplay.lua','server/police.lua','server/main.lua'}
client_script 'client/main.lua'
ui_page 'web/index.html'
files {'web/index.html','web/style.css','web/locale.js','web/app.js'}
