# macOS 向け ECG アプリ — コード・設定ファイル一覧

プロジェクト内の macOS 固有ファイルはすべて以下のパスに格納されています。

```
BSMS-main-2/bsms_app/macos/
```

---

## ファイル構成

```
macos/
├── Podfile                        ← CocoaPods 依存関係定義
├── Podfile.lock                   ← 依存バージョン固定
├── Flutter/
│   ├── Flutter-Debug.xcconfig
│   ├── Flutter-Release.xcconfig
│   └── GeneratedPluginRegistrant.swift
├── Runner.xcodeproj/              ← Xcode プロジェクト設定
├── Runner.xcworkspace/            ← Xcode ワークスペース（CocoaPods 込み）
└── Runner/
    ├── Info.plist                 ← Bluetooth 権限説明文 ★
    ├── DebugProfile.entitlements  ← デバッグ時の権限設定 ★
    ├── Release.entitlements       ← リリース時の権限設定 ★
    ├── AppDelegate.swift          ← アプリ起動エントリポイント
    ├── MainFlutterWindow.swift    ← Flutter ウィンドウ初期化
    ├── Assets.xcassets/           ← アプリアイコン
    ├── Base.lproj/MainMenu.xib    ← メニューバー定義
    └── Configs/
        ├── AppInfo.xcconfig       ← Bundle ID・アプリ名 ★
        ├── Debug.xcconfig
        ├── Release.xcconfig
        └── Warnings.xcconfig
```

---

## 重要ファイルの内容

### 1. Info.plist — Bluetooth 権限説明文

**パス:** `macos/Runner/Info.plist`

Bluetooth を使用するために macOS が要求する権限説明文を追加しています。
この文字列はシステムのダイアログに表示されます。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(FLUTTER_BUILD_NAME)</string>
    <key>CFBundleVersion</key>
    <string>$(FLUTTER_BUILD_NUMBER)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>NSHumanReadableCopyright</key>
    <string>$(PRODUCT_COPYRIGHT)</string>
    <key>NSMainNibFile</key>
    <string>MainMenu</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>

    <!-- ★ Bluetooth 権限（今回追加） -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>This app needs Bluetooth access to connect to ECG monitoring devices.</string>
</dict>
</plist>
```

---

### 2. DebugProfile.entitlements — デバッグ用権限

**パス:** `macos/Runner/DebugProfile.entitlements`

macOS の App Sandbox 内で Bluetooth を使うための権限設定です。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>

    <!-- ★ Bluetooth 権限 -->
    <key>com.apple.security.device.bluetooth</key>
    <true/>
</dict>
</plist>
```

---

### 3. Release.entitlements — リリース用権限

**パス:** `macos/Runner/Release.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- ★ Bluetooth 権限 -->
    <key>com.apple.security.device.bluetooth</key>
    <true/>
</dict>
</plist>
```

---

### 4. AppDelegate.swift — アプリ起動エントリポイント

**パス:** `macos/Runner/AppDelegate.swift`

Flutter の macOS テンプレートそのままです。最後のウィンドウを閉じたときにアプリを終了します。

```swift
import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(
        _ app: NSApplication
    ) -> Bool {
        return true
    }
}
```

---

### 5. MainFlutterWindow.swift — Flutter ウィンドウ初期化

**パス:** `macos/Runner/MainFlutterWindow.swift`

Flutter の ViewController を macOS ウィンドウに埋め込み、プラグインを登録します。

```swift
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)

        super.awakeFromNib()
    }
}
```

---

### 6. Configs/AppInfo.xcconfig — アプリ基本情報

**パス:** `macos/Runner/Configs/AppInfo.xcconfig`

Bundle ID やアプリ名を変更する場合はここを編集します。

```
PRODUCT_NAME = bsms_app
PRODUCT_BUNDLE_IDENTIFIER = com.example.bsmsApp
PRODUCT_COPYRIGHT = Copyright © 2026 com.example. All rights reserved.
```

---

### 7. Podfile — CocoaPods 依存関係

**パス:** `macos/Podfile`

macOS の BLE プラグイン（`reactive_ble_mobile`）と SharedPreferences を CocoaPods で管理します。

```ruby
platform :osx, '10.15'

ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug'   => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(
    File.join('..', 'Flutter', 'ephemeral', 'Flutter-Generated.xcconfig'), __FILE__
  )
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. " \
          "Run 'flutter pub get' first."
  end
  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found. Try deleting Flutter-Generated.xcconfig, " \
        "then run 'flutter pub get'."
end

require File.expand_path(
  File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root
)

flutter_macos_podfile_setup

target 'Runner' do
  use_frameworks!
  flutter_install_all_macos_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_macos_build_settings(target)
  end
end
```

---

### 8. Podfile.lock — 依存バージョン固定

**パス:** `macos/Podfile.lock`

使用している CocoaPods パッケージのバージョン：

| パッケージ | バージョン |
|---|---|
| FlutterMacOS | 1.0.0 |
| reactive_ble_mobile | 0.0.1 |
| shared_preferences_foundation | 0.0.1 |
| Protobuf | 3.29.6 |
| SwiftProtobuf | 1.38.0 |

---

## macOS ビルド手順

```bash
# 1. プロジェクトディレクトリへ移動
cd BSMS-main-2/bsms_app

# 2. 依存関係インストール
flutter pub get

# 3. CocoaPods インストール（初回 or Podfile 変更後）
cd macos && pod install && cd ..

# 4. macOS アプリとして実行
flutter run -d macos

# 5. リリースビルド
flutter build macos
# → build/macos/Build/Products/Release/bsms_app.app
```

---

## macOS 固有の設定ポイント（今回追加・確認した内容）

| 設定 | ファイル | 内容 |
|---|---|---|
| Bluetooth 権限説明文 | `Info.plist` | `NSBluetoothAlwaysUsageDescription` を追加 |
| Sandbox 内 BLE 権限 | `DebugProfile.entitlements` | `com.apple.security.device.bluetooth = true` を追加 |
| Sandbox 内 BLE 権限 | `Release.entitlements` | `com.apple.security.device.bluetooth = true` を追加 |
| 最低 macOS バージョン | `Podfile` | `platform :osx, '10.15'`（Catalina 以降） |

> **注意:** macOS では App Sandbox が有効なため、Entitlements に Bluetooth 権限を明示しないと BLE スキャンが動作しません。iOS と違い Info.plist だけでは不十分です。
