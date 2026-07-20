import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/media_url.dart';
import '../../booking/data/repositories.dart';

class AddressSuggestion {
  const AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.district,
    this.road,
    this.houseNumber,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String district;
  final String? road;
  final String? houseNumber;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      AddressSuggestion(
        displayName: json['display_name']?.toString() ?? '',
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        district: json['district']?.toString() ?? 'Frankfurt',
        road: json['road']?.toString(),
        houseNumber: json['house_number']?.toString(),
      );
}

class ParkingMedia {
  const ParkingMedia({
    required this.id,
    required this.imageUrl,
    this.approvalStatus = 'approved',
    this.reason,
  });

  final int id;
  final String imageUrl;
  final String approvalStatus;
  final String? reason;

  factory ParkingMedia.fromJson(Map<String, dynamic> json) => ParkingMedia(
        id: json['id'] as int,
        imageUrl: resolveMediaUrl(json['image_url']?.toString()),
        approvalStatus: json['approval_status']?.toString() ?? 'approved',
        reason: json['ai_reason']?.toString(),
      );
}

class ParkingReview {
  const ParkingReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.authorName,
    this.authorImageUrl,
  });

  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String authorName;
  final String? authorImageUrl;

  factory ParkingReview.fromJson(Map<String, dynamic> json) => ParkingReview(
        id: json['id'].toString(),
        rating: json['rating'] as int,
        comment: json['comment'] as String,
        createdAt: DateTime.parse(json['created_at'].toString()),
        authorName: json['author_name']?.toString() ?? 'FREIRAUM Nutzer',
        authorImageUrl: json['author_image_url'] == null
            ? null
            : resolveMediaUrl(json['author_image_url'].toString()),
      );
}

class MarketplaceRepository {
  const MarketplaceRepository(this.api);

  final ApiClient api;

  Future<List<AddressSuggestion>> suggestAddress(String query) async {
    if (query.trim().length < 3) return const [];
    final values = await api.get(
      '/locations/suggest',
      query: {'q': query.trim()},
      authenticated: false,
    ) as List;
    return values
        .map(
          (value) => AddressSuggestion.fromJson(
            value as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<String> uploadProfileImage(
    Uint8List bytes,
    String filename,
  ) async {
    final response = await api.upload(
      '/auth/me/profile-image',
      bytes: bytes,
      filename: filename,
    ) as Map<String, dynamic>;
    return resolveMediaUrl(response['profile_image_url']?.toString());
  }

  Future<ParkingMedia> uploadParkingImage(
    String spaceId,
    Uint8List bytes,
    String filename,
  ) async =>
      ParkingMedia.fromJson(
        await api.upload(
          '/host/parking-spaces/$spaceId/images',
          bytes: bytes,
          filename: filename,
        ) as Map<String, dynamic>,
      );

  Future<List<ParkingMedia>> parkingImages(String spaceId) async =>
      (await api.get(
        '/parking-spaces/$spaceId/images',
        authenticated: false,
      ) as List)
          .map(
            (value) => ParkingMedia.fromJson(value as Map<String, dynamic>),
          )
          .toList();

  Future<List<ParkingMedia>> hostParkingImages(String spaceId) async =>
      (await api.get('/host/parking-spaces/$spaceId/images') as List)
          .map(
            (value) => ParkingMedia.fromJson(value as Map<String, dynamic>),
          )
          .toList();

  Future<List<ParkingReview>> reviews(String spaceId) async =>
      (await api.get(
        '/parking-spaces/$spaceId/reviews',
        authenticated: false,
      ) as List)
          .map(
            (value) => ParkingReview.fromJson(value as Map<String, dynamic>),
          )
          .toList();

  Future<void> createReview(
    String bookingId,
    int rating,
    String comment,
  ) async {
    await api.post(
      '/bookings/$bookingId/review',
      body: {'rating': rating, 'comment': comment.trim()},
    );
  }
}

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>(
  (ref) => MarketplaceRepository(ref.watch(apiClientProvider)),
);

final parkingImagesProvider =
    FutureProvider.family<List<ParkingMedia>, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).parkingImages(id);
});

final parkingReviewsProvider =
    FutureProvider.family<List<ParkingReview>, String>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).reviews(id);
});
