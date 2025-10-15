const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ws-multicharacter';
const MAX_SLOTS = 3;

const postNui = (endpoint, payload = {}) =>
    fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload),
    });

const loadingScreen = document.getElementById('loading-screen');
const loadingText = document.getElementById('loading-text');

const state = {
    characters: {},
    characterAmount: MAX_SLOTS,
    selectedIndex: null,
    allowDelete: false,
    customNationality: false,
    nationalities: [],
    translations: {},
    chardata: {},
    premiumSlotIndex: null,
    premiumSlotIsFree: false,
    brandName: 'WOLFSTUDIO',
    portraitConfig: null,
};

const currencyFormatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0,
});

function setBodyActive(active) {
    document.body.classList.toggle('nui-active', active);
    document.body.style.display = active ? 'flex' : 'none';
}

function showLoading(textKey) {
    if (!loadingScreen) return;
    if (textKey) {
        loadingText.textContent = translationManager.translate(textKey);
    }
    loadingScreen.classList.remove('hidden');
}

function updateLoading(textKey) {
    if (loadingText && textKey) {
        loadingText.textContent = translationManager.translate(textKey);
    }
}

function hideLoading() {
    loadingScreen?.classList.add('hidden');
}

function closeInterfaceToGame() {
    hideLoading();
    CharCreatorUI.hide();
    CharSelectUI.hide();
    setBodyActive(false);
}

function parseMetadata(metadata) {
    if (!metadata) return {};
    if (typeof metadata === 'object') return metadata;
    try {
        return JSON.parse(metadata);
    } catch (error) {
        return {};
    }
}

function formatPlaytime(minutes) {
    const totalMinutes = Number(minutes) || 0;
    if (totalMinutes <= 0) {
        return '0 h, 0 min';
    }
    const hours = Math.floor(totalMinutes / 60);
    const mins = Math.floor(totalMinutes % 60);
    return `${hours} h, ${mins} min`;
}

function formatDate(value) {
    if (!value) return '---';
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return value;
    }
    return date.toLocaleDateString('de-DE');
}

function resolveGenderLabel(gender) {
    if (typeof gender === 'number') {
        return gender === 0 ? translationManager.translate('male') : translationManager.translate('female');
    }

    const lower = (gender || '').toString().toLowerCase();
    if (lower.startsWith('m')) return translationManager.translate('male');
    if (lower.startsWith('f')) return translationManager.translate('female');
    return translationManager.translate('other') || 'Other';
}

function resolveGenderKey(gender) {
    if (typeof gender === 'number') {
        return gender === 0 ? 'male' : 'female';
    }

    const lower = (gender || '').toString().toLowerCase();
    if (lower.startsWith('m')) return 'male';
    if (lower.startsWith('f')) return 'female';
    if (lower.startsWith('d')) return 'other';
    return 'other';
}

