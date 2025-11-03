WSShops = WSShops or {}
WSShops.Migrations = WSShops.Migrations or {}

local Migrations = WSShops.Migrations
local prefix = '[ws-shopsystem] '

local function log(message, ...)
    local formatted = prefix .. (message:format(...))
    print(formatted)
end

local function warn(message, ...)
    local formatted = prefix .. (message:format(...))
    print(formatted)
end

local databaseName

local function getDatabaseName()
    if databaseName ~= nil then
        return databaseName
    end

    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT DATABASE()')
    end)

    if not ok then
        warn('Failed to resolve database name: %s', result)
        databaseName = false
        return databaseName
    end

    databaseName = result or false
    return databaseName
end

local function tableExists(tableName)
    local db = getDatabaseName()
    if not db or db == '' then return false end

    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?', { db, tableName })
    end)

    if not ok then
        warn('Failed to check table %s: %s', tableName, result)
        return false
    end

    return (tonumber(result) or 0) > 0
end

local function columnExists(tableName, columnName)
    local db = getDatabaseName()
    if not db or db == '' then return false end

    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?', { db, tableName, columnName })
    end)

    if not ok then
        warn('Failed to check column %s.%s: %s', tableName, columnName, result)
        return false
    end

    return (tonumber(result) or 0) > 0
end

local function ensureTable(name, statement)
    if tableExists(name) then return true end

    local ok, err = pcall(function()
        MySQL.query.await(statement)
    end)

    if not ok then
        warn('Failed to create table %s: %s', name, err)
        return false
    end

    log('Created missing table %s', name)
    return true
end

local function ensureColumn(tableName, columnName, statement)
    if columnExists(tableName, columnName) then return true end

    local ok, err = pcall(function()
        MySQL.update.await(statement)
    end)

    if not ok then
        warn('Failed to add column %s.%s: %s', tableName, columnName, err)
        return false
    end

    log('Added missing column %s.%s', tableName, columnName)
    return true
end

