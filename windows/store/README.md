# Microsoft Store

Die Store-Fassung ist eine **zusätzliche** Installationsart. DMG, EXE und
winget bleiben unverändert; die Store-Version nutzt dieselbe Sync-Engine und
dieselben lokalen Daten.

## Einmalige Einrichtung

### 1. Entwicklerkonto und Name reservieren

1. Auf <https://storedeveloper.microsoft.com> ein **Individual-Konto**
   anlegen. Es ist kostenlos, verlangt aber eine Identitätsprüfung mit Ausweis
   und Selfie.
2. Im Partner Center unter **Apps and games → New product** den Produktnamen
   reservieren – für dieses Produkt ist **Toolbox for Windows** angelegt. Ist
   ein Name belegt, einen eindeutigen Namen wählen; der Anzeigename im Paket
   bleibt „Toolbox for Windows“.
3. Unter **Package/Identity** diese Werte kopieren:
   - `Package/Identity/Name` → `identityName`
   - `Package/Identity/Publisher` → `publisher`

### 2. Store-Identität eintragen

`windows/store/store.config.json` ist für dieses Produkt bereits ausgefüllt:

```json
{
  "identityName": "NHoartApps.ToolboxforWindows",
  "publisher": "CN=4C6F0CE5-5A19-4199-945D-0218158D3762",
  "publisherDisplayName": "NHoartApps",
  "applicationId": "Toolbox",
  "displayName": "Toolbox for Windows",
  "storeId": "9P4FPTHZHVJD"
}
```

`identityName` und `publisher` müssen **exakt** den Partner-Center-Werten
entsprechen. Das Paket wird später vom Store neu signiert; ein eigenes
Zertifikat ist nicht nötig.

Für dieses Produkt sind die Werte bereits eingetragen:

| Feld | Wert |
| --- | --- |
| `identityName` | `NHoartApps.ToolboxforWindows` |
| `publisher` | `CN=4C6F0CE5-5A19-4199-945D-0218158D3762` |
| `publisherDisplayName` | `NHoartApps` |
| `displayName` | `Toolbox for Windows` |
| Store-ID | `9P4FPTHZHVJD` |

### 3. AppX bauen

Der Workflow **Microsoft Store (AppX)** baut das Paket auf `windows-latest`.
Er läuft bei jedem Push eines Tags `v*` und manuell über **Actions → Microsoft
Store (AppX) → Run workflow**. Der Store-Build pinnt `toolsets.winCodeSign`
auf `1.1.0` (Windows Kits 10.0.26100.0); die alte
`winCodeSign-2.6.0`-Toolchain ist auf aktuellen Windows-Runnern für AppX nicht
mehr zuverlässig. Er entfernt außerdem die GitHub-`publish`-Konfiguration aus
dem NSIS-Build; veröffentlicht wird ausschließlich über den Workflow. Bei
einem Fehler schreibt der Workflow die letzten Zeilen des Build-Logs in die
Job-Zusammenfassung.

- Der Store-Build schreibt **immer** `de-DE`, `en-US`, `es-ES` und `fr-FR` in
  das AppX-Manifest. Die zentrale Liste steht in
  `windows/scripts/appx-languages.js`; `windows/package.json` und der Build
  müssen exakt diese vier Sprachen enthalten, sonst bricht der Build ab.
- Nach dem Build prüft `windows/scripts/verify-appx.ps1` das fertige Paket:
  Identität, Paketversion, `x64` und **exakt** die vier Sprachen. Bei einer
  Abweichung schlägt der Workflow fehl, bevor ein Artefakt hochgeladen wird.
- Der Lauf legt das Artefakt **Toolbox-appx** ab; darin liegen
  `Toolbox-<version>.appx` und `SHA256SUMS.txt`.
- Vor dem Eintragen der echten Identität kann mit **Testbau mit
  Platzhalter-Identität** die Paketierung geprüft werden. Dieses Paket ist
  **nicht** im Store einreichbar und heißt **Toolbox-appx-test**.
- Lokal prüfen: `cd windows && npm run dist:store -- --check` (zeigt auch die
  vier Sprachen).
- Lokal bauen: `npm run dist:store` (benötigt Windows oder Parallels); danach
  `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-appx.ps1`
  ausführen.

Der bestehende Workflow `windows-exe.yml` wird nicht verändert. Die Store-Fassung
wird **nicht** als GitHub-Release-Asset veröffentlicht.

