
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livestock_toxic_plant_detection/main.dart';

void main() {
  testWidgets('Home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ToxicPlantApp(),
      ),
    );

    // Verify that the title is loaded
    expect(find.text('AgriGuard'), findsWidgets);
    expect(find.text('Common toxic plants'), findsWidgets);
  });
}
