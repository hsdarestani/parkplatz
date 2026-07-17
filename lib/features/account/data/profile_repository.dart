import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';
import '../../parking/data/providers.dart';

abstract interface class ProfileRepository {
  Future<AppUser> read();
  Future<AppUser> updateDisplayName(String displayName);
}

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this.api);

  final ApiClient api;

  @override
  Future<AppUser> read() async => AppUser.fromJson(
        await api.get('/auth/me') as Map<String, dynamic>,
      );

  @override
  Future<AppUser> updateDisplayName(String displayName) async =>
      AppUser.fromJson(
        await api.patch(
          '/auth/me',
          body: {'display_name': displayName.trim()},
        ) as Map<String, dynamic>,
      );
}

class LocalProfileRepository implements ProfileRepository {
  const LocalProfileRepository(this.auth);

  final AuthRepository auth;

  @override
  Future<AppUser> read() async {
    if (!auth.authenticated) await auth.restore();
    return auth.currentUser ??
        const AppUser(
          id: 'local',
          email: 'lokal@beta',
          displayName: 'Beta-Nutzer',
        );
  }

  @override
  Future<AppUser> updateDisplayName(String displayName) async {
    final user = await read();
    return AppUser(
      id: user.id,
      email: user.email,
      displayName: displayName.trim(),
    );
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final mode = ref.watch(appModeProvider);
  if (mode == AppMode.localBeta) {
    return LocalProfileRepository(ref.watch(authRepositoryProvider));
  }
  return ApiProfileRepository(ref.watch(apiClientProvider));
});
