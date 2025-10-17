local Config = WSShopConfig
local Utils = WSShops.Utils
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add(Config.ManagementCommand or 'shopadmin', 'Öffnet das Shop-Admin-Menü', {}, false, function(source)
    local isAdmin = WSShops.PlayerIsAdmin and WSShops.PlayerIsAdmin(source)
    if not isAdmin then
        Utils.Notify(source, Utils.Locale('error.role_not_allowed'), 'error')
        return
    end

    local payload = WSShops.BuildAdminPayload and WSShops.BuildAdminPayload() or {}
    TriggerClientEvent('ws-shopsystem:client:openAdminOverview', source, payload)
end, 'user')
