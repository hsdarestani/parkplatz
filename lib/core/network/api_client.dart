import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../config/environment.dart';

sealed class ApiException implements Exception {
  const ApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class ApiOfflineException extends ApiException {
  const ApiOfflineException() : super('Der Server ist gerade nicht erreichbar.');
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException([
    String message = 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
  ]) : super(message);
}

class ApiValidationException extends ApiException {
  const ApiValidationException(super.message, {super.code});
}

class ApiConflictException extends ApiException {
  const ApiConflictException(super.message, {super.code});
}

class ApiNotFoundException extends ApiException {
  const ApiNotFoundException([
    String message = 'Der Eintrag wurde nicht gefunden.',
  ]) : super(message);
}

class ApiServerException extends ApiException {
  const ApiServerException()
      : super('Der Server ist vorübergehend nicht verfügbar.');
}

abstract interface class ApiTokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save(String access, String refresh);
  Future<void> clear();
}

class ApiClient {
  ApiClient(this.tokens, [http.Client? client])
      : client = client ?? http.Client();

  final ApiTokenStore tokens;
  final http.Client client;
  Future<bool>? _refreshing;

  static const timeout = Duration(seconds: 8);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Environment.apiBaseUrl.endsWith('/')
        ? Environment.apiBaseUrl.substring(
            0,
            Environment.apiBaseUrl.length - 1,
          )
        : Environment.apiBaseUrl;
    return Uri.parse('$base${path.startsWith('/') ? path : '/$path'}')
        .replace(queryParameters: query);
  }

  Future<bool> health() async {
    try {
      final response = await client
          .get(_uri('/health'))
          .timeout(const Duration(seconds: 3));
      final body = jsonDecode(response.body);
      return response.statusCode == 200 &&
          body is Map &&
          body['status'] == 'ok' &&
          body['database'] == 'connected';
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) =>
      _request(
        'GET',
        path,
        query: query,
        authenticated: authenticated,
      );

  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) =>
      _request(
        'POST',
        path,
        body: body,
        authenticated: authenticated,
      );

  Future<dynamic> patch(String path, {Object? body}) =>
      _request('PATCH', path, body: body);

  Future<void> delete(String path) async {
    await _request('DELETE', path);
  }

  Future<dynamic> upload(
    String path, {
    required Uint8List bytes,
    required String filename,
    String field = 'file',
    bool retried = false,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers['Accept'] = 'application/json';
    final token = await tokens.readAccess();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        field,
        bytes,
        filename: filename,
        contentType: _mediaTypeFor(filename),
      ),
    );

    http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)),
      );
    } on TimeoutException catch (_) {
      throw const ApiOfflineException();
    } on http.ClientException catch (_) {
      throw const ApiOfflineException();
    }

    if (response.statusCode == 401 && !retried && await _refresh()) {
      return upload(
        path,
        bytes: bytes,
        filename: filename,
        field: field,
        retried: true,
      );
    }
    return _decodeResponse(response);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
    bool retried = false,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = await tokens.readAccess();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      final request = http.Request(method, _uri(path, query))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      response = await http.Response.fromStream(
        await client.send(request).timeout(timeout),
      );
    } on TimeoutException catch (_) {
      throw const ApiOfflineException();
    } on http.ClientException catch (_) {
      throw const ApiOfflineException();
    }

    if (response.statusCode == 401 &&
        authenticated &&
        !retried &&
        await _refresh()) {
      return _request(
        method,
        path,
        body: body,
        query: query,
        authenticated: true,
        retried: true,
      );
    }
    return _decodeResponse(response);
  }

  Future<dynamic> _decodeResponse(http.Response response) async {
    if (response.statusCode == 204) return null;

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final detail = decoded is Map ? decoded['detail'] : null;
    final data = detail is Map
        ? detail
        : decoded is Map
            ? decoded
            : <String, dynamic>{};
    final message = data is Map && data['message'] is String
        ? data['message'] as String
        : _validationMessage(detail);
    final code = data is Map ? data['code']?.toString() : null;

    switch (response.statusCode) {
      case 401:
        await tokens.clear();
        throw ApiUnauthorizedException(
          message ??
              'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
        );
      case 404:
        throw ApiNotFoundException(
          message ?? 'Der Eintrag wurde nicht gefunden.',
        );
      case 409:
        throw ApiConflictException(
          message ??
              'Dieser Zeitraum wurde gerade gebucht. Bitte wähle eine andere Zeit.',
          code: code,
        );
      case 400:
      case 422:
        throw ApiValidationException(
          message ?? 'Bitte prüfe deine Eingaben.',
          code: code,
        );
      default:
        throw const ApiServerException();
    }
  }

  Future<bool> _refresh() {
    final active = _refreshing;
    if (active != null) return active;
    final refresh = _doRefresh().whenComplete(() => _refreshing = null);
    _refreshing = refresh;
    return refresh;
  }

  Future<bool> _doRefresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null) return false;
    try {
      final response = await post(
        '/auth/refresh',
        body: {'refresh_token': refresh},
        authenticated: false,
      );
      await tokens.save(
        response['access_token'] as String,
        response['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      await tokens.clear();
      return false;
    }
  }
}

