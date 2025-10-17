# WS-Shopsystem Admin-/Creator-Panel – aktualisiertes Konzept

## Überblick

Das Admin-Panel des WS-Shopsystems wurde so konzipiert, dass sämtliche Shop-bezogenen Einstellungen ingame vorgenommen werden können. Die aktuelle Umsetzung bietet:

- ein Dashboard mit Kartenübersicht aller Shops samt Status, Level und Kernkennzahlen,
- eine rechte Seitenleiste für die Abschnitts-Navigation im Editor (Allgemein, Standort, NPC, Blip, Dropoffs, Depots, Fahrzeug-Spawns, Fahrzeuge, Produkte, Routen),
- einen Blip-Builder inklusive Vorschau-Parametern (Sprite, Farbe, Skalierung, Short-Range),
- einen Fahrzeug-Editor mit Template-Unterstützung (Preise, Level, Kapazitäten, Verbrauchsfaktoren),
- UI-Notifications direkt im Panel für Erfolgs- und Fehlermeldungen sowie Hinweise,
- persistente Speicherung aller Einstellungen in der Datenbank ohne manuelle Änderungen an `config.lua`.

Das Dokument beschreibt die relevanten UX-Flows, Datenmodelle und Server-/Client-Komponenten der aktuellen Version, damit Erweiterungen und Reviews auf derselben Wissensbasis stattfinden können.

## UX-Flows

### Dashboard

1. **Einstieg**: `/shopadmin` öffnet das Panel auf dem Dashboard.
2. **Shop-Karten**: Jede Karte zeigt Name, Typ, Level, Koordinaten, aktiven Blip-Status, Depot-/Dropoff-Zähler und Fahrzeuganzahl.
3. **Aktionen**: Über die Karte kann direkt in den Editor gewechselt oder ein neuer Shop-Draft erstellt werden. Die Sidebar listet zusätzlich alle Shops als Schnellfilter.

### Abschnitts-Navigation (rechte Sidebar)

Die Navigation bleibt beim Scrollen sichtbar und ermöglicht den Direkt-Sprung zu einzelnen Formularbereichen.

- **Allgemein**: Name, Typ, Kauf-/Verkaufspreis, globale Metadaten.
- **Standort**: Koordinaten aufnehmen (Spielerposition), Zone definieren, NPC setzen.
- **NPC**: Ped-Modell und Scenario.
- **Blip**: Aktivierung, Sprite, Farbe, Skalierung, Label, Short-Range.
- **Dropoffs / Depots / Fahrzeug-Spawns**: Punktlisten mit Koordinatenaufnahme und Sortierung.
- **Fahrzeuge**: Fahrzeugpools mit Template-Support, Preis, Level, Kapazität, Kofferraum, Treibstoff-Modifikator.
- **Produkte**: Kategorien-Zuweisung an den Shop (Inventar wird automatisch mit Datenbank synchronisiert).
- **Routen**: Mehrpunkt-Routen pro Shop mit Label und Koordinaten.

### Speichern & Notifications

1. Änderungen aktivieren den Speicher-Button und markieren die Navigation als „dirty“.
2. Beim Speichern ruft das UI den Callback `ws-shopsystem:server:adminSaveShop` auf.
3. Serverseitig erfolgen Validierung (inkl. Blip-Checks), Datenbank-Persistenz und Cache-Refresh.
4. Erfolg und Fehler werden sowohl per QB-Notify als auch durch die NUI-Notifications angezeigt.

### Fahrzeugverwaltung im Bossmenü

- Fahrzeugkonfigurationen aus dem Admin-Panel stehen sofort im Bossmenü zur Verfügung.
- Level-Gating und Kaufpreise stammen aus den gespeicherten Fahrzeugpools.
- Fahrzeuge können von Spielern dort erworben werden; Unlock-Checks laufen serverseitig.

### Lieferaufträge

- Der Tab „Aufträge“ (Sidebar im Bossmenü) zeigt alle offenen bzw. geplanten Lieferungen.
- Beim Start wird das konfigurierte Fahrzeug gespawnt, die Route gesetzt und die Itemliste anhand der Kapazität generiert.
- Abschlüsse, Abbrüche und Fehler liefern entsprechende Notifications.

## Datenmodell (Datenbank)

Folgende Tabellen werden von der Creator-Logik befüllt bzw. gelesen:

