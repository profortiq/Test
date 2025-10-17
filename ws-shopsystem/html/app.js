const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'ws-shopsystem';

const state = {
    visible: false,
    view: 'shop',
    shop: null,
    meta: {},
    cart: [],
    selectedCategory: null,
    managementTab: 'dashboard',
    notifications: [],
    admin: {
        shops: [],
        selected: null,
        draft: null,
        dirty: false,
        createMode: false,
        view: 'dashboard',
        activeSection: 'general',
        pendingSelection: null,
        config: {
            shopTypes: {},
            vehicleTemplates: {},
            depots: [],
        },
    },
};

const clone = (value) => {
    try {
        return JSON.parse(JSON.stringify(value));
    } catch (error) {
        return value;
    }
};

const escapeHtml = (value) => {
    if (value === null || value === undefined) return '';
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
};

const managementTabs = [
    { key: 'dashboard', label: 'Dashboard' },
    { key: 'inventory', label: 'Lager' },
    { key: 'employees', label: 'Mitarbeiter' },
    { key: 'deliveries', label: 'Lieferungen' },
    { key: 'finance', label: 'Finanzen' },
    { key: 'vehicles', label: 'Fahrzeuge' },
];

const send = (action, data = {}) => {
    fetch(`https://${resourceName}/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    }).catch((error) => console.error('NUI send failed', action, error));
};

const nuiInvoke = async (action, data = {}) => {
    try {
        const response = await fetch(`https://${resourceName}/${action}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json; charset=UTF-8',
            },
            body: JSON.stringify(data),
        });
        if (!response.ok) return null;
        const payload = await response.json().catch(() => null);
        return payload;
    } catch (error) {
        return null;
    }
};

const currency = (value) => `$${Number(value || 0).toLocaleString('de-DE')}`;

let notificationSeq = 0;

const removeNotification = (id) => {
    const index = state.notifications.findIndex((entry) => entry.id === id);
    if (index === -1) return;
    state.notifications.splice(index, 1);
    renderNotifications();
};

const pushNotification = (message, type = 'info', duration = 5000) => {
    if (!message) return null;
    const id = `notif-${Date.now()}-${notificationSeq++}`;
    const entry = {
        id,
        message,
        type,
        expires: Date.now() + Math.max(duration || 0, 1500),
    };
    state.notifications.push(entry);
    renderNotifications();
    window.setTimeout(() => removeNotification(id), Math.max(duration || 0, 1500));
    return id;
};

const showNotification = (message, type = 'info', duration = 5000) => {
    pushNotification(message, type, duration);
};

const getCategories = () => {
    if (!state.shop || !state.shop.inventory) return [];
    return Object.entries(state.shop.inventory).map(([key, value]) => ({
        key,
        label: value.label || key,
        items: value.items || [],
    }));
};

const getInventoryItems = () => {
    const items = [];
    getCategories().forEach((category) => {
        category.items.forEach((item) => items.push(item));
    });
    return items;
};

const getItemById = (id) => {
    const categories = getCategories();
    for (const category of categories) {
        const item = category.items.find((product) => product.id === id);
        if (item) return item;
    }
    return null;
};

const calculateItemPricing = (item) => {
    const basePrice = Number(item?.overridePrice ?? item?.basePrice ?? 0);
    const shopDiscount = Number(state.shop?.discount ?? 0);
    const itemDiscount = Number(item?.discount ?? 0);
    const effectiveDiscount = itemDiscount > 0 ? itemDiscount : (shopDiscount > 0 ? shopDiscount : 0);
    const finalPrice = effectiveDiscount > 0 ? Math.max(0, Math.floor(basePrice * (100 - effectiveDiscount) / 100)) : basePrice;
    return {
        basePrice,
        finalPrice,
        discount: effectiveDiscount,
    };
};

const getVehicleOwnership = () => state.shop?.vehicleOwnership || {};

const isVehicleUnlocked = (vehicleKey) => Boolean(getVehicleOwnership()[vehicleKey]?.unlocked);

const getVehicleCapacity = (vehicleKey) => {
    const base = Number(state.shop?.deliveryVehicles?.[vehicleKey]?.capacity ?? 0);
    const levelBonus = Number(state.shop?.deliveryCapacityBonus ?? 0);
    const level = Number(state.shop?.level ?? 1);
    const bonus = levelBonus > 0 ? Math.max(0, level - 1) * levelBonus : 0;
    return base + bonus;
};

const getUnlockedVehicles = () => {
    const ownership = getVehicleOwnership();
    return Object.entries(state.shop?.deliveryVehicles || {})
        .filter(([key]) => ownership[key]?.unlocked)
        .map(([key, value]) => ({ key, ...value }));
};

const ensureSelectedCategory = () => {
    if (!state.selectedCategory) {
        const categories = getCategories();
        state.selectedCategory = categories[0]?.key ?? null;
    }
};

const cartTotal = () => state.cart.reduce((sum, item) => sum + item.price * item.quantity, 0);

const updateShopHeader = () => {
    const shop = state.shop;
    if (!shop) return;
    const typeConfig = shop.typeConfig || {};

    const nameElement = document.getElementById('shop-name');
    if (nameElement) nameElement.textContent = shop.label || 'Shop';

    const descriptionElement = document.getElementById('shop-description');
    if (descriptionElement) descriptionElement.textContent = typeConfig.label || '';

    const ownerElement = document.getElementById('shop-owner');
    if (ownerElement) ownerElement.textContent = shop.ownerName || 'Niemand';

    const discountValue = Number.isFinite(shop.discount) ? shop.discount : 0;
    const discountElement = document.getElementById('shop-discount');
    if (discountElement) discountElement.textContent = `${discountValue}%`;

    const icon = typeConfig.icon || shop.config?.icon || 'icons/default.svg';
    const iconElement = document.getElementById('shop-icon');
    if (iconElement) iconElement.src = icon;
};

const renderCategories = () => {
    const list = document.getElementById('category-list');
    if (!list) return;
    list.innerHTML = '';
    const categories = getCategories();
    ensureSelectedCategory();
    categories.forEach((category) => {
        const button = document.createElement('button');
        button.classList.add('category');
        if (state.selectedCategory === category.key) button.classList.add('active');
        button.dataset.category = category.key;
        button.innerHTML = `
            <span>${category.items.length} Artikel</span>
            ${category.label}
        `;
        list.appendChild(button);
    });
};

const renderProducts = () => {
    const grid = document.getElementById('product-grid');
    if (!grid) return;
    grid.innerHTML = '';
    if (!state.selectedCategory) return;
    const category = getCategories().find((c) => c.key === state.selectedCategory);
    if (!category) return;

    category.items.forEach((item) => {
        const pricing = calculateItemPricing(item);
        const basePrice = pricing.basePrice;
        const finalPrice = pricing.finalPrice;
        const effectiveDiscount = pricing.discount;
        const hasDiscount = effectiveDiscount > 0 && finalPrice < basePrice;
        const card = document.createElement('article');
        card.classList.add('product-card');
        card.dataset.itemId = item.id;
        card.innerHTML = `
            <div class="product-icon">
                <img src="${item.icon || 'icons/default.svg'}" alt="${item.label}">
            </div>
            <h3>${item.label}</h3>
            <p>Auf Lager: ${item.quantity}</p>
            <div class="product-meta">
                <div class="price-group">
                    <span class="price-tag${hasDiscount ? ' price-tag--discount' : ''}">${currency(finalPrice)}</span>
                    ${hasDiscount ? `<span class="price-original">${currency(basePrice)}</span>` : ''}
                    ${hasDiscount ? `<span class="price-badge">-${effectiveDiscount}%</span>` : ''}
                </div>
                <span>${item.item}</span>
            </div>
            <button class="btn-add" data-action="add-product" data-item-id="${item.id}" ${item.quantity <= 0 ? 'disabled' : ''}>${item.quantity <= 0 ? 'Ausverkauft' : 'In den Korb'}</button>
        `;
        grid.appendChild(card);
    });
};

const renderNotifications = () => {
    const container = document.getElementById('notifications');
    if (!container) return;
    if (!state.notifications || state.notifications.length === 0) {
        container.innerHTML = '';
        container.classList.add('hidden');
        return;
    }
    container.classList.remove('hidden');
    container.innerHTML = state.notifications.map((entry) => `
        <div class="notification notification--${entry.type || 'info'}" data-id="${entry.id}">
            <div class="notification__message">${escapeHtml(entry.message)}</div>
            <button class="notification__close" data-action="notification-close" data-id="${entry.id}" aria-label="Schließen">&times;</button>
        </div>
    `).join('');
};

const renderCart = () => {
    const itemsContainer = document.getElementById('cart-items');
    if (!itemsContainer) return;
    const info = document.getElementById('cart-info');
    const total = document.getElementById('cart-total');

    itemsContainer.innerHTML = '';
    if (info) info.textContent = `${state.cart.length} Artikel`;
    if (total) total.textContent = currency(cartTotal());

    if (state.cart.length === 0) {
        const empty = document.createElement('div');
        empty.classList.add('cart-empty');
        empty.textContent = 'Leerer Warenkorb';
        itemsContainer.appendChild(empty);
        return;
    }

    state.cart.forEach((entry) => {
        const div = document.createElement('div');
        div.classList.add('cart-item');
        div.dataset.itemId = entry.id;
        div.innerHTML = `
            <div class="cart-item-header">
                <strong>${entry.label}</strong>
                <span>${currency(entry.price)}</span>
            </div>
            <div class="cart-item-actions">
                <div class="quantity-control" data-item-id="${entry.id}">
                    <button data-action="decrease">-</button>
                    <span>${entry.quantity}</span>
                    <button data-action="increase">+</button>
                </div>
                <button class="btn ghost" data-action="remove-item" data-item-id="${entry.id}">Entfernen</button>
            </div>
        `;
        itemsContainer.appendChild(div);
    });
};

const renderManagementTabs = () => {
    const nav = document.getElementById('management-tabs');
    if (!nav) return;
    nav.innerHTML = '';
    managementTabs.forEach((tab) => {
        const button = document.createElement('button');
        button.classList.add('management-tab');
        if (state.managementTab === tab.key) button.classList.add('active');
        button.dataset.tab = tab.key;
        button.textContent = tab.label;
        nav.appendChild(button);
    });
};

const renderEmptyStatePanel = (message) => {
    const panel = document.createElement('div');
    panel.classList.add('panel', 'panel-empty');
    panel.innerHTML = `
        <div class="empty-state">
            <h3>Shopverwaltung</h3>
            <p>${message}</p>
        </div>
    `;
    return panel;
};