function buildSlotData() {
    const slots = [];
    const slotCount = Math.min(MAX_SLOTS, state.characterAmount || MAX_SLOTS);

    for (let index = 1; index <= slotCount; index += 1) {
        const char = state.characters[index];
        const isPremiumCandidate = typeof state.premiumSlotIndex === 'number' && index === state.premiumSlotIndex;
        const isPremium = Boolean(isPremiumCandidate && !state.premiumSlotIsFree);
        const banner = translationManager.formatTranslation('slot_label', { index });

        if (char) {
            const charinfo = char.charinfo || {};
            const metadata = parseMetadata(char.metadata);
            const jobLabel = char.job?.label || translationManager.translate('job_unemployed') || 'Unemployed';

            const firstname = (charinfo.firstname || '').trim();
            const lastname = (charinfo.lastname || '').trim();

            const slot = {
                index,
                state: 'occupied',
                isPremium,
                banner,
                nameParts: {
                    first: firstname || translationManager.translate('unknown_character'),
                    last: lastname,
                },
                jobLabel,
                stats: [
                    {
                        key: 'cash',
                        label: translationManager.translate('stat_cash'),
                        value: currencyFormatter.format(char.money?.cash || 0),
                    },
                    {
                        key: 'bank',
                        label: translationManager.translate('stat_bank'),
                        value: currencyFormatter.format(char.money?.bank || 0),
                    },
                    {
                        key: 'birthdate',
                        label: translationManager.translate('stat_birthdate'),
                        value: formatDate(charinfo.birthdate),
                    },
                    {
                        key: 'nationality',
                        label: translationManager.translate('stat_nationality'),
                        value: charinfo.nationality || '---',
                    },
                    {
                        key: 'gender',
                        label: translationManager.translate('stat_gender'),
                        value: resolveGenderLabel(charinfo.gender),
                    },
                ],
                gender: resolveGenderKey(charinfo.gender),
                character: char,
                primaryLabel: translationManager.translate('select_character'),
                secondaryLabel: translationManager.translate('delete_character'),
            };

            if (metadata.isbanned || metadata.banInfo) {
                const reason = metadata.banInfo?.reason || 'No reason provided';
                const expires = metadata.banInfo?.expires || 'N/A';
                slot.notice = `${translationManager.translate('banned_notice') || 'Account banned.'}<span>${translationManager.formatTranslation('banned_reason', { reason })}<br />${translationManager.formatTranslation('banned_expires', { expires })}</span>`;
            }

            slots.push(slot);
        } else {
            const emptyTitle = translationManager.translate(isPremium ? 'premium_slot_title' : 'free_slot_title');
            const primaryLabel = translationManager.translate(isPremium ? 'premium_slot_button' : 'create_button');

            slots.push({
                index,
                state: 'empty',
                isPremium,
                banner,
                emptyTitle,
                description: '',
                stats: [
                    {
                        key: 'cash',
                        label: translationManager.translate('stat_cash'),
                        value: currencyFormatter.format(0),
                    },
                    {
                        key: 'bank',
                        label: translationManager.translate('stat_bank'),
                        value: currencyFormatter.format(0),
                    },
                    {
                        key: 'birthdate',
                        label: translationManager.translate('stat_birthdate'),
                        value: '---',
                    },
                    {
                        key: 'nationality',
                        label: translationManager.translate('stat_nationality'),
                        value: '---',
                    },
                    {
                        key: 'gender',
                        label: translationManager.translate('stat_gender'),
                        value: translationManager.translate('other'),
                    },
                ],
                gender: 'other',
                primaryLabel,
                meta: translationManager.translate(isPremium ? 'premium_slot_hint' : 'free_slot_hint'),
            });
        }
    }

    return slots;
}

function applyUiTranslations() {
    const title = document.querySelector('[data-translate="ui_title"]');
    const subtitle = document.querySelector('[data-translate="ui_subtitle"]');
    if (title) {
        const brand = state.brandName || translationManager.translate('brand_name') || 'WOLFSTUDIO';
        let suffix = translationManager.translate('brand_suffix');
        if (!suffix || suffix === 'brand_suffix') {
            const fallbackTitle = translationManager.translate('ui_title');
            const match = fallbackTitle && fallbackTitle.match(/<span>(.*?)<\/span>/i);
            suffix = match ? match[1] : fallbackTitle.replace(brand, '').trim();
            if (!suffix || suffix === fallbackTitle) {
                suffix = 'Character Management';
            }
        }
        title.innerHTML = `${brand} <span>${suffix}</span>`;
    }
    if (subtitle) {
        subtitle.textContent = translationManager.translate('ui_subtitle');
    }

    CharSelectUI.configure({
        allowDelete: state.allowDelete,
        translations: {
            selectCharacter: translationManager.translate('select_character'),
            deleteCharacter: translationManager.translate('delete_character'),
            createCharacter: translationManager.translate('create_button'),
            disconnect: translationManager.translate('disconnect'),
            premiumLabel: translationManager.translate('premium_slot_badge'),
        },
        portraits: state.portraitConfig,
    });

    CharCreatorUI.setTranslations({
        creator_title: translationManager.translate('creator_title'),
        creator_subtitle: translationManager.translate('creator_subtitle'),
        firstname_label: translationManager.translate('firstname'),
        lastname_label: translationManager.translate('lastname'),
        nationality_label: translationManager.translate('nationality'),
        birthdate_label: translationManager.translate('birthdate'),
        gender_label: translationManager.translate('gender'),
        cancel: translationManager.translate('cancel'),
        create_button: translationManager.translate('create_button'),
        male: translationManager.translate('male'),
        female: translationManager.translate('female'),
        nationality_placeholder: translationManager.translate('nationality_placeholder'),
    });

    refreshSlots();
}

