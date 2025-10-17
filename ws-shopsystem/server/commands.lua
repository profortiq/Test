local Config = WSShopConfig
local Utils = WSShops.Utils
local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Commands.Add(Config.ManagementCommand or 'shopadmin', 'Öffnet das Shop-Admin-Menü', {}, false, function(source)
    local payload = WSShops.BuildAdminPayload and WSShops.BuildAdminPayload() or {}
    TriggerClientEvent('ws-shopsystem:client:openAdminOverview', source, payload)
end, 'admin')
