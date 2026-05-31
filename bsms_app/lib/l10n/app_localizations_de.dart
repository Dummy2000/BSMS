// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get navLive => 'Live EKG';

  @override
  String get navHistory => 'Verlauf';

  @override
  String get navPersons => 'Personen';

  @override
  String get liveEcgTitle => 'Live EKG';

  @override
  String get bleDisconnectTooltip => 'BLE trennen';

  @override
  String get bleConnectTooltip => 'BLE verbinden';

  @override
  String get espStart => 'Messung starten';

  @override
  String get espStandby => 'Standby';

  @override
  String get waitingForData => 'Warte auf Daten …';

  @override
  String get noBleDevice => 'Kein BLE-Gerät verbunden';

  @override
  String get statusNotConnected => 'Nicht verbunden';

  @override
  String get statusConnected => 'Verbunden';

  @override
  String get statusConnectionLost => 'Verbindung getrennt';

  @override
  String get statusSearching => 'Suche Gerät …';

  @override
  String get statusDisconnected => 'Getrennt';

  @override
  String get recordStart => 'Aufnahme starten';

  @override
  String get recordStop => 'Aufnahme stoppen';

  @override
  String bpm(int value) {
    return '$value bpm';
  }

  @override
  String hrv(int value) {
    return 'HRV $value ms';
  }

  @override
  String get leadOffTitle => 'Elektrode abgegangen!';

  @override
  String get leadOffDetailBoth => 'Beide Elektroden ohne Kontakt';

  @override
  String leadOffDetailOne(String lead) {
    return 'Elektrode $lead ohne Kontakt';
  }

  @override
  String leadOffHint(String detail) {
    return '$detail – bitte Kontakt prüfen.';
  }

  @override
  String get personPickTitle => 'Person auswählen';

  @override
  String get personNoneYet => 'Noch keine Personen — bitte zuerst anlegen.';

  @override
  String get personCreateNew => 'Neue Person anlegen';

  @override
  String personAge(int age) {
    return '$age Jahre';
  }

  @override
  String get historyTitle => 'Aufnahmen';

  @override
  String get tabSdImport => 'SD-Import';

  @override
  String get tabBleRecordings => 'BLE-Aufnahmen';

  @override
  String get sdEmpty =>
      'Noch keine SD-Importe.\nTippe auf + um eine Datei zu laden.';

  @override
  String get bleEmpty =>
      'Noch keine BLE-Aufnahmen.\nStarte eine Aufnahme im Live-Tab.';

  @override
  String get importFile => 'Datei importieren';

  @override
  String importedSummary(int samples, int skipped) {
    return 'Importiert: $samples Samples ($skipped fehlerhafte Pakete übersprungen)';
  }

  @override
  String get removeTooltip => 'Entfernen';

  @override
  String get importError =>
      'Die Datei ist beschädigt oder hat ein unbekanntes Format.';

  @override
  String sessionSubtitle(String duration, int samples) {
    return '$duration · $samples Samples';
  }

  @override
  String get axisTime => 'Zeit';

  @override
  String get axisAdc => 'ADC';

  @override
  String get axisHr => 'HR (bpm)';

  @override
  String sessionHeaderSub(int samples, String duration) {
    return '$samples Samples · $duration';
  }

  @override
  String get tooltipRPeaksShow => 'R-Peaks anzeigen';

  @override
  String get tooltipRPeaksHide => 'R-Peaks ausblenden';

  @override
  String get tooltipHrShow => 'HR anzeigen';

  @override
  String get tooltipHrHide => 'HR ausblenden';

  @override
  String get tooltipLeadOffShow => 'Lead-Off anzeigen';

  @override
  String get tooltipLeadOffHide => 'Lead-Off ausblenden';

  @override
  String get tooltipDisconnectShow => 'Abbrüche anzeigen';

  @override
  String get tooltipDisconnectHide => 'Abbrüche ausblenden';

  @override
  String get tooltipShowRaw => 'Roh anzeigen';

  @override
  String get tooltipShowFiltered => 'Gefiltert anzeigen';

  @override
  String get statAvgHr => 'Ø HR';

  @override
  String get statSdnn => 'SDNN';

  @override
  String get statRmssd => 'RMSSD';

  @override
  String get rmssdOpen => 'öffnen ›';

  @override
  String get statTachy => 'Tachy';

  @override
  String get statBrady => 'Brady';

  @override
  String get statPauses => 'Pausen';

  @override
  String get statLeadOff => 'Lead-Off';

  @override
  String get statDisconnects => 'Abbrüche';

  @override
  String get evtTachycardia => 'Tachykardie';

  @override
  String get evtBradycardia => 'Bradykardie';

  @override
  String get evtPause => 'Pause';

  @override
  String get evtLeadOff => 'Lead-Off';

  @override
  String get evtContactLoss => 'Kontaktverlust';

  @override
  String eventCounter(int index, int total) {
    return 'Ereignis $index / $total';
  }

  @override
  String get prevEvent => 'Voriges Ereignis';

  @override
  String get nextEvent => 'Nächstes Ereignis';

  @override
  String get eventListTooltip => 'Ereignisliste';

  @override
  String eventsTitle(int count) {
    return 'Ereignisse ($count)';
  }

  @override
  String get close => 'Schließen';

  @override
  String get rmssdTitle => 'RMSSD';

  @override
  String get rmssdNotComputed => 'Noch nicht berechnet';

  @override
  String get rmssdNa => 'N.A.';

  @override
  String rmssdResultDetail(String start, int seconds, int beats) {
    return 'ab $start · Dauer $seconds s · $beats Schläge';
  }

  @override
  String rmssdTooFewBeats(int beats) {
    return 'Zu wenige Schläge im Zeitraum ($beats).';
  }

  @override
  String get rmssdWindowLength => 'Fensterlänge';

  @override
  String rmssdCreateHere(String start) {
    return 'RMSSD hier erstellen (ab $start)';
  }

  @override
  String rmssdNotEnoughAfter(int seconds) {
    return 'Nicht genug Aufnahme nach der aktuellen Position ($seconds s benötigt).';
  }

  @override
  String get rmssdCustomRange => 'Eigener Zeitraum';

  @override
  String get rmssdStartTime => 'Startzeit (ab Beginn)';

  @override
  String get rmssdComputeRange => 'Für diesen Zeitraum berechnen';

  @override
  String rmssdOutOfRange(String total) {
    return 'Zeitraum liegt außerhalb der Aufnahme (gesamt $total).';
  }

  @override
  String skippedPackets(int count) {
    return '$count fehlerhafte Pakete übersprungen';
  }

  @override
  String get zoomIn => 'Vergrößern';

  @override
  String get zoomOut => 'Verkleinern';

  @override
  String get personDeleteTitle => 'Person löschen?';

  @override
  String personDeleteBody(String name) {
    return '$name und alle zugehörigen Daten werden entfernt.';
  }

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get personsTitle => 'Personen';

  @override
  String get personsEmpty =>
      'Noch keine Personen angelegt.\nTippe auf + um eine neue Person zu erstellen.';

  @override
  String get newPerson => 'Neue Person';

  @override
  String get noRecordings => 'Noch keine Aufnahmen.';

  @override
  String get editPerson => 'Person bearbeiten';

  @override
  String get fieldName => 'Name *';

  @override
  String get nameRequired => 'Name erforderlich';

  @override
  String get fieldAge => 'Alter *';

  @override
  String get yearsSuffix => 'Jahre';

  @override
  String get validAge => 'Gültiges Alter eingeben';

  @override
  String get fieldNotes => 'Notizen (optional)';

  @override
  String get notesHint => 'z.B. Diagnose, Medikamente …';

  @override
  String get create => 'Erstellen';

  @override
  String get save => 'Speichern';

  @override
  String get permTitle => 'BSMS EKG Monitor';

  @override
  String get permIntro =>
      'Für den Betrieb werden folgende Berechtigungen benötigt:';

  @override
  String get permBluetooth => 'Bluetooth';

  @override
  String get permBluetoothDesc =>
      'Verbindung zum EKG-Holter über BLE herstellen und Messdaten empfangen.';

  @override
  String get permLocation => 'Standort';

  @override
  String get permLocationDesc =>
      'Auf Android ≤ 11 für das BLE-Scanning zwingend erforderlich.';

  @override
  String get permStorage => 'Speicher';

  @override
  String get permStorageDesc =>
      'SD-Karten-Dateien auf älteren Android-Versionen importieren.';

  @override
  String get permPermanentlyDenied =>
      'Eine Berechtigung wurde dauerhaft verweigert. Bitte erlaube den Zugriff in den App-Einstellungen.';

  @override
  String get permOpenSettings => 'Einstellungen öffnen';

  @override
  String get permGrant => 'Berechtigungen erteilen';
}
