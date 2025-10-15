local Translations = {
    notifications = {
        ["char_deleted"] = "Charakter geloescht!",
        ["deleted_other_char"] = "Du hast den Charakter mit der Buerger-ID %{citizenid} erfolgreich geloescht.",
        ["forgot_citizenid"] = "Du hast vergessen, eine Buerger-ID einzugeben!",
    },

    commands = {
        -- /deletechar
        ["deletechar_description"] = "Loescht den Charakter eines anderen Spielers",
        ["citizenid"] = "Buerger-ID",
        ["citizenid_help"] = "Die Buerger-ID des Charakters, den du loeschen moechtest",

        -- /logout
        ["logout_description"] = "Charakter abmelden (nur Admin)",

        -- /closeNUI
        ["closeNUI_description"] = "Multi-NUI schliessen"
    },

    misc = {
        ["droppedplayer"] = "Du wurdest von QBCore getrennt"
    },

    ui = {
        -- Main
        characters_header = "Meine Charaktere",
        emptyslot = "Freier Slot",
        play_button = "Spielen",
        create_button = "Charakter erstellen",
        delete_button = "Charakter loeschen",
        select_character = "Charakter auswaehlen",
        disconnect = "Trennen",
        brand_name = "WOLFSTUDIO",
        brand_suffix = "Charakterverwaltung",
        ui_title = "%{brand} <span>Charakterverwaltung</span>",
        ui_subtitle = "Waehle einen bestehenden Charakter oder erstelle einen neuen Slot.",

        -- Character Information
        charinfo_header = "Charakterinformationen",
        charinfo_description = "Waehle einen Charakter-Slot, um alle Informationen ueber deinen Charakter zu sehen.",
        name = "Name",
        male = "Maennlich",
        female = "Weiblich",
        firstname = "Vorname",
        lastname = "Nachname",
        nationality = "Nationalitaet",
        gender = "Geschlecht",
        birthdate = "Geburtsdatum",
        job = "Beruf",
        jobgrade = "Berufsstufe",
        cash = "Bargeld",
        bank = "Bank",
        phonenumber = "Telefonnummer",
        accountnumber = "Kontonummer",
        nationality_placeholder = "Nationalitaet",
        job_unemployed = "Arbeitslos",
        unknown_character = "Unbekannter Charakter",
        other = "Divers",
        stat_cash = "Bargeld",
        stat_bank = "Kreditkarte",
        stat_birthdate = "Geburtsdatum",
        stat_nationality = "Nationalitaet",
        stat_gender = "Geschlecht",
        banned_notice = "Du bist auf diesem Charakter gebannt.",
        banned_reason = "Grund: %{reason}",
        banned_expires = "Laeuft ab: %{expires}",
        slot_label = "Charakter Slot #%{index}",
        free_slot_title = "Freier Slot",
        premium_slot_title = "Freier Slot",
        free_slot_hint = "Charakter Slot fuer neue Bewohner",
        premium_slot_hint = "Charakter Slot fuer neue Bewohner",
        premium_slot_button = "Charakter erstellen",
        premium_slot_badge = "Freier Slot",
        creator_title = "Neuen Charakter erstellen",
        creator_subtitle = "Fuelle die Basisinformationen aus. Aussehen und weitere Optionen folgen im naechsten Schritt.",

        chardel_header = "Charakterregistrierung",

        -- Delete character
        deletechar_header = "Charakter loeschen",
        deletechar_description = "Bist du sicher, dass du deinen Charakter loeschen moechtest?",

        -- Buttons
        cancel = "Abbrechen",
        confirm = "Bestaetigen",

        -- Loading Text
        retrieving_playerdata = "Spielerdaten werden abgerufen",
        validating_playerdata = "Spielerdaten werden ueberprueft",
        retrieving_characters = "Charaktere werden abgerufen",
        validating_characters = "Charaktere werden ueberprueft",

        -- Notifications
        ran_into_issue = "Wir haben ein Problem festgestellt",
        profanity = "Es scheint, als wuerdest du unangebrachte Begriffe in deinem Namen oder deiner Nationalitaet verwenden!",
        forgotten_field = "Es scheint, als haettest du eines oder mehrere Felder vergessen auszufuellen!"
    }
}

if GetConvar('qb_locale', 'en') == 'de' then
    Lang = Locale:new({
        phrases = Translations,
        warnOnMissing = true,
        fallbackLang = Lang,
    })
end
