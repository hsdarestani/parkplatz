import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/core/network/api_client.dart';
import 'package:freiraum_parking/features/booking/data/owner_aware_availability_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements ApiTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readAccess() async => 'access-token';

  @override
  Future<String?> readRefresh() async => 'refresh-token';

  @override
  Future<void> save(String access, String refresh) async {}
}

void main() {
  test('owned parking space is rejected before public availability lookup',
      () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      expect(request.url.path, endsWith('/host/parking-spaces'));
      return http.Response(
        jsonEncode([
          {'id': 'owned-space'},
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = OwnerAwareApiAvailabilityRepository(
      ApiClient(_TokenStore(), client),
    );

    final result = await repository.check(
      'owned-space',
      DateTime(2026, 7, 20, 10),
      DateTime(2026, 7, 20, 12),
    );

    expect(requests, 1);
    expect(result.available, isFalse);
    expect(
      result.message,
      'Du kannst deinen eigenen Stellplatz nicht buchen.',
    );
  });

  test('non-owner continues to live availability lookup', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests += 1;
      if (request.url.path.endsWith('/host/parking-spaces')) {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, endsWith('/availability'));
      return http.Response(
        jsonEncode({'available': true}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final repository = OwnerAwareApiAvailabilityRepository(
      ApiClient(_TokenStore(), client),
    );

    final result = await repository.check(
      'guest-space',
      DateTime(2026, 7, 20, 10),
      DateTime(2026, 7, 20, 12),
    );

    expect(requests, 2);
    expect(result.available, isTrue);
  });
}
