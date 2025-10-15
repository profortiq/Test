WSShopConfig = {
    Locale = 'de',
    Debug = false,
    UseTarget = true,
    TargetIcon = 'fas fa-store',
    TargetLabel = 'Shop oeffnen',
    TargetDistance = 2.0,
    BossmenuLabel = 'Shopverwaltung',
    InteractionKey = 'E',
    ManagementKey = 'G',
    BankingAccount = 'bank',
    CashSalesFallback = true,
    LowStockThreshold = 15,
    LowStockCooldown = 600, -- seconds before another alert
    AutoDeliveryThreshold = 10,
    DefaultRestockQuantity = 50,
    PhoneResource = 'qb-phone', -- for push messages
    ManagementCommand = 'shopadmin',
    DeliveryBlipSprite = 478,
    DeliveryBlipColor = 1,
    DepotBlipSprite = 478,
    DepotBlipColor = 75,
    DeliveryTickRate = 1000,
    DeliveryFailurePenalty = 400,
    DeliveryBasePayout = 75,
    DeliveryFuelCostPerKm = 18,
    DeliveryCapacityBonusPerLevel = 15,
    VehicleMaintainanceCost = 125,
    StatHistoryDays = 30,
    OfflineWagePayout = true,
    AutoTerminateInactiveDays = 14,
    ManagerMenuAccessRoles = { 'manager', 'owner' },
    FinanceAccessRoles = { 'owner' },
    DeliveryAccessRoles = { 'owner', 'manager', 'driver' },
    DiscountAccessRoles = { 'owner', 'manager' },
    AllowedWebhookEvents = {
        ['big_sale'] = true,
        ['delivery_failed'] = true,
        ['level_up'] = true,
    },
}

WSShopConfig.XP = {
    Sale = 5,
    Delivery = 35,
    EmployeeSale = 7,
    ManualRestock = 10,
    MissionSuccessBonus = 15,
    MissionFailurePenalty = 10,
}

WSShopConfig.Levels = {
    [1] = {
        xp = 0,
        label = 'Startup',
        unlocks = { features = { 'basic_sales' }, vehicles = { 'pony' }, discounts = 0 },
        credit = 0,
    },
    [2] = {
        xp = 250,
        label = 'Junior Haendler',
        unlocks = { features = { 'discounts', 'auto_orders', 'credit_line' }, vehicles = { 'speedo' }, discounts = 2 },
        credit = 5000,
    },
    [3] = {
        xp = 600,
        label = 'Franchise',
        unlocks = { features = { 'employee_bonuses', 'premium_products' }, vehicles = { 'benson' }, discounts = 4 },
        credit = 10000,
    },
    [4] = {
        xp = 1200,
        label = 'Unternehmen',
        unlocks = { features = { 'fleet_upgrade', 'priority_deliveries' }, vehicles = { 'mule' }, discounts = 6 },
        credit = 15000,
    },
    [5] = {
        xp = 2000,
        label = 'Konzern',
        unlocks = { features = { 'exclusive_products', 'fast_deliveries', 'brand_customization' }, vehicles = { 'pounder' }, discounts = 8 },
        credit = 20000,
    },
}

WSShopConfig.Roles = {
    owner = {
        label = 'Besitzer',
        wage = 0,
        permissions = { 'everything' },
    },
    manager = {
        label = 'Manager',
        wage = 350,
        permissions = { 'hire', 'fire', 'finance_view', 'pricing', 'deliveries', 'discounts', 'stats' },
    },
    cashier = {
        label = 'Kassierer',
        wage = 250,
        permissions = { 'sales', 'inventory_view', 'discounts_limited' },
    },
    driver = {
        label = 'Fahrer',
        wage = 280,
        permissions = { 'deliveries', 'vehicles' },
    },
}