function refreshSlots() {
    const slots = buildSlotData();

    if (slots.length === 0) {
        state.selectedIndex = null;
    } else if (!state.selectedIndex || state.selectedIndex > slots.length) {
        const occupied = slots.find((slot) => slot.state === 'occupied');
        state.selectedIndex = occupied ? occupied.index : 1;
    }

    CharSelectUI.setSlots(slots, state.selectedIndex);

    const selectedSlot = slots.find((slot) => slot.index === state.selectedIndex);
    if (selectedSlot) {
        CharSelectUI.setSelected(selectedSlot.index, { silent: true });
        previewSlot(selectedSlot);
    }
}

function previewSlot(slot) {
    if (slot.state === 'occupied' && slot.character) {
        postNui('cDataPed', { cData: slot.character });
    } else {
        postNui('cDataPed', {});
    }
}

function openCreator(slot) {
    CharSelectUI.hide();
    CharCreatorUI.show({
        slot: slot.index,
        customNationality: state.customNationality,
        nationalities: state.nationalities,
        translations: {
            creator_title: translationManager.translate('creator_title'),
            creator_subtitle: translationManager.translate('creator_subtitle'),
            firstname_label: translationManager.translate('firstname'),
            lastname_label: translationManager.translate('lastname'),
            nationality_label: translationManager.translate('nationality'),
            birthdate_label: translationManager.translate('birthdate'),
            gender_label: translationManager.translate('gender'),
            cancel: translationManager.translate('cancel'),
            create_button: translationManager.translate('create_button'),
            male: translationManager.translate('male'),
            female: translationManager.translate('female'),
            nationality_placeholder: translationManager.translate('nationality_placeholder'),
        },
    });
}

function closeCreator() {
    CharCreatorUI.hide();
    CharSelectUI.show();
}

function handleCharacterCreation(payload) {
    if (!payload) return;

    const validationResult = characterValidator.validateCharacter({
        firstname: payload.firstname,
        lastname: payload.lastname,
        nationality: payload.nationality,
        gender: payload.gender,
        date: payload.date,
    });

    if (!validationResult.isValid) {
        Swal.fire({
            icon: 'error',
            title: translationManager.translate('ran_into_issue'),
            text: translationManager.formatTranslation(validationResult.message, { field: translationManager.translate(validationResult.field) }),
            timer: 5000,
            timerProgressBar: true,
            showConfirmButton: false,
        });
        return;
    }

    closeCreator();
    showLoading('validating_characters');

    postNui('createNewCharacter', {
        firstname: payload.firstname,
        lastname: payload.lastname,
        nationality: payload.nationality,
        birthdate: payload.date,
        gender: payload.gender,
        cid: payload.slot,
    });
}

function handleCharacterSelection(slot) {
    if (!slot || slot.state !== 'occupied' || !slot.character) {
        openCreator(slot);
        return;
    }

    CharSelectUI.hide();
    closeInterfaceToGame();
    postNui('selectCharacter', { cData: slot.character });
}

