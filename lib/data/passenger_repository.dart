import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/settings/app_settings.dart';

/// Talks to TricyKab `/api/v1/*` for the passenger flows.
///
/// Returns parsed maps; callers are expected to handle nulls and shape variance.
class PassengerRepository {
  PassengerRepository({required this.settings, required this.apiBase});

  final AppSettings settings;
  final String apiBase;

  String get _base {
    final raw = apiBase.trim();
    if (raw.isEmpty) {
      throw StateError('API base not configured.');
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  Uri _u(String p) => Uri.parse('$_base${p.startsWith('/') ? p : '/$p'}');

  Map<String, String> _headers({bool jsonBody = false, String? idempotencyKey}) {
    final h = <String, String>{
      'Accept': 'application/json',
      // Avoid ngrok's interstitial "browser warning" page on tunneled traffic.
      'ngrok-skip-browser-warning': 'true',
    };
    if (jsonBody) h['Content-Type'] = 'application/json';
    final token = settings.accessToken;
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    if (idempotencyKey != null) {
      h['Idempotency-Key'] = idempotencyKey;
    }
    return h;
  }

  Future<Map<String, dynamic>> _decode(http.Response r) async {
    final body = r.body.isEmpty ? '{}' : r.body;
    final m = jsonDecode(body);
    return m is Map<String, dynamic> ? m : <String, dynamic>{};
  }

  // ---- Auth ----

  Future<void> requestOtpForPhoneVerification(String phoneNumber) async {
    final r = await http.post(_u('/auth/otp/request'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'phone_number': phoneNumber, 'role_hint': 'PASSENGER'}));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'OTP request failed');
    }
  }

  Future<void> registerPassenger({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    final r = await http.post(_u('/passenger/register'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
        }));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Registration failed');
    }
    await settings.setLastEmail(email);
    await settings.setLastPhone(phoneNumber);
  }

  Future<void> verifyPhone({
    required String email,
    required String phoneNumber,
    required String otpCode,
  }) async {
    final r = await http.post(_u('/passenger/verify-phone'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'email': email,
          'phone_number': phoneNumber,
          'otp_code': otpCode,
        }));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Phone verification failed');
    }
    await settings.setLastEmail(email);
    await settings.setLastPhone(phoneNumber);
  }

  Future<void> loginPassenger({
    required String email,
    required String password,
  }) async {
    final r = await http.post(_u('/passenger/login'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'email': email,
          'password': password,
        }));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Login failed');
    }
    final data = m['data'];
    if (data is Map<String, dynamic>) {
      final access = data['access_token'];
      final refresh = data['refresh_token'];
      if (access is String && access.isNotEmpty) {
        await settings.setAccessToken(access);
      }
      if (refresh is String) {
        await settings.setRefreshToken(refresh);
      }
    }
    await settings.setLastEmail(email);
  }

  // ---- Bookings ----

  Future<Map<String, dynamic>> createBooking({
    required String rideType,
    required Map<String, Object?> pickup,
    required Map<String, Object?> destination,
    required String idempotencyKey,
  }) async {
    final r = await http.post(_u('/bookings'),
        headers: _headers(jsonBody: true, idempotencyKey: idempotencyKey),
        body: jsonEncode({
          'ride_type': rideType,
          'pickup': pickup,
          'destination': destination,
        }));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Could not create booking');
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> cancelBooking(int bookingId, {String reasonCode = 'PASSENGER_REQUEST'}) async {
    final r = await http.post(_u('/bookings/$bookingId/cancel'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'reason_code': reasonCode}));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Cancel failed');
    }
  }

  Future<List<Map<String, dynamic>>> myBookings({bool active = false}) async {
    final qs = active ? '?active=1' : '';
    final r = await http.get(_u('/bookings$qs'), headers: _headers());
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Could not load bookings');
    }
    final data = m['data'];
    final list = data is Map<String, dynamic> ? data['bookings'] : null;
    if (list is List) {
      return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> tripTracking(int bookingId) async {
    final r = await http.get(_u('/bookings/$bookingId/trip-tracking'), headers: _headers());
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Tracking unavailable');
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// `kind`: `pickup` — passenger at pickup (advances booking like driver arrived when applicable); `dropoff` — passenger at destination during trip.
  Future<Map<String, dynamic>> passengerAck(int bookingId, String kind) async {
    final r = await http.post(
      _u('/bookings/$bookingId/passenger-ack'),
      headers: _headers(
        jsonBody: true,
        idempotencyKey: 'passenger-ack-$bookingId-$kind-${DateTime.now().microsecondsSinceEpoch}',
      ),
      body: jsonEncode({'kind': kind}),
    );
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Acknowledgement failed');
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> receipt(int bookingId) async {
    final r = await http.get(_u('/bookings/$bookingId/receipt'), headers: _headers());
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Receipt unavailable');
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<void> submitTripRating(int tripId, int rating) async {
    final r = await http.post(
      _u('/trips/$tripId/rate'),
      headers: _headers(
        jsonBody: true,
        idempotencyKey: 'trip-rate-$tripId',
      ),
      body: jsonEncode({'rating': rating}),
    );
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Failed to submit rating');
    }
  }

  /// PRD §7.19 — file a dispute against a completed/actioned booking.
  ///
  /// [disputeType] must be one of: FARE, NO_SHOW, GPS, CONDUCT, SAFETY, OTHER.
  /// [description] is a mandatory free-text explanation (10–1000 chars).
  Future<void> submitDispute({
    required int bookingId,
    required String disputeType,
    required String description,
  }) async {
    final r = await http.post(
      _u('/bookings/$bookingId/dispute'),
      headers: _headers(
        jsonBody: true,
        idempotencyKey: 'dispute-$bookingId-${DateTime.now().microsecondsSinceEpoch}',
      ),
      body: jsonEncode({'dispute_type': disputeType, 'description': description}),
    );
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Failed to submit dispute');
    }
  }

  Future<void> sos({
    int? bookingId,
    required double latitude,
    required double longitude,
    String? notes,
  }) async {
    final r = await http.post(_u('/passenger/sos'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          if (bookingId != null) 'booking_id': bookingId,
          'latitude': latitude,
          'longitude': longitude,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'SOS failed');
    }
  }

  // ---- Profile ----

  Future<Map<String, dynamic>> myProfile() async {
    final r = await http.get(_u('/passenger/me/profile'), headers: _headers());
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Could not load profile');
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateProfile({
    String? homeAddress,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? profilePhotoUrl,
  }) async {
    final r = await http.post(_u('/passenger/me/profile'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          if (homeAddress != null) 'home_address': homeAddress,
          if (emergencyContactName != null) 'emergency_contact_name': emergencyContactName,
          if (emergencyContactPhone != null) 'emergency_contact_phone': emergencyContactPhone,
          if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
        }));
    final m = await _decode(r);
    if (r.statusCode >= 400 || m['success'] != true) {
      throw _apiError(m, r.statusCode, 'Profile update failed');
    }
    final data = m['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  StateError _apiError(Map<String, dynamic> body, int status, String fallback) {
    final err = body['error'];
    if (err is Map<String, dynamic>) {
      final msg = err['message'];
      final code = err['code'];
      return StateError('${msg is String ? msg : fallback} ($code)');
    }
    return StateError('$fallback (HTTP $status)');
  }
}
