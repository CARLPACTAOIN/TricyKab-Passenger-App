import 'package:flutter_test/flutter_test.dart';
import 'package:passenger_app/core/settings/app_settings.dart';
import 'package:passenger_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('passenger app boots into Login when no token set', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    await tester.pumpWidget(TricyKabPassengerApp(settings: settings));
    await tester.pump();
    expect(find.text('TricyKab'), findsWidgets);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('login screen shows TricyKab brand block', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final settings = await AppSettings.load();
    await tester.pumpWidget(TricyKabPassengerApp(settings: settings));
    await tester.pump();
    expect(find.text('TricyKab'), findsWidgets);
    expect(find.text('Sign in to your account'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });
}
