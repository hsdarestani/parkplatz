import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/media_url.dart';
import '../../booking/data/repositories.dart';
import '../../parking/data/providers.dart';

class ProfileUser {
  const ProfileUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.profileImageUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String? profileImageUrl;

  factory ProfileUser.fromJson(Map<String, dynamic> json) => ProfileUser(
        id: json['id'].toString(),
        email: json['email'] as String,
        displayName: json['display_name'] as String,
        profileImageUrl: json['profile_image_url'] == null
            ? null
            : resolveMediaUrl(json['profile_image_url'].toString()),
      );
}

// Compatibility for older screens and tests that imported AppUser.
typedef AppUser = ProfileUser;

abstract interface class ProfileRepository {
  Future<ProfileUser> read();
  Future<ProfileUser> updateDisplayName(String displayName);
}

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this.api);

  final ApiClient api;

  @override
  Future<ProfileUser> read() async => ProfileUser.fromJson(
        await api.get('/auth/me/profile') as Map<String, dynamic>,
      );

  @override
  Future<ProfileUser> updateDisplayName(String displayName) async {
    await api.patch(
      '/auth/me',
      body: {'display_name': displayName.trim()},
    );
    return read();
  }
}

class LocalProfileRepository implements ProfileRepository {
  const LocalProfileRepository(this.auth);

  final AuthRepository auth;

  @override
  Future<ProfileUser> read() async {
    if (!auth.authenticated) await auth.restore();
    final user = auth.currentUser;
    return ProfileUser(
      id: user?.id ?? 'local',
      email: user?.email ?? 'lokal@beta',
      displayName: user?.displayName ?? 'Beta-Nutzer',
    );
  }

  @override
  Future<ProfileUser> updateDisplayName(String displayName) async {
    final user = await read();
    return ProfileUser(
      id: user.id,
      email: user.email,
      displayName: displayName.trim(),
      profileImageUrl: user.profileImageUrl,
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
