import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:freiraum_parking/core/network/api_client.dart';
import 'package:freiraum_parking/features/marketplace/data/marketplace_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Tokens implements ApiTokenStore {
  _Tokens({this.access = 'access'});

  String? access;

  @override
  Future<void> clear() async => access = null;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => null;

  @override
  Future<void> save(String access, String refresh) async {
    this.access = access;
  }
}

http.Response _json(Object value, [int status = 200]) => http.Response(
      jsonEncode(value),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('short address query is rejected locally without a network request', () async {
    var requests = 0;
    final repository = MarketplaceRepository(
      ApiClient(
        _Tokens(),
        MockClient((_) async {
          requests += 1;
          return _json([]);
        }),
      ),
    );

    expect(await repository.suggestAddress('ab'), isEmpty);
    expect(requests, 0);
  });

  test('address suggestions preserve verified coordinates and address fields', () async {
    final repository = MarketplaceRepository(
      ApiClient(
        _Tokens(),
        MockClient((request) async {
          expect(request.url.path.endsWith('/locations/suggest'), isTrue);
          expect(request.url.queryParameters['q'], 'Zeil 10');
          expect(request.headers['authorization'], isNull);
          return _json([
            {
              'display_name': 'Zeil 10, Frankfurt am Main',
              'latitude': 50.114,
              'longitude': 8.682,
              'district': 'Innenstadt',
              'road': 'Zeil',
              'house_number': '10',
            },
          ]);
        }),
      ),
    );

    final values = await repository.suggestAddress('  Zeil 10  ');

    expect(values, hasLength(1));
    expect(values.single.displayName, 'Zeil 10, Frankfurt am Main');
    expect(values.single.latitude, 50.114);
    expect(values.single.longitude, 8.682);
    expect(values.single.district, 'Innenstadt');
    expect(values.single.road, 'Zeil');
    expect(values.single.houseNumber, '10');
  });

  test('public media and reviews parse defaults and resolved media URLs', () async {
    final repository = MarketplaceRepository(
      ApiClient(
        _Tokens(),
        MockClient((request) async {
          if (request.url.path.endsWith('/images')) {
            expect(request.headers['authorization'], isNull);
            return _json([
              {'id': 1, 'image_url': 'https://cdn.example/space.jpg'},
              {
                'id': 2,
                'image_url': 'https://cdn.example/pending.jpg',
                'approval_status': 'pending',
                'ai_reason': 'reviewing',
              },
            ]);
          }
          expect(request.url.path.endsWith('/reviews'), isTrue);
          expect(request.headers['authorization'], isNull);
          return _json([
            {
              'id': 'review-1',
              'rating': 5,
              'comment': 'Sehr gut',
              'created_at': '2026-07-20T12:00:00Z',
              'author_image_url': 'https://cdn.example/user.jpg',
            },
          ]);
        }),
      ),
    );

    final media = await repository.parkingImages('space-1');
    final reviews = await repository.reviews('space-1');

    expect(media, hasLength(2));
    expect(media.first.approvalStatus, 'approved');
    expect(media.last.approvalStatus, 'pending');
    expect(media.last.reason, 'reviewing');
    expect(reviews.single.authorName, 'FREIRAUM Nutzer');
    expect(reviews.single.authorImageUrl, 'https://cdn.example/user.jpg');
    expect(reviews.single.createdAt.isUtc, isTrue);
  });

  test('authenticated host media and review creation use exact API payloads', () async {
    var hostImagesRead = false;
    var reviewCreated = false;
    final repository = MarketplaceRepository(
      ApiClient(
        _Tokens(),
        MockClient((request) async {
          if (request.method == 'GET') {
            hostImagesRead = true;
            expect(request.url.path.endsWith('/host/parking-spaces/s1/images'), isTrue);
            expect(request.headers['authorization'], 'Bearer access');
            return _json([
              {'id': 3, 'image_url': 'https://cdn.example/host.jpg'},
            ]);
          }
          reviewCreated = true;
          expect(request.url.path.endsWith('/bookings/b1/review'), isTrue);
          expect(request.headers['authorization'], 'Bearer access');
          expect(jsonDecode(request.body), {
            'rating': 4,
            'comment': 'Sauber und sicher',
          });
          return _json({'ok': true});
        }),
      ),
    );

    expect(await repository.hostParkingImages('s1'), hasLength(1));
    await repository.createReview('b1', 4, '  Sauber und sicher  ');

    expect(hostImagesRead, isTrue);
    expect(reviewCreated, isTrue);
  });

  test('profile and parking uploads send multipart files and parse response', () async {
    var uploadCount = 0;
    final repository = MarketplaceRepository(
      ApiClient(
        _Tokens(),
        MockClient((request) async {
          uploadCount += 1;
          expect(request.method, 'POST');
          expect(request.headers['authorization'], 'Bearer access');
          expect(request.headers['content-type'], contains('multipart/form-data'));
          if (request.url.path.endsWith('/profile-image')) {
            return _json({'profile_image_url': 'https://cdn.example/profile.jpg'});
          }
          expect(
            request.url.path.endsWith('/host/parking-spaces/s1/images'),
            isTrue,
          );
          return _json({
            'id': 9,
            'image_url': 'https://cdn.example/parking.jpg',
            'approval_status': 'approved',
          });
        }),
      ),
    );

    final profile = await repository.uploadProfileImage(
      Uint8List.fromList([1, 2, 3]),
      'profile.jpg',
    );
    final parking = await repository.uploadParkingImage(
      's1',
      Uint8List.fromList([4, 5, 6]),
      'parking.jpg',
    );

    expect(profile, 'https://cdn.example/profile.jpg');
    expect(parking.id, 9);
    expect(parking.imageUrl, 'https://cdn.example/parking.jpg');
    expect(uploadCount, 2);
  });
}