const renderDashboardPanel = () => {
    const shop = state.shop;
    if (!shop) {
        return renderEmptyStatePanel('Kein Shop ausgewählt.');
    }
    const typeConfig = shop.typeConfig || {};
    const panel = document.createElement('div');
    panel.classList.add('panel');
    panel.innerHTML = `
        <h3>Shop Übersicht</h3>
        <div class="stat-grid">
            <div class="stat-card">
                <span class="label">Shop Level</span>
                <span class="value">${shop.level}</span>
            </div>
            <div class="stat-card">
                <span class="label">Gesamt XP</span>
                <span class="value">${shop.xp}</span>
            </div>
            <div class="stat-card">
                <span class="label">Kontostand</span>
                <span class="value">${currency(shop.balance)}</span>
            </div>
            <div class="stat-card">
                <span class="label">Aktiver Rabatt</span>
                <span class="value">${shop.discount || 0}%</span>
            </div>
        </div>
        <div class="tag">Shop Typ: ${typeConfig.label || shop.type}</div>
    `;
    const heading = panel.querySelector('h3');
    if (heading) heading.textContent = 'Shop Uebersicht';

    const stats = shop.stats || {};
    const labels = Array.isArray(stats.labels) ? stats.labels : [];
    const sales = Array.isArray(stats.sales) ? stats.sales : [];
    const xp = Array.isArray(stats.xp) ? stats.xp : [];
    const deliveries = Array.isArray(stats.deliveries) ? stats.deliveries : [];
    const numericValues = [...sales, ...xp, ...deliveries]
        .map(Number)
        .filter((value) => !Number.isNaN(value));
    const maxValue = numericValues.length ? Math.max(...numericValues, 1) : 1;

    const chartColumns = labels.map((label, index) => {
        const salesValue = Number(sales[index] || 0);
        const xpValue = Number(xp[index] || 0);
        const deliveriesValue = Number(deliveries[index] || 0);
        const height = (value) => {
            if (value <= 0) return 0;
            const computed = Math.round((value / maxValue) * 100);
            return Math.max(computed, 8);
        };
        return `
            <div class="chart-column">
                <div class="chart-bars">
                    <div class="chart-bar chart-bar--sales" style="height: ${height(salesValue)}%;" title="Umsatz: ${currency(salesValue)}"></div>
                    <div class="chart-bar chart-bar--xp" style="height: ${height(xpValue)}%;" title="XP: ${xpValue}"></div>
                    <div class="chart-bar chart-bar--deliveries" style="height: ${height(deliveriesValue)}%;" title="Lieferungen: ${deliveriesValue}"></div>
                </div>
                <span class="chart-label">${label || '-'}</span>
            </div>
        `;
    }).join('');

    const chartSection = labels.length
        ? `
            <div class="chart-legend">
                <span class="legend-entry legend-sales">Umsatz</span>
                <span class="legend-entry legend-xp">XP</span>
                <span class="legend-entry legend-deliveries">Lieferungen</span>
            </div>
            <div class="chart-grid">
                ${chartColumns}
            </div>
        `
        : '<div class="chart-empty">Keine Daten vorhanden</div>';

    const chartContainer = document.createElement('div');
    chartContainer.classList.add('chart-container');
    chartContainer.innerHTML = `
        <div class="chart-header">
            <h4>Performance (7 Tage)</h4>
        </div>
        ${chartSection}
    `;

    const tag = panel.querySelector('.tag');
    if (tag && tag.parentElement) {
        tag.parentElement.insertBefore(chartContainer, tag);
    } else {
        panel.appendChild(chartContainer);
    }

    return panel;
};

