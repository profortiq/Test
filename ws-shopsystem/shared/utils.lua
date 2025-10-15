local Utils = {}

local Config = WSShopConfig

Utils.Debug = function(message, ...)
    if not Config.Debug then return end
    local formatted = '[ws-shopsystem] ' .. message
    if ... then
        print(string.format(formatted, ...))
    else
        print(formatted)
    end
end

---@param citizenid string
---@return table|nil
Utils.GetPlayerByCitizenId = function(citizenid)
    local QBCore = exports['qb-core']:GetCoreObject()
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        if Player.PlayerData.citizenid == citizenid then
            return Player
        end
    end
    return nil
end

---@param source number
---@return table|nil
Utils.GetPlayerData = function(source)
    local QBCore = exports['qb-core']:GetCoreObject()
    return QBCore.Functions.GetPlayer(source)
end

Utils.Notify = function(source, message, nType, length)
    TriggerClientEvent('QBCore:Notify', source, message, nType or 'primary', length or 5000)
end

Utils.Locale = function(key, ...)
    if not Locale then return key end
    return Locale(key, ...)
end

Utils.HasPermission = function(role, permission)
    if not role then return false end
    if role == 'owner' then return true end
    local roleConfig = Config.Roles[role]
    if not roleConfig then return false end
    if not roleConfig.permissions then return false end
    if roleConfig.permissions[1] == 'everything' then return true end
    for _, perm in pairs(roleConfig.permissions) do
        if perm == permission then
            return true
        end
    end
    return false
end

Utils.Round = function(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor(value * power + 0.5) / power
end

Utils.DeepCopy = function(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            copy[k] = Utils.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

Utils.MergeInventory = function(target, source)
    for category, data in pairs(source) do
        target[category] = target[category] or { label = data.label, items = {} }
        for _, item in ipairs(data.items) do
            target[category].items[#target[category].items + 1] = Utils.DeepCopy(item)
        end
    end
    return target
end

Utils.VecToTable = function(vec)
    if type(vec) == 'vector3' or type(vec) == 'vector4' then
        return { x = vec.x, y = vec.y, z = vec.z, w = vec.w }
    end
    return vec
end

Utils.GetLevelFromXP = function(xp)
    local level = 1
    for lvl, data in pairs(Config.Levels) do
        if xp >= data.xp and lvl > level then
            level = lvl
        end
    end
    return level
end

Utils.GetNextLevelXP = function(currentLevel)
    local nextLevel = WSShopConfig.Levels[currentLevel + 1]
    if not nextLevel then return nil end
    return nextLevel.xp
end

WSShops = WSShops or {}
WSShops.Utils = Utils

return Utils
