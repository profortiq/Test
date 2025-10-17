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
    `webhook` TEXT DEFAULT NULL,
    `metadata` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
);

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
);

ALTER TABLE `ws_shops`
    ADD COLUMN IF NOT EXISTS `ped_model` VARCHAR(60) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `ped_scenario` VARCHAR(120) DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS `zone_length` FLOAT DEFAULT 2.0,
    ADD COLUMN IF NOT EXISTS `zone_width` FLOAT DEFAULT 2.0,
    ADD COLUMN IF NOT EXISTS `zone_min_z` FLOAT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `zone_max_z` FLOAT DEFAULT 0;

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
);

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
);

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
);

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
);

CREATE TABLE IF NOT EXISTS `ws_shop_product_categories` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `sort_index` INT(11) NOT NULL DEFAULT 0,
    `category` VARCHAR(120) NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `product_category_unique` (`shop_id`, `category`),
    CONSTRAINT `fk_product_category_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `ws_shop_routes` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `shop_id` INT(11) NOT NULL,
    `sort_index` INT(11) NOT NULL DEFAULT 0,
    `label` VARCHAR(120) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `route_shop_idx` (`shop_id`, `sort_index`),
    CONSTRAINT `fk_route_shop` FOREIGN KEY (`shop_id`) REFERENCES `ws_shops` (`id`) ON DELETE CASCADE
);

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
);

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
);

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
);

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
);

CREATE TABLE IF NOT EXISTS `ws_shop_delivery_items` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `delivery_id` INT(11) NOT NULL,
    `item` VARCHAR(60) NOT NULL,
    `label` VARCHAR(120) NOT NULL,
    `quantity` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `delivery_item` (`delivery_id`),
    CONSTRAINT `fk_delivery_items_delivery` FOREIGN KEY (`delivery_id`) REFERENCES `ws_shop_deliveries` (`id`) ON DELETE CASCADE
);

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
);

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
);