const renderInventoryPanel = () => {
    const panel = document.createElement('div');
    panel.classList.add('panel');
    panel.innerHTML = `
        <h3>Lagerbestand & Preise</h3>
        <table>
            <thead>
                <tr>
                    <th>Artikel</th>
                    <th>Kategorie</th>
                    <th>Auf Lager</th>
                    <th>Verkaufspreis</th>
                    <th>Rabatt (%)</th>
                    <th></th>
                </tr>
            </thead>
            <tbody id="inventory-body"></tbody>
        </table>
        <form data-action="set-discount" class="discount-form">
            <label>Standard Rabatt (%)</label>
            <input type="number" min="0" max="50" value="${state.shop.discount || 0}">
            <button class="btn primary" type="submit">Aktualisieren</button>
        </form>
    `;

    const body = panel.querySelector('#inventory-body');
    const defaultDiscount = Number(state.shop?.discount ?? 0);
    const categories = getCategories();
    categories.forEach((category) => {
        category.items.forEach((item) => {
            const pricing = calculateItemPricing(item);
            const basePrice = pricing.basePrice;
            const finalPrice = pricing.finalPrice;
            const hasDiscount = pricing.discount > 0 && finalPrice < basePrice;
            const itemDiscountValue = Number(item.discount ?? 0);
            const hint = itemDiscountValue <= 0 && defaultDiscount > 0
                ? `<span class="discount-hint">Standard: ${defaultDiscount}%</span>`
                : '';
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td>${item.label}</td>
                <td>${category.label}</td>
                <td>${item.quantity}</td>
                <td>
                    <div class="table-price">
                        <span class="price-tag${hasDiscount ? ' price-tag--discount' : ''}">${currency(finalPrice)}</span>
                        ${hasDiscount ? `<span class="price-original">${currency(basePrice)}</span>` : ''}
                    </div>
                </td>
                <td>
                    <form data-action="set-item-discount" data-item-id="${item.id}" class="inline-form">
                        <div class="discount-input">
                            <input type="number" min="0" max="50" value="${itemDiscountValue}">
                            <span>%</span>
                        </div>
                        <button class="btn secondary" type="submit">Speichern</button>
                    </form>
                    ${hint}
                </td>
                <td>
                    <form data-action="set-price" data-item-id="${item.id}" class="inline-form">
                        <input type="number" min="0" value="${item.overridePrice ?? item.basePrice}">
                        <button class="btn secondary" type="submit">Speichern</button>
                    </form>
                </td>
            `;
            body.appendChild(tr);
        });
    });
    return panel;
};

const renderEmployeesPanel = () => {
    const panel = document.createElement('div');
    panel.classList.add('panel');
    panel.innerHTML = `
        <h3>Mitarbeiter</h3>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>CitizenID</th>
                    <th>Rolle</th>
                    <th>Lohn</th>
                    <th>Status</th>
                    <th></th>
                </tr>
            </thead>
            <tbody id="employee-body"></tbody>
        </table>
        <form data-action="hire-employee" class="employee-form">
            <input type="text" name="citizenid" placeholder="CitizenID" required>
            <select name="role">
                <option value="cashier">Kassierer</option>
                <option value="driver">Fahrer</option>
                <option value="manager">Manager</option>
            </select>
            <input type="number" name="wage" placeholder="Lohn" min="0" value="${state.modalDefaultWage || 250}">
            <button class="btn primary" type="submit">Einstellen</button>
        </form>
    `;

    const body = panel.querySelector('#employee-body');
    (state.shop.employees || []).forEach((employee) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${employee.name}</td>
            <td>${employee.citizenid}</td>
            <td>${employee.role}</td>
            <td>${currency(employee.wage || 0)}</td>
            <td>${employee.status}</td>
            <td><button class="btn ghost" data-action="fire-employee" data-citizenid="${employee.citizenid}">Entlassen</button></td>
        `;
        body.appendChild(tr);
    });
    return panel;
};

const renderDeliveriesPanel = () => {
    const panel = document.createElement('div');
    panel.classList.add('panel');
    const deliveries = state.shop.deliveries || [];
    const vehicles = state.shop.deliveryVehicles || {};
    panel.innerHTML = `
        <h3>Lieferaufträge</h3>
        <div class="delivery-list">
            ${deliveries.length === 0 ? '<div class="chart-empty">Keine offenen Lieferaufträge.</div>' : ''}
        </div>
        <form data-action="create-delivery" class="delivery-form">
            <h4>Neue Lieferung planen</h4>
            <label>Bezeichnung</label>
            <input type="text" name="label" placeholder="Kommentar">
            <label>Fahrzeug</label>
            <select name="vehicle" required ${getUnlockedVehicles().length ? '' : 'disabled'}>
                <option value="">Fahrzeug wählen</option>
                ${Object.entries(vehicles).map(([key, config]) => {
                    const unlocked = isVehicleUnlocked(key);
                    const meetsLevel = (state.shop?.level || 1) >= (config.minLevel || 1);
                    return `<option value="${key}" ${!unlocked ? 'disabled' : ''}>${config.label} (${config.capacity})${!unlocked ? ' - gesperrt' : ''}</option>`;
                }).join('')}
            </select>
            <div class="delivery-items" data-role="delivery-items"></div>
            <button class="btn secondary" type="button" data-role="add-delivery-item">+ Artikel hinzufügen</button>
            <div class="capacity-hint">Kapazität: <span data-role="capacity-info">0</span></div>
            <button class="btn primary" type="submit">Auftrag erstellen</button>
        </form>
    `;

    const list = panel.querySelector('.delivery-list');
    deliveries.forEach((delivery) => {
        const vehicle = vehicles[delivery.vehicle_model] || {};
        const unlocked = isVehicleUnlocked(delivery.vehicle_model);
        const totalQuantity = (delivery.items || []).reduce((sum, item) => sum + Number(item.quantity || 0), 0);
        const itemsHtml = (delivery.items || []).map((item) => `
            <li>
                <span>${item.label || item.item}</span>
                <span class="delivery-item-qty">${item.quantity}</span>
            </li>
        `).join('');
        const isPending = delivery.status === 'pending';
        const card = document.createElement('div');
        card.classList.add('delivery-card');
        card.innerHTML = `
            <div class="delivery-header">
                <strong>${delivery.identifier}</strong>
                <span class="delivery-status delivery-status--${delivery.status}">${delivery.status}</span>
            </div>
            <div class="delivery-body">
                <div class="delivery-info">
                    <span>Fahrzeug: ${vehicle.label || delivery.vehicle_model || 'Nicht zugewiesen'}</span>
                    <span>Menge: ${totalQuantity}</span>
                    ${delivery.metadata?.label ? `<span>Kommentar: ${delivery.metadata.label}</span>` : ''}
                    ${delivery.metadata?.vehicle && !unlocked ? '<span class="delivery-warning">Fahrzeug gesperrt</span>' : ''}
                </div>
                <ul class="delivery-items-list">
                    ${itemsHtml || '<li>Keine Artikel</li>'}
                </ul>
            </div>
            <div class="delivery-actions">
                ${isPending
                    ? `<button class="btn secondary" data-action="start-delivery" data-delivery="${delivery.identifier}" data-vehicle="${delivery.vehicle_model || ''}">Starten</button>`
                    : '<span class="delivery-progress">Aktiv</span>'}
            </div>
        `;
        list.appendChild(card);
    });

    setupDeliveryForm(panel);
    return panel;
};

const setupDeliveryForm = (panel) => {
    const form = panel.querySelector('form[data-action="create-delivery"]');
    if (!form) return;
    const unlockedVehicles = getUnlockedVehicles();
    const addItemButton = form.querySelector('[data-role="add-delivery-item"]');
    const submitButton = form.querySelector('button[type="submit"]');
    const itemsContainer = form.querySelector('[data-role="delivery-items"]');
    const capacityInfo = form.querySelector('[data-role="capacity-info"]');
    const vehicleSelect = form.querySelector('select[name="vehicle"]');

    if (!unlockedVehicles.length) {
        if (itemsContainer) {
            itemsContainer.innerHTML = '<div class="chart-empty">Keine freigeschalteten Fahrzeuge verfügbar.</div>';
        }
        if (addItemButton) addItemButton.disabled = true;
        if (submitButton) submitButton.disabled = true;
        return;
    }

    const createItemRow = () => {
        const row = document.createElement('div');
        row.classList.add('delivery-item-row');
        row.dataset.role = 'delivery-row';

        const select = document.createElement('select');
        select.dataset.role = 'item-select';
        select.innerHTML = `
            <option value="">Artikel auswählen</option>
            ${getInventoryItems().map((item) => `
                <option value="${item.id}" data-item="${item.item}" data-label="${item.label}">
                    ${item.label} (${item.quantity}x)
                </option>
            `).join('')}
        `;

        const quantity = document.createElement('input');
        quantity.type = 'number';
        quantity.dataset.role = 'item-quantity';
        quantity.min = '1';
        quantity.value = '10';

        const remove = document.createElement('button');
        remove.type = 'button';
        remove.classList.add('btn', 'ghost');
        remove.dataset.role = 'remove-item';
        remove.innerHTML = '&times;';

        row.appendChild(select);
        row.appendChild(quantity);
        row.appendChild(remove);

        return row;
    };

    const updateCapacityHint = () => {
        if (!capacityInfo) return;
        const rows = Array.from(form.querySelectorAll('[data-role="delivery-row"]'));
        const vehicleKey = vehicleSelect.value;
        const capacity = getVehicleCapacity(vehicleKey);
        const total = rows.reduce((sum, row) => {
            const value = Number(row.querySelector('[data-role="item-quantity"]')?.value || 0);
            return sum + Math.max(0, value);
        }, 0);

        capacityInfo.textContent = capacity > 0 ? `${total} / ${capacity}` : `${total}`;
        const over = capacity > 0 && total > capacity;
        form.classList.toggle('capacity-over', over);
        if (submitButton) {
            submitButton.disabled = !vehicleKey || total <= 0 || over;
        }
    };

    const ensureRow = () => {
        if (!itemsContainer) return;
        if (!itemsContainer.querySelector('[data-role="delivery-row"]')) {
            itemsContainer.appendChild(createItemRow());
        }
    };

    ensureRow();
    updateCapacityHint();

    if (addItemButton) {
        addItemButton.addEventListener('click', () => {
            if (!itemsContainer) return;
            itemsContainer.appendChild(createItemRow());
            updateCapacityHint();
        });
    }

    form.addEventListener('click', (event) => {
        const target = event.target;
        if (target?.dataset.role === 'remove-item') {
            const row = target.closest('[data-role="delivery-row"]');
            if (row) {
                row.remove();
                ensureRow();
                updateCapacityHint();
            }
        }
    });

    form.addEventListener('input', (event) => {
        if (event.target && event.target.matches('[data-role="item-select"], [data-role="item-quantity"]')) {
            updateCapacityHint();
        }
    });

    form.addEventListener('change', (event) => {
        if (event.target && event.target.name === 'vehicle') {
            updateCapacityHint();
        }
    });

    updateCapacityHint();
};

const renderFinancePanel = () => {
    const panel = document.createElement('div');
    panel.classList.add('panel');
    panel.innerHTML = `
        <h3>Finanzen</h3>
        <div class="finance-actions">
            <form data-action="deposit">
                <input type="number" name="amount" placeholder="Einzahlen" min="1">
                <button class="btn secondary" type="submit">Einzahlen</button>
            </form>
            <form data-action="withdraw">
                <input type="number" name="amount" placeholder="Auszahlen" min="1">
                <button class="btn secondary" type="submit">Auszahlen</button>
            </form>
        </div>
    `;
    return panel;
};

const renderVehiclesPanel = () => {
    const panel = document.createElement('div');
    panel.classList.add('panel');
    const vehicles = Object.entries(state.shop?.deliveryVehicles || {});
    panel.innerHTML = `
        <h3>Lieferfahrzeuge</h3>
        <div class="vehicle-grid"></div>
    `;
    const grid = panel.querySelector('.vehicle-grid');
    if (!vehicles.length) {
        grid.innerHTML = '<div class="chart-empty">Keine Fahrzeuge konfiguriert.</div>';
        return panel;
    }

    const ownership = getVehicleOwnership();
    vehicles.forEach(([key, vehicle]) => {
        const unlocked = Boolean(ownership[key]?.unlocked);
        const meetsLevel = (state.shop?.level || 1) >= (vehicle.minLevel || 1);
        const price = Number(vehicle.price || 0);
        const priceLabel = price > 0 ? currency(price) : 'Kostenlos';
        const iconPath = vehicle.icon || `icons/${key}.svg`;
        const card = document.createElement('article');
        card.classList.add('vehicle-card');
        if (unlocked) card.classList.add('vehicle-card--unlocked');

        const purchasedAt = ownership[key]?.purchasedAt
            ? new Date(ownership[key].purchasedAt * 1000).toLocaleDateString()
            : null;

        let actionHtml = '';
        if (unlocked) {
            actionHtml = `<span class="vehicle-status vehicle-status--active">Freigeschaltet${purchasedAt ? `<small>seit ${purchasedAt}</small>` : ''}</span>`;
        } else if (!meetsLevel) {
            actionHtml = `<span class="vehicle-status vehicle-status--locked">Level ${vehicle.minLevel} benötigt</span>`;
        } else {
            actionHtml = `
                <button class="btn primary" data-action="unlock-vehicle" data-vehicle="${key}">
                    Freischalten ${priceLabel}
                </button>
            `;
        }

        card.innerHTML = `
            <div class="vehicle-header">
                <div class="vehicle-icon">
                    <img src="${iconPath}" alt="${vehicle.label}">
                </div>
                <div>
                    <h4>${vehicle.label}</h4>
                    <p>Kapazität: ${vehicle.capacity}</p>
                </div>
            </div>
            <ul class="vehicle-specs">
                <li>Level ${vehicle.minLevel || 1}</li>
                <li>Preis: ${priceLabel}</li>
                <li>Trunk: ${vehicle.trunkInventory || 0}</li>
            </ul>
            <div class="vehicle-actions">
                ${actionHtml}
            </div>
        `;
        grid.appendChild(card);
    });
    return panel;
};

const renderManagementPanel = () => {
    const container = document.getElementById('management-panel');
    if (!container) return;
    container.innerHTML = '';
    if (!state.shop) {
        container.appendChild(renderEmptyStatePanel('Kein Shop ausgewählt.'));
        return;
    }
    switch (state.managementTab) {
        case 'dashboard':
            container.appendChild(renderDashboardPanel());
            break;
        case 'inventory':
            container.appendChild(renderInventoryPanel());
            break;
        case 'employees':
            container.appendChild(renderEmployeesPanel());
            break;
        case 'deliveries':
            container.appendChild(renderDeliveriesPanel());
            break;
        case 'finance':
            container.appendChild(renderFinancePanel());
            break;
        case 'vehicles':
            container.appendChild(renderVehiclesPanel());
            break;
        default:
            container.appendChild(renderDashboardPanel());
    }
};

const getAdminSelectedShop = () => state.admin.shops.find((shop) => shop.identifier === state.admin.selected) || null;

const toNumber = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizeIdentifier = (value) => {
    if (!value) return '';
    return String(value)
        .trim()
        .toLowerCase()
        .replace(/\s+/g, '_')
        .replace(/[^a-z0-9_]/g, '')
        .replace(/_+/g, '_')
        .replace(/^_/, '')
        .replace(/_$/, '');
};

const flattenInventory = (inventory) => {
    const items = [];
    Object.entries(inventory || {}).forEach(([categoryKey, category]) => {
        (category.items || []).forEach((item) => {
            items.push({
                id: item.id || null,
                item: item.item || '',
                label: item.label || '',
                icon: item.icon || '',
                category: categoryKey,
                quantity: toNumber(item.quantity, 0),
                basePrice: toNumber(item.basePrice ?? item.base_price, 0),
                overridePrice: toNumber(item.overridePrice ?? item.override_price ?? item.basePrice ?? item.base_price, 0),
                discount: toNumber(item.discount, 0),
                minLevel: toNumber(item.minLevel ?? item.min_level, 1),
            });
        });
    });
    items.sort((a, b) => (a.label || a.item || '').localeCompare(b.label || b.item || ''));
    return items;
};

const normalizeVehicleDraftEntry = (entry) => {
    if (!entry) return null;
    const templates = state.admin.config.vehicleTemplates || {};
    const templateFor = (key) => (key && templates[key]) || {};

    if (typeof entry === 'string') {
        const key = String(entry);
        const template = templateFor(key);
        return {
            key,
            model: template.model || key,
            label: template.label || template.name || key,
            price: toNumber(template.price, 0),
            minLevel: Math.max(1, toNumber(template.minLevel, 1)),
            capacity: toNumber(template.capacity, 0),
            trunk: toNumber(template.trunk, 0),
            fuelModifier: toNumber(template.fuelModifier ?? 1, 1),
        };
    }

    if (typeof entry === 'object') {
        const key = entry.key
            || entry.vehicle_key
            || entry.model
            || entry.vehicle
            || entry.spawn
            || entry.spawnName
            || entry.modelName
            || entry.label
            || entry.name;
        if (!key) return null;
        const template = templateFor(key);
        const model = entry.model
            || entry.spawn
            || entry.vehicle
            || entry.modelName
            || template.model
            || key;
        const label = entry.label
            || entry.display
            || entry.name
            || template.label
            || template.name
            || model
            || key;
        const price = toNumber(entry.price ?? entry.cost ?? entry.purchasePrice ?? template.price, 0);
        const minLevel = Math.max(1, toNumber(entry.minLevel ?? entry.min_level ?? entry.level ?? template.minLevel, 1));
        const capacity = toNumber(entry.capacity ?? entry.cargo ?? entry.maxCapacity ?? template.capacity, 0);
        const trunk = toNumber(entry.trunk ?? entry.trunk_size ?? entry.trunkInventory ?? template.trunk, 0);
        const fuel = toNumber(entry.fuelModifier ?? entry.fuel_modifier ?? template.fuelModifier ?? 1, 1);
        return {
            key: String(key),
            model: model || String(key),
            label: label || model || String(key),
            price,
            minLevel,
            capacity,
            trunk,
            fuelModifier: fuel > 0 ? fuel : 1,
        };
    }

    return null;
};

const normalizeRoutePoints = (points) => {
    return (Array.isArray(points) ? points : []).map((point) => ({
        x: toNumber(point.x, 0),
        y: toNumber(point.y, 0),
        z: toNumber(point.z, 0),
        label: point.label || '',
    }));
};

const buildAdminDraft = (shop) => {
    if (!shop) return null;
    const creator = shop.metadata?.creator || {};
    const coords = creator.coords || shop.coords || { x: 0, y: 0, z: 0, w: shop.heading || 0 };
    const pedSource = creator.ped || shop.config?.ped || {};
    const zoneSource = creator.zone || shop.config?.zone || {};
    const dropoffsSource = Array.isArray(creator.dropoffs) && creator.dropoffs.length
        ? creator.dropoffs
        : [{ x: coords.x ?? 0, y: coords.y ?? 0, z: coords.z ?? 0, label: shop.label || '' }];
    const depotsSource = Array.isArray(creator.depots) ? creator.depots : [];
    const vehiclesSource = Array.isArray(creator.vehicles) ? creator.vehicles : [];
    const productsSource = Array.isArray(creator.products) ? creator.products : [];

    const blipDisabled = creator.blip === false;
    const blipSource = blipDisabled ? {} : (creator.blip || shop.config?.blip || {});
    const blip = {
        enabled: blipDisabled ? false : Boolean(blipSource && (blipSource.sprite || blipSource.color || blipSource.label || blipSource.scale)),
        sprite: toNumber(blipSource.sprite, 59),
        color: toNumber(blipSource.color, 1),
        scale: Number.isFinite(blipSource.scale) ? Number(blipSource.scale) : 0.8,
        label: blipSource.label || shop.label || '',
        shortRange: blipSource.shortRange !== false,
    };

    const vehicleSpawns = Array.isArray(creator.vehicleSpawns)
        ? creator.vehicleSpawns.map((point) => ({
            x: toNumber(point.x ?? point.coords?.x, 0),
            y: toNumber(point.y ?? point.coords?.y, 0),
            z: toNumber(point.z ?? point.coords?.z, 0),
            heading: toNumber(point.heading ?? point.w, coords.w ?? 0),
            label: point.label || '',
        }))
        : [];

    const vehicleDraft = [];
    const seenVehicles = new Set();
    vehiclesSource.forEach((entry) => {
        const normalized = normalizeVehicleDraftEntry(entry);
        if (!normalized || !normalized.key || seenVehicles.has(normalized.key)) return;
        seenVehicles.add(normalized.key);
        vehicleDraft.push(normalized);
    });

    const routes = Array.isArray(creator.routes)
        ? creator.routes.map((route, index) => ({
            label: route.label || `Route ${index + 1}`,
            points: normalizeRoutePoints(route.points),
        }))
        : [];

    return {
        identifier: shop.identifier,
        label: shop.label || '',
        type: shop.type,
        coords: {
            x: Number(coords.x ?? 0),
            y: Number(coords.y ?? 0),
            z: Number(coords.z ?? 0),
            heading: Number(coords.w ?? shop.heading ?? 0),
        },
        ped: {
            model: pedSource.model || '',
            scenario: pedSource.scenario || '',
        },
        zone: {
            length: Number(zoneSource.length ?? 2.0),
            width: Number(zoneSource.width ?? 2.0),
            minZ: Number(zoneSource.minZ ?? (Number(coords.z ?? 0) - 1)),
            maxZ: Number(zoneSource.maxZ ?? (Number(coords.z ?? 0) + 1)),
        },
        dropoffs: dropoffsSource.map((point) => ({
            x: Number(point.x ?? 0),
            y: Number(point.y ?? 0),
            z: Number(point.z ?? 0),
            label: point.label || '',
        })),
        depots: depotsSource.map((point) => ({
            x: Number(point.x ?? point.coords?.x ?? 0),
            y: Number(point.y ?? point.coords?.y ?? 0),
            z: Number(point.z ?? point.coords?.z ?? 0),
            heading: Number(point.heading ?? 0),
            label: point.label || '',
        })),
        vehicles: vehiclesSource.map((vehicle) => String(vehicle)),
        products: productsSource.map((product) => String(product)),
        purchasePrice: toNumber(shop.purchasePrice ?? creator.purchasePrice, 0),
        sellPrice: toNumber(shop.sellPrice ?? creator.sellPrice, 0),
        inventory: flattenInventory(shop.inventory),
        vehicleSpawns,
        vehicles: vehicleDraft,
        routes,
        blip,
        isNew: false,
    };
};

const sanitizeCoords = (coords) => ({
    x: toNumber(coords?.x, 0),
    y: toNumber(coords?.y, 0),
    z: toNumber(coords?.z, 0),
    heading: toNumber(coords?.heading ?? coords?.w, 0),
});

const buildNewAdminDraft = (type, coords) => {
    const typeKey = type || Object.keys(state.admin.config.shopTypes || {})[0] || '';
    const typeConfig = state.admin.config.shopTypes[typeKey] || {};
    const baseCoords = sanitizeCoords(coords || {});
    return {
        identifier: '',
        label: '',
        type: typeKey,
        coords: baseCoords,
        ped: { model: '', scenario: '' },
        zone: {
            length: 2.0,
            width: 2.0,
            minZ: baseCoords.z - 1,
            maxZ: baseCoords.z + 1,
        },
        dropoffs: [{ x: baseCoords.x, y: baseCoords.y, z: baseCoords.z, label: '' }],
        depots: [],
        vehicles: [],
        products: [],
        purchasePrice: toNumber(typeConfig.purchasePrice, 0),
        sellPrice: toNumber(typeConfig.sellPrice, 0),
        inventory: [],
        vehicleSpawns: [{
            x: baseCoords.x,
            y: baseCoords.y,
            z: baseCoords.z,
            heading: baseCoords.heading,
            label: '',
        }],
        routes: [],
        blip: {
            enabled: false,
            sprite: 59,
            color: 1,
            scale: 0.8,
            label: '',
            shortRange: true,
        },
        isNew: true,
    };
};

const fetchCurrentPosition = async () => {
    const payload = await nuiInvoke('adminGetPlayerCoords');
    if (!payload) return null;
    const coords = payload.coords || payload;
    if (!coords) return null;
    return sanitizeCoords(coords);
};

const updateZoneFromCoords = (draft, coords) => {
    if (!draft || !coords) return;
    draft.zone.minZ = coords.z - Math.max(1, draft.zone.length / 2);
    draft.zone.maxZ = coords.z + Math.max(1, draft.zone.length / 2);
};

const setAdminData = (payload) => {
    state.admin.shops = payload?.shops || [];
    state.admin.config = {
        shopTypes: payload?.shopTypes || {},
        vehicleTemplates: payload?.vehicleTemplates || payload?.deliveryVehicles || {},
        depots: payload?.depots || [],
    };
    const previousSelection = state.admin.pendingSelection || state.admin.selected;
    state.admin.pendingSelection = null;
    if (previousSelection && state.admin.shops.some((shop) => shop.identifier === previousSelection)) {
        state.admin.selected = previousSelection;
    } else {
        state.admin.selected = null;
    }
    state.admin.createMode = false;
    state.admin.dirty = false;

    if (state.admin.view === 'editor') {
        if (!state.admin.selected && state.admin.shops.length > 0) {
            state.admin.selected = state.admin.shops[0].identifier;
        }
        const selectedShop = getAdminSelectedShop();
        state.admin.draft = selectedShop ? buildAdminDraft(selectedShop) : null;
        if (!state.admin.draft) {
            state.admin.view = 'dashboard';
        }
    } else {
        state.admin.draft = null;
        state.admin.activeSection = 'general';
    }
};

const updateAdminSaveButton = () => {
    const button = document.querySelector('[data-action="admin-save"]');
    if (button) {
        const draft = state.admin.draft;
        let canSave = false;
        if (state.admin.createMode) {
            const normalizedId = normalizeIdentifier(draft?.identifier || '');
            canSave = Boolean(draft && normalizedId && draft.label && draft.type);
        } else {
            canSave = Boolean(draft) && state.admin.dirty;
        }
        button.classList.toggle('disabled', !canSave);
        button.disabled = !canSave;
    }
};

const updateAdminActionButtons = () => {
    const startButton = document.querySelector('[data-action="admin-start-create"]');
    if (startButton) {
        startButton.classList.toggle('hidden', state.admin.createMode);
    }
    const cancelButton = document.querySelector('[data-action="admin-cancel-create"]');
    if (cancelButton) {
        cancelButton.classList.toggle('hidden', !state.admin.createMode);
    }
};

const renderAdminList = () => {
    const container = document.getElementById('admin-sidebar');
    if (!container) return;
    container.innerHTML = '';
    const hasShops = state.admin.shops.length > 0;

    if (state.admin.createMode) {
        const draft = state.admin.draft || {};
        const button = document.createElement('button');
        button.type = 'button';
        button.classList.add('admin-card', 'active', 'admin-card--draft');
        button.dataset.action = 'select-new';
        button.innerHTML = `
            <div class="info">
                <strong>${draft.label || 'Neuer Shop'}</strong>
                <span>ID: ${draft.identifier || '–'}</span>
                <span>Typ: ${draft.type || '–'}</span>
            </div>
            <div class="info">
                <span>Standort</span>
                <span>${Number(draft.coords?.x ?? 0).toFixed(1)}, ${Number(draft.coords?.y ?? 0).toFixed(1)}</span>
            </div>
        `;
        container.appendChild(button);
    }

    if (!hasShops && !state.admin.createMode) {
        container.innerHTML = '<div class="admin-empty">Keine Shops vorhanden.</div>';
        return;
    }

    state.admin.shops.forEach((shop) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.classList.add('admin-card');
        if (!state.admin.createMode && state.admin.view === 'editor' && shop.identifier === state.admin.selected) {
            button.classList.add('active');
        }
        button.dataset.action = 'select-shop';
        button.dataset.identifier = shop.identifier;
        button.innerHTML = `
            <div class="info">
                <strong>${shop.label}</strong>
                <span>Typ: ${shop.type}</span>
                <span>Besitzer: ${shop.owner || 'Niemand'}</span>
            </div>
            <div class="info">
                <span>Level ${shop.level}</span>
                <span>Konto: ${currency(shop.balance)}</span>
            </div>
        `;
        container.appendChild(button);
    });
};

const renderAdminDashboard = (container) => {
    const shops = state.admin.shops || [];
    if (!shops.length) {
        container.innerHTML = '<div class="admin-empty">Keine Shops vorhanden.</div>';
        return;
    }
    const count = shops.length;
    const cards = shops.map((shop) => {
        const coords = shop.coords || {};
        const x = toNumber(coords.x, 0);
        const y = toNumber(coords.y, 0);
        const location = Number.isFinite(x) && Number.isFinite(y)
            ? `${x.toFixed(1)}, ${y.toFixed(1)}`
            : '–';
        return `
            <div class="admin-dashboard__card">
                <h4>${escapeHtml(shop.label || shop.identifier || 'Unbenannter Shop')}</h4>
                <div class="meta">
                    <span>ID: ${escapeHtml(shop.identifier || '–')}</span>
                    <span>Typ: ${escapeHtml(shop.type || '–')}</span>
                    <span>Besitzer: ${escapeHtml(shop.owner || 'Niemand')}</span>
                    <span>Level: ${toNumber(shop.level, 1)}</span>
                    <span>Saldo: ${currency(shop.balance || 0)}</span>
                    <span>Standort: ${location}</span>
                </div>
                <div class="actions">
                    <button class="btn secondary" data-action="select-shop" data-identifier="${escapeHtml(shop.identifier || '')}">Bearbeiten</button>
                </div>
            </div>
        `;
    }).join('');
    container.innerHTML = `
        <div class="admin-dashboard">
            <div class="admin-dashboard__header">
                <h3>Shop Übersicht</h3>
                <div class="admin-dashboard__meta">${count} ${count === 1 ? 'Shop' : 'Shops'} konfiguriert</div>
            </div>
            <div class="admin-dashboard__grid">${cards}</div>
        </div>
    `;
};

const renderAdminSectionNav = (sections) => {
    const nav = document.getElementById('admin-section-nav');
    if (!nav) return;
    if (!Array.isArray(sections) || sections.length === 0) {
        nav.innerHTML = '';
        nav.classList.add('hidden');
        return;
    }
    if (!sections.some((section) => section.key === state.admin.activeSection)) {
        state.admin.activeSection = sections[0].key;
    }
    nav.classList.remove('hidden');
    nav.innerHTML = `
        <span class="admin-section-nav__title">Bereiche</span>
        <div class="admin-section-nav__list">
            ${sections.map((section) => `
                <button type="button"
                    class="admin-section-nav__item ${state.admin.activeSection === section.key ? 'active' : ''}"
                    data-action="admin-scroll-section"
                    data-target="admin-section-${section.key}"
                    data-section="${section.key}">
                    ${escapeHtml(section.title)}
                </button>
            `).join('')}
        </div>
    `;
};

const renderAdminDetail = () => {
    const container = document.getElementById('admin-detail');
    const nav = document.getElementById('admin-section-nav');
    if (!container || !nav) return;
    container.innerHTML = '';

    if (state.admin.view !== 'editor' || !state.admin.draft) {
        renderAdminDashboard(container);
        renderAdminSectionNav([]);
        updateAdminSaveButton();
        return;
    }

    const draft = state.admin.draft;
    const sections = [];
    const addSection = (key, title, body) => {
        sections.push({ key, title, body });
    };

    const typeOptions = Object.entries(state.admin.config.shopTypes || {});
    const typeOptionsHtml = (() => {
        const entries = typeOptions.map(([key, type]) => `<option value="${key}" ${key === draft.type ? 'selected' : ''}>${escapeHtml(type.label || key)}</option>`);
        if (draft.type && !typeOptions.some(([key]) => key === draft.type)) {
            entries.push(`<option value="${escapeHtml(draft.type)}" selected>${escapeHtml(draft.type)}</option>`);
        }
        return entries.join('');
    })();

    const identifierField = state.admin.createMode
        ? `<label>Shop-ID<input type="text" data-field="identifier" value="${escapeHtml(draft.identifier || '')}" placeholder="z.B. legion247"></label>`
        : `<div class="admin-readonly">ID: ${escapeHtml(draft.identifier)}</div>`;

    addSection('general', 'Allgemein', `
        ${identifierField}
        <label>Shop-Name<input type="text" data-field="label" value="${escapeHtml(draft.label || '')}"></label>
        <label>Shop-Typ
            <select data-field="type">
                ${typeOptionsHtml}
            </select>
        </label>
        <div class="admin-grid">
            <label>Kaufpreis<input type="number" step="1" data-field="purchasePrice" value="${toNumber(draft.purchasePrice, 0)}"></label>
            <label>Verkaufspreis<input type="number" step="1" data-field="sellPrice" value="${toNumber(draft.sellPrice, 0)}"></label>
        </div>
    `);

    addSection('location', 'Standort', `
        <div class="admin-grid">
            <label>X<input type="number" step="0.01" data-group="coords" data-key="x" value="${toNumber(draft.coords.x, 0)}"></label>
            <label>Y<input type="number" step="0.01" data-group="coords" data-key="y" value="${toNumber(draft.coords.y, 0)}"></label>
            <label>Z<input type="number" step="0.01" data-group="coords" data-key="z" value="${toNumber(draft.coords.z, 0)}"></label>
            <label>Heading<input type="number" step="0.01" data-group="coords" data-key="heading" value="${toNumber(draft.coords.heading, 0)}"></label>
        </div>
        <button type="button" class="btn secondary" data-action="capture-coords">Aktuelle Position übernehmen</button>
    `);

    addSection('npc', 'NPC', `
        <label>Modell<input type="text" data-group="ped" data-key="model" value="${escapeHtml(draft.ped.model || '')}"></label>
        <label>Scenario<input type="text" data-group="ped" data-key="scenario" value="${escapeHtml(draft.ped.scenario || '')}"></label>
    `);

    addSection('zone', 'Zone', `
        <div class="admin-grid">
            <label>Länge<input type="number" step="0.01" data-group="zone" data-key="length" value="${toNumber(draft.zone.length, 2)}"></label>
            <label>Breite<input type="number" step="0.01" data-group="zone" data-key="width" value="${toNumber(draft.zone.width, 2)}"></label>
            <label>Min Z<input type="number" step="0.01" data-group="zone" data-key="minZ" value="${toNumber(draft.zone.minZ, 0)}"></label>
            <label>Max Z<input type="number" step="0.01" data-group="zone" data-key="maxZ" value="${toNumber(draft.zone.maxZ, 0)}"></label>
        </div>
        <button type="button" class="btn secondary" data-action="capture-zone">Zone anpassen (Position)</button>
    `);

    const blip = draft.blip || {};
    addSection('blip', 'Blip', `
        <label class="admin-checkbox">
            <input type="checkbox" data-group="blip" data-key="enabled" ${blip.enabled ? 'checked' : ''}>
            <span>Blip aktivieren</span>
        </label>
        <div class="admin-grid">
            <label>Sprite<input type="number" step="1" data-group="blip" data-key="sprite" value="${toNumber(blip.sprite, 59)}"></label>
            <label>Farbe<input type="number" step="1" data-group="blip" data-key="color" value="${toNumber(blip.color, 1)}"></label>
            <label>Skalierung<input type="number" step="0.01" data-group="blip" data-key="scale" value="${Number.isFinite(blip.scale) ? blip.scale : 0.8}"></label>
        </div>
        <label>Anzeige-Name<input type="text" data-group="blip" data-key="label" value="${escapeHtml(blip.label || '')}"></label>
        <label class="admin-checkbox">
            <input type="checkbox" data-group="blip" data-key="shortRange" ${blip.shortRange === false ? '' : 'checked'}>
            <span>Nur in der Nähe anzeigen</span>
        </label>
    `);

    const dropoffRows = draft.dropoffs.map((point, index) => `
        <div class="admin-point-row" data-index="${index}">
            <label>X<input type="number" step="0.01" data-group="dropoffs" data-index="${index}" data-key="x" value="${toNumber(point.x, 0)}"></label>
            <label>Y<input type="number" step="0.01" data-group="dropoffs" data-index="${index}" data-key="y" value="${toNumber(point.y, 0)}"></label>
            <label>Z<input type="number" step="0.01" data-group="dropoffs" data-index="${index}" data-key="z" value="${toNumber(point.z, 0)}"></label>
            <label>Label<input type="text" data-group="dropoffs" data-index="${index}" data-key="label" value="${escapeHtml(point.label || '')}"></label>
            <div class="admin-point-row__actions">
                <button type="button" class="btn ghost" data-action="capture-point" data-point-type="dropoffs" data-index="${index}">Position</button>
                <button type="button" class="btn ghost" data-action="remove-dropoff" data-index="${index}">&times;</button>
            </div>
        </div>
    `).join('');
    addSection('dropoffs', 'Lieferpunkte', `
        <div class="admin-point-list">${dropoffRows || '<div class="admin-empty">Keine Lieferpunkte.</div>'}</div>
        <div class="admin-section__actions">
            <button type="button" class="btn secondary" data-action="add-dropoff">+ Punkt hinzufügen</button>
            <button type="button" class="btn secondary" data-action="add-dropoff-current">+ Punkt (Position)</button>
        </div>
    `);

    const depotRows = draft.depots.map((point, index) => `
        <div class="admin-point-row" data-index="${index}">
            <label>X<input type="number" step="0.01" data-group="depots" data-index="${index}" data-key="x" value="${toNumber(point.x, 0)}"></label>
            <label>Y<input type="number" step="0.01" data-group="depots" data-index="${index}" data-key="y" value="${toNumber(point.y, 0)}"></label>
            <label>Z<input type="number" step="0.01" data-group="depots" data-index="${index}" data-key="z" value="${toNumber(point.z, 0)}"></label>
            <label>Heading<input type="number" step="0.01" data-group="depots" data-index="${index}" data-key="heading" value="${toNumber(point.heading, 0)}"></label>
            <label>Label<input type="text" data-group="depots" data-index="${index}" data-key="label" value="${escapeHtml(point.label || '')}"></label>
            <div class="admin-point-row__actions">
                <button type="button" class="btn ghost" data-action="capture-point" data-point-type="depots" data-index="${index}">Position</button>
                <button type="button" class="btn ghost" data-action="remove-depot" data-index="${index}">&times;</button>
            </div>
        </div>
    `).join('');
    addSection('depots', 'Depotpunkte', `
        <div class="admin-point-list">${depotRows || '<div class="admin-empty">Keine Depotpunkte.</div>'}</div>
        <div class="admin-section__actions">
            <button type="button" class="btn secondary" data-action="add-depot">+ Depot hinzufügen</button>
            <button type="button" class="btn secondary" data-action="add-depot-current">+ Depot (Position)</button>
        </div>
    `);

    const spawnRows = draft.vehicleSpawns.map((point, index) => `
        <div class="admin-point-row" data-index="${index}">
            <label>X<input type="number" step="0.01" data-group="vehicleSpawns" data-index="${index}" data-key="x" value="${toNumber(point.x, 0)}"></label>
            <label>Y<input type="number" step="0.01" data-group="vehicleSpawns" data-index="${index}" data-key="y" value="${toNumber(point.y, 0)}"></label>
            <label>Z<input type="number" step="0.01" data-group="vehicleSpawns" data-index="${index}" data-key="z" value="${toNumber(point.z, 0)}"></label>
            <label>Heading<input type="number" step="0.01" data-group="vehicleSpawns" data-index="${index}" data-key="heading" value="${toNumber(point.heading, 0)}"></label>
            <label>Label<input type="text" data-group="vehicleSpawns" data-index="${index}" data-key="label" value="${escapeHtml(point.label || '')}"></label>
            <div class="admin-point-row__actions">
                <button type="button" class="btn ghost" data-action="capture-point" data-point-type="vehicleSpawns" data-index="${index}">Position</button>
                <button type="button" class="btn ghost" data-action="remove-vehicle-spawn" data-index="${index}">&times;</button>
            </div>
        </div>
    `).join('');
    addSection('vehicleSpawns', 'Fahrzeug-Spawns', `
        <div class="admin-point-list">${spawnRows || '<div class="admin-empty">Keine Spawnpunkte.</div>'}</div>
        <div class="admin-section\__actions">
            <button type="button" class="btn secondary" data-action="add-vehicle-spawn">+ Spawn hinzufügen</button>
            <button type="button" class="btn secondary" data-action="add-vehicle-spawn-current">+ Spawn (Position)</button>
        </div>
    `);

    const templates = Object.entries(state.admin.config.vehicleTemplates || {});
    const templateOptions = ['<option value="">Vorlage wählen</option>'].
        concat(templates.map(([key, vehicle]) => `<option value="${escapeHtml(key)}">${escapeHtml(vehicle.label || vehicle.model || key)}</option>`)).join('');
    const vehicleRows = (draft.vehicles || []).map((vehicle, index) => `
        <tr data-index="${index}">
            <td><input type="text" data-group="vehicles" data-index="${index}" data-key="key" value="${escapeHtml(vehicle.key || '')}"></td>
            <td><input type="text" data-group="vehicles" data-index="${index}" data-key="label" value="${escapeHtml(vehicle.label || '')}"></td>
            <td><input type="text" data-group="vehicles" data-index="${index}" data-key="model" value="${escapeHtml(vehicle.model || '')}"></td>
            <td><input type="number" step="1" data-group="vehicles" data-index="${index}" data-key="price" value="${toNumber(vehicle.price, 0)}"></td>
            <td><input type="number" step="1" data-group="vehicles" data-index="${index}" data-key="minLevel" value="${toNumber(vehicle.minLevel, 1)}"></td>
            <td><input type="number" step="1" data-group="vehicles" data-index="${index}" data-key="capacity" value="${toNumber(vehicle.capacity, 0)}"></td>
            <td><input type="number" step="1" data-group="vehicles" data-index="${index}" data-key="trunk" value="${toNumber(vehicle.trunk, 0)}"></td>
            <td><input type="number" step="0.1" data-group="vehicles" data-index="${index}" data-key="fuelModifier" value="${Number(vehicle.fuelModifier || 1).toFixed(2)}"></td>
            <td><button type="button" class="btn ghost" data-action="remove-vehicle" data-index="${index}">&times;</button></td>
        </tr>
    `).join('');
    addSection('vehicles', 'Fahrzeuge', `
        <div class="admin-vehicle-controls">
            <select data-role="vehicle-template">${templateOptions}</select>
            <button type="button" class="btn secondary" data-action="admin-add-vehicle-template">Vorlage übernehmen</button>
            <button type="button" class="btn ghost" data-action="admin-add-vehicle-manual">Eigenes Fahrzeug</button>
        </div>
        <div class="admin-table-wrapper admin-vehicle-table">
            <table class="admin-table">
                <thead>
                    <tr>
                        <th>Schlüssel</th>
                        <th>Label</th>
                        <th>Modell</th>
                        <th>Preis</th>
                        <th>Min. Level</th>
                        <th>Kapazität</th>
                        <th>Kofferraum</th>
                        <th>Kraftstofffaktor</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    ${vehicleRows || '<tr><td colspan="9" class="admin-empty">Keine Fahrzeuge hinterlegt.</td></tr>'}
                </tbody>
            </table>
        </div>
    `);

    const productOptions = Object.entries(activeType.baseProducts || {});
    const productKeys = new Set(productOptions.map(([key]) => key));
    const productCheckboxes = productOptions.map(([key, product]) => {
        const checked = draft.products.includes(key);
        return `
            <label class="admin-checkbox">
                <input type="checkbox" data-collection="products" value="${key}" ${checked ? 'checked' : ''}>
                <span>${escapeHtml(product.label || key)}</span>
            </label>
        `;
    });
    draft.products.forEach((key) => {
        if (!productKeys.has(key)) {
            productCheckboxes.push(`
                <label class="admin-checkbox">
                    <input type="checkbox" data-collection="products" value="${key}" checked>
                    <span>${escapeHtml(key)}</span>
                </label>
            `);
        }
    });
    const inventoryRows = draft.inventory.map((item, index) => `
        <tr data-index="${index}">
            <td><input type="text" data-group="inventory" data-index="${index}" data-key="label" value="${escapeHtml(item.label || '')}"></td>
            <td><input type="text" data-group="inventory" data-index="${index}" data-key="item" value="${escapeHtml(item.item || '')}"></td>
            <td><input type="text" data-group="inventory" data-index="${index}" data-key="category" value="${escapeHtml(item.category || '')}"></td>
            <td><input type="text" data-group="inventory" data-index="${index}" data-key="icon" value="${escapeHtml(item.icon || '')}"></td>
            <td><input type="number" step="1" data-group="inventory" data-index="${index}" data-key="quantity" value="${toNumber(item.quantity, 0)}"></td>
            <td><input type="number" step="0.01" data-group="inventory" data-index="${index}" data-key="basePrice" value="${toNumber(item.basePrice, 0)}"></td>
            <td><input type="number" step="0.01" data-group="inventory" data-index="${index}" data-key="overridePrice" value="${toNumber(item.overridePrice, 0)}"></td>
            <td><input type="number" step="1" data-group="inventory" data-index="${index}" data-key="minLevel" value="${toNumber(item.minLevel, 1)}"></td>
            <td><input type="number" step="1" data-group="inventory" data-index="${index}" data-key="discount" value="${toNumber(item.discount, 0)}"></td>
            <td><button type="button" class="btn ghost" data-action="remove-item" data-index="${index}">&times;</button></td>
        </tr>
    `).join('');
    addSection('products', 'Produkte', `
        <div class="admin-checkbox-grid">${productCheckboxes.join('') || '<div class="admin-empty">Keine Kategorien für diesen Typ.</div>'}</div>
        <div class="admin-table-wrapper">
            <table class="admin-table">
                <thead>
                    <tr>
                        <th>Label</th>
                        <th>Item</th>
                        <th>Kategorie</th>
                        <th>Icon</th>
                        <th>Menge</th>
                        <th>Marktpreis</th>
                        <th>Verkaufspreis</th>
                        <th>Min. Level</th>
                        <th>Rabatt %</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    ${inventoryRows || '<tr><td colspan="10" class="admin-empty">Keine Produkte gepflegt.</td></tr>'}
                </tbody>
            </table>
        </div>
        <button type="button" class="btn secondary" data-action="add-item">+ Produkt hinzufügen</button>
    `);

    const routesHtml = draft.routes.map((route, routeIndex) => {
        const pointRows = route.points.map((point, pointIndex) => `
            <div class="admin-point-row" data-index="${pointIndex}">
                <label>X<input type="number" step="0.01" data-group="route-point" data-route-index="${routeIndex}" data-point-index="${pointIndex}" data-key="x" value="${toNumber(point.x, 0)}"></label>
                <label>Y<input type="number" step="0.01" data-group="route-point" data-route-index="${routeIndex}" data-point-index="${pointIndex}" data-key="y" value="${toNumber(point.y, 0)}"></label>
                <label>Z<input type="number" step="0.01" data-group="route-point" data-route-index="${routeIndex}" data-point-index="${pointIndex}" data-key="z" value="${toNumber(point.z, 0)}"></label>
                <label>Label<input type="text" data-group="route-point" data-route-index="${routeIndex}" data-point-index="${pointIndex}" data-key="label" value="${escapeHtml(point.label || '')}"></label>
                <div class="admin-point-row__actions">
                    <button type="button" class="btn ghost" data-action="capture-point" data-point-type="route" data-route-index="${routeIndex}" data-point-index="${pointIndex}">Position</button>
                    <button type="button" class="btn ghost" data-action="remove-route-point" data-route-index="${routeIndex}" data-point-index="${pointIndex}">&times;</button>
                </div>
            </div>
        `).join('');
        return `
            <div class="admin-route" data-route-index="${routeIndex}">
                <div class="admin-route__header">
                    <label>Routenname<input type="text" data-group="routes" data-index="${routeIndex}" data-key="label" value="${escapeHtml(route.label || '')}"></label>
                    <button type="button" class="btn ghost" data-action="remove-route" data-index="${routeIndex}">&times;</button>
                </div>
                <div class="admin-point-list">${pointRows || '<div class="admin-empty">Keine Wegpunkte.</div>'}</div>
                <div class="admin-route__actions">
                    <button type="button" class="btn secondary" data-action="add-route-point" data-route-index="${routeIndex}">+ Wegpunkt</button>
                    <button type="button" class="btn secondary" data-action="add-route-point-current" data-route-index="${routeIndex}">+ Wegpunkt (Position)</button>
                </div>
            </div>
        `;
    }).join('');
    addSection('routes', 'Liefer-Routen', `
        <div class="admin-route-list">${routesHtml || '<div class="admin-empty">Keine Routen definiert.</div>'}</div>
        <button type="button" class="btn secondary" data-action="add-route">+ Route hinzufügen</button>
    `);

    container.innerHTML = `
        <div class="admin-form">
            ${sections.map((section) => `
                <section id="admin-section-${section.key}" class="admin-section">
                    <h3>${escapeHtml(section.title)}</h3>
                    ${section.body}
                </section>
            `).join('')}
        </div>
    `;

    renderAdminSectionNav(sections);
    updateAdminSaveButton();
};

const selectAdminShop = (identifier) => {
    if (!identifier) return;
    state.admin.view = 'editor';
    state.admin.activeSection = 'general';
    state.admin.createMode = false;
    if (identifier === state.admin.selected) {
        state.admin.draft = buildAdminDraft(getAdminSelectedShop());
        state.admin.dirty = false;
        renderAdminList();
        renderAdminDetail();
        return;
    }
    state.admin.selected = identifier;
    state.admin.draft = buildAdminDraft(getAdminSelectedShop());
    state.admin.dirty = false;
    renderAdminList();
    renderAdminDetail();
};

const markAdminDirty = () => {
    state.admin.dirty = true;
    updateAdminSaveButton();
};

const addAdminPoint = (type) => {
    if (!state.admin.draft) return;
    const list = state.admin.draft[type];
    if (!Array.isArray(list)) return;
    if (type === 'depots' && Array.isArray(state.admin.config.depots) && state.admin.config.depots.length) {
        const defaultDepot = state.admin.config.depots[0];
        const coords = defaultDepot.coords || defaultDepot;
        list.push({
            x: Number(coords?.x ?? 0),
            y: Number(coords?.y ?? 0),
            z: Number(coords?.z ?? 0),
            heading: Number(defaultDepot.heading ?? 0),
            label: defaultDepot.label || '',
        });
    } else {
        list.push({
            x: state.admin.draft.coords.x,
            y: state.admin.draft.coords.y,
            z: state.admin.draft.coords.z,
            heading: state.admin.draft.coords.heading,
            label: '',
        });
    }
    markAdminDirty();
    renderAdminDetail();
};

const addAdminPointFromCoords = (type, coords) => {
    if (!state.admin.draft) return;
    const list = state.admin.draft[type];
    if (!Array.isArray(list)) return;
    const base = sanitizeCoords(coords || state.admin.draft.coords);
    list.push({
        x: base.x,
        y: base.y,
        z: base.z,
        heading: base.heading,
        label: '',
    });
    markAdminDirty();
    renderAdminDetail();
};

const removeAdminPoint = (type, index) => {
    if (!state.admin.draft) return;
    const list = state.admin.draft[type];
    if (!Array.isArray(list)) return;
    list.splice(index, 1);
    markAdminDirty();
    renderAdminDetail();
};

const addInventoryItem = () => {
    if (!state.admin.draft) return;
    state.admin.draft.inventory = Array.isArray(state.admin.draft.inventory) ? state.admin.draft.inventory : [];
    state.admin.draft.inventory.push({
        id: null,
        item: '',
        label: '',
        icon: '',
        category: '',
        quantity: 0,
        basePrice: 0,
        overridePrice: 0,
        minLevel: 1,
        discount: 0,
    });
    markAdminDirty();
    renderAdminDetail();
};

const removeInventoryItem = (index) => {
    if (!state.admin.draft || !Array.isArray(state.admin.draft.inventory)) return;
    state.admin.draft.inventory.splice(index, 1);
    markAdminDirty();
    renderAdminDetail();
};

const addVehicleSpawn = (coords) => {
    if (!state.admin.draft) return;
    state.admin.draft.vehicleSpawns = Array.isArray(state.admin.draft.vehicleSpawns) ? state.admin.draft.vehicleSpawns : [];
    const base = sanitizeCoords(coords || state.admin.draft.coords);
    state.admin.draft.vehicleSpawns.push({
        x: base.x,
        y: base.y,
        z: base.z,
        heading: base.heading,
        label: '',
    });
    markAdminDirty();
    renderAdminDetail();
};

const removeVehicleSpawn = (index) => {
    if (!state.admin.draft || !Array.isArray(state.admin.draft.vehicleSpawns)) return;
    state.admin.draft.vehicleSpawns.splice(index, 1);
    markAdminDirty();
    renderAdminDetail();
};

const addVehicleFromTemplate = (key) => {
    if (!state.admin.draft || !key) return;
    const templates = state.admin.config.vehicleTemplates || {};
    const template = templates[key];
    if (!template) {
        showNotification('Keine Fahrzeugvorlage gefunden.', 'error', 3000);
        return;
    }
    state.admin.draft.vehicles = Array.isArray(state.admin.draft.vehicles) ? state.admin.draft.vehicles : [];
    if (state.admin.draft.vehicles.some((vehicle) => vehicle.key === key)) {
        showNotification('Fahrzeug ist bereits hinterlegt.', 'warning', 2500);
        return;
    }
    const normalized = normalizeVehicleDraftEntry({ ...template, key });
    if (!normalized) {
        showNotification('Fahrzeugdaten konnten nicht übernommen werden.', 'error', 3000);
        return;
    }
    state.admin.draft.vehicles.push(normalized);
    markAdminDirty();
    renderAdminDetail();
};

const addManualVehicle = () => {
    if (!state.admin.draft) return;
    state.admin.draft.vehicles = Array.isArray(state.admin.draft.vehicles) ? state.admin.draft.vehicles : [];
    state.admin.draft.vehicles.push({
        key: '',
        label: '',
        model: '',
        price: 0,
        minLevel: 1,
        capacity: 0,
        trunk: 0,
        fuelModifier: 1,
    });
    markAdminDirty();
    renderAdminDetail();
};

const removeVehicle = (index) => {
    if (!state.admin.draft || !Array.isArray(state.admin.draft.vehicles)) return;
    state.admin.draft.vehicles.splice(index, 1);
    markAdminDirty();
    renderAdminDetail();
};

const addRoute = (coords) => {
    if (!state.admin.draft) return;
    state.admin.draft.routes = Array.isArray(state.admin.draft.routes) ? state.admin.draft.routes : [];
    const nextIndex = state.admin.draft.routes.length + 1;
    const route = {
        label: `Route ${nextIndex}`,
        points: [],
    };
    if (coords) {
        route.points.push({ x: coords.x, y: coords.y, z: coords.z, label: 'Start' });
    }
    state.admin.draft.routes.push(route);
    markAdminDirty();
    renderAdminDetail();
};

const removeRoute = (index) => {
    if (!state.admin.draft || !Array.isArray(state.admin.draft.routes)) return;
    state.admin.draft.routes.splice(index, 1);
    markAdminDirty();
    renderAdminDetail();
};

const addRoutePoint = (routeIndex, coords) => {
    if (!state.admin.draft || !Array.isArray(state.admin.draft.routes)) return;
    const route = state.admin.draft.routes[routeIndex];
    if (!route) return;
    route.points = Array.isArray(route.points) ? route.points : [];
    const position = coords ? { x: coords.x, y: coords.y, z: coords.z, label: '' } : {
        x: state.admin.draft.coords.x,
        y: state.admin.draft.coords.y,
        z: state.admin.draft.coords.z,
        label: '',
    };
    route.points.push(position);
    markAdminDirty();
    renderAdminDetail();
};

const removeRoutePoint = (routeIndex, pointIndex) => {
    if (!state.admin.draft || !Array.isArray(state.admin.draft.routes)) return;
    const route = state.admin.draft.routes[routeIndex];
    if (!route || !Array.isArray(route.points)) return;
    route.points.splice(pointIndex, 1);
    markAdminDirty();
    renderAdminDetail();
};

const parseAdminValue = (input) => {
    if (input.type === 'number') {
        const parsed = Number(input.value);
        return Number.isFinite(parsed) ? parsed : 0;
    }
    return input.value;
};

const handleAdminInput = (event) => {
    if (state.view !== 'admin' || !state.admin.draft) return;
    const target = event.target;
    const field = target.dataset.field;
    if (field && target.type !== 'select-one') {
        state.admin.draft[field] = parseAdminValue(target);
        markAdminDirty();
        return;
    }

    const group = target.dataset.group;
    const key = target.dataset.key;
    if (!group || !key) return;

    const value = parseAdminValue(target);
    if (group === 'coords') {
        state.admin.draft.coords[key] = value;
    } else if (group === 'ped') {
        state.admin.draft.ped[key] = value;
    } else if (group === 'zone') {
        state.admin.draft.zone[key] = value;
    } else if (group === 'dropoffs' || group === 'depots' || group === 'vehicleSpawns') {
        const index = Number(target.dataset.index);
        if (!Number.isInteger(index) || !state.admin.draft[group][index]) return;
        state.admin.draft[group][index][key] = value;
    } else if (group === 'inventory') {
        const index = Number(target.dataset.index);
        if (!Number.isInteger(index) || !state.admin.draft.inventory[index]) return;
        state.admin.draft.inventory[index][key] = value;
    } else if (group === 'routes') {
        const index = Number(target.dataset.index);
        if (!Number.isInteger(index) || !state.admin.draft.routes[index]) return;
        state.admin.draft.routes[index][key] = value;
    } else if (group === 'route-point') {
        const routeIndex = Number(target.dataset.routeIndex);
        const pointIndex = Number(target.dataset.pointIndex);
        if (!Number.isInteger(routeIndex) || !Number.isInteger(pointIndex)) return;
        const route = state.admin.draft.routes[routeIndex];
        if (!route || !route.points || !route.points[pointIndex]) return;
        route.points[pointIndex][key] = value;
    } else if (group === 'vehicles') {
        const index = Number(target.dataset.index);
        if (!Number.isInteger(index) || !state.admin.draft.vehicles?.[index]) return;
        const vehicle = state.admin.draft.vehicles[index];
        if (target.type === 'checkbox') {
            vehicle[key] = target.checked;
        } else if (['price', 'minLevel', 'capacity', 'trunk'].includes(key)) {
            vehicle[key] = toNumber(value, 0);
        } else if (key === 'fuelModifier') {
            const modifier = parseFloat(target.value);
            vehicle.fuelModifier = Number.isFinite(modifier) && modifier > 0 ? modifier : 1;
        } else {
            vehicle[key] = target.value;
        }
    } else if (group === 'blip') {
        state.admin.draft.blip = state.admin.draft.blip || {
            enabled: false,
            sprite: 59,
            color: 1,
            scale: 0.8,
            label: '',
            shortRange: true,
        };
        if (key === 'enabled' || key === 'shortRange') {
            state.admin.draft.blip[key] = target.checked;
        } else if (key === 'scale') {
            const scale = parseFloat(target.value);
            state.admin.draft.blip.scale = Number.isFinite(scale) ? scale : 0.8;
        } else if (key === 'sprite' || key === 'color') {
            state.admin.draft.blip[key] = toNumber(target.value, key === 'sprite' ? 59 : 1);
        } else if (key === 'label') {
            state.admin.draft.blip.label = target.value;
        } else {
            state.admin.draft.blip[key] = value;
        }
    }
    markAdminDirty();
};

const handleAdminCollectionChange = (collection, value, checked) => {
    if (!state.admin.draft) return;
    state.admin.draft[collection] = Array.isArray(state.admin.draft[collection]) ? state.admin.draft[collection] : [];
    const exists = state.admin.draft[collection].includes(value);
    if (checked && !exists) {
        state.admin.draft[collection].push(value);
    }
    if (!checked && exists) {
        state.admin.draft[collection] = state.admin.draft[collection].filter((entry) => entry !== value);
    }
    markAdminDirty();
};

const handleAdminChange = (event) => {
    if (state.view !== 'admin' || !state.admin.draft) return;
    const target = event.target;
    const collection = target.dataset.collection;
    if (collection) {
        handleAdminCollectionChange(collection, target.value, target.checked);
        return;
    }

    const field = target.dataset.field;
    if (field) {
        if (field === 'type') {
            state.admin.draft.type = target.value;
            state.admin.draft.products = [];
            state.admin.activeSection = 'general';
            markAdminDirty();
            renderAdminDetail();
        } else {
            state.admin.draft[field] = parseAdminValue(target);
            markAdminDirty();
        }
        return;
    }

    if (target.dataset.group) {
        handleAdminInput(event);
    }
};

const startAdminCreateFlow = async () => {
    const coords = await fetchCurrentPosition();
    const baseType = state.admin.draft?.type || Object.keys(state.admin.config.shopTypes || {})[0] || '';
    state.admin.draft = buildNewAdminDraft(baseType, coords || state.admin.draft?.coords || {});
    state.admin.view = 'editor';
    state.admin.activeSection = 'general';
    state.admin.createMode = true;
    state.admin.dirty = true;
    state.admin.pendingSelection = null;
    renderAdminList();
    renderAdminDetail();
    updateAdminSaveButton();
    updateAdminActionButtons();
};

const cancelAdminCreate = () => {
    state.admin.createMode = false;
    state.admin.pendingSelection = null;
    if (state.admin.selected) {
        state.admin.view = 'editor';
        state.admin.activeSection = 'general';
        state.admin.draft = buildAdminDraft(getAdminSelectedShop());
    } else {
        state.admin.view = 'dashboard';
        state.admin.draft = null;
    }
    state.admin.dirty = false;
    renderAdminList();
    renderAdminDetail();
    updateAdminSaveButton();
    updateAdminActionButtons();
};

const handleAdminClick = async (event) => {
    if (state.view !== 'admin') return;
    const el = event.target.closest('[data-action]');
    if (!el) return;
    const action = el.dataset.action;
    if (action === 'select-shop') {
        const identifier = el.dataset.identifier;
        if (identifier) {
            selectAdminShop(identifier);
        }
    } else if (action === 'select-new') {
        if (!state.admin.createMode && state.admin.draft?.isNew) {
            state.admin.createMode = true;
            renderAdminList();
            renderAdminDetail();
            updateAdminActionButtons();
        }
    } else if (action === 'admin-show-dashboard') {
        state.admin.view = 'dashboard';
        state.admin.createMode = false;
        state.admin.draft = null;
        state.admin.dirty = false;
        renderAdminList();
        renderAdminDetail();
        updateAdminActionButtons();
        updateAdminSaveButton();
    } else if (action === 'admin-start-create') {
        await startAdminCreateFlow();
    } else if (action === 'admin-cancel-create') {
        cancelAdminCreate();
    } else if (action === 'add-dropoff') {
        addAdminPoint('dropoffs');
    } else if (action === 'add-dropoff-current') {
        const coords = await fetchCurrentPosition();
        if (coords) addAdminPointFromCoords('dropoffs', coords);
    } else if (action === 'remove-dropoff') {
        const index = Number(el.dataset.index);
        if (Number.isInteger(index)) removeAdminPoint('dropoffs', index);
    } else if (action === 'add-depot') {
        addAdminPoint('depots');
    } else if (action === 'add-depot-current') {
        const coords = await fetchCurrentPosition();
        if (coords) addAdminPointFromCoords('depots', coords);
    } else if (action === 'remove-depot') {
        const index = Number(el.dataset.index);
        if (Number.isInteger(index)) removeAdminPoint('depots', index);
    } else if (action === 'add-vehicle-spawn') {
        addVehicleSpawn();
    } else if (action === 'add-vehicle-spawn-current') {
        const coords = await fetchCurrentPosition();
        addVehicleSpawn(coords);
    } else if (action === 'remove-vehicle-spawn') {
        const index = Number(el.dataset.index);
        if (Number.isInteger(index)) removeVehicleSpawn(index);
    } else if (action === 'add-item') {
        addInventoryItem();
    } else if (action === 'remove-item') {
        const index = Number(el.dataset.index);
        if (Number.isInteger(index)) removeInventoryItem(index);
    } else if (action === 'add-route') {
        const coords = await fetchCurrentPosition();
        addRoute(coords || null);
    } else if (action === 'remove-route') {
        const index = Number(el.dataset.index);
        if (Number.isInteger(index)) removeRoute(index);
    } else if (action === 'add-route-point') {
        const routeIndex = Number(el.dataset.routeIndex);
        if (Number.isInteger(routeIndex)) addRoutePoint(routeIndex);
    } else if (action === 'add-route-point-current') {
        const routeIndex = Number(el.dataset.routeIndex);
        if (Number.isInteger(routeIndex)) {
            const coords = await fetchCurrentPosition();
            addRoutePoint(routeIndex, coords || null);
        }
    } else if (action === 'remove-route-point') {
        const routeIndex = Number(el.dataset.routeIndex);
        const pointIndex = Number(el.dataset.pointIndex);
        if (Number.isInteger(routeIndex) && Number.isInteger(pointIndex)) {
            removeRoutePoint(routeIndex, pointIndex);
        }
    } else if (action === 'admin-add-vehicle-template') {
        const select = document.querySelector('[data-role="vehicle-template"]');
        const templateKey = select?.value?.trim();
        if (templateKey) {
            addVehicleFromTemplate(templateKey);
            select.value = '';
        }
    } else if (action === 'admin-add-vehicle-manual') {
        addManualVehicle();
    } else if (action === 'remove-vehicle') {
        const index = Number(el.dataset.index);
        if (Number.isInteger(index)) removeVehicle(index);
    } else if (action === 'admin-scroll-section') {
        const sectionKey = el.dataset.section;
        const targetId = el.dataset.target;
        if (sectionKey) {
            state.admin.activeSection = sectionKey;
            const nav = document.getElementById('admin-section-nav');
            if (nav) {
                nav.querySelectorAll('[data-section]').forEach((button) => {
                    button.classList.toggle('active', button.dataset.section === sectionKey);
                });
            }
        }
        if (targetId) {
            const section = document.getElementById(targetId);
            if (section) {
                section.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
    } else if (action === 'capture-coords') {
        const coords = await fetchCurrentPosition();
        if (coords && state.admin.draft) {
            state.admin.draft.coords = coords;
            updateZoneFromCoords(state.admin.draft, coords);
            markAdminDirty();
            renderAdminDetail();
        }
    } else if (action === 'capture-zone') {
        const coords = await fetchCurrentPosition();
        if (coords && state.admin.draft) {
            updateZoneFromCoords(state.admin.draft, coords);
            state.admin.draft.coords.z = coords.z;
            markAdminDirty();
            renderAdminDetail();
        }
    } else if (action === 'capture-point') {
        const pointType = el.dataset.pointType;
        const coords = await fetchCurrentPosition();
        if (!coords || !state.admin.draft) return;
        if (pointType === 'route') {
            const routeIndex = Number(el.dataset.routeIndex);
            const pointIndex = Number(el.dataset.pointIndex);
            if (!Number.isInteger(routeIndex) || !Number.isInteger(pointIndex)) return;
            const route = state.admin.draft.routes?.[routeIndex];
            if (!route || !route.points?.[pointIndex]) return;
            route.points[pointIndex].x = coords.x;
            route.points[pointIndex].y = coords.y;
            route.points[pointIndex].z = coords.z;
            markAdminDirty();
            renderAdminDetail();
            return;
        }
        const index = Number(el.dataset.index);
        if (!Number.isInteger(index)) return;
        const list = state.admin.draft[pointType];
        if (!Array.isArray(list) || !list[index]) return;
        list[index].x = coords.x;
        list[index].y = coords.y;
        list[index].z = coords.z;
        if (typeof coords.heading === 'number') {
            list[index].heading = coords.heading;
        }
        markAdminDirty();
        renderAdminDetail();
    } else if (action === 'admin-save') {
        if (el.classList.contains('disabled') || !state.admin.draft) return;
        const payload = clone(state.admin.draft);
        payload.isNew = state.admin.createMode || state.admin.draft.isNew;
        if (payload.isNew) {
            payload.identifier = normalizeIdentifier(payload.identifier || '');
            if (!payload.identifier) {
                updateAdminSaveButton();
                return;
            }
            state.admin.draft.identifier = payload.identifier;
        }
        state.admin.pendingSelection = payload.identifier;
        const result = await nuiInvoke('adminSaveShop', payload);
        if (!result || !result.success) {
            state.admin.pendingSelection = null;
            state.admin.dirty = true;
            updateAdminSaveButton();
            if (result && result.message) {
                showNotification(result.message, 'error', 4000);
            } else {
                showNotification('Shop konnte nicht gespeichert werden.', 'error', 4000);
            }
            return;
        }
        state.admin.dirty = false;
        if (result.payload) {
            setAdminData(result.payload);
            renderAdminList();
            renderAdminDetail();
            updateAdminActionButtons();
        }
        showNotification('Shop erfolgreich gespeichert.', 'success', 2500);
        updateAdminSaveButton();
    } else if (action === 'admin-reset') {
        if (state.admin.createMode) {
            cancelAdminCreate();
        } else {
            state.admin.draft = buildAdminDraft(getAdminSelectedShop());
            state.admin.dirty = false;
            if (state.admin.draft) {
                state.admin.view = 'editor';
                state.admin.activeSection = 'general';
            } else {
                state.admin.view = 'dashboard';
            }
            renderAdminDetail();
            updateAdminSaveButton();
        }
    }
};

const adminView = document.getElementById('admin-view');
if (adminView) {
    adminView.addEventListener('input', handleAdminInput);
    adminView.addEventListener('change', handleAdminChange);
    adminView.addEventListener('click', handleAdminClick);
}

const syncAccessFlags = () => {
    if (!state.meta) state.meta = {};
    const meta = state.meta;
    const shop = state.shop;
    const citizenId = meta.citizenid;
    const ownerId = shop?.owner;
    const wasOwner = Boolean(meta.isOwner);
    const isOwnerNow = Boolean(citizenId && ownerId && ownerId === citizenId);
    meta.isOwner = isOwnerNow;
    if (isOwnerNow) {
        meta.canManage = true;
    } else if (wasOwner && !isOwnerNow) {
        meta.canManage = false;
    } else if (typeof meta.canManage !== 'boolean') {
        meta.canManage = false;
    }
};

const updateHeaderActions = () => {
    const btnManagement = document.getElementById('btn-open-management');
    if (btnManagement) {
        btnManagement.classList.toggle('hidden', !state.meta?.canManage);
    }

    const btnSell = document.getElementById('btn-sell-shop');
    if (btnSell) {
        btnSell.classList.toggle('hidden', !state.meta?.isOwner);
        btnSell.disabled = !state.meta?.isOwner;
    }

    const btnBuy = document.getElementById('btn-buy-shop');
    if (btnBuy) {
        const canBuy = Boolean(state.shop && !state.shop.owner);
        btnBuy.classList.toggle('hidden', !canBuy);
        btnBuy.disabled = !canBuy;
    }

    const btnAdmin = document.getElementById('btn-open-admin');
    if (btnAdmin) {
        btnAdmin.classList.toggle('hidden', !state.meta?.isAdmin);
    }
};

const toggleView = (view) => {
    let targetView = view;
    if (targetView === 'management' && !state.meta?.canManage) {
        targetView = 'shop';
    }
    if (targetView === 'admin' && !state.meta?.isAdmin) {
        targetView = 'shop';
    }
    state.view = targetView;
    document.getElementById('shop-view').classList.toggle('hidden', targetView !== 'shop');
    document.getElementById('management-view').classList.toggle('hidden', targetView !== 'management');
    document.getElementById('admin-view').classList.toggle('hidden', targetView !== 'admin');
};

const render = () => {
    const app = document.getElementById('app');
    if (!state.visible) {
        document.body.classList.remove('nui-active');
        document.body.style.display = 'none';
        if (app) app.classList.add('hidden');
        return;
    }

    document.body.classList.add('nui-active');
    document.body.style.display = 'block';
    if (app) app.classList.remove('hidden');

    syncAccessFlags();
    updateHeaderActions();

    updateShopHeader();
    renderCategories();
    renderProducts();
    renderCart();
    renderManagementTabs();
    renderManagementPanel();
    renderAdminList();
    renderAdminDetail();
    updateAdminActionButtons();
    toggleView(state.view);
    renderNotifications();
};

const addToCart = (itemId) => {
    const item = getItemById(itemId);
    if (!item) return;
    const pricing = calculateItemPricing(item);
    const price = pricing.finalPrice;
    const existing = state.cart.find((entry) => entry.id === itemId);
    if (existing) {
        if (existing.quantity >= item.quantity) return;
        existing.quantity += 1;
    } else {
        state.cart.push({
            id: itemId,
            item: item.item,
            label: item.label,
            price,
            quantity: 1,
        });
    }
    renderCart();
};

const adjustCartQuantity = (itemId, delta) => {
    const entry = state.cart.find((item) => item.id === itemId);
    const item = getItemById(itemId);
    if (!entry || !item) return;
    entry.quantity = Math.min(Math.max(entry.quantity + delta, 1), item.quantity);
    renderCart();
};

const removeCartItem = (itemId) => {
    state.cart = state.cart.filter((item) => item.id !== itemId);
    renderCart();
};

const bindEvents = () => {
    const categoryList = document.getElementById('category-list');
    if (categoryList) {
        categoryList.addEventListener('click', (event) => {
            const category = event.target.closest('.category');
            if (!category) return;
            state.selectedCategory = category.dataset.category;
            renderProducts();
            renderCategories();
        });
    }

    const productGrid = document.getElementById('product-grid');
    if (productGrid) {
        productGrid.addEventListener('click', (event) => {
            const button = event.target.closest('[data-action="add-product"]');
            if (!button) return;
            addToCart(Number(button.dataset.itemId));
        });
    }

    const cartItems = document.getElementById('cart-items');
    if (cartItems) {
        cartItems.addEventListener('click', (event) => {
            const target = event.target;
            const itemId = Number(target.dataset.itemId || target.closest('[data-item-id]')?.dataset.itemId);
            if (!itemId) return;

            const action = target.dataset.action;
            if (action === 'increase') {
                adjustCartQuantity(itemId, 1);
            } else if (action === 'decrease') {
                adjustCartQuantity(itemId, -1);
            } else if (action === 'remove-item') {
                removeCartItem(itemId);
            }
        });
    }

    const cartFooter = document.querySelector('.cart-footer');
    if (cartFooter) {
        cartFooter.addEventListener('click', (event) => {
            const button = event.target.closest('[data-payment]');
            if (!button || state.cart.length === 0) return;
            send('purchase', { cart: state.cart, payWith: button.dataset.payment });
            state.cart = [];
            renderCart();
        });
    }

    const btnClose = document.getElementById('btn-close');
    if (btnClose) btnClose.addEventListener('click', () => send('close'));

    const btnManagement = document.getElementById('btn-open-management');
    if (btnManagement) {
        btnManagement.addEventListener('click', () => {
            if (!state.meta?.canManage) return;
            send('openManagement');
        });
    }

    const btnAdmin = document.getElementById('btn-open-admin');
    if (btnAdmin) btnAdmin.addEventListener('click', () => {
        if (!state.meta?.isAdmin) return;
        state.view = 'admin';
        render();
    });

    const btnSell = document.getElementById('btn-sell-shop');
    if (btnSell) {
        btnSell.addEventListener('click', () => {
            if (!state.meta?.isOwner) return;
            send('sellShop');
        });
    }

    const btnBuy = document.getElementById('btn-buy-shop');
    if (btnBuy) {
        btnBuy.addEventListener('click', () => {
            if (!state.shop || state.shop.owner) return;
            send('buyShop');
        });
    }

    const tabsNav = document.getElementById('management-tabs');
    if (tabsNav) {
        tabsNav.addEventListener('click', (event) => {
            const button = event.target.closest('[data-tab]');
            if (!button) return;
            state.managementTab = button.dataset.tab;
            renderManagementTabs();
            renderManagementPanel();
        });
    }

    const managementPanel = document.getElementById('management-panel');
    if (managementPanel) {
        managementPanel.addEventListener('submit', (event) => {
            const form = event.target;
            const action = form.dataset.action;
            if (!action) return;
            event.preventDefault();

            if (action === 'set-price') {
                const price = Number(form.querySelector('input').value);
                send('setPrice', { itemId: Number(form.dataset.itemId), price });
            } else if (action === 'set-item-discount') {
                const discount = Number(form.querySelector('input').value);
                send('setItemDiscount', { itemId: Number(form.dataset.itemId), discount });
            } else if (action === 'set-discount') {
                const discount = Number(form.querySelector('input').value);
                send('setDiscount', { discount });
            } else if (action === 'hire-employee') {
                const data = Object.fromEntries(new FormData(form).entries());
                send('hireEmployee', {
                    citizenid: data.citizenid,
                    role: data.role,
                    wage: Number(data.wage),
                });
                form.reset();
            } else if (action === 'create-delivery') {
                const vehicle = form.querySelector('select[name="vehicle"]')?.value;
                const label = form.querySelector('input[name="label"]')?.value?.trim() || '';
                const rows = Array.from(form.querySelectorAll('[data-role="delivery-row"]'));
                const items = rows.map((row) => {
                    const select = row.querySelector('[data-role="item-select"]');
                    const quantityInput = row.querySelector('[data-role="item-quantity"]');
                    const itemId = Number(select?.value);
                    const quantity = Number(quantityInput?.value || 0);
                    if (!itemId || quantity <= 0) return null;
                    const itemData = getItemById(itemId);
                    if (!itemData) return null;
                    return {
                        item: itemData.item,
                        label: itemData.label,
                        quantity,
                    };
                }).filter(Boolean);

                if (!vehicle || items.length === 0) {
                    return;
                }

                send('createDelivery', { vehicle, label, items });
                form.reset();
                const container = form.querySelector('[data-role="delivery-items"]');
                if (container) container.innerHTML = '';
                setupDeliveryForm(form.closest('.panel'));
            } else if (action === 'deposit' || action === 'withdraw') {
                const amount = Number(form.querySelector('input').value);
                send(action, { amount });
                form.reset();
            }
        });

        managementPanel.addEventListener('click', (event) => {
            const target = event.target;
            const action = target.dataset.action;
            if (!action) return;

            if (action === 'fire-employee') {
                send('fireEmployee', { citizenid: target.dataset.citizenid });
            } else if (action === 'start-delivery') {
                const deliveryId = target.dataset.delivery;
                const vehicle = target.dataset.vehicle || null;
                send('startDelivery', { deliveryId, vehicle });
            } else if (action === 'unlock-vehicle') {
                const vehicle = target.dataset.vehicle;
                if (!vehicle) return;
                send('unlockVehicle', { vehicle });
            }
        });
    }

    const notificationsEl = document.getElementById('notifications');
    if (notificationsEl) {
        notificationsEl.addEventListener('click', (event) => {
            const close = event.target.closest('[data-action="notification-close"]');
            if (!close) return;
            const id = close.dataset.id;
            removeNotification(id);
        });
    }
};

window.addEventListener('message', (event) => {
    const data = event.data;
    switch (data.action) {
        case 'openShop':
            state.visible = true;
            state.view = 'shop';
            state.shop = data.shop;
            state.shop.vehicleOwnership = state.shop.vehicleOwnership || {};
            state.meta = data.meta || {};
            state.cart = [];
            state.selectedCategory = null;
            state.managementTab = 'dashboard';
            ensureSelectedCategory();
            render();
            break;
        case 'openManagement':
            state.visible = true;
            state.view = 'management';
            state.shop = data.shop;
            state.shop.vehicleOwnership = state.shop.vehicleOwnership || {};
            state.meta = data.meta || {};
            state.managementTab = 'dashboard';
            ensureSelectedCategory();
            render();
            break;
        case 'openAdminOverview':
            state.visible = true;
            state.view = 'admin';
            state.admin.view = 'dashboard';
            state.admin.activeSection = 'general';
            setAdminData(data || {});
            state.meta = { isAdmin: true };
            render();
            break;
        case 'close':
            state.visible = false;
            state.shop = null;
            state.cart = [];
            state.meta = {};
            state.notifications = [];
            render();
            renderNotifications();
            break;
        case 'refreshShop': {
            const previousShop = state.shop;
            state.shop = data.shop;
            if (previousShop?.stats && !state.shop.stats) {
                state.shop.stats = previousShop.stats;
            }
            state.shop.vehicleOwnership = state.shop.vehicleOwnership || {};
            render();
            break;
        }
        case 'refreshDeliveries':
            if (state.shop) {
                state.shop.deliveries = data.deliveries;
                if (state.view === 'management') {
                    renderManagementPanel();
                }
            }
            break;
        case 'notify':
            showNotification(data.message, data.type || 'info', data.duration || 5000);
            break;
        default:
            break;
    }
});

document.addEventListener('DOMContentLoaded', () => {
    document.body.classList.remove('nui-active');
    document.body.style.display = 'none';
    bindEvents();
    render();
});