WSShopConfig.ShopTypes = {
    ['247'] = {
        label = '24/7 Markt',
        purchasePrice = 125000,
        sellPrice = 90000,
        icon = 'icons/247.svg',
        baseProducts = {
            snacks = {
                label = 'Snacks',
                items = {
                    { item = 'sandwich', label = 'Sandwich', icon = 'icons/sandwich.svg', price = 6, restock = 50 },
                    { item = 'donut', label = 'Donut', icon = 'icons/donut.svg', price = 5, restock = 50 },
                    { item = 'chips', label = 'Chips', icon = 'icons/chips.svg', price = 4, restock = 50 },
                },
            },
            drinks = {
                label = 'Getraenke',
                items = {
                    { item = 'water_bottle', label = 'Wasser', icon = 'icons/water.svg', price = 3, restock = 60 },
                    { item = 'coffee', label = 'Kaffee', icon = 'icons/coffee.svg', price = 4, restock = 45 },
                    { item = 'cola', label = 'Cola', icon = 'icons/cola.svg', price = 4, restock = 60 },
                },
            },
            misc = {
                label = 'Sonstiges',
                items = {
                    { item = 'bandage', label = 'Bandage', icon = 'icons/bandage.svg', price = 12, restock = 30 },
                    { item = 'lighter', label = 'Feuerzeug', icon = 'icons/lighter.svg', price = 8, restock = 25 },
                    { item = 'phone', label = 'Einfaches Telefon', icon = 'icons/phone.svg', price = 450, restock = 10 },
                },
            },
        },
    },
    ['ammunation'] = {
        label = 'Ammu-Nation',
        purchasePrice = 350000,
        sellPrice = 250000,
        icon = 'icons/ammo.svg',
        restricted = true,
        baseProducts = {
            pistols = {
                label = 'Pistolen',
                items = {
                    { item = 'weapon_pistol', label = 'Pistol', icon = 'icons/pistol.svg', price = 6000, restock = 20, minLevel = 2 },
                    { item = 'pistol_ammo', label = '9mm Munition', icon = 'icons/ammo.svg', price = 75, restock = 120, minLevel = 1 },
                },
            },
            accessories = {
                label = 'Zubehoer',
                items = {
                    { item = 'weapon_flashlight', label = 'Taschenlampe', icon = 'icons/flashlight.svg', price = 750, restock = 30 },
                    { item = 'weapon_knife', label = 'Messer', icon = 'icons/knife.svg', price = 650, restock = 35 },
                },
            },
        },
    },
    ['hardware'] = {
        label = 'Baumarkt',
        purchasePrice = 200000,
        sellPrice = 140000,
        icon = 'icons/hardware.svg',
        baseProducts = {
            tools = {
                label = 'Werkzeuge',
                items = {
                    { item = 'lockpick', label = 'Dietrich', icon = 'icons/lockpick.svg', price = 150, restock = 40 },
                    { item = 'weapon_wrench', label = 'Schraubenschluessel', icon = 'icons/wrench.svg', price = 250, restock = 35 },
                    { item = 'repairkit', label = 'Reparaturkit', icon = 'icons/repairkit.svg', price = 950, restock = 20 },
                },
            },
            building = {
                label = 'Baumaterial',
                items = {
                    { item = 'metalscrap', label = 'Metallschrott', icon = 'icons/metal.svg', price = 25, restock = 80 },
                    { item = 'plastic', label = 'Plastik', icon = 'icons/plastic.svg', price = 14, restock = 80 },
                    { item = 'aluminum', label = 'Aluminium', icon = 'icons/aluminum.svg', price = 18, restock = 70 },
                },
            },
        },
    },
    ['weed'] = {
        label = 'Green Corner',
        purchasePrice = 275000,
        sellPrice = 190000,
        icon = 'icons/weed.svg',
        illegal = true,
        baseProducts = {
            flower = {
                label = 'Blueten',
                items = {
                    { item = 'weed_skunk', label = 'Skunk', icon = 'icons/weedbag.svg', price = 85, restock = 90 },
                    { item = 'weed_purple_haze', label = 'Purple Haze', icon = 'icons/weedbag.svg', price = 95, restock = 90 },
                },
            },
            accessories = {
                label = 'Zubehoer',
                items = {
                    { item = 'rolling_paper', label = 'Papes', icon = 'icons/paper.svg', price = 6, restock = 120 },
                    { item = 'lighter', label = 'Feuerzeug', icon = 'icons/lighter.svg', price = 7, restock = 120 },
                },
            },
        },
    },
}