local tableStatements = {
    { 'ws_shops', [[
        CREATE TABLE IF NOT EXISTS `ws_shops` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `label` VARCHAR(120) NOT NULL,
            `type` VARCHAR(60) NOT NULL,
            `coords` LONGTEXT DEFAULT NULL,
            `heading` FLOAT DEFAULT 0,
            `ped_model` VARCHAR(60) DEFAULT NULL,
            `ped_scenario` VARCHAR(120) DEFAULT NULL,
            `zone_length` FLOAT DEFAULT 2.0,
            `zone_width` FLOAT DEFAULT 2.0,
            `zone_min_z` FLOAT DEFAULT 0,
            `zone_max_z` FLOAT DEFAULT 0,
            `level` INT(11) NOT NULL DEFAULT 1,
            `xp` INT(11) NOT NULL DEFAULT 0,
            `owner_citizenid` VARCHAR(50) DEFAULT NULL,
            `owner_name` VARCHAR(120) DEFAULT NULL,
            `balance` INT(11) NOT NULL DEFAULT 0,
            `purchase_price` INT(11) NOT NULL DEFAULT 0,
            `sell_price` INT(11) NOT NULL DEFAULT 0,
            `discount` INT(11) NOT NULL DEFAULT 0,
            `credit_limit` INT(11) NOT NULL DEFAULT 0,
            `credit_used` INT(11) NOT NULL DEFAULT 0,
            `webhook` TEXT DEFAULT NULL,
            `metadata` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_inventory', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_inventory` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `item` VARCHAR(60) NOT NULL,
            `label` VARCHAR(120) NOT NULL,
            `icon` VARCHAR(120) DEFAULT NULL,
            `category` VARCHAR(60) NOT NULL,
            `quantity` INT(11) NOT NULL DEFAULT 0,
            `base_price` INT(11) NOT NULL DEFAULT 0,
            `override_price` INT(11) DEFAULT NULL,
            `discount` INT(11) NOT NULL DEFAULT 0,
            `min_level` INT(11) NOT NULL DEFAULT 1,
            `metadata` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `shop_item` (`shop_id`, `item`),
            CONSTRAINT `fk_inventory_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_dropoffs', [[
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
    ]] },
    { 'ws_shop_depots', [[
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
    ]] },
    { 'ws_shop_vehicle_spawns', [[
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
    ]] },
    { 'ws_shop_allowed_vehicles', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_allowed_vehicles` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `sort_index` INT(11) NOT NULL DEFAULT 0,
            `vehicle_key` VARCHAR(64) NOT NULL,
            `model` VARCHAR(60) DEFAULT NULL,
            `label` VARCHAR(120) DEFAULT NULL,
            `price` INT(11) NOT NULL DEFAULT 0,
            `min_level` INT(11) NOT NULL DEFAULT 1,
            `capacity` INT(11) NOT NULL DEFAULT 0,
            `trunk_size` INT(11) NOT NULL DEFAULT 0,
            `fuel_modifier` FLOAT NOT NULL DEFAULT 1.0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `vehicle_unique` (`shop_id`, `vehicle_key`),
            CONSTRAINT `fk_allowed_vehicle_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_product_categories', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_product_categories` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `sort_index` INT(11) NOT NULL DEFAULT 0,
            `category` VARCHAR(120) NOT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `product_category_unique` (`shop_id`, `category`),
            CONSTRAINT `fk_product_category_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_routes', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_routes` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `sort_index` INT(11) NOT NULL DEFAULT 0,
            `label` VARCHAR(120) DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `route_shop_idx` (`shop_id`, `sort_index`),
            CONSTRAINT `fk_route_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_route_points', [[
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
    ]] },
    { 'ws_shop_employees', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_employees` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(120) NOT NULL,
            `role` VARCHAR(32) NOT NULL,
            `wage` INT(11) NOT NULL DEFAULT 0,
            `status` ENUM('active','vacation','terminated') NOT NULL DEFAULT 'active',
            `last_activity` DATETIME DEFAULT CURRENT_TIMESTAMP,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `shop_employee_unique` (`shop_id`, `citizenid`),
            CONSTRAINT `fk_employee_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_finance_log', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_finance_log` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `type` VARCHAR(60) NOT NULL,
            `amount` INT(11) NOT NULL,
            `balance_after` INT(11) NOT NULL,
            `description` VARCHAR(255) DEFAULT NULL,
            `payload` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `shop_finance_idx` (`shop_id`,`type`),
            CONSTRAINT `fk_finance_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_deliveries', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_deliveries` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `identifier` VARCHAR(64) NOT NULL,
            `type` VARCHAR(32) NOT NULL DEFAULT 'manual',
            `status` VARCHAR(32) NOT NULL DEFAULT 'pending',
            `citizenid` VARCHAR(50) DEFAULT NULL,
            `vehicle_model` VARCHAR(60) DEFAULT NULL,
            `vehicle_plate` VARCHAR(12) DEFAULT NULL,
            `capacity` INT(11) NOT NULL DEFAULT 0,
            `distance` FLOAT DEFAULT 0,
            `payout` INT(11) DEFAULT 0,
            `penalty` INT(11) DEFAULT 0,
            `metadata` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
            `finished_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            UNIQUE KEY `delivery_identifier` (`identifier`),
            KEY `shop_delivery_idx` (`shop_id`,`status`),
            CONSTRAINT `fk_delivery_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_delivery_items', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_delivery_items` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `delivery_id` INT(11) NOT NULL,
            `item` VARCHAR(60) NOT NULL,
            `label` VARCHAR(120) NOT NULL,
            `quantity` INT(11) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `delivery_item` (`delivery_id`),
            CONSTRAINT `fk_delivery_items_delivery` FOREIGN KEY (`delivery_id`) REFERENCES `ws_shop_deliveries` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_vehicles', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_vehicles` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `model` VARCHAR(60) NOT NULL,
            `plate` VARCHAR(12) NOT NULL,
            `base_capacity` INT(11) NOT NULL DEFAULT 0,
            `upgrades` LONGTEXT DEFAULT NULL,
            `level` INT(11) NOT NULL DEFAULT 1,
            `stored` TINYINT(1) NOT NULL DEFAULT 1,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `plate_unique` (`plate`),
            CONSTRAINT `fk_vehicle_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
    { 'ws_shop_statistics_daily', [[
        CREATE TABLE IF NOT EXISTS `ws_shop_statistics_daily` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `shop_id` INT(11) NOT NULL,
            `stat_date` DATE NOT NULL,
            `sales_total` INT(11) NOT NULL DEFAULT 0,
            `sales_count` INT(11) NOT NULL DEFAULT 0,
            `deliveries_completed` INT(11) NOT NULL DEFAULT 0,
            `deliveries_failed` INT(11) NOT NULL DEFAULT 0,
            `employees_active` INT(11) NOT NULL DEFAULT 0,
            `xp_earned` INT(11) NOT NULL DEFAULT 0,
            `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `shop_day_unique` (`shop_id`,`stat_date`),
            CONSTRAINT `fk_statistics_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]] },
}

local columnStatements = {
    { 'ws_shops', 'ped_model', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `ped_model` VARCHAR(60) DEFAULT NULL' },
    { 'ws_shops', 'ped_scenario', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `ped_scenario` VARCHAR(120) DEFAULT NULL' },
    { 'ws_shops', 'zone_length', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `zone_length` FLOAT DEFAULT 2.0' },
    { 'ws_shops', 'zone_width', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `zone_width` FLOAT DEFAULT 2.0' },
    { 'ws_shops', 'zone_min_z', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `zone_min_z` FLOAT DEFAULT 0' },
    { 'ws_shops', 'zone_max_z', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `zone_max_z` FLOAT DEFAULT 0' },
    { 'ws_shops', 'credit_limit', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `credit_limit` INT(11) NOT NULL DEFAULT 0 AFTER `discount`' },
    { 'ws_shops', 'credit_used', 'ALTER TABLE `ws_shops` ADD COLUMN IF NOT EXISTS `credit_used` INT(11) NOT NULL DEFAULT 0 AFTER `credit_limit`' },
    { 'ws_shop_allowed_vehicles', 'model', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `model` VARCHAR(60) DEFAULT NULL AFTER `vehicle_key`' },
    { 'ws_shop_allowed_vehicles', 'label', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `label` VARCHAR(120) DEFAULT NULL AFTER `model`' },
    { 'ws_shop_allowed_vehicles', 'price', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `price` INT(11) NOT NULL DEFAULT 0 AFTER `label`' },
    { 'ws_shop_allowed_vehicles', 'min_level', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `min_level` INT(11) NOT NULL DEFAULT 1 AFTER `price`' },
    { 'ws_shop_allowed_vehicles', 'capacity', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `capacity` INT(11) NOT NULL DEFAULT 0 AFTER `min_level`' },
    { 'ws_shop_allowed_vehicles', 'trunk_size', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `trunk_size` INT(11) NOT NULL DEFAULT 0 AFTER `capacity`' },
    { 'ws_shop_allowed_vehicles', 'fuel_modifier', 'ALTER TABLE `ws_shop_allowed_vehicles` ADD COLUMN IF NOT EXISTS `fuel_modifier` FLOAT NOT NULL DEFAULT 1.0 AFTER `trunk_size`' },
}

local ranMigrations = false

local function ensureSpecificTables(targets)
    if type(targets) ~= 'table' then return end
    for _, name in ipairs(targets) do
        for _, entry in ipairs(tableStatements) do
            if entry[1] == name then
                ensureTable(entry[1], entry[2])
                break
            end
        end
    end
end

local function executeMigrations()
    for _, entry in ipairs(tableStatements) do
        ensureTable(entry[1], entry[2])
    end

    for _, entry in ipairs(columnStatements) do
        ensureColumn(entry[1], entry[2], entry[3])
    end
end

local function tryRunMigrations()
    if ranMigrations then return true end

    local ok, err = pcall(executeMigrations)
    if not ok then
        warn('Database migration failed: %s', err)
        return false
    end

    ranMigrations = true
    return true
end

Migrations.Ensure = function()
    return tryRunMigrations()
end

Migrations.EnsureDeliveryTables = function()
    local success = tryRunMigrations()
    if not success then return false end
    ensureSpecificTables({
        'ws_shop_deliveries',
        'ws_shop_delivery_items',
        'ws_shop_routes',
        'ws_shop_route_points',
    })
    return true
end

MySQL.ready(function()
    tryRunMigrations()
end)

CreateThread(function()
    Wait(1000)
    tryRunMigrations()
end)

