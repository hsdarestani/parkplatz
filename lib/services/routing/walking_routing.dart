import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/api_client.dart';

class WalkingRoute {
  const WalkingRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
  });

  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> geometry;

  int get durationMinutes => (durationSeconds / 60).ceil();

  String get distanceLabel => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
      : '$distanceMeters m';
}

class RouteRequest {
  const RouteRequest({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
  });

  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;

  @override
  bool operator ==(Object other) =>
      other is RouteRequest &&
      other.fromLat == fromLat &&
      other.fromLng == fromLng &&
      other.toLat == toLat &&
      other.toLng == toLng;

  @override
  int get hashCode => Object.hash(fromLat, fromLng, toLat, toLng);
}

class WalkingRoutingRepository {
  const WalkingRoutingRepository(this.api);

  final ApiClient api;

  Future<WalkingRoute> route(RouteRequest request) async {
    final response = await api.get(
      '/routing/walking',
      authenticated: false,
      query: {
        'from_lat': request.fromLat.toString(),
        'from_lng': request.fromLng.toString(),
        'to_lat': request.toLat.toString(),
        'to_lng': request.toLng.toString(),
      },
    ) as Map<String, dynamic>;

    final geometry = (response['geometry'] as List? ?? const [])
        .map((value) => value as Map<String, dynamic>)
        .map(
          (value) => LatLng(
            (value['latitude'] as num).toDouble(),
            (value['longitude'] as num).toDouble(),
          ),
        )
        .toList();

    return WalkingRoute(
      distanceMeters: response['distance_meters'] as int,
      durationSeconds: response['duration_seconds'] as int,
      geometry: geometry,
    );
  }
}

final walkingRoutingRepositoryProvider = Provider<WalkingRoutingRepository>(
  (ref) => WalkingRoutingRepository(ref.watch(apiClientProvider)),
);

final walkingRouteProvider =
    FutureProvider.family<WalkingRoute?, RouteRequest>((ref, request) async {
  try {
    return await ref.watch(walkingRoutingRepositoryProvider).route(request);
  } catch (_) {
    return null;
  }
});

class UserLocationController extends StateNotifier<AsyncValue<LatLng?>> {
  UserLocationController() : super(const AsyncData(null));

  Future<LatLng?> locate() async {
    state = const AsyncLoading();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Bitte aktiviere die Standortdienste.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Standortfreigabe wurde nicht erteilt.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final value = LatLng(position.latitude, position.longitude);
      state = AsyncData(value);
      return value;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  void clear() => state = const AsyncData(null);
}

final userLocationProvider =
    StateNotifierProvider<UserLocationController, AsyncValue<LatLng?>>(
  (ref) => UserLocationController(),
);
