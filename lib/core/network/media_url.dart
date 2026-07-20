import '../../config/environment.dart';

String resolveMediaUrl(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  var raw = value.trim();
  final parsed = Uri.tryParse(raw);
  if (parsed?.hasScheme == true) return raw;

  if (raw == '/media' || raw.startsWith('/media/')) {
    raw = '/api$raw';
  }
  final api = Uri.parse(Environment.apiBaseUrl);
  if (api.hasScheme) {
    final path = raw.startsWith('/') ? raw : '/$raw';
    return api.replace(path: path, query: null).toString();
  }
  return Uri.base.resolve(raw.startsWith('/') ? raw.substring(1) : raw).toString();
}
