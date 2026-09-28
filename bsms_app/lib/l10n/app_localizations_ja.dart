// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get navLive => 'ライブ心電図';

  @override
  String get navHistory => '履歴';

  @override
  String get navPersons => '人物';

  @override
  String get liveEcgTitle => 'ライブ心電図';

  @override
  String get bleDisconnectTooltip => 'BLEを切断';

  @override
  String get bleConnectTooltip => 'BLEに接続';

  @override
  String get espStart => '計測を開始';

  @override
  String get espStandby => 'スタンバイ';

  @override
  String get waitingForData => 'データを待機中 …';

  @override
  String get noBleDevice => 'BLEデバイスが未接続です';

  @override
  String get statusNotConnected => '未接続';

  @override
  String get statusConnected => '接続済み';

  @override
  String get statusConnectionLost => '接続が切断されました';

  @override
  String get statusSearching => 'デバイスを検索中 …';

  @override
  String get statusDisconnected => '切断';

  @override
  String get recordStart => '記録を開始';

  @override
  String get recordStop => '記録を停止';

  @override
  String bpm(int value) {
    return '$value bpm';
  }

  @override
  String hrv(int value) {
    return 'HRV $value ms';
  }

  @override
  String get leadOffTitle => '電極が外れました！';

  @override
  String get leadOffDetailBoth => '両方の電極が接触していません';

  @override
  String leadOffDetailOne(String lead) {
    return '電極 $lead が接触していません';
  }

  @override
  String leadOffHint(String detail) {
    return '$detail – 接触を確認してください。';
  }

  @override
  String get personPickTitle => '人物を選択';

  @override
  String get personNoneYet => '人物がまだいません — 先に作成してください。';

  @override
  String get personCreateNew => '新しい人物を作成';

  @override
  String personAge(int age) {
    return '$age 歳';
  }

  @override
  String get historyTitle => '記録';

  @override
  String get tabSdImport => 'SDインポート';

  @override
  String get tabBleRecordings => 'BLE記録';

  @override
  String get sdEmpty => 'SDインポートはまだありません。\n＋をタップしてファイルを読み込みます。';

  @override
  String get bleEmpty => 'BLE記録はまだありません。\nライブタブで記録を開始してください。';

  @override
  String get importFile => 'ファイルをインポート';

  @override
  String importedSummary(int samples, int skipped) {
    return 'インポート完了：$samples サンプル（不正パケット $skipped 件をスキップ）';
  }

  @override
  String get removeTooltip => '削除';

  @override
  String get importError => 'ファイルが破損しているか、形式が不明です。';

  @override
  String get tileOptionsTooltip => 'オプション';

  @override
  String get exportCsv => 'エクスポート (CSV)';

  @override
  String get deleteAction => '削除';

  @override
  String get exportInProgress => 'CSVを作成中…';

  @override
  String exportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String sessionSubtitle(String duration, int samples) {
    return '$duration · $samples サンプル';
  }

  @override
  String get axisTime => '時間';

  @override
  String get axisAdc => 'ADC';

  @override
  String get axisHr => '心拍数 (bpm)';

  @override
  String sessionHeaderSub(int samples, String duration) {
    return '$samples サンプル · $duration';
  }

  @override
  String get tooltipRPeaksShow => 'R波を表示';

  @override
  String get tooltipRPeaksHide => 'R波を非表示';

  @override
  String get tooltipHrShow => '心拍数を表示';

  @override
  String get tooltipHrHide => '心拍数を非表示';

  @override
  String get tooltipLeadOffShow => '電極外れを表示';

  @override
  String get tooltipLeadOffHide => '電極外れを非表示';

  @override
  String get tooltipDisconnectShow => '切断を表示';

  @override
  String get tooltipDisconnectHide => '切断を非表示';

  @override
  String get tooltipShowRaw => '生データを表示';

  @override
  String get tooltipShowFiltered => 'フィルタ済みを表示';

  @override
  String get statAvgHr => '平均心拍';

  @override
  String get statSdnn => 'SDNN';

  @override
  String get statRmssd => 'RMSSD';

  @override
  String get rmssdOpen => '開く ›';

  @override
  String get statTachy => '頻脈';

  @override
  String get statBrady => '徐脈';

  @override
  String get statPauses => '停止';

  @override
  String get statLeadOff => '電極外れ';

  @override
  String get statDisconnects => '切断';

  @override
  String get evtTachycardia => '頻脈';

  @override
  String get evtBradycardia => '徐脈';

  @override
  String get evtPause => '停止';

  @override
  String get evtLeadOff => '電極外れ';

  @override
  String get evtContactLoss => '接触喪失';

  @override
  String eventCounter(int index, int total) {
    return 'イベント $index / $total';
  }

  @override
  String get prevEvent => '前のイベント';

  @override
  String get nextEvent => '次のイベント';

  @override
  String get eventListTooltip => 'イベント一覧';

  @override
  String eventsTitle(int count) {
    return 'イベント（$count）';
  }

  @override
  String get close => '閉じる';

  @override
  String get rmssdTitle => 'RMSSD';

  @override
  String get rmssdNotComputed => '未計算';

  @override
  String get rmssdNa => '計測不可';

  @override
  String rmssdResultDetail(String start, int seconds, int beats) {
    return '$start から · 長さ $seconds 秒 · $beats 拍';
  }

  @override
  String rmssdTooFewBeats(int beats) {
    return '範囲内の拍が少なすぎます（$beats）。';
  }

  @override
  String get rmssdWindowLength => 'ウィンドウ長';

  @override
  String rmssdCreateHere(String start) {
    return 'ここでRMSSDを作成（$start から）';
  }

  @override
  String rmssdNotEnoughAfter(int seconds) {
    return '現在位置の後の記録が不足しています（$seconds 秒必要）。';
  }

  @override
  String get rmssdCustomRange => 'カスタム範囲';

  @override
  String get rmssdStartTime => '開始時刻（先頭から）';

  @override
  String get rmssdComputeRange => 'この範囲で計算';

  @override
  String rmssdOutOfRange(String total) {
    return '範囲が記録外です（全体 $total）。';
  }

  @override
  String skippedPackets(int count) {
    return '不正パケット $count 件をスキップ';
  }

  @override
  String get zoomIn => '拡大';

  @override
  String get zoomOut => '縮小';

  @override
  String get personDeleteTitle => '人物を削除しますか？';

  @override
  String personDeleteBody(String name) {
    return '$name と関連するすべてのデータが削除されます。';
  }

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get personsTitle => '人物';

  @override
  String get personsEmpty => '人物がまだ作成されていません。\n＋をタップして新しい人物を作成します。';

  @override
  String get newPerson => '新しい人物';

  @override
  String get noRecordings => '記録はまだありません。';

  @override
  String get editPerson => '人物を編集';

  @override
  String get fieldName => '名前 *';

  @override
  String get nameRequired => '名前は必須です';

  @override
  String get fieldAge => '年齢 *';

  @override
  String get yearsSuffix => '歳';

  @override
  String get validAge => '有効な年齢を入力してください';

  @override
  String get fieldNotes => 'メモ（任意）';

  @override
  String get notesHint => '例：診断、服薬 …';

  @override
  String get create => '作成';

  @override
  String get save => '保存';

  @override
  String get permTitle => 'BSMS 心電図モニター';

  @override
  String get permIntro => '動作には以下の権限が必要です：';

  @override
  String get permBluetooth => 'Bluetooth';

  @override
  String get permBluetoothDesc => 'BLEでEKG-Holterに接続し、測定データを受信します。';

  @override
  String get permLocation => '位置情報';

  @override
  String get permLocationDesc => 'Android 11 以下でのBLEスキャンに必須です。';

  @override
  String get permStorage => 'ストレージ';

  @override
  String get permStorageDesc => '古いAndroidでSDカードのファイルをインポートします。';

  @override
  String get permPermanentlyDenied => '権限が完全に拒否されました。アプリの設定でアクセスを許可してください。';

  @override
  String get permOpenSettings => '設定を開く';

  @override
  String get permGrant => '権限を許可';
}
