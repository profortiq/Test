WSShops = WSShops or {}

local function log(message, ...)
    local formatted = message
    if select('#', ...) > 0 then
        formatted = message:format(...)
    end
    print(('^3[ws-shopsystem]^7 %s'):format(formatted))
end

local function tableExists(name)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { name })
    return count and count > 0
end

local function columnExists(tableName, columnName)
    local count = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?]], { tableName, columnName })
    return count and count > 0
end

local schemaTables = {
    {
        name = 'ws_shop_dropoffs',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_dropoffs` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `shop_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `label` VARCHAR(120) DEFAULT NULL,
                `x` FLOAT NOT NULL DEFAULT 0,
                `y` FLOAT NOT NULL DEFAULT 0,
                `z` FLOAT NOT NULL DEFAULT 0,
                PRIMARY KEY (`id`),
                KEY `dropoff_shop_idx` (`shop_id`, `sort_index`),
                CONSTRAINT `fk_dropoff_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = 'ws_shop_depots',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_depots` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `shop_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `label` VARCHAR(120) DEFAULT NULL,
                `x` FLOAT NOT NULL DEFAULT 0,
                `y` FLOAT NOT NULL DEFAULT 0,
                `z` FLOAT NOT NULL DEFAULT 0,
                `heading` FLOAT DEFAULT 0,
                PRIMARY KEY (`id`),
                KEY `depot_shop_idx` (`shop_id`, `sort_index`),
                CONSTRAINT `fk_depot_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = 'ws_shop_vehicle_spawns',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_vehicle_spawns` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `shop_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `label` VARCHAR(120) DEFAULT NULL,
                `x` FLOAT NOT NULL DEFAULT 0,
                `y` FLOAT NOT NULL DEFAULT 0,
                `z` FLOAT NOT NULL DEFAULT 0,
                `heading` FLOAT DEFAULT 0,
                PRIMARY KEY (`id`),
                KEY `vehicle_spawn_shop_idx` (`shop_id`, `sort_index`),
                CONSTRAINT `fk_vehicle_spawn_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = 'ws_shop_allowed_vehicles',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_allowed_vehicles` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `shop_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `vehicle_key` VARCHAR(64) NOT NULL,
                PRIMARY KEY (`id`),
                UNIQUE KEY `vehicle_unique` (`shop_id`, `vehicle_key`),
                CONSTRAINT `fk_allowed_vehicle_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = 'ws_shop_product_categories',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_product_categories` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `shop_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `category` VARCHAR(120) NOT NULL,
                PRIMARY KEY (`id`),
                UNIQUE KEY `product_category_unique` (`shop_id`, `category`),
                CONSTRAINT `fk_product_category_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = 'ws_shop_routes',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_routes` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `shop_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `label` VARCHAR(120) DEFAULT NULL,
                PRIMARY KEY (`id`),
                KEY `route_shop_idx` (`shop_id`, `sort_index`),
                CONSTRAINT `fk_route_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
    {
        name = 'ws_shop_route_points',
        sql = [[
            CREATE TABLE IF NOT EXISTS `ws_shop_route_points` (
                `id` INT(11) NOT NULL AUTO_INCREMENT,
                `route_id` INT(11) NOT NULL,
                `sort_index` INT(11) NOT NULL DEFAULT 0,
                `label` VARCHAR(120) DEFAULT NULL,
                `x` FLOAT NOT NULL DEFAULT 0,
                `y` FLOAT NOT NULL DEFAULT 0,
                `z` FLOAT NOT NULL DEFAULT 0,
                PRIMARY KEY (`id`),
                KEY `route_point_idx` (`route_id`, `sort_index`),
                CONSTRAINT `fk_route_point_route` FOREIGN KEY (`route_id`) REFERENCES `ws_shop_routes` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
    },
}

local schemaColumns = {
    { table = 'ws_shops', column = 'ped_model', definition = '`ped_model` VARCHAR(60) DEFAULT NULL' },
    { table = 'ws_shops', column = 'ped_scenario', definition = '`ped_scenario` VARCHAR(120) DEFAULT NULL' },
    { table = 'ws_shops', column = 'zone_length', definition = '`zone_length` FLOAT DEFAULT 2.0' },
    { table = 'ws_shops', column = 'zone_width', definition = '`zone_width` FLOAT DEFAULT 2.0' },
    { table = 'ws_shops', column = 'zone_min_z', definition = '`zone_min_z` FLOAT DEFAULT 0' },
    { table = 'ws_shops', column = 'zone_max_z', definition = '`zone_max_z` FLOAT DEFAULT 0' },
}

local function ensureSchema()
    local created, added = 0, 0

    for _, entry in ipairs(schemaTables) do
        if not tableExists(entry.name) then
            MySQL.update.await(entry.sql)
            created = created + 1
        end
    end

    for _, entry in ipairs(schemaColumns) do
        if not columnExists(entry.table, entry.column) then
            MySQL.update.await(('ALTER TABLE `%s` ADD COLUMN %s'):format(entry.table, entry.definition))
            added = added + 1
        end
    end

    if created > 0 or added > 0 then
        log('Schema synchronised (%s tables created, %s columns added)', created, added)
    end
end

WSShops.Migrations = WSShops.Migrations or {}
WSShops.Migrations.EnsureSchema = ensureSchema

CreateThread(function()
    -- Give the database wrapper time to initialise before running migrations
    Wait(750)
    local ok, err = pcall(ensureSchema)
    if not ok then
        log('Schema sync failed: %s', err)
    end
end)
