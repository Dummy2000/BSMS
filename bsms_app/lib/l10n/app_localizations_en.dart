// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navLive => 'Live ECG';

  @override
  String get navHistory => 'History';

  @override
  String get navPersons => 'People';

  @override
  String get liveEcgTitle => 'Live ECG';

  @override
  String get bleDisconnectTooltip => 'Disconnect BLE';

  @override
  String get bleConnectTooltip => 'Connect BLE';

  @override
  String get waitingForData => 'Waiting for data …';

  @override
  String get noBleDevice => 'No BLE device connected';

  @override
  String get statusNotConnected => 'Not connected';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusConnectionLost => 'Connection lost';

  @override
  String get statusSearching => 'Searching for device …';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get recordStart => 'Start recording';

  @override
  String get recordStop => 'Stop recording';

  @override
  String bpm(int value) {
    return '$value bpm';
  }

  @override
  String hrv(int value) {
    return 'HRV $value ms';
  }

  @override
  String get leadOffTitle => 'Electrode disconnected!';

  @override
  String get leadOffDetailBoth => 'Both electrodes have no contact';

  @override
  String leadOffDetailOne(String lead) {
    return 'Electrode $lead has no contact';
  }

  @override
  String leadOffHint(String detail) {
    return '$detail – please check contact.';
  }

  @override
  String get personPickTitle => 'Select person';

  @override
  String get personNoneYet => 'No people yet — please create one first.';

  @override
  String get personCreateNew => 'Create new person';

  @override
  String personAge(int age) {
    return '$age years';
  }

  @override
  String get historyTitle => 'Recordings';

  @override
  String get tabSdImport => 'SD import';

  @override
  String get tabBleRecordings => 'BLE recordings';

  @override
  String get sdEmpty => 'No SD imports yet.\nTap + to load a file.';

  @override
  String get bleEmpty =>
      'No BLE recordings yet.\nStart a recording in the Live tab.';

  @override
  String get importFile => 'Import file';

  @override
  String importedSummary(int samples, int skipped) {
    return 'Imported: $samples samples ($skipped faulty packets skipped)';
  }

  @override
  String get removeTooltip => 'Remove';

  @override
  String get importError => 'The file is corrupt or has an unknown format.';

  @override
  String sessionSubtitle(String duration, int samples) {
    return '$duration · $samples samples';
  }

  @override
  String get axisTime => 'Time';

  @override
  String get axisAdc => 'ADC';

  @override
  String get axisHr => 'HR (bpm)';

  @override
  String sessionHeaderSub(int samples, String duration) {
    return '$samples samples · $duration';
  }

  @override
  String get tooltipRPeaksShow => 'Show R-peaks';

  @override
  String get tooltipRPeaksHide => 'Hide R-peaks';

  @override
  String get tooltipHrShow => 'Show HR';

  @override
  String get tooltipHrHide => 'Hide HR';

  @override
  String get tooltipLeadOffShow => 'Show lead-off';

  @override
  String get tooltipLeadOffHide => 'Hide lead-off';

  @override
  String get tooltipDisconnectShow => 'Show dropouts';

  @override
  String get tooltipDisconnectHide => 'Hide dropouts';

  @override
  String get tooltipShowRaw => 'Show raw';

  @override
  String get tooltipShowFiltered => 'Show filtered';

  @override
  String get statAvgHr => 'Avg HR';

  @override
  String get statSdnn => 'SDNN';

  @override
  String get statRmssd => 'RMSSD';

  @override
  String get rmssdOpen => 'open ›';

  @override
  String get statTachy => 'Tachy';

  @override
  String get statBrady => 'Brady';

  @override
  String get statPauses => 'Pauses';

  @override
  String get statLeadOff => 'Lead-Off';

  @override
  String get statDisconnects => 'Dropouts';

  @override
  String get evtTachycardia => 'Tachycardia';

  @override
  String get evtBradycardia => 'Bradycardia';

  @override
  String get evtPause => 'Pause';

  @override
  String get evtLeadOff => 'Lead-Off';

  @override
  String get evtContactLoss => 'Contact loss';

  @override
  String eventCounter(int index, int total) {
    return 'Event $index / $total';
  }

  @override
  String get prevEvent => 'Previous event';

  @override
  String get nextEvent => 'Next event';

  @override
  String get eventListTooltip => 'Event list';

  @override
  String eventsTitle(int count) {
    return 'Events ($count)';
  }

  @override
  String get close => 'Close';

  @override
  String get rmssdTitle => 'RMSSD';

  @override
  String get rmssdNotComputed => 'Not computed yet';

  @override
  String get rmssdNa => 'N.A.';

  @override
  String rmssdResultDetail(String start, int seconds, int beats) {
    return 'from $start · duration $seconds s · $beats beats';
  }

  @override
  String rmssdTooFewBeats(int beats) {
    return 'Too few beats in range ($beats).';
  }

  @override
  String get rmssdWindowLength => 'Window length';

  @override
  String rmssdCreateHere(String start) {
    return 'Create RMSSD here (from $start)';
  }

  @override
  String rmssdNotEnoughAfter(int seconds) {
    return 'Not enough recording after the current position ($seconds s needed).';
  }

  @override
  String get rmssdCustomRange => 'Custom range';

  @override
  String get rmssdStartTime => 'Start time (from beginning)';

  @override
  String get rmssdComputeRange => 'Compute for this range';

  @override
  String rmssdOutOfRange(String total) {
    return 'Range is outside the recording (total $total).';
  }

  @override
  String skippedPackets(int count) {
    return '$count faulty packets skipped';
  }

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get personDeleteTitle => 'Delete person?';

  @override
  String personDeleteBody(String name) {
    return '$name and all associated data will be removed.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get personsTitle => 'People';

  @override
  String get personsEmpty =>
      'No people created yet.\nTap + to create a new person.';

  @override
  String get newPerson => 'New person';

  @override
  String get noRecordings => 'No recordings yet.';

  @override
  String get editPerson => 'Edit person';

  @override
  String get fieldName => 'Name *';

  @override
  String get nameRequired => 'Name required';

  @override
  String get fieldAge => 'Age *';

  @override
  String get yearsSuffix => 'years';

  @override
  String get validAge => 'Enter a valid age';

  @override
  String get fieldNotes => 'Notes (optional)';

  @override
  String get notesHint => 'e.g. diagnosis, medication …';

  @override
  String get create => 'Create';

  @override
  String get save => 'Save';

  @override
  String get permTitle => 'BSMS ECG Monitor';

  @override
  String get permIntro => 'The following permissions are required to operate:';

  @override
  String get permBluetooth => 'Bluetooth';

  @override
  String get permBluetoothDesc =>
      'Connect to the EKG-Holter via BLE and receive measurement data.';

  @override
  String get permLocation => 'Location';

  @override
  String get permLocationDesc => 'Required for BLE scanning on Android ≤ 11.';

  @override
  String get permStorage => 'Storage';

  @override
  String get permStorageDesc =>
      'Import SD-card files on older Android versions.';

  @override
  String get permPermanentlyDenied =>
      'A permission was permanently denied. Please allow access in the app settings.';

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permGrant => 'Grant permissions';
}
