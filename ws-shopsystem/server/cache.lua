local Config = WSShopConfig
local Utils = WSShops.Utils
local QBCore = exports['qb-core']:GetCoreObject()

WSShops.DB = WSShops.DB or {}
WSShops.Cache = WSShops.Cache or {
    ShopsById = {},
    ShopsByIdentifier = {},
}

local Cache = WSShops.Cache

local function EncodeCoords(coords)
    if type(coords) == 'table' and coords.x then
        return json.encode(coords)
    end
    if type(coords) == 'vector3' or type(coords) == 'vector4' then
        return json.encode({ x = coords.x, y = coords.y, z = coords.z, w = coords.w })
    end
    return coords
end

local function DecodeCoords(payload)
    if not payload then return nil end
    local ok, data = pcall(json.decode, payload)
    if not ok then return nil end
    if data.w then
        return vector4(data.x, data.y, data.z, data.w)
    end
    if data.x then
        return vector3(data.x, data.y, data.z)
    end
    return data
end

local function EnsureShopExists(identifier, shopConfig)
    local row = MySQL.single.await('SELECT * FROM ws_shops WHERE identifier = ?', { identifier })
    local shopType = shopConfig.type or shopConfig.shopType or (row and row.type) or '247'
    local shopTypeConfig = Config.ShopTypes[shopType] or {}

    if row then
        local desiredPurchase = shopConfig.purchasePrice
        if (not desiredPurchase or desiredPurchase <= 0) and shopTypeConfig.purchasePrice then
            desiredPurchase = shopTypeConfig.purchasePrice
        end
        desiredPurchase = desiredPurchase or row.purchase_price or 0

        local desiredSell = shopConfig.sellPrice
        if (not desiredSell or desiredSell <= 0) and shopTypeConfig.sellPrice then
            desiredSell = shopTypeConfig.sellPrice
        end
        desiredSell = desiredSell or row.sell_price or 0

        local needsUpdate = false
        if (row.purchase_price or 0) <= 0 and desiredPurchase > 0 then
            row.purchase_price = desiredPurchase
            needsUpdate = true
        end
        if (row.sell_price or 0) <= 0 and desiredSell > 0 then
            row.sell_price = desiredSell
            needsUpdate = true
        end
        if needsUpdate then
            MySQL.update.await('UPDATE ws_shops SET purchase_price = ?, sell_price = ? WHERE id = ?', {
                row.purchase_price,
                row.sell_price,
                row.id,
            })
        end
        return row
    end

    local purchasePrice = shopConfig.purchasePrice
    if (not purchasePrice or purchasePrice <= 0) and shopTypeConfig.purchasePrice then
        purchasePrice = shopTypeConfig.purchasePrice
    end
    purchasePrice = purchasePrice or 0

    local sellPrice = shopConfig.sellPrice
    if (not sellPrice or sellPrice <= 0) and shopTypeConfig.sellPrice then
        sellPrice = shopTypeConfig.sellPrice
    end
    sellPrice = sellPrice or 0

    local pedModel = shopConfig.ped and shopConfig.ped.model or nil
    local pedScenario = shopConfig.ped and shopConfig.ped.scenario or nil
    local zone = shopConfig.zone or {}
    local zoneLength = tonumber(zone.length) or 2.0
    local zoneWidth = tonumber(zone.width) or 2.0
    local baseZ = (shopConfig.coords and shopConfig.coords.z) or 0.0
    local zoneMinZ = tonumber(zone.minZ) or (baseZ - 1.0)
    local zoneMaxZ = tonumber(zone.maxZ) or (baseZ + 1.0)

    local insertId = MySQL.insert.await('INSERT INTO ws_shops (identifier, label, type, coords, heading, purchase_price, sell_price, metadata, ped_model, ped_scenario, zone_length, zone_width, zone_min_z, zone_max_z) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        identifier,
        shopConfig.label,
        shopType,
        EncodeCoords(shopConfig.coords),
        shopConfig.heading or 0.0,
        purchasePrice,
        sellPrice,
        json.encode({
            ped = shopConfig.ped,
            zone = shopConfig.zone,
            blip = shopConfig.blip,
        }),
        pedModel,
        pedScenario,
        zoneLength,
        zoneWidth,
        zoneMinZ,
        zoneMaxZ,
    })

    Utils.Debug('Inserted new shop %s (%s) with id %s', identifier, shopConfig.label, insertId)

    row = MySQL.single.await('SELECT * FROM ws_shops WHERE id = ?', { insertId })
    return row