### 4. AppX im Partner Center hochladen

1. **Workflow starten:** **Actions → Microsoft Store (AppX) → Run workflow**.
   Bei einem Release reicht auch ein Tag `v<version>`; der Workflow läuft dann
   automatisch. Warte, bis der Lauf grün ist und der Schritt
   **AppX-Manifest prüfen** die vier Sprachen bestätigt hat.
2. **Artefakt herunterladen:** Öffne den Lauf und lade unter **Artifacts** die
   Datei **Toolbox-appx** herunter. Entpacke sie. Verwende **nicht** das
   Artefakt `Toolbox-appx-test` aus einem Testbau.
3. **Datei prüfen:** Auf Windows die Prüfsumme vergleichen:

   ```powershell
   Get-FileHash .\Toolbox-3.3.1.appx -Algorithm SHA256
   Get-Content .\SHA256SUMS.txt
   ```

   Beide SHA256-Werte müssen übereinstimmen. Optional das Manifest erneut
   prüfen (im Repository unter `windows`):

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-appx.ps1 -Path .\Toolbox-3.3.1.appx
   ```

4. **Partner Center öffnen:** **Apps and games → Toolbox for Windows →
   Submission → Packages**.
5. **Altes Paket ersetzen:** Falls dort noch die alte
   `Toolbox-3.3.1.appx` ohne die vier Sprachen steht, entferne sie zuerst über
   die Paketaktionen. Warte, bis das Paket nicht mehr gelistet ist.
6. **Neues Paket hochladen:** **Upload package** wählen und die neue
   `.appx` auswählen. Lade **kein** Zertifikat hoch; der Store signiert das
   Paket beim Einreichen selbst. Warte, bis der Status **Validated** lautet.
7. **Sprachen kontrollieren:** Unter **In Paketen unterstützte Sprachen**
   müssen **Deutsch, Englisch, Spanisch und Französisch** stehen. Fehlt eine
   Sprache, nicht einreichen: Artefakt und Workflow-Log prüfen und den Build
   erneut starten.
8. **Submission speichern:** Die übrigen Angaben bleiben unverändert. Erst
   wenn das Paket validiert ist und die vier Sprachen angezeigt werden, mit
   Abschnitt 5 fortfahren.

### 5. Übrige Submission prüfen und einreichen

Die erste Submission lässt sich nicht per API anlegen und muss manuell
erfolgen:

1. **Properties**: Kategorie **Produktivität**, Systemanforderung
   **Windows 10 (1809) oder neuer, 64 Bit**.
2. **Age rating**: keine jugendgefährdenden Inhalte (3+).
3. **Pricing**: kostenlos.
4. **Store listing**: Werte aus [Einreichung: Texte und Angaben](#einreichung-texte-und-angaben).
5. **Privacy policy**: <https://github.com/NHoart/Toolbox/blob/main/PRIVACY.md>
6. **Support**: <https://github.com/NHoart/Toolbox/issues>
7. **Zur Zertifizierung übermitteln** und die Zertifizierung abwarten.

Nach der Veröffentlichung die Store-URL
`https://apps.microsoft.com/detail/<StoreId>` als Repository-Variable
**`STORE_URL`** hinterlegen (Settings → Secrets and variables → Actions →
Variables). Die Release-Notes neuer Releases nehmen dann automatisch eine Store-Zeile in die
Installationstabelle auf. Für das bereits veröffentlichte 3.3.1 die Zeile einmal
manuell ergänzen. Ohne `STORE_URL` bleibt die Zeile leer.

### 6. Spätere Updates

1. `version` in `windows/package.json` erhöhen und einen Tag `v<version>`
   pushen.
2. Der Store-Workflow baut die neue `.appx` und prüft die vier Sprachen.
3. Artefakt herunterladen, Prüfsumme vergleichen und die `.appx` im Partner
   Center als neue Submission hochladen (Schritte aus Abschnitt 4).
4. Der Store aktualisiert installierte Apps; `electron-updater` ist in der
   Store-Fassung deaktiviert.

Eine spätere Automatisierung kann die Microsoft Store Developer CLI mit einer
Entra-ID-App verwenden. Dafür werden Seller-ID, Tenant-ID, Client-ID und
Client-Secret benötigt; diese Zugangsdaten gehören nicht ins Repository.

