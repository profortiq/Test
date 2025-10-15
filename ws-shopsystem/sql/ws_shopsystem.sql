CREATE TABLE IF NOT EXISTS `ws_shops` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `label` VARCHAR(120) NOT NULL,
    `type` VARCHAR(60) NOT NULL,
    `coords` LONGTEXT DEFAULT NULL,
    `heading` FLOAT DEFAULT 0,
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
