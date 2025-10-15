(function () {
    const root = document.getElementById('creator');
    const form = document.getElementById('character-form');
    const cancelButton = document.getElementById('cancel');
    const nationalityInput = document.getElementById('nationality-input');
    const nationalitySelect = document.getElementById('nationality-select');
    const genderSelect = document.getElementById('gender');

    const state = {
        slot: null,
        customNationality: false,
        translations: {},
        nationalities: [],
    };

    const callbacks = {
        onSubmit: () => {},
        onCancel: () => {},
    };

    function applyTranslations() {
        const map = state.translations || {};

        const selectors = [
            { selector: '[data-translate="creator_title"]', key: 'creator_title' },
            { selector: '[data-translate="creator_subtitle"]', key: 'creator_subtitle' },
            { selector: '[data-translate="firstname_label"]', key: 'firstname_label' },
            { selector: '[data-translate="lastname_label"]', key: 'lastname_label' },
            { selector: '[data-translate="nationality_label"]', key: 'nationality_label' },
            { selector: '[data-translate="birthdate_label"]', key: 'birthdate_label' },
            { selector: '[data-translate="gender_label"]', key: 'gender_label' },
            { selector: '#cancel', key: 'cancel' },
            { selector: '[data-translate="create_button"]', key: 'create_button' },
        ];

        selectors.forEach(({ selector, key }) => {
            const el = root.querySelector(selector);
            if (el && map[key]) {
                el.textContent = map[key];
            }
        });

        if (nationalityInput) {
            nationalityInput.placeholder = map.nationality_placeholder || 'Nationality';
        }
    }

    function refreshGenderOptions() {
        if (!genderSelect) return;

        const options = [
            { key: 'male', value: state.translations.male || 'Male' },
            { key: 'female', value: state.translations.female || 'Female' },
        ];

        genderSelect.innerHTML = '';
        options.forEach((opt) => {
            const option = document.createElement('option');
            option.value = opt.value;
            option.textContent = opt.value;
            genderSelect.appendChild(option);
        });
    }

    function updateNationalityField() {
        if (!nationalityInput || !nationalitySelect) return;

        if (state.customNationality) {
            nationalityInput.classList.remove('hidden');
            nationalityInput.required = true;
            nationalitySelect.classList.add('hidden');
            nationalitySelect.required = false;
        } else {
            nationalityInput.classList.add('hidden');
            nationalityInput.required = false;
            nationalitySelect.classList.remove('hidden');
            nationalitySelect.required = true;

            nationalitySelect.innerHTML = '';
            state.nationalities.forEach((country) => {
                const option = document.createElement('option');
                option.value = country;
                option.textContent = country;
                nationalitySelect.appendChild(option);
            });
        }
    }

    function setDefaultValues() {
        if (!genderSelect) return;
        if (genderSelect.options.length > 0) {
            genderSelect.selectedIndex = 0;
        }

        if (nationalitySelect && !state.customNationality) {
            nationalitySelect.selectedIndex = 0;
        }

        if (nationalityInput && state.customNationality) {
            nationalityInput.value = '';
        }

        const today = new Date(Date.now() - new Date().getTimezoneOffset() * 60000)
            .toISOString()
            .split('T')[0];
        const birthdate = document.getElementById('birthdate');
        if (birthdate) {
            birthdate.value = today;
        }
    }

    function collectFormData() {
        const formData = new FormData(form);

        const firstname = (formData.get('firstname') || '').trim();
        const lastname = (formData.get('lastname') || '').trim();

        let nationality;
        if (state.customNationality) {
            nationality = (nationalityInput?.value || '').trim();
        } else {
            nationality = nationalitySelect?.value || '';
        }

        const payload = {
            slot: state.slot,
            firstname,
            lastname,
            nationality,
            date: formData.get('birthdate'),
            gender: formData.get('gender'),
        };

        return payload;
    }

    const CharCreatorUI = {
        init(options = {}) {
            Object.assign(callbacks, options);

            if (form) {
                form.addEventListener('submit', (event) => {
                    event.preventDefault();
                    const payload = collectFormData();
                    callbacks.onSubmit(payload);
                });
            }

            if (cancelButton) {
                cancelButton.addEventListener('click', (event) => {
                    event.preventDefault();
                    callbacks.onCancel();
                });
            }

            document.addEventListener('keydown', (event) => {
                if (event.key === 'Escape' && !root.classList.contains('hidden')) {
                    callbacks.onCancel();
                }
            });
        },

        show(config = {}) {
            state.slot = config.slot;
            state.customNationality = Boolean(config.customNationality);
            state.nationalities = Array.isArray(config.nationalities) ? config.nationalities : [];

            if (config.translations) {
                state.translations = { ...state.translations, ...config.translations };
            }

            applyTranslations();
            refreshGenderOptions();
            updateNationalityField();
            if (form) {
                form.reset();
            }
            setDefaultValues();

            root?.classList.remove('hidden');
            root?.setAttribute('aria-hidden', 'false');
        },

        hide() {
            root?.classList.add('hidden');
            root?.setAttribute('aria-hidden', 'true');
            if (form) {
                form.reset();
            }
            state.slot = null;
        },

        setTranslations(translations = {}) {
            state.translations = { ...state.translations, ...translations };
            applyTranslations();
            refreshGenderOptions();
        },

        setNationalities(list = [], customNationality = false) {
            state.nationalities = Array.isArray(list) ? list : [];
            state.customNationality = Boolean(customNationality);
            updateNationalityField();
        },
    };

    window.CharCreatorUI = CharCreatorUI;
})();
