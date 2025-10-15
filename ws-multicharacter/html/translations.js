/**
 * Translations utility for ws-multicharacter
 * Handles all translation functionality in one place
 */

class TranslationManager {
    constructor() {
        this.translations = {};
        this.fallbacks = {
            // Core prompts
            deletechar_description: "Bist du sicher, dass du diesen Charakter loeschen moechtest?",
            deletechar_title: "Charakter loeschen?",
            confirm: "Confirm",
            cancel: "Cancel",
            chardel_header: "Character Registration",
            firstname: "First Name",
            lastname: "Last Name",
            nationality: "Nationality",
            birthdate: "Date of Birth",
            gender: "Gender",
            male: "Male",
            female: "Female",
            create_button: "Create Character",
            retrieving_playerdata: "Retrieving player data...",
            validating_playerdata: "Validating player data...",
            retrieving_characters: "Retrieving characters...",
            validating_characters: "Validating characters...",
            ran_into_issue: "We ran into an issue!",
            profanity: "Your inputs contain profanity. Please try again.",
            forgotten_field: "You forgot to fill in a field!",
            connection_error: "Connection error. Please try again.",
            delete_failed: "Failed to delete character. Please try again.",
            selection_failed: "Failed to select character. Please try again.",
            creation_failed: "Failed to create character. Please try again.",
            setup_failed: "Failed to set up characters. Please try again.",

            // Validation
            firstname_too_short: "First name must be at least 2 characters long.",
            firstname_too_long: "First name cannot exceed 16 characters.",
            lastname_too_short: "Last name must be at least 2 characters long.",
            lastname_too_long: "Last name cannot exceed 16 characters.",
            invalid_date: "Please enter a valid date of birth.",
            date: "Date of Birth",
            field: "Field",

            // Headline & actions
            ui_title: "%{brand} <span>Character Management</span>",
            brand_name: "WOLFSTUDIO",
        brand_suffix: "Character Management",
        ui_subtitle: "Waehle einen bestehenden Charakter oder erstelle einen neuen Slot.",
            select_character: "Select Character",
            delete_character: "Delete Character",
            disconnect: "Disconnect",

            // Slot descriptors
            occupied_description: "Dieser Slot ist bereits belegt. Wenn du den Charakter loeschst, gehen alle zugehoerigen Gegenstaende dauerhaft verloren.",
            free_slot_title: "Free Slot",
            free_slot_desc: "Dieser Slot ist kostenlos fuer die Charaktererstellung. Beim Entfernen werden alle Besitztuemer geloescht.",
            free_slot_hint: "Charakter Slot fuer neue Bewohner",
            premium_slot_title: "Free Slot",
            premium_slot_desc: "Dieser Slot ist kostenlos fuer die Charaktererstellung. Beim Entfernen werden alle Besitztuemer geloescht.",
            premium_slot_hint: "Charakter Slot fuer neue Bewohner",
            premium_slot_button: "Create Character",
            premium_slot_badge: "Free Slot",
            creator_title: "Neuen Charakter erstellen",
            creator_subtitle: "Fuelle die Basisinformationen aus. Aussehen und weitere Optionen folgen im naechsten Schritt.",
            nationality_placeholder: "Nationality",
            job_unemployed: "Unemployed",
            unknown_character: "Unknown Character",

            // Stats
            stat_hours: "Hours in the game",
            stat_cash: "Cash",
            stat_bank: "Credit Card",
            stat_birthdate: "Birthdate",
            stat_nationality: "Nationality",
            stat_gender: "Gender",
            other: "Other",

            // Ban messaging
            banned_notice: "You are banned from this character.",
            banned_reason: "Reason: {reason}",
            banned_expires: "Expires: {expires}",

            // Misc
            slot_label: "Character Slot #{index}",
        };
    }

    /**
     * Set translations from server
     * @param {Object} translations - Translation key-value pairs
     */
    setTranslations(translations) {
        this.translations = translations || {};
    }

    /**
     * Get translation for a key
     * @param {string} key - Translation key
     * @returns {string} Translated text or fallback
     */
    translate(key) {
        // First check in server-provided translations
        if (this.translations[key]) {
            return this.translations[key];
        }

        // Then check in fallbacks
        if (this.fallbacks[key]) {
            return this.fallbacks[key];
        }

        // Return the key itself if no translation found
        return key;
    }

    /**
     * Format a translation with dynamic values
     * @param {string} key - Translation key
     * @param {Object} params - Object containing replacement values
     * @returns {string} Formatted translation
     */
    formatTranslation(key, params) {
        let text = this.translate(key);

        if (params) {
            Object.keys(params).forEach((param) => {
                text = text.replace(`{${param}}`, params[param]);
            });
        }

        return text;
    }
}

// Create a global instance for the application
const translationManager = new TranslationManager();