## Sync und Daten

- Das Paket deklariert `runFullTrust` und `privateNetworkClientServer`.
  Bonjour/mDNS und TCP funktionieren wie in der EXE-Fassung.
- Beim ersten Start der Store-Fassung wird eine vorhandene
  `%APPDATA%\Toolbox\data.json` in den paketierten AppData-Bereich kopiert,
  sofern dort noch keine Datei liegt. Die EXE-Installation bleibt unberührt.
  Die EXE vorher schließen, damit der aktuellste Stand übernommen wird.
- Auf einem echten Windows-PC testen: Store-App starten, die Freigabe für
  **Private Netzwerke** erlauben, denselben Sync-Namen wie auf Mac/iPhone
  eintragen und mit allen drei Varianten abgleichen.
- Die Store-Fassung braucht keine Internetverbindung für den Sync. Das
  Windows-Netzwerkprofil muss „Privat“ sein.

## Einreichung: Texte und Angaben

Alle Werte für die erste Submission, in der Reihenfolge des Partner Centers.
Das AppX deklariert `de-DE`, `en-US`, `es-ES` und `fr-FR`; die App-Oberfläche
richtet sich nach der Windows-Sprache und fällt bei anderen Sprachen auf
Deutsch zurück. Die Store-Einträge gibt es zusätzlich auf Englisch (USA),
Spanisch (Spanien) und Französisch (Frankreich). Produkt-ID: `9P4FPTHZHVJD`.

> **Wichtig:** Das derzeit im Partner Center validierte Paket
> `Toolbox-3.3.1.appx` wurde vor der Lokalisierung gebaut. Für die
> ausgelieferte Store-App müssen ein neues AppX mit den vier Sprachen gebaut
> und die Submission aktualisiert werden. Der Build läuft auf Windows oder
> über den Workflow **Microsoft Store (AppX)**; auf macOS ist er nicht möglich.

### Store-Eintrag (de-DE)

**Produktname:** `Toolbox for Windows` (reserviert) · **Anzeigename im Paket:**
`Toolbox for Windows`. Listing- und Paketname sind damit identisch.

**Kurzbeschreibung (unter 270 Zeichen):**

> Wassertracker, Zähler, Einheitenrechner und Alltagswerkzeuge – mit Abgleich
> im lokalen WLAN zwischen Windows, Mac und iPhone.

**Beschreibung:**

> Toolbox bündelt sechs Alltagswerkzeuge in einer App – ohne Konto, ohne Cloud
> und ohne Server.
>
> • Wassertracker: Tagesziel, Fortschrittsring, Schnellwahl für Glas und
> Flasche sowie Verlauf der letzten 30 Tage
> • Zähler: Plus/Minus, Undo, Reset, Auto-Zählmodus und benannte, gespeicherte
> Zählerstände
> • Einheiten: Umrechnung zwischen MB/GB und Mbit/MB
> • Downloadzeit: geschätzte Dauer aus Dateigröße und Geschwindigkeit
> • Stromverbrauch: Energie aus Leistung und Nutzungsdauer, optional mit
> Kosten zum eigenen kWh-Preis
> • Lokaler Abgleich: Windows, Mac und iPhone tauschen Wasser- und
> Zählerstände direkt im WLAN aus
>
> Alle Daten bleiben auf den Geräten. Es gibt kein Benutzerkonto, keine
> Anmeldung, keine Telemetrie und keine Werbung. Der Abgleich läuft nur im
> lokalen Netzwerk und ist nicht zusätzlich verschlüsselt; dafür auf allen
> Geräten denselben Sync-Namen eintragen.
>
> Die Windows-Fassung läuft unter Windows 10 (Version 1809) oder neuer, 64 Bit.
> Updates kommen über den Microsoft Store.

**Produktfeatures (max. 20, je 200 Zeichen):**

1. Wassertracker mit Tagesziel, Fortschrittsring und Verlauf der letzten 30 Tage
2. Schnellwahl für Glas und Flasche sowie frei wählbare Menge von 1 bis 10.000 ml
3. Zähler mit Plus/Minus, Undo, Reset, Auto-Zählmodus und gespeicherten Zählerständen
4. Einheitenrechner für MB/GB und Mbit/MB
5. Downloadzeit-Rechner aus Dateigröße und Geschwindigkeit
6. Stromverbrauchsrechner mit optionaler Kostenberechnung zum eigenen kWh-Preis
7. Abgleich im lokalen WLAN zwischen Windows, Mac und iPhone – ohne Konto und ohne Cloud
8. Alle Daten bleiben lokal: keine Telemetrie, keine Werbung

