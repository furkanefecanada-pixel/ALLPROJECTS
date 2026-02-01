import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:auraglowup/main.dart';
import 'package:auraglowup/app_controller.dart';
import 'package:auraglowup/auralevelmanager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App opens', (WidgetTester tester) async {
    // ✅ SharedPreferences mock
    SharedPreferences.setMockInitialValues({});

    final controller = await AppController.bootstrap();
    final aura = await AuraLevelManager.bootstrap();
    final coach = await AuraCoachManager.bootstrap();

    await tester.pumpWidget(
      AuraGlowUpApp(controller: controller, aura: aura, coach: coach),
    );
    await tester.pumpAndSettle();

    // İlk açılışta dil ekranı gelirse seç
    final hasLangPicker =
        find.text('Choose language').evaluate().isNotEmpty ||
        find.text('Dil seç').evaluate().isNotEmpty;

    if (hasLangPicker) {
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
    }

    // App title topbar’da
    expect(find.text('Aura GlowUp'), findsWidgets);
  });
}
