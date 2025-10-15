fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Wolfstudio'
description 'Advanced ownership-based shop framework for QBCore'
version '0.1.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/main.lua',
    'client/zones.lua',
    'client/deliveries.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/cache.lua',
    'server/main.lua',
    'server/finance.lua',
    'server/deliveries.lua',
    'server/commands.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/icons/*.svg'
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-phone',
    'qb-management'
}
