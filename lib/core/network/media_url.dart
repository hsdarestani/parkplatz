import '../../config/environment.dart';

String resolveMediaUrl(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  final raw = value.trim();
  final parsed = Uri.tryParse(raw);
  if (parsed?.hasScheme == true) return raw;

  final api = Uri.parse(Environment.apiBaseUrl);
  if (api.hasScheme) {
    return api.replace(path: raw.startsWith('/') ? raw : '/$raw', query: null).toString();
  }
  return Uri.base.resolve(raw.startsWith('/') ? raw.substring(1) : raw).toString();
}
