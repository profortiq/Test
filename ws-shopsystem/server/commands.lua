local Config = WSShopConfig
local Utils = WSShops.Utils
local QBCore = exports['qb-core']:GetCoreObject()

local function buildAdminPayloadSafe()
    if not WSShops.BuildAdminPayload then
        return nil, 'missing_builder'
    end

    local ok, payload = pcall(WSShops.BuildAdminPayload)
    if not ok then
        Utils.Debug('Failed to build admin payload: %s', payload)
        return nil, payload
    end

    return payload
end

local function openAdminPanel(source, options)
    options = options or {}

    if not source or source <= 0 then
        return false, nil, 'invalid_source'
    end

    if not WSShops.PlayerIsAdmin or not WSShops.PlayerIsAdmin(source) then
        local message = Utils.Locale('error.role_not_allowed')
        if not options.silent then
            Utils.Notify(source, message, 'error')
        end
        return false, nil, message
    end

    local payload, errorMessage = buildAdminPayloadSafe()
    if not payload then
        local message = errorMessage or Utils.Locale('error.admin_payload_failed')
        if not options.silent then
            Utils.Notify(source, message, 'error')
        end
        return false, nil, message
    end

    if not options.skipTrigger then
        TriggerClientEvent('ws-shopsystem:client:openAdminOverview', source, payload)
    end

    return true, payload
end

local commandName = Config.ManagementCommand or 'shopadmin'

QBCore.Commands.Add(commandName, 'Öffnet das Shop-Admin-Menü', {}, false, function(source)
    TriggerClientEvent('ws-shopsystem:client:requestAdminPanel', source)
end, 'user')

RegisterNetEvent('ws-shopsystem:server:openAdminPanel', function()
    local src = source
    TriggerClientEvent('ws-shopsystem:client:requestAdminPanel', src)
end)

exports('OpenAdminPanel', function(target)
    return openAdminPanel(target, { silent = true })
end)

QBCore.Functions.CreateCallback('ws-shopsystem:server:adminOpen', function(source, cb)
    local success, payload, message = openAdminPanel(source, { silent = true, skipTrigger = true })
    if not success then
        cb({ success = false, message = message })
        return
    end

    cb({ success = true, payload = payload })
end)