function handleDelete(slot) {
    if (!slot || slot.state !== 'occupied' || !slot.character) return;

    Swal.fire({
        icon: 'warning',
        title: translationManager.translate('deletechar_title'),
        text: translationManager.translate('deletechar_description'),
        showCancelButton: true,
        confirmButtonText: translationManager.translate('confirm'),
        cancelButtonText: translationManager.translate('cancel'),
        confirmButtonColor: '#e74c3c',
        reverseButtons: true,
    }).then((result) => {
        if (result.isConfirmed) {
            showLoading('validating_playerdata');
            postNui('removeCharacter', { citizenid: slot.character.citizenid });
        }
    });
}

function handleUiToggle(payload) {
    state.customNationality = Boolean(payload.customNationality);
    state.allowDelete = Boolean(payload.enableDeleteButton);
    const availableSlots = Number(payload.nChar || 0) || MAX_SLOTS;
    state.characterAmount = Math.min(MAX_SLOTS, availableSlots || MAX_SLOTS);
    state.nationalities = Array.isArray(payload.countries) ? payload.countries : [];
    state.translations = payload.translations || {};
    state.brandName = payload.brandName || state.brandName;
    const slotIndex = Number(payload.premiumSlotIndex);
    state.premiumSlotIndex = Number.isFinite(slotIndex) && slotIndex > 0 ? slotIndex : null;
    state.premiumSlotIsFree = Boolean(payload.premiumSlotIsFree);
    state.portraitConfig = payload.portraits || null;

    translationManager.setTranslations(payload.translations || {});

    applyUiTranslations();
    CharCreatorUI.setNationalities(state.nationalities, state.customNationality);

    if (payload.toggle) {
        state.selectedIndex = null;
        setBodyActive(true);
        CharCreatorUI.hide();
        CharSelectUI.show();
        showLoading('retrieving_playerdata');

        setTimeout(() => {
            updateLoading('retrieving_characters');
            postNui('setupCharacters');
        }, 300);
    } else {
        hideLoading();
        CharCreatorUI.hide();
        CharSelectUI.hide();
        CharSelectUI.clear();
        setBodyActive(false);
        state.characters = {};
        state.chardata = {};
        state.selectedIndex = null;
    }
}

function handleSetupCharacters(payload) {
    hideLoading();

    state.characters = {};
    (payload.characters || []).forEach((character) => {
        if (character && character.cid) {
            const slotIndex = Number(character.cid);
            if (Number.isFinite(slotIndex) && slotIndex >= 1 && slotIndex <= MAX_SLOTS) {
                state.characters[slotIndex] = character;
            }
        }
    });

    refreshSlots();
    CharSelectUI.show();
    postNui('removeBlur');
}

function handleSetupCharInfo(payload) {
    state.chardata = payload.chardata || {};
}

window.addEventListener('DOMContentLoaded', () => {
    initializeValidator();

    CharSelectUI.init({
        onPreview: (slot) => {
            state.selectedIndex = slot.index;
            previewSlot(slot);
        },
        onPlay: (slot) => {
            state.selectedIndex = slot.index;
            handleCharacterSelection(slot);
        },
        onCreate: (slot) => {
            state.selectedIndex = slot.index;
            openCreator(slot);
        },
        onDelete: (slot) => {
            handleDelete(slot);
        },
        onDisconnect: () => {
            postNui('disconnectButton', {});
        },
    });

    CharCreatorUI.init({
        onSubmit: (payload) => {
            handleCharacterCreation(payload);
        },
        onCancel: () => {
            closeCreator();
            CharSelectUI.show();
        },
    });

    document.body.style.display = 'none';
});

window.addEventListener('message', (event) => {
    const data = event.data || {};

    switch (data.action) {
        case 'ui':
            handleUiToggle(data);
            break;
        case 'setupCharacters':
            handleSetupCharacters(data);
            break;
        case 'setupCharInfo':
            handleSetupCharInfo(data);
            break;
        case 'forceClose':
            closeInterfaceToGame();
            state.characters = {};
            state.chardata = {};
            state.selectedIndex = null;
            CharSelectUI.clear();
            break;
        default:
            break;
    }
});
