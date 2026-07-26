import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenStore implements ApiTokenStore {
  String? access;
  String? refresh;
  int clearCount = 0;
  int saveCount = 0;

  _TokenStore({this.access, this.refresh});

  @override
  Future<void> clear() async {
    clearCount += 1;
    access = null;
    refresh = null;
  }

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => refresh;

  @override
  Future<void> save(String access, String refresh) async {
    saveCount += 1;
    this.access = access;
    this.refresh = refresh;
  }
}

http.Response _json(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('health only passes for a connected API', () async {
    final healthy = ApiClient(
      _TokenStore(),
      MockClient(
        (_) async => _json(
          {'status': 'ok', 'database': 'connected'},
          200,
        ),
      ),
    );
    final degraded = ApiClient(
      _TokenStore(),
      MockClient(
        (_) async => _json(
          {'status': 'degraded', 'database': 'unavailable'},
          200,
        ),
      ),
    );

    expect(await healthy.health(), isTrue);
    expect(await degraded.health(), isFalse);
  });

  test('authenticated requests send the access token and query values', () async {
    final tokens = _TokenStore(access: 'access-token');
    final api = ApiClient(
      tokens,
      MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['authorization'], 'Bearer access-token');
        expect(request.url.queryParameters, {'page': '2'});
        return _json({'ok': true}, 200);
      }),
    );

    expect(
      await api.get('/secure', query: const {'page': '2'}),
      {'ok': true},
    );
  });

  test('401 refreshes once, stores new tokens, and retries the request', () async {
    final tokens = _TokenStore(access: 'expired', refresh: 'refresh-1');
    var protectedCalls = 0;
    var refreshCalls = 0;
    final api = ApiClient(
      tokens,
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls += 1;
          expect(jsonDecode(request.body), {'refresh_token': 'refresh-1'});
          return _json(
            {
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
            },
            200,
          );
        }

        protectedCalls += 1;
        if (protectedCalls == 1) {
          expect(request.headers['authorization'], 'Bearer expired');
          return _json(
            {
              'detail': {'code': 'expired', 'message': 'expired'},
            },
            401,
          );
        }
        expect(request.headers['authorization'], 'Bearer access-2');
        return _json({'value': 42}, 200);
      }),
    );

    expect(await api.get('/secure'), {'value': 42});
    expect(refreshCalls, 1);
    expect(protectedCalls, 2);
    expect(tokens.saveCount, 1);
    expect(tokens.access, 'access-2');
    expect(tokens.refresh, 'refresh-2');
  });

  test('failed refresh clears tokens and returns unauthorized', () async {
    final tokens = _TokenStore(access: 'expired', refresh: 'bad-refresh');
    final api = ApiClient(
      tokens,
      MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(
            {
              'detail': {
                'code': 'invalid_refresh',
                'message': 'Sitzung abgelaufen.',
              },
            },
            401,
          );
        }
        return _json(
          {
            'detail': {'code': 'expired', 'message': 'Sitzung abgelaufen.'},
          },
          401,
        );
      }),
    );

    await expectLater(api.get('/secure'), throwsA(isA<ApiUnauthorizedException>()));
    expect(tokens.clearCount, greaterThanOrEqualTo(1));
    expect(tokens.access, isNull);
    expect(tokens.refresh, isNull);
  });

  test('validation and conflict responses preserve user-safe code and message', () async {
    final validationApi = ApiClient(
      _TokenStore(),
      MockClient(
        (_) async => _json(
          {
            'detail': [
              {
                'type': 'missing',
                'loc': ['body', 'exact_address'],
                'msg': 'Field required',
              }
            ],
          },
          422,
        ),
      ),
    );
    final conflictApi = ApiClient(
      _TokenStore(),
      MockClient(
        (_) async => _json(
          {
            'detail': {
              'code': 'booking_overlap',
              'message': 'Zeitraum ist nicht mehr frei.',
            },
          },
          409,
        ),
      ),
    );

    await expectLater(
      validationApi.post('/host', body: const {}),
      throwsA(
        isA<ApiValidationException>().having(
          (error) => error.message,
          'message',
          'Genaue Adresse fehlt.',
        ),
      ),
    );
    await expectLater(
      conflictApi.post('/booking', body: const {}),
      throwsA(
        isA<ApiConflictException>()
            .having((error) => error.code, 'code', 'booking_overlap')
            .having(
              (error) => error.message,
              'message',
              'Zeitraum ist nicht mehr frei.',
            ),
      ),
    );
  });

  test('invalid server payload never leaks raw response text', () async {
    final api = ApiClient(
      _TokenStore(),
      MockClient((_) async => http.Response('<html>secret stack trace</html>', 500)),
    );

    await expectLater(
      api.get('/broken', authenticated: false),
      throwsA(
        isA<ApiServerException>().having(
          (error) => error.message,
          'message',
          'Der Server ist vorübergehend nicht verfügbar.',
        ),
      ),
    );
  });
}
