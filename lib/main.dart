import 'package:flutter/material.dart';

import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';
import 'data/passenger_bookings_scope.dart';
import 'data/passenger_bookings_store.dart';
import 'data/passenger_repository.dart';
import 'features/book/screens/book_ride_screen.dart';
import 'features/auth/screens/otp_login_screen.dart';
import 'features/history/screens/my_trips_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/trip/screens/active_trip_screen.dart';
import 'features/trip/screens/receipt_screen.dart';

/// Fixed API base for the pilot tunnel.
const String kApiBase = 'https://satisfactory-flo-inarguably.ngrok-free.dev/api/v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
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
  late PassengerBookingsStore _bookingsStore;

  @override
  void initState() {
    super.initState();
    _repo = PassengerRepository(settings: widget.settings, apiBase: kApiBase);
    _bookingsStore = PassengerBookingsStore(repo: _repo, settings: widget.settings);
  }

  @override
  void dispose() {
    _bookingsStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PassengerBookingsScope(
      store: _bookingsStore,
      child: MaterialApp(
      title: 'TricyKab Passenger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: _initialRoute(),
      onGenerateRoute: (route) {
        Widget? page;
        if (route.name == '/login') {
          page = OtpLoginScreen(repo: _repo, settings: widget.settings);
        } else if (route.name == '/book') {
          page = BookRideScreen(repo: _repo, settings: widget.settings);
        } else if (route.name == '/trips') {
          page = const MyTripsScreen();
        } else if (route.name == '/profile') {
          page = ProfileScreen(repo: _repo, settings: widget.settings);
        } else if (route.name == '/active') {
          final args = route.arguments;
          final bookingId = args is int ? args : 0;
          page = ActiveTripScreen(repo: _repo, bookingId: bookingId);
        } else if (route.name == '/receipt') {
          final args = route.arguments;
          final bookingId = args is int ? args : 0;
          page = ReceiptScreen(repo: _repo, bookingId: bookingId);
        }

        if (page == null) return null;

        final args = route.arguments;
        final fromTab = (args is Map) ? (args['fromTab'] as int?) : null;
        final toTab = (args is Map) ? (args['toTab'] as int?) : null;

        // Tab-to-tab navigation: slide left when moving forward (e.g. Home->Trips),
        // slide right when moving backward (e.g. Profile->Trips).
        if (fromTab != null && toTab != null && fromTab != toTab) {
          final begin = toTab > fromTab ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
          return PageRouteBuilder(
            settings: route,
            pageBuilder: (context, animation, secondaryAnimation) => page!,
            transitionDuration: const Duration(milliseconds: 260),
            reverseTransitionDuration: const Duration(milliseconds: 220),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
              return SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
                child: child,
              );
            },
          );
        }

        // Default navigation (booking->active, etc.)
        return MaterialPageRoute(builder: (_) => page!, settings: route);
      },
      ),
    );
  }

  String _initialRoute() {
    if ((widget.settings.accessToken ?? '').isEmpty) return '/login';
    return '/book';
  }
}
