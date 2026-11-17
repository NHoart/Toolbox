(function (root, factory) {
  const api = factory()
  if (typeof module === 'object' && module.exports) module.exports = api
  root.ToolboxI18n = api
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  const dictionaries = {
    de: {},
    en: {
      'WERKZEUGE': 'TOOLS',
      'Heute': 'Today',
      'Verlauf': 'History',
      'Einheiten': 'Units',
      'Zähler': 'Counter',
      'Downloadzeit': 'Download time',
      'Stromverbrauch': 'Power usage',
      'Sync im WLAN': 'Wi-Fi sync',
      'Suche im WLAN…': 'Searching Wi-Fi…',
      'Wassertracker': 'Water tracker',
      'Dein Fortschritt für heute': 'Your progress for today',
      'HEUTE': 'TODAY',
      'von 2000 ml Ziel · noch 2000 ml offen': 'of 2000 ml goal · 2000 ml to go',
      'Glas': 'Glass',
      'Flasche': 'Bottle',
      'Eigene Menge': 'Custom amount',
      'Rückgängig': 'Undo',
      'Schnellwahl': 'Quick add',
      'Tagesziel': 'Daily goal',
      'Ziel für heute': 'Goal for today',
      'Durchschnitt': 'Average',
      'pro Tag': 'per day',
      'Ziel erreicht': 'Goal reached',
      'Tagen': 'days',
      'Bester Tag': 'Best day',
      'Höchstwert': 'Highest',
      'LETZTE 30 TAGE': 'LAST 30 DAYS',
      'Unter Ziel': 'Below goal',
      'TAGE': 'DAYS',
      'UMRECHNUNG': 'CONVERSION',
      'Wert in MB': 'Value in MB',
      'Reset': 'Reset',
      'ERGEBNIS': 'RESULT',
      'Wert eingeben': 'Enter a value',
      'ZÄHLERSTAND': 'COUNT',
      'Läuft': 'Running',
      'Zurücksetzen': 'Reset',
      'Automatisch': 'Automatic',
      '5× pro Sekunde': '5× per second',
      'Start': 'Start',
      'GESPEICHERT': 'SAVED',
      'DATEI UND VERBINDUNG': 'FILE AND CONNECTION',
      'Dateigröße': 'File size',
      'Einheit': 'Unit',
      'Downloadgeschwindigkeit': 'Download speed',
      'DOWNLOADZEIT': 'DOWNLOAD TIME',
      'Dateigröße und Geschwindigkeit eingeben': 'Enter file size and speed',
      'VERBRAUCH EINGEBEN': 'ENTER USAGE',
      'Leistung': 'Power',
      'Watt': 'Watts',
      'Nutzungsdauer': 'Duration',
      'Stunden': 'Hours',
      'Strompreis pro kWh (optional)': 'Electricity price per kWh (optional)',
      'Kosten: Kein Strompreis angegeben': 'Cost: No electricity price entered',
      'Menge eintragen': 'Enter amount',
      'Zahl eintippen oder eine Schnellauswahl verwenden.': 'Type a number or use a quick pick.',
      'Bitte eine Zahl zwischen 1 und 10000 eingeben.': 'Please enter a number between 1 and 10000.',
      'Abbrechen': 'Cancel',
      'Hinzufügen': 'Add',
      'Stand speichern': 'Save count',
      'Aktueller Stand: 0': 'Current count: 0',
      'Aktueller Stand: {count}': 'Current count: {count}',
      'Name': 'Name',
      'Speichern': 'Save',
      'Einstellungen': 'Settings',
      'Wasser, Netzwerk, Updates und Anzeige': 'Water, network, updates, and display',
      'SPRACHE': 'LANGUAGE',
      'Sprache': 'Language',
      'Systemsprache': 'System language',
      'Die App startet nach dem Wechsel neu.': 'The app will restart after switching.',
      'Sprache konnte nicht gespeichert werden.': 'The language could not be saved.',
      'MENGEN': 'AMOUNTS',
      'LOKALES NETZWERK': 'LOCAL NETWORK',
      'Status': 'Status',
      'Dieser PC': 'This PC',
      'Jetzt suchen': 'Search now',
      'Gleicht Wassertracker und Zähler direkt mit deinen Geräten im selben WLAN ab – ohne Server und ohne Konto. Trage auf allen Geräten denselben Namen ein; nur Geräte mit diesem Namen gleichen sich ab. Ohne Namen ist der Abgleich aus. Mac, iPhone und dieser PC können gleichzeitig verbunden sein; ein Gerät gibt übernommene Änderungen automatisch an die anderen weiter.': 'Sync the water tracker and counter directly with your devices on the same Wi-Fi – no server and no account. Use the same name on every device; only devices with that name sync. Without a name, sync is off. Mac, iPhone, and this PC can be connected at the same time; a device automatically passes received changes on to the others.',
      'UPDATES': 'UPDATES',
      'Automatisch prüfen': 'Check automatically',
      'Version wird geladen…': 'Loading version…',
      'Jetzt nach Updates suchen': 'Check for updates now',
      'Prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht. Ein Update ersetzt die installierte App und startet sie neu.': 'Checks at most once a day on startup whether a newer version is available on GitHub. An update replaces the installed app and restarts it.',
      'Updates werden über den Microsoft Store verwaltet. Der Store hält Toolbox automatisch aktuell; die GitHub-Update-Prüfung ist in dieser Fassung aus.': 'Updates are managed through the Microsoft Store. The Store keeps Toolbox up to date automatically; the GitHub update check is disabled in this version.',
      'Heute zurücksetzen': 'Reset today',
      'Setzt die heutige Trinkmenge auf 0 ml.': "Sets today's water intake to 0 ml.",
      'Fertig': 'Done',
      'Update verfügbar': 'Update available',
      'Eine neue Version steht bereit.': 'A new version is ready.',
      'Wird geladen …': 'Loading …',
      'Später': 'Later',
      'Installieren und neu starten': 'Install and restart',
      'Sync-Einstellungen öffnen': 'Open sync settings',
      'Umrechnung': 'Conversion',
      'Verringern': 'Decrease',
      'Erhöhen': 'Increase',
      'Langsamer': 'Slower',
      'Schneller': 'Faster',
      'Aktuellen Stand speichern': 'Save current count',
      'Geschwindigkeitseinheit': 'Speed unit',
      'Schließen': 'Close',
      'z. B. Runde 1': 'e.g. Round 1',
      'Glas verkleinern': 'Decrease glass size',
      'Glas vergrößern': 'Increase glass size',
      'Flasche verkleinern': 'Decrease bottle size',
      'Flasche vergrößern': 'Increase bottle size',
      'Tagesziel verkleinern': 'Decrease daily goal',
      'Tagesziel vergrößern': 'Increase daily goal',
      'z. B. Familie': 'e.g. Family',
      'Die letzten 30 Tage im Überblick': 'The last 30 days at a glance',
      'MB/GB und Mbit/MB umrechnen': 'Convert MB/GB and Mbit/MB',
      'Manuell oder automatisch zählen': 'Count manually or automatically',
      'Dateigröße und Geschwindigkeit': 'File size and speed',
      'Leistung, Dauer und Kosten': 'Power, duration, and cost',
      'Wert in GB': 'Value in GB',
      'Wert in Mbit': 'Value in Mbit',
      'Tagesziel erreicht – {goal} ml geschafft.': 'Daily goal reached – {goal} ml completed.',
      'von {goal} ml Ziel · noch {remaining} ml offen': 'of {goal} ml goal · {remaining} ml to go',
      'Rückgängig ({amount} ml)': 'Undo ({amount} ml)',
      '{reached} von {total}': '{reached} of {total}',
      'Ziel: {goal} ml': 'Goal: {goal} ml',
      'Ergebnis in {unit}': 'Result in {unit}',
      'Berechnet ohne zusätzliche Verzögerungen': 'Calculated without extra delays',
      'Kosten: {cost}': 'Cost: {cost}',
      '{rate}× pro Sekunde': '{rate}× per second',
      'Stopp': 'Stop',
      'Noch nichts gespeichert': 'Nothing saved yet',
      'Speichere den aktuellen Stand über das Lesezeichen oben.': 'Save the current count using the bookmark above.',
      'Stand laden': 'Load count',
      'Stand löschen': 'Delete count',
      'Gerät': 'Device',
      'Sync im WLAN eingeschaltet': 'Wi-Fi sync turned on',
      'Sync im WLAN ausgeschaltet': 'Wi-Fi sync turned off',
      'Suche nach Geräten im WLAN…': 'Searching for devices on Wi-Fi…',
      'Heutige Trinkmenge zurückgesetzt': "Today's water intake reset",
      'Automatische Update-Prüfung eingeschaltet': 'Automatic update check turned on',
      'Automatische Update-Prüfung ausgeschaltet': 'Automatic update check turned off',
      'Der Abgleich ist ausgeschaltet.': 'Sync is turned off.',
      'Noch kein Gerät verbunden. Öffne Toolbox auf einem Gerät mit demselben Namen im selben WLAN.': 'No device connected yet. Open Toolbox on a device with the same name on the same Wi-Fi.',
      'Aus': 'Off',
      'Name fehlt': 'Name missing',
      'Verbunden mit 1 Gerät': 'Connected to 1 device',
      'Verbunden mit {count} Geräten': 'Connected to {count} devices',
      'Netzwerk-Problem': 'Network problem',
      'Zuletzt {time}': 'Last {time}',
      'Kein Gerät gefunden': 'No device found',
      'Sync aus': 'Sync off',
      'Version {version}': 'Version {version}',
      'Toolbox konnte die Windows-Schnittstelle nicht laden.': 'Toolbox could not load the Windows interface.',
      'Updates über den Microsoft Store': 'Updates via Microsoft Store',
      'Wird geladen … {percent} %': 'Loading … {percent}%',
      'Wird installiert…': 'Installing…',
      'Suche nach Updates…': 'Checking for updates…',
      'Version {version} verfügbar': 'Version {version} available',
      'Prüfung fehlgeschlagen': 'Check failed',
      'Aktuell (Version {version})': 'Up to date (version {version})',
      'Update {version} installieren': 'Install update {version}',
      'Version {version} ist verfügbar – du benutzt {current}.': 'Version {version} is available – you are using {current}.',
      'Keine Versionshinweise angegeben.': 'No release notes provided.',
      'Update-Aktion fehlgeschlagen': 'Update action failed',
      'Aktion fehlgeschlagen': 'Action failed',
      'Std.': 'hrs',
      'Min.': 'min',
      'Sek.': 'sec',
      'Windows-PC': 'Windows PC',
      'Netzwerk-Port:': 'Network port:',
      'Bonjour:': 'Bonjour:',
      'Bonjour konnte nicht gestartet werden:': 'Bonjour could not be started:',
      'Suche im WLAN fehlgeschlagen:': 'Wi-Fi search failed:',
      'Ankündigung im WLAN:': 'Wi-Fi announcement:',
      'Ankündigung im WLAN fehlgeschlagen:': 'Wi-Fi announcement failed:',
      'Die Update-Prüfung ist nur in der installierten App verfügbar.': 'Update checks are only available in the installed app.',
      'Das Update kann nur in der installierten App installiert werden.': 'Updates can only be installed in the installed app.',
      'Die Update-Prüfung ist fehlgeschlagen. Bitte später erneut versuchen.': 'Update check failed. Please try again later.',
      'Das Update konnte nicht installiert werden. Bitte später erneut versuchen.': 'The update could not be installed. Please try again later.'
    },
    es: {
      'WERKZEUGE': 'HERRAMIENTAS',
      'Heute': 'Hoy',
      'Verlauf': 'Historial',
      'Einheiten': 'Unidades',
      'Zähler': 'Contador',
      'Downloadzeit': 'Tiempo de descarga',
      'Stromverbrauch': 'Consumo eléctrico',
      'Sync im WLAN': 'Sincronización Wi-Fi',
      'Suche im WLAN…': 'Buscando en la Wi-Fi…',
      'Wassertracker': 'Registro de agua',
      'Dein Fortschritt für heute': 'Tu progreso de hoy',
      'HEUTE': 'HOY',
      'von 2000 ml Ziel · noch 2000 ml offen': 'de 2000 ml de objetivo · quedan 2000 ml',
      'Glas': 'Vaso',
      'Flasche': 'Botella',
      'Eigene Menge': 'Cantidad personalizada',
      'Rückgängig': 'Deshacer',
      'Schnellwahl': 'Acceso rápido',
      'Tagesziel': 'Objetivo diario',
      'Ziel für heute': 'Objetivo de hoy',
      'Durchschnitt': 'Promedio',
      'pro Tag': 'por día',
      'Ziel erreicht': 'Objetivo alcanzado',
      'Tagen': 'días',
      'Bester Tag': 'Mejor día',
      'Höchstwert': 'Máximo',
      'LETZTE 30 TAGE': 'ÚLTIMOS 30 DÍAS',
      'Unter Ziel': 'Por debajo del objetivo',
      'TAGE': 'DÍAS',
      'UMRECHNUNG': 'CONVERSIÓN',
      'Wert in MB': 'Valor en MB',
      'Reset': 'Restablecer',
      'ERGEBNIS': 'RESULTADO',
      'Wert eingeben': 'Introduce un valor',
      'ZÄHLERSTAND': 'CONTEO',
      'Läuft': 'En marcha',
      'Zurücksetzen': 'Restablecer',
      'Automatisch': 'Automático',
      '5× pro Sekunde': '5× por segundo',
      'Start': 'Iniciar',
      'GESPEICHERT': 'GUARDADOS',
      'DATEI UND VERBINDUNG': 'ARCHIVO Y CONEXIÓN',
      'Dateigröße': 'Tamaño del archivo',
      'Einheit': 'Unidad',
      'Downloadgeschwindigkeit': 'Velocidad de descarga',
      'DOWNLOADZEIT': 'TIEMPO DE DESCARGA',
      'Dateigröße und Geschwindigkeit eingeben': 'Introduce el tamaño y la velocidad',
      'VERBRAUCH EINGEBEN': 'INTRODUCIR CONSUMO',
      'Leistung': 'Potencia',
      'Watt': 'Vatios',
      'Nutzungsdauer': 'Duración de uso',
      'Stunden': 'Horas',
      'Strompreis pro kWh (optional)': 'Precio de la electricidad por kWh (opcional)',
      'Kosten: Kein Strompreis angegeben': 'Coste: no se indicó precio de la electricidad',
      'Menge eintragen': 'Introducir cantidad',
      'Zahl eintippen oder eine Schnellauswahl verwenden.': 'Escribe un número o usa una selección rápida.',
      'Bitte eine Zahl zwischen 1 und 10000 eingeben.': 'Introduce un número entre 1 y 10000.',
      'Abbrechen': 'Cancelar',
      'Hinzufügen': 'Añadir',
      'Stand speichern': 'Guardar conteo',
      'Aktueller Stand: 0': 'Conteo actual: 0',
      'Aktueller Stand: {count}': 'Conteo actual: {count}',
      'Name': 'Nombre',
      'Speichern': 'Guardar',
      'Einstellungen': 'Ajustes',
      'Wasser, Netzwerk, Updates und Anzeige': 'Agua, red, actualizaciones y pantalla',
      'SPRACHE': 'IDIOMA',
      'Sprache': 'Idioma',
      'Systemsprache': 'Idioma del sistema',
      'Die App startet nach dem Wechsel neu.': 'La app se reiniciará después del cambio.',
      'Sprache konnte nicht gespeichert werden.': 'No se pudo guardar el idioma.',
      'MENGEN': 'CANTIDADES',
      'LOKALES NETZWERK': 'RED LOCAL',
      'Status': 'Estado',
      'Dieser PC': 'Este PC',
      'Jetzt suchen': 'Buscar ahora',
      'Gleicht Wassertracker und Zähler direkt mit deinen Geräten im selben WLAN ab – ohne Server und ohne Konto. Trage auf allen Geräten denselben Namen ein; nur Geräte mit diesem Namen gleichen sich ab. Ohne Namen ist der Abgleich aus. Mac, iPhone und dieser PC können gleichzeitig verbunden sein; ein Gerät gibt übernommene Änderungen automatisch an die anderen weiter.': 'Sincroniza el registro de agua y el contador directamente con tus dispositivos en la misma Wi-Fi: sin servidor y sin cuenta. Usa el mismo nombre en todos los dispositivos; solo se sincronizan los que tienen ese nombre. Sin nombre, la sincronización está desactivada. Mac, iPhone y este PC pueden estar conectados a la vez; un dispositivo reenvía automáticamente los cambios recibidos a los demás.',
      'UPDATES': 'ACTUALIZACIONES',
      'Automatisch prüfen': 'Comprobar automáticamente',
      'Version wird geladen…': 'Cargando versión…',
      'Jetzt nach Updates suchen': 'Buscar actualizaciones ahora',
      'Prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht. Ein Update ersetzt die installierte App und startet sie neu.': 'Comprueba al iniciar como máximo una vez al día si hay una versión más reciente en GitHub. Una actualización sustituye la app instalada y la reinicia.',
      'Updates werden über den Microsoft Store verwaltet. Der Store hält Toolbox automatisch aktuell; die GitHub-Update-Prüfung ist in dieser Fassung aus.': 'Las actualizaciones se gestionan mediante Microsoft Store. La Store mantiene Toolbox actualizado automáticamente; la comprobación de GitHub está desactivada en esta versión.',
      'Heute zurücksetzen': 'Restablecer hoy',
      'Setzt die heutige Trinkmenge auf 0 ml.': 'Pone el consumo de agua de hoy a 0 ml.',
      'Fertig': 'Listo',
      'Update verfügbar': 'Actualización disponible',
      'Eine neue Version steht bereit.': 'Hay una nueva versión disponible.',
      'Wird geladen …': 'Cargando…',
      'Später': 'Más tarde',
      'Installieren und neu starten': 'Instalar y reiniciar',
      'Sync-Einstellungen öffnen': 'Abrir ajustes de sincronización',
      'Umrechnung': 'Conversión',
      'Verringern': 'Disminuir',
      'Erhöhen': 'Aumentar',
      'Langsamer': 'Más lento',
      'Schneller': 'Más rápido',
      'Aktuellen Stand speichern': 'Guardar conteo actual',
      'Geschwindigkeitseinheit': 'Unidad de velocidad',
      'Schließen': 'Cerrar',
      'z. B. Runde 1': 'p. ej. Ronda 1',
      'Glas verkleinern': 'Reducir tamaño del vaso',
      'Glas vergrößern': 'Aumentar tamaño del vaso',
      'Flasche verkleinern': 'Reducir tamaño de la botella',
      'Flasche vergrößern': 'Aumentar tamaño de la botella',
      'Tagesziel verkleinern': 'Reducir objetivo diario',
      'Tagesziel vergrößern': 'Aumentar objetivo diario',
      'z. B. Familie': 'p. ej. Familia',
      'Die letzten 30 Tage im Überblick': 'Los últimos 30 días de un vistazo',
      'MB/GB und Mbit/MB umrechnen': 'Convertir MB/GB y Mbit/MB',
      'Manuell oder automatisch zählen': 'Contar manual o automáticamente',
      'Dateigröße und Geschwindigkeit': 'Tamaño del archivo y velocidad',
      'Leistung, Dauer und Kosten': 'Potencia, duración y coste',
      'Wert in GB': 'Valor en GB',
      'Wert in Mbit': 'Valor en Mbit',
      'Tagesziel erreicht – {goal} ml geschafft.': 'Objetivo diario alcanzado: {goal} ml completados.',
      'von {goal} ml Ziel · noch {remaining} ml offen': 'de {goal} ml de objetivo · quedan {remaining} ml',
      'Rückgängig ({amount} ml)': 'Deshacer ({amount} ml)',
      '{reached} von {total}': '{reached} de {total}',
      'Ziel: {goal} ml': 'Objetivo: {goal} ml',
      'Ergebnis in {unit}': 'Resultado en {unit}',
      'Berechnet ohne zusätzliche Verzögerungen': 'Calculado sin retardos adicionales',
      'Kosten: {cost}': 'Coste: {cost}',
      '{rate}× pro Sekunde': '{rate}× por segundo',
      'Stopp': 'Detener',
      'Noch nichts gespeichert': 'Aún no hay nada guardado',
      'Speichere den aktuellen Stand über das Lesezeichen oben.': 'Guarda el conteo actual con el marcador de arriba.',
      'Stand laden': 'Cargar conteo',
      'Stand löschen': 'Eliminar conteo',
      'Gerät': 'Dispositivo',
      'Sync im WLAN eingeschaltet': 'Sincronización Wi-Fi activada',
      'Sync im WLAN ausgeschaltet': 'Sincronización Wi-Fi desactivada',
      'Suche nach Geräten im WLAN…': 'Buscando dispositivos en la Wi-Fi…',
      'Heutige Trinkmenge zurückgesetzt': 'Consumo de agua de hoy restablecido',
      'Automatische Update-Prüfung eingeschaltet': 'Comprobación automática de actualizaciones activada',
      'Automatische Update-Prüfung ausgeschaltet': 'Comprobación automática de actualizaciones desactivada',
      'Der Abgleich ist ausgeschaltet.': 'La sincronización está desactivada.',
      'Noch kein Gerät verbunden. Öffne Toolbox auf einem Gerät mit demselben Namen im selben WLAN.': 'Aún no hay ningún dispositivo conectado. Abre Toolbox en un dispositivo con el mismo nombre en la misma Wi-Fi.',
      'Aus': 'Desactivada',
      'Name fehlt': 'Falta el nombre',
      'Verbunden mit 1 Gerät': 'Conectado a 1 dispositivo',
      'Verbunden mit {count} Geräten': 'Conectado a {count} dispositivos',
      'Netzwerk-Problem': 'Problema de red',
      'Zuletzt {time}': 'Última {time}',
      'Kein Gerät gefunden': 'No se encontró ningún dispositivo',
      'Sync aus': 'Sincronización desactivada',
      'Version {version}': 'Versión {version}',
      'Toolbox konnte die Windows-Schnittstelle nicht laden.': 'Toolbox no pudo cargar la interfaz de Windows.',
      'Updates über den Microsoft Store': 'Actualizaciones mediante Microsoft Store',
      'Wird geladen … {percent} %': 'Cargando… {percent} %',
      'Wird installiert…': 'Instalando…',
      'Suche nach Updates…': 'Buscando actualizaciones…',
      'Version {version} verfügbar': 'Versión {version} disponible',
      'Prüfung fehlgeschlagen': 'Error en la comprobación',
      'Aktuell (Version {version})': 'Actualizado (versión {version})',
      'Update {version} installieren': 'Instalar actualización {version}',
      'Version {version} ist verfügbar – du benutzt {current}.': 'La versión {version} está disponible; usas la {current}.',
      'Keine Versionshinweise angegeben.': 'No hay notas de la versión.',
      'Update-Aktion fehlgeschlagen': 'Error en la acción de actualización',
      'Aktion fehlgeschlagen': 'Error en la acción',
      'Std.': 'h',
      'Min.': 'min',
      'Sek.': 's',
      'Windows-PC': 'PC con Windows',
      'Netzwerk-Port:': 'Puerto de red:',
      'Bonjour:': 'Bonjour:',
      'Bonjour konnte nicht gestartet werden:': 'No se pudo iniciar Bonjour:',
      'Suche im WLAN fehlgeschlagen:': 'Error al buscar en la Wi-Fi:',
      'Ankündigung im WLAN:': 'Anuncio en la Wi-Fi:',
      'Ankündigung im WLAN fehlgeschlagen:': 'Error al anunciar en la Wi-Fi:',
      'Die Update-Prüfung ist nur in der installierten App verfügbar.': 'La comprobación de actualizaciones solo está disponible en la app instalada.',
      'Das Update kann nur in der installierten App installiert werden.': 'La actualización solo se puede instalar en la app instalada.',
      'Die Update-Prüfung ist fehlgeschlagen. Bitte später erneut versuchen.': 'La comprobación de actualizaciones falló. Inténtalo de nuevo más tarde.',
      'Das Update konnte nicht installiert werden. Bitte später erneut versuchen.': 'No se pudo instalar la actualización. Inténtalo de nuevo más tarde.'
    },
    fr: {
      'WERKZEUGE': 'OUTILS',
      'Heute': "Aujourd'hui",
      'Verlauf': 'Historique',
      'Einheiten': 'Unités',
      'Zähler': 'Compteur',
      'Downloadzeit': 'Temps de téléchargement',
      'Stromverbrauch': 'Consommation électrique',
      'Sync im WLAN': 'Synchronisation Wi-Fi',
      'Suche im WLAN…': 'Recherche sur le Wi-Fi…',
      'Wassertracker': "Suivi de l'eau",
      'Dein Fortschritt für heute': 'Votre progression du jour',
      'HEUTE': "AUJOURD'HUI",
      'von 2000 ml Ziel · noch 2000 ml offen': "sur 2000 ml d'objectif · 2000 ml restants",
      'Glas': 'Verre',
      'Flasche': 'Bouteille',
      'Eigene Menge': 'Quantité personnalisée',
      'Rückgängig': 'Annuler',
      'Schnellwahl': 'Ajout rapide',
      'Tagesziel': 'Objectif quotidien',
      'Ziel für heute': 'Objectif du jour',
      'Durchschnitt': 'Moyenne',
      'pro Tag': 'par jour',
      'Ziel erreicht': 'Objectif atteint',
      'Tagen': 'jours',
      'Bester Tag': 'Meilleur jour',
      'Höchstwert': 'Maximum',
      'LETZTE 30 TAGE': '30 DERNIERS JOURS',
      'Unter Ziel': "Sous l'objectif",
      'TAGE': 'JOURS',
      'UMRECHNUNG': 'CONVERSION',
      'Wert in MB': 'Valeur en Mo',
      'Reset': 'Réinitialiser',
      'ERGEBNIS': 'RÉSULTAT',
      'Wert eingeben': 'Saisir une valeur',
      'ZÄHLERSTAND': 'COMPTEUR',
      'Läuft': 'En cours',
      'Zurücksetzen': 'Réinitialiser',
      'Automatisch': 'Automatique',
      '5× pro Sekunde': '5× par seconde',
      'Start': 'Démarrer',
      'GESPEICHERT': 'ENREGISTRÉS',
      'DATEI UND VERBINDUNG': 'FICHIER ET CONNEXION',
      'Dateigröße': 'Taille du fichier',
      'Einheit': 'Unité',
      'Downloadgeschwindigkeit': 'Vitesse de téléchargement',
      'DOWNLOADZEIT': 'TEMPS DE TÉLÉCHARGEMENT',
      'Dateigröße und Geschwindigkeit eingeben': 'Saisir la taille et la vitesse',
      'VERBRAUCH EINGEBEN': 'SAISIR LA CONSOMMATION',
      'Leistung': 'Puissance',
      'Watt': 'Watts',
      'Nutzungsdauer': "Durée d'utilisation",
      'Stunden': 'Heures',
      'Strompreis pro kWh (optional)': "Prix de l'électricité par kWh (facultatif)",
      'Kosten: Kein Strompreis angegeben': "Coût : aucun prix de l'électricité indiqué",
      'Menge eintragen': 'Saisir la quantité',
      'Zahl eintippen oder eine Schnellauswahl verwenden.': 'Saisissez un nombre ou utilisez une sélection rapide.',
      'Bitte eine Zahl zwischen 1 und 10000 eingeben.': 'Veuillez saisir un nombre entre 1 et 10000.',
      'Abbrechen': 'Annuler',
      'Hinzufügen': 'Ajouter',
      'Stand speichern': 'Enregistrer le compteur',
      'Aktueller Stand: 0': 'Compteur actuel : 0',
      'Aktueller Stand: {count}': 'Compteur actuel : {count}',
      'Name': 'Nom',
      'Speichern': 'Enregistrer',
      'Einstellungen': 'Paramètres',
      'Wasser, Netzwerk, Updates und Anzeige': 'Eau, réseau, mises à jour et affichage',
      'SPRACHE': 'LANGUE',
      'Sprache': 'Langue',
      'Systemsprache': 'Langue du système',
      'Die App startet nach dem Wechsel neu.': "L'app redémarrera après le changement.",
      'Sprache konnte nicht gespeichert werden.': "Impossible d'enregistrer la langue.",
      'MENGEN': 'QUANTITÉS',
      'LOKALES NETZWERK': 'RÉSEAU LOCAL',
      'Status': 'État',
      'Dieser PC': 'Ce PC',
      'Jetzt suchen': 'Rechercher maintenant',
      'Gleicht Wassertracker und Zähler direkt mit deinen Geräten im selben WLAN ab – ohne Server und ohne Konto. Trage auf allen Geräten denselben Namen ein; nur Geräte mit diesem Namen gleichen sich ab. Ohne Namen ist der Abgleich aus. Mac, iPhone und dieser PC können gleichzeitig verbunden sein; ein Gerät gibt übernommene Änderungen automatisch an die anderen weiter.': "Synchronisez le suivi de l'eau et le compteur directement avec vos appareils sur le même Wi-Fi : sans serveur et sans compte. Utilisez le même nom sur tous les appareils ; seuls ceux qui portent ce nom se synchronisent. Sans nom, la synchronisation est désactivée. Mac, iPhone et ce PC peuvent être connectés en même temps ; un appareil transmet automatiquement les modifications reçues aux autres.",
      'UPDATES': 'MISES À JOUR',
      'Automatisch prüfen': 'Vérifier automatiquement',
      'Version wird geladen…': 'Chargement de la version…',
      'Jetzt nach Updates suchen': 'Rechercher des mises à jour',
      'Prüft beim Start höchstens einmal pro Tag, ob auf GitHub eine neuere Version bereitsteht. Ein Update ersetzt die installierte App und startet sie neu.': 'Vérifie au démarrage, au plus une fois par jour, si une version plus récente est disponible sur GitHub. Une mise à jour remplace l’app installée et la redémarre.',
      'Updates werden über den Microsoft Store verwaltet. Der Store hält Toolbox automatisch aktuell; die GitHub-Update-Prüfung ist in dieser Fassung aus.': 'Les mises à jour sont gérées par le Microsoft Store. Le Store maintient Toolbox à jour automatiquement ; la vérification GitHub est désactivée dans cette version.',
      'Heute zurücksetzen': "Réinitialiser aujourd'hui",
      'Setzt die heutige Trinkmenge auf 0 ml.': "Remet la consommation d'eau du jour à 0 ml.",
      'Fertig': 'Terminé',
      'Update verfügbar': 'Mise à jour disponible',
      'Eine neue Version steht bereit.': 'Une nouvelle version est disponible.',
      'Wird geladen …': 'Chargement…',
      'Später': 'Plus tard',
      'Installieren und neu starten': 'Installer et redémarrer',
      'Sync-Einstellungen öffnen': 'Ouvrir les paramètres de synchronisation',
      'Umrechnung': 'Conversion',
      'Verringern': 'Diminuer',
      'Erhöhen': 'Augmenter',
      'Langsamer': 'Plus lent',
      'Schneller': 'Plus rapide',
      'Aktuellen Stand speichern': 'Enregistrer le compteur actuel',
      'Geschwindigkeitseinheit': 'Unité de vitesse',
      'Schließen': 'Fermer',
      'z. B. Runde 1': 'p. ex. Manche 1',
      'Glas verkleinern': 'Réduire la taille du verre',
      'Glas vergrößern': 'Augmenter la taille du verre',
      'Flasche verkleinern': 'Réduire la taille de la bouteille',
      'Flasche vergrößern': 'Augmenter la taille de la bouteille',
      'Tagesziel verkleinern': "Réduire l'objectif quotidien",
      'Tagesziel vergrößern': "Augmenter l'objectif quotidien",
      'z. B. Familie': 'p. ex. Famille',
      'Die letzten 30 Tage im Überblick': 'Les 30 derniers jours en un coup d’œil',
      'MB/GB und Mbit/MB umrechnen': 'Convertir Mo/Go et Mbit/Mo',
      'Manuell oder automatisch zählen': 'Compter manuellement ou automatiquement',
      'Dateigröße und Geschwindigkeit': 'Taille du fichier et vitesse',
      'Leistung, Dauer und Kosten': 'Puissance, durée et coût',
      'Wert in GB': 'Valeur en Go',
      'Wert in Mbit': 'Valeur en Mbit',
      'Tagesziel erreicht – {goal} ml geschafft.': 'Objectif quotidien atteint – {goal} ml effectués.',
      'von {goal} ml Ziel · noch {remaining} ml offen': "sur {goal} ml d'objectif · {remaining} ml restants",
      'Rückgängig ({amount} ml)': 'Annuler ({amount} ml)',
      '{reached} von {total}': '{reached} sur {total}',
      'Ziel: {goal} ml': 'Objectif : {goal} ml',
      'Ergebnis in {unit}': 'Résultat en {unit}',
      'Berechnet ohne zusätzliche Verzögerungen': 'Calculé sans délais supplémentaires',
      'Kosten: {cost}': 'Coût : {cost}',
      '{rate}× pro Sekunde': '{rate}× par seconde',
      'Stopp': 'Arrêter',
      'Noch nichts gespeichert': "Rien d'enregistré",
      'Speichere den aktuellen Stand über das Lesezeichen oben.': 'Enregistrez le compteur actuel avec le signet ci-dessus.',
      'Stand laden': 'Charger le compteur',
      'Stand löschen': 'Supprimer le compteur',
      'Gerät': 'Appareil',
      'Sync im WLAN eingeschaltet': 'Synchronisation Wi-Fi activée',
      'Sync im WLAN ausgeschaltet': 'Synchronisation Wi-Fi désactivée',
      'Suche nach Geräten im WLAN…': "Recherche d'appareils sur le Wi-Fi…",
      'Heutige Trinkmenge zurückgesetzt': "Consommation d'eau du jour réinitialisée",
      'Automatische Update-Prüfung eingeschaltet': 'Vérification automatique des mises à jour activée',
      'Automatische Update-Prüfung ausgeschaltet': 'Vérification automatique des mises à jour désactivée',
      'Der Abgleich ist ausgeschaltet.': 'La synchronisation est désactivée.',
      'Noch kein Gerät verbunden. Öffne Toolbox auf einem Gerät mit demselben Namen im selben WLAN.': "Aucun appareil connecté. Ouvrez Toolbox sur un appareil portant le même nom sur le même Wi-Fi.",
      'Aus': 'Désactivée',
      'Name fehlt': 'Nom manquant',
      'Verbunden mit 1 Gerät': 'Connecté à 1 appareil',
      'Verbunden mit {count} Geräten': 'Connecté à {count} appareils',
      'Netzwerk-Problem': 'Problème réseau',
      'Zuletzt {time}': 'Dernière {time}',
      'Kein Gerät gefunden': 'Aucun appareil trouvé',
      'Sync aus': 'Synchronisation désactivée',
      'Version {version}': 'Version {version}',
      'Toolbox konnte die Windows-Schnittstelle nicht laden.': "Toolbox n'a pas pu charger l'interface Windows.",
      'Updates über den Microsoft Store': 'Mises à jour via le Microsoft Store',
      'Wird geladen … {percent} %': 'Chargement… {percent} %',
      'Wird installiert…': 'Installation…',
      'Suche nach Updates…': 'Recherche de mises à jour…',
      'Version {version} verfügbar': 'Version {version} disponible',
      'Prüfung fehlgeschlagen': 'Échec de la vérification',
      'Aktuell (Version {version})': 'À jour (version {version})',
      'Update {version} installieren': 'Installer la mise à jour {version}',
      'Version {version} ist verfügbar – du benutzt {current}.': 'La version {version} est disponible ; vous utilisez la {current}.',
      'Keine Versionshinweise angegeben.': 'Aucune note de version fournie.',
      'Update-Aktion fehlgeschlagen': "Échec de l'action de mise à jour",
      'Aktion fehlgeschlagen': "Échec de l'action",
      'Std.': 'h',
      'Min.': 'min',
      'Sek.': 's',
      'Windows-PC': 'PC Windows',
      'Netzwerk-Port:': 'Port réseau :',
      'Bonjour:': 'Bonjour :',
      'Bonjour konnte nicht gestartet werden:': "Impossible de démarrer Bonjour :",
      'Suche im WLAN fehlgeschlagen:': 'Échec de la recherche Wi-Fi :',
      'Ankündigung im WLAN:': 'Annonce Wi-Fi :',
      'Ankündigung im WLAN fehlgeschlagen:': 'Échec de l’annonce Wi-Fi :',
      'Die Update-Prüfung ist nur in der installierten App verfügbar.': "La vérification des mises à jour n'est disponible que dans l'app installée.",
      'Das Update kann nur in der installierten App installiert werden.': "La mise à jour ne peut être installée que dans l'app installée.",
      'Die Update-Prüfung ist fehlgeschlagen. Bitte später erneut versuchen.': 'La vérification des mises à jour a échoué. Veuillez réessayer plus tard.',
      'Das Update konnte nicht installiert werden. Bitte später erneut versuchen.': "Impossible d'installer la mise à jour. Veuillez réessayer plus tard."
    }
  }

  const supported = ['de', 'en', 'es', 'fr']
  // Englisch ist der Rückfall für alle Sprachen, die die App nicht kennt.
  const defaultLanguage = 'en'
  const localeTags = { de: 'de-DE', en: 'en-US', es: 'es-ES', fr: 'fr-FR' }
  const STORAGE_KEY = 'toolbox.locale'

  function baseLanguage(tag) {
    return String(tag || '').trim().toLowerCase().split('-')[0]
  }

  /// Nimmt den vollständigen Region-Tag (z. B. en-GB), solange er gültig ist und
  /// zur gewählten Sprache passt; sonst den Standard-Tag der Sprache.
  function canonicalTag(tag, language) {
    const raw = String(tag || '').trim()
    if (raw) {
      try {
        const [canonical] = Intl.getCanonicalLocales(raw)
        if (canonical && baseLanguage(canonical) === language) return canonical
      } catch {
        // Ungültiger Tag – unten auf den Standard der Sprache zurückfallen.
      }
    }
    return localeTags[language]
  }

  function preferredTags() {
    if (typeof navigator === 'undefined') return []
    const tags = []
    if (Array.isArray(navigator.languages)) {
      for (const tag of navigator.languages) {
        if (typeof tag === 'string' && tag.trim()) tags.push(tag)
      }
    }
    if (typeof navigator.language === 'string' && navigator.language.trim()) {
      tags.push(navigator.language)
    }
    return tags
  }

  function readStoredPreference() {
    if (typeof localStorage === 'undefined') return null
    try {
      const language = String(localStorage.getItem(STORAGE_KEY) || '').toLowerCase().split('-')[0]
      return supported.includes(language) ? language : null
    } catch {
      return null
    }
  }

  function setLocalePreference(value) {
    if (typeof localStorage === 'undefined') return false
    const language = String(value || '').toLowerCase().split('-')[0]
    try {
      if (supported.includes(language)) {
        localStorage.setItem(STORAGE_KEY, language)
      } else {
        localStorage.removeItem(STORAGE_KEY)
      }
      return true
    } catch {
      return false
    }
  }

  /// Reine Auswahllogik, damit sie ohne Browser geprüft werden kann.
  /// Reihenfolge: erzwungene Sprache, gespeicherte Wahl, Systemsprachen,
  /// danach Englisch.
  function chooseLocale({ forced, stored, preferred } = {}) {
    const forcedLanguage = baseLanguage(forced)
    if (forced && supported.includes(forcedLanguage)) {
      return { language: forcedLanguage, localeTag: canonicalTag(forced, forcedLanguage) }
    }
    if (stored && supported.includes(stored)) {
      return { language: stored, localeTag: localeTags[stored] }
    }
    for (const tag of preferred || []) {
      const language = baseLanguage(tag)
      if (supported.includes(language)) {
        return { language, localeTag: canonicalTag(tag, language) }
      }
    }
    return { language: defaultLanguage, localeTag: localeTags[defaultLanguage] }
  }

  function resolveLocale() {
    const forced = typeof window !== 'undefined' ? window.__toolboxLocale : undefined
    return chooseLocale({
      forced,
      stored: readStoredPreference(),
      preferred: preferredTags(),
    })
  }

  const resolved = resolveLocale()
  const locale = resolved.language
  const preference = readStoredPreference() || 'system'

  function interpolate(template, variables) {
    return String(template).replace(/\{(\w+)\}/g, (match, key) => {
      return variables && Object.prototype.hasOwnProperty.call(variables, key)
        ? String(variables[key])
        : match
    })
  }

  function translateFor(language, text, variables) {
    const dict = dictionaries[language] || {}
    if (language === 'de') return interpolate(text, variables)
    const template = Object.prototype.hasOwnProperty.call(dict, text) ? dict[text] : text
    return interpolate(template, variables)
  }

  function t(text, variables) {
    return translateFor(locale, text, variables)
  }

  function localizeDom(documentRoot) {
    const doc = documentRoot || (typeof document !== 'undefined' ? document : null)
    if (!doc) return
    doc.documentElement.lang = locale

    const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT, {
      acceptNode(node) {
        const parent = node.parentElement
        if (!parent) return NodeFilter.FILTER_REJECT
        if (/^(SCRIPT|STYLE|TEXTAREA)$/i.test(parent.tagName)) return NodeFilter.FILTER_REJECT
        return NodeFilter.FILTER_ACCEPT
      }
    })

    const nodes = []
    while (walker.nextNode()) nodes.push(walker.currentNode)

    for (const node of nodes) {
      const raw = node.nodeValue || ''
      const trimmed = raw.trim()
      if (!trimmed) continue
      const normalized = trimmed.replace(/\s+/g, ' ')
      const translated = t(normalized)
      if (translated === normalized) continue
      const leading = raw.match(/^\s*/)[0]
      const trailing = raw.match(/\s*$/)[0]
      node.nodeValue = leading + translated + trailing
    }

    for (const element of doc.querySelectorAll('[placeholder], [title], [aria-label]')) {
      for (const attribute of ['placeholder', 'title', 'aria-label']) {
        const value = element.getAttribute(attribute)
        if (!value) continue
        const translated = t(value)
        if (translated !== value) element.setAttribute(attribute, translated)
      }
    }
  }

  function missingKeys(language, keys) {
    const dict = dictionaries[language] || {}
    return keys.filter(key => !Object.prototype.hasOwnProperty.call(dict, key))
  }

  return {
    dictionaries,
    supported,
    defaultLanguage,
    locale,
    language: locale,
    preference,
    localeTag: resolved.localeTag,
    localeTags,
    chooseLocale,
    baseLanguage,
    setLocalePreference,
    t,
    translateFor,
    localizeDom,
    missingKeys
  }
})
