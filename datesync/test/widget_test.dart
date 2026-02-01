import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:datesync/state/app_state.dart';
import 'package:datesync/app/app.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // shared_preferences mock (yoksa load patlar)
    SharedPreferences.setMockInitialValues({});

    final appState = AppState();
    await appState.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const DateSyncApp(),
      ),
    );

    await tester.pump();
    expect(find.text('DateSync'), findsWidgets);
  });
}
