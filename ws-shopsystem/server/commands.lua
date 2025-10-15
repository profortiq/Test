local Config = WSShopConfig
local Utils = WSShops.Utils
local QBCore = exports['qb-core']:GetCoreObject()

local function SerializeShops()
    local payload = {}
    for identifier, shop in pairs(WSShops.Cache.ShopsByIdentifier) do
        payload[#payload + 1] = {
            identifier = identifier,
            label = shop.label,
            type = shop.type,
            owner = shop.ownerName,
            level = shop.level,
            balance = shop.balance,
        }
    end
    return payload
end

QBCore.Commands.Add(Config.ManagementCommand or 'shopadmin', 'Öffnet das Shop-Admin-Menü', {}, false, function(source)
    TriggerClientEvent('ws-shopsystem:client:openAdminOverview', source, SerializeShops())
end, 'admin')
