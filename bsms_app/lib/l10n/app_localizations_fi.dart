// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Finnish (`fi`).
class AppLocalizationsFi extends AppLocalizations {
  AppLocalizationsFi([String locale = 'fi']) : super(locale);

  @override
  String get navLive => 'Live-EKG';

  @override
  String get navHistory => 'Historia';

  @override
  String get navPersons => 'Henkilöt';

  @override
  String get liveEcgTitle => 'Live-EKG';

  @override
  String get bleDisconnectTooltip => 'Katkaise BLE';

  @override
  String get bleConnectTooltip => 'Yhdistä BLE';

  @override
  String get espStart => 'Aloita mittaus';

  @override
  String get espStandby => 'Valmiustila';

  @override
  String get waitingForData => 'Odotetaan dataa …';

  @override
  String get noBleDevice => 'Ei BLE-laitetta yhdistettynä';

  @override
  String get statusNotConnected => 'Ei yhteyttä';

  @override
  String get statusConnected => 'Yhdistetty';

  @override
  String get statusConnectionLost => 'Yhteys katkesi';

  @override
  String get statusSearching => 'Etsitään laitetta …';

  @override
  String get statusDisconnected => 'Katkaistu';

  @override
  String get recordStart => 'Aloita tallennus';

  @override
  String get recordStop => 'Lopeta tallennus';

  @override
  String bpm(int value) {
    return '$value lyöntiä/min';
  }

  @override
  String hrv(int value) {
    return 'HRV $value ms';
  }

  @override
  String get leadOffTitle => 'Elektrodi irronnut!';

  @override
  String get leadOffDetailBoth => 'Molemmat elektrodit ilman kontaktia';

  @override
  String leadOffDetailOne(String lead) {
    return 'Elektrodi $lead ilman kontaktia';
  }

  @override
  String leadOffHint(String detail) {
    return '$detail – tarkista kontakti.';
  }

  @override
  String get personPickTitle => 'Valitse henkilö';

  @override
  String get personNoneYet => 'Ei vielä henkilöitä — luo ensin yksi.';

  @override
  String get personCreateNew => 'Luo uusi henkilö';

  @override
  String personAge(int age) {
    return '$age vuotta';
  }

  @override
  String get historyTitle => 'Tallenteet';

  @override
  String get tabSdImport => 'SD-tuonti';

  @override
  String get tabBleRecordings => 'BLE-tallenteet';

  @override
  String get sdEmpty =>
      'Ei vielä SD-tuonteja.\nNapauta + ladataksesi tiedoston.';

  @override
  String get bleEmpty =>
      'Ei vielä BLE-tallenteita.\nAloita tallennus Live-välilehdellä.';

  @override
  String get importFile => 'Tuo tiedosto';

  @override
  String importedSummary(int samples, int skipped) {
    return 'Tuotu: $samples näytettä ($skipped virheellistä pakettia ohitettu)';
  }

  @override
  String get removeTooltip => 'Poista';

  @override
  String get importError =>
      'Tiedosto on vioittunut tai sen muoto on tuntematon.';

  @override
  String get tileOptionsTooltip => 'Valinnat';

  @override
  String get exportCsv => 'Vie (CSV)';

  @override
  String get deleteAction => 'Poista';

  @override
  String get exportInProgress => 'Luodaan CSV-tiedostoa …';

  @override
  String exportFailed(String error) {
    return 'Vienti epäonnistui: $error';
  }

  @override
  String sessionSubtitle(String duration, int samples) {
    return '$duration · $samples näytettä';
  }

  @override
  String get axisTime => 'Aika';

  @override
  String get axisAdc => 'ADC';

  @override
  String get axisHr => 'Syke (l/min)';

  @override
  String sessionHeaderSub(int samples, String duration) {
    return '$samples näytettä · $duration';
  }

  @override
  String get tooltipRPeaksShow => 'Näytä R-piikit';

  @override
  String get tooltipRPeaksHide => 'Piilota R-piikit';

  @override
  String get tooltipHrShow => 'Näytä syke';

  @override
  String get tooltipHrHide => 'Piilota syke';

  @override
  String get tooltipLeadOffShow => 'Näytä irtoamiset';

  @override
  String get tooltipLeadOffHide => 'Piilota irtoamiset';

  @override
  String get tooltipDisconnectShow => 'Näytä katkokset';

  @override
  String get tooltipDisconnectHide => 'Piilota katkokset';

  @override
  String get tooltipShowRaw => 'Näytä raakadata';

  @override
  String get tooltipShowFiltered => 'Näytä suodatettu';

  @override
  String get statAvgHr => 'Ka. syke';

  @override
  String get statSdnn => 'SDNN';

  @override
  String get statRmssd => 'RMSSD';

  @override
  String get rmssdOpen => 'avaa ›';

