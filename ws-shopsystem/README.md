# WS Shop System

Ein umfangreiches Shop-, Wirtschafts- und Liefer-System für QBCore-Server. Spieler können Shops kaufen, verwalten, Mitarbeiter einstellen, Liefermissionen fahren, Preise anpassen und Finanzen im Blick behalten – alles mit einer modernen NUI im roten Wolfstudio-Stil.

---

## Voraussetzungen

| Resource          | Hinweis                                                                 |
|-------------------|-------------------------------------------------------------------------|
| `qb-core`         | Framework                                                               |
| `oxmysql`         | Datenbank-Verbindung (mit `@oxmysql/lib/MySQL.lua` geladen)             |
| `qb-target`       | Für die Interaktionen an Shops                                          |
| `qb-menu`         | Für Menü-Interactions innerhalb des Systems                             |
| `qb-phone`        | Für Benachrichtigungen und Mails                                        |
| `qb-management`   | Optional, falls Gesellschaftskonten genutzt werden sollen               |

Stelle sicher, dass alle Ressourcen aktuell sind und **vor** `ws-shopsystem` in der `server.cfg` gestartet werden.

---

## Installation

1. **Resource kopieren**  
   Lege den Ordner `ws-shopsystem` unter `resources/[pro]/` (oder deinen bevorzugten Ressourcen-Ordner).

2. **SQL importieren**  
   Führe die Datei `sql/ws_shopsystem.sql` in deiner Datenbank aus (z. B. über phpMyAdmin oder `mysql` CLI).

3. **Resource starten**  
   Ergänze deine `server.cfg` um:  
   ```
   ensure ws-shopsystem
   ```

4. **Server neu starten**
   Nach dem Neustart seedet das Script automatisch alle Shops aus der `config.lua` in die Datenbank.

---

## Admin-Creator & Shopverwaltung

- Öffne das Creator-Panel mit `/shopadmin` (oder der in `config.lua` definierten Taste). Du landest zunächst auf einem Dashboard,
  das alle Shops inklusive Level, Kontostand, Typ und Koordinaten anzeigt. Von dort oder über die Shop-Liste links gelangst du in den Editor.
- Im Editor findest du rechts eine Abschnitts-Navigation. Damit springst du ohne Scrollen zu Allgemein, Standort, NPC, Blip, Lieferpunkten,
  Depots, Fahrzeug-Spawns, Fahrzeugverwaltung, Produktkategorien und Routen.
- Ped, Zone, Liefer- und Depotpunkte sowie Fahrzeug-Spawns lassen sich direkt erfassen – Koordinaten werden auf Wunsch per
  „Position“-Button vom eigenen Charakter übernommen. Der integrierte Blip-Creator unterstützt Sprite, Farbe, Skalierung, Label und
  Short-Range-Einstellung pro Shop.
- Jeder Shop besitzt eine eigene Fahrzeugverwaltung. Modelle, Labels, Preise, Mindestlevel, Kapazitäten, Kofferraumgrößen und
  Spritfaktoren werden vollständig über das UI gepflegt und landen nach dem Speichern automatisch in `ws_shop_allowed_vehicles`.
  Die alte Tabelle `WSShopConfig.DeliveryVehicles` entfällt damit komplett.
- Dropoffs, Depots, Spawnpunkte, Liefer-Routen und Produktkategorien werden beim Speichern ebenfalls in die Datenbank geschrieben
  und stehen nach einem Reload sofort im Creator sowie in der Welt bereit.
- Scheitert das Speichern (z. B. wegen fehlender Berechtigungen oder Datenbankproblemen), informiert das UI und es bleiben keine
  halbfertigen Einträge zurück.

Im Bossmenü der Spieler existiert zusätzlich der Tab „Aufträge“ (Sidebar-Button), in dem alle offenen Liefermissionen des Shops
auflisten, neue Aufträge geplant und mit einem Klick gestartet werden können. Beim Start spawnt das konfigurierte Fahrzeug am
zugewiesenen Depot und die zuvor definierten Routenpunkte werden genutzt.

