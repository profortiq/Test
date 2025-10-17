local Config = WSShopConfig
local Utils = WSShops.Utils
local QBCore = exports['qb-core']:GetCoreObject()

local function BuildAdminPayloadSafe()
    if not WSShops.BuildAdminPayload then return {} end
    local ok, payload = pcall(WSShops.BuildAdminPayload)
    if not ok then
        Utils.Debug('Failed to build admin payload: %s', payload)
        return nil, payload
    end

local function OpenAdminPanel(src, opts)
    opts = opts or {}
    if not src or src <= 0 then return false, 'invalid_source' end

    if not (WSShops.PlayerIsAdmin and WSShops.PlayerIsAdmin(src)) then
        if not opts.silent then
            Utils.Notify(src, Utils.Locale('error.role_not_allowed'), 'error')
        end
        return false, 'unauthorised'
    end

    local payload, err = BuildAdminPayloadSafe()
    if not payload then
        Utils.Notify(src, Utils.Locale('error.admin_payload_failed'), 'error')
        return false, err or 'payload'
    end

    TriggerClientEvent('ws-shopsystem:client:openAdminOverview', src, payload)
    return true
end

local commandName = Config.ManagementCommand or 'shopadmin'

QBCore.Commands.Add(commandName, 'Öffnet das Shop-Admin-Menü', {}, false, function(source)
    OpenAdminPanel(source)
end, 'user')

RegisterNetEvent('ws-shopsystem:server:openAdminPanel', function()
    local src = source
    OpenAdminPanel(src)
end)

exports('OpenAdminPanel', function(target)
    return OpenAdminPanel(target, { silent = true })
end)
