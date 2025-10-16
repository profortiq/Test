local QBCore = exports['qb-core']:GetCoreObject()

WSShopClient = WSShopClient or {}
WSShopClient.ActiveShop = nil
WSShopClient.ActiveRole = nil
WSShopClient.IsOwner = false
WSShopClient.IsAdmin = false
WSShopClient.ActiveMeta = {}

local function Sanitize(value)
    local valueType = type(value)
    if valueType == 'vector3' then
        return { x = value.x, y = value.y, z = value.z }
    elseif valueType == 'vector4' then
        return { x = value.x, y = value.y, z = value.z, w = value.w }
    elseif valueType == 'table' then
        local result = {}
        for key, data in pairs(value) do
            result[key] = Sanitize(data)
        end
        return result
    end
    return value
end

local function PrepareShop(shop)
    if not shop then return nil end
    local sanitized = Sanitize(shop)
    sanitized.deliveryVehicles = sanitized.deliveryVehicles or {}
    sanitized.roles = sanitized.roles or {}
    sanitized.levels = sanitized.levels or {}
    sanitized.vehicleOwnership = sanitized.vehicleOwnership or {}
    return sanitized
end

local function CloseUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    WSShopClient.ActiveShop = nil
    WSShopClient.ActiveRole = nil
    WSShopClient.IsOwner = false
    WSShopClient.IsAdmin = false
    WSShopClient.ActiveMeta = {}
end

RegisterNetEvent('ws-shopsystem:client:openShop', function(shop, meta)
    local prepared = PrepareShop(shop)
    WSShopClient.ActiveShop = prepared
    WSShopClient.ActiveRole = meta and meta.role or nil
    WSShopClient.IsOwner = meta and meta.isOwner or false
    WSShopClient.IsAdmin = meta and meta.isAdmin or false
    WSShopClient.ActiveMeta = meta or {}
    if WSShopClient.ActiveMeta.canManage == nil then
        WSShopClient.ActiveMeta.canManage = false
    end
    if not WSShopClient.ActiveMeta.citizenid then
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData then
            WSShopClient.ActiveMeta.citizenid = playerData.citizenid
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openShop',
        shop = prepared,
        meta = meta,
    })
end)

RegisterNetEvent('ws-shopsystem:client:openManagement', function(shop, meta)
    local prepared = PrepareShop(shop)
    WSShopClient.ActiveShop = prepared
    WSShopClient.ActiveRole = meta and meta.role or nil
    WSShopClient.IsOwner = meta and meta.isOwner or false
    WSShopClient.IsAdmin = meta and meta.isAdmin or false
    WSShopClient.ActiveMeta = meta or {}
    if WSShopClient.ActiveMeta.canManage == nil then
        WSShopClient.ActiveMeta.canManage = false
    end
    if not WSShopClient.ActiveMeta.citizenid then
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData then
            WSShopClient.ActiveMeta.citizenid = playerData.citizenid
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openManagement',
        shop = prepared,
        meta = meta,
    })
end)

RegisterNetEvent('ws-shopsystem:client:openAdminOverview', function(payload)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdminOverview',
        shops = payload and payload.shops or {},
        shopTypes = payload and payload.shopTypes or {},
        deliveryVehicles = payload and payload.deliveryVehicles or {},
        depots = payload and payload.depots or {},
    })
end)

RegisterNetEvent('ws-shopsystem:client:purchaseSuccess', function(total)
    QBCore.Functions.Notify(('[Shop] Kauf erfolgreich - $%s'):format(total), 'success')
end)

RegisterNetEvent('ws-shopsystem:client:shopUpdated', function(identifier, data)
    if not WSShopClient.ActiveShop or WSShopClient.ActiveShop.identifier ~= identifier then return end
    for key, value in pairs(data) do
        WSShopClient.ActiveShop[key] = value
    end
    if data.vehicleOwnership then
        WSShopClient.ActiveShop.vehicleOwnership = data.vehicleOwnership
    end
    if data.metadata then
        WSShopClient.ActiveShop.metadata = data.metadata
    end
    if data.owner ~= nil then
        local playerData = QBCore.Functions.GetPlayerData()
        local citizenId = playerData and playerData.citizenid
        if citizenId and data.owner == citizenId then
            WSShopClient.IsOwner = true
            WSShopClient.ActiveMeta = WSShopClient.ActiveMeta or {}
            WSShopClient.ActiveMeta.isOwner = true
            WSShopClient.ActiveMeta.canManage = true
            WSShopClient.ActiveMeta.citizenid = citizenId
        else
            if WSShopClient.IsOwner then
                WSShopClient.IsOwner = false
            end
            if WSShopClient.ActiveMeta then
                if WSShopClient.ActiveMeta.isOwner then
                    WSShopClient.ActiveMeta.isOwner = false
                    if not WSShopClient.ActiveMeta.role or WSShopClient.ActiveMeta.role == '' then
                        WSShopClient.ActiveMeta.canManage = false
                    end
                end
            end
        end
    end
    SendNUIMessage({
        action = 'refreshShop',
        shop = WSShopClient.ActiveShop,
    })
end)

