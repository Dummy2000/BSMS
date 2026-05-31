import 'package:flutter/foundation.dart';

/// Global flag for the hidden "retro pixel mode" (unlocked via the Konami code).
///
/// Lives above the widget tree so the [MaterialApp] theme can react to it while
/// the Konami detector (below the MaterialApp) sets it. Intentionally NOT
/// persisted — it resets to `false` on every app restart.
final ValueNotifier<bool> pixelModeEnabled = ValueNotifier<bool>(false);
