local Config = WSShopConfig
local QBCore = exports['qb-core']:GetCoreObject()

local SpawnedPeds = {}
local ZonesCreated = false
local InteractionPoints = {}
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

local function SpawnShopPed(identifier, config)
    if not config.ped or SpawnedPeds[identifier] then return end

    local model = LoadModel(config.ped.model or 'mp_m_shopkeep_01')
    if not model then return end

    local coords = config.coords
    local heading = config.heading or 0.0

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
    local zone = config.zone or { length = 2.0, width = 2.0, heading = config.heading or 0.0, minZ = coords.z - 1.0, maxZ = coords.z + 1.0 }

    exports['qb-target']:AddBoxZone('ws-shop-' .. identifier, coords, zone.length or 2.0, zone.width or 2.0, {
        name = 'ws-shop-' .. identifier,
        heading = zone.heading or config.heading or 0.0,
        minZ = zone.minZ or (coords.z - 1.0),
        maxZ = zone.maxZ or (coords.z + 1.0),
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
    InteractionPoints[#InteractionPoints + 1] = {
        identifier = identifier,
        coords = vector3(config.coords.x, config.coords.y, config.coords.z),
        label = config.label or identifier,
    }
end

local function AddBlip(identifier, config)
    if not config.blip then return end
    local blip = AddBlipForCoord(config.coords.x, config.coords.y, config.coords.z)
    SetBlipSprite(blip, config.blip.sprite or 59)
    SetBlipColour(blip, config.blip.color or 1)
    SetBlipScale(blip, config.blip.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(config.label or identifier)
    EndTextCommandSetBlipName(blip)
end

local function SetupShop(identifier, config)
    if type(config.coords) ~= 'vector3' and type(config.coords) ~= 'vector4' then
        config.coords = vector3(config.coords.x, config.coords.y, config.coords.z)
    end
    SpawnShopPed(identifier, config)
    AddTargetZone(identifier, config)
    if (not Config.UseTarget) or not HasTarget then
        AddInteractionPoint(identifier, config)
    end
    AddBlip(identifier, config)
end

RegisterNetEvent('ws-shopsystem:client:setupZones', function(_payload)
    if ZonesCreated then return end
    for identifier, shop in pairs(Config.Shops) do
        SetupShop(identifier, shop)
    end
    ZonesCreated = true
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, ped in pairs(SpawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
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

        for _, point in ipairs(InteractionPoints) do
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
