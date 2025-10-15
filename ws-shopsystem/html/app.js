const state = {
    visible: false,
    view: 'shop',
    shop: null,
    meta: {},
    cart: [],
    selectedCategory: null,
    managementTab: 'dashboard',
    adminShops: [],
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
    fetch(`https://ws-shopsystem/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data),
    });
};

const currency = (value) => `$${Number(value || 0).toLocaleString('de-DE')}`;

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

const getVehicleCapacity = (vehicleKey) => Number(state.shop?.deliveryVehicles?.[vehicleKey]?.capacity ?? 0);

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

const renderDashboardPanel = () => {
    const shop = state.shop;
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

const renderAdminList = () => {
    const container = document.getElementById('admin-list');
    if (!container) return;
    container.innerHTML = '';
    state.adminShops.forEach((shop) => {
        const card = document.createElement('div');
        card.classList.add('admin-card');
        card.innerHTML = `
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
        container.appendChild(card);
    });
};

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
    toggleView(state.view);
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
            state.adminShops = data.shops || [];
            state.meta = { isAdmin: true };
            render();
            break;
        case 'close':
            state.visible = false;
            state.shop = null;
            state.cart = [];
            state.meta = {};
            render();
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