RegisterNetEvent('ws-shopsystem:client:inventoryUpdated', function(identifier)
    if not WSShopClient.ActiveShop or WSShopClient.ActiveShop.identifier ~= identifier then return end
    QBCore.Functions.TriggerCallback('ws-shopsystem:server:getShopData', function(shop)
        if not shop then return end
        local prepared = PrepareShop(shop)
        WSShopClient.ActiveShop = prepared
        SendNUIMessage({
            action = 'refreshShop',
            shop = prepared,
        })
    end, identifier)
end)

RegisterNetEvent('ws-shopsystem:client:lowStock', function(identifier, item, quantity)
    if not WSShopClient.IsOwner then return end
    if not WSShopClient.ActiveShop or WSShopClient.ActiveShop.identifier ~= identifier then return end
    QBCore.Functions.Notify(('Niedriger Bestand: %s (%s Stück).'):format(item, quantity), 'warning', 6000)
end)

RegisterNUICallback('close', function(_, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('purchase', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:purchaseItems', WSShopClient.ActiveShop.identifier, data.cart, data.payWith)
    cb('ok')
end)

RegisterNUICallback('openManagement', function(_, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    if not WSShopClient.ActiveMeta or not WSShopClient.ActiveMeta.canManage then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:openManagement', WSShopClient.ActiveShop.identifier)
    cb('ok')
end)

RegisterNUICallback('setPrice', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:setPrice', WSShopClient.ActiveShop.identifier, data.itemId, data.price)
    cb('ok')
end)

RegisterNUICallback('setItemDiscount', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:setItemDiscount', WSShopClient.ActiveShop.identifier, data.itemId, data.discount)
    cb('ok')
end)

RegisterNUICallback('setDiscount', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:setDiscount', WSShopClient.ActiveShop.identifier, data.discount)
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:deposit', WSShopClient.ActiveShop.identifier, data.amount)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:withdraw', WSShopClient.ActiveShop.identifier, data.amount)
    cb('ok')
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:hireEmployee', WSShopClient.ActiveShop.identifier, data.citizenid, data.role, data.wage)
    cb('ok')
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:fireEmployee', WSShopClient.ActiveShop.identifier, data.citizenid)
    cb('ok')
end)

RegisterNUICallback('createDelivery', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:createDelivery', WSShopClient.ActiveShop.identifier, data)
    cb('ok')
end)

RegisterNUICallback('startDelivery', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:startDelivery', WSShopClient.ActiveShop.identifier, data.deliveryId, data.vehicle, data.plate)
    cb('ok')
end)

RegisterNUICallback('completeDelivery', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:completeDelivery', WSShopClient.ActiveShop.identifier, data.deliveryId, data.duration, data.fuelCost)
    cb('ok')
end)

RegisterNUICallback('failDelivery', function(data, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:failDelivery', WSShopClient.ActiveShop.identifier, data.deliveryId, data.reason)
    cb('ok')
end)

RegisterNUICallback('sellShop', function(_, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    if not WSShopClient.IsOwner then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:sellShop', WSShopClient.ActiveShop.identifier)
    cb('ok')
end)

RegisterNUICallback('buyShop', function(_, cb)
    if not WSShopClient.ActiveShop then cb('error') return end
    if WSShopClient.ActiveShop.owner then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:purchaseShop', WSShopClient.ActiveShop.identifier)
    cb('ok')
end)

RegisterNUICallback('adminClose', function(_, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('adminSaveShop', function(data, cb)
    TriggerServerEvent('ws-shopsystem:server:adminSaveShop', data)
    cb('ok')
end)

RegisterNUICallback('adminGetPlayerCoords', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    cb({
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = heading,
        }
    })
end)

RegisterCommand('ws-shop-close', function()
    if WSShopClient.ActiveShop then
        CloseUI()
    end
end, false)

RegisterKeyMapping('ws-shop-close', 'Shop Interface schliessen', 'keyboard', 'BACK')

RegisterNetEvent('ws-shopsystem:client:receiveShopCache', function(payload)
    TriggerEvent('ws-shopsystem:client:setupZones', payload)
end)

RegisterNetEvent('ws-shopsystem:client:attemptOpenShop', function(data)
    TriggerServerEvent('ws-shopsystem:server:openShop', data.identifier)
end)

RegisterNetEvent('ws-shopsystem:client:attemptManagement', function(data)
    TriggerServerEvent('ws-shopsystem:server:openManagement', data.identifier)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(1500)
    TriggerServerEvent('ws-shopsystem:server:requestShopCache')
end)
