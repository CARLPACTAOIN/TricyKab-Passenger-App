import 'package:flutter_test/flutter_test.dart';
import 'package:passenger_app/core/settings/app_settings.dart';
import 'package:passenger_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('passenger app boots into settings when no API base set',
      (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    await tester.pumpWidget(TricyKabPassengerApp(settings: settings));
    await tester.pump();
    // AppBar still uses the literal title 'Settings' so the design refresh
    // doesn't break the boot smoke test.
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('login screen shows TricyKab brand block when API base is configured',
      (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'tricykab_api_base': 'http://10.0.2.2:8000/api/v1',
    });
    final settings = await AppSettings.load();
    await tester.pumpWidget(TricyKabPassengerApp(settings: settings));
    await tester.pump();
    expect(find.text('TricyKab'), findsWidgets);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
