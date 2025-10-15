(function () {
    const resourceTranslations = {
        selectCharacter: 'Select Character',
        deleteCharacter: 'Delete Character',
        createCharacter: 'Create Character',
        disconnect: 'Disconnect',
        premiumLabel: 'Free Slot',
    };

    const defaultPortraitConfig = {
        male: [
            'https://cdn.discordapp.com/attachments/1337012310870327397/1427673548566036550/Screenshot_2025-10-14_170300.png?ex=68efb81a&is=68ee669a&hm=b965cd449dd64be68097f6fe7e52cf0fb81628c638bc92d142bf7cfe74d22309&',
            'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549400965160/Screenshot_2025-10-14_170404.png?ex=68efb81b&is=68ee669b&hm=8524ede899e82763f046d341eaf94de2ee2093fb85edcf549a80317ff6b793d0&',
        ],
        female: [
            'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549019156480/Screenshot_2025-10-14_170336.png?ex=68efb81a&is=68ee669a&hm=427acc187e63dd88e01c443e0247aa294cacac7a763f09cb84b7c7fee1c76379&',
        ],
        other: [
            'https://cdn.discordapp.com/attachments/1337012310870327397/1427673549019156480/Screenshot_2025-10-14_170336.png?ex=68efb81a&is=68ee669a&hm=427acc187e63dd88e01c443e0247aa294cacac7a763f09cb84b7c7fee1c76379&',
        ],
    };

    let portraitFallbacks = JSON.parse(JSON.stringify(defaultPortraitConfig));
    let defaultPortraits = [...portraitFallbacks.other];

    function applyPortraitConfig(config) {
        if (!config || typeof config !== 'object') {
            portraitFallbacks = JSON.parse(JSON.stringify(defaultPortraitConfig));
            defaultPortraits = [...portraitFallbacks.other];
            return;
        }

        const normalized = {
            male: Array.isArray(config.male) && config.male.length > 0 ? config.male : defaultPortraitConfig.male,
            female: Array.isArray(config.female) && config.female.length > 0 ? config.female : defaultPortraitConfig.female,
            other: Array.isArray(config.other) && config.other.length > 0 ? config.other : defaultPortraitConfig.other,
        };

        portraitFallbacks = normalized;
        if (Array.isArray(config.default) && config.default.length > 0) {
            defaultPortraits = config.default;
        } else {
            defaultPortraits = [...normalized.other];
        }
    }

    applyPortraitConfig();

    function resolvePortrait(slot) {
        if (slot.portrait) {
            return slot.portrait;
        }

        const genderKey = (slot.gender || '').toLowerCase();
        const pool = portraitFallbacks[genderKey] || portraitFallbacks.other || defaultPortraits;
        return pool[(slot.index - 1) % pool.length] || defaultPortraits[0];
    }

    const root = document.getElementById('charselect');
    const slotWrapper = root ? root.querySelector('#slot-wrapper') : null;
    const disconnectButton = document.getElementById('disconnect-button');

    const state = {
        slots: [],
        selectedIndex: null,
        allowDelete: false,
        translations: { ...resourceTranslations },
    };

    const callbacks = {
        onPreview: () => { },
        onPlay: () => { },
        onCreate: () => { },
        onDelete: () => { },
        onDisconnect: () => { },
    };

    function applyTranslationsToStaticElements() {
        if (disconnectButton) {
            disconnectButton.textContent = state.translations.disconnect || resourceTranslations.disconnect;
        }
    }

    function highlightSelected() {
        if (!slotWrapper) return;
        slotWrapper.querySelectorAll('.slot-card').forEach((card) => {
            const idx = Number(card.dataset.slot || 0);
            card.classList.toggle('selected', idx === state.selectedIndex);
        });
    }

    function handleCardClick(slot) {
        if (slot.state !== 'occupied') {
            state.selectedIndex = slot.index;
            highlightSelected();
            callbacks.onPreview(slot);
            return;
        }

        if (state.selectedIndex !== slot.index) {
            state.selectedIndex = slot.index;
            highlightSelected();
            callbacks.onPreview(slot);
        }
    }

    function renderSlot(slot) {
        const card = document.createElement('article');
        card.className = `slot-card ${slot.state}`;
        card.dataset.slot = String(slot.index);

        if (slot.isPremium) {
            card.classList.add('premium');
        }

        if (slot.index === state.selectedIndex) {
            card.classList.add('selected');
        }

        const banner = document.createElement('span');
        banner.className = 'slot-label';
        banner.textContent = slot.banner || `Slot ${slot.index}`;
        card.appendChild(banner);

        if (slot.isPremium) {
            const pill = document.createElement('span');
            pill.className = 'premium-pill';
            pill.textContent = state.translations.premium_slot_badge || resourceTranslations.premiumLabel;
            card.appendChild(pill);
        }

        const portrait = document.createElement('img');
        portrait.className = 'portrait';
        portrait.alt = slot.nameParts?.first || slot.emptyTitle || `Slot ${slot.index}`;
        portrait.src = resolvePortrait(slot);
        card.appendChild(portrait);

        if (slot.state === 'occupied') {
            const name = document.createElement('h2');
            name.className = 'character-name';

            const firstSpan = document.createElement('span');
            firstSpan.className = 'first';
            firstSpan.textContent = (slot.nameParts?.first || '').toUpperCase();
            name.appendChild(firstSpan);

            if (slot.nameParts?.last) {
                const lastSpan = document.createElement('span');
                lastSpan.className = 'last';
                lastSpan.textContent = slot.nameParts.last.toUpperCase();
                name.append(' ');
                name.appendChild(lastSpan);
            }

            card.appendChild(name);

            if (slot.jobLabel) {
                const meta = document.createElement('p');
                meta.className = 'slot-meta';
                meta.textContent = slot.jobLabel;
                card.appendChild(meta);
            }
        } else {
            const title = document.createElement('h2');
            title.className = 'slot-title';
            title.textContent = slot.emptyTitle || `Slot ${slot.index}`;
            card.appendChild(title);

            if (slot.meta) {
                const meta = document.createElement('p');
                meta.className = 'slot-meta';
                meta.textContent = slot.meta;
                card.appendChild(meta);
            }
        }

        if (slot.description) {
            const description = document.createElement('p');
            description.className = 'slot-description';
            description.textContent = slot.description;
            card.appendChild(description);
        }

        if (slot.stats && slot.stats.length) {
            const stats = document.createElement('div');
            stats.className = 'stat-list';

            slot.stats.forEach((item) => {
                const row = document.createElement('div');
                row.className = 'stat-row';

                const label = document.createElement('span');
                label.className = 'label';
                label.textContent = item.label;

                const value = document.createElement('span');
                value.className = 'value';
                value.textContent = item.value;

                row.appendChild(label);
                row.appendChild(value);
                stats.appendChild(row);
            });

            card.appendChild(stats);
        }

        if (slot.notice) {
            const notice = document.createElement('div');
            notice.className = 'notice';
            notice.innerHTML = slot.notice;
            card.appendChild(notice);
        } else if (slot.state === 'empty') {
            const description = document.createElement('p');
            description.className = 'empty-description';
            description.textContent = slot.description || state.translations.emptyDescription || resourceTranslations.emptyDescription;
            card.appendChild(description);
        }

        const actions = document.createElement('div');
        actions.className = 'slot-actions';

        const primary = document.createElement('button');
        primary.className = 'slot-button primary';
        if (slot.isPremium && slot.state === 'empty') {
            primary.classList.add('premium');
        }
        primary.textContent = slot.primaryLabel
            || (slot.state === 'occupied'
                ? state.translations.selectCharacter || resourceTranslations.selectCharacter
                : state.translations.createCharacter || resourceTranslations.createCharacter);

        primary.addEventListener('click', (event) => {
            event.stopPropagation();
            if (slot.state === 'occupied') {
                state.selectedIndex = slot.index;
                highlightSelected();
                callbacks.onPlay(slot);
            } else {
                state.selectedIndex = slot.index;
                highlightSelected();
                callbacks.onCreate(slot);
            }
        });

        actions.appendChild(primary);

        if (slot.state === 'occupied') {
            const secondary = document.createElement('button');
            secondary.className = 'slot-button secondary';
            secondary.textContent = slot.secondaryLabel || state.translations.deleteCharacter || resourceTranslations.deleteCharacter;
            secondary.disabled = !state.allowDelete;

            secondary.addEventListener('click', (event) => {
                event.stopPropagation();
                if (!state.allowDelete) return;
                callbacks.onDelete(slot);
            });

            actions.appendChild(secondary);
        }

        card.appendChild(actions);

        card.addEventListener('click', (event) => {
            if (event.target.closest('.slot-button')) {
                return;
            }
            handleCardClick(slot);
        });

        return card;
    }

    function render() {
        if (!slotWrapper) {
            return;
        }

        slotWrapper.innerHTML = '';
        state.slots.forEach((slot) => {
            slotWrapper.appendChild(renderSlot(slot));
        });

        highlightSelected();
    }

    const CharSelectUI = {
        init(options = {}) {
            Object.assign(callbacks, options);

            if (disconnectButton) {
                disconnectButton.addEventListener('click', (event) => {
                    event.preventDefault();
                    callbacks.onDisconnect();
                });
            }
        },

        configure(config = {}) {
            if (typeof config.allowDelete === 'boolean') {
                state.allowDelete = config.allowDelete;
            }

            if (config.translations) {
                state.translations = { ...state.translations, ...config.translations };
                applyTranslationsToStaticElements();
            }

            applyPortraitConfig(config.portraits);
        },

        setSlots(slots = [], selectedIndex) {
            state.slots = Array.isArray(slots) ? slots : [];
            if (typeof selectedIndex === 'number') {
                state.selectedIndex = selectedIndex;
            } else {
                state.selectedIndex = null;
            }
            render();
        },

        show() {
            root?.classList.remove('hidden');
        },

        hide() {
            root?.classList.add('hidden');
        },

        setSelected(index, opts = {}) {
            state.selectedIndex = index;
            highlightSelected();
            if (!opts.silent) {
                const slot = state.slots.find((s) => s.index === index);
                if (slot) {
                    callbacks.onPreview(slot);
                }
            }
        },

        clear() {
            state.slots = [];
            state.selectedIndex = null;
            if (slotWrapper) {
                slotWrapper.innerHTML = '';
            }
        },
    };

    window.CharSelectUI = CharSelectUI;
})();