WSShopConfig.Shops = {
    legion247 = {
        label = 'Legion Square 24/7',
        type = '247',
        ped = { model = 'mp_m_shopkeep_01', scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        coords = vector3(25.7, -1345.3, 29.5),
        heading = 271.0,
        zone = { length = 2.0, width = 2.0, minZ = 28.5, maxZ = 30.5 },
        blip = { sprite = 59, color = 1, scale = 0.8 },
        defaultStock = 'config',
    },
    sandy247 = {
        label = 'Sandy Shores 24/7',
        type = '247',
        ped = { model = 'mp_m_shopkeep_01', scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        coords = vector3(1961.24, 3740.3, 32.34),
        heading = 312.0,
        zone = { length = 2.0, width = 2.0, minZ = 31.34, maxZ = 33.34 },
        blip = { sprite = 59, color = 1, scale = 0.8 },
        defaultStock = 'config',
    },
    paleto247 = {
        label = 'Paleto Bay 24/7',
        type = '247',
        ped = { model = 'mp_m_shopkeep_01', scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        coords = vector3(1730.12, 6413.02, 35.04),
        heading = 67.0,
        zone = { length = 2.0, width = 2.0, minZ = 34.04, maxZ = 36.04 },
        blip = { sprite = 59, color = 1, scale = 0.8 },
        defaultStock = 'config',
    },
}

WSShopConfig.Depots = {
    {
        label = 'Los Santos Logistik',
        coords = vector3(1204.51, -3115.38, 5.54),
        heading = 0.0,
        radius = 40.0,
    },
    {
        label = 'Paleto Bay Depot',
        coords = vector3(169.34, 6624.28, 31.64),
        heading = 45.0,
        radius = 35.0,
    },
}

WSShopConfig.DeliveryVehicles = {
    pony = {
        label = 'Pony',
        capacity = 65,
        minLevel = 1,
        fuelModifier = 1.0,
        trunkInventory = 225000,
        price = 7500,
        upgrades = {
            cargo = { label = 'Cargo-Upgrade I', capacityBonus = 20, price = 9500 },
            engine = { label = 'Motor Tuning I', speedBonus = 0.1, price = 8500 },
        },
    },
    speedo = {
        label = 'Speedo',
        capacity = 90,
        minLevel = 2,
        fuelModifier = 0.95,
        trunkInventory = 250000,
        price = 12500,
        upgrades = {
            cargo = { label = 'Cargo-Upgrade II', capacityBonus = 35, price = 13500 },
            engine = { label = 'Motor Tuning II', speedBonus = 0.15, price = 11500 },
        },
    },
    benson = {
        label = 'Benson',
        capacity = 130,
        minLevel = 3,
        fuelModifier = 1.15,
        trunkInventory = 325000,
        price = 18500,
        upgrades = {
            cargo = { label = 'Cargo-Upgrade III', capacityBonus = 45, price = 16500 },
            engine = { label = 'Motor Tuning III', speedBonus = 0.18, price = 14000 },
        },
    },
    mule = {
        label = 'Mule',
        capacity = 170,
        minLevel = 4,
        fuelModifier = 1.2,
        trunkInventory = 400000,
        price = 23500,
        upgrades = {
            cargo = { label = 'Cargo-Upgrade IV', capacityBonus = 55, price = 21500 },
            engine = { label = 'Motor Tuning IV', speedBonus = 0.2, price = 17500 },
        },
    },
    pounder = {
        label = 'Pounder',
        capacity = 240,
        minLevel = 5,
        fuelModifier = 1.4,
        trunkInventory = 475000,
        price = 29500,
        upgrades = {
            cargo = { label = 'Cargo-Upgrade V', capacityBonus = 65, price = 27500 },
            engine = { label = 'Motor Tuning V', speedBonus = 0.25, price = 21500 },
        },
    },
}

WSShopConfig.Notifications = {
    phone = {
        sender = 'Wirtschaftskammer',
        subjectLowStock = 'Niedriger Bestand in %s',
        subjectDelivery = 'Lieferauftrag',
        subjectFinance = 'Shop Finanzen - %s',
        messageLowStock = 'Artikel %s faellt unter %s Stueck. Bitte fuelle das Lager auf.',
        messageAutoDelivery = 'Automatische Bestellung fuer %s erstellt (%s Einheiten).',
        messageDeliveryReady = 'Lieferung %s wartet im Depot %s.',
        messageFailed = 'Lieferung %s fehlgeschlagen. Vertragsstrafe: $%s.',
        messagePayroll = 'Gehalt von $%s erhalten von %s.',
    },
    webhook = {
        enabled = false,
        url = '',
    },
}

WSShopConfig.Icons = {
    default = 'icons/default.svg',
}

return WSShopConfig