---

## Erstkonfiguration

Alle Einstellungen findest du in `config.lua`. Wichtige Bereiche:

- **Allgemein (`WSShopConfig`)**: Sprache, Ziel-Modus (`UseTarget`), Low-Stock-Schwellen, Benachrichtigungen, Befehle. `InteractionKey` und `ManagementKey` dienen als Fallback-Steuerung, falls `qb-target` nicht genutzt wird.
- **Admin-Zugriff (`WSShopConfig.AdminAccess`)**: Definiere, welche QB-Core Berechtigungen, Ace-Gruppen, Identifiers oder CitizenIDs den Shop-Creator öffnen dürfen.
- **XP / Level (`WSShopConfig.XP`, `WSShopConfig.Levels`)**: Erfahrung pro Aktion, freischaltbare Features, Fahrzeuge, Rabatte.
- **Rollen (`WSShopConfig.Roles`)**: Berechtigungen, Standardlöhne, Zugriff auf Menüpunkte.
- **Shoptypen (`WSShopConfig.ShopTypes`)**: Artikel, Preise, Icons, Kauf-/Verkaufspreise.
- **Shop-Liste (`WSShopConfig.Shops`)**: Wird bewusst leer gelassen. Neue Shops werden vollständig über das Admin-Panel erstellt und landen direkt in der Datenbank.
- **Depots (`WSShopConfig.Depots`)**: Optionale globale Vorschläge für Depots, falls der Creator keine individuellen Punkte setzt. Fahrzeuge werden ausschließlich im Admin-Panel gepflegt und landen mitsamt Preis-, Level- und Kapazitätsangaben direkt in der Datenbank.
- **Benachrichtigungen (`WSShopConfig.Notifications`)**: Mail-Texte, Webhook-Einstellungen.
- **UI-Notifications**: Das Panel blendet wichtige Ereignisse unten mittig ein (Erfolg, Fehler, Warnungen). Diese Hinweise erscheinen zusätzlich zu den klassischen QB-Notifications.

> **Hinweis:** Alle Umlaute wurden als ASCII (z. B. `ae`, `oe`) hinterlegt, damit selbst bei ANSI-Encoding keine Probleme auftreten. Passe Texte nach Bedarf an.

---

## Ingame-Ablauf

### Shop kaufen
1. Gehe zu einem Shop (via Blip oder Target).  
2. Nutze den Target-Kreis (`Shop oeffnen`). Wenn `qb-target` nicht aktiv ist, kannst du den Shop jederzeit mit `InteractionKey` (Standard `E`) öffnen und mit `ManagementKey` (Standard `G`) die Verwaltung aufrufen.  
3. Wenn kein Besitzer eingetragen ist, kannst du den Shop kaufen (Preis aus `config.lua`).  
4. Nach dem Kauf stehen alle Verwaltungsfunktionen zur Verfügung.

### Verwaltung (Bossmenü)
- Öffne den Shop → klicke auf „Verwaltung“ (Owner/Manager-Rolle benötigt).  
- Tabs: `Dashboard`, `Lager`, `Mitarbeiter`, `Aufträge`, `Finanzen`, `Fahrzeuge`.
- Preise anpassen, Mitarbeiter einstellen/entlassen, Lieferungen beauftragen, Ein-/Auszahlungen.
- Im Tab `Fahrzeuge` können Shopbesitzer die freigeschalteten Lieferfahrzeuge sehen und kaufen. Welche Modelle zur Auswahl stehen,
  definiert der Admin im Creator. Dort lassen sich Modellname (Spawncode), Preis, Mindestlevel, Kapazität, Kofferraum und
  Spritfaktor pro Shop speichern – komplett ohne Einträge in der `config.lua`.
- Der Tab `Finanzen` zeigt jetzt Kontostand, Kreditrahmen, offene Beträge und verfügbare Mittel in einer Bank-ähnlichen Übersicht.
  Einzahlungen, Auszahlungen, Kreditaufnahme und Tilgung werden direkt im Panel ausgelöst und sofort in der Datenbank verbucht.
