import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/core/network/api_client.dart';
import 'package:freiraum_parking/services/routing/walking_routing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _EmptyTokens implements ApiTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccess() async => null;

  @override
  Future<String?> readRefresh() async => null;

  @override
  Future<void> save(String access, String refresh) async {}
}

void main() {
  test('walking routing sends all coordinates and parses GeoJSON order', () async {
    final api = ApiClient(
      _EmptyTokens(),
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path.endsWith('/routing/walking'), isTrue);
        expect(request.url.queryParameters, {
          'from_lat': '50.11',
          'from_lng': '8.65',
          'to_lat': '50.12',
          'to_lng': '8.66',
        });
        return http.Response(
          jsonEncode({
            'distance_meters': 1450,
            'duration_seconds': 721,
            'geometry': [
              {'latitude': 50.11, 'longitude': 8.65},
              {'latitude': 50.12, 'longitude': 8.66},
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final route = await WalkingRoutingRepository(api).route(
      const RouteRequest(
        fromLat: 50.11,
        fromLng: 8.65,
        toLat: 50.12,
        toLng: 8.66,
      ),
    );

    expect(route.distanceMeters, 1450);
    expect(route.durationSeconds, 721);
    expect(route.durationMinutes, 13);
    expect(route.distanceLabel, '1,4 km');
    expect(route.geometry, hasLength(2));
    expect(route.geometry.first.latitude, 50.11);
    expect(route.geometry.first.longitude, 8.65);
  });

  test('walking route labels keep meter precision below one kilometer', () {
    const route = WalkingRoute(
      distanceMeters: 999,
      durationSeconds: 60,
      geometry: [],
    );

    expect(route.distanceLabel, '999 m');
    expect(route.durationMinutes, 1);
  });

  test('route requests compare every endpoint coordinate', () {
    const first = RouteRequest(
      fromLat: 50.1,
      fromLng: 8.6,
      toLat: 50.2,
      toLng: 8.7,
    );
    const same = RouteRequest(
      fromLat: 50.1,
      fromLng: 8.6,
      toLat: 50.2,
      toLng: 8.7,
    );
    const different = RouteRequest(
      fromLat: 50.1,
      fromLng: 8.6,
      toLat: 50.21,
      toLng: 8.7,
    );

    expect(first, same);
    expect(first.hashCode, same.hashCode);
    expect(first, isNot(different));
  });
}
