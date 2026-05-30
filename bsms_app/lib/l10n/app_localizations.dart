import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fi.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fi'),
    Locale('ja'),
  ];

  /// No description provided for @navLive.
  ///
  /// In en, this message translates to:
  /// **'Live ECG'**
  String get navLive;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navPersons.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get navPersons;

  /// No description provided for @liveEcgTitle.
  ///
  /// In en, this message translates to:
  /// **'Live ECG'**
  String get liveEcgTitle;

  /// No description provided for @bleDisconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect BLE'**
  String get bleDisconnectTooltip;

  /// No description provided for @bleConnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connect BLE'**
  String get bleConnectTooltip;

  /// No description provided for @waitingForData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for data …'**
  String get waitingForData;

  /// No description provided for @noBleDevice.
  ///
  /// In en, this message translates to:
  /// **'No BLE device connected'**
  String get noBleDevice;

  /// No description provided for @statusNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get statusNotConnected;

  /// No description provided for @statusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get statusConnected;

  /// No description provided for @statusConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get statusConnectionLost;

  /// No description provided for @statusSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for device …'**
  String get statusSearching;

  /// No description provided for @statusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get statusDisconnected;

  /// No description provided for @recordStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordStart;

  /// No description provided for @recordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get recordStop;

  /// No description provided for @bpm.
  ///
  /// In en, this message translates to:
  /// **'{value} bpm'**
  String bpm(int value);

  /// No description provided for @hrv.
  ///
  /// In en, this message translates to:
  /// **'HRV {value} ms'**
  String hrv(int value);

  /// No description provided for @leadOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Electrode disconnected!'**
  String get leadOffTitle;

  /// No description provided for @leadOffDetailBoth.
  ///
  /// In en, this message translates to:
  /// **'Both electrodes have no contact'**
  String get leadOffDetailBoth;

  /// No description provided for @leadOffDetailOne.
  ///
  /// In en, this message translates to:
  /// **'Electrode {lead} has no contact'**
  String leadOffDetailOne(String lead);

  /// No description provided for @leadOffHint.
  ///
  /// In en, this message translates to:
  /// **'{detail} – please check contact.'**
  String leadOffHint(String detail);

  /// No description provided for @personPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Select person'**
  String get personPickTitle;

  /// No description provided for @personNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No people yet — please create one first.'**
  String get personNoneYet;

  /// No description provided for @personCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new person'**
  String get personCreateNew;

  /// No description provided for @personAge.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String personAge(int age);

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get historyTitle;

  /// No description provided for @tabSdImport.
  ///
  /// In en, this message translates to:
  /// **'SD import'**
  String get tabSdImport;

  /// No description provided for @tabBleRecordings.
  ///
  /// In en, this message translates to:
  /// **'BLE recordings'**
  String get tabBleRecordings;

  /// No description provided for @sdEmpty.
  ///
  /// In en, this message translates to:
  /// **'No SD imports yet.\nTap + to load a file.'**
  String get sdEmpty;

  /// No description provided for @bleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No BLE recordings yet.\nStart a recording in the Live tab.'**
  String get bleEmpty;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'Import file'**
  String get importFile;

  /// No description provided for @importedSummary.
  ///
  /// In en, this message translates to:
  /// **'Imported: {samples} samples ({skipped} faulty packets skipped)'**
  String importedSummary(int samples, int skipped);

  /// No description provided for @removeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeTooltip;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'The file is corrupt or has an unknown format.'**
  String get importError;

  /// No description provided for @sessionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{duration} · {samples} samples'**
  String sessionSubtitle(String duration, int samples);

  /// No description provided for @axisTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get axisTime;

  /// No description provided for @axisAdc.
  ///
  /// In en, this message translates to:
  /// **'ADC'**
  String get axisAdc;

  /// No description provided for @axisHr.
  ///
  /// In en, this message translates to:
  /// **'HR (bpm)'**
  String get axisHr;

  /// No description provided for @sessionHeaderSub.
  ///
  /// In en, this message translates to:
  /// **'{samples} samples · {duration}'**
  String sessionHeaderSub(int samples, String duration);

  /// No description provided for @tooltipRPeaksShow.
  ///
  /// In en, this message translates to:
  /// **'Show R-peaks'**
  String get tooltipRPeaksShow;

  /// No description provided for @tooltipRPeaksHide.
  ///
  /// In en, this message translates to:
  /// **'Hide R-peaks'**
  String get tooltipRPeaksHide;

  /// No description provided for @tooltipHrShow.
  ///
  /// In en, this message translates to:
  /// **'Show HR'**
  String get tooltipHrShow;

  /// No description provided for @tooltipHrHide.
  ///
  /// In en, this message translates to:
  /// **'Hide HR'**
  String get tooltipHrHide;

  /// No description provided for @tooltipLeadOffShow.
  ///
  /// In en, this message translates to:
  /// **'Show lead-off'**
  String get tooltipLeadOffShow;

  /// No description provided for @tooltipLeadOffHide.
  ///
  /// In en, this message translates to:
  /// **'Hide lead-off'**
  String get tooltipLeadOffHide;

  /// No description provided for @tooltipDisconnectShow.
  ///
  /// In en, this message translates to:
  /// **'Show dropouts'**
  String get tooltipDisconnectShow;

  /// No description provided for @tooltipDisconnectHide.
  ///
  /// In en, this message translates to:
  /// **'Hide dropouts'**
  String get tooltipDisconnectHide;

  /// No description provided for @tooltipShowRaw.
  ///
  /// In en, this message translates to:
  /// **'Show raw'**
  String get tooltipShowRaw;

  /// No description provided for @tooltipShowFiltered.
  ///
  /// In en, this message translates to:
  /// **'Show filtered'**
  String get tooltipShowFiltered;

  /// No description provided for @statAvgHr.
  ///
  /// In en, this message translates to:
  /// **'Avg HR'**
  String get statAvgHr;

  /// No description provided for @statSdnn.
  ///
  /// In en, this message translates to:
  /// **'SDNN'**
  String get statSdnn;

  /// No description provided for @statRmssd.
  ///
  /// In en, this message translates to:
  /// **'RMSSD'**
  String get statRmssd;

  /// No description provided for @rmssdOpen.
  ///
  /// In en, this message translates to:
  /// **'open ›'**
  String get rmssdOpen;

  /// No description provided for @statTachy.
  ///
  /// In en, this message translates to:
  /// **'Tachy'**
  String get statTachy;

  /// No description provided for @statBrady.
  ///
  /// In en, this message translates to:
  /// **'Brady'**
  String get statBrady;

  /// No description provided for @statPauses.
  ///
  /// In en, this message translates to:
  /// **'Pauses'**
  String get statPauses;

  /// No description provided for @statLeadOff.
  ///
  /// In en, this message translates to:
  /// **'Lead-Off'**
  String get statLeadOff;

  /// No description provided for @statDisconnects.
  ///
  /// In en, this message translates to:
  /// **'Dropouts'**
  String get statDisconnects;

  /// No description provided for @evtTachycardia.
  ///
  /// In en, this message translates to:
  /// **'Tachycardia'**
  String get evtTachycardia;

  /// No description provided for @evtBradycardia.
  ///
  /// In en, this message translates to:
  /// **'Bradycardia'**
  String get evtBradycardia;

  /// No description provided for @evtPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get evtPause;

  /// No description provided for @evtLeadOff.
  ///
  /// In en, this message translates to:
  /// **'Lead-Off'**
  String get evtLeadOff;

  /// No description provided for @evtContactLoss.
  ///
  /// In en, this message translates to:
  /// **'Contact loss'**
  String get evtContactLoss;

  /// No description provided for @eventCounter.
  ///
  /// In en, this message translates to:
  /// **'Event {index} / {total}'**
  String eventCounter(int index, int total);

  /// No description provided for @prevEvent.
  ///
  /// In en, this message translates to:
  /// **'Previous event'**
  String get prevEvent;

  /// No description provided for @nextEvent.
  ///
  /// In en, this message translates to:
  /// **'Next event'**
  String get nextEvent;

  /// No description provided for @eventListTooltip.
  ///
  /// In en, this message translates to:
  /// **'Event list'**
  String get eventListTooltip;

  /// No description provided for @eventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events ({count})'**
  String eventsTitle(int count);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @rmssdTitle.
  ///
  /// In en, this message translates to:
  /// **'RMSSD'**
  String get rmssdTitle;

  /// No description provided for @rmssdNotComputed.
  ///
  /// In en, this message translates to:
  /// **'Not computed yet'**
  String get rmssdNotComputed;

  /// No description provided for @rmssdNa.
  ///
  /// In en, this message translates to:
  /// **'N.A.'**
  String get rmssdNa;

  /// No description provided for @rmssdResultDetail.
  ///
  /// In en, this message translates to:
  /// **'from {start} · duration {seconds} s · {beats} beats'**
  String rmssdResultDetail(String start, int seconds, int beats);

  /// No description provided for @rmssdTooFewBeats.
  ///
  /// In en, this message translates to:
  /// **'Too few beats in range ({beats}).'**
  String rmssdTooFewBeats(int beats);

  /// No description provided for @rmssdWindowLength.
  ///
  /// In en, this message translates to:
  /// **'Window length'**
  String get rmssdWindowLength;

  /// No description provided for @rmssdCreateHere.
  ///
  /// In en, this message translates to:
  /// **'Create RMSSD here (from {start})'**
  String rmssdCreateHere(String start);

  /// No description provided for @rmssdNotEnoughAfter.
  ///
  /// In en, this message translates to:
  /// **'Not enough recording after the current position ({seconds} s needed).'**
  String rmssdNotEnoughAfter(int seconds);

  /// No description provided for @rmssdCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get rmssdCustomRange;

  /// No description provided for @rmssdStartTime.
  ///
  /// In en, this message translates to:
  /// **'Start time (from beginning)'**
  String get rmssdStartTime;

  /// No description provided for @rmssdComputeRange.
  ///
  /// In en, this message translates to:
  /// **'Compute for this range'**
  String get rmssdComputeRange;

  /// No description provided for @rmssdOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Range is outside the recording (total {total}).'**
  String rmssdOutOfRange(String total);

  /// No description provided for @skippedPackets.
  ///
  /// In en, this message translates to:
  /// **'{count} faulty packets skipped'**
  String skippedPackets(int count);

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @personDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete person?'**
  String get personDeleteTitle;

  /// No description provided for @personDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'{name} and all associated data will be removed.'**
  String personDeleteBody(String name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @personsTitle.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get personsTitle;

  /// No description provided for @personsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No people created yet.\nTap + to create a new person.'**
  String get personsEmpty;

  /// No description provided for @newPerson.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get newPerson;

  /// No description provided for @noRecordings.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet.'**
  String get noRecordings;

  /// No description provided for @editPerson.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get editPerson;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get fieldName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name required'**
  String get nameRequired;

  /// No description provided for @fieldAge.
  ///
  /// In en, this message translates to:
  /// **'Age *'**
  String get fieldAge;

  /// No description provided for @yearsSuffix.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get yearsSuffix;

  /// No description provided for @validAge.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid age'**
  String get validAge;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get fieldNotes;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. diagnosis, medication …'**
  String get notesHint;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @permTitle.
  ///
  /// In en, this message translates to:
  /// **'BSMS ECG Monitor'**
  String get permTitle;

  /// No description provided for @permIntro.
  ///
  /// In en, this message translates to:
  /// **'The following permissions are required to operate:'**
  String get permIntro;

  /// No description provided for @permBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth'**
  String get permBluetooth;

  /// No description provided for @permBluetoothDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect to the EKG-Holter via BLE and receive measurement data.'**
  String get permBluetoothDesc;

  /// No description provided for @permLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get permLocation;

  /// No description provided for @permLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Required for BLE scanning on Android ≤ 11.'**
  String get permLocationDesc;

  /// No description provided for @permStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get permStorage;

  /// No description provided for @permStorageDesc.
  ///
  /// In en, this message translates to:
  /// **'Import SD-card files on older Android versions.'**
  String get permStorageDesc;

  /// No description provided for @permPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'A permission was permanently denied. Please allow access in the app settings.'**
  String get permPermanentlyDenied;

  /// No description provided for @permOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permOpenSettings;

  /// No description provided for @permGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant permissions'**
  String get permGrant;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fi', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fi':
      return AppLocalizationsFi();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
