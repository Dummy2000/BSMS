import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

/// Convenience accessor: `context.l10n.someKey`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