- `Aufträge` ist in eine Auftragsliste und ein Planungsfenster aufgeteilt. Start-Buttons stehen direkt bei jedem Auftrag bereit,
  während die Erstellung unten rechts läuft – inklusive Kapazitätsanzeige und Fahrzeug-Checks.

### Liefermissionen
1. Erstelle im Tab „Lieferungen“ eine manuelle Bestellung oder warte auf eine automatische, wenn Lagerbestand fällt.  
2. Fahrer (mit Rolle `driver` oder höher) starten die Mission über das Menü.  
3. Pickup am Depot → Marker `E` → Ware laden (Blip wird gesetzt).  
4. Zum Shop fahren → Marker `E` → abladen.  
5. Lagerbestand erhöht sich, Finanzen/XP werden verbucht.  
6. Abbruch oder Scheitern löst Strafen aus (`DeliveryFailurePenalty`).  

### Benachrichtigungen
- E-Mails über `qb-phone` bei Low-Stock, automatischen Bestellungen oder Gehaltszahlungen.  
- Optional: Discord-Webhooks über `WSShopConfig.Notifications.webhook` aktivieren.

---

## Befehle & Rechte

| Befehl           | Beschreibung                          | Berechtigung (QBCore ACL) |
|------------------|---------------------------------------|---------------------------|
| `/shopadmin`     | Admin-Übersicht aller Shops öffnen    | Laut `WSShopConfig.AdminAccess` |

- Der Chat-Befehl ruft intern den Callback `ws-shopsystem:server:adminOpen` auf. Eigene Ressourcen können denselben Callback nutzen, um die aktuelle Creator-Payload inkl. Fehlermeldung bei fehlenden Rechten zu erhalten.

Weitere Aktionen laufen über den NUI-Workflow oder `qb-target` (Interaktionen am Shop).

---

## Datenbank-Tabellen

- `ws_shops` – Stammdaten (Besitzer, Level, Kontostand, Metadaten)  
- `ws_shop_inventory` – Lagerbestand, Preise, Levelanforderungen  
- `ws_shop_employees` – Mitarbeiterliste inkl. Rollen & Status  
- `ws_shop_finance_log` – Finanztransaktionen (Ein-/Auszahlungen, Verkäufe, Strafen)  
- `ws_shop_deliveries` / `ws_shop_delivery_items` – Lieferaufträge und Fracht
- `ws_shop_allowed_vehicles` – Fahrzeugpools pro Shop (Key, Modell, Preis, Level, Kapazität, Verbrauch)
- `ws_shop_vehicles` – Persistente Lieferfahrzeuge (Placeholder für spätere Erweiterungen)
- `ws_shop_statistics_daily` – Tagesstatistiken (Umsatz, Lieferungen, XP)  

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| SQL-Fehler beim Start | `sql/ws_shopsystem.sql` importiert? Tabelle vorhanden? |
| Keine Target-Interaktion | `qb-target` aktiv? `UseTarget` in `config.lua` auf `true`? |
| Mail kommt nicht an | Prüfe `qb-phone` API (`:server:sendNewMail`) und `PhoneResource` in der Config |
| Keine Icons | Stelle sicher, dass alle `.svg` Dateien in `html/icons/` vorhanden sind |
| Shops ohne Items | Nach Config-Änderungen Server neu starten, Inventar wird automatisch gesynct |
| Lieferungen starten nicht | Rolle (`driver`/`manager`/`owner`) zuweisen, Fahrzeugmodell/Plate prüfen |

---

## Empfohlene Erweiterungen

- Fahrzeuge persistent kaufen/lagern (`ws_shop_vehicles` nutzen)  
- Statistik-Tab in der Verwaltung mit Graphen (nutzt `ws_shop_statistics_daily`)  
- Weitere Shoptypen und Artikel hinzufügen  
- Webhook-Integration für High-Level-Shops aktivieren  

---

Viel Erfolg beim Betreiben eures Wirtschaftssystems! Bei Fragen oder Erweiterungswünschen einfach melden. 💼🚚🛒
