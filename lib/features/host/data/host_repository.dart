import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

class HostSpaceRecord {
  const HostSpaceRecord({
    required this.id,
    required this.title,
    required this.district,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    required this.exactAddress,
    required this.entranceInstructions,
    required this.hourlyPriceCents,
    required this.maxHeight,
    required this.maxWidth,
    required this.maxLength,
    required this.accessType,
    required this.covered,
    required this.evCharging,
    required this.accessible,
    required this.instantBookable,
    required this.verified,
    required this.status,
  });

  final String id;
  final String title;
  final String district;
  final String landmark;
  final double latitude;
  final double longitude;
  final String exactAddress;
  final String entranceInstructions;
  final int hourlyPriceCents;
  final double maxHeight;
  final double maxWidth;
  final double maxLength;
  final String accessType;
  final bool covered;
  final bool evCharging;
  final bool accessible;
  final bool instantBookable;
  final bool verified;
  final String status;

  bool get active => status == 'active';

  factory HostSpaceRecord.fromJson(Map<String, dynamic> json) =>
      HostSpaceRecord(
        id: json['id'].toString(),
        title: json['title'] as String,
        district: json['district'] as String,
        landmark: json['landmark'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        exactAddress: json['exact_address'] as String,
        entranceInstructions: json['entrance_instructions'] as String,
        hourlyPriceCents: json['hourly_price_cents'] as int,
        maxHeight: (json['max_height_m'] as num).toDouble(),
        maxWidth: (json['max_width_m'] as num).toDouble(),
        maxLength: (json['max_length_m'] as num).toDouble(),
        accessType: json['access_type'] as String,
        covered: json['is_covered'] == true,
        evCharging: json['has_ev_charging'] == true,
        accessible: json['is_accessible'] == true,
        instantBookable: json['is_instant_bookable'] == true,
        verified: json['is_verified'] == true,
        status: (json['status'] ?? 'active') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'district': district,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'exact_address': exactAddress,
        'entrance_instructions': entranceInstructions,
        'hourly_price_cents': hourlyPriceCents,
        'currency': 'EUR',
        'max_height_m': maxHeight,
        'max_width_m': maxWidth,
        'max_length_m': maxLength,
        'access_type': accessType,
        'is_covered': covered,
        'has_ev_charging': evCharging,
        'is_accessible': accessible,
        'is_instant_bookable': instantBookable,
        'is_verified': verified,
        'status': status,
      };

  Map<String, dynamic> toApi() => {
        'title': title,
        'district': district,
        'landmark': landmark,
        'latitude': latitude,
        'longitude': longitude,
        'exact_address': exactAddress,
        'entrance_instructions': entranceInstructions,
        'hourly_price_cents': hourlyPriceCents,
        'currency': 'EUR',
        'max_height_m': maxHeight,
        'max_width_m': maxWidth,
        'max_length_m': maxLength,
        'access_type': accessType,
        'is_covered': covered,
        'has_ev_charging': evCharging,
        'is_accessible': accessible,
        'is_instant_bookable': instantBookable,
      };

  HostSpaceRecord copyWith({String? status}) => HostSpaceRecord(
        id: id,
        title: title,
        district: district,
        landmark: landmark,
        latitude: latitude,
        longitude: longitude,
        exactAddress: exactAddress,
        entranceInstructions: entranceInstructions,
        hourlyPriceCents: hourlyPriceCents,
        maxHeight: maxHeight,
        maxWidth: maxWidth,
        maxLength: maxLength,
        accessType: accessType,
        covered: covered,
        evCharging: evCharging,
        accessible: accessible,
        instantBookable: instantBookable,
        verified: verified,
        status: status ?? this.status,
      );
}

abstract interface class HostRepository {
  Future<List<HostSpaceRecord>> spaces();
  Future<List<BookingRecord>> bookings();
  Future<HostSpaceRecord> create(HostSpaceRecord space);
  Future<HostSpaceRecord> setStatus(String id, String status);
}

class ApiHostRepository implements HostRepository {
  const ApiHostRepository(this.api);

  final ApiClient api;

  @override
  Future<List<HostSpaceRecord>> spaces() async =>
      (await api.get('/host/parking-spaces') as List)
          .map(
            (value) => HostSpaceRecord.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList();

  @override
  Future<List<BookingRecord>> bookings() async =>
      (await api.get('/host/bookings') as List)
          .map(
            (value) => BookingRecord.fromJson(
              value as Map<String, dynamic>,
            ),
          )
          .toList();

  @override
  Future<HostSpaceRecord> create(HostSpaceRecord space) async =>
      HostSpaceRecord.fromJson(
        await api.post(
          '/host/parking-spaces',
          body: space.toApi(),
        ) as Map<String, dynamic>,
      );

  @override
  Future<HostSpaceRecord> setStatus(String id, String status) async =>
      HostSpaceRecord.fromJson(
        await api.patch(
          '/host/parking-spaces/$id/status',
          body: {'status': status},
        ) as Map<String, dynamic>,
      );
}

class LocalHostRepository implements HostRepository {
  static const _key = 'local_beta_host_spaces';

  Future<void> _write(List<HostSpaceRecord> spaces) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _key,
      spaces.map((space) => jsonEncode(space.toJson())).toList(),
    );
  }

  @override
  Future<List<HostSpaceRecord>> spaces() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences
            .getStringList(_key)
            ?.map(
              (value) => HostSpaceRecord.fromJson(
                jsonDecode(value) as Map<String, dynamic>,
              ),
            )
            .toList() ??
        [];
  }

  @override
  Future<List<BookingRecord>> bookings() async => [];

  @override
  Future<HostSpaceRecord> create(HostSpaceRecord space) async {
    final values = await spaces();
    final saved = HostSpaceRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: space.title,
      district: space.district,
      landmark: space.landmark,
      latitude: space.latitude,
      longitude: space.longitude,
      exactAddress: space.exactAddress,
      entranceInstructions: space.entranceInstructions,
      hourlyPriceCents: space.hourlyPriceCents,
      maxHeight: space.maxHeight,
      maxWidth: space.maxWidth,
      maxLength: space.maxLength,
      accessType: space.accessType,
      covered: space.covered,
      evCharging: space.evCharging,
      accessible: space.accessible,
      instantBookable: space.instantBookable,
      verified: false,
      status: 'active',
    );
    values.insert(0, saved);
    await _write(values);
    return saved;
  }

  @override
  Future<HostSpaceRecord> setStatus(String id, String status) async {
    final values = await spaces();
    final index = values.indexWhere((space) => space.id == id);
    if (index == -1) {
      throw StateError('Stellplatz nicht gefunden.');
    }
    values[index] = values[index].copyWith(status: status);
    await _write(values);
    return values[index];
  }
}

final hostRepositoryProvider = Provider<HostRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode == AppMode.localBeta) return LocalHostRepository();
  return ApiHostRepository(ref.watch(apiClientProvider));
});
