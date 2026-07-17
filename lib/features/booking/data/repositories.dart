import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/environment.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/models.dart';
import '../../parking/data/demo_parking_repository.dart';

abstract interface class TokenStorage implements ApiTokenStore {
  Future<void> replace(String access, String refresh);
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;

  @override
  Future<String?> readAccess() => storage.read(key: 'access_token');

  @override
  Future<String?> readRefresh() => storage.read(key: 'refresh_token');

  @override
  Future<void> save(String access, String refresh) => replace(access, refresh);

  @override
  Future<void> replace(String access, String refresh) async {
    await storage.write(key: 'access_token', value: access);
    await storage.write(key: 'refresh_token', value: refresh);
  }

  @override
  Future<void> clear() async {
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
  }
}

enum AppMode { checking, api, localBeta, unavailable }

class AppModeController extends StateNotifier<AppMode> {
  AppModeController(this.api) : super(AppMode.checking) {
    check();
  }

  AppModeController.fixed(AppMode mode) : api = null, super(mode);
  final ApiClient? api;

  Future<void> check() async {
    if (api == null) return;
    state = AppMode.checking;
    final healthy = await api!.health();
    state = healthy
        ? AppMode.api
        : Environment.allowLocalBookingFallback
            ? AppMode.localBeta
            : AppMode.unavailable;
  }
}

final tokenStorageProvider =
    Provider<TokenStorage>((_) => const SecureTokenStorage());
final apiClientProvider =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));
final appModeProvider = StateNotifierProvider<AppModeController, AppMode>(
  (ref) => AppModeController(ref.watch(apiClientProvider)),
);

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id, email, displayName;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String,
      );
}

abstract interface class AuthRepository {
  Future<void> login(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> logout();
  Future<bool> restore();
  bool get authenticated;
  AppUser? get currentUser;
}

class LocalBetaAuthRepository implements AuthRepository {
  static bool _authenticated = false;

  @override
  bool get authenticated => _authenticated;

  @override
  AppUser? get currentUser => _authenticated
      ? const AppUser(
          id: 'local',
          email: 'lokal@beta',
          displayName: 'Beta-Nutzer',
        )
      : null;

  @override
  Future<void> login(String email, String password) async {
    if (!email.contains('@') || password.length < 8) {
      throw const FormatException('E-Mail oder Passwort ist ungültig.');
    }
    _authenticated = true;
  }

  @override
  Future<void> register(String name, String email, String password) =>
      login(email, password);

  @override
  Future<void> logout() async => _authenticated = false;

  @override
  Future<bool> restore() async => authenticated;
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this.api, this.tokens);

  final ApiClient api;
  final TokenStorage tokens;
  AppUser? _user;

  @override
  bool get authenticated => _user != null;

  @override
  AppUser? get currentUser => _user;