**Keywords (max. 7, je 40 Zeichen, zusammen max. 21 Wörter):**

`Wassertracker` · `Wasser trinken` · `Zähler` · `Einheitenrechner` ·
`Downloadzeit berechnen` · `Stromverbrauch berechnen` · `WLAN Sync`

**Copyright:** © 2026 Noah Hartmann  
**Entwickelt von:** Noah Hartmann  
**Support:** <https://github.com/NHoart/Toolbox/issues>  
**Website:** <https://github.com/NHoart/Toolbox>  
**Datenschutzerklärung:** <https://github.com/NHoart/Toolbox/blob/main/PRIVACY.md>  
**Zusätzliche Lizenzbedingungen:** Proprietär – alle Rechte vorbehalten. Der
Quellcode ist öffentlich einsehbar; Nutzung und Weitergabe richten sich nach
der LICENSE im Repository: <https://github.com/NHoart/Toolbox/blob/main/LICENSE>  
**Store-Logo:** `windows/store/StoreListingIcon.png` (300 × 300, 1:1)  
**Screenshots:** fünf PNGs (2464 × 1648) im Store-Eintrag hochgeladen; die
Dateien liegen unter `windows/store/screenshots/`. Ein sechstes Motiv aus dem
Chat war nicht als Datei vorhanden, ist aber nicht erforderlich.  
**Was ist neu in dieser Version:** bei der ersten Einreichung leer lassen.

### Zusätzliche Store-Einträge (en-US, es-ES, fr-FR)

Die Store-Einträge **Englisch (Vereinigte Staaten)**, **Spanisch (Spanien)**
und **Französisch (Frankreich)** sind vollständig angelegt und mit denselben
fünf Screenshots versehen. Beschreibungen, Kurzbeschreibungen, je acht
Features, je sieben Keywords sowie Copyright-, Lizenz- und Entwicklerangaben
sind übersetzt. Die früheren Hinweise auf eine rein deutsche Oberfläche wurden
entfernt, nachdem die App de/en/es/fr lokalisiert wurde.

Die fünf Screenshots zeigen weiterhin die deutsche Oberfläche. Die App ist
inzwischen lokalisiert; für eine optimale Darstellung sollten die Aufnahmen je
Store-Sprache durch Bilder der jeweiligen UI ersetzt werden. Das ist kein
Pflichtfeld und blockiert die Einreichung nicht.

Die **Paketsprachen** sind in `windows/package.json` auf `de-DE`, `en-US`,
`es-ES` und `fr-FR` erweitert. Das bereits hochgeladene AppX enthält diese
Erweiterung noch nicht; nach einem Neubau auf Windows muss es im Partner Center
erneut hochgeladen und die Submission aktualisiert werden.

### Preise und Verfügbarkeit

| Feld | Wert |
| --- | --- |
| Preis | Kostenlos |
| Kostenlose Testversion | Nein |
| In-App-Käufe | Nein |
| Märkte | Alle Märkte, in denen der Microsoft Store verfügbar ist |
| Gerätefamilie | Windows 10/11 (Desktop), x64 |
| Veröffentlichung | Sobald die Zertifizierung abgeschlossen ist |
| Verkaufspreise/Angebote | Keine |

### Eigenschaften

**Kategorie:** Produktivität (keine Unterkategorie)

**Systemanforderungen:**

| Feld | Wert |
| --- | --- |
| Betriebssystem | Windows 10, Version 1809 (Build 17763) oder neuer |
| Architektur | x64 |
| Arbeitsspeicher | 4 GB (empfohlen) |
| DirectX | Nicht erforderlich |
| Grafik | Nicht erforderlich |
| Freier Speicherplatz | rund 400 MB (empfohlen) |

**Zusätzliche Systemanforderungen (max. 11, je 200 Zeichen):**

- Für den Abgleich im lokalen WLAN: gleiches Netzwerk mit dem Profil „Privat“,
  Freigabe für private Netzwerke in der Windows-Firewall und identischer
  Sync-Name auf allen Geräten.
