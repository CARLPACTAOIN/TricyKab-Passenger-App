import 'package:flutter/material.dart';

import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'data/passenger_repository.dart';
import 'features/book/screens/book_ride_screen.dart';
import 'features/auth/screens/otp_login_screen.dart';
import 'features/history/screens/my_trips_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/trip/screens/active_trip_screen.dart';
import 'features/trip/screens/receipt_screen.dart';

const String kBuildTimeApiBase = String.fromEnvironment('TRICYKAB_API_BASE', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  if (settings.apiBase.isEmpty && kBuildTimeApiBase.isNotEmpty) {
    await settings.setApiBase(kBuildTimeApiBase);
  }
  runApp(TricyKabPassengerApp(settings: settings));
}

class TricyKabPassengerApp extends StatefulWidget {
  const TricyKabPassengerApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<TricyKabPassengerApp> createState() => _TricyKabPassengerAppState();
}

class _TricyKabPassengerAppState extends State<TricyKabPassengerApp> {
  late PassengerRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = PassengerRepository(settings: widget.settings);
  }

  void _onSettingsSaved() {
    setState(() {
      _repo = PassengerRepository(settings: widget.settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TricyKab Passenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: _initialRoute(),
      routes: {
        '/login': (_) => OtpLoginScreen(repo: _repo, settings: widget.settings),
        '/book': (_) => BookRideScreen(repo: _repo, settings: widget.settings),
        '/trips': (_) => MyTripsScreen(repo: _repo, settings: widget.settings),
        '/profile': (_) => ProfileScreen(repo: _repo, settings: widget.settings),
        '/settings': (_) => SettingsScreen(settings: widget.settings, onSaved: _onSettingsSaved),
      },
      onGenerateRoute: (route) {
        if (route.name == '/active') {
          final args = route.arguments;
          final bookingId = args is int ? args : 0;
          return MaterialPageRoute(builder: (_) => ActiveTripScreen(repo: _repo, bookingId: bookingId));
        }
        if (route.name == '/receipt') {
          final args = route.arguments;
          final bookingId = args is int ? args : 0;
          return MaterialPageRoute(builder: (_) => ReceiptScreen(repo: _repo, bookingId: bookingId));
        }
        return null;
      },
    );
  }

  String _initialRoute() {
    if (widget.settings.apiBase.isEmpty) return '/settings';
    if ((widget.settings.accessToken ?? '').isEmpty) return '/login';
    return '/book';
  }
}