  @override
  String get statTachy => 'Takykardia';

  @override
  String get statBrady => 'Bradykardia';

  @override
  String get statPauses => 'Tauot';

  @override
  String get statLeadOff => 'Irtoaminen';

  @override
  String get statDisconnects => 'Katkokset';

  @override
  String get evtTachycardia => 'Takykardia';

  @override
  String get evtBradycardia => 'Bradykardia';

  @override
  String get evtPause => 'Tauko';

  @override
  String get evtLeadOff => 'Irtoaminen';

  @override
  String get evtContactLoss => 'Kontaktin menetys';

  @override
  String eventCounter(int index, int total) {
    return 'Tapahtuma $index / $total';
  }

  @override
  String get prevEvent => 'Edellinen tapahtuma';

  @override
  String get nextEvent => 'Seuraava tapahtuma';

  @override
  String get eventListTooltip => 'Tapahtumalista';

  @override
  String eventsTitle(int count) {
    return 'Tapahtumat ($count)';
  }

  @override
  String get close => 'Sulje';

  @override
  String get rmssdTitle => 'RMSSD';

  @override
  String get rmssdNotComputed => 'Ei vielä laskettu';

  @override
  String get rmssdNa => 'Ei saat.';

  @override
  String rmssdResultDetail(String start, int seconds, int beats) {
    return 'alkaen $start · kesto $seconds s · $beats lyöntiä';
  }

  @override
  String rmssdTooFewBeats(int beats) {
    return 'Liian vähän lyöntejä jaksolla ($beats).';
  }

  @override
  String get rmssdWindowLength => 'Ikkunan pituus';

  @override
  String rmssdCreateHere(String start) {
    return 'Luo RMSSD tähän (alkaen $start)';
  }

  @override
  String rmssdNotEnoughAfter(int seconds) {
    return 'Tallennetta ei ole tarpeeksi nykyisen kohdan jälkeen (tarvitaan $seconds s).';
  }

  @override
  String get rmssdCustomRange => 'Mukautettu jakso';

  @override
  String get rmssdStartTime => 'Aloitusaika (alusta)';

  @override
  String get rmssdComputeRange => 'Laske tälle jaksolle';

  @override
  String rmssdOutOfRange(String total) {
    return 'Jakso on tallenteen ulkopuolella (yhteensä $total).';
  }

  @override
  String skippedPackets(int count) {
    return '$count virheellistä pakettia ohitettu';
  }

  @override
  String get zoomIn => 'Lähennä';

  @override
  String get zoomOut => 'Loitonna';

  @override
  String get personDeleteTitle => 'Poistetaanko henkilö?';

  @override
  String personDeleteBody(String name) {
    return '$name ja kaikki siihen liittyvät tiedot poistetaan.';
  }

  @override
  String get cancel => 'Peruuta';

  @override
  String get delete => 'Poista';

  @override
  String get personsTitle => 'Henkilöt';

  @override
  String get personsEmpty =>
      'Ei vielä luotuja henkilöitä.\nNapauta + luodaksesi uuden henkilön.';

  @override
  String get newPerson => 'Uusi henkilö';

  @override
  String get noRecordings => 'Ei vielä tallenteita.';

  @override
  String get editPerson => 'Muokkaa henkilöä';

  @override
  String get fieldName => 'Nimi *';

  @override
  String get nameRequired => 'Nimi vaaditaan';

  @override
  String get fieldAge => 'Ikä *';

  @override
  String get yearsSuffix => 'vuotta';

  @override
  String get validAge => 'Anna kelvollinen ikä';

  @override
  String get fieldNotes => 'Muistiinpanot (valinnainen)';

  @override
  String get notesHint => 'esim. diagnoosi, lääkitys …';

  @override
  String get create => 'Luo';

  @override
  String get save => 'Tallenna';

  @override
  String get permTitle => 'BSMS EKG -monitori';

  @override
  String get permIntro => 'Toimintaan tarvitaan seuraavat luvat:';

  @override
  String get permBluetooth => 'Bluetooth';

  @override
  String get permBluetoothDesc =>
      'Yhteys EKG-Holteriin BLE:n kautta ja mittausdatan vastaanotto.';

  @override
  String get permLocation => 'Sijainti';

  @override
  String get permLocationDesc =>
      'Pakollinen BLE-skannaukseen Android ≤ 11 -versioissa.';

  @override
  String get permStorage => 'Tallennustila';

  @override
  String get permStorageDesc =>
      'SD-korttitiedostojen tuonti vanhemmissa Android-versioissa.';

  @override
  String get permPermanentlyDenied =>
      'Lupa evättiin pysyvästi. Salli käyttö sovelluksen asetuksista.';

  @override
  String get permOpenSettings => 'Avaa asetukset';

  @override
  String get permGrant => 'Myönnä luvat';
}