  Future<void> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final json = await api.post(
      path,
      body: body,
      authenticated: false,
    ) as Map<String, dynamic>;
    await tokens.save(
      json['access_token'] as String,
      json['refresh_token'] as String,
    );
    await _me();
  }

  @override
  Future<void> login(String email, String password) => _authenticate(
        '/auth/login',
        {'email': email.trim(), 'password': password},
      );

  @override
  Future<void> register(String name, String email, String password) =>
      _authenticate(
        '/auth/register',
        {
          'display_name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );

  Future<void> _me() async => _user = AppUser.fromJson(
        await api.get('/auth/me') as Map<String, dynamic>,
      );

  @override
  Future<bool> restore() async {
    if (await tokens.readRefresh() == null) return false;
    try {
      await _me();
      return true;
    } catch (_) {
      await tokens.clear();
      _user = null;
      return false;
    }
  }

  @override
  Future<void> logout() async {
    final refresh = await tokens.readRefresh();
    try {
      if (refresh != null) {
        await api.post(
          '/auth/logout',
          body: {'refresh_token': refresh},
          authenticated: false,
        );
      }
    } finally {
      await tokens.clear();
      _user = null;
    }
  }
}

class VehicleRecord {
  const VehicleRecord({
    required this.id,
    required this.name,
    required this.plate,
    required this.height,
    required this.width,
    required this.length,
    required this.isDefault,
  });

  final String id, name, plate;
  final double height, width, length;
  final bool isDefault;

  factory VehicleRecord.fromJson(Map<String, dynamic> json) => VehicleRecord(
        id: json['id'].toString(),
        name: json['name'] as String,
        plate: json['plate'] as String,
        height: (json['height_m'] as num).toDouble(),
        width: (json['width_m'] as num).toDouble(),
        length: (json['length_m'] as num).toDouble(),
        isDefault: json['is_default'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'plate': plate,
        'height_m': height,
        'width_m': width,
        'length_m': length,
        'is_default': isDefault,
      };

  Map<String, dynamic> toApi() => {...toJson()}..remove('id');
}

abstract interface class VehicleRepository {
  Future<List<VehicleRecord>> all();
  Future<VehicleRecord> save(VehicleRecord vehicle);
  Future<void> delete(String id);
}

class ApiVehicleRepository implements VehicleRepository {
  ApiVehicleRepository(this.api);
  final ApiClient api;

  @override
  Future<List<VehicleRecord>> all() async =>
      (await api.get('/vehicles') as List)
          .map((value) => VehicleRecord.fromJson(value))
          .toList();

  @override
  Future<VehicleRecord> save(VehicleRecord vehicle) async =>
      VehicleRecord.fromJson(
        await (vehicle.id.isEmpty
            ? api.post('/vehicles', body: vehicle.toApi())
            : api.patch('/vehicles/${vehicle.id}', body: vehicle.toApi())),
      );

  @override
  Future<void> delete(String id) => api.delete('/vehicles/$id');
}

class LocalVehicleRepository implements VehicleRepository {
  static const key = 'local_beta_vehicles';

  @override
  Future<List<VehicleRecord>> all() async =>
      (await SharedPreferences.getInstance())
          .getStringList(key)
          ?.map((value) => VehicleRecord.fromJson(jsonDecode(value)))
          .toList() ??
      [];

  Future<void> _write(List<VehicleRecord> vehicles) async =>
      (await SharedPreferences.getInstance()).setStringList(
        key,
        vehicles.map((vehicle) => jsonEncode(vehicle.toJson())).toList(),
      );

  @override
  Future<VehicleRecord> save(VehicleRecord vehicle) async {
    final values = await all();
    final saved = vehicle.id.isEmpty
        ? VehicleRecord(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: vehicle.name,
            plate: vehicle.plate,
            height: vehicle.height,
            width: vehicle.width,
            length: vehicle.length,
            isDefault: vehicle.isDefault,
          )
        : vehicle;
    values.removeWhere((value) => value.id == saved.id);
    values.add(saved);
    await _write(values);
    return saved;
  }

  @override
  Future<void> delete(String id) async {
    final values = await all();
    values.removeWhere((value) => value.id == id);
    await _write(values);
  }
}

class BookingRecord {
  const BookingRecord({
    required this.id,
    required this.parkingId,
    required this.title,
    required this.reference,
    this.vehicleId = '',
    required this.plate,
    required this.status,
    required this.start,
    required this.end,
    this.hourlyPriceCents = 0,
    required this.totalCents,
    this.currency = 'EUR',
    this.cancelledAt,
    this.exactAddress,
    this.entranceInstructions,
    this.accessCode,
    this.parkingPassToken,
    this.localBeta = false,
  });

  final String id,
      parkingId,
      title,
      reference,
      vehicleId,
      plate,
      status,
      currency;
  final DateTime start, end;
  final int hourlyPriceCents, totalCents;
  final DateTime? cancelledAt;
  final String? exactAddress,
      entranceInstructions,
      accessCode,
      parkingPassToken;
  final bool localBeta;

  factory BookingRecord.fromJson(
    Map<String, dynamic> json, {
    bool localBeta = false,
  }) =>
      BookingRecord(
        id: json['id'].toString(),
        parkingId: (json['parking_space_id'] ?? json['parkingId']).toString(),
        title: (json['parking_title'] ?? json['title'] ?? 'Stellplatz') as String,
        reference: (json['public_reference'] ?? json['reference']) as String,
        vehicleId: (json['vehicle_id'] ?? json['vehicleId'] ?? '').toString(),
        plate: (json['vehicle_plate'] ?? json['plate'] ?? '') as String,
        status: json['status'] as String,
        start: DateTime.parse((json['start_at'] ?? json['start']) as String),
        end: DateTime.parse((json['end_at'] ?? json['end']) as String),
        hourlyPriceCents:
            (json['hourly_price_cents_snapshot'] ?? json['hourlyPriceCents'] ?? 0)
                as int,
        totalCents:
            (json['total_price_cents'] ?? json['totalCents']) as int,
        currency: (json['currency'] ?? 'EUR') as String,
        cancelledAt: json['cancelled_at'] == null
            ? null
            : DateTime.parse(json['cancelled_at']),
        exactAddress: json['exact_address'],
        entranceInstructions: json['entrance_instructions'],
        accessCode: json['access_code'],
        parkingPassToken: json['parking_pass_token'],
        localBeta: localBeta || json['localBeta'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'parkingId': parkingId,
        'title': title,
        'reference': reference,
        'vehicleId': vehicleId,
        'plate': plate,
        'status': status,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'hourlyPriceCents': hourlyPriceCents,
        'totalCents': totalCents,
        'currency': currency,
        'cancelled_at': cancelledAt?.toIso8601String(),
        'localBeta': localBeta,
      };

  BookingRecord cancelled() => BookingRecord(
        id: id,
        parkingId: parkingId,
        title: title,
        reference: reference,
        vehicleId: vehicleId,
        plate: plate,
        status: 'cancelled',
        start: start,
        end: end,
        hourlyPriceCents: hourlyPriceCents,
        totalCents: totalCents,
        currency: currency,
        cancelledAt: DateTime.now(),
        localBeta: localBeta,
      );
}

abstract interface class BookingRepository {
  Future<List<BookingRecord>> all();
  Future<BookingRecord?> detail(String id);
  Future<BookingRecord> create(BookingRecord booking);
  Future<void> cancel(String id);
}

int _bookingRequestSequence = 0;

String createBookingIdempotencyKey() {
  _bookingRequestSequence = (_bookingRequestSequence + 1) & 0x7fffffff;
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final sequence = _bookingRequestSequence.toRadixString(36);
  return '$timestamp-$sequence';
}

class ApiBookingRepository implements BookingRepository {
  ApiBookingRepository(this.api);
  final ApiClient api;

  @override
  Future<List<BookingRecord>> all() async =>
      (await api.get('/bookings') as List)
          .map((value) => BookingRecord.fromJson(value))
          .toList();

  @override
  Future<BookingRecord?> detail(String id) async =>
      BookingRecord.fromJson(await api.get('/bookings/$id'));

  @override
  Future<BookingRecord> create(BookingRecord booking) async =>
      BookingRecord.fromJson(
        await api.post(
          '/bookings',
          body: {
            'parking_space_id': booking.parkingId,
            'vehicle_id': booking.vehicleId,
            'start_at': booking.start.toIso8601String(),
            'end_at': booking.end.toIso8601String(),
            'idempotency_key': createBookingIdempotencyKey(),
          },
        ),
      );

  @override
  Future<void> cancel(String id) async {
    await api.post(
      '/bookings/$id/cancel',
      body: {'reason': 'Vom Nutzer storniert'},
    );
  }
}

class LocalBetaBookingRepository implements BookingRepository {
  static const _key = 'local_beta_bookings';

  @override
  Future<List<BookingRecord>> all() async =>
      (await SharedPreferences.getInstance())
          .getStringList(_key)
          ?.map(
            (value) => BookingRecord.fromJson(
              jsonDecode(value),
              localBeta: true,
            ),
          )
          .toList() ??
      [];

  Future<void> _save(List<BookingRecord> bookings) async =>
      (await SharedPreferences.getInstance()).setStringList(
        _key,
        bookings.map((booking) => jsonEncode(booking.toJson())).toList(),
      );

  @override
  Future<BookingRecord> create(BookingRecord booking) async {
    final local = BookingRecord(
      id: booking.id,
      parkingId: booking.parkingId,
      title: booking.title,
      reference: booking.reference,
      vehicleId: booking.vehicleId,
      plate: booking.plate,
      status: booking.status,
      start: booking.start,
      end: booking.end,
      hourlyPriceCents: booking.hourlyPriceCents,
      totalCents: booking.totalCents,
      localBeta: true,
    );
    final values = await all();
    if (!values.any((value) => value.id == booking.id)) {
      values.add(local);
      await _save(values);
    }
    return local;
  }

  @override
  Future<BookingRecord?> detail(String id) async {
    for (final booking in await all()) {
      if (booking.id == id) return booking;
    }
    return null;
  }

  @override
  Future<void> cancel(String id) async {
    final values = await all();
    await _save(
      values
          .map((booking) => booking.id == id ? booking.cancelled() : booking)
          .toList(),
    );
  }
}

class AvailabilityResult {
  const AvailabilityResult(this.available, {this.message});
  final bool available;
  final String? message;
}

abstract interface class AvailabilityRepository {
  Future<AvailabilityResult> check(
    String id,
    DateTime start,
    DateTime end,
  );
}

class ApiAvailabilityRepository implements AvailabilityRepository {
  ApiAvailabilityRepository(this.api);
  final ApiClient api;

  @override
  Future<AvailabilityResult> check(
    String id,
    DateTime start,
    DateTime end,
  ) async {
    final json = await api.get(
      '/parking-spaces/$id/availability',
      query: {
        'start_at': start.toIso8601String(),
        'end_at': end.toIso8601String(),
      },
      authenticated: false,
    );
    return AvailabilityResult(
      json['available'] as bool,
      message: json['message'] as String?,
    );
  }
}

class LocalAvailabilityRepository implements AvailabilityRepository {
  @override
  Future<AvailabilityResult> check(
    String id,
    DateTime start,
    DateTime end,
  ) async =>
      const AvailabilityResult(true);
}

class ApiParkingRepository implements ParkingRepository {
  ApiParkingRepository(this.api);
  final ApiClient api;

  @override
  Future<List<ParkingSpace>> all() async => (await api.get(
        '/parking-spaces',
        authenticated: false,
      ) as List)
          .map((value) => _parkingFromJson(value as Map<String, dynamic>))
          .toList();

  @override
  Future<ParkingSpace?> byId(String id) async {
    try {
      return _parkingFromJson(
        await api.get(
          '/parking-spaces/$id',
          authenticated: false,
        ) as Map<String, dynamic>,
      );
    } on ApiNotFoundException {
      return null;
    }
  }
}

ParkingSpace _parkingFromJson(Map<String, dynamic> json) {
  final access = switch (json['access_type']?.toString()) {
    'barrier' || 'schranke' => AccessType.schranke,
    'gate' || 'tor' => AccessType.tor,
    'underground' || 'tiefgarage' => AccessType.tiefgarage,
    'reception' || 'rezeption' => AccessType.rezeption,
    _ => AccessType.offen,
  };
  return ParkingSpace(
    id: json['id'].toString(),
    title: json['title'] as String,
    district: json['district'] as String,
    landmark: json['landmark'] as String,
    lat: (json['latitude'] as num).toDouble(),
    lng: (json['longitude'] as num).toDouble(),
    hourlyPrice: (json['hourly_price_cents'] as num).toDouble() / 100,
    currency: (json['currency'] ?? 'EUR') as String,
    walkingMeters: 500,
    walkingMinutes: 7,
    available: true,
    instant: json['is_instant_bookable'] == true,
    covered: json['is_covered'] == true,
    ev: json['has_ev_charging'] == true,
    accessible: json['is_accessible'] == true,
    maxHeight: (json['max_height_m'] as num).toDouble(),
    maxWidth: (json['max_width_m'] as num).toDouble(),
    maxLength: (json['max_length_m'] as num).toDouble(),
    access: access,
    entranceSummary: 'Genaue Zufahrt nach bestätigter Buchung',
    hostType: 'FREIRAUM Partner',
    verified: json['is_verified'] == true,
    rating: (json['rating'] as num).toDouble(),
    reviewCount: json['review_count'] as int,
    cancellationSummary:
        'Stornierungsbedingungen werden vor Buchung bestätigt',
    availabilityStatus: 'Verfügbarkeit wird live geprüft',
    visual: json['is_covered'] == true
        ? VisualType.garage
        : VisualType.privateOutdoor,
  );
}