- Eine Internetverbindung ist nur für Updates aus dem Microsoft Store nötig;
  alle Werkzeuge und der Abgleich funktionieren offline.

**Capability-Begründungen (falls im Partner Center abgefragt):**

- `runFullTrust`: Toolbox ist eine Electron-Desktop-App, die als voll
  vertrauenswürdige Win32-Anwendung außerhalb der UWP-Sandbox läuft. Die
  Capability ist nötig, um die Oberfläche, den lokalen Speicher unter
  `%APPDATA%\Toolbox` und den Geräteabgleich auszuführen.
- `privateNetworkClientServer`: Der optionale Abgleich nutzt Bonjour/mDNS und
  TCP im lokalen Netzwerk, um Wasser- und Zählerstände zwischen Windows, Mac
  und iPhone auszutauschen. Es werden keine Daten ins Internet übertragen;
  ohne Sync-Namen ist der Abgleich inaktiv.

**Altersfreigabe (IARC):** Fragebogen vollständig mit „Nein“ beantwortet und
gespeichert. Ergebnis: USK 0 („Freigegeben ohne Altersbeschränkung“), PEGI 3,
ESRB Everyone, IARC 3+, Microsoft Store 3+. Die IARC-Nutzungsbedingungen
wurden dabei akzeptiert.

### Übermittlungsoptionen

- **Gerätefamilie:** Windows 10/11, x64 (keine Xbox-Fassung)
- **Auffindbarkeit:** in Suchergebnissen und beim Durchsuchen des Stores
  anzeigen, nicht nur per Direktlink
- **Veröffentlichung:** sofort nach erfolgreicher Zertifizierung
- **Begründung für `runFullTrust` (max. 500 Zeichen):**

> Toolbox is an Electron-based MSIX desktop app. runFullTrust is required to
> launch the packaged desktop executable and its bundled Chromium/Node.js
> runtime; without it the app cannot start. The app stores data locally and
> uses privateNetworkClientServer only for optional LAN sync between the
> user's own devices. It installs no services, drivers, or background
> components, requires no admin rights, and does not bypass Store policies.

- **Hinweise für die Zertifizierung:**

> Toolbox ist eine Electron-Desktop-App (Win32, x64) ohne Anmeldung und ohne
> Cloud. Die Store-Fassung prüft keine GitHub-Updates; Updates kommen
> ausschließlich über den Microsoft Store. Beim ersten Start kann Windows die
> Firewall-Freigabe für private Netzwerke abfragen; sie ist nur für den
> optionalen Geräteabgleich per Bonjour/mDNS und TCP nötig und kann abgelehnt
> werden, ohne die übrigen Funktionen einzuschränken. Der Abgleich ist ohne
> Sync-Namen inaktiv. Zum Prüfen genügt ein Gerät; für den Abgleich werden zwei
> Geräte im selben WLAN mit identischem Sync-Namen benötigt. Es werden keine
> Daten an Dritte gesendet und keine Telemetrie erhoben.

### Vor dem Einreichen

- [x] Screenshots hochladen (fünf unter `windows/store/screenshots/`)
- [x] IARC-Fragebogen vollständig beantworten und Altersfreigaben speichern
- [x] Preise und Verfügbarkeit, Eigenschaften, Store-Eintrag und Übermittlungsoptionen ausfüllen
- [x] AppX hochgeladen und validiert (`Toolbox-3.3.1.appx`)
- [x] Zusätzliche Store-Einträge en-US und es-ES vollständig ausgefüllt
- [x] App-Lokalisierung de/en/es/fr im Renderer eingebaut
- [x] Zusätzlicher Store-Eintrag fr-FR vollständig ausgefüllt
- [x] Store-Build deklariert und prüft `de-DE`, `en-US`, `es-ES`, `fr-FR`
- [ ] Screenshots je Sprache durch Aufnahmen der lokalisierten UI ersetzen
      (aktuell dieselben fünf deutschen Aufnahmen; nicht pflichtig)
- [ ] Neues AppX mit de/en/es/fr bauen und im Partner Center hochladen
      (Windows oder GitHub-Actions-Workflow erforderlich)
- [ ] Einreichung „Zur Zertifizierung übermitteln“ absenden (noch nicht abgesendet)
- [ ] Nach der Veröffentlichung `STORE_URL` als Repository-Variable setzen
      (`https://apps.microsoft.com/detail/9P4FPTHZHVJD`)
