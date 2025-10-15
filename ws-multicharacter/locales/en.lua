local Translations = {
    notifications = {
        ["char_deleted"] = "Character deleted!",
        ["deleted_other_char"] = "You successfully deleted the character with citizen id %{citizenid}.",
        ["forgot_citizenid"] = "You forgot to input a citizen id!",
    },

    commands = {
        -- /deletechar
        ["deletechar_description"] = "Deletes another players character",
        ["citizenid"] = "Citizen ID",
        ["citizenid_help"] = "The Citizen ID of the character you want to delete",

        -- /logout
        ["logout_description"] = "Logout of Character (Admin Only)",

        -- /closeNUI
        ["closeNUI_description"] = "Close Multi NUI"
    },

    misc = {
        ["droppedplayer"] = "You have disconnected from QBCore"
    },

    ui = {
        -- Main
        characters_header = "My Characters",
        emptyslot = "Empty Slot",
        play_button = "Play",
        create_button = "Create Character",
        delete_button = "Delete Character",
        select_character = "Select Character",
        disconnect = "Disconnect",
        brand_name = "WOLFSTUDIO",
        brand_suffix = "Character Management",
        ui_title = "%{brand} <span>Character Management</span>",
        ui_subtitle = "Choose an existing character or create a new slot.",

        -- Character Information
        charinfo_header = "Character Information",
        charinfo_description = "Select a character slot to see all information about your character.",
        name = "Name",
        male = "Male",
        female = "Female",
        firstname = "First Name",
        lastname = "Last Name",
        nationality = "Nationality",
        gender = "Gender",
        birthdate = "Birthdate",
        nationality_placeholder = "Nationality",
        job = "Job",
        jobgrade = "Job Grade",
        cash = "Cash",
        bank = "Bank",
        phonenumber = "Phone Number",
        accountnumber = "Account Number",
        job_unemployed = "Unemployed",
        unknown_character = "Unknown Character",
        other = "Other",
        stat_cash = "Cash",
        stat_bank = "Credit Card",
        stat_birthdate = "Birthdate",
        stat_nationality = "Nationality",
        stat_gender = "Gender",
        banned_notice = "You are banned from this character.",
        banned_reason = "Reason: %{reason}",
        banned_expires = "Expires: %{expires}",
        slot_label = "Character Slot #%{index}",
        free_slot_title = "Free Slot",
        premium_slot_title = "Free Slot",
        free_slot_hint = "Character slot for new residents",
        premium_slot_hint = "Character slot for new residents",
        premium_slot_button = "Create Character",
        premium_slot_badge = "Free Slot",
        creator_title = "Create a new character",
        creator_subtitle = "Fill out the basic information. Appearance and more options follow in the next step.",

        chardel_header = "Character Registration",

        -- Delete character
        deletechar_header = "Delete Character",
        deletechar_description = "Are You Sure You Want To Delete Your Character?",

        -- Buttons
        cancel = "Cancel",
        confirm = "Confirm",

        -- Loading Text
        retrieving_playerdata = "Retrieving player data",
        validating_playerdata = "Validating player data",
        retrieving_characters = "Retrieving characters",
        validating_characters = "Validating characters",

        -- Notifications
        ran_into_issue = "We ran into an issue",
        profanity = "It seems like you are trying to use some type of profanity / bad words in your name or nationality!",
        forgotten_field = "It seems like you have forgotten to input one or multiple of the fields!"
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})