end

local function SeedInventory(shopId, shopTypeConfig)
    if not shopTypeConfig or not shopTypeConfig.baseProducts then return false end
    local rows = MySQL.query.await('SELECT COUNT(*) as count FROM ws_shop_inventory WHERE shop_id = ?', { shopId })
    if rows and rows[1] and rows[1].count > 0 then
        return false
    end

    local inserted = 0
    for category, data in pairs(shopTypeConfig.baseProducts) do
        for _, item in ipairs(data.items) do
            MySQL.insert.await([[
                INSERT INTO ws_shop_inventory
                    (shop_id, item, label, icon, category, quantity, base_price, override_price, min_level, discount)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                shopId,
                item.item,
                item.label,
                item.icon,
                category,
                item.restock or Config.DefaultRestockQuantity or 50,
                item.price or 0,
                item.price or 0,
                item.minLevel or 1,
                0,
            })
            inserted = inserted + 1
        end
    end
    if inserted > 0 then
        Utils.Debug('Seeded inventory for shop %s with %s entries', shopId, inserted)
        return true
    end
    return false
end

local function BuildShop(row)
    local identifier = row.identifier
    local configShop = Utils.DeepCopy(Config.Shops[identifier] or {})
    local shopType = row.type or configShop.type
    local shopTypeConfig = Config.ShopTypes[shopType] or {}
    local inventory = {}
    local baseProducts = (shopTypeConfig and shopTypeConfig.baseProducts) or {}
    local inventoryRows = MySQL.query.await('SELECT * FROM ws_shop_inventory WHERE shop_id = ?', { row.id }) or {}
    if (#inventoryRows == 0) and shopTypeConfig and configShop.defaultStock == 'config' then
        local seeded = SeedInventory(row.id, shopTypeConfig)
        if seeded then
            inventoryRows = MySQL.query.await('SELECT * FROM ws_shop_inventory WHERE shop_id = ?', { row.id }) or {}
        end
    end

    for _, item in ipairs(inventoryRows) do
        local category = item.category or 'uncategorised'
        local categoryLabel = category
        if baseProducts[category] and baseProducts[category].label then
            categoryLabel = baseProducts[category].label
        end
        local icon = item.icon
        if (not icon or icon == '') and baseProducts[category] then
            for _, baseItem in ipairs(baseProducts[category].items or {}) do
                if baseItem.item == item.item then
                    icon = baseItem.icon
                    break
                end
            end
        end
        inventory[category] = inventory[category] or { label = categoryLabel, items = {} }
        inventory[category].items[#inventory[category].items + 1] = {
            id = item.id,
            item = item.item,
            label = item.label,
            icon = icon,
            quantity = item.quantity,
            basePrice = item.base_price,
            overridePrice = item.override_price,
            category = category,
            minLevel = item.min_level,
            discount = item.discount or 0,
        }
    end

    local employees = MySQL.query.await('SELECT * FROM ws_shop_employees WHERE shop_id = ?', { row.id }) or {}
    local deliveries = MySQL.query.await('SELECT * FROM ws_shop_deliveries WHERE shop_id = ? AND status IN ("pending","active")', { row.id }) or {}
    for _, delivery in ipairs(deliveries) do
        delivery.items = MySQL.query.await('SELECT item, label, quantity FROM ws_shop_delivery_items WHERE delivery_id = ?', { delivery.id }) or {}
        if delivery.metadata then
            local okMeta, decoded = pcall(json.decode, delivery.metadata)
            if okMeta and decoded then
                delivery.metadata = decoded
            end
        end
    end

    local metadata = {}
    if row.metadata then
        local ok, decoded = pcall(json.decode, row.metadata)
        if ok and decoded then metadata = decoded end
    end

    local creator = metadata.creator or {}

    if metadata.ped and not creator.ped then
        creator.ped = metadata.ped
    end
    if metadata.zone and not creator.zone then
        creator.zone = metadata.zone
    end
    if metadata.blip and creator.blip == nil then
        creator.blip = metadata.blip
    end

    metadata.creator = creator

    if row.ped_model and row.ped_model ~= '' then
        creator.ped = creator.ped or {}
        creator.ped.model = row.ped_model
        creator.ped.scenario = row.ped_scenario
    end

    if row.zone_length and row.zone_length > 0 then
        creator.zone = creator.zone or {}
        creator.zone.length = row.zone_length
        creator.zone.width = row.zone_width or creator.zone.width or 2.0
        creator.zone.minZ = row.zone_min_z or creator.zone.minZ or 0.0
        creator.zone.maxZ = row.zone_max_z or creator.zone.maxZ or 0.0
    end

    local dropoffRows = MySQL.query.await('SELECT label, x, y, z FROM ws_shop_dropoffs WHERE shop_id = ? ORDER BY sort_index ASC, id ASC', { row.id }) or {}
    if #dropoffRows > 0 then
        creator.dropoffs = {}
        for _, entry in ipairs(dropoffRows) do
            creator.dropoffs[#creator.dropoffs + 1] = {
                x = tonumber(entry.x) or 0.0,
                y = tonumber(entry.y) or 0.0,
                z = tonumber(entry.z) or 0.0,
                label = entry.label,
            }
        end
    end

    local depotRows = MySQL.query.await('SELECT label, x, y, z, heading FROM ws_shop_depots WHERE shop_id = ? ORDER BY sort_index ASC, id ASC', { row.id }) or {}
    if #depotRows > 0 then
        creator.depots = {}
        for _, entry in ipairs(depotRows) do
            creator.depots[#creator.depots + 1] = {
                x = tonumber(entry.x) or 0.0,
                y = tonumber(entry.y) or 0.0,
                z = tonumber(entry.z) or 0.0,
                heading = tonumber(entry.heading) or 0.0,
                label = entry.label,
            }
        end
    end

    local spawnRows = MySQL.query.await('SELECT label, x, y, z, heading FROM ws_shop_vehicle_spawns WHERE shop_id = ? ORDER BY sort_index ASC, id ASC', { row.id }) or {}
    if #spawnRows > 0 then
        creator.vehicleSpawns = {}
        for _, entry in ipairs(spawnRows) do
            creator.vehicleSpawns[#creator.vehicleSpawns + 1] = {
                x = tonumber(entry.x) or 0.0,
                y = tonumber(entry.y) or 0.0,
                z = tonumber(entry.z) or 0.0,
                heading = tonumber(entry.heading) or 0.0,
                label = entry.label,
            }
        end
    end

    local vehicleRows = MySQL.query.await('SELECT vehicle_key FROM ws_shop_allowed_vehicles WHERE shop_id = ? ORDER BY sort_index ASC, id ASC', { row.id }) or {}
    if #vehicleRows > 0 then
        creator.vehicles = {}
        for _, entry in ipairs(vehicleRows) do
            creator.vehicles[#creator.vehicles + 1] = entry.vehicle_key
        end
    end

    local categoryRows = MySQL.query.await('SELECT category FROM ws_shop_product_categories WHERE shop_id = ? ORDER BY sort_index ASC, id ASC', { row.id }) or {}
    if #categoryRows > 0 then
        creator.products = {}
        for _, entry in ipairs(categoryRows) do
            creator.products[#creator.products + 1] = entry.category
        end
    end

    local routeRows = MySQL.query.await('SELECT id, label FROM ws_shop_routes WHERE shop_id = ? ORDER BY sort_index ASC, id ASC', { row.id }) or {}
    if #routeRows > 0 then
        creator.routes = {}
        for _, route in ipairs(routeRows) do
            local points = MySQL.query.await('SELECT label, x, y, z FROM ws_shop_route_points WHERE route_id = ? ORDER BY sort_index ASC, id ASC', { route.id }) or {}
            local mapped = { label = route.label, points = {} }
            for _, point in ipairs(points) do
                mapped.points[#mapped.points + 1] = {
                    x = tonumber(point.x) or 0.0,
                    y = tonumber(point.y) or 0.0,
                    z = tonumber(point.z) or 0.0,
                    label = point.label,
                }
            end
            creator.routes[#creator.routes + 1] = mapped
        end
    end

    if creator.ped then
        configShop.ped = creator.ped
    end
    if creator.zone then
        configShop.zone = creator.zone
    end
    if creator.blip == false then
        configShop.blip = nil
    elseif creator.blip then
        configShop.blip = creator.blip
    end

    local coords = creator.coords and vector3(creator.coords.x, creator.coords.y, creator.coords.z)
        or configShop.coords or DecodeCoords(row.coords)
    local headingOverride = creator.heading or (creator.coords and creator.coords.w)
    local heading = headingOverride or configShop.heading or row.heading or 0.0

    local purchasePrice = row.purchase_price
    if (not purchasePrice or purchasePrice <= 0) then
        if configShop.purchasePrice and configShop.purchasePrice > 0 then
            purchasePrice = configShop.purchasePrice
        elseif shopTypeConfig.purchasePrice and shopTypeConfig.purchasePrice > 0 then
            purchasePrice = shopTypeConfig.purchasePrice
        else
            purchasePrice = 0
        end
    end

    local sellPrice = row.sell_price
    if (not sellPrice or sellPrice <= 0) then
        if configShop.sellPrice and configShop.sellPrice > 0 then
            sellPrice = configShop.sellPrice
        elseif shopTypeConfig.sellPrice and shopTypeConfig.sellPrice > 0 then
            sellPrice = shopTypeConfig.sellPrice
        else
            sellPrice = 0
        end
    end

    local shop = {
        id = row.id,
        identifier = identifier,
        label = row.label,
        type = shopType,
        coords = coords,
        heading = heading,
        owner = row.owner_citizenid,
        ownerName = row.owner_name,
        level = row.level,
        xp = row.xp,
        balance = row.balance or 0,
        purchasePrice = purchasePrice,
        sellPrice = sellPrice,
        discount = row.discount,
        metadata = metadata,
        config = configShop,
        typeConfig = shopTypeConfig,
        inventory = inventory,
        employees = employees,
        deliveries = deliveries,
    }

    return shop
end

local function CacheShop(shop)
    Cache.ShopsById[shop.id] = shop
    Cache.ShopsByIdentifier[shop.identifier] = shop
end

function WSShops.DB.LoadAll()
    if WSShops.Migrations and WSShops.Migrations.EnsureSchema then
        local ok, err = pcall(WSShops.Migrations.EnsureSchema)
        if not ok then
            print(('^1[ws-shopsystem]^7 Failed to ensure schema: %s'):format(err))
        end
    end

    Cache.ShopsById = {}
    Cache.ShopsByIdentifier = {}

    for identifier, shopConfig in pairs(Config.Shops) do
        EnsureShopExists(identifier, shopConfig)
    end

    local rows = MySQL.query.await('SELECT * FROM ws_shops', {})
    local total = 0
    for _, row in ipairs(rows or {}) do
        local shop = BuildShop(row)
        CacheShop(shop)
        local seeded = SeedInventory(shop.id, shop.typeConfig)
        if seeded and WSShops.FetchInventory then
            WSShops.FetchInventory(shop)
        end
        total = total + 1
    end
    Utils.Debug('Loaded %s shops into cache', total)
    if WSShops.BroadcastShopCache then
        WSShops.BroadcastShopCache()
    end
end

function WSShops.DB.Refresh(identifier)
    local row = MySQL.single.await('SELECT * FROM ws_shops WHERE identifier = ?', { identifier })
    if not row then return end
    local shop = BuildShop(row)
    CacheShop(shop)
    return shop
end

function WSShops.GetByIdentifier(identifier)
    return Cache.ShopsByIdentifier[identifier]
end

function WSShops.GetById(id)
    return Cache.ShopsById[id]
end

function WSShops.UpdateCache(shop)
    if not shop or not shop.id then return end
    CacheShop(shop)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(1500)
        WSShops.DB.LoadAll()
    end)
end)

RegisterNetEvent('ws-shopsystem:server:requestShopCache', function()
    local src = source
    if WSShops.BroadcastShopCache then
        WSShops.BroadcastShopCache(src)
    end
end)
