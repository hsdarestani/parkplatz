import '../../../core/network/api_client.dart';
import 'repositories.dart';

class OwnerAwareApiAvailabilityRepository implements AvailabilityRepository {
  const OwnerAwareApiAvailabilityRepository(this.api);

  final ApiClient api;

  @override
  Future<AvailabilityResult> check(
    String id,
    DateTime start,
    DateTime end,
  ) async {
    final ownedSpaces = await api.get('/host/parking-spaces') as List;
    final ownedByCurrentUser = ownedSpaces.any(
      (value) => value is Map && value['id'].toString() == id,
    );

    if (ownedByCurrentUser) {
      return const AvailabilityResult(
        false,
        message: 'Du kannst deinen eigenen Stellplatz nicht buchen.',
      );
    }

    final json = await api.get(
      '/parking-spaces/$id/availability',
      query: {
        'start_at': start.toIso8601String(),
        'end_at': end.toIso8601String(),
      },
      authenticated: false,
    ) as Map<String, dynamic>;

    return AvailabilityResult(
      json['available'] as bool,
      message: json['message'] as String?,
    );
  }
}
