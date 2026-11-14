# winget-Paket

Zusätzlicher Installationsweg für die Windows-App. Das GitHub-Release bleibt
der primäre Download; die Release-Notes nennen oben in der Download-Tabelle
zusätzlich `winget install --id NHoart.Toolbox -e`.

## Was hier liegt

`manifests/` enthält den vorbereiteten Stand für 3.2.0 in genau der Struktur,
die das Community-Repository erwartet
(`manifests/<Anfangsbuchstabe>/<Publisher>/<Paket>/<Version>/`).

Die SHA256 im Installer-Manifest stammt aus dem veröffentlichten Release-Asset.
Ein lokaler `npm run dist`-Build kann minimal abweichen und darf dafür nicht
verwendet werden.

## Erzeugung im Release-Workflow

Nach dem Installer-Build führt `.github/workflows/windows-exe.yml`
`npm run winget:manifest` aus. Das Skript liest die Version aus
`windows/package.json`, berechnet die SHA256 des gebauten
`dist/Toolbox-Setup.exe` und schreibt die drei Manifeste nach
`windows/dist/winget/manifests/n/NHoart/Toolbox/<Version>/`. Anschließend prüft
der Job das Set mit `winget validate`; schlägt die Prüfung fehl, bricht der Lauf
vor dem Release ab. Danach hängt er den Ordner als Artefakt **Toolbox-winget**
an.

Lokal derselbe Ablauf:

```bash
cd windows
npm run dist
npm run winget:manifest
```

## Einmalig veröffentlichen

1. `microsoft/winget-pkgs` forken.
2. Den Ordner `manifests/n/NHoart/Toolbox/3.2.0` unverändert in den Fork
   übernehmen.
3. Auf Windows mit `winget validate --manifest <Pfad>` prüfen.
4. Pull Request gegen `microsoft/winget-pkgs` stellen. Beim ersten Beitrag wird
   die Microsoft-CLA einmalig bestätigt.
5. Erst nach dem Merge findet `winget install --id NHoart.Toolbox -e` das Paket.
   Vorher schlägt der Befehl mit „No package found“ fehl.

## Neue Version

Für jede Version das Artefakt **Toolbox-winget** aus dem Workflow-Lauf laden,
den enthaltenen Versionsordner unter
`manifests/n/NHoart/Toolbox/<Version>/` in den Fork legen und als PR
einreichen. Version, URL und SHA256 kommen aus dem Build und müssen nicht von
Hand gepflegt werden.

Die Paket-ID `NHoart.Toolbox` bleibt unverändert, sonst funktioniert
`winget upgrade` nicht.

Der PR bleibt manuell: Er braucht einen Fork unter dem eigenen GitHub-Konto und
die einmalige CLA-Bestätigung.
