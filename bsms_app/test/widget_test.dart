// Smoke test: the app builds and resolves localizations for each supported
// locale, showing the localized bottom-navigation labels.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bsms_app/l10n/app_localizations.dart';

void main() {
  testWidgets('localized nav labels resolve per locale', (tester) async {
    Future<void> pumpFor(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final l = AppLocalizations.of(context);
            return Text('${l.navLive}|${l.navHistory}|${l.navPersons}');
          },
        ),
      ));
      await tester.pumpAndSettle();
    }

    await pumpFor(const Locale('en'));
    expect(find.text('Live ECG|History|People'), findsOneWidget);

    await pumpFor(const Locale('de'));
    expect(find.text('Live EKG|Verlauf|Personen'), findsOneWidget);

    await pumpFor(const Locale('ja'));
    expect(find.text('ライブ心電図|履歴|人物'), findsOneWidget);
  });

  test('all five locales are supported', () {
    final codes =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(['en', 'de', 'es', 'fi', 'ja']));
  });
}