MediaType _mediaTypeFor(String filename) {
  final extension = filename.toLowerCase().split('.').last;
  return switch (extension) {
    'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
    'png' => MediaType('image', 'png'),
    'webp' => MediaType('image', 'webp'),
    'pdf' => MediaType('application', 'pdf'),
    _ => MediaType('application', 'octet-stream'),
  };
}

String? _validationMessage(dynamic detail) {
  if (detail is! List || detail.isEmpty || detail.first is! Map) return null;
  final error = detail.first as Map;
  final location = error['loc'];
  final field = location is List && location.isNotEmpty
      ? location.last.toString()
      : 'Eingabe';
  final label = _fieldLabel(field);
  final type = error['type']?.toString();
  final context = error['ctx'];

  switch (type) {
    case 'missing':
      return '$label fehlt.';
    case 'string_too_short':
      final minimum = context is Map ? context['min_length'] : null;
      return minimum == null
          ? '$label ist zu kurz.'
          : '$label muss mindestens $minimum Zeichen enthalten.';
    case 'string_too_long':
      final maximum = context is Map ? context['max_length'] : null;
      return maximum == null
          ? '$label ist zu lang.'
          : '$label darf höchstens $maximum Zeichen enthalten.';
    case 'greater_than_equal':
      final minimum = context is Map ? context['ge'] : null;
      return '$label muss mindestens $minimum sein.';
    case 'greater_than':
      final minimum = context is Map ? context['gt'] : null;
      return '$label muss größer als $minimum sein.';
    case 'less_than_equal':
      final maximum = context is Map ? context['le'] : null;
      return '$label darf höchstens $maximum sein.';
    case 'literal_error':
      return '$label enthält eine ungültige Auswahl.';
    default:
      final fallback = error['msg']?.toString();
      return fallback == null ? null : '$label: $fallback';
  }
}

String _fieldLabel(String field) => switch (field) {
      'title' => 'Titel',
      'district' => 'Stadtteil',
      'landmark' => 'Orientierungspunkt',
      'latitude' => 'Breitengrad',
      'longitude' => 'Längengrad',
      'exact_address' => 'Genaue Adresse',
      'entrance_instructions' => 'Zufahrts- und Einparkhinweise',
      'hourly_price_cents' => 'Preis pro Stunde',
      'currency' => 'Währung',
      'max_height_m' => 'Maximale Höhe',
      'max_width_m' => 'Maximale Breite',
      'max_length_m' => 'Maximale Länge',
      'access_type' => 'Art der Zufahrt',
      _ => field,
    };
