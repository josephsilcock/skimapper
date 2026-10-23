import 'package:flutter_test/flutter_test.dart';
import 'package:skimapper/main.dart';

import 'map/fake_native_map.dart';
import 'support/run_record_capture.dart';

void main() {
  testWidgets('the app logs its launch once, stamped in UTC to the ms', (
    tester,
  ) async {
    FakeNativeMap(tester);

    final logged = await runRecordDuring(() async {
      await tester.pumpWidget(const SkimapperApp());
      await tester.pumpWidget(const SkimapperApp());
    });

    expect(logged.where((line) => line.contains('app launch')), [
      matches(appRunRecordLine('app launch')),
    ]);
  });
}
