// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navLive => 'ECG en vivo';

  @override
  String get navHistory => 'Historial';

  @override
  String get navPersons => 'Personas';

  @override
  String get liveEcgTitle => 'ECG en vivo';

  @override
  String get bleDisconnectTooltip => 'Desconectar BLE';

  @override
  String get bleConnectTooltip => 'Conectar BLE';

  @override
  String get espStart => 'Iniciar medición';

  @override
  String get espStandby => 'Reposo';

  @override
  String get waitingForData => 'Esperando datos …';

  @override
  String get noBleDevice => 'Ningún dispositivo BLE conectado';

  @override
  String get statusNotConnected => 'No conectado';

  @override
  String get statusConnected => 'Conectado';

  @override
  String get statusConnectionLost => 'Conexión perdida';

  @override
  String get statusSearching => 'Buscando dispositivo …';

  @override
  String get statusDisconnected => 'Desconectado';

  @override
  String get recordStart => 'Iniciar grabación';

  @override
  String get recordStop => 'Detener grabación';

  @override
  String bpm(int value) {
    return '$value ppm';
  }

  @override
  String hrv(int value) {
    return 'VFC $value ms';
  }

  @override
  String get leadOffTitle => '¡Electrodo desconectado!';

  @override
  String get leadOffDetailBoth => 'Ambos electrodos sin contacto';

  @override
  String leadOffDetailOne(String lead) {
    return 'Electrodo $lead sin contacto';
  }

  @override
  String leadOffHint(String detail) {
    return '$detail – comprueba el contacto.';
  }

  @override
  String get personPickTitle => 'Seleccionar persona';

  @override
  String get personNoneYet => 'Aún no hay personas — crea una primero.';

  @override
  String get personCreateNew => 'Crear nueva persona';

  @override
  String personAge(int age) {
    return '$age años';
  }

  @override
  String get historyTitle => 'Grabaciones';

  @override
  String get tabSdImport => 'Importar SD';

  @override
  String get tabBleRecordings => 'Grabaciones BLE';

  @override
  String get sdEmpty =>
      'Aún no hay importaciones SD.\nToca + para cargar un archivo.';

  @override
  String get bleEmpty =>
      'Aún no hay grabaciones BLE.\nInicia una grabación en la pestaña En vivo.';

  @override
  String get importFile => 'Importar archivo';

  @override
  String importedSummary(int samples, int skipped) {
    return 'Importado: $samples muestras ($skipped paquetes erróneos omitidos)';
  }

  @override
  String get removeTooltip => 'Eliminar';

  @override
  String get importError =>
      'El archivo está dañado o tiene un formato desconocido.';

  @override
  String sessionSubtitle(String duration, int samples) {
    return '$duration · $samples muestras';
  }

  @override
  String get axisTime => 'Tiempo';

  @override
  String get axisAdc => 'ADC';

  @override
  String get axisHr => 'FC (ppm)';

  @override
  String sessionHeaderSub(int samples, String duration) {
    return '$samples muestras · $duration';
  }

  @override
  String get tooltipRPeaksShow => 'Mostrar picos R';

  @override
  String get tooltipRPeaksHide => 'Ocultar picos R';

  @override
  String get tooltipHrShow => 'Mostrar FC';

  @override
  String get tooltipHrHide => 'Ocultar FC';

  @override
  String get tooltipLeadOffShow => 'Mostrar lead-off';

  @override
  String get tooltipLeadOffHide => 'Ocultar lead-off';

  @override
  String get tooltipDisconnectShow => 'Mostrar cortes';

  @override
  String get tooltipDisconnectHide => 'Ocultar cortes';

  @override
  String get tooltipShowRaw => 'Mostrar sin filtrar';

  @override
  String get tooltipShowFiltered => 'Mostrar filtrado';

  @override
  String get statAvgHr => 'FC med.';

  @override
  String get statSdnn => 'SDNN';

  @override
  String get statRmssd => 'RMSSD';

  @override
  String get rmssdOpen => 'abrir ›';

  @override
  String get statTachy => 'Taqui';

  @override
  String get statBrady => 'Bradi';

  @override
  String get statPauses => 'Pausas';

  @override
  String get statLeadOff => 'Lead-Off';

  @override
  String get statDisconnects => 'Cortes';

  @override
  String get evtTachycardia => 'Taquicardia';

  @override
  String get evtBradycardia => 'Bradicardia';

  @override
  String get evtPause => 'Pausa';

  @override
  String get evtLeadOff => 'Lead-Off';

  @override
  String get evtContactLoss => 'Pérdida de contacto';

  @override
  String eventCounter(int index, int total) {
    return 'Evento $index / $total';
  }

  @override
  String get prevEvent => 'Evento anterior';

  @override
  String get nextEvent => 'Evento siguiente';

  @override
  String get eventListTooltip => 'Lista de eventos';

  @override
  String eventsTitle(int count) {
    return 'Eventos ($count)';
  }

  @override
  String get close => 'Cerrar';

  @override
  String get rmssdTitle => 'RMSSD';

  @override
  String get rmssdNotComputed => 'Aún no calculado';

  @override
  String get rmssdNa => 'N.D.';

  @override
  String rmssdResultDetail(String start, int seconds, int beats) {
    return 'desde $start · duración $seconds s · $beats latidos';
  }

  @override
  String rmssdTooFewBeats(int beats) {
    return 'Muy pocos latidos en el rango ($beats).';
  }

  @override
  String get rmssdWindowLength => 'Longitud de ventana';

  @override
  String rmssdCreateHere(String start) {
    return 'Crear RMSSD aquí (desde $start)';
  }

  @override
  String rmssdNotEnoughAfter(int seconds) {
    return 'No hay suficiente grabación tras la posición actual (se necesitan $seconds s).';
  }

  @override
  String get rmssdCustomRange => 'Rango personalizado';

  @override
  String get rmssdStartTime => 'Hora de inicio (desde el comienzo)';

  @override
  String get rmssdComputeRange => 'Calcular para este rango';

  @override
  String rmssdOutOfRange(String total) {
    return 'El rango está fuera de la grabación (total $total).';
  }

  @override
  String skippedPackets(int count) {
    return '$count paquetes erróneos omitidos';
  }

  @override
  String get zoomIn => 'Acercar';

  @override
  String get zoomOut => 'Alejar';

  @override
  String get personDeleteTitle => '¿Eliminar persona?';

  @override
  String personDeleteBody(String name) {
    return '$name y todos los datos asociados se eliminarán.';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get delete => 'Eliminar';

  @override
  String get personsTitle => 'Personas';

  @override
  String get personsEmpty =>
      'Aún no hay personas creadas.\nToca + para crear una nueva persona.';

  @override
  String get newPerson => 'Nueva persona';

  @override
  String get noRecordings => 'Aún no hay grabaciones.';

  @override
  String get editPerson => 'Editar persona';

  @override
  String get fieldName => 'Nombre *';

  @override
  String get nameRequired => 'Nombre obligatorio';

  @override
  String get fieldAge => 'Edad *';

  @override
  String get yearsSuffix => 'años';

  @override
  String get validAge => 'Introduce una edad válida';

  @override
  String get fieldNotes => 'Notas (opcional)';

  @override
  String get notesHint => 'p. ej. diagnóstico, medicación …';

  @override
  String get create => 'Crear';

  @override
  String get save => 'Guardar';

  @override
  String get permTitle => 'Monitor ECG BSMS';

  @override
  String get permIntro =>
      'Para funcionar se necesitan los siguientes permisos:';

  @override
  String get permBluetooth => 'Bluetooth';

  @override
  String get permBluetoothDesc =>
      'Conectar con el EKG-Holter por BLE y recibir datos de medición.';

  @override
  String get permLocation => 'Ubicación';

  @override
  String get permLocationDesc =>
      'Obligatorio para el escaneo BLE en Android ≤ 11.';

  @override
  String get permStorage => 'Almacenamiento';

  @override
  String get permStorageDesc =>
      'Importar archivos de tarjeta SD en versiones antiguas de Android.';

  @override
  String get permPermanentlyDenied =>
      'Un permiso fue denegado permanentemente. Permite el acceso en los ajustes de la app.';

  @override
  String get permOpenSettings => 'Abrir ajustes';

  @override
  String get permGrant => 'Conceder permisos';
}
