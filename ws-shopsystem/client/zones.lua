local Config = WSShopConfig
local QBCore = exports['qb-core']:GetCoreObject()

local SpawnedPeds = {}
local SpawnedBlips = {}
local InteractionPoints = {}
local ActiveShops = {}
local TargetResource = GetResourceState('qb-target')
local HasTarget = TargetResource == 'started' or TargetResource == 'starting'

local function LoadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    return model
end

local function RemoveShopPed(identifier)
    local ped = SpawnedPeds[identifier]
    if ped and DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
    SpawnedPeds[identifier] = nil
end

local function RemoveTargetZone(identifier)
    if not Config.UseTarget or not HasTarget then return end
    local zoneName = 'ws-shop-' .. identifier
    exports['qb-target']:RemoveZone(zoneName)
end

local function ClearShopBlip(identifier)
    local blip = SpawnedBlips[identifier]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    SpawnedBlips[identifier] = nil
end

local function RemoveInteractionPoint(identifier)
    InteractionPoints[identifier] = nil
end

local function TeardownShop(identifier)
    RemoveShopPed(identifier)
    RemoveTargetZone(identifier)
    ClearShopBlip(identifier)
    RemoveInteractionPoint(identifier)
    ActiveShops[identifier] = nil
end

local function ToVector3(data)
    if not data then return nil end
    local t = type(data)
    if t == 'vector3' then
        return data
    elseif t == 'vector4' then
        return vector3(data.x, data.y, data.z)
    elseif t == 'table' then
        local x = tonumber(data.x or data.coords and data.coords.x)
        local y = tonumber(data.y or data.coords and data.coords.y)
        local z = tonumber(data.z or data.coords and data.coords.z)
        if x and y and z then
            return vector3(x, y, z)
        end
    end
    return nil
end

local function ExtractHeading(...)
    for i = 1, select('#', ...) do
        local entry = select(i, ...)
        if entry ~= nil then
            if type(entry) == 'number' then
                local value = tonumber(entry)
                if value then return value end
            elseif type(entry) == 'table' then
                if entry.heading ~= nil then
                    local value = tonumber(entry.heading)
                    if value then return value end
                end
                if entry.w ~= nil then
                    local value = tonumber(entry.w)
                    if value then return value end
                end
            end
        end
    end
    return 0.0
end

local function SpawnShopPed(identifier, config)
    if not config or not config.ped or not config.ped.model or config.ped.model == '' then
        RemoveShopPed(identifier)
        return
    end

    local model = LoadModel(config.ped.model or 'mp_m_shopkeep_01')
    if not model then return end

    local coords = config.coords
    local heading = config.heading or 0.0

    RemoveShopPed(identifier)

    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)

    if config.ped.scenario then
        TaskStartScenarioInPlace(ped, config.ped.scenario, 0, true)
    end

    SpawnedPeds[identifier] = ped
    SetModelAsNoLongerNeeded(model)
end

local function AddTargetZone(identifier, config)
    if not Config.UseTarget or not HasTarget then return end
    local coords = config.coords
    local zone = config.zone or {}
    local heading = zone.heading or config.heading or 0.0
    local length = tonumber(zone.length) or 2.0
    local width = tonumber(zone.width) or 2.0
    local minZ = tonumber(zone.minZ) or (coords.z - 1.0)
    local maxZ = tonumber(zone.maxZ) or (coords.z + 1.0)

    RemoveTargetZone(identifier)

    exports['qb-target']:AddBoxZone('ws-shop-' .. identifier, coords, length, width, {
        name = 'ws-shop-' .. identifier,
        heading = heading,
        minZ = minZ,
        maxZ = maxZ,
    }, {
        options = {
            {
                type = 'client',
                event = 'ws-shopsystem:client:attemptOpenShop',
                icon = Config.TargetIcon or 'fas fa-store',
                label = Config.TargetLabel or 'Shop betreten',
                identifier = identifier,
            },
            {
                type = 'client',
                event = 'ws-shopsystem:client:attemptManagement',
                icon = 'fas fa-briefcase',
                label = Config.BossmenuLabel or 'Shopverwaltung',
                identifier = identifier,
            },
        },
        distance = Config.TargetDistance or 2.0,
    })
end

