local QBCore = exports['qb-core']:GetCoreObject()
local Config = WSShopConfig
local Utils = WSShops.Utils

WSShops.Deliveries = WSShops.Deliveries or {}
local Deliveries = WSShops.Deliveries

local function EncodeMetadata(data)
    if not data then return '{}' end
    local encoded, err
    if WSShops and WSShops.EncodeForJson then
        encoded, err = WSShops.EncodeForJson(data)
    else
        local ok
        ok, encoded = pcall(json.encode, data)
        if not ok then
            err = encoded
            encoded = nil
        end
    end
    if not encoded then
        Utils.Debug('Failed to encode delivery metadata: %s', err or 'unknown')
        return '{}'
    end
    return encoded
end

local function GenerateIdentifier(shop)
    local prefix = (shop.identifier or ("SHOP" .. tostring(shop.id or ''))):upper()
    local suffix = math.random(1000, 9999)
    return string.format('%s-%04d', prefix, suffix)
end

local function VecToTable(vec)
    if type(vec) == 'vector3' then
        return { x = vec.x, y = vec.y, z = vec.z }
    elseif type(vec) == 'vector4' then
        return { x = vec.x, y = vec.y, z = vec.z, w = vec.w }
    end
    return vec
end

local function TableToVec3(data)
    if not data then return nil end
    if data.x and data.y and data.z then
        return vector3(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    end
    return nil
end

local function CloneItems(items)
    local result = {}
    for _, item in ipairs(items or {}) do
        result[#result + 1] = {
            item = item.item,
            label = item.label,
            quantity = tonumber(item.quantity) or 0,
            id = item.id,
            category = item.category,
        }
    end
    return result
end

local function CalculateVehicleCapacity(shop, vehicleKey)
    local vehicleConfig = Config.DeliveryVehicles[vehicleKey]
    if not vehicleConfig then return 0 end
    local base = tonumber(vehicleConfig.capacity or 0) or 0
    local bonusPerLevel = Config.DeliveryCapacityBonusPerLevel or 0
    local level = tonumber(shop.level or 1) or 1
    if level < 1 then level = 1 end
    return base + math.max(0, level - 1) * bonusPerLevel
end

local function FindInventoryItem(shop, itemName)
    if not shop.inventory then
        WSShops.FetchInventory(shop)
    end
    for _, category in pairs(shop.inventory or {}) do
        for _, item in ipairs(category.items or {}) do
            if item.item == itemName then
                return item
            end
        end
    end
    return nil
end

local function SerializeDelivery(delivery)
    local metadata = delivery.metadata
    if metadata and type(metadata) == 'string' then
        local ok, decoded = pcall(json.decode, metadata)
        if ok and decoded then
            metadata = decoded
        end
    end
    return {
        id = delivery.id,
        identifier = delivery.identifier,
        status = delivery.status,
        vehicle_model = delivery.vehicle_model,
        vehicle_plate = delivery.vehicle_plate,
        capacity = delivery.capacity,
        distance = delivery.distance,
        payout = delivery.payout,
        penalty = delivery.penalty,
        metadata = metadata,
        items = CloneItems(delivery.items or {}),
    }
end

local function UpdateCachedDeliveries(shop)
    shop.deliveries = shop.deliveries or {}
    local rows = MySQL.query.await('SELECT * FROM ws_shop_deliveries WHERE shop_id = ? AND status IN ("pending","active")', { shop.id }) or {}
    local deliveries = {}
    for _, row in ipairs(rows) do
        row.items = MySQL.query.await('SELECT * FROM ws_shop_delivery_items WHERE delivery_id = ?', { row.id }) or {}
        deliveries[#deliveries + 1] = SerializeDelivery(row)
    end
    shop.deliveries = deliveries
    WSShops.UpdateCache(shop)
end

local function ChooseDepot(shop)
    local metadata = shop.metadata or {}
    local creator = metadata.creator or {}
    local depots = creator.depots or metadata.depots
    local list = {}
    if type(depots) == 'table' then
        for _, depot in ipairs(depots) do
            if depot and depot.x and depot.y and depot.z then
                list[#list + 1] = depot
            end
        end
    end
    if #list == 0 then
        for _, depot in ipairs(Config.Depots or {}) do
            list[#list + 1] = VecToTable(depot.coords) or depot.coords
        end
    end
    if #list == 0 then return nil end
    local choice = list[math.random(1, #list)]
    local coords = choice.coords or choice
    local heading = choice.heading or shop.heading or 0.0
    return {
        label = choice.label or 'Depot',
        coords = coords,
        heading = heading,
    }
end

local function ChooseDropoff(shop)
    local metadata = shop.metadata or {}
    local creator = metadata.creator or {}
    local dropoffs = creator.dropoffs or metadata.dropoffs
    local list = {}
    if type(dropoffs) == 'table' then
        for _, entry in ipairs(dropoffs) do
            if entry and entry.x and entry.y and entry.z then
                list[#list + 1] = entry
            end
        end
    end
    local coords
    local label = shop.label
    if #list > 0 then
        local choice = list[math.random(1, #list)]
        coords = choice.coords or choice
        label = choice.label or label
    else
        coords = VecToTable(shop.coords)
    end
    return {
        coords = coords,
        label = label,
    }
end

local function DistanceBetween(a, b)
    if not a or not b then return 0 end
    local vecA = vector3(a.x + 0.0, a.y + 0.0, a.z + 0.0)
    local vecB = vector3(b.x + 0.0, b.y + 0.0, b.z + 0.0)
    return #(vecA - vecB)
end

local function GeneratePlate()
    local charset = {}
    for i = 48, 57 do charset[#charset + 1] = string.char(i) end
    for i = 65, 90 do charset[#charset + 1] = string.char(i) end
    local plate = ''
    for i = 1, 8 do
        plate = plate .. charset[math.random(1, #charset)]
    end
    return plate
end

function Deliveries.Create(shop, citizenid, data)
    if not shop or not data then return nil end
    if not data.items or #data.items == 0 then return nil end

    local identifier = GenerateIdentifier(shop)
    local vehicleKey = data.vehicle
    local vehicleConfig = Config.DeliveryVehicles[vehicleKey]
    if not vehicleConfig then return nil end

    if shop.metadata and shop.metadata.creator and shop.metadata.creator.vehicles then
        local allowed = false
        for _, key in ipairs(shop.metadata.creator.vehicles) do
            if key == vehicleKey then
                allowed = true
                break
            end
        end
        if not allowed then
            return nil, 'vehicle'
        end
    end

    local capacity = CalculateVehicleCapacity(shop, vehicleKey)
    local totalQuantity = 0
    local items = {}

    WSShops.FetchInventory(shop)

    for _, entry in ipairs(data.items) do
        local quantity = tonumber(entry.quantity) or 0
        if quantity <= 0 then
            return nil
        end
        local inventoryItem = FindInventoryItem(shop, entry.item)
        if not inventoryItem then
            return nil
        end
        totalQuantity = totalQuantity + quantity
        items[#items + 1] = {
            item = inventoryItem.item,
            label = inventoryItem.label,
            quantity = quantity,
            id = inventoryItem.id,
            category = inventoryItem.category,
        }
    end

    if totalQuantity > capacity then
        return nil, 'capacity'
    end

    local dropoff = ChooseDropoff(shop)
    local depot = ChooseDepot(shop)
    if not depot or not depot.coords then
        depot = {
            coords = VecToTable(shop.coords),
            heading = shop.heading or 0.0,
            label = 'Depot',
        }
    end

    local distance = DistanceBetween(depot.coords, dropoff.coords)
    local payout = math.floor((Config.DeliveryBasePayout or 0) + totalQuantity * 2)
    local penalty = Config.DeliveryFailurePenalty or 0
    local metadata = {
        label = data.label or '',
        depot = depot,
        dropoff = dropoff,
        vehicle = vehicleKey,
        totalQuantity = totalQuantity,
    }

    local deliveryId = MySQL.insert.await([[INSERT INTO ws_shop_deliveries
        (shop_id, identifier, type, status, citizenid, vehicle_model, vehicle_plate, capacity, distance, payout, penalty, metadata)
        VALUES (?, ?, ?, 'pending', ?, ?, NULL, ?, ?, ?, ?, ?)
    ]], {
        shop.id,
        identifier,
        data.type or 'manual',
        citizenid,
        vehicleKey,
        nil,
        capacity,
        distance,
        payout,
        penalty,
        EncodeMetadata(metadata),
    })

    if not deliveryId then return nil end

    for _, item in ipairs(items) do
        MySQL.insert.await([[INSERT INTO ws_shop_delivery_items (delivery_id, item, label, quantity)
            VALUES (?, ?, ?, ?)
        ]], {
            deliveryId,
            item.item,
            item.label,
            item.quantity,
        })
    end

    UpdateCachedDeliveries(shop)
    TriggerClientEvent('ws-shopsystem:client:deliveriesUpdated', -1, shop.identifier)

    return identifier
end

local function FindDelivery(shop, deliveryIdentifier)
    if not shop or not deliveryIdentifier then return nil end
    shop.deliveries = shop.deliveries or {}
    for _, delivery in ipairs(shop.deliveries) do
        if delivery.identifier == deliveryIdentifier then
            return delivery
        end
    end
    return nil
end

local function UpdateDeliveryStatus(shop, delivery, status, fields)
    if not delivery then return end
    fields = fields or {}
    fields.status = status
    local query = {
        'UPDATE ws_shop_deliveries SET status = @status, updated_at = NOW()'
    }
    local params = {
        ['@status'] = status,
        ['@id'] = delivery.id,
    }
    for key, value in pairs(fields) do
        if key ~= 'status' then
            query[#query + 1] = string.format(', %s = @%s', key, key)
            params['@' .. key] = value
        end
    end
    query[#query + 1] = 'WHERE id = @id'
    MySQL.update.await(table.concat(query, ' '), params)
    UpdateCachedDeliveries(shop)
    TriggerClientEvent('ws-shopsystem:client:deliveriesUpdated', -1, shop.identifier)
end

local function SpawnVehicleForPlayer(src, model, coords, heading)
    heading = heading or 0.0
    local vehType = 'automobile'
    local vehicle = QBCore.Functions.CreateVehicle(src, model, vehType, {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = heading,
    }, false)
    if not vehicle or vehicle == 0 then
        vehicle = QBCore.Functions.SpawnVehicle(src, model, {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            w = heading,
        }, false)
    end
    if not vehicle or vehicle == 0 then return nil end
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    return vehicle
end

function Deliveries.Start(shop, player, deliveryIdentifier, vehicleKey, customPlate)
    local delivery = FindDelivery(shop, deliveryIdentifier)
    if not delivery then return false, 'not_found' end
    if delivery.status ~= 'pending' then return false, 'not_pending' end

    local depot = delivery.metadata and delivery.metadata.depot or ChooseDepot(shop)
    local dropoff = delivery.metadata and delivery.metadata.dropoff or ChooseDropoff(shop)

    local coords = depot.coords or VecToTable(shop.coords)
    local heading = depot.heading or shop.heading or 0.0

    local vehicle = SpawnVehicleForPlayer(player.PlayerData.source, vehicleKey or delivery.vehicle_model or 'pony', coords, heading)
    if not vehicle then
        return false, 'vehicle'
    end

    local plate = (customPlate and string.upper(customPlate)) or GeneratePlate()
    SetVehicleNumberPlateText(vehicle, plate)
    SetVehicleFuelLevel(vehicle, 100.0)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    delivery.status = 'active'
    delivery.citizenid = player.PlayerData.citizenid
    delivery.vehicle_model = vehicleKey or delivery.vehicle_model
    delivery.vehicle_plate = plate
    delivery.metadata = delivery.metadata or {}
    delivery.metadata.depot = depot
    delivery.metadata.dropoff = dropoff

    UpdateDeliveryStatus(shop, delivery, 'active', {
        citizenid = player.PlayerData.citizenid,
        vehicle_model = delivery.vehicle_model,
        vehicle_plate = plate,
        metadata = EncodeMetadata(delivery.metadata),
    })

    local fuelCost = math.floor((Config.DeliveryFuelCostPerKm or 0) * (delivery.distance or 0))

    TriggerClientEvent('ws-shopsystem:client:deliveryStarted', player.PlayerData.source, shop.identifier, delivery.identifier, {
        coords = delivery.metadata.depot.coords,
        label = delivery.metadata.depot.label,
        heading = heading,
    }, {
        coords = delivery.metadata.dropoff.coords,
        label = delivery.metadata.dropoff.label,
    }, netId, plate, delivery.vehicle_model, fuelCost)

    if Config.Notifications and Config.Notifications.phone and delivery.metadata.depot then
        local subject = Config.Notifications.phone.subjectDelivery:format(shop.label)
        local message = Config.Notifications.phone.messageDeliveryReady:format(delivery.identifier, delivery.metadata.depot.label)
        WSShops.NotifyOwner(shop, subject, message)
        WSShops.NotifyCitizen(player.PlayerData.citizenid, subject, message)
    end

    return true
end

local function AdjustInventory(shop, items)
    WSShops.FetchInventory(shop)
    for _, item in ipairs(items or {}) do
        local inventoryItem = FindInventoryItem(shop, item.item)
        if inventoryItem then
            local newQuantity = (inventoryItem.quantity or 0) + (tonumber(item.quantity) or 0)
            inventoryItem.quantity = newQuantity
            WSShops.UpdateInventoryQuantity(inventoryItem.id, newQuantity)
        end
    end
    WSShops.FetchInventory(shop)
end

function Deliveries.Complete(shop, player, deliveryIdentifier, duration, fuelCost)
    local delivery = FindDelivery(shop, deliveryIdentifier)
    if not delivery then return false, 'not_found' end
    if delivery.status ~= 'active' then return false, 'not_active' end
    if delivery.citizenid and delivery.citizenid ~= player.PlayerData.citizenid then
        return false, 'forbidden'
    end

    AdjustInventory(shop, delivery.items)

    UpdateDeliveryStatus(shop, delivery, 'completed', {
        finished_at = os.date('%Y-%m-%d %H:%M:%S'),
    })

    if WSShops.Finance and WSShops.Finance.RecordDelivery then
        WSShops.Finance.RecordDelivery(shop, true, Config.XP.Delivery)
    end
    WSShops.AddXP(shop, Config.XP.Delivery, 'delivery_success')

    local penalty = tonumber(fuelCost or 0) or 0
    if penalty > 0 then
        WSShops.UpdateBalance(shop, -penalty, 'delivery_fuel', { delivery = delivery.identifier })
    end
    WSShops.UpdateBalance(shop, -(Config.VehicleMaintainanceCost or 0), 'delivery_maintain', { delivery = delivery.identifier })

    if Config.Notifications and Config.Notifications.phone then
        local subject = Config.Notifications.phone.subjectDelivery:format(shop.label)
        local message = ('Lieferung %s abgeschlossen. Lager aufgefuellt.'):format(delivery.identifier)
        WSShops.NotifyOwner(shop, subject, message)
        WSShops.NotifyCitizen(player.PlayerData.citizenid, subject, message)
    end

    return true
end

function Deliveries.Fail(shop, player, deliveryIdentifier, reason)
    local delivery = FindDelivery(shop, deliveryIdentifier)
    if not delivery then return false, 'not_found' end
    if delivery.status ~= 'active' and delivery.status ~= 'pending' then return false, 'not_active' end
    if delivery.citizenid and delivery.citizenid ~= player.PlayerData.citizenid then
        return false, 'forbidden'
    end

    UpdateDeliveryStatus(shop, delivery, 'failed', {
        finished_at = os.date('%Y-%m-%d %H:%M:%S'),
    })

    if WSShops.Finance and WSShops.Finance.RecordDelivery then
        WSShops.Finance.RecordDelivery(shop, false)
    end

    local penalty = delivery.penalty or Config.DeliveryFailurePenalty or 0
    if penalty > 0 then
        WSShops.UpdateBalance(shop, -penalty, 'delivery_failed', { delivery = delivery.identifier, reason = reason })
    end

    if Config.Notifications and Config.Notifications.phone then
        local subject = Config.Notifications.phone.subjectDelivery:format(shop.label)
        local message = Config.Notifications.phone.messageFailed:format(delivery.identifier, penalty)
        WSShops.NotifyOwner(shop, subject, message)
        if delivery.citizenid then
            WSShops.NotifyCitizen(delivery.citizenid, subject, message)
        end
    end

    return true
end

return Deliveries
