local Config = WSShopConfig
local QBCore = exports['qb-core']:GetCoreObject()

local function DrawText3D(x, y, z, text)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 250
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local ActiveDelivery = nil
local DeliveryThreadActive = false
local RouteBlip = nil
local VehicleBlip = nil

local function RemoveRouteBlip()
    if RouteBlip and DoesBlipExist(RouteBlip) then
        RemoveBlip(RouteBlip)
    end
    RouteBlip = nil
end

local function RemoveVehicleBlip()
    if VehicleBlip and DoesBlipExist(VehicleBlip) then
        RemoveBlip(VehicleBlip)
    end
    VehicleBlip = nil
end

local function CreateRouteBlip(coords, label, color, sprite)
    RemoveRouteBlip()
    RouteBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(RouteBlip, sprite or Config.DeliveryBlipSprite or 478)
    SetBlipColour(RouteBlip, color or Config.DeliveryBlipColor or 1)
    SetBlipScale(RouteBlip, 0.85)
    SetBlipRoute(RouteBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Lieferung')
    EndTextCommandSetBlipName(RouteBlip)
end

local function SetVehicleBlip(netId)
    RemoveVehicleBlip()
    if not netId then return end
    local attempts = 0
    CreateThread(function()
        local entity
        while attempts < 50 do
            entity = NetworkGetEntityFromNetworkId(netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then
                break
            end
            attempts = attempts + 1
            Wait(200)
        end
        if not entity or entity == 0 or not DoesEntityExist(entity) then return end
        VehicleBlip = AddBlipForEntity(entity)
        SetBlipSprite(VehicleBlip, 67)
        SetBlipColour(VehicleBlip, 2)
        SetBlipScale(VehicleBlip, 0.85)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Lieferfahrzeug')
        EndTextCommandSetBlipName(VehicleBlip)
    end)
end

local function Distance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

local function HandleDeliveryLoop()
    if DeliveryThreadActive then return end
    DeliveryThreadActive = true
    CreateThread(function()
        while ActiveDelivery do
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            if ActiveDelivery.stage == 'pickup' then
                local depot = ActiveDelivery.pickup
                local dist = Distance({ x = coords.x, y = coords.y, z = coords.z }, depot.coords)
                if dist < 5.0 then
                    DrawMarker(1, depot.coords.x, depot.coords.y, depot.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 255, 70, 70, 120, false, false, 2, false, nil, nil, false)
                    if dist < 2.0 then
                        DrawText3D(depot.coords.x, depot.coords.y, depot.coords.z + 0.1, '[E] Waren laden')
                        if IsControlJustReleased(0, 38) then
                            ActiveDelivery.stage = 'dropoff'
                            ActiveDelivery.startTime = GetGameTimer()
                            CreateRouteBlip(ActiveDelivery.dropoff.coords, 'Lieferung abgeben', 2, 478)
                            QBCore.Functions.Notify('Waren geladen. Bringe sie zum Shop.', 'success')
                        end
                    end
                end
            elseif ActiveDelivery.stage == 'dropoff' then
                local dropoff = ActiveDelivery.dropoff
                local dist = Distance({ x = coords.x, y = coords.y, z = coords.z }, dropoff.coords)
                if dist < 5.0 then
                    DrawMarker(1, dropoff.coords.x, dropoff.coords.y, dropoff.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 255, 70, 70, 120, false, false, 2, false, nil, nil, false)
                    if dist < 2.0 then
                        DrawText3D(dropoff.coords.x, dropoff.coords.y, dropoff.coords.z + 0.1, '[E] Waren abladen')
                        if IsControlJustReleased(0, 38) then
                            local duration = math.floor((GetGameTimer() - ActiveDelivery.startTime) / 60000)
                            TriggerServerEvent('ws-shopsystem:server:completeDelivery', ActiveDelivery.shopIdentifier, ActiveDelivery.deliveryIdentifier, duration, ActiveDelivery.fuelCost)
                            ActiveDelivery = nil
                            RemoveRouteBlip()
                            RemoveVehicleBlip()
                            break
                        end
                    end
                end
            end

            Wait(0)
        end
        DeliveryThreadActive = false
    end)
end

RegisterNetEvent('ws-shopsystem:client:deliveryStarted', function(identifier, deliveryIdentifier, pickup, dropoff, vehicleNetId, vehiclePlate, vehicleModel, fuelCost)
    if not pickup or not pickup.coords then return end
    if not dropoff or not dropoff.coords then return end

    ActiveDelivery = {
        shopIdentifier = identifier,
        deliveryIdentifier = deliveryIdentifier,
        stage = 'pickup',
        pickup = {
            coords = vector3(pickup.coords.x, pickup.coords.y, pickup.coords.z),
            label = pickup.label or 'Depot',
            heading = pickup.heading or 0.0,
        },
        dropoff = {
            coords = vector3(dropoff.coords.x, dropoff.coords.y, dropoff.coords.z),
            label = dropoff.label or 'Shop',
        },
        fuelCost = fuelCost or 0,
        vehicleNetId = vehicleNetId,
        vehiclePlate = vehiclePlate,
        vehicleModel = vehicleModel,
    }

    CreateRouteBlip(pickup.coords, 'Waren abholen', 1, Config.DepotBlipSprite or 478)
    SetVehicleBlip(vehicleNetId)
    if vehicleModel then
        QBCore.Functions.Notify(('Fahrzeug %s steht bereit.'):format(vehicleModel), 'primary', 5500)
    end
    QBCore.Functions.Notify('Fahre zum Depot und lade die Waren.', 'primary', 6500)
    HandleDeliveryLoop()
end)

RegisterNetEvent('ws-shopsystem:client:deliveriesUpdated', function(identifier)
    if not WSShopClient.ActiveShop or WSShopClient.ActiveShop.identifier ~= identifier then return end
    QBCore.Functions.TriggerCallback('ws-shopsystem:server:getShopData', function(shop)
        if not shop then return end
        WSShopClient.ActiveShop = shop
        SendNUIMessage({
            action = 'refreshDeliveries',
            deliveries = shop.deliveries,
        })
    end, identifier)
end)

RegisterNUICallback('cancelDelivery', function(data, cb)
    if not ActiveDelivery or ActiveDelivery.deliveryIdentifier ~= data.deliveryId then cb('error') return end
    TriggerServerEvent('ws-shopsystem:server:failDelivery', ActiveDelivery.shopIdentifier, ActiveDelivery.deliveryIdentifier, 'cancelled')
    ActiveDelivery = nil
    RemoveRouteBlip()
    RemoveVehicleBlip()
    cb('ok')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    RemoveRouteBlip()
    RemoveVehicleBlip()
end)
