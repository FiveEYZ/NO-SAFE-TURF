fx_version 'cerulean'
game 'gta5'
author 'NO SAFE TURF contributors'
description 'NO SAFE TURF — crime and survival with weekly seasons'
version '0.2.1'
node_version '22'
dependency '/onesync'
dependency 'spawnmanager'
shared_script 'shared/config.lua'
server_scripts {'server/storage.js','server/core.lua','server/gameplay.lua','server/police.lua','server/main.lua'}
client_script 'client/main.lua'
ui_page 'web/index.html'
files {'web/index.html','web/style.css','web/locale.js','web/app.js'}
