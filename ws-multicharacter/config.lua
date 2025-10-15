Config = {}
Config.Interior = vector3(-763.2816, 330.0418, 199.4865)              -- Interior to load where characters are previewed
Config.DefaultSpawn = vector3(-1035.71, -2731.87, 12.86)              -- Default spawn coords if you have start apartments disabled
Config.PedCoords = vector4(-763.2816, 330.0418, 199.4865, 177.7942)   -- Create preview ped at these coordinates
Config.HiddenCoords = vector4(-779.0154, 326.1801, 196.0860, 91.0454) -- Hides your actual ped while you are in selection
Config.CamCoords = vector4(-763.1219, 326.8112, 200, 357.0954)        -- Camera coordinates for character preview screen
Config.EnableDeleteButton = true                                      -- Define if the player can delete the character or not
Config.BrandName = "WOLFSTUDIO"                                         -- Display name shown in the character UI
Config.customNationality = false                                      -- Defines if Nationality input is custom of blocked to the list of Countries
Config.SkipSelection = false                                          -- Skip the spawn selection and spawns the player at the last location
Config.PremiumSlotIndex = 3                                           -- Slot index that should be highlighted (set to nil if not needed)
Config.PremiumSlotIsFree = true                                       -- Treat the configured premium slot as a regular free slot
Config.DefaultNumberOfCharacters = 3                                  -- Define maximum amount of default characters (maximum 5 characters defined by default)
Config.PlayersNumberOfCharacters = {                                  -- Define maximum amount of player characters by rockstar license (you can find this license in your server's database in the player table)
    { license = 'license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', numberOfChars = 2 },
}
Config.SlotPortraits = {                                              -- UI portrait fallbacks per gender
    male = {
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673548566036550/Screenshot_2025-10-14_170300.png?ex=68efb81a&is=68ee669a&hm=b965cd449dd64be68097f6fe7e52cf0fb81628c638bc92d142bf7cfe74d22309&',
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549400965160/Screenshot_2025-10-14_170404.png?ex=68efb81b&is=68ee669b&hm=8524ede899e82763f046d341eaf94de2ee2093fb85edcf549a80317ff6b793d0&',
    },
    female = {
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549019156480/Screenshot_2025-10-14_170336.png?ex=68efb81a&is=68ee669a&hm=427acc187e63dd88e01c443e0247aa294cacac7a763f09cb84b7c7fee1c76379&',
    },
    other = {
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549019156480/Screenshot_2025-10-14_170336.png?ex=68efb81a&is=68ee669a&hm=427acc187e63dd88e01c443e0247aa294cacac7a763f09cb84b7c7fee1c76379&',
    },
    default = {
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549019156480/Screenshot_2025-10-14_170336.png?ex=68efb81a&is=68ee669a&hm=427acc187e63dd88e01c443e0247aa294cacac7a763f09cb84b7c7fee1c76379&',
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673548566036550/Screenshot_2025-10-14_170300.png?ex=68efb81a&is=68ee669a&hm=b965cd449dd64be68097f6fe7e52cf0fb81628c638bc92d142bf7cfe74d22309&',
        'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549400965160/Screenshot_2025-10-14_170404.png?ex=68efb81b&is=68ee669b&hm=8524ede899e82763f046d341eaf94de2ee2093fb85edcf549a80317ff6b793d0&',
    },
}


