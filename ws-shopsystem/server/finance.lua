local QBCore = exports['qb-core']:GetCoreObject()
local Config = WSShopConfig
local Utils = WSShops.Utils

WSShops.Finance = WSShops.Finance or {}
local Finance = WSShops.Finance

local function UpsertDailyStat(shopId, column, value)
    local today = os.date('%Y-%m-%d')
    MySQL.insert.await([[
        INSERT INTO ws_shop_statistics_daily (shop_id, stat_date, ]] .. column .. [[)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE ]] .. column .. [[ = ]] .. column .. [[ + VALUES(]] .. column .. [[), updated_at = CURRENT_TIMESTAMP
    ]], { shopId, today, value })
end

function Finance.RecordSale(shop, amount)
    UpsertDailyStat(shop.id, 'sales_total', amount)
    UpsertDailyStat(shop.id, 'sales_count', 1)
end

function Finance.RecordDelivery(shop, success, xp)
    local column = success and 'deliveries_completed' or 'deliveries_failed'
    UpsertDailyStat(shop.id, column, 1)
    if xp then
        Finance.RecordXP(shop, xp)
    end
end

function Finance.RecordEmployeeActivity(shop, employees)
    UpsertDailyStat(shop.id, 'employees_active', employees)
end

function Finance.RecordXP(shop, xp)
    UpsertDailyStat(shop.id, 'xp_earned', xp)
end

function Finance.PayEmployee(shop, employee, amount, reason)
    WSShops.UpdateBalance(shop, -amount, reason or 'payroll', { employee = employee.citizenid })
    local target = Utils.GetPlayerByCitizenId(employee.citizenid)
    if target then
        target.Functions.AddMoney(Config.BankingAccount, amount, 'ws-shop-payroll')
        Utils.Notify(target.PlayerData.source, Utils.Locale('success.wage_paid', amount), 'success')
    elseif Config.OfflineWagePayout then
        local accounts = MySQL.single.await('SELECT money FROM players WHERE citizenid = ?', { employee.citizenid })
        if accounts then
            local money = json.decode(accounts.money or '{}')
            money[Config.BankingAccount] = (money[Config.BankingAccount] or 0) + amount
            MySQL.update.await('UPDATE players SET money = ? WHERE citizenid = ?', { json.encode(money), employee.citizenid })
        end
    end
    WSShops.NotifyOwner(shop,
        Config.Notifications.phone.subjectFinance:format(shop.label),
        ('Mitarbeiter %s wurde $%s bezahlt.'):format(employee.name, amount))
end

CreateThread(function()
    while true do
        Wait(30 * 60 * 1000)
        for _, shop in pairs(WSShops.Cache.ShopsByIdentifier) do
            if shop and shop.employees then
                local active = 0
                for _, employee in ipairs(shop.employees) do
                    if employee.status == 'active' then
                        active = active + 1
                        if employee.wage and employee.wage > 0 and shop.balance >= employee.wage then
                            Finance.PayEmployee(shop, employee, employee.wage, 'salary')
                        end
                    end
                end
                if active > 0 then
                    Finance.RecordEmployeeActivity(shop, active)
                end
            end
        end
    end
end)