local function AddInteractionPoint(identifier, config)
    InteractionPoints[identifier] = {
        identifier = identifier,
        coords = vector3(config.coords.x, config.coords.y, config.coords.z),
        label = config.label or identifier,
    }
end

local function AddBlip(identifier, config)
    if not config.blip then return end
    ClearShopBlip(identifier)
    local blip = AddBlipForCoord(config.coords.x, config.coords.y, config.coords.z)
    SetBlipSprite(blip, config.blip.sprite or 59)
    SetBlipColour(blip, config.blip.color or 1)
    SetBlipScale(blip, config.blip.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(config.label or identifier)
    EndTextCommandSetBlipName(blip)
    SpawnedBlips[identifier] = blip
end

local function SetupShop(data)
    if type(data) ~= 'table' or not data.identifier then return end

    local identifier = data.identifier
    local metadata = data.metadata or {}
    local creator = metadata.creator or {}
    local baseConfig = data.config or {}

    local coords = ToVector3(creator.coords)
        or ToVector3(data.coords)
        or ToVector3(baseConfig.coords)
        or ToVector3(Config.Shops[identifier] and Config.Shops[identifier].coords)

    if not coords then return end

    local heading = ExtractHeading(
        creator.heading,
        creator.coords,
        data.heading,
        data.coords,
        baseConfig.heading,
        baseConfig.coords
    )

    local pedConfig = creator.ped or baseConfig.ped or {}
    local zoneConfig = creator.zone or baseConfig.zone or {}
    local blipConfig = creator.blip or baseConfig.blip
    local label = data.label or baseConfig.label or identifier

    local shopConfig = {
        label = label,
        coords = coords,
        heading = heading,
        ped = pedConfig,
        zone = zoneConfig,
        blip = blipConfig,
    }

    TeardownShop(identifier)
    SpawnShopPed(identifier, shopConfig)
    AddTargetZone(identifier, shopConfig)
    if (not Config.UseTarget) or not HasTarget then
        AddInteractionPoint(identifier, shopConfig)
    end
    AddBlip(identifier, shopConfig)

    ActiveShops[identifier] = {
        coords = coords,
        heading = heading,
        label = label,
    }
end

RegisterNetEvent('ws-shopsystem:client:setupZones', function(payload)
    local seen = {}
    local hasPayload = false

    if type(payload) == 'table' then
        for _, entry in ipairs(payload) do
            if type(entry) == 'table' and entry.identifier then
                hasPayload = true
                SetupShop(entry)
                seen[entry.identifier] = true
            end
        end
    end

    if not hasPayload then
        for identifier, shop in pairs(Config.Shops) do
            SetupShop({
                identifier = identifier,
                label = shop.label or identifier,
                coords = shop.coords,
                heading = shop.heading,
                config = shop,
            })
            seen[identifier] = true
        end
    end

    for identifier in pairs(ActiveShops) do
        if not seen[identifier] then
            TeardownShop(identifier)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for identifier in pairs(SpawnedPeds) do
        RemoveShopPed(identifier)
    end
    for identifier in pairs(SpawnedBlips) do
        ClearShopBlip(identifier)
    end
    if Config.UseTarget and HasTarget then
        for identifier in pairs(ActiveShops) do
            RemoveTargetZone(identifier)
        end
    end
    InteractionPoints = {}
    ActiveShops = {}
end)

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (#text) / 250
    DrawRect(0.0, 0.0125, 0.02 + factor, 0.03, 0, 0, 0, 120)
    ClearDrawOrigin()
end

CreateThread(function()
    if Config.UseTarget and HasTarget then return end
    local openKey = (Config.InteractionKey or 'E'):upper()
    local openControl = (QBCore.Shared and QBCore.Shared.KeyList and QBCore.Shared.KeyList[openKey]) or 38
    local openText = ('[%s] Shop oeffnen'):format(openKey)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)

        for _, point in pairs(InteractionPoints) do
            local dist = #(pos - point.coords)
            if dist <= (Config.TargetDistance or 2.0) + 0.2 then
                sleep = 0
                DrawText3D(point.coords.x, point.coords.y, point.coords.z + 1.0, openText)

                if IsControlJustReleased(0, openControl) then
                    TriggerEvent('ws-shopsystem:client:attemptOpenShop', { identifier = point.identifier })
                end
            end
        end

        Wait(sleep)
    end
end)