| Tabelle | Zweck |
| --- | --- |
| `ws_shops` | Stammdaten, Standort, Level, Besitzer, Creator-Metadaten |
| `ws_shop_inventory` | Shop-spezifisches Inventar (Items, Preise, Limits, Level) |
| `ws_shop_dropoffs` | Lieferpunkte (Koordinaten, Reihenfolge, Label) |
| `ws_shop_depots` | Depotpunkte / Fahrzeugabholung |
| `ws_shop_vehicle_spawns` | Spawnpunkte für Lieferfahrzeuge |
| `ws_shop_allowed_vehicles` | Fahrzeugpools inkl. Key; Detaildaten im Creator-Metadaten-JSON |
| `ws_shop_product_categories` | Zugeordnete Produktkategorien eines Shops |
| `ws_shop_routes` & `ws_shop_route_points` | Liefer-Routen und deren Zwischenpunkte |
| `ws_shop_deliveries` & `ws_shop_delivery_items` | Aktive sowie abgeschlossene Lieferaufträge |
| `ws_shop_employees` | Mitarbeiter-Verwaltung, Rollen, Status |
| `ws_shop_finance_log` | Finanzhistorie pro Shop |

Weitere Tabellen (z. B. Statistiken) können optional ergänzt werden, sind aber nicht Bestandteil des aktuellen Panels.

## Server-Komponenten

- **`server/main.lua`**
  - Berechtigungsprüfung (`WSShopConfig.AdminAccess`).
  - Admin-Speicherlogik (`AdminSaveShopInternal`) inkl. Validierungen für Blips, Fahrzeuge, Dropoffs etc.
  - Trigger für Notifications (`Utils.Notify`) und Broadcasts (`ws-shopsystem:client:shopUpdated`).
- **`server/cache.lua`**
  - Lädt nach jedem Admin-Save alle Shopdaten neu.
  - Bereitet die NUI-Payloads für Dashboard, Editor und Bossmenü auf.
- **`server/deliveries.lua`**
  - Erzeugt Lieferaufträge, Itemlisten, Spawnpunkte.
  - Prüft Level- und Fahrzeugvoraussetzungen.
- **`server/migrations.lua`**
  - Legt Tabellen/Spalten beim Resource-Start an, falls sie fehlen.

## Client-/UI-Komponenten

- **`html/app.js`**
  - Enthält State-Management (`state.admin`), Routing (Dashboard vs. Editor), Notifications und Render-Funktionen.
  - `normalizeVehicleDraftEntry` sorgt für Abwärtskompatibilität von Alt-Daten.
  - `renderNotifications` stellt UI-Hinweise mittig unten dar (Erfolg, Warnung, Fehler).
- **`html/style.css`**
  - Layout für Dashboard, Editor, rechte Sidebar, Formulare und Notification-Overlay.
- **`html/index.html`**
  - Markup für Dashboard-Kacheln, Editor, Sidebar-Navigation, Notification-Container.
- **`client/main.lua`**
  - Öffnet Admin-Panel (`openAdminOverview`) und leitet Notifications (`ws-shopsystem:client:nuiNotify`) an die NUI weiter.

## Validierung & Fehlermeldungen

- **Blip-Validierung**: Sprite 1–1000, Farbe 0–85, Skalierung 0.1–2.5, Label maximal 60 Zeichen. Ungültige Eingaben werden serverseitig abgewiesen und via Notification gemeldet.
- **Fahrzeuge**: Keys werden normalisiert, doppelte Einträge gefiltert, Werte wie Kapazität und Preis geclampet.
- **Punktlisten**: Dropoffs/Depots/Spawns/Routen akzeptieren nur numerische Koordinaten.
- **Speicherfehler**: Bei DB-Problemen oder fehlenden Berechtigungen bleibt der Draft erhalten und das UI weist darauf hin.

## Erweiterungsideen

- Kartenübersicht mit Live-GPS (Vector -> Map preview) im Dashboard.
- Historische Notifications (Persistenz in einer eigenen Tabelle).
- Erweiterte Statistik-Panels (Umsatz, Lieferzeit, Fahrzeugnutzung).
- Mehrsprachige UI (aktuell Deutsch/Englisch lokalisiert).

Dieses Dokument wird fortlaufend gepflegt, sobald weitere Features (z. B. Spielerprogression oder globale Einstellungen) umgesetzt werden.

