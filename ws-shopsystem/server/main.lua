local QBCore = exports['qb-core']:GetCoreObject()
local Config = WSShopConfig
local Utils = WSShops.Utils

local AdminAccess = {
    qbPermissions = {},
    aceGroups = {},
    identifiers = {},
    citizenIds = {},
}

local function BuildAdminAccess()
    AdminAccess.qbPermissions = {}
    AdminAccess.aceGroups = {}
    AdminAccess.identifiers = {}
    AdminAccess.citizenIds = {}

    local cfg = Config.AdminAccess or {}

    local function ingestList(list, asSet, transform, target)
        if type(list) ~= 'table' then return end
        transform = transform or function(value) return value end
        local seen = {}

        local function addValue(value)
            if asSet then
                target[value] = true
            else
                if not seen[value] then
                    target[#target + 1] = value
                    seen[value] = true
                end
            end
        end

        for _, value in ipairs(list) do
            if type(value) == 'string' then
                local normalized = transform(value)
                addValue(normalized)
            end
        end

        for key, value in pairs(list) do
            if type(key) == 'string' then
                local shouldInclude = value
                if type(value) == 'boolean' then
                    shouldInclude = value
                elseif type(value) == 'number' then
                    shouldInclude = value ~= 0
                elseif type(value) == 'string' then
                    shouldInclude = true
                end

                if shouldInclude then
                    local normalized = transform(key)
                    addValue(normalized)
                end
            elseif type(value) == 'string' then
                local normalized = transform(value)
                addValue(normalized)
            end
        end
    end

    ingestList(cfg.QBPermissions, false, function(value) return value end, AdminAccess.qbPermissions)
    ingestList(cfg.AceGroups, false, function(value) return value end, AdminAccess.aceGroups)
    ingestList(cfg.Identifiers, true, function(value) return value:lower() end, AdminAccess.identifiers)
    ingestList(cfg.CitizenIds, true, function(value) return value:upper() end, AdminAccess.citizenIds)

    if #AdminAccess.qbPermissions == 0 and cfg.QBPermissions == nil then
        AdminAccess.qbPermissions = { 'god', 'admin' }
    end
end

BuildAdminAccess()

local function GetShop(identifier)
    local shop = WSShops.GetByIdentifier(identifier)
    if not shop then
        shop = WSShops.DB.Refresh(identifier)
    end
    return shop
end

local function GetShopById(id)
    local shop = WSShops.GetById(id)
    if not shop then
        shop = WSShops.DB.Refresh(id)
    end
    return shop
end

local function CommitShopOwner(shop, citizenid, name)
    shop.owner = citizenid
    shop.ownerName = name
    WSShops.UpdateCache(shop)
    MySQL.update.await('UPDATE ws_shops SET owner_citizenid = ?, owner_name = ?, updated_at = NOW() WHERE id = ?', {
        citizenid,
        name,
        shop.id,
    })
end

local function ResetShopOwner(shop)
    shop.owner = nil
    shop.ownerName = nil
    WSShops.UpdateCache(shop)
    MySQL.update.await('UPDATE ws_shops SET owner_citizenid = NULL, owner_name = NULL, updated_at = NOW() WHERE id = ?', {
        shop.id,
    })
end

local SanitizeForClient -- forward declaration

local function EncodeForJson(value)
    if value == nil then return nil end
    local sanitized = value
    if SanitizeForClient then
        sanitized = SanitizeForClient(value)
    end
    local ok, encoded = pcall(json.encode, sanitized)
    if not ok then
        return nil, encoded
    end
    return encoded, nil
end

WSShops.EncodeForJson = EncodeForJson

local function SaveMetadata(shop)
    if not shop.metadata then return end
    local encoded, err = EncodeForJson(shop.metadata)
    if not encoded then
        Utils.Debug('Failed to encode metadata for shop %s: %s', shop.identifier or '?', err or 'unknown')
        return
    end
    MySQL.update.await('UPDATE ws_shops SET metadata = ?, updated_at = NOW() WHERE id = ?', {
        encoded,
        shop.id,
    })
end

local function EncodeCoords(value)
    if type(value) == 'table' and value.x then
        return json.encode(value)
    end
    if type(value) == 'vector3' or type(value) == 'vector4' then
        return json.encode({ x = value.x, y = value.y, z = value.z, w = value.w })
    end
    return value
end

local function Trim(value)
    if not value then return nil end
    local trimmed = tostring(value):match('^%s*(.-)%s*$')
    if trimmed == '' then return nil end
    return trimmed
end

local function NormalizeIdentifier(value)
    local trimmed = Trim(value)
    if not trimmed then return nil end
    trimmed = trimmed:lower():gsub('%s+', '_')
    trimmed = trimmed:gsub('[^%w_]', '')
    trimmed = trimmed:gsub('_+', '_')
    trimmed = trimmed:gsub('^_', ''):gsub('_$', '')
    if trimmed == '' then return nil end
    return trimmed
end

local function SanitizePointList(list, includeHeading)
    local result = {}
    if type(list) ~= 'table' then return result end
    for _, entry in ipairs(list) do
        local px = tonumber(entry.x)
        local py = tonumber(entry.y)
        local pz = tonumber(entry.z)
        if px and py and pz then
            local point = { x = px, y = py, z = pz }
            local label = Trim(entry.label)
            if label then
                point.label = label
            end
            if includeHeading then
                point.heading = tonumber(entry.heading) or 0.0
            end
            result[#result + 1] = point
        end
    end
    return result
end

local function SanitizeRoutes(routes)
    local result = {}
    if type(routes) ~= 'table' then return result end
    for _, entry in ipairs(routes) do
        local points = {}
        if type(entry.points) == 'table' then
            for _, point in ipairs(entry.points) do
                local px = tonumber(point.x)
                local py = tonumber(point.y)
                local pz = tonumber(point.z)
                if px and py and pz then
                    local routePoint = { x = px, y = py, z = pz }
                    local label = Trim(point.label)
                    if label then
                        routePoint.label = label
                    end
                    points[#points + 1] = routePoint
                end
            end
        end
        if #points > 0 then
            local label = Trim(entry.label)
            result[#result + 1] = {
                label = label,
                points = points,
            }
        end
    end
    return result
end

local function SanitizeBlip(blipPayload, defaultLabel)
    if type(blipPayload) ~= 'table' then return nil end

    local enabled = blipPayload.enabled
    if enabled == nil then
        if blipPayload.sprite ~= nil or blipPayload.color ~= nil or blipPayload.scale ~= nil or blipPayload.label ~= nil then
            enabled = true
        else
            return nil
        end
    end

    if not enabled then
        return false
    end

    local spriteProvided = blipPayload.sprite ~= nil
    local sprite = tonumber(blipPayload.sprite)
    if spriteProvided then
        if not sprite or sprite < 1 or sprite > 1000 then
            return nil, 'Blip-Sprite muss eine Zahl zwischen 1 und 1000 sein.'
        end
        sprite = math.floor(sprite)
    else
        sprite = 59
    end

    local colorProvided = blipPayload.color ~= nil
    local color = tonumber(blipPayload.color)
    if colorProvided then
        if not color or color < 0 or color > 85 then
            return nil, 'Blip-Farbe muss eine Zahl zwischen 0 und 85 sein.'
        end
        color = math.floor(color)
    else
        color = 1
    end

    local scaleProvided = blipPayload.scale ~= nil
    local scale = tonumber(blipPayload.scale)
    if scaleProvided then
        if not scale or scale <= 0 or scale > 2.5 then
            return nil, 'Blip-Skalierung muss zwischen 0.1 und 2.5 liegen.'
        end
        scale = math.floor(scale * 100) / 100
        if scale < 0.1 then scale = 0.1 end
    else
        scale = 0.8
    end

    local label = Trim(blipPayload.label)
    if label then
        if #label > 60 then
            label = label:sub(1, 60)
        end
    else
        label = defaultLabel or 'Shop'
    end

    local shortRange = blipPayload.shortRange ~= false

    return {
        sprite = sprite,
        color = color,
        scale = scale,
        label = label,
        shortRange = shortRange,
    }
end

local function SanitizeVehicles(list)
    local sanitized = {}
    if type(list) ~= 'table' then return sanitized end

    local seen = {}
    for _, entry in ipairs(list) do
        local entryType = type(entry)
        local key
        local model
        local label
        local price = 0
        local minLevel = 1
        local capacity = 0
        local trunk = 0
        local fuelModifier = 1.0

        if entryType == 'string' then
            key = NormalizeIdentifier(entry)
            model = Trim(entry)
            label = Trim(entry)
        elseif entryType == 'table' then
            key = entry.key or entry.vehicle_key or entry.model or entry.label or entry.name
            key = NormalizeIdentifier(key)
            model = Trim(entry.model) or Trim(entry.spawn) or Trim(entry.vehicle) or Trim(entry.modelName) or Trim(entry.vehicleModel)
            label = Trim(entry.label) or Trim(entry.name)
            price = tonumber(entry.price or entry.cost) or 0
            minLevel = tonumber(entry.minLevel or entry.min_level or entry.level) or 1
            capacity = tonumber(entry.capacity or entry.cargo or entry.maxCapacity) or 0
            trunk = tonumber(entry.trunk or entry.trunk_size or entry.trunkInventory) or 0
            fuelModifier = tonumber(entry.fuelModifier or entry.fuel_modifier) or 1.0
        end

        if key then
            model = model and Trim(model) or key
            label = label and Trim(label) or model
            price = math.max(0, math.floor(tonumber(price) or 0))
            minLevel = math.max(1, math.floor(tonumber(minLevel) or 1))
            capacity = math.max(0, math.floor(tonumber(capacity) or 0))
            trunk = math.max(0, math.floor(tonumber(trunk) or 0))
            local fuel = tonumber(fuelModifier) or 1.0
            if fuel <= 0 then fuel = 1.0 end

            if not seen[key] then
                sanitized[#sanitized + 1] = {
                    key = key,
                    model = model,
                    label = label,
                    price = price,
                    minLevel = minLevel,
                    capacity = capacity,
                    trunk = trunk,
                    fuelModifier = fuel,
                }
                seen[key] = true
            end
        end
    end

    return sanitized
end

local function BuildVehicleMap(list, alreadySanitized)
    local entries = alreadySanitized and (list or {}) or SanitizeVehicles(list)
    local map = {}
    for _, vehicle in ipairs(entries) do
        if type(vehicle) == 'table' and vehicle.key then
            map[vehicle.key] = {
                key = vehicle.key,
                model = vehicle.model or vehicle.key,
                label = vehicle.label or vehicle.model or vehicle.key,
                price = math.max(0, math.floor(tonumber(vehicle.price) or 0)),
                minLevel = math.max(1, math.floor(tonumber(vehicle.minLevel or vehicle.min_level) or 1)),
                capacity = math.max(0, math.floor(tonumber(vehicle.capacity) or 0)),
                trunk = math.max(0, math.floor(tonumber(vehicle.trunk or vehicle.trunk_size) or 0)),
                fuelModifier = tonumber(vehicle.fuelModifier or vehicle.fuel_modifier) or 1.0,
            }
        end
    end
    return map
end

WSShops = WSShops or {}
WSShops.SanitizeVehicles = SanitizeVehicles
WSShops.BuildVehicleMap = function(list)
    return BuildVehicleMap(list, false)
end

local function GetVehicleMap(shop)
    if not shop then return {} end
    shop.metadata = shop.metadata or {}
    local creator = shop.metadata.creator or {}

    if creator.vehicleMap and next(creator.vehicleMap) then
        return creator.vehicleMap
    end

    local vehicles = creator.vehicles
    if type(vehicles) ~= 'table' or #vehicles == 0 then
        vehicles = {}
        if shop.id then
            local rows = MySQL.query.await([[SELECT vehicle_key, model, label, price, min_level, capacity, trunk_size, fuel_modifier
                FROM ws_shop_allowed_vehicles WHERE shop_id = ? ORDER BY sort_index ASC, id ASC
            ]], { shop.id }) or {}
            for _, row in ipairs(rows) do
                vehicles[#vehicles + 1] = {
                    key = row.vehicle_key,
                    model = row.model,
                    label = row.label,
                    price = row.price,
                    minLevel = row.min_level,
                    capacity = row.capacity,
                    trunk = row.trunk_size,
                    fuelModifier = row.fuel_modifier,
                }
            end
        end
    end

    vehicles = SanitizeVehicles(vehicles)
    creator.vehicles = vehicles
    creator.vehicleMap = BuildVehicleMap(vehicles, true)

    shop.metadata.creator = creator
    shop.metadata.vehicleMap = creator.vehicleMap
    return creator.vehicleMap or {}
end

local function GetVehicleConfig(shop, key)
    if not shop or not key then return nil end
    local map = GetVehicleMap(shop)
    return map[key]
end

WSShops.GetVehicleMap = GetVehicleMap
WSShops.GetVehicleConfig = GetVehicleConfig

local function PersistDropoffs(shopId, dropoffs)
    local ok, err = pcall(function()
        MySQL.update.await('DELETE FROM ws_shop_dropoffs WHERE shop_id = ?', { shopId })
        for index, point in ipairs(dropoffs or {}) do
            MySQL.insert.await('INSERT INTO ws_shop_dropoffs (shop_id, sort_index, label, x, y, z) VALUES (?, ?, ?, ?, ?, ?)', {
                shopId,
                index,
                Trim(point.label),
                tonumber(point.x) or 0.0,
                tonumber(point.y) or 0.0,
                tonumber(point.z) or 0.0,
            })
        end
    end)
    if not ok then return false, err end
    return true
end

local function PersistDepots(shopId, depots)
    local ok, err = pcall(function()
        MySQL.update.await('DELETE FROM ws_shop_depots WHERE shop_id = ?', { shopId })
        for index, point in ipairs(depots or {}) do
            MySQL.insert.await('INSERT INTO ws_shop_depots (shop_id, sort_index, label, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                shopId,
                index,
                Trim(point.label),
                tonumber(point.x) or 0.0,
                tonumber(point.y) or 0.0,
                tonumber(point.z) or 0.0,
                tonumber(point.heading) or 0.0,
            })
        end
    end)
    if not ok then return false, err end
    return true
end

local function PersistVehicleSpawns(shopId, spawns)
    local ok, err = pcall(function()
        MySQL.update.await('DELETE FROM ws_shop_vehicle_spawns WHERE shop_id = ?', { shopId })
        for index, point in ipairs(spawns or {}) do
            MySQL.insert.await('INSERT INTO ws_shop_vehicle_spawns (shop_id, sort_index, label, x, y, z, heading) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                shopId,
                index,
                Trim(point.label),
                tonumber(point.x) or 0.0,
                tonumber(point.y) or 0.0,
                tonumber(point.z) or 0.0,
                tonumber(point.heading) or 0.0,
            })
        end
    end)
    if not ok then return false, err end
    return true
end

local function PersistRoutes(shopId, routes)
    local ok, err = pcall(function()
        local existing = MySQL.query.await('SELECT id FROM ws_shop_routes WHERE shop_id = ?', { shopId }) or {}
        for _, row in ipairs(existing) do
            MySQL.update.await('DELETE FROM ws_shop_route_points WHERE route_id = ?', { row.id })
        end
        MySQL.update.await('DELETE FROM ws_shop_routes WHERE shop_id = ?', { shopId })

        for index, route in ipairs(routes or {}) do
            local routeId = MySQL.insert.await('INSERT INTO ws_shop_routes (shop_id, sort_index, label) VALUES (?, ?, ?)', {
                shopId,
                index,
                Trim(route.label),
            })
            if routeId then
                for pointIndex, point in ipairs(route.points or {}) do
                    MySQL.insert.await('INSERT INTO ws_shop_route_points (route_id, sort_index, label, x, y, z) VALUES (?, ?, ?, ?, ?, ?)', {
                        routeId,
                        pointIndex,
                        Trim(point.label),
                        tonumber(point.x) or 0.0,
                        tonumber(point.y) or 0.0,
                        tonumber(point.z) or 0.0,
                    })
                end
            end
        end
    end)
    if not ok then return false, err end
    return true
end

local function PersistAllowedVehicles(shopId, vehicles)
    local sanitized = SanitizeVehicles(vehicles)
    local ok, err = pcall(function()
        MySQL.update.await('DELETE FROM ws_shop_allowed_vehicles WHERE shop_id = ?', { shopId })
        for index, vehicle in ipairs(sanitized) do
            MySQL.insert.await([[INSERT INTO ws_shop_allowed_vehicles
                (shop_id, sort_index, vehicle_key, model, label, price, min_level, capacity, trunk_size, fuel_modifier)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                shopId,
                index,
                vehicle.key,
                vehicle.model,
                vehicle.label,
                vehicle.price,
                vehicle.minLevel,
                vehicle.capacity,
                vehicle.trunk,
                vehicle.fuelModifier,
            })
        end
    end)
    if not ok then return false, err end
    return true, nil, sanitized
end

local function PersistProductCategories(shopId, categories)
    local ok, err = pcall(function()
        MySQL.update.await('DELETE FROM ws_shop_product_categories WHERE shop_id = ?', { shopId })
        for index, category in ipairs(categories or {}) do
            local trimmed = Trim(category)
            if trimmed then
                MySQL.insert.await('INSERT INTO ws_shop_product_categories (shop_id, sort_index, category) VALUES (?, ?, ?)', {
                    shopId,
                    index,
                    trimmed,
                })
            end
        end
    end)
    if not ok then return false, err end
    return true
end

local function PersistCreatorData(shopId, creator)
    if not shopId or not creator then return true end
    local ok, err = PersistDropoffs(shopId, creator.dropoffs)
    if not ok then return false, err end
    ok, err = PersistDepots(shopId, creator.depots)
    if not ok then return false, err end
    ok, err = PersistVehicleSpawns(shopId, creator.vehicleSpawns)
    if not ok then return false, err end
    ok, err = PersistRoutes(shopId, creator.routes)
    if not ok then return false, err end
    local sanitizedVehicles
    ok, err, sanitizedVehicles = PersistAllowedVehicles(shopId, creator.vehicles)
    if not ok then return false, err end
    creator.vehicles = sanitizedVehicles or {}
    ok, err = PersistProductCategories(shopId, creator.products)
    if not ok then return false, err end
    return true
end

local function SyncInventoryRecords(shop, payloadInventory)
    if not shop or type(payloadInventory) ~= 'table' then return end
    local existingRows = MySQL.query.await('SELECT id FROM ws_shop_inventory WHERE shop_id = ?', { shop.id }) or {}
    local existingSet = {}
    for _, row in ipairs(existingRows) do
        existingSet[row.id] = true
    end

    local kept = {}
    for _, entry in ipairs(payloadInventory) do
        local itemName = Trim(entry.item)
        local label = Trim(entry.label)
        local category = Trim(entry.category)
        if itemName and label and category then
            local quantity = math.max(0, math.floor(tonumber(entry.quantity) or 0))
            local basePrice = math.max(0, math.floor(tonumber(entry.basePrice) or 0))
            local overridePrice = tonumber(entry.overridePrice)
            if overridePrice then
                overridePrice = math.max(0, math.floor(overridePrice))
            else
                overridePrice = basePrice
            end
            local minLevel = math.max(1, math.floor(tonumber(entry.minLevel) or 1))
            local discount = math.max(0, math.floor(tonumber(entry.discount) or 0))
            local icon = Trim(entry.icon)
            local id = tonumber(entry.id)

            if id and existingSet[id] then
                MySQL.update.await('UPDATE ws_shop_inventory SET item = ?, label = ?, icon = ?, category = ?, quantity = ?, base_price = ?, override_price = ?, min_level = ?, discount = ?, updated_at = NOW() WHERE id = ? AND shop_id = ?', {
                    itemName,
                    label,
                    icon,
                    category,
                    quantity,
                    basePrice,
                    overridePrice,
                    minLevel,
                    discount,
                    id,
                    shop.id,
                })
                kept[id] = true
            else
                local newId = MySQL.insert.await('INSERT INTO ws_shop_inventory (shop_id, item, label, icon, category, quantity, base_price, override_price, min_level, discount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
                    shop.id,
                    itemName,
                    label,
                    icon,
                    category,
                    quantity,
                    basePrice,
                    overridePrice,
                    minLevel,
                    discount,
                })
                if newId then
                    kept[newId] = true
                end
            end
        end
    end

    for id in pairs(existingSet) do
        if not kept[id] then
            MySQL.update.await('DELETE FROM ws_shop_inventory WHERE id = ? AND shop_id = ?', { id, shop.id })
        end
    end
end

local function CreateShopFromPayload(payload, src, suppressNotify)
    local function notify(message, nType)
        if suppressNotify then return end
        Utils.Notify(src, message, nType or 'error')
    end
    local identifier = NormalizeIdentifier(payload.identifier)
    if not identifier then
        notify('Ungültige Shop-ID.', 'error')
        return nil, 'invalid_identifier'
    end

    if GetShop(identifier) or MySQL.single.await('SELECT id FROM ws_shops WHERE identifier = ?', { identifier }) then
        notify('Ein Shop mit dieser ID existiert bereits.', 'error')
        return nil, 'duplicate'
    end

    local typeKey = payload.type
    if not typeKey or not Config.ShopTypes[typeKey] then
        notify('Ungültiger Shop-Typ.', 'error')
        return nil, 'invalid_type'
    end

    local label = Trim(payload.label) or identifier

    local coordsPayload = payload.coords or {}
    local x = tonumber(coordsPayload.x) or 0.0
    local y = tonumber(coordsPayload.y) or 0.0
    local z = tonumber(coordsPayload.z) or 0.0
    local heading = tonumber(coordsPayload.heading or coordsPayload.w) or 0.0

    local purchasePrice = tonumber(payload.purchasePrice) or (Config.ShopTypes[typeKey] and Config.ShopTypes[typeKey].purchasePrice) or 0
    if purchasePrice < 0 then purchasePrice = 0 end
    local sellPrice = tonumber(payload.sellPrice) or (Config.ShopTypes[typeKey] and Config.ShopTypes[typeKey].sellPrice) or 0
    if sellPrice < 0 then sellPrice = 0 end

    local metadata = {
        creator = {
            coords = { x = x, y = y, z = z, w = heading },
            heading = heading,
            ped = type(payload.ped) == 'table' and {
                model = Trim(payload.ped.model),
                scenario = Trim(payload.ped.scenario),
            } or nil,
            zone = type(payload.zone) == 'table' and {
                length = tonumber(payload.zone.length) or 2.0,
                width = tonumber(payload.zone.width) or 2.0,
                minZ = tonumber(payload.zone.minZ) or (z - 1.0),
                maxZ = tonumber(payload.zone.maxZ) or (z + 1.0),
            } or nil,
            dropoffs = SanitizePointList(payload.dropoffs, false),
            depots = SanitizePointList(payload.depots, true),
            vehicles = {},
            products = {},
            vehicleSpawns = SanitizePointList(payload.vehicleSpawns, true),
            routes = SanitizeRoutes(payload.routes),
            purchasePrice = purchasePrice,
            sellPrice = sellPrice,
        },
    }

    metadata.creator.vehicles = SanitizeVehicles(payload.vehicles)
    metadata.creator.vehicleMap = BuildVehicleMap(metadata.creator.vehicles, true)
    metadata.vehicleMap = metadata.creator.vehicleMap

    if type(payload.products) == 'table' then
        local seen = {}
        for _, category in ipairs(payload.products) do
            if type(category) == 'string' then
                local trimmed = Trim(category)
                if trimmed and not seen[trimmed] then
                    metadata.creator.products[#metadata.creator.products + 1] = trimmed
                    seen[trimmed] = true
                end
            end
        end
    end

    local pedModel = metadata.creator.ped and Trim(metadata.creator.ped.model)
    local pedScenario = metadata.creator.ped and Trim(metadata.creator.ped.scenario)
    local zone = metadata.creator.zone or {}
    local zoneLength = tonumber(zone.length) or 2.0
    local zoneWidth = tonumber(zone.width) or 2.0
    local zoneMinZ = tonumber(zone.minZ) or (z - 1.0)
    local zoneMaxZ = tonumber(zone.maxZ) or (z + 1.0)

    local metadataJson, metadataErr = EncodeForJson(metadata)
    if not metadataJson then
        Utils.Debug('Failed to encode metadata for new shop %s: %s', identifier, metadataErr or 'unknown')
        notify('Shop konnte nicht erstellt werden (Metadatenfehler).', 'error')
        return nil, 'metadata_encode_error'
    end

    local insertOk, insertResult = pcall(function()
        return MySQL.insert.await('INSERT INTO ws_shops (identifier, label, type, coords, heading, purchase_price, sell_price, metadata, ped_model, ped_scenario, zone_length, zone_width, zone_min_z, zone_max_z) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            identifier,
            label,
            typeKey,
            EncodeCoords({ x = x, y = y, z = z, w = heading }),
            heading,
            purchasePrice,
            sellPrice,
            metadataJson,
            pedModel,
            pedScenario,
            zoneLength,
            zoneWidth,
            zoneMinZ,
            zoneMaxZ,
        })
    end)

    if not insertOk then
        Utils.Debug('Failed to create shop %s: %s', identifier, insertResult)
        notify('Shop konnte nicht erstellt werden (Datenbankfehler).', 'error')
        return nil, 'db_error'
    end

    local insertId = insertResult
    if not insertId then
        notify('Shop konnte nicht erstellt werden (Datenbankfehler).', 'error')
        return nil, 'db_error'
    end

    local persisted, persistErr = PersistCreatorData(insertId, metadata.creator)
    if not persisted then
        Utils.Debug('Failed to persist creator data for new shop %s: %s', identifier, persistErr or 'unknown')
        pcall(function()
            MySQL.update.await('DELETE FROM ws_shops WHERE id = ?', { insertId })
        end)
        notify('Shop konnte nicht erstellt werden (Datenbankfehler).', 'error')
        return nil, 'db_error'
    end

    return WSShops.DB.Refresh(identifier)
end

local CreateShopErrorMessages = {
    invalid_identifier = 'Ungültige Shop-ID.',
    duplicate = 'Ein Shop mit dieser ID existiert bereits.',
    invalid_type = 'Ungültiger Shop-Typ.',
    metadata_encode_error = 'Shop konnte nicht erstellt werden (Metadatenfehler).',
    db_error = 'Shop konnte nicht erstellt werden (Datenbankfehler).',
}

local function PlayerIsAdmin(src)
    for _, permission in ipairs(AdminAccess.qbPermissions) do
        if QBCore.Functions.HasPermission(src, permission) then
            return true
        end
    end

    for _, group in ipairs(AdminAccess.aceGroups) do
        if IsPlayerAceAllowed(src, group) then
            return true
        end
    end

    if next(AdminAccess.identifiers) then
        local identifiers = GetPlayerIdentifiers(src) or {}
        for _, identifier in ipairs(identifiers) do
            if AdminAccess.identifiers[identifier:lower()] then
                return true
            end
        end
    end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    local citizenid = Player.PlayerData and Player.PlayerData.citizenid
    if citizenid and AdminAccess.citizenIds[citizenid:upper()] then
        return true
    end

    local function CheckLicenseString(value)
        if type(value) ~= 'string' then return false end
        return AdminAccess.identifiers['license:' .. value:lower()] == true
    end

    if Player.PlayerData then
        if CheckLicenseString(Player.PlayerData.license) then
            return true
        end
        local metadata = Player.PlayerData.metadata
        if metadata then
            if CheckLicenseString(metadata.licence) or CheckLicenseString(metadata.license) then
                return true
            end
        end
    end

    return false
end

local function BuildShopCachePayload()
    local payload = {}
    for identifier, shop in pairs(WSShops.Cache and WSShops.Cache.ShopsByIdentifier or {}) do
        payload[#payload + 1] = {
            identifier = identifier,
            label = shop.label,
            coords = SanitizeForClient(shop.coords),
            heading = shop.heading,
            type = shop.type,
            owner = shop.owner,
            level = shop.level,
            config = SanitizeForClient(shop.config or {}),
            metadata = SanitizeForClient(shop.metadata or {}),
        }
    end
    table.sort(payload, function(a, b)
        local aLabel = a.label or a.identifier
        local bLabel = b.label or b.identifier
        return aLabel < bLabel
    end)
    return payload
end

local function BroadcastShopCache(target)
    local payload = BuildShopCachePayload()
    TriggerClientEvent('ws-shopsystem:client:receiveShopCache', target or -1, payload)
end

WSShops.BuildShopCachePayload = BuildShopCachePayload
WSShops.BroadcastShopCache = BroadcastShopCache

local function SeedInventoryForCategories(shop, categories)
    if type(categories) ~= 'table' then return end
    local normalized = {}
    local seen = {}
    for _, value in pairs(categories) do
        if type(value) == 'string' then
            local key = value
            if not seen[key] then
                normalized[#normalized + 1] = key
                seen[key] = true
            end
        end
    end
    if #normalized == 0 then return end

    local typeConfig = Config.ShopTypes[shop.type] or {}
    if not typeConfig.baseProducts then return end

    MySQL.update.await('DELETE FROM ws_shop_inventory WHERE shop_id = ?', { shop.id })
    for _, category in ipairs(normalized) do
        local categoryConfig = typeConfig.baseProducts[category]
        if categoryConfig then
            for _, item in ipairs(categoryConfig.items or {}) do
                MySQL.insert.await([[INSERT INTO ws_shop_inventory
                    (shop_id, item, label, icon, category, quantity, base_price, override_price, min_level, discount)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ]], {
                    shop.id,
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
            end
        end
    end
    WSShops.FetchInventory(shop)
end

SanitizeForClient = function(value)
    local t = type(value)
    if t == 'vector3' then
        return { x = value.x, y = value.y, z = value.z }
    elseif t == 'vector4' then
        return { x = value.x, y = value.y, z = value.z, w = value.w }
    elseif t == 'table' then
        local result = {}
        for k, v in pairs(value) do
            result[k] = SanitizeForClient(v)
        end
        return result
    end
    return value
end

local function FetchDashboardStats(shop)
    local stats = {
        labels = {},
        sales = {},
        xp = {},
        deliveries = {},
    }
    local rows = MySQL.query.await('SELECT stat_date, sales_total, xp_earned, deliveries_completed FROM ws_shop_statistics_daily WHERE shop_id = ? ORDER BY stat_date DESC LIMIT 7', {
        shop.id,
    }) or {}

    for idx = #rows, 1, -1 do
        local row = rows[idx]
        local label = row.stat_date and tostring(row.stat_date) or ''
        if #label >= 5 then
            label = string.sub(label, 6)
        end
        stats.labels[#stats.labels + 1] = label
        stats.sales[#stats.sales + 1] = row.sales_total or 0
        stats.xp[#stats.xp + 1] = row.xp_earned or 0
        stats.deliveries[#stats.deliveries + 1] = row.deliveries_completed or 0
    end

    return stats
end

local function PrepareShopPayload(shop, options)
    options = options or {}

    local deliveryVehicles = {}
    local vehicleMap = GetVehicleMap(shop)
    for key, vehicle in pairs(vehicleMap) do
        deliveryVehicles[key] = SanitizeForClient({
            key = key,
            label = vehicle.label,
            model = vehicle.model,
            capacity = vehicle.capacity,
            minLevel = vehicle.minLevel,
            price = vehicle.price,
            trunk = vehicle.trunk,
            fuelModifier = vehicle.fuelModifier,
        })
    end

    local data = {
        id = shop.id,
        identifier = shop.identifier,
        label = shop.label,
        type = shop.type,
        coords = SanitizeForClient(shop.coords),
        heading = shop.heading,
        owner = shop.owner,
        ownerName = shop.ownerName,
        level = shop.level,
        xp = shop.xp,
        balance = shop.balance,
        purchasePrice = shop.purchasePrice,
        sellPrice = shop.sellPrice,
        discount = shop.discount,
        config = SanitizeForClient(shop.config or {}),
        typeConfig = SanitizeForClient(shop.typeConfig or {}),
        inventory = SanitizeForClient(shop.inventory or {}),
        employees = SanitizeForClient(shop.employees or {}),
        deliveries = SanitizeForClient(shop.deliveries or {}),
        deliveryVehicles = deliveryVehicles,
        roles = SanitizeForClient(Config.Roles),
        levels = SanitizeForClient(Config.Levels),
        vehicleOwnership = SanitizeForClient((shop.metadata and shop.metadata.vehicleUnlocks) or {}),
        metadata = SanitizeForClient(shop.metadata or {}),
    }
    data.deliveryCapacityBonus = Config.DeliveryCapacityBonusPerLevel or 0

    if options.includeStats then
        data.stats = FetchDashboardStats(shop)
    end
    return data
end

local function FetchVehicleTemplates()
    local templates = {}

    if WSShops.Cache and WSShops.Cache.ShopsByIdentifier then
        for _, shop in pairs(WSShops.Cache.ShopsByIdentifier) do
            local map = GetVehicleMap(shop)
            for key, vehicle in pairs(map) do
                if key and not templates[key] then
                    templates[key] = vehicle
                end
            end
        end
    end

    local rows = MySQL.query.await('SELECT vehicle_key, model, label, price, min_level, capacity, trunk_size, fuel_modifier FROM ws_shop_allowed_vehicles', {}) or {}
    for _, row in ipairs(rows) do
        local sanitized = SanitizeVehicles({
            {
                key = row.vehicle_key,
                model = row.model,
                label = row.label,
                price = row.price,
                minLevel = row.min_level,
                capacity = row.capacity,
                trunk = row.trunk_size,
                fuelModifier = row.fuel_modifier,
            },
        })
        local vehicle = sanitized[1]
        if vehicle and vehicle.key and not templates[vehicle.key] then
            templates[vehicle.key] = vehicle
        end
    end

    return templates
end

local function BuildAdminPayload()
    local shops = {}
    for identifier, shop in pairs(WSShops.Cache and WSShops.Cache.ShopsByIdentifier or {}) do
        shops[#shops + 1] = {
            identifier = identifier,
            label = shop.label,
            type = shop.type,
            owner = shop.ownerName or shop.owner,
            level = shop.level,
            balance = shop.balance,
            coords = SanitizeForClient(shop.coords),
            heading = shop.heading,
            purchasePrice = shop.purchasePrice,
            sellPrice = shop.sellPrice,
            metadata = SanitizeForClient(shop.metadata or {}),
            config = SanitizeForClient(shop.config or {}),
            typeConfig = SanitizeForClient(shop.typeConfig or {}),
            inventory = SanitizeForClient(shop.inventory or {}),
        }
    end
    table.sort(shops, function(a, b)
        return (a.label or a.identifier) < (b.label or b.identifier)
    end)

    return {
        shops = shops,
        shopTypes = SanitizeForClient(Config.ShopTypes),
        vehicleTemplates = SanitizeForClient(FetchVehicleTemplates()),
        depots = SanitizeForClient(Config.Depots),
    }
end

WSShops.BuildAdminPayload = BuildAdminPayload

local function EnsureVehicleUnlocks(shop)
    shop.metadata = shop.metadata or {}
    shop.metadata.vehicleUnlocks = shop.metadata.vehicleUnlocks or {}
    return shop.metadata.vehicleUnlocks
end

local function RecordLowStock(shop, item)
    shop.metadata = shop.metadata or {}
    shop.metadata.lowStock = shop.metadata.lowStock or {}
    local key = tostring(item.item)
    local now = os.time()
    local lastAlert = shop.metadata.lowStock[key] or 0
    if item.quantity <= (Config.LowStockThreshold or 15) then
        if now - lastAlert >= (Config.LowStockCooldown or 600) then
            shop.metadata.lowStock[key] = now
            SaveMetadata(shop)
            WSShops.NotifyOwner(shop,
                Config.Notifications.phone.subjectLowStock:format(shop.label),
                Config.Notifications.phone.messageLowStock:format(item.label, item.quantity))
            TriggerClientEvent('ws-shopsystem:client:lowStock', -1, shop.identifier, item.item, item.quantity)
        end
        if shop.owner and Config.AutoDeliveryThreshold and item.quantity <= Config.AutoDeliveryThreshold then
            if WSShops.Deliveries and WSShops.Deliveries.Create then
                local quantity = Config.DefaultRestockQuantity or 50
                local deliveryId = WSShops.Deliveries.Create(shop, shop.owner, {
                    type = 'auto',
                    items = {
                        {
                            item = item.item,
                            label = item.label,
                            quantity = quantity,
                        },
                    },
                    distance = 5.0,
                })
                if deliveryId then
                    WSShops.NotifyOwner(shop,
                        Config.Notifications.phone.subjectDelivery:format(shop.label),
                        Config.Notifications.phone.messageAutoDelivery:format(item.label, quantity))
                end
            end
        end
    else
        if shop.metadata.lowStock[key] then
            shop.metadata.lowStock[key] = nil
            SaveMetadata(shop)
        end
    end
end

function WSShops.UpdateBalance(shop, amount, reason, metadata)
    shop.balance = shop.balance + amount
    if shop.balance < 0 then shop.balance = 0 end
    WSShops.UpdateCache(shop)
    MySQL.update.await('UPDATE ws_shops SET balance = ?, updated_at = NOW() WHERE id = ?', {
        shop.balance,
        shop.id,
    })

    local financePayload
    if metadata then
        local encoded, encodeErr = EncodeForJson(metadata)
        if not encoded then
            Utils.Debug('Failed to encode finance metadata for shop %s: %s', shop.identifier or '?', encodeErr or 'unknown')
        else
            financePayload = encoded
        end
    end

    MySQL.insert.await('INSERT INTO ws_shop_finance_log (shop_id, type, amount, balance_after, description, payload) VALUES (?, ?, ?, ?, ?, ?)', {
        shop.id,
        reason or 'unknown',
        amount,
        shop.balance,
        reason,
        financePayload,
    })
end

function WSShops.UpdateInventoryQuantity(itemId, quantity)
    MySQL.update.await('UPDATE ws_shop_inventory SET quantity = ? WHERE id = ?', {
        quantity,
        itemId,
    })
end

function WSShops.FetchInventory(shop)
    local rows = MySQL.query.await('SELECT * FROM ws_shop_inventory WHERE shop_id = ?', { shop.id }) or {}
    local inventory = {}
    local typeConfig = shop.typeConfig or Config.ShopTypes[shop.type] or {}
    for _, item in ipairs(rows) do
        local category = item.category
        local categoryLabel = category
        if typeConfig.baseProducts and typeConfig.baseProducts[category] then
            categoryLabel = typeConfig.baseProducts[category].label or category
        end
        local icon = item.icon
        if (not icon or icon == '') and typeConfig.baseProducts and typeConfig.baseProducts[category] then
            for _, baseItem in ipairs(typeConfig.baseProducts[category].items or {}) do
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
            minLevel = item.min_level,
            category = category,
            discount = item.discount or 0,
        }
    end
    shop.inventory = inventory
    WSShops.UpdateCache(shop)
end

function WSShops.AddXP(shop, xp, reason)
    local oldLevel = shop.level
    shop.xp = (shop.xp or 0) + xp
    shop.level = Utils.GetLevelFromXP(shop.xp)
    MySQL.update.await('UPDATE ws_shops SET xp = ?, level = ? WHERE id = ?', {
        shop.xp,
        shop.level,
        shop.id,
    })
    if shop.level > oldLevel then
        TriggerEvent('ws-shopsystem:server:shopLevelUp', shop, oldLevel, shop.level, reason)
    end
end

function WSShops.NotifyOwner(shop, subject, message)
    if not shop.owner then return end
    if not Config.PhoneResource or Config.PhoneResource == '' then return end
    TriggerEvent(Config.PhoneResource .. ':server:sendNewMail', shop.owner, {
        sender = Config.Notifications.phone.sender,
        subject = subject,
        message = message,
    })
end

function WSShops.NotifyCitizen(citizenid, subject, message)
    if not citizenid then return end
    if not Config.PhoneResource or Config.PhoneResource == '' then return end
    TriggerEvent(Config.PhoneResource .. ':server:sendNewMail', citizenid, {
        sender = Config.Notifications.phone.sender,
        subject = subject,
        message = message,
    })
end

local function EnsureShopExists(identifier, src)
    local shop = GetShop(identifier)
    if not shop then
        Utils.Notify(src, Utils.Locale('error.shop_not_found'), 'error')
        return nil
    end
    return shop
end

WSShops = WSShops or {}

function WSShops.PlayerIsOwner(player, shop)
    return shop.owner and player.PlayerData.citizenid == shop.owner
end

function WSShops.PlayerRole(player, shop)
    if WSShops.PlayerIsOwner(player, shop) then return 'owner' end
    for _, employee in pairs(shop.employees or {}) do
        if employee.citizenid == player.PlayerData.citizenid then
            return employee.role
        end
    end
    return nil
end

function WSShops.PlayerHasRole(player, shop, allowedRoles)
    local role = WSShops.PlayerRole(player, shop)
    if not role then return false end
    for _, allowed in ipairs(allowedRoles) do
        if allowed == role then
            return true
        end
    end
    return false
end

local function PlayerCanAccessManagement(player, shop, src)
    if not shop.owner then return false end
    if WSShops.PlayerHasRole(player, shop, Config.ManagerMenuAccessRoles or {}) then
        return true
    end
    if src and QBCore.Functions.HasPermission(src, 'admin') then
        return true
    end
    return false
end

RegisterNetEvent('ws-shopsystem:server:purchaseShop', function(identifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if shop.owner then
        Utils.Notify(src, Utils.Locale('error.already_owned'), 'error')
        return
    end

    local price = shop.purchasePrice
    if not price or price <= 0 then
        price = (shop.typeConfig and shop.typeConfig.purchasePrice) or (shop.config and shop.config.purchasePrice) or 0
    end
    if price <= 0 then
        Utils.Notify(src, Utils.Locale('error.shop_not_for_sale'), 'error')
        return
    end
    shop.purchasePrice = price

    if not Player.Functions.RemoveMoney(Config.BankingAccount, price, 'ws-shopsystem-purchase') then
        Utils.Notify(src, Utils.Locale('error.insufficient_funds'), 'error')
        return
    end

    CommitShopOwner(shop, Player.PlayerData.citizenid, ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname))

    Utils.Notify(src, Utils.Locale('success.shop_purchased', shop.label), 'success', 8000)
    WSShops.AddXP(shop, Config.XP.Sale, 'shop_purchase')
    TriggerClientEvent('ws-shopsystem:client:shopUpdated', -1, shop.identifier, {
        owner = shop.owner,
        ownerName = shop.ownerName,
        level = shop.level,
    })
end)

RegisterNetEvent('ws-shopsystem:server:sellShop', function(identifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerIsOwner(Player, shop) then
        Utils.Notify(src, Utils.Locale('error.not_owner'), 'error')
        return
    end

    local payout = shop.sellPrice or math.floor((shop.purchasePrice or 0) * 0.7)
    ResetShopOwner(shop)
    Player.Functions.AddMoney(Config.BankingAccount, payout, 'ws-shopsystem-sell')

    Utils.Notify(src, Utils.Locale('success.shop_sold', payout), 'success')
    TriggerClientEvent('ws-shopsystem:client:shopUpdated', -1, shop.identifier, {
        owner = shop.owner,
        ownerName = shop.ownerName,
        level = shop.level,
    })
end)

RegisterNetEvent('ws-shopsystem:server:openShop', function(identifier, options)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    WSShops.FetchInventory(shop)
    local payload = PrepareShopPayload(shop, { includeStats = true })
    local canManage = PlayerCanAccessManagement(Player, shop, src)
    TriggerClientEvent('ws-shopsystem:client:openShop', src, payload, {
        role = WSShops.PlayerRole(Player, shop),
        isOwner = WSShops.PlayerIsOwner(Player, shop),
        isAdmin = QBCore.Functions.HasPermission(src, 'admin'),
        canManage = canManage,
        citizenid = Player.PlayerData.citizenid,
    })
end)

RegisterNetEvent('ws-shopsystem:server:purchaseItems', function(identifier, cart, payWith)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    WSShops.FetchInventory(shop)

    local total = 0
    local itemsToGive = {}
    for _, entry in ipairs(cart or {}) do
        local itemId = entry.id
        local quantity = tonumber(entry.quantity) or 0
        if quantity <= 0 then
            Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
            return
        end

        local found
        for _, category in pairs(shop.inventory) do
            for _, item in ipairs(category.items) do
                if item.id == itemId then
                    found = item
                    break
                end
            end
            if found then break end
        end

        if not found then
            Utils.Notify(src, Utils.Locale('error.shop_not_found'), 'error')
            return
        end

        if found.quantity < quantity then
            Utils.Notify(src, Utils.Locale('error.stock_empty'), 'error')
            return
        end

        local unitPrice = found.overridePrice or found.basePrice or 0
        local itemDiscount = tonumber(found.discount) or 0
        local effectiveDiscount = itemDiscount > 0 and itemDiscount or (shop.discount or 0)
        if effectiveDiscount > 0 then
            unitPrice = math.max(0, math.floor(unitPrice * (100 - effectiveDiscount) / 100))
        end
        total = total + unitPrice * quantity
        found.quantity = found.quantity - quantity
        WSShops.UpdateInventoryQuantity(found.id, found.quantity)
        RecordLowStock(shop, found)
        itemsToGive[#itemsToGive + 1] = { item = found.item, amount = quantity }
    end

    if total <= 0 then
        Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
        return
    end

    local account = payWith or Config.BankingAccount
    if account == 'cash' then
        if not Player.Functions.RemoveMoney('cash', total, 'ws-shop-purchase') then
            Utils.Notify(src, Utils.Locale('error.insufficient_funds'), 'error')
            return
        end
    elseif account == 'crypto' then
        if not exports['qb-crypto'] or not exports['qb-crypto']:RemoveCrypto(src, total) then
            Utils.Notify(src, Utils.Locale('error.insufficient_funds'), 'error')
            return
        end
    else
        if not Player.Functions.RemoveMoney(Config.BankingAccount, total, 'ws-shop-purchase') then
            Utils.Notify(src, Utils.Locale('error.insufficient_funds'), 'error')
            return
        end
    end

    for _, item in ipairs(itemsToGive) do
        if not Player.Functions.AddItem(item.item, item.amount) then
            Utils.Notify(src, Utils.Locale('error.inventory_full'), 'error')
        end
    end

    WSShops.UpdateBalance(shop, total, 'sale', {
        customer = Player.PlayerData.citizenid,
        items = cart,
    })

    if WSShops.Finance and WSShops.Finance.RecordSale then
        WSShops.Finance.RecordSale(shop, total)
    end

    WSShops.AddXP(shop, Config.XP.Sale, 'sale')

    TriggerClientEvent('ws-shopsystem:client:purchaseSuccess', src, total)
    TriggerClientEvent('ws-shopsystem:client:inventoryUpdated', -1, shop.identifier)

    if shop.owner then
        WSShops.NotifyOwner(shop,
            Config.Notifications.phone.subjectFinance:format(shop.label),
            ('Es gab einen Verkauf im Wert von $%s.'):format(total))
    end
end)

RegisterNetEvent('ws-shopsystem:server:setPrice', function(identifier, itemId, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.DiscountAccessRoles) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    local inventoryRow = MySQL.single.await('SELECT * FROM ws_shop_inventory WHERE id = ? AND shop_id = ?', { itemId, shop.id })
    if not inventoryRow then
        Utils.Notify(src, Utils.Locale('error.shop_not_found'), 'error')
        return
    end

    MySQL.update.await('UPDATE ws_shop_inventory SET override_price = ? WHERE id = ?', { price, itemId })
    WSShops.FetchInventory(shop)
    TriggerClientEvent('ws-shopsystem:client:inventoryUpdated', -1, shop.identifier)
    Utils.Notify(src, Utils.Locale('success.price_updated'), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:setItemDiscount', function(identifier, itemId, discount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.DiscountAccessRoles) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    local inventoryRow = MySQL.single.await('SELECT id FROM ws_shop_inventory WHERE id = ? AND shop_id = ?', { itemId, shop.id })
    if not inventoryRow then
        Utils.Notify(src, Utils.Locale('error.shop_not_found'), 'error')
        return
    end

    discount = tonumber(discount) or 0
    discount = math.max(0, math.min(50, math.floor(discount)))

    MySQL.update.await('UPDATE ws_shop_inventory SET discount = ? WHERE id = ?', { discount, itemId })
    WSShops.FetchInventory(shop)
    TriggerClientEvent('ws-shopsystem:client:inventoryUpdated', -1, shop.identifier)
    Utils.Notify(src, Utils.Locale('success.discount_updated'), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:setDiscount', function(identifier, discount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.DiscountAccessRoles) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    discount = math.max(0, math.min(50, math.floor(discount)))
    shop.discount = discount
    WSShops.UpdateCache(shop)
    MySQL.update.await('UPDATE ws_shops SET discount = ? WHERE id = ?', { discount, shop.id })

    Utils.Notify(src, Utils.Locale('success.discount_updated'), 'success')
    TriggerClientEvent('ws-shopsystem:client:shopUpdated', -1, shop.identifier, {
        discount = discount,
    })
end)

RegisterNetEvent('ws-shopsystem:server:unlockVehicle', function(identifier, vehicleKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not PlayerCanAccessManagement(Player, shop, src) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    if type(vehicleKey) ~= 'string' or vehicleKey == '' then
        Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
        return
    end

    local vehicleConfig = GetVehicleConfig(shop, vehicleKey)
    if not vehicleConfig then
        Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
        return
    end

    local requiredLevel = vehicleConfig.minLevel or 1
    if (shop.level or 1) < requiredLevel then
        Utils.Notify(src, ('Benötigt Shop Level %s.'):format(requiredLevel), 'error')
        return
    end

    local ownership = EnsureVehicleUnlocks(shop)
    if ownership[vehicleKey] and ownership[vehicleKey].unlocked then
        Utils.Notify(src, 'Fahrzeug bereits freigeschaltet.', 'primary')
        return
    end

    local price = vehicleConfig.price or 0
    if price > 0 then
        if (shop.balance or 0) < price then
            Utils.Notify(src, Utils.Locale('error.insufficient_funds'), 'error')
            return
        end
        WSShops.UpdateBalance(shop, -price, 'vehicle_purchase', {
            citizenid = Player.PlayerData.citizenid,
            vehicle = vehicleKey,
        })
    end

    ownership[vehicleKey] = {
        unlocked = true,
        purchasedAt = os.time(),
        by = Player.PlayerData.citizenid,
    }
    WSShops.UpdateCache(shop)
    SaveMetadata(shop)

    Utils.Notify(src, ('%s freigeschaltet.'):format(vehicleConfig.label or vehicleKey), 'success')
    TriggerClientEvent('ws-shopsystem:client:shopUpdated', -1, shop.identifier, {
        vehicleOwnership = SanitizeForClient(ownership),
    })
end)

RegisterNetEvent('ws-shopsystem:server:deposit', function(identifier, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.FinanceAccessRoles) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then
        Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
        return
    end

    if not Player.Functions.RemoveMoney(Config.BankingAccount, amount, 'ws-shop-deposit') then
        Utils.Notify(src, Utils.Locale('error.insufficient_funds'), 'error')
        return
    end

    WSShops.UpdateBalance(shop, amount, 'deposit', { citizenid = Player.PlayerData.citizenid })
    Utils.Notify(src, Utils.Locale('success.finance_deposit', amount), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:withdraw', function(identifier, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.FinanceAccessRoles) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 or amount > shop.balance then
        Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
        return
    end

    WSShops.UpdateBalance(shop, -amount, 'withdraw', { citizenid = Player.PlayerData.citizenid })
    Player.Functions.AddMoney(Config.BankingAccount, amount, 'ws-shop-withdraw')
    Utils.Notify(src, Utils.Locale('success.finance_withdraw', amount), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:hireEmployee', function(identifier, citizenid, role, wage)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, { 'owner', 'manager' }) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    local roleConfig = Config.Roles[role]
    if not roleConfig then
        Utils.Notify(src, Utils.Locale('error.invalid_amount'), 'error')
        return
    end

    local targetPlayer = Utils.GetPlayerByCitizenId(citizenid)
    local name = targetPlayer and ('%s %s'):format(targetPlayer.PlayerData.charinfo.firstname, targetPlayer.PlayerData.charinfo.lastname) or citizenid

    MySQL.insert.await('INSERT INTO ws_shop_employees (shop_id, citizenid, name, role, wage) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE role = VALUES(role), wage = VALUES(wage), status = "active"', {
        shop.id,
        citizenid,
        name,
        role,
        wage or roleConfig.wage or 0,
    })

    WSShops.FetchInventory(shop)
    shop.employees = MySQL.query.await('SELECT * FROM ws_shop_employees WHERE shop_id = ?', { shop.id }) or {}
    WSShops.UpdateCache(shop)

    Utils.Notify(src, Utils.Locale('success.employee_hired', name), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:fireEmployee', function(identifier, citizenid)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, { 'owner', 'manager' }) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    MySQL.update.await('UPDATE ws_shop_employees SET status = "terminated" WHERE shop_id = ? AND citizenid = ?', { shop.id, citizenid })
    shop.employees = MySQL.query.await('SELECT * FROM ws_shop_employees WHERE shop_id = ?', { shop.id }) or {}
    WSShops.UpdateCache(shop)

    Utils.Notify(src, Utils.Locale('success.employee_fired', citizenid), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:openManagement', function(identifier)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not shop.owner then
        Utils.Notify(src, Utils.Locale('error.shop_unowned'), 'error')
        return
    end

    if not PlayerCanAccessManagement(Player, shop, src) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    WSShops.FetchInventory(shop)
    local payload = PrepareShopPayload(shop)

    TriggerClientEvent('ws-shopsystem:client:openManagement', src, payload, {
        role = WSShops.PlayerRole(Player, shop),
        isOwner = WSShops.PlayerIsOwner(Player, shop),
        isAdmin = QBCore.Functions.HasPermission(src, 'admin'),
        canManage = true,
        citizenid = Player.PlayerData.citizenid,
    })
end)

RegisterNetEvent('ws-shopsystem:server:createDelivery', function(identifier, payload)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.DeliveryAccessRoles or {}) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    if not WSShops.Deliveries or not WSShops.Deliveries.Create then
        Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        return
    end

    local deliveryId, err = WSShops.Deliveries.Create(shop, Player.PlayerData.citizenid, payload or {})
    if not deliveryId then
        if err == 'capacity' then
            Utils.Notify(src, Utils.Locale('error.delivery_capacity'), 'error')
        elseif err == 'vehicle' then
            Utils.Notify(src, Utils.Locale('error.delivery_vehicle_locked'), 'error')
        else
            Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        end
        return
    end

    Utils.Notify(src, Utils.Locale('info.new_delivery'), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:startDelivery', function(identifier, deliveryIdentifier, vehicleKey, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.PlayerHasRole(Player, shop, Config.DeliveryAccessRoles or {}) then
        Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    if not WSShops.Deliveries or not WSShops.Deliveries.Start then
        Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        return
    end

    local success, reason = WSShops.Deliveries.Start(shop, Player, deliveryIdentifier, vehicleKey, plate)
    if not success then
        if reason == 'not_found' then
            Utils.Notify(src, Utils.Locale('error.shop_not_found'), 'error')
        elseif reason == 'vehicle' then
            Utils.Notify(src, Utils.Locale('error.delivery_vehicle_locked'), 'error')
        else
            Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        end
        return
    end

    Utils.Notify(src, Utils.Locale('success.delivery_started'), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:completeDelivery', function(identifier, deliveryIdentifier, duration, fuelCost)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.Deliveries or not WSShops.Deliveries.Complete then
        Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        return
    end

    local success, reason = WSShops.Deliveries.Complete(shop, Player, deliveryIdentifier, duration, fuelCost)
    if not success then
        if reason == 'forbidden' then
            Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        else
            Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        end
        return
    end

    Utils.Notify(src, Utils.Locale('success.delivery_finished'), 'success')
end)

RegisterNetEvent('ws-shopsystem:server:failDelivery', function(identifier, deliveryIdentifier, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local shop = EnsureShopExists(identifier, src)
    if not shop then return end

    if not WSShops.Deliveries or not WSShops.Deliveries.Fail then
        Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        return
    end

    local success, err = WSShops.Deliveries.Fail(shop, Player, deliveryIdentifier, reason)
    if not success then
        if err == 'forbidden' then
            Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        else
            Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
        end
        return
    end

    Utils.Notify(src, Utils.Locale('error.delivery_failed'), 'error')
end)

local function AdminSaveShopInternal(src, payload)
    if not PlayerIsAdmin(src) then
        return false, nil, 'Keine Berechtigung für diese Aktion.'
    end
    if type(payload) ~= 'table' then
        return false, nil, 'Ungültige Daten übermittelt.'
    end

    local identifier = payload.identifier
    if not identifier and payload.isNew then
        identifier = NormalizeIdentifier(payload.proposedIdentifier or payload.label)
    end
    if not identifier then
        return false, nil, 'Keine gültige Shop-ID angegeben.'
    end

    payload.identifier = identifier

    local shop = GetShop(identifier)
    if not shop then
        if payload.isNew then
            local created, reason = CreateShopFromPayload(payload, src, true)
            if not created then
                local message = CreateShopErrorMessages[reason] or 'Shop konnte nicht erstellt werden.'
                return false, nil, message
            end
            shop = created
        else
            return false, nil, 'Shop wurde nicht gefunden.'
        end
    end

    local newLabel = Trim(payload.label)
    if newLabel then
        shop.label = newLabel
    end

    if payload.type and Config.ShopTypes[payload.type] then
        shop.type = payload.type
        shop.typeConfig = Config.ShopTypes[shop.type] or {}
    end

    local coordsPayload = payload.coords or {}
    local x = tonumber(coordsPayload.x) or (shop.coords and shop.coords.x) or 0.0
    local y = tonumber(coordsPayload.y) or (shop.coords and shop.coords.y) or 0.0
    local z = tonumber(coordsPayload.z) or (shop.coords and shop.coords.z) or 0.0
    local heading = tonumber(coordsPayload.heading or coordsPayload.w) or shop.heading or 0.0

    shop.coords = vector3(x, y, z)
    shop.heading = heading

    local purchasePrice = shop.purchasePrice or 0
    if payload.purchasePrice ~= nil then
        purchasePrice = math.max(0, math.floor(tonumber(payload.purchasePrice) or 0))
        shop.purchasePrice = purchasePrice
    end

    local sellPrice = shop.sellPrice or 0
    if payload.sellPrice ~= nil then
        sellPrice = math.max(0, math.floor(tonumber(payload.sellPrice) or 0))
        shop.sellPrice = sellPrice
    end

    shop.metadata = shop.metadata or {}
    shop.metadata.creator = shop.metadata.creator or {}
    local creator = shop.metadata.creator
    creator.coords = { x = x, y = y, z = z, w = heading }
    creator.heading = heading

    if type(payload.ped) == 'table' then
        local model = Trim(payload.ped.model)
        local scenario = Trim(payload.ped.scenario)
        if model then
            creator.ped = {
                model = model,
                scenario = scenario,
            }
        else
            creator.ped = nil
        end
    end

    if type(payload.zone) == 'table' then
        creator.zone = {
            length = tonumber(payload.zone.length) or 2.0,
            width = tonumber(payload.zone.width) or 2.0,
            minZ = tonumber(payload.zone.minZ) or (z - 1.0),
            maxZ = tonumber(payload.zone.maxZ) or (z + 1.0),
        }
    end

    if type(payload.blip) == 'table' then
        local blipData, blipError = SanitizeBlip(payload.blip, shop.label or identifier)
        if blipError then
            return false, nil, blipError
        end
        if blipData == false then
            creator.blip = false
        elseif blipData then
            creator.blip = blipData
        end
    end

    creator.dropoffs = SanitizePointList(payload.dropoffs, false)
    creator.depots = SanitizePointList(payload.depots, true)
    creator.vehicleSpawns = SanitizePointList(payload.vehicleSpawns, true)
    creator.routes = SanitizeRoutes(payload.routes)

    creator.vehicles = SanitizeVehicles(payload.vehicles)

    local categorySet = {}
    if type(payload.products) == 'table' then
        creator.products = {}
        for _, category in ipairs(payload.products) do
            local trimmed = Trim(category)
            if trimmed and not categorySet[trimmed] then
                creator.products[#creator.products + 1] = trimmed
                categorySet[trimmed] = true
            end
        end
    end

    creator.purchasePrice = shop.purchasePrice or purchasePrice
    creator.sellPrice = shop.sellPrice or sellPrice

    local seededInventory = false
    if type(payload.inventory) == 'table' then
        SyncInventoryRecords(shop, payload.inventory)
        if (not creator.products or #creator.products == 0) then
            creator.products = {}
            for _, entry in ipairs(payload.inventory) do
                local cat = Trim(entry.category)
                if cat and not categorySet[cat] then
                    creator.products[#creator.products + 1] = cat
                    categorySet[cat] = true
                end
            end
        end
    elseif creator.products and #creator.products > 0 then
        SeedInventoryForCategories(shop, creator.products)
        seededInventory = true
    end

    local pedModel = creator.ped and Trim(creator.ped.model)
    local pedScenario = creator.ped and Trim(creator.ped.scenario)
    local zone = creator.zone or {}
    local zoneLength = tonumber(zone.length) or 2.0
    local zoneWidth = tonumber(zone.width) or 2.0
    local zoneMinZ = tonumber(zone.minZ) or (z - 1.0)
    local zoneMaxZ = tonumber(zone.maxZ) or (z + 1.0)

    local persisted, persistErr = PersistCreatorData(shop.id, creator)
    if not persisted then
        Utils.Debug('Failed to persist creator data for shop %s: %s', shop.identifier or '?', persistErr or 'unknown')
        return false, nil, 'Shop konnte nicht gespeichert werden (Datenbankfehler).'
    end

    creator.vehicleMap = BuildVehicleMap(creator.vehicles, true)
    shop.metadata.creator = creator
    shop.metadata.vehicleMap = creator.vehicleMap

    local metadataJson, metadataErr = EncodeForJson(shop.metadata)
    if not metadataJson then
        Utils.Debug('Failed to encode metadata for shop %s: %s', shop.identifier or '?', metadataErr or 'unknown')
        return false, nil, 'Shop konnte nicht gespeichert werden (Metadatenfehler).'
    end

    local updateOk, updateErr = pcall(function()
        MySQL.update.await('UPDATE ws_shops SET label = ?, type = ?, coords = ?, heading = ?, purchase_price = ?, sell_price = ?, metadata = ?, ped_model = ?, ped_scenario = ?, zone_length = ?, zone_width = ?, zone_min_z = ?, zone_max_z = ?, updated_at = NOW() WHERE id = ?', {
            shop.label,
            shop.type,
            EncodeCoords({ x = x, y = y, z = z, w = heading }),
            heading,
            shop.purchasePrice or purchasePrice,
            shop.sellPrice or sellPrice,
            metadataJson,
            pedModel,
            pedScenario,
            zoneLength,
            zoneWidth,
            zoneMinZ,
            zoneMaxZ,
            shop.id,
        })
    end)

    if not updateOk then
        Utils.Debug('Failed to update shop %s: %s', shop.identifier or '?', updateErr)
        return false, nil, 'Shop konnte nicht gespeichert werden (Datenbankfehler).'
    end

    shop = WSShops.DB.Refresh(shop.identifier) or shop

    if type(payload.inventory) == 'table' or seededInventory then
        WSShops.FetchInventory(shop)
    end

    BroadcastShopCache()

    TriggerClientEvent('ws-shopsystem:client:inventoryUpdated', -1, shop.identifier)

    TriggerClientEvent('ws-shopsystem:client:shopUpdated', -1, shop.identifier, {
        label = shop.label,
        metadata = SanitizeForClient(shop.metadata or {}),
        config = SanitizeForClient(shop.config or {}),
        coords = SanitizeForClient(shop.coords),
        heading = shop.heading,
    })

    return true, BuildAdminPayload(), nil
end

RegisterNetEvent('ws-shopsystem:server:adminSaveShop', function(payload)
    local src = source
    local success, adminPayload, errorMessage = AdminSaveShopInternal(src, payload)
    if not success then
        if errorMessage then
            Utils.Notify(src, errorMessage, 'error')
        end
        return
    end

    Utils.Notify(src, Utils.Locale('success.shop_saved'), 'success')
    TriggerClientEvent('ws-shopsystem:client:openAdminOverview', src, adminPayload)
end)

QBCore.Functions.CreateCallback('ws-shopsystem:server:adminSaveShop', function(source, cb, payload)
    local success, adminPayload, errorMessage = AdminSaveShopInternal(source, payload)
    if not success then
        if errorMessage then
            Utils.Notify(source, errorMessage, 'error')
        end
        cb({ success = false, message = errorMessage })
        return
    end

    Utils.Notify(source, Utils.Locale('success.shop_saved'), 'success')
    cb({ success = true, payload = adminPayload })
end)

QBCore.Functions.CreateCallback('ws-shopsystem:server:getShopData', function(source, cb, identifier)
    local shop = EnsureShopExists(identifier, source)
    if not shop then cb(nil) return end
    WSShops.FetchInventory(shop)
    cb(PrepareShopPayload(shop))
end)

AddEventHandler('ws-shopsystem:server:shopLevelUp', function(shop, fromLevel, toLevel, reason)
    Utils.Debug('Shop %s leveled from %s to %s (%s)', shop.identifier, fromLevel, toLevel, reason or 'unknown')
    WSShops.NotifyOwner(shop,
        Config.Notifications.phone.subjectFinance:format(shop.label),
        ('Gratulation! Dein Shop hat Level %s erreicht.'):format(toLevel))
    TriggerClientEvent('ws-shopsystem:client:shopUpdated', -1, shop.identifier, {
        level = toLevel,
        xp = shop.xp,
    })
end)
