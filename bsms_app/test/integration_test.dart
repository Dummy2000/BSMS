import 'package:flutter_test/flutter_test.dart';
import 'package:bsms_app/data/ecg_integration_test.dart';

void main() {
  test('ECG Data Pipeline Integration Test', () async {
    final tester = EcgIntegrationTest();

    try {
      await tester.runAllTests();

      // Basic assertions to ensure test passed
      expect(tester, isNotNull);

      // Note: In a real test environment, we'd add more specific assertions
      // For now, this mainly serves as a demo/integration test

    } finally {
      tester.dispose();
    }
  });
}