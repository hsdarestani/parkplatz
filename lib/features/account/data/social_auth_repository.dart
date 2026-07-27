import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../booking/data/repositories.dart';

enum SocialAuthProvider { google, apple }

extension SocialAuthProviderName on SocialAuthProvider {
  String get apiName => switch (this) {
        SocialAuthProvider.google => 'google',
        SocialAuthProvider.apple => 'apple',
      };
}

class SocialAuthAvailability {
  const SocialAuthAvailability({
    required this.googleConfigured,
    required this.googleEnabled,
    required this.appleConfigured,
    required this.appleEnabled,
  });

  const SocialAuthAvailability.disabled()
      : googleConfigured = false,
        googleEnabled = false,
        appleConfigured = false,
        appleEnabled = false;

  final bool googleConfigured;
  final bool googleEnabled;
  final bool appleConfigured;
  final bool appleEnabled;

  factory SocialAuthAvailability.fromJson(Map<String, dynamic> json) {
    final google = json['google'] as Map<String, dynamic>? ?? const {};
    final apple = json['apple'] as Map<String, dynamic>? ?? const {};
    return SocialAuthAvailability(
      googleConfigured: google['configured'] == true,
      googleEnabled: google['enabled'] == true,
      appleConfigured: apple['configured'] == true,
      appleEnabled: apple['enabled'] == true,
    );
  }
}

abstract interface class SocialAuthRepository {
  Future<SocialAuthAvailability> availability();

  Future<Map<String, dynamic>> exchange(
    SocialAuthProvider provider, {
    required String idToken,
    String? nonce,
  });
}

class ApiSocialAuthRepository implements SocialAuthRepository {
  const ApiSocialAuthRepository(this.api);

  final ApiClient api;

  @override
  Future<SocialAuthAvailability> availability() async {
    final json = await api.get(
      '/auth/providers',
      authenticated: false,
    ) as Map<String, dynamic>;
    return SocialAuthAvailability.fromJson(json);
  }

  @override
  Future<Map<String, dynamic>> exchange(
    SocialAuthProvider provider, {
    required String idToken,
    String? nonce,
  }) async {
    return await api.post(
      '/auth/oauth/${provider.apiName}',
      authenticated: false,
      body: {
        'id_token': idToken,
        if (nonce != null) 'nonce': nonce,
      },
    ) as Map<String, dynamic>;
  }
}

final socialAuthRepositoryProvider = Provider<SocialAuthRepository>(
  (ref) => ApiSocialAuthRepository(ref.watch(apiClientProvider)),
);
