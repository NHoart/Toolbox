# Microsoft Store

Die Store-Fassung ist eine **zusätzliche** Installationsart. DMG, EXE und
winget bleiben unverändert; die Store-Version nutzt dieselbe Sync-Engine und
dieselben lokalen Daten.

## Einmalige Einrichtung

### 1. Entwicklerkonto und Name reservieren

1. Auf <https://storedeveloper.microsoft.com> ein **Individual-Konto**
   anlegen. Es ist kostenlos, verlangt aber eine Identitätsprüfung mit Ausweis
   und Selfie.
2. Der Store-Name ist reserviert: **Toolbox for Windows**. Kopiere im Partner
   Center unter **Package/Identity** die Werte für `identityName` und
   `publisher`. Die App selbst und die interne Bezeichnung bleiben „Toolbox“.
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
entsprechen. `displayName` muss **exakt** der reservierte Store-Name sein; er
erscheint im Startmenü und in der Paketbeschreibung. Das Paket wird später vom
Store neu signiert; ein eigenes Zertifikat ist nicht nötig.

### 3. AppX bauen

Der Workflow **Microsoft Store (AppX)** baut das Paket auf `windows-latest`.
Er läuft bei jedem Tag `v*` und manuell über **Actions → Microsoft Store
(AppX) → Run workflow**. Der Store-Build pinnt `toolsets.winCodeSign` auf
`1.1.0` (Windows Kits 10.0.26100.0); die alte `winCodeSign-2.6.0`-Toolchain
ist auf aktuellen Windows-Runnern für AppX nicht mehr zuverlässig. Der
Store-Build entfernt außerdem die GitHub-`publish`-Konfiguration aus dem
NSIS-Build; veröffentlicht wird ausschließlich über den Workflow. Bei einem
Fehler schreibt der Workflow die letzten Zeilen des Build-Logs in die
Job-Zusammenfassung.

- Vor dem Eintragen der echten Identität kann mit **Testbau mit
  Platzhalter-Identität** die Paketierung geprüft werden. Dieses Paket ist
  **nicht** im Store einreichbar.
- Der Lauf legt das Artefakt **Toolbox-appx** ab; du lädst es herunter. Darin
  liegt `Toolbox-<version>.appx`.
- Lokal prüfen: `cd windows && npm run dist:store -- --check`.
- Lokal bauen: `npm run dist:store` (benötigt Windows oder Parallels).

Der bestehende Workflow `windows-exe.yml` wird nicht verändert. Die Store-Fassung
wird **nicht** als GitHub-Release-Asset veröffentlicht.

### 4. Erste Einreichung im Partner Center

Die erste Submission lässt sich nicht per API anlegen und muss manuell
erfolgen:

1. Im Partner Center eine Submission für Toolbox öffnen.
2. Unter **Packages** die heruntergeladene `.appx` hochladen. Der Store prüft
   und signiert sie.
3. **Properties**: Kategorie **Produktivität**, Systemanforderung
   **Windows 10 (1809) oder neuer, 64 Bit**.
4. **Age rating**: keine jugendgefährdenden Inhalte (3+).
5. **Pricing**: kostenlos.
6. **Store listing**: Texte, Logo und Screenshots aus dem Abschnitt unten.
7. **Privacy policy**: <https://github.com/NHoart/Toolbox/blob/main/PRIVACY.md>
8. **Support**: <https://github.com/NHoart/Toolbox/issues>
9. Einreichen und die Zertifizierung abwarten.

Nach der Veröffentlichung die Store-URL
`https://apps.microsoft.com/detail/9P4FPTHZHVJD` als Repository-Variable
**`STORE_URL`** hinterlegen (Settings → Secrets and variables → Actions →
Variables). Die Release-Notes neuer Releases nehmen dann automatisch eine Store-Zeile in die
Installationstabelle auf. Für das bereits veröffentlichte 3.3.1 die Zeile einmal
manuell ergänzen. Ohne `STORE_URL` bleibt die Zeile leer.

### 5. Spätere Updates

1. `version` in `windows/package.json` erhöhen und einen Tag `v<version>`
   pushen.
2. Der Store-Workflow baut die neue `.appx`.
3. Die `.appx` im Partner Center als neue Submission hochladen.
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

## Listing-Texte

**App-Name:** `Toolbox for Windows`

**Kurzbeschreibung (max. 270 Zeichen):**

> Wassertracker, Zähler, Einheitenrechner und Alltagswerkzeuge – mit Abgleich
> im lokalen WLAN zwischen Windows, Mac und iPhone.

**Beschreibung:**

> Toolbox bündelt sechs Alltagswerkzeuge in einer App: Wassertracker mit
> Tagesziel und Verlauf, Zähler mit Auto-Zählung und gespeicherten Ständen,
> Einheitenrechner, Downloadzeit-Rechner, Stromverbrauchsrechner und mehr.
>
> Der Abgleich im lokalen WLAN verbindet Windows, Mac und iPhone direkt –
> ohne Konto, ohne Cloud und ohne Server. Alle Daten bleiben auf den Geräten.
>
> Die Windows-Fassung läuft unter Windows 10 (1809) oder neuer, 64 Bit.

**Kategorie:** Produktivität

**Logo:** `windows/store/StoreListingIcon.png` (300 × 300)

**Screenshots:** mindestens ein Bild, 1366 × 768 oder größer, maximal 10.
Die Startseite „Wassertracker“ und der Zähler eignen sich als Motive.

**Copyright:** © 2026 Noah Hartmann
